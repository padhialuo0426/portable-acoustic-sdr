function gui()
%GUI  实验二 · 线性调频(chirp)扩频通信 —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp2_chirp/host)后直接运行 gui
%
%   把「手把手部署运行教程」第 4 节的动作串成一次点击：
%     板上启动 chirp_rx 采集 → 宿主机扬声器播放 chirp 信号 → 等采集窗口跑完
%     → scp 取回 chirp5.mat → 帧同步/硬判决/算 BER → 显示还原点阵
%
%   为什么不需要"掐秒表"：板上程序从启动到真正开始采集的死区实测只有
%   70~175ms，ssh 连接开销约 20ms；而帧同步是在整条判决流里扫 m 序列、
%   不要求对齐——只要信号完整落在采集窗口内就能解。所以默认 1s 前导 +
%   2s 尾部余量已经很宽裕，手动操作时那种"看到板子开始录就立刻放音"的
%   紧张感在这里是不必要的。
%
%   注意：本界面是便利封装。教学正路仍是 bok_emit / bok_rev 两个脚本手动跑
%   （见 documents/手把手部署运行教程.md）。为了让那两个脚本保持可独立通读，
%   本文件自带了等价的组帧/解码逻辑，没有把它们重构成函数——**改帧结构时
%   两边都要改**。

    A.here = fileparts(mfilename('fullpath'));
    if isempty(A.here), A.here = pwd; end
    A.imgdir = fullfile(A.here, '..', 'baseband_images');
    A.fs = 8000; A.T = 0.1; A.B = 200; A.fc = 1000; A.n = 800;
    A.mseq  = [1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
    A.GUARD = 5;

    %% ------------------------- 界面骨架 -------------------------
    fig = uifigure('Name','实验二 · chirp 扩频 —— 一键声学实测', ...
                   'Position',[80 80 1020 660]);
    root = uigridlayout(fig,[1 2]);
    root.ColumnWidth = {340,'1x'};

    gL = uigridlayout(uipanel(root,'Title','设置与操作'),[18 2]);
    gL.RowHeight   = [repmat({26},1,12), repmat({32},1,5), {'1x'}];
    gL.ColumnWidth = {100,'1x'};
    gL.RowSpacing  = 4;      % 默认 10 会把 17 个间隙累积成 170px，末尾按钮被挤出可视区

    lab = @(t) uilabel(gL,'Text',t,'HorizontalAlignment','right');

    lab('主机/IP');      A.host = uieditfield(gL,'text','Value','pi5', ...
                              'Tooltip','ssh 别名（如 pi5）或 IP（如 192.168.3.82）');
    lab('用户名');       A.user = uieditfield(gL,'text','Value','', ...
                              'Placeholder','留空 = 用 ~/.ssh/config 里的 User');
    lab('密码');         A.pass = uieditfield(gL,'text','Value','', ...
                              'Placeholder','留空 = 密钥登录（推荐）', ...
                              'Tooltip','注意：MATLAB 编辑框不支持掩码，密码会明文显示');
    lab('板上路径');     A.rdir = uieditfield(gL,'text','Value','','Enable','off', ...
                              'Placeholder','点「① 自检」后自动填入');
    lab('ALSA 设备');
    gAd = uigridlayout(gL,[1 2]); gAd.ColumnWidth = {'1x',30};
    gAd.RowHeight = {'1x'}; gAd.Padding = [0 0 0 0]; gAd.ColumnSpacing = 4;
    A.dev  = uidropdown(gAd,'Items',{'(点「① 自检」后枚举)'},'Enable','off');
    A.btnAlsa = uibutton(gAd,'Text','⟳','Enable','off', ...
             'Tooltip','重新枚举板上采集设备（换麦克风/重插 USB 后点一下）', ...
             'ButtonPushedFcn',@(~,~)refreshAlsa());
    A.devStrs = {};
    imgItems = listImages(A.imgdir);
    lab('发送图片');     A.img  = uidropdown(gL,'Items',imgItems, ...
                                             'Value',pickDefault(imgItems), ...
                                             'ValueChangedFcn',@(~,~)refreshTiming());
    lab('前导余量 (s)'); A.lead = uieditfield(gL,'numeric','Value',1,'Limits',[0 30], ...
                                             'ValueChangedFcn',@(~,~)refreshTiming());
    lab('尾部余量 (s)'); A.tail = uieditfield(gL,'numeric','Value',2,'Limits',[0 60], ...
                                             'ValueChangedFcn',@(~,~)refreshTiming());
    lab('播放幅度');     A.amp  = uieditfield(gL,'numeric','Value',0.8,'Limits',[0 1]);
    [odevNames, A.odevIDs] = listOutputs();
    lab('输出设备');
    gOd = uigridlayout(gL,[1 2]); gOd.ColumnWidth = {'1x',30};
    gOd.RowHeight = {'1x'}; gOd.Padding = [0 0 0 0]; gOd.ColumnSpacing = 4;
    A.odev = uidropdown(gOd,'Items',odevNames,'Value',pickSpeaker(odevNames));
    uibutton(gOd,'Text','⟳','Tooltip','重新枚举输出设备（插拔耳机后点一下）', ...
             'ButtonPushedFcn',@(~,~)refreshOutputs());
    lab('信号时长');     A.durTxt = uilabel(gL,'Text','—');
    lab('采集窗口');     A.capTxt = uilabel(gL,'Text','—');

    A.btnCheck = mkButton(gL,'① 自检（连接 / 同步源码 / 枚举声卡）',@onCheck);
    A.btnLevel = mkButton(gL,'② 电平校准（放测试音测 RMS）',@onLevel);
    A.btnRun   = mkButton(gL,'③ 一键声学实测',@onRun);
    A.btnDec   = mkButton(gL,'仅解码已取回的 chirp5.mat',@onDecodeOnly);
    A.btnStop  = mkButton(gL,'中止板上采集',@onStop);

    gR = uigridlayout(root,[2 1]); gR.RowHeight = {'1x',180};

    pRes = uipanel(gR,'Title','结果');
    gRes = uigridlayout(pRes,[2 2]); gRes.RowHeight = {28,'1x'};
    A.berTxt = uilabel(gRes,'Text','BER: —','FontSize',16,'FontWeight','bold');
    A.berTxt.Layout.Column = [1 2];
    A.axTx = uiaxes(gRes); title(A.axTx,'发送点阵');  axis(A.axTx,'off');
    A.axRx = uiaxes(gRes); title(A.axRx,'接收还原');  axis(A.axRx,'off');

    gLog = uigridlayout(uipanel(gR,'Title','日志'),[1 1]);
    gLog.Padding = [5 5 5 5];
    A.log = uitextarea(gLog,'Editable','off','Value',cell(0,1),'FontName','Menlo');

    refreshTiming();
    logf('就绪。建议顺序：① 自检 → ② 电平校准 → ③ 一键实测。');
    logf('放音在本机、录音在板子，不要自放自录。');

    %% ------------------------- 回调 -------------------------

    function onCheck(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            logf('--- 自检 ---');
            [~,tgt,~,~] = sshBase();
            if isempty(A.pass.Value)
                logf('连接 %s（密钥登录）', tgt);
            else
                logf('连接 %s（密码登录，sshpass %s）', tgt, ternary(hasSshpass(),'可用','缺失'));
            end
            [st,out] = ssh('hostname');
            if st ~= 0
                logf('✗ ssh 连不上 %s：%s', A.host.Value, strtrim(out));
                return
            end
            logf('✓ ssh 通，板子 hostname = %s', strtrim(out));

            % 同步源码 -> 枚举采集设备 -> 看有没有编好的可执行
            if ~deployFiles(), return, end
            refreshAlsa();

            [st,~] = ssh(sprintf('test -x %s/build/chirp_rx', A.rdir.Value));
            if st == 0
                logf('✓ 板上已有可执行 build/chirp_rx，可以直接做实测。');
            else
                logf('△ 板上还没编译出 build/chirp_rx。源码已经传好，到板上执行：');
                logf('     ssh %s "cd %s && make clean && make"', tgt, A.rdir.Value);
                logf('  编译需要 libasound2-dev（见 Q&A Q10）。这一步刻意保留手动，见 Q8。');
            end
        catch e
            logf('✗ 自检出错：%s', e.message);
        end
    end

    function onLevel(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            logf('--- 电平校准：板上录 6s，本机放 4s 测试音 ---');
            if ~ready() || ~ensureConn(), return, end
            wav = '/tmp/pasdr_level.wav';
            bgssh(sprintf('arecord -D %s -f S16_LE -r 8000 -c 1 -d 6 %s', alsaDev(), wav));
            pause(1);

            [x,~,~,~,~] = buildWaveform();
            nplay = min(numel(x), 4*A.fs);
            playblocking(mkPlayer(x(1:nplay)*A.amp.Value));
            logf('测试音播放完毕，等板上录音结束…');
            waitRemoteDone('arecord', 12);

            local = fullfile(tempdir,'pasdr_level.wav');
            [st,out] = scpFrom(wav, local);
            if st ~= 0, logf('✗ 取回录音失败：%s', strtrim(out)); return, end

            y = audioread(local);
            pk = max(abs(y))*32768;  rms_ = sqrt(mean(y.^2))*32768;
            logf('RMS = %.0f    峰值 = %d', rms_, pk);
            if pk < 300
                logf('✗ 太弱：麦克风可能没接好，或本机音量太低（见 Q&A Q4）。');
            elseif pk < 1500
                logf('△ 偏低：建议调高本机播放音量或板上采集增益。');
            elseif pk > 20000
                logf('△ 偏高：有过载风险，建议调低（见 Q&A Q5）。');
            else
                logf('✓ 电平合适（峰值几千量级），可以做实测了。');
            end
            logf('板上调增益：amixer -c <card> sset <控件> <百分比> cap');
        catch e
            logf('✗ 电平校准出错：%s', e.message);
        end
    end

    function onRun(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            [x, info_all, code, NN, MM] = buildWaveform();
            dur  = code * A.T;
            tcap = ceil(A.lead.Value + dur + A.tail.Value);

            logf('--- 一键实测 ---');
            if ~ready() || ~ensureConn(), return, end
            logf('图片 %s  %dx%d=%d 位  符号数=%d  时长=%.1fs  采集窗口 -t %d', ...
                 A.img.Value, MM, NN, NN*MM, code, dur, tcap);

            % 1) 板上启动采集（后台），旧数据先删掉避免看到上一次的结果
            bgssh(sprintf('cd %s && rm -f chirp5.mat && ./build/chirp_rx -d %s -t %d', ...
                          A.rdir.Value, alsaDev(), tcap));
            logf('板上 chirp_rx 已启动，等 %.1fs 前导…', A.lead.Value);
            pause(A.lead.Value);

            % 2) 本机放音（阻塞，确保放完再往下走）
            logf('开始播放（%.1fs）…', dur);
            playblocking(mkPlayer(x*A.amp.Value));
            logf('播放结束，等板上采集窗口跑完…');

            % 3) 等板上进程退出
            if ~waitRemoteDone('chirp_rx', tcap + 10)
                logf('△ 等待超时，仍尝试取回数据。');
            end

            % 4) 取回
            localMat = fullfile(A.here,'chirp5.mat');
            [st,out] = scpFrom(sprintf('%s/chirp5.mat', A.rdir.Value), localMat);
            if st ~= 0
                logf('✗ scp 取回失败：%s', strtrim(out));
                logf('  板上可能没产出 chirp5.mat（采集设备打不开？见 Q&A Q1/Q2）。');
                return
            end
            logf('✓ 已取回 chirp5.mat -> host/');

            % 5) 解码
            doDecode(localMat, info_all, NN, MM);
        catch e
            logf('✗ 实测出错：%s', e.message);
        end
    end

    function onDecodeOnly(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            [~, info_all, ~, NN, MM] = buildWaveform();
            doDecode(fullfile(A.here,'chirp5.mat'), info_all, NN, MM);
        catch e
            logf('✗ 解码出错：%s', e.message);
        end
    end

    function onStop(~,~)
        [~,~] = ssh('pkill -x chirp_rx; pkill -x arecord');
        logf('已向板子发送中止信号。');
    end

    %% ------------------------- 干活的部分 -------------------------

    function doDecode(matfile, info_all, NN, MM)
        if ~isfile(matfile)
            logf('✗ 找不到 %s，先做一次实测。', matfile); return
        end
        S = load(matfile);
        if ~isfield(S,'toFileData5')
            logf('✗ %s 里没有 toFileData5 变量。', matfile); return
        end
        xs = S.toFileData5(2,:);            % 第 1 行是时间，第 2 行是判决值
        logf('判决流 %d 帧（%.1fs）', numel(xs), numel(xs)/10);
        if ~deadStreamOK(all(xs == 0)), return, end

        [ber, bmp, l1, l2, flag] = decodeStream(xs, info_all, NN, MM);
        logf('帧同步：flag=%d  帧头=%d  帧尾=%d（相距 %d）', flag, l1, l2, l2-l1);

        A.berTxt.Text = sprintf('BER = %d/%d = %.4f', round(ber*NN*MM), NN*MM, ber);
        if ber == 0
            A.berTxt.FontColor = [0 0.5 0];
            logf('✓ BER = 0，实验二通过。');
        else
            A.berTxt.FontColor = [0.8 0 0];
            logf('△ BER = %.4f，有误码。检查电平/环境噪声。', ber);
        end

        showBitmap(A.axTx, imread(fullfile(A.imgdir, A.img.Value)), '发送点阵');
        showBitmap(A.axRx, bmp, '接收还原');
    end

    % 组帧 + BOK chirp 调制（与 bok_emit.m 等价，但不放音、不写 info_all.mat）
    function [x, info_all, code, NN, MM] = buildWaveform()
        imdata = imread(fullfile(A.imgdir, A.img.Value));
        data = double(imdata);
        [NN, MM] = size(data);              % NN=行(高)  MM=列(宽)
        info_all = zeros(1, NN*MM);
        for m = 1:MM                        % 列优先展开
            for nn = 1:NN
                info_all((m-1)*NN+nn) = data(nn,m);
            end
        end
        L = NN*MM;
        code = 50 + L + A.GUARD;
        info = zeros(1, code);
        info(1:10)        = 0;                          % 信号检测前导
        info(11:20)       = [1 0 1 0 1 0 1 0 1 0];      % 交替段
        info(21:35)       = A.mseq;                     % 帧头
        info(36:35+L)     = info_all;                   % 图片信息
        info(36+L:50+L)   = A.mseq;                     % 帧尾
        % 其余为 GUARD 个 0：补偿接收 1 符号时延、防 EOF 截断

        t = linspace(0, A.T, A.n);
        k = A.B / A.T;
        miu = ones(1, code); miu(info == 1) = -1;       % 码元0->上扫, 1->下扫
        x = zeros(1, code*A.n);
        for i = 1:code
            x((i-1)*A.n+1 : i*A.n) = ...
                real(exp(1i*(2*pi*A.fc*t + pi*miu(i)*k*t.^2)));
        end
    end

    % 帧同步 + 硬判决（与 bok_rev.m 等价；另外把 flag=-1 的极性反转也试一遍）
    function [ber, bmp, l1, l2, flag] = decodeStream(xs, info_all, NN, MM)
        L = NN*MM;  gap = L + 15;
        pm = [-1;1;1;-1;-1;1;-1;1;-1;-1;-1;-1;1;1;1];
        best = [];
        for fl = [1 -1]
            loc = [];
            for p = 1:numel(xs)-14
                if xs(p:p+14)*fl*pm > sum(abs(xs(p:p+10))) && abs(xs(p)) == 1
                    loc(end+1) = p; %#ok<AGROW>
                end
            end
            for i = 1:numel(loc)-1
                if any(loc(i+1:end) - loc(i) == gap)
                    best = [fl, loc(i), loc(i)+gap];  break
                end
            end
            if ~isempty(best), break, end
        end
        if isempty(best)
            error(['未找到相距 %d 的帧头/帧尾 m 序列。可能原因：图片选错、' ...
                   '采集时长不够、信号太弱或过载。'], gap);
        end
        flag = best(1);  l1 = best(2);  l2 = best(3);
        dec = double(xs(l1+15 : l2-1) <= 0);    % >0 判为码元 0，否则为 1
        if flag == -1, dec = 1 - dec; end
        ber = sum(dec ~= info_all) / L;
        bmp = reshape(dec, NN, MM);             % 列优先，与组帧时一致
    end

    %% ------------------------- 小工具 -------------------------

    % 显式指定输出设备，不依赖系统默认输出——否则接了蓝牙耳机时声音会跑到
    % 耳机里，板上麦克风一无所获（判决流全 0）。这是实测踩过的坑。
    % 板上确实跑完了、文件也取回了，但内容是死的——这种情况要把原因说清楚，
    % 否则只会抛一个含糊的"找不到帧头/峰值不对"，排查方向全错。
    function ok = deadStreamOK(isDead)
        ok = ~isDead;
        if isDead
            logf('✗ 板上采到的数据全为 0——麦克风没收到任何信号。按可能性排：');
            logf('   1) 选中设备的音量太低。注意 macOS/Windows 都是**按设备分别记忆音量**的，');
            logf('      系统音量滑块只控制"当前默认输出"。若默认输出是蓝牙耳机，而这里选的是');
            logf('      %s，那么调系统音量调的是耳机、扬声器仍停在旧音量——', A.odev.Value);
            logf('      声音确实从扬声器出来了，但小到麦克风收不到。');
            logf('      解决：把系统输出临时切到该设备再调音量，或直接断开耳机。');
            logf('   2) 「输出设备」选错（当前选的是 %s）；', A.odev.Value);
            logf('   3) 麦克风没接好 / 「ALSA 设备」card 号不对（见 Q&A Q2/Q4）。');
            logf('   先点「② 电平校准」，看 RMS 是否随放音跳起来——它就是用来定位这类问题的。');
        end
    end

    function p = mkPlayer(y)
        k = find(strcmp(A.odev.Items, A.odev.Value), 1);
        if isempty(k) || isempty(A.odevIDs)
            p = audioplayer(y, A.fs);
        else
            p = audioplayer(y, A.fs, 16, A.odevIDs(k));
        end
        if ~isempty(regexpi(A.odev.Value, 'airpod|headphone|headset|bluetooth|耳机', 'once'))
            logf('△ 输出设备像是耳机：%s —— 声音不会经空气传到板上麦克风。', A.odev.Value);
        end
    end

    % 拼 ssh 公共部分。密码非空时走 sshpass -e：密码经环境变量传给 sshpass，
    % 不出现在命令行里（否则同机其它用户 ps 就能看到）。留空则用密钥登录，
    % 并加 BatchMode=yes 让连不上时立刻失败而不是卡在密码提示上。
    function [pre, tgt, opts, ok] = sshBase()
        ok  = true;  pre = '';
        tgt = strtrim(A.host.Value);
        u   = strtrim(A.user.Value);
        if ~isempty(u), tgt = [u '@' tgt]; end
        if isempty(A.pass.Value)
            opts = '-o BatchMode=yes -o ConnectTimeout=8';
        else
            if ~hasSshpass()
                logf('✗ 填了密码，但系统里没有 sshpass，无法用密码登录。');
                if ispc
                    logf('  Windows 没有 sshpass（自带的只有 ssh/scp）。请清空密码框改用密钥登录：');
                    logf('       ssh-keygen -t ed25519');
                    logf('       type %%USERPROFILE%%\\.ssh\\id_ed25519.pub | ssh %s "mkdir -p .ssh && cat >> .ssh/authorized_keys"', tgt);
                else
                    logf('  两条路：① 清空密码框，改用密钥登录（推荐）：');
                    logf('       ssh-keygen -t ed25519 && ssh-copy-id %s', tgt);
                    logf('  ② 安装 sshpass：macOS `brew install sshpass`，Debian `apt install sshpass`。');
                end
                ok = false;  opts = '';  return
            end
            setenv('SSHPASS', A.pass.Value);
            pre  = 'sshpass -e ';
            % 填了密码就明确只走密码认证，这需要同时关掉两样东西，否则密码框形同虚设：
            %   PubkeyAuthentication=no —— 否则本机有可用密钥时 ssh 先用密钥连上，
            %      密码填错也"成功"；
            %   ControlMaster=no / ControlPath=none —— 这条更隐蔽：~/.ssh/config 里
            %      常见的 `ControlMaster auto` + `ControlPersist` 会复用已认证的连接，
            %      认证环节被整个跳过，错密码照样通（实测踩过）。
            opts = ['-o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new ' ...
                    '-o PubkeyAuthentication=no -o PreferredAuthentications=password ' ...
                    '-o ControlMaster=no -o ControlPath=none'];
        end
    end

    % 开跑前先探一次连通。否则主机/密码填错时，会白放完整段音频、再慢慢
    % 等满超时才失败——用户等一分钟才知道是 IP 打错了。
    % ---- 板上采集设备：ssh 过去 arecord -l 现场枚举 ----
    function refreshAlsa()
        if ~ensureConn(), return, end
        [st,out] = ssh('arecord -l');
        if st ~= 0, logf('✗ 枚举板上采集设备失败：%s', strtrim(out)); return, end
        [nm, ds] = parseArecord(out);
        if isempty(ds)
            A.dev.Items = {'(板上没有采集设备)'};  A.dev.Enable = 'off';  A.devStrs = {};
            logf('✗ 板上 arecord -l 没列出任何采集设备——麦克风没插好？（见 Q&A Q4）');
            return
        end
        keep = alsaDev();                       % 尽量保住用户已选的那个
        A.devStrs = ds;  A.dev.Items = nm;
        A.dev.Enable = 'on';  A.btnAlsa.Enable = 'on';
        k = find(strcmp(ds, keep), 1);
        if isempty(k), k = pickCapture(nm); end
        A.dev.Value = nm{k};
        A.dev.Tooltip = strjoin(nm, newline);   % 下拉收起时名字会截断
        logf('板上采集设备 %d 个：', numel(nm));
        for i = 1:numel(nm), logf('    %s', nm{i}); end
    end

    % 下拉里显示的是带描述的长名字，真正要传给 -d/-D 的是 plughw:X,Y
    function d = alsaDev()
        d = '';
        if isempty(A.devStrs), return, end
        k = find(strcmp(A.dev.Items, A.dev.Value), 1);
        if ~isempty(k) && k <= numel(A.devStrs), d = A.devStrs{k}; end
    end

    % ---- 把板上编译需要的源码送过去 ----
    % 用 MATLAB 自带的 tar 打包，不依赖宿主机有 find/tar（教程第 2 节那条管线
    % 在 Windows 上要 Git Bash 才有）。只挑 Makefile/.c/.h，与教程口径一致：
    % .slx、基带图片、slprj 缓存都不上板。
    function ok = deployFiles()
        ok = false;
        [repoRoot, expName] = fileparts(fileparts(A.here));
        pats = { fullfile('common','include','*.h'), ...
                 fullfile('common','src','*.c'), ...
                 fullfile(expName,'Makefile'), ...
                 fullfile(expName,'include','*.h'), ...
                 fullfile(expName,'src','*.c'), ...
                 fullfile(expName,'simulink_model','*_ert_rtw','*.c'), ...
                 fullfile(expName,'simulink_model','*_ert_rtw','*.h') };
        rel = {};
        for i = 1:numel(pats)
            L = dir(fullfile(repoRoot, pats{i}));
            for k = 1:numel(L)
                if L(k).isdir, continue, end
                r = L(k).folder(numel(repoRoot)+2:end);     % 去掉 repoRoot 前缀
                rel{end+1} = strrep(fullfile(r, L(k).name), '\', '/'); %#ok<AGROW>
            end
        end
        if isempty(rel)
            logf('✗ 本地没找到要上板的源码（Makefile/.c/.h），工程目录不完整？');
            return
        end

        tgz = fullfile(tempdir, 'pasdr_deploy.tgz');
        if isfile(tgz), delete(tgz); end
        tar(tgz, rel, repoRoot);
        logf('打包 %d 个文件（Makefile/.c/.h）上传…', numel(rel));

        remoteRoot = '~/portable-acoustic-sdr';
        [st,out] = scpTo(tgz, '/tmp/pasdr_deploy.tgz');
        if st ~= 0, logf('✗ 上传失败：%s', strtrim(out)); return, end
        % --exclude='._*'：macOS 的扩展属性会被 MATLAB 的 tar 打成 AppleDouble
        % 条目，解包后变成一堆 ._xxx.c 垃圾文件。它们不会被编进去（GNU make 的
        % wildcard 用 glob，* 不匹配点开头的文件），但没必要留在板上。
        [st,out] = ssh(sprintf(['mkdir -p %s && tar xzf /tmp/pasdr_deploy.tgz -C %s ' ...
                                '--exclude=''._*'' && rm -f /tmp/pasdr_deploy.tgz'], ...
                               remoteRoot, remoteRoot));
        if st ~= 0, logf('✗ 板上解包失败：%s', strtrim(out)); return, end

        A.rdir.Value  = sprintf('%s/%s', remoteRoot, expName);
        A.rdir.Enable = 'on';
        logf('✓ 源码已同步到板上 %s', A.rdir.Value);
        ok = true;
    end

    % 自检之前，板上路径和采集设备都是空的，直接跑必然失败——提前说清楚
    function ok = ready()
        ok = ~isempty(strtrim(A.rdir.Value)) && ~isempty(alsaDev());
        if ~ok
            logf('✗ 还没自检。先点「① 自检」——它会把源码同步到板上并枚举采集设备。');
        end
    end

    function [st,out] = scpTo(localPath, remotePath)
        [pre,tgt,opts,ok] = sshBase();
        if ~ok, st = 255; out = 'sshpass 缺失'; return, end
        [dstDir, nm, ext] = fileparts(localPath);
        if isempty(dstDir), dstDir = pwd; end
        oldDir = cd(dstDir);
        restore = onCleanup(@() cd(oldDir));
        [st,out] = system(sprintf('%sscp -q %s "%s" %s:%s', pre, opts, [nm ext], tgt, remotePath));
    end

    function ok = ensureConn()
        [st,out] = ssh('true');
        ok = (st == 0);
        if ~ok
            [~,tgt,~,~] = sshBase();
            logf('✗ 连不上 %s，已中止。', tgt);
            o = strtrim(out);
            if ~isempty(o), logf('  %s', o); end
            logf('  先点「① 自检」确认主机/用户名/密码，或改用密钥登录。');
        end
    end

    function [st,out] = ssh(remoteCmd)
        [pre,tgt,opts,ok] = sshBase();
        if ~ok, st = 255; out = 'sshpass 缺失'; return, end
        [st,out] = system(sprintf('%sssh %s %s "%s"', pre, opts, tgt, remoteCmd));
    end

    % 从板上取文件；remoteRel 相对板上工程目录，留空表示 remoteRel 是绝对路径
    function [st,out] = scpFrom(remotePath, localPath)
        [pre,tgt,opts,ok] = sshBase();
        if ~ok, st = 255; out = 'sshpass 缺失'; return, end
        % 先 cd 到目标目录、再用裸文件名作为 scp 的目的地。绕开 Windows 上
        % "C:\..." 的盘符冒号被 scp 误当成 host: 前缀的老问题，macOS/Linux 下等价。
        [dstDir, nm, ext] = fileparts(localPath);
        if isempty(dstDir), dstDir = pwd; end
        oldDir = cd(dstDir);
        restore = onCleanup(@() cd(oldDir));
        [st,out] = system(sprintf('%sscp -q %s %s:%s "%s"', ...
                                  pre, opts, tgt, remotePath, [nm ext]));
    end

    function bgssh(remoteCmd)
        [pre,tgt,opts,ok] = sshBase();
        if ~ok, return, end
        c = sprintf('%sssh %s %s "%s"', pre, opts, tgt, remoteCmd);
        if ispc
            % 空标题 "" 不能省：start 会把第一个带引号的参数当成窗口标题
            system(sprintf('start "" /b %s > NUL 2>&1', c));
        else
            system(sprintf('%s > /dev/null 2>&1 &', c));
        end
    end

    function ok = waitRemoteDone(procName, timeoutSec)
        t0 = tic;  ok = false;
        while toc(t0) < timeoutSec
            % 必须用 -x（精确匹配进程名）：-f 会匹配到承载 pgrep 的那条
            % ssh 命令行本身（里面就含进程名），导致永远判定为"还在跑"。
            [st,out] = ssh(sprintf('pgrep -x %s >/dev/null && echo RUN || echo DONE', procName));
            if st ~= 0
                logf('△ 轮询板上进程时 ssh 失败，不再空转等待。');
                return          % 连接已经断了，继续轮询只是把超时耗满
            end
            if contains(out,'DONE'), ok = true; return, end
            pause(0.5);
        end
    end

    function refreshOutputs()
        cur = A.odev.Value;
        [nm, A.odevIDs] = listOutputs();
        A.odev.Items = nm;
        if any(strcmp(nm, cur)), A.odev.Value = cur;
        else,                    A.odev.Value = pickSpeaker(nm); end
        logf('输出设备已刷新，共 %d 个：%s', numel(nm), strjoin(nm, ' | '));
    end

    function refreshTiming()
        try
            inf_ = imfinfo(fullfile(A.imgdir, A.img.Value));
            L = inf_.Width * inf_.Height;
            code = 50 + L + A.GUARD;
            dur  = code * A.T;
            A.durTxt.Text = sprintf('%.1f s（%d 符号 / %d 位）', dur, code, L);
            A.capTxt.Text = sprintf('-t %d', ceil(A.lead.Value + dur + A.tail.Value));
        catch
            A.durTxt.Text = '—';  A.capTxt.Text = '—';
        end
    end

    function setBusy(tf)
        s = {'on','off'};  s = s{1+tf};
        A.btnCheck.Enable = s;  A.btnLevel.Enable = s;
        A.btnRun.Enable   = s;  A.btnDec.Enable   = s;
        drawnow;
    end

    function logf(fmt, varargin)
        msg = sprintf(fmt, varargin{:});
        cur = A.log.Value;
        if isscalar(cur) && isempty(strtrim(cur{1})), cur = cell(0,1); end
        A.log.Value = [cur; strsplit(msg, newline)'];
        scroll(A.log,'bottom');  drawnow;
    end
end

%% ------------------------- 局部函数 -------------------------

% arecord -l 形如：
%   card 2: K10 [KSS K10], device 0: USB Audio [USB Audio]
% 解析成设备串 plughw:2,0 和带详细名称的显示串
function [names, devs] = parseArecord(txt)
    names = {};  devs = {};
    lines = strsplit(txt, newline);
    for i = 1:numel(lines)
        tok = regexp(strtrim(lines{i}), ...
            '^card\s+(\d+):\s*\S+\s*\[([^\]]*)\].*?device\s+(\d+):\s*(.*?)\s*\[', ...
            'tokens', 'once');
        if numel(tok) == 4
            devs{end+1}  = sprintf('plughw:%s,%s', tok{1}, tok{3}); %#ok<AGROW>
            names{end+1} = sprintf('plughw:%s,%s — %s (%s)', ...
                                   tok{1}, tok{3}, strtrim(tok{2}), strtrim(tok{4})); %#ok<AGROW>
        end
    end
end

% 板上常同时有 HDMI 等无关采集口，USB 声卡才是麦克风，优先选它
function k = pickCapture(names)
    k = find(~cellfun(@isempty, regexpi(names,'usb','once')), 1);
    if isempty(k), k = 1; end
end

function v = ternary(c, a, b)
    if c, v = a; else, v = b; end
end

function ok = hasSshpass()
    if ispc
        [s,~] = system('where sshpass');
    else
        [s,~] = system('command -v sshpass');
    end
    ok = (s == 0);
end

function [names, ids] = listOutputs()
    names = {};  ids = [];
    try
        d = audiodevinfo;
        for i = 1:numel(d.output)
            names{end+1} = d.output(i).Name; %#ok<AGROW>
            ids(end+1)   = d.output(i).ID;   %#ok<AGROW>
        end
    catch
    end
    if isempty(names), names = {'(系统默认)'}; ids = []; end
end

% 优先选内置扬声器：接了蓝牙耳机时默认输出会被抢走，而本实验必须走扬声器
function v = pickSpeaker(names)
    k = find(~cellfun(@isempty, regexpi(names, 'speaker|扬声器|built-?in|internal', 'once')), 1);
    if isempty(k), k = 1; end
    v = names{k};
end

function b = mkButton(parent, txt, cb)
    b = uibutton(parent,'Text',txt,'ButtonPushedFcn',cb);
    b.Layout.Column = [1 2];
end

% 默认选最短的 ren128b（约 18s），跑通链路最快；没有就用第一张
function v = pickDefault(items)
    k = find(strcmpi(items,'ren128b.bmp'), 1);
    if isempty(k), k = 1; end
    v = items{k};
end

function items = listImages(d)
    L = dir(fullfile(d,'*.bmp'));
    if isempty(L)
        items = {'(baseband_images 下没有 bmp)'};
    else
        items = {L.name};
    end
end

function showBitmap(ax, bw, ttl)
    imagesc(ax, double(bw) > 0);
    colormap(ax, flipud(gray(2)));       % 1 -> 黑，0 -> 白
    axis(ax,'image');  axis(ax,'off');  title(ax, ttl);
end
