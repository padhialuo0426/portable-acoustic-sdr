function gui()
%GUI  实验三 · 线性调频(chirp)扩频通信 —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp3_chirp/host)后直接运行 gui
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
    A.jses = [];  A.jkey = '';      % 复用的 JSch 会话
    A.imgdir = fullfile(A.here, '..', 'baseband_images');
    A.cancelled = false; A.player = []; A.job = ''; A.busy = false;
    A.fs = 8000; A.T = 0.1; A.B = 200; A.fc = 1000; A.n = 800;
    A.mseq  = [1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
    A.GUARD = 5;

    %% ------------------------- 界面骨架 -------------------------
    fig = uifigure('Name','实验三 · chirp 扩频 —— 一键声学实测', ...
                   'Position',[80 80 1020 660]);
    root = uigridlayout(fig,[1 2]);
    root.ColumnWidth = {340,'1x'};

    gL = uigridlayout(uipanel(root,'Title','设置与操作'),[19 2]);
    gL.RowHeight   = [repmat({26},1,12), repmat({32},1,6), {'1x'}];
    gL.ColumnWidth = {100,'1x'};
    gL.RowSpacing  = 4;      % 默认 10 会把 17 个间隙累积成 170px，末尾按钮被挤出可视区

    lab = @(t) uilabel(gL,'Text',t,'HorizontalAlignment','right');

    % 三项都必填。走 MATLAB 自带的 JSch，它不读 ~/.ssh/config，所以「主机/IP」
    % 不能填 ssh 别名（pi5 这种），要填真实 IP 或可解析的主机名。
    lab('主机/IP');      A.host = uieditfield(gL,'text','Value','', ...
                              'Placeholder','如 192.168.3.82', ...
                              'Tooltip','IP 或可解析主机名；不支持 ~/.ssh/config 里的别名', ...
                              'ValueChangedFcn',@(~,~)credentialsChanged());
    lab('用户名');       A.user = uieditfield(gL,'text','Value','', ...
                              'Placeholder','板子登录名，如 pi', ...
                              'ValueChangedFcn',@(~,~)credentialsChanged());
    lab('密码');         A.pass = uieditfield(gL,'text','Value','', ...
                              'Placeholder','板子登录密码', ...
                              'Tooltip','注意：MATLAB 编辑框不支持掩码，密码会明文显示', ...
                              'ValueChangedFcn',@(~,~)credentialsChanged());
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

    A.btnCheck = mkButton(gL,'① 自检（连接 / 枚举声卡）',@onCheck);
    A.btnSync  = mkButton(gL,'② 同步源码到板上并编译',@onSync);
    A.btnLevel = mkButton(gL,'③ 电平校准（放测试音测 RMS）',@onLevel);
    A.btnRun   = mkButton(gL,'④ 一键声学实测',@onRun);
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

    fig.CloseRequestFcn = @(~,~) closeAll();
    refreshTiming();
    logf('就绪。顺序：① 自检 → ② 同步并编译 → ③ 电平校准 → ④ 一键实测');
    logf('先填「主机/IP」「用户名」「密码」三项（不支持 ~/.ssh/config 别名）');
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
            clearCapture();
            tgt = jTarget();
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

            [st,~] = ssh(sprintf('test -x %s/build/chirp_rx', remoteDir()));
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
            [buildStatus,out] = ssh(sprintf('cd %s && make clean && make', ...
                                  remoteDir()));
            [st,~] = ssh(sprintf('test -x %s/build/chirp_rx', remoteDir()));
            if buildStatus == 0 && st == 0
                logStep('编译', '✓', '已生成 build/chirp_rx');
                return
            end
            logStep('编译', '✗', '编译失败（退出码 %d）', buildStatus);
            if contains(out, 'asoundlib.h') || contains(out, '-lasound')
                logf('  板上缺 ALSA 开发库（见 Q&A Q8）');
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
            if ~ensureConn(), return, end
            if isempty(alsaDev()), logf('先点「① 自检」枚举采集设备。'); return, end
            wav = ['/tmp/pasdr_level_' char(java.util.UUID.randomUUID()) '.wav'];
            bgssh(sprintf('arecord -D %s -f S16_LE -r 8000 -c 1 -d 6 %s', shellQuote(alsaDev()), shellQuote(wav)));
            pause(1); checkCancelled();

            [x,~,~,~,~] = buildWaveform();
            nplay = min(numel(x), 4*A.fs);
            playAudio(x(1:nplay)*A.amp.Value);
            logStep('板上录音 6s / 本机放音 4s', '✓', '');
            if ~waitRemoteDone(12), return, end

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
            [x, info_all, code, NN, MM] = buildWaveform();
            dur  = code * A.T;
            tcap = ceil(A.lead.Value + dur + A.tail.Value);

            logf('--- ④ 一键实测 ---');
            if ~ensureConn() || ~ready(), return, end
            logf('%s  %dx%d=%d 位  信号 %.1fs  采集窗口 %ds', ...
                 A.img.Value, MM, NN, NN*MM, dur, tcap);

            % 1) 板上启动采集（后台），旧数据先删掉避免看到上一次的结果
            bgssh(sprintf('cd %s && rm -f chirp5.mat && ./build/chirp_rx -d %s -t %d', ...
                          remoteDir(), shellQuote(alsaDev()), tcap));
            logStep('板上采集', '✓', '已启动');
            pause(A.lead.Value); checkCancelled();

            % 2) 本机放音（阻塞，确保放完再往下走）
            logStep('本机放音', '▶', '%.1fs', dur);
            playAudio(x*A.amp.Value);
            logStep('本机放音', '✓', '结束，等板上采集窗口跑完');

            % 3) 等板上进程退出
            if ~waitRemoteDone(tcap + 10), return, end

            % 4) 取回
            localMat = fullfile(A.here,'chirp5.mat');
            [st,out] = scpFrom(sprintf('%s/chirp5.mat', A.rdir.Value), localMat);
            if st ~= 0
                logStep('取回数据', '✗', '%s', firstLine(out));
                logf('  板上可能没产出 chirp5.mat（采集设备打不开？见 Q&A Q1/Q2）');
                return
            end
            logStep('取回数据', '✓', 'chirp5.mat');

            % 5) 解码
            doDecode(localMat, info_all, NN, MM);
        catch e
            logStep('一键实测', '✗', '%s', firstLine(e.message));
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
            logStep('解码', '✗', '%s', firstLine(e.message));
        end
    end

    function onStop(~,~)
        A.cancelled = true;
        if ~isempty(A.player), stop(A.player); end
        if isempty(A.job)
            logf('没有本界面启动的采集任务。'); return
        end
        stopJob();
        logf('已请求中止本次采集，本地流程也已取消。');
    end

    %% ------------------------- 干活的部分 -------------------------

    function doDecode(matfile, info_all, NN, MM)
        if ~isfile(matfile)
            logStep('解码', '✗', '本地没有 chirp5.mat，先做一次实测'); return
        end
        S = load(matfile);
        if ~isfield(S,'toFileData5')
            logStep('解码', '✗', '文件里没有 toFileData5 变量'); return
        end
        validateattributes(S.toFileData5, {'numeric'}, {'2d','nrows',2,'nonempty','real','finite'});
        xs = S.toFileData5(2,:);            % 第 1 行是时间，第 2 行是判决值
        if ~deadStreamOK(all(xs == 0)), return, end

        [ber, bmp, l1, l2, flag] = decodeStream(xs, info_all, NN, MM);
        logStep('帧同步', '✓', '帧头 %d / 帧尾 %d（极性 %+d）', l1, l2, flag);

        A.berTxt.Text = sprintf('BER = %d/%d = %.4f', round(ber*NN*MM), NN*MM, ber);
        if ber == 0
            A.berTxt.FontColor = [0 0.5 0];
            logStep('BER', '✓', '0/%d，实验三通过', NN*MM);
        else
            A.berTxt.FontColor = [0.8 0 0];
            logStep('BER', '△', '%.4f 有误码，检查电平/环境噪声', ber);
        end

        showBitmap(A.axTx, imread(fullfile(A.imgdir, A.img.Value)), '发送点阵');
        showBitmap(A.axRx, bmp, '接收还原');
    end

    % 组帧 + BOK chirp 调制（与 bok_emit.m 等价，但不放音、不写 info_all.mat）
    function [x, info_all, code, NN, MM] = buildWaveform()
        imdata = imread(fullfile(A.imgdir, A.img.Value));
        if ~ismatrix(imdata) || ~all(imdata(:) == 0 | imdata(:) == 1)
            error('发送图片必须为只含 0/1 的单通道二值 BMP。');
        end
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
        dec = double(xs(l1+15 : l2-1)*flag <= 0);    % >0 判为码元 0，否则为 1
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
            logStep('数据检查', '✗', '板上采到的全是 0，麦克风没收到信号');
            logf('  常见原因：选中输出设备的音量过低（系统音量只作用于默认输出）、');
            logf('  输出设备选错、麦克风没接好。先用「③ 电平校准」看 RMS（见 Q&A Q7/Q4）');
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

    % ---- 板上采集设备：连过去跑 arecord -l 现场枚举 ----
    function ok = refreshAlsa()
        ok = false;
        if ~ensureConn(), clearCapture(); return, end
        [st,out] = ssh('LC_ALL=C arecord -l');
        if st ~= 0
            clearCapture();
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
    % .slx、基带图片不上板；slprj 中编译需要的 _sharedutils 源码也要上传。
    function ok = deployFiles()
        ok = false;
        [repoRoot, expName] = fileparts(fileparts(A.here));
        pats = { fullfile('common','include','*.h'), ...
                 fullfile('common','src','*.c'), ...
                 fullfile(expName,'Makefile'), ...
                 fullfile(expName,'include','*.h'), ...
                 fullfile(expName,'src','*.c'), ...
                 fullfile(expName,'simulink_model','*_ert_rtw','*.c'), ...
                 fullfile(expName,'simulink_model','*_ert_rtw','*.h'), ...
                 fullfile(expName,'simulink_model','slprj','ert','_sharedutils','*.c'), ...
                 fullfile(expName,'simulink_model','slprj','ert','_sharedutils','*.h') };
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

        tgz = [tempname '.tgz'];
        tarCleanup = onCleanup(@() deleteIfPresent(tgz));
        if isfile(tgz), delete(tgz); end
        tar(tgz, rel, repoRoot);

        remoteRoot = '~/portable-acoustic-sdr';
        % 先删掉板上旧的生成代码目录：tar 解包只覆盖/新增、不删除，若这次重新
        % 生成让某个 .c 改了名或消失，残留的"孤儿 .c"会被 Makefile 的 *.c 通配
        % 编进去而报错（教程 5.1 提醒过的坑）。手写源码目录不会有这问题，不动。

        remoteTar = ['/tmp/pasdr_deploy_' char(java.util.UUID.randomUUID()) '.tgz'];
        [st,out] = scpTo(tgz, remoteTar);
        if st ~= 0, logStep('同步源码', '✗', '上传失败：%s', firstLine(out)); return, end
        % --exclude='._*'：macOS 的扩展属性会被 MATLAB 的 tar 打成 AppleDouble
        % 条目，解包后变成一堆 ._xxx.c 垃圾文件。它们不会被编进去（GNU make 的
        % wildcard 用 glob，* 不匹配点开头的文件），但没必要留在板上。
        [st,out] = ssh(sprintf(['tar tzf %s >/dev/null && mkdir -p %s && rm -rf %s/%s/simulink_model && tar xzf %s -C %s ' ...
                                '--exclude=''._*'' && rm -f %s'], ...
                               shellQuote(remoteTar), remoteRoot, remoteRoot, expName, ...
                               shellQuote(remoteTar), remoteRoot, shellQuote(remoteTar)));
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
        [st,~] = ssh(sprintf('test -x %s/build/chirp_rx', remoteDir()));
        ok = (st == 0);
        if ~ok
            logStep('前置检查', '✗', '板上没有可执行，先点「② 同步源码到板上并编译」');
        end
    end

    function [st,out] = scpTo(localPath, remotePath)
        [st,out] = jput(localPath, remotePath);
    end

    % 开跑前先探一次连通。否则主机/密码填错时，会白放完整段音频、再慢慢
    % 等满超时才失败——用户等一分钟才知道是 IP 打错了。
    function ok = ensureConn()
        [st,out] = ssh('true');
        ok = (st == 0);
        if ~ok
            logStep(sprintf('连接 %s', jTarget()), '✗', '%s', firstLine(out));
            logf('  已中止。先用「① 自检」确认主机/用户名/密码');
        end
    end

    %% ---------------- 传输层：全部走 MATLAB 自带的 JSch ----------------
    % 不调用系统的 ssh/scp/sshpass。JSch 来自 matlabroot/java/jarext/jsch.jar，
    % 属于 MATLAB **基础安装**（本机一个支持包都没装，它照样可用），所以
    % Windows/macOS/Linux 行为完全一致，填 IP+用户名+密码即可一键部署——这正是
    % MathWorks 树莓派支持包能做到全平台一键部署的同一条路径。
    %
    % 两点代价，已知并接受：
    %   1. 不读 ~/.ssh/config，主机栏不能用别名；
    %   2. MATLAB 带的是 JSch 0.1.x，**不支持 ed25519 私钥**（实测 addIdentity
    %      直接报 invalid privatekey），所以这里只做密码认证。
    % 复用同一条 JSch 会话：自检/轮询会发很多条短命令，每条都新建 TCP+认证
    % 太慢（等待板上进程时是 0.5s 一次）。凭据变了就重建。
    function s = jsession()
        if isempty(strtrim(A.host.Value)) || isempty(strtrim(A.user.Value)) ...
                || isempty(A.pass.Value)
            error('请先填写「主机/IP」「用户名」「密码」三项。');
        end
        key = sprintf('%s|%s', jTarget(), A.pass.Value);
        if ~isempty(A.jses) && strcmp(A.jkey, key) && A.jses.isConnected()
            s = A.jses;  return
        end
        jdisconnect();
        j = javaObject('com.jcraft.jsch.JSch');
        cfg = java.util.Properties();
        cfg.put('StrictHostKeyChecking','no');   % 实验环境沿用不校验主机密钥的策略（并非 accept-new）
        [u, h] = jUserHost();
        [ip, note] = resolveHost(h);
        if ~isempty(note), logf('  主机 %s %s', h, note); end
        s = j.getSession(u, ip, 22);
        s.setPassword(A.pass.Value);
        s.setConfig(cfg);
        s.setTimeout(60000);      % 板上 make 期间输出有间隔，别让读超时打断
        try
            s.connect(10000);
        catch e
            s.disconnect();
            rethrow(e);
        end
        A.jses = s;  A.jkey = key;
    end

    function jdisconnect()
        try
            if ~isempty(A.jses) && A.jses.isConnected(), A.jses.disconnect(); end
        catch
        end
        A.jses = [];  A.jkey = '';
    end

    function [u, h] = jUserHost()
        h = strtrim(A.host.Value);
        u = strtrim(A.user.Value);
    end

    % 自己解析主机名、优先取 IPv4，再把地址交给 JSch。两个实测踩到的坑：
    %   1. 板子常同时有全局 IPv6（树莓派默认就有两个 2001:...），而 Java 默认
    %      优先 IPv6，那些地址未必可路由 -> NoRouteToHost；
    %   2. 本机若装了 Clash/Surge 这类做 fake-IP DNS 的代理软件，解析不了的
    %      主机名会被统统映射到 198.18.0.0/15 的假地址（实测 pi5 -> 198.18.1.254），
    %      连出去必然失败。系统 ssh 不会踩这个坑是因为它读 ~/.ssh/config 把别名
    %      直接换成真实 IP、根本不做 DNS 解析；JSch 没有这层保护。
    function [ip, note] = resolveHost(h)
        note = '';  ip = h;
        try
            addrs = java.net.InetAddress.getAllByName(h);
        catch
            note = '解析不了，建议直接填 IP';  return
        end
        pick = '';
        for k = 1:numel(addrs)
            a = char(addrs(k).getHostAddress());
            if ~contains(a, ':'), pick = a; break, end      % 优先 IPv4
        end
        if isempty(pick), pick = char(addrs(1).getHostAddress()); end
        ip = pick;
        if ~strcmp(ip, h), note = sprintf('解析为 %s', ip); end
        if startsWith(ip,'198.18.') || startsWith(ip,'198.19.')
            note = sprintf(['%s —— 这是代理软件(Clash/Surge 等)的 fake-IP，' ...
                            '不是板子的真实地址。请在「主机/IP」直接填局域网 IP'], note);
        end
    end

    function t = jTarget()
        [u, h] = jUserHost();
        if isempty(h),      t = '(未填主机)';
        elseif isempty(u),  t = h;
        else,               t = [u '@' h];
        end
    end

    % 用字节流保存完整输出；轮询通道结束，避免 readLine 阻塞 UI。
    function [st, out] = jexec(cmd)
        st = 255;
        try
            s = jsession();
            ch = s.openChannel('exec');
            closer = onCleanup(@() ch.disconnect());
            ch.setCommand(sprintf('{ %s ; } 2>&1', cmd));
            bytes = java.io.ByteArrayOutputStream();
            ch.setOutputStream(bytes);
            ch.connect(10000);
            deadline = tic;
            while ~ch.isClosed()
                if toc(deadline) > 180
                    error('远端命令超过 180 秒未结束。');
                end
                pause(0.02);
            end
            st = double(ch.getExitStatus());
            out = char(bytes.toString('UTF-8'));
        catch e
            out = jerr(e);
        end
    end

    % 每次任务独立目录，保存真实退出码/日志，并只中止自己的进程组。
    function jexecDetached(cmd)
        checkCancelled();
        [st,out] = ssh('mktemp -d /tmp/pasdr_job.XXXXXXXX');
        if st ~= 0, error('%s', out); end
        A.job = strtrim(out);
        q = shellQuote(A.job);
        body = sprintf('echo $$ > %s/pid; ( %s ); rc=$?; echo "$rc" > %s/status', q, cmd, q);
        [st,out] = ssh(sprintf('nohup setsid sh -c %s >%s/log 2>&1 </dev/null & launcher=$!', shellQuote(body), q));
        if st ~= 0, error('后台启动失败：%s', out); end
        % 等到远端包装进程确实启动，不能只等固定 0.2s 就声称成功。
        [st,out] = ssh(sprintf(['i=0; while [ ! -s %s/pid ] && [ "$i" -lt 50 ]; ' ...
            'do sleep 0.1; i=$((i+1)); done; test -s %s/pid'], q, q));
        if st ~= 0, error('后台进程未启动：%s', out); end
        pause(0.2); checkCancelled();
        [done,ok] = jobStatus();
        if done && ~ok, error('板上采集启动失败，见上方日志。'); end
    end

    % SFTP 的初始目录就是家目录，但它不展开 ~，去掉前缀用相对路径即可
    function p = jPath(p)
        if startsWith(p, '~/'), p = p(3:end); end
    end

    function [st, out] = jput(localPath, remotePath)
        st = 0;  out = '';
        try
            s  = jsession();
            sf = s.openChannel('sftp');
            closer = onCleanup(@() sf.disconnect());
            sf.connect(10000);
            sf.put(localPath, jPath(remotePath));
        catch e
            st = 1;  out = jerr(e);
        end
    end

    function [st, out] = jget(remotePath, localPath)
        st = 0;  out = '';
        try
            s  = jsession();
            sf = s.openChannel('sftp');
            closer = onCleanup(@() sf.disconnect());
            sf.connect(10000);
            partial = [tempname(fileparts(localPath)) '.part'];
            cleanup = onCleanup(@() deleteIfPresent(partial));
            sf.get(jPath(remotePath), partial);
            [ok,msg] = movefile(partial, localPath, 'f');
            if ~ok, error('%s', msg); end
        catch e
            st = 1;  out = jerr(e);
        end
    end

    function [st,out] = ssh(remoteCmd)
        [st,out] = jexec(remoteCmd);
    end

    % macOS 的「本地网络」隐私限制只挡局域网、不挡公网，且授权按**责任进程**
    % 归属：从 Finder/Dock 启动时责任进程就是 MATLAB 自己，从终端启动时是终端，
    % 这正是"终端启动能连、点图标启动连不上"的原因。环境变量 __CFBundleIdentifier
    % 记的就是这个责任进程，可直接用来判断当前 MATLAB 是怎么起来的。
    % 实测依据：点图标启动的 MATLAB 里，局域网 TCP 失败而 webread 公网正常。
    function s = netHint()
        if ~ismac
            s = '——检查板子地址、本机路由和防火墙';  return
        end
        if strcmp(getenv('__CFBundleIdentifier'), 'com.mathworks.matlab')
            s = ['——这个 MATLAB 是从 Finder/Dock 启动的，几乎可以确定是 macOS' ...
                 '「本地网络」隐私限制：它只挡局域网、不挡公网。最省事的绕法是' ...
                 '在终端执行 matlab -desktop 启动 MATLAB（授权按责任进程归属，' ...
                 '终端启动即可继承）。'];
        else
            s = '——检查板子地址是否填对、板子与本机是否同网段';
        end
    end

    % Java 异常带一大段栈，日志里只要人看得懂的那句
    function s = jerr(e)
        s = firstLine(regexprep(e.message, '^Java exception occurred:\s*', ''));
        s = strtrim(regexprep(s, '^com\.jcraft\.jsch\.\w+:\s*', ''));
        m = e.message;
        if strcmpi(s, 'Auth fail') || strcmpi(s, 'Auth cancel')
            s = '认证失败——用户名或密码不对';
        elseif contains(m, 'UnknownHostException')
            s = '主机名解析不了——建议直接填局域网 IP';
        elseif contains(lower(m), 'connection refused')
            % 这条要排在通用的 ConnectException 前面：地址是通的，只是没人听 22 端口
            s = '连接被拒——地址通了但 22 端口没响应，板子上 sshd 开着吗？';
        elseif contains(m, 'NoRouteToHostException') || contains(lower(m), 'no route to host') ...
                || contains(lower(m), 'host is down') || contains(m, 'ConnectException') ...
                || contains(m, 'SocketException') || contains(m, 'SocketTimeoutException') ...
                || contains(lower(m), 'timed out') || contains(lower(m), 'timeout')
            % 以上都是"TCP 层就没连上"，对用户是同一件事，合并处理
            s = ['连不上板子（还没走到密码认证这一步）' netHint()];
        end
        if isempty(s), s = firstLine(e.message); end
    end

    % 从板上取文件。走 SFTP，没有命令行 scp 那套 "C:\..." 盘符被当成 host:
    % 前缀的 Windows 老问题，本地路径直接给绝对路径即可。
    function [st,out] = scpFrom(remotePath, localPath)
        [st,out] = jget(remotePath, localPath);
    end

    function bgssh(remoteCmd)
        jexecDetached(remoteCmd);
    end

    function ok = waitRemoteDone(timeoutSec)
        t0 = tic; ok = false;
        while toc(t0) < timeoutSec
            checkCancelled();
            [done,ok] = jobStatus();
            if done, return, end
            pause(0.2);
        end
        stopJob();
        logStep('等待采集', '✗', '超时，已中止本次任务，不读取未完成数据');
    end

    function [done,ok] = jobStatus()
        q = shellQuote(A.job);
        [st,out] = ssh(sprintf('if test -f %s/status; then cat %s/status; else echo RUN; fi', q, q));
        if st ~= 0, error('查询采集状态失败：%s', out); end
        done = ~strcmp(strtrim(out), 'RUN');
        ok = done && strcmp(strtrim(out), '0');
        if done && ~ok
            [~,details] = ssh(sprintf('tail -n 8 %s/log', q));
            logStep('板上采集', '✗', '退出码 %s：%s', strtrim(out), strtrim(details));
        end
    end

    function stopJob()
        if isempty(A.job), return, end
        q = shellQuote(A.job);
        [st,out] = ssh(sprintf(['if test -s %s/pid && ! test -f %s/status; then ' ...
            'pid=$(cat %s/pid); case "$pid" in ""|*[!0-9]*) exit 1;; esac; ' ...
            '/bin/kill -TERM -- -"$pid"; fi'], q, q, q));
        if st ~= 0, logStep('中止采集', '✗', '%s', firstLine(out)); end
    end

    function checkCancelled()
        if A.cancelled || ~isvalid(fig), error('本次操作已取消。'); end
    end

    function playAudio(y)
        checkCancelled();
        A.player = mkPlayer(y);
        play(A.player);
        while isplaying(A.player)
            pause(0.05); checkCancelled();
        end
        checkCancelled();
    end

    function clearCapture()
        A.devStrs = {};
        A.dev.Items = {'(点「① 自检」后枚举)'};
        A.dev.Enable = 'off'; A.btnAlsa.Enable = 'off';
    end

    function credentialsChanged()
        jdisconnect(); clearCapture();
        A.rdir.Value = ''; A.rdir.Enable = 'off';
    end

    function q = remoteDir()
        p = strtrim(A.rdir.Value);
        if startsWith(p, '~/')
            q = ['$HOME/' shellQuote(p(3:end))];
        else
            q = shellQuote(p);
        end
    end

    function refreshOutputs()
        if A.busy, return, end
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
        if ~isvalid(fig), return, end
        if tf
            A.cancelled = false;
        elseif ~isempty(A.job)
            stopJob();
            A.job = '';
        end
        A.busy = tf;
        s = {'on','off'};  s = s{1+tf};
        A.btnCheck.Enable = s;  A.btnSync.Enable  = s;
        A.btnLevel.Enable = s;  A.btnRun.Enable   = s;
        A.btnDec.Enable   = s;
        A.host.Enable = s; A.user.Enable = s; A.pass.Enable = s;
        A.lead.Enable = s; A.tail.Enable = s; A.amp.Enable = s;
        A.odev.Enable = s; A.img.Enable = s;
        if ~isempty(A.rdir.Value), A.rdir.Enable = s; end
        if ~isempty(A.devStrs), A.dev.Enable = s; A.btnAlsa.Enable = s; end
        drawnow;
    end

    % 日志只报流程和状态，不打印可执行命令——命令该出现在文档里，不该刷屏
    function closeAll()
        if A.busy
            onStop([],[]);
            logf('请等待本次操作结束后再关闭窗口。'); return
        end
        jdisconnect();
        delete(fig);
    end

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

% POSIX shell 单引号转义，允许板上路径含空格/单引号。
function q = shellQuote(s)
    quote = char(39);
    q = [quote strrep(char(s), quote, [quote char(34) quote char(34) quote]) quote];
end

function deleteIfPresent(p)
    if isfile(p), delete(p); end
end
