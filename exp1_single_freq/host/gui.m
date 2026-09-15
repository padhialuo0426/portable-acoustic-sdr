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

    gL = uigridlayout(uipanel(root,'Title','设置与操作'),[16 2]);
    gL.RowHeight   = [repmat({26},1,10), repmat({34},1,5), {'1x'}];
    gL.ColumnWidth = {100,'1x'};

    lab = @(t) uilabel(gL,'Text',t,'HorizontalAlignment','right');

    lab('ssh 主机');     A.host = uieditfield(gL,'text','Value','pi5');
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
    lab('输出设备');     A.odev = uidropdown(gL,'Items',odevNames, ...
                                             'Value',pickSpeaker(odevNames));
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

    A.log = uitextarea(uipanel(gR,'Title','日志'),'Editable','off','Value',cell(0,1));

    refreshTiming();
    logf('就绪。建议顺序：① 自检 → ② 电平校准 → ③ 一键实测。');
    logf('放音在本机、录音在板子，不要自放自录。');

    %% ------------------------- 回调 -------------------------

    function onCheck(~,~)
        setBusy(true);
        try
            logf('--- 自检 ---');
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
        setBusy(false);
    end

    function onLevel(~,~)
        setBusy(true);
        try
            logf('--- 电平校准：板上录 6s，本机放 4s 测试音 ---');
            wav = '/tmp/pasdr_level.wav';
            bgssh(sprintf('arecord -D %s -f S16_LE -r 8000 -c 1 -d 6 %s', A.dev.Value, wav));
            pause(1);

            playblocking(mkPlayer(makeTone(4)*A.amp.Value));
            logf('测试音播放完毕，等板上录音结束…');
            waitRemoteDone('arecord', 12);

            local = fullfile(tempdir,'pasdr_level.wav');
            [st,out] = system(sprintf('scp -q %s:%s "%s"', A.host.Value, wav, local));
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
        setBusy(false);
    end

    function onRun(~,~)
        setBusy(true);
        try
            tcap = ceil(A.lead.Value + A.dur.Value + A.tail.Value);
            logf('--- 一键实测 ---');
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
            [st,out] = system(sprintf('scp -q %s:%s/single_f.mat "%s"', ...
                                      A.host.Value, A.rdir.Value, localMat));
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
        setBusy(false);
    end

    function onAnalyzeOnly(~,~)
        setBusy(true);
        try
            doAnalyze(fullfile(A.here,'single_f.mat'));
        catch e
            logf('✗ 分析出错：%s', e.message);
        end
        setBusy(false);
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
            logf('   1) 「输出设备」选错：接了蓝牙耳机时声音不走扬声器（当前选的是 %s）', A.odev.Value);
            logf('   2) 本机音量过低或静音；');
            logf('   3) 麦克风没接好 / 「ALSA 设备」card 号不对（见 Q&A Q2/Q4）。');
            logf('   先点「② 电平校准」，看 RMS 是否随放音跳起来。');
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

    function [st,out] = ssh(remoteCmd)
        [st,out] = system(sprintf('ssh -o BatchMode=yes -o ConnectTimeout=8 %s "%s"', ...
                                  A.host.Value, remoteCmd));
    end

    function bgssh(remoteCmd)
        c = sprintf('ssh -o BatchMode=yes %s "%s"', A.host.Value, remoteCmd);
        if ispc
            system(sprintf('start /b %s > NUL 2>&1', c));
        else
            system(sprintf('%s > /dev/null 2>&1 &', c));
        end
    end

    function ok = waitRemoteDone(procName, timeoutSec)
        t0 = tic;  ok = false;
        while toc(t0) < timeoutSec
            % 必须用 -x（精确匹配进程名）：-f 会匹配到承载 pgrep 的那条
            % ssh 命令行本身（里面就含进程名），导致永远判定为"还在跑"。
            [~,out] = ssh(sprintf('pgrep -x %s >/dev/null && echo RUN || echo DONE', procName));
            if contains(out,'DONE'), ok = true; return, end
            pause(0.5);
        end
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
