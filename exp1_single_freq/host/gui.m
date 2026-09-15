function gui()
%GUI  实验一 · 单频信号测试 —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp1_single_freq/host)后直接运行 gui
%
%   把「手把手部署运行教程」第 3 节的动作串成一次点击：
%     板上启动 sdr_rx 采集 → 宿主机扬声器播放单频音 → 等采集窗口跑完
%     → scp 取回 single_f.mat → FFT 看频谱峰值是否落在设定频率
%
%   时序不必掐秒表：板上程序从启动到真正开始采集的死区实测只有 70~175ms，
%   ssh 连接开销约 20ms；而频谱分析是对整段录音做 FFT，单频音落在窗口
%   任意位置都能测出峰值。默认 1s 前导 + 2s 尾部余量足够。
%
%   注意：本界面是便利封装。教学正路仍是 single_fre_emit / spectrum 两个脚本
%   手动跑（见 documents/手把手部署运行教程.md）。为了让那两个脚本保持可独立
%   通读，本文件自带了等价的波形生成与频谱分析逻辑，没有去重构它们。

    A.here = fileparts(mfilename('fullpath'));
    if isempty(A.here), A.here = pwd; end
    A.fs = 8000;

    %% ------------------------- 界面骨架 -------------------------
    fig = uifigure('Name','实验一 · 单频信号 —— 一键声学实测', ...
                   'Position',[80 80 1020 660]);
    root = uigridlayout(fig,[1 2]);
    root.ColumnWidth = {340,'1x'};

    gL = uigridlayout(uipanel(root,'Title','设置与操作'),[19 2]);
    gL.RowHeight   = [repmat({26},1,12), repmat({32},1,6), {'1x'}];
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
    lab('载波 fc (Hz)'); A.fc   = uieditfield(gL,'numeric','Value',1000,'Limits',[50 3900]);
    lab('发射时长 (s)'); A.dur  = uieditfield(gL,'numeric','Value',1,'Limits',[0.1 60], ...
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
    lab('采集窗口');     A.capTxt = uilabel(gL,'Text','—');

    A.btnCheck = mkButton(gL,'① 自检（连接 / 枚举声卡）',@onCheck);
    A.btnSync  = mkButton(gL,'② 同步源码到板上并编译',@onSync);
    A.btnLevel = mkButton(gL,'③ 电平校准（放测试音测 RMS）',@onLevel);
    A.btnRun   = mkButton(gL,'④ 一键声学实测',@onRun);
    A.btnAna   = mkButton(gL,'仅分析已取回的 single_f.mat',@onAnalyzeOnly);
    A.btnStop  = mkButton(gL,'中止板上采集',@onStop);

    gR = uigridlayout(root,[2 1]); gR.RowHeight = {'1x',180};

    pRes = uipanel(gR,'Title','结果');
    gRes = uigridlayout(pRes,[3 1]); gRes.RowHeight = {28,'1x','1x'};
    A.pkTxt = uilabel(gRes,'Text','频谱峰值: —','FontSize',16,'FontWeight','bold');
    A.axT = uiaxes(gRes); title(A.axT,'时域波形');  xlabel(A.axT,'时间 (s)');
    A.axF = uiaxes(gRes); title(A.axF,'频谱 (FFT)'); xlabel(A.axF,'频率 (Hz)');

    gLog = uigridlayout(uipanel(gR,'Title','日志'),[1 1]);
    gLog.Padding = [5 5 5 5];
    A.log = uitextarea(gLog,'Editable','off','Value',cell(0,1),'FontName','Menlo');

    refreshTiming();
    logf('就绪。顺序：① 自检 → ② 同步并编译 → ③ 电平校准 → ④ 一键实测');
    logf('放音在本机、录音在板子，不要自放自录');

    %% ------------------------- 回调 -------------------------

    function onCheck(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            logf('--- ① 自检 ---');
            % 先清空再重新探测：自检有好几条提前 return 的分支（连不上、枚举
            % 失败…），若不清空，上一次成功时填的路径会继续显示，而它可能早已
            % 不成立了。自检的语义应当是"显示的一切都是刚刚验证过的"。
            A.rdir.Value = '';  A.rdir.Enable = 'off';
            [~,tgt,~,~] = sshBase();
            [st,out] = ssh('hostname');
            if st ~= 0
                logStep(sprintf('连接 %s', tgt), '✗', '%s', firstLine(out));
                return
            end
            logStep(sprintf('连接 %s', tgt), '✓', '%s', strtrim(out));

            if ~refreshAlsa(), return, end

            % 「板上路径」显示的必须是**板上确实存在**的目录，不能是本地推算出来
            % 的预期值——否则板子上被 rm -rf 之后重开界面，日志说"还没同步"、
            % 输入框却显示着路径，自相矛盾。所以先探再填，探不到就清空并置灰。
            [~, expName] = fileparts(fileparts(A.here));
            guess = sprintf('~/portable-acoustic-sdr/%s', expName);
            [st,~] = ssh(sprintf('test -d %s', guess));
            if st ~= 0
                A.rdir.Value  = '';
                A.rdir.Enable = 'off';
                logStep('板上源码', '△', '板上没有，请点「② 同步源码到板上并编译」');
                return
            end
            A.rdir.Value  = guess;
            A.rdir.Enable = 'on';
            logStep('板上源码', '✓', '%s', guess);

            [st,~] = ssh(sprintf('test -x %s/build/sdr_rx', A.rdir.Value));
            if st == 0
                logStep('板上可执行', '✓', '已就绪');
            else
                logStep('板上可执行', '△', '未编译，请点「② 同步源码到板上并编译」');
            end
        catch e
            logStep('自检', '✗', '%s', firstLine(e.message));
        end
    end

    function onSync(~,~)
        setBusy(true);
        guard = onCleanup(@() setBusy(false));
        try
            logf('--- ② 同步源码到板上并编译 ---');
            if ~ensureConn(), return, end
            if ~deployFiles(), return, end
            % make clean 不能省：PC 与板子时钟可能有偏差，新 .c 的时间戳不一定
            % 比旧 .o 新，make 会误判"已是最新"而不重编，跑的还是旧逻辑
            logStep('编译', '▶', '板上 gcc，稍候');
            [~,out] = ssh(sprintf('cd %s && make clean >/dev/null 2>&1 && make 2>&1', ...
                                  A.rdir.Value));
            [st,~] = ssh(sprintf('test -x %s/build/sdr_rx', A.rdir.Value));
            if st == 0
                logStep('编译', '✓', '已生成 build/sdr_rx');
                return
            end
            logStep('编译', '✗', '未生成可执行');
            if contains(out, 'asoundlib.h') || contains(out, '-lasound')
                logf('  板上缺 ALSA 开发库（见 Q&A Q10）');
            end
            tail_ = strsplit(strtrim(out), newline);
            for i = max(1, numel(tail_)-4):numel(tail_)
                logf('  %s', strtrim(tail_{i}));
            end
        catch e
            logStep('同步并编译', '✗', '%s', firstLine(e.message));
        end
    end

    function onLevel(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            logf('--- ③ 电平校准 ---');
            if ~ready() || ~ensureConn(), return, end
            wav = '/tmp/pasdr_level.wav';
            bgssh(sprintf('arecord -D %s -f S16_LE -r 8000 -c 1 -d 6 %s', alsaDev(), wav));
            pause(1);

            playblocking(mkPlayer(makeTone(4)*A.amp.Value));
            logStep('板上录音 6s / 本机放音 4s', '✓', '');
            waitRemoteDone('arecord', 12);

            local = fullfile(tempdir,'pasdr_level.wav');
            [st,out] = scpFrom(wav, local);
            if st ~= 0, logStep('取回录音', '✗', '%s', firstLine(out)); return, end

            y = audioread(local);
            pk = max(abs(y))*32768;  rms_ = sqrt(mean(y.^2))*32768;
            lv = sprintf('RMS=%.0f 峰值=%.0f', rms_, pk);
            if pk < 300
                logStep('电平', '✗', '%s 太弱，麦克风没接好或音量太低（见 Q&A Q4）', lv);
            elseif pk < 1500
                logStep('电平', '△', '%s 偏低，调高本机音量或板上采集增益', lv);
            elseif pk > 20000
                logStep('电平', '△', '%s 偏高，有过载风险（见 Q&A Q5）', lv);
            else
                logStep('电平', '✓', '%s 合适', lv);
            end
        catch e
            logStep('电平校准', '✗', '%s', firstLine(e.message));
        end
    end

    function onRun(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            tcap = ceil(A.lead.Value + A.dur.Value + A.tail.Value);
            logf('--- ④ 一键实测 ---');
            if ~ready() || ~ensureConn(), return, end
            logf('单频 %g Hz  信号 %.1fs  采集窗口 %ds', ...
                 A.fc.Value, A.dur.Value, tcap);

            % 1) 板上启动采集（后台），旧数据先删掉
            bgssh(sprintf('cd %s && rm -f single_f.mat single_f2.mat && ./build/sdr_rx -d %s -t %d', ...
                          A.rdir.Value, alsaDev(), tcap));
            logStep('板上采集', '✓', '已启动');
            pause(A.lead.Value);

            % 2) 本机放音（阻塞）
            logStep('本机放音', '▶', '%.1fs', A.dur.Value);
            playblocking(mkPlayer(makeTone(A.dur.Value)*A.amp.Value));
            logStep('本机放音', '✓', '结束，等板上采集窗口跑完');

            % 3) 等板上进程退出
            if ~waitRemoteDone('sdr_rx', tcap + 10)
                logStep('等待采集', '△', '超时，仍尝试取回数据');
            end

            % 4) 取回
            localMat = fullfile(A.here,'single_f.mat');
            [st,out] = scpFrom(sprintf('%s/single_f.mat', A.rdir.Value), localMat);
            if st ~= 0
                logStep('取回数据', '✗', '%s', firstLine(out));
                logf('  板上可能没产出 single_f.mat（采集设备打不开？见 Q&A Q1/Q2）');
                return
            end
            logStep('取回数据', '✓', 'single_f.mat');

            % 5) 频谱分析
            doAnalyze(localMat);
        catch e
            logStep('一键实测', '✗', '%s', firstLine(e.message));
        end
    end

    function onAnalyzeOnly(~,~)
        setBusy(true);
        % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、scp 失败等失败
        % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次失败
        % 之后整个界面永久变灰按不动。
        guard = onCleanup(@() setBusy(false));
        try
            doAnalyze(fullfile(A.here,'single_f.mat'));
        catch e
            logStep('分析', '✗', '%s', firstLine(e.message));
        end
    end

    function onStop(~,~)
        [~,~] = ssh('pkill -x sdr_rx; pkill -x arecord');
        logf('已向板子发送中止信号。');
    end

    %% ------------------------- 干活的部分 -------------------------

    % 与 spectrum.m 等价：81×N 去掉时间行、逐列拼长向量、去直流、FFT 找正频峰
    function doAnalyze(matfile)
        if ~isfile(matfile)
            logStep('分析', '✗', '本地没有 single_f.mat，先做一次实测'); return
        end
        S = load(matfile);
        if ~isfield(S,'toFileData')
            logStep('分析', '✗', '文件里没有 toFileData 变量'); return
        end
        X = S.toFileData;
        if size(X,1) == 81, X = X(2:end,:); end     % 第 1 行是时间戳
        y = X(:);
        N = numel(y);
        if N == 0, logStep('分析', '✗', '数据为空'); return, end
        if ~deadStreamOK(max(abs(y)) < 1e-9), return, end
        y = y - mean(y);

        Y  = fft(y);
        f  = (-N/2:N/2-1)*(A.fs/N);
        Ys = fftshift(abs(Y))/N;
        pos = f > 0;  fpos = f(pos);  Ypos = Ys(pos);
        [pk, idx] = max(Ypos);
        fpeak = fpos(idx);

        plot(A.axT, (0:N-1)/A.fs, y);  grid(A.axT,'on');
        title(A.axT,'时域波形');  xlabel(A.axT,'时间 (s)');  ylabel(A.axT,'幅度');

        plot(A.axF, f, Ys);  grid(A.axF,'on');  xlim(A.axF,[0 A.fs/2]);
        hold(A.axF,'on');
        plot(A.axF, fpeak, pk, 'rv', 'MarkerFaceColor','r');
        text(A.axF, fpeak, pk, sprintf('  %.1f Hz', fpeak), 'Color','r');
        hold(A.axF,'off');
        title(A.axF,'频谱 (FFT)');  xlabel(A.axF,'频率 (Hz)');  ylabel(A.axF,'|Y|');

        err = abs(fpeak - A.fc.Value);
        A.pkTxt.Text = sprintf('频谱峰值 = %.1f Hz（设定 %g Hz，偏差 %.1f Hz）', ...
                               fpeak, A.fc.Value, err);
        if err <= 10
            A.pkTxt.FontColor = [0 0.5 0];
            logStep('频谱峰值', '✓', '%.1f Hz，实验一通过', fpeak);
        else
            A.pkTxt.FontColor = [0.8 0 0];
            logStep('频谱峰值', '△', '%.1f Hz 偏离设定 %g Hz，检查电平/噪声/采样率', ...
                    fpeak, A.fc.Value);
        end
    end

    % 与 single_fre_emit.m 等价的单频波形
    function x = makeTone(seconds)
        t = 0:1/A.fs:seconds;
        x = sin(2*pi*A.fc.Value*t);
    end

    %% ------------------------- 小工具 -------------------------

    % 显式指定输出设备，不依赖系统默认输出——否则接了蓝牙耳机时声音会跑到
    % 耳机里，板上麦克风一无所获（判决流全 0）。这是实测踩过的坑。
    % 板上确实跑完了、文件也取回了，但内容是死的——这种情况要把原因说清楚，
    % 否则只会抛一个含糊的"找不到帧头/峰值不对"，排查方向全错。
    function ok = deadStreamOK(isDead)
        ok = ~isDead;
        if isDead
            logStep('数据检查', '✗', '板上采到的全是 0，麦克风没收到信号');
            logf('  常见原因：选中输出设备的音量过低（系统音量只作用于默认输出）、');
            logf('  输出设备选错、麦克风没接好。先用「③ 电平校准」看 RMS（见 Q&A Q9/Q4）');
        end
    end

    function p = mkPlayer(y)
        k = find(strcmp(A.odev.Items, A.odev.Value), 1);
        if isempty(k) || isempty(A.odevIDs)
            p = audioplayer(y, A.fs);
        else
            try
                p = audioplayer(y, A.fs, 16, A.odevIDs(k));
            catch
                % 枚举之后把耳机拔了/断了，device ID 已失效。这里不能悄悄退回
                % 系统默认输出——那正是"声音跑进耳机、板上采到全 0"的成因。
                error(['输出设备「%s」已不可用（拔掉了？）。' ...
                       '点「输出设备」旁的 ⟳ 重新枚举后再试。'], A.odev.Value);
            end
        end
        if ~isempty(regexpi(A.odev.Value, 'airpod|headphone|headset|bluetooth|耳机', 'once'))
            logStep('输出设备', '△', '像是耳机，声音不会经空气传到板上麦克风');
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
                logStep('密码登录', '✗', '本机没有 sshpass');
                if ispc
                    logf('  Windows 没有 sshpass：请清空密码框改用密钥登录（见教程附录）');
                else
                    logf('  清空密码框改用密钥登录（推荐），或先安装 sshpass');
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
    function ok = refreshAlsa()
        ok = false;
        if ~ensureConn(), return, end
        [st,out] = ssh('arecord -l');
        if st ~= 0
            logStep('枚举采集设备', '✗', '%s', firstLine(out)); return
        end
        [nm, ds] = parseArecord(out);
        if isempty(ds)
            A.dev.Items = {'(板上没有采集设备)'};  A.dev.Enable = 'off';  A.devStrs = {};
            logStep('枚举采集设备', '✗', '板上一个都没有，麦克风没插好？（见 Q&A Q4）');
            return
        end
        keep = alsaDev();                       % 尽量保住用户已选的那个
        A.devStrs = ds;  A.dev.Items = nm;
        A.dev.Enable = 'on';  A.btnAlsa.Enable = 'on';
        k = find(strcmp(ds, keep), 1);
        if isempty(k), k = pickCapture(nm); end
        A.dev.Value = nm{k};
        A.dev.Tooltip = strjoin(nm, newline);   % 下拉收起时名字会截断
        logStep('枚举采集设备', '✓', '%d 个，选用 %s', numel(nm), nm{k});
        ok = true;
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
            logStep('同步源码', '✗', '本地没找到 Makefile/.c/.h');
            return
        end

        tgz = fullfile(tempdir, 'pasdr_deploy.tgz');
        if isfile(tgz), delete(tgz); end
        tar(tgz, rel, repoRoot);


        remoteRoot = '~/portable-acoustic-sdr';
        % 先删掉板上旧的生成代码目录：tar 解包只覆盖/新增、不删除，若这次重新
        % 生成让某个 .c 改了名或消失，残留的"孤儿 .c"会被 Makefile 的 *.c 通配
        % 编进去而报错（教程 5.1 提醒过的坑）。手写源码目录不会有这问题，不动。
        ssh(sprintf('rm -rf %s/%s/simulink_model', remoteRoot, expName));

        [st,out] = scpTo(tgz, '/tmp/pasdr_deploy.tgz');
        if st ~= 0, logStep('同步源码', '✗', '上传失败：%s', firstLine(out)); return, end
        % --exclude='._*'：macOS 的扩展属性会被 MATLAB 的 tar 打成 AppleDouble
        % 条目，解包后变成一堆 ._xxx.c 垃圾文件。它们不会被编进去（GNU make 的
        % wildcard 用 glob，* 不匹配点开头的文件），但没必要留在板上。
        [st,out] = ssh(sprintf(['mkdir -p %s && tar xzf /tmp/pasdr_deploy.tgz -C %s ' ...
                                '--exclude=''._*'' && rm -f /tmp/pasdr_deploy.tgz'], ...
                               remoteRoot, remoteRoot));
        if st ~= 0, logStep('同步源码', '✗', '板上解包失败：%s', firstLine(out)); return, end

        A.rdir.Value  = sprintf('%s/%s', remoteRoot, expName);
        A.rdir.Enable = 'on';
        logStep('同步源码', '✓', '%d 个文件 -> %s', numel(rel), A.rdir.Value);
        ok = true;
    end

    % 自检之前，板上路径和采集设备都是空的，直接跑必然失败——提前说清楚
    function ok = ready()
        ok = false;
        if isempty(alsaDev())
            logStep('前置检查', '✗', '还没自检，先点「① 自检」');  return
        end
        if isempty(strtrim(A.rdir.Value))
            logStep('前置检查', '✗', '板上没有源码，先点「② 同步源码到板上并编译」');
            return
        end
        [st,~] = ssh(sprintf('test -x %s/build/sdr_rx', A.rdir.Value));
        ok = (st == 0);
        if ~ok
            logStep('前置检查', '✗', '板上没有可执行，先点「② 同步源码到板上并编译」');
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
            logStep(sprintf('连接 %s', tgt), '✗', '%s', firstLine(out));
            logf('  已中止。先用「① 自检」确认主机/用户名/密码');
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
                logStep('等待采集', '△', 'ssh 断了，不再空转等待');
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
        A.capTxt.Text = sprintf('-t %d', ...
            ceil(A.lead.Value + A.dur.Value + A.tail.Value));
    end

    function setBusy(tf)
        s = {'on','off'};  s = s{1+tf};
        A.btnCheck.Enable = s;  A.btnSync.Enable  = s;
        A.btnLevel.Enable = s;  A.btnRun.Enable   = s;
        A.btnAna.Enable   = s;
        drawnow;
    end

    % 日志只报流程和状态，不打印可执行命令——命令该出现在文档里，不该刷屏
    function logStep(label, mark, fmt, varargin)
        if nargin < 3 || isempty(fmt)
            logf('%s … %s', label, mark);
        else
            logf('%s … %s %s', label, mark, sprintf(fmt, varargin{:}));
        end
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

% ssh/scp 的报错常有好几行，日志里只留最有信息量的第一行
function s = firstLine(txt)
    t = strtrim(txt);
    if isempty(t), s = ''; return, end
    parts = strsplit(t, newline);
    s = strtrim(parts{1});
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
