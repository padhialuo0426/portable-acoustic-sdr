function gui()
%GUI  实验一 · 单频信号测试 —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp1_single_freq/host)后直接运行 gui
%
%   把「手把手部署运行教程」第 3 节的动作串成一次点击：
%     板上启动 sdr_rx 采集 → 宿主机扬声器播放单频正弦 → 等采集窗口跑完
%     → 取回 single_f.mat → FFT 找谱峰 → 与设定载波比对
%
%   界面骨架、板上连接、同步编译、电平校准都在 common/matlab/+asdr 里，
%   三个实验共用；本文件只提供单频特有的发波与频谱分析。
%
%   注意：本界面是便利封装。教学正路仍是 single_fre_emit / spectrum 两个脚本
%   手动跑（见 documents/手把手部署运行教程.md）。

    here = fileparts(mfilename('fullpath'));
    if isempty(here), here = pwd; end
    addpath(fullfile(here,'..','..','common','matlab'));   % +asdr 共用层

    P.fs = 8000;

    spec.title    = '实验一 · 单频信号 —— 一键声学实测';
    spec.binary   = 'sdr_rx';
    spec.outMat   = 'single_f.mat';
    spec.fs       = P.fs;
    spec.extraRemove = {'single_f2.mat'};
    spec.auxButton   = '仅分析已取回的 single_f.mat';
    spec.buildParams  = @(app,gL,lab) buildParams(app, gL, lab);
    spec.buildResults = @(app,panel)  buildResults(app, panel);
    spec.plainDuration = @(app) app.ui.dur.Value;   % 发射时长是输入项，不必另算
    spec.prepare      = @(app) prepare(app, P);
    spec.levelAudio   = @(app) makeTone(app, P, 4); % 校准固定放 4s 测试音
    spec.analyze      = @(app,f,meta) analyze(app, f, P);
    asdr.App(spec, here);
end

%% ------------------------- 单频特有部分 -------------------------

function buildParams(app, gL, lab)
    lab('载波 fc (Hz)');
    app.ui.fc  = uieditfield(gL,'numeric','Value',1000,'Limits',[50 3900]);
    lab('发射时长 (s)');
    app.ui.dur = uieditfield(gL,'numeric','Value',1,'Limits',[0.1 60], ...
                             'ValueChangedFcn',@(~,~)app.refreshTiming());
    app.track({app.ui.fc, app.ui.dur});
end

function buildResults(app, panel)
    g = uigridlayout(panel,[3 1]);  g.RowHeight = {28,'1x','1x'};
    app.ui.pkTxt = uilabel(g,'Text','频谱峰值: —','FontSize',16,'FontWeight','bold');
    app.ui.axT = uiaxes(g);  title(app.ui.axT,'时域波形');   xlabel(app.ui.axT,'时间 (s)');
    app.ui.axF = uiaxes(g);  title(app.ui.axF,'频谱 (FFT)'); xlabel(app.ui.axF,'频率 (Hz)');
end

function y = makeTone(app, P, sec)
    t = (0:round(sec*P.fs)-1)/P.fs;
    y = sin(2*pi*app.ui.fc.Value*t);
end

function meta = prepare(app, P)
    meta.dur  = app.ui.dur.Value;
    meta.x    = makeTone(app, P, meta.dur);
    meta.desc = sprintf('单频 %g Hz', app.ui.fc.Value);
end

% 与 spectrum.m 等价：81×N 去掉时间行、逐列拼长向量、去直流、FFT 找正频峰
function analyze(app, matfile, P)
    if ~isfile(matfile)
        app.logStep('分析', '✗', '本地没有 single_f.mat，先做一次实测'); return
    end
    S = load(matfile);
    if ~isfield(S,'toFileData')
        app.logStep('分析', '✗', '文件里没有 toFileData 变量'); return
    end
    X = S.toFileData;
    if size(X,1) == 81, X = X(2:end,:); end     % 第 1 行是时间戳
    if ~isnumeric(X) || ~isreal(X) || any(~isfinite(X(:)))
        error('采样数据必须为有限实数。');
    end
    y = X(:);
    N = numel(y);
    if N < 3, app.logStep('分析', '✗', '采样点不足'); return, end
    if ~app.deadStreamOK(max(abs(y)) < 1e-9), return, end
    y = y - mean(y);

    Y  = fft(y);
    f  = (-floor(N/2):ceil(N/2)-1)*(P.fs/N);
    Ys = fftshift(abs(Y))/N;
    pos = f > 0;  fpos = f(pos);  Ypos = Ys(pos);
    [pk, idx] = max(Ypos);
    fpeak = fpos(idx);

    plot(app.ui.axT, (0:N-1)/P.fs, y);  grid(app.ui.axT,'on');
    title(app.ui.axT,'时域波形');  xlabel(app.ui.axT,'时间 (s)');  ylabel(app.ui.axT,'幅度');

    plot(app.ui.axF, f, Ys);  grid(app.ui.axF,'on');  xlim(app.ui.axF,[0 P.fs/2]);
    hold(app.ui.axF,'on');
    plot(app.ui.axF, fpeak, pk, 'rv', 'MarkerFaceColor','r');
    text(app.ui.axF, fpeak, pk, sprintf('  %.1f Hz', fpeak), 'Color','r');
    hold(app.ui.axF,'off');
    title(app.ui.axF,'频谱 (FFT)');  xlabel(app.ui.axF,'频率 (Hz)');  ylabel(app.ui.axF,'|Y|');

    fc  = app.ui.fc.Value;
    err = abs(fpeak - fc);
    app.ui.pkTxt.Text = sprintf('频谱峰值 = %.1f Hz（设定 %g Hz，偏差 %.1f Hz）', fpeak, fc, err);
    if err <= 10
        app.ui.pkTxt.FontColor = [0 0.5 0];
        app.logStep('频谱峰值', '✓', '%.1f Hz，实验一通过', fpeak);
    else
        app.ui.pkTxt.FontColor = [0.8 0 0];
        app.logStep('频谱峰值', '△', '%.1f Hz 偏离设定 %g Hz，检查电平/噪声/采样率', fpeak, fc);
    end
end
