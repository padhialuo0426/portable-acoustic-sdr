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
    lab('板上路径');     A.rdir = uieditfield(gL,'text','Value','~/portable-acoustic-sdr/exp1_single_freq');
    lab('ALSA 设备');    A.dev  = uieditfield(gL,'text','Value','plughw:2,0');
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

    A.btnCheck = mkButton(gL,'① 自检（ssh / 可执行 / 声卡）',@onCheck);
    A.btnLevel = mkButton(gL,'② 电平校准（放测试音测 RMS）',@onLevel);
    A.btnRun   = mkButton(gL,'③ 一键声学实测',@onRun);
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

            [st,~] = ssh(sprintf('test -x %s/build/sdr_rx', A.rdir.Value));
            if st == 0
                logf('✓ 板上已有可执行 build/sdr_rx');
            else
                logf('✗ 板上没找到 %s/build/sdr_rx', A.rdir.Value);
                logf('  先按教程第 2 节传代码，再在板上 make（需 libasound2-dev）。');
            end

            [~,out] = ssh('arecord -l');
            logf('--- 板上采集设备 (arecord -l) ---');
            logf('%s', strtrim(out));
            logf('把上面麦克风所在的 card 号填进「ALSA 设备」，形如 plughw:<card>,0。');
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
            if ~ensureConn(), return, end
            wav = '/tmp/pasdr_level.wav';
            bgssh(sprintf('arecord -D %s -f S16_LE -r 8000 -c 1 -d 6 %s', A.dev.Value, wav));
            pause(1);

            playblocking(mkPlayer(makeTone(4)*A.amp.Value));
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
            tcap = ceil(A.lead.Value + A.dur.Value + A.tail.Value);
            logf('--- 一键实测 ---');
            if ~ensureConn(), return, end
            logf('单频 fc=%g Hz  发射 %.1fs  采集窗口 -t %d', ...
                 A.fc.Value, A.dur.Value, tcap);

            % 1) 板上启动采集（后台），旧数据先删掉
            bgssh(sprintf('cd %s && rm -f single_f.mat single_f2.mat && ./build/sdr_rx -d %s -t %d', ...
                          A.rdir.Value, A.dev.Value, tcap));
            logf('板上 sdr_rx 已启动，等 %.1fs 前导…', A.lead.Value);
            pause(A.lead.Value);

            % 2) 本机放音（阻塞）
            logf('开始播放（%.1fs）…', A.dur.Value);
            playblocking(mkPlayer(makeTone(A.dur.Value)*A.amp.Value));
            logf('播放结束，等板上采集窗口跑完…');

            % 3) 等板上进程退出
            if ~waitRemoteDone('sdr_rx', tcap + 10)
                logf('△ 等待超时，仍尝试取回数据。');
            end

            % 4) 取回
            localMat = fullfile(A.here,'single_f.mat');
            [st,out] = scpFrom(sprintf('%s/single_f.mat', A.rdir.Value), localMat);
            if st ~= 0
                logf('✗ scp 取回失败：%s', strtrim(out));
                logf('  板上可能没产出 single_f.mat（采集设备打不开？见 Q&A Q1/Q2）。');
                return
            end
            logf('✓ 已取回 single_f.mat -> host/');

            % 5) 频谱分析
            doAnalyze(localMat);
        catch e
            logf('✗ 实测出错：%s', e.message);
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
            logf('✗ 分析出错：%s', e.message);
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
            logf('✗ 找不到 %s，先做一次实测。', matfile); return
        end
        S = load(matfile);
        if ~isfield(S,'toFileData')
            logf('✗ %s 里没有 toFileData 变量。', matfile); return
        end
        X = S.toFileData;
        if size(X,1) == 81, X = X(2:end,:); end     % 第 1 行是时间戳
        y = X(:);
        N = numel(y);
        if N == 0, logf('✗ 数据为空。'); return, end
        logf('样本数=%d  时长=%.2fs  录到的峰值=%.0f', N, N/A.fs, max(abs(y)));
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
            logf('✓ 峰值 %.1f Hz 落在设定频率附近，实验一通过。', fpeak);
        else
            A.pkTxt.FontColor = [0.8 0 0];
            logf('△ 峰值 %.1f Hz 偏离设定 %g Hz。检查电平/环境噪声/设备采样率。', ...
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
        A.capTxt.Text = sprintf('-t %d', ...
            ceil(A.lead.Value + A.dur.Value + A.tail.Value));
    end

    function setBusy(tf)
        s = {'on','off'};  s = s{1+tf};
        A.btnCheck.Enable = s;  A.btnLevel.Enable = s;
        A.btnRun.Enable   = s;  A.btnAna.Enable   = s;
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
