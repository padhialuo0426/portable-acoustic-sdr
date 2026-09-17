function gui()
%GUI  实验四 · V.22bis 声学 modem —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp4_v22bis/)后直接运行 gui
%
%   把手动流程串成一次点击：
%     板上启动 v22_rx 采集 → 宿主机扬声器播放 V.22bis 信号 → 等采集窗口跑完
%     → 取回 v22sym.mat → 判决/差分/解扰/HDLC → 显示 BER 与还原点阵
%
%   界面骨架、板上连接、同步编译、电平校准都在 common/matlab/+asdr 里，
%   四个实验共用；本文件只提供 V.22bis 特有的组帧/调制/解码。
%
%   与实验二/三的 gui.m 有一处结构差别：那两个能直接用
%   asdr.ImageUI.analyze（板上出的是 2×N 的标量判决流，解码就是扫 m 序列）；
%   本实验板上出的是 121×N 的复符号，解码走 HDLC，所以 analyze 自己写。
%   发图下拉、结果面板、点阵显示仍然复用 ImageUI。
%
%   注意：本界面是便利封装。教学正路仍是 v22_emit / v22_rev 两个脚本手动跑。
%   与前三个实验不同，本文件**不重复**组帧/调制/解码逻辑——那些已经抽成
%   v22_mod / v22_demod / v22_pack / v22_unpack 等函数，界面直接调用，
%   不存在"改帧结构要改两边"的问题。

    here = fileparts(mfilename('fullpath'));
    if isempty(here), here = pwd; end
    addpath(fullfile(here,'..','common','matlab'));   % +asdr 共用层

    P.imgdir = fullfile(here,'baseband_images');

    spec.title    = '实验四 · V.22bis 声学 modem —— 一键声学实测';
    spec.binary   = 'v22_rx';
    spec.outMat   = 'v22sym.mat';
    spec.fs       = 9600;                  % 本实验采样率，不是其它实验的 8000
    spec.showDuration = true;
    spec.buildParams  = @(app,gL,lab) buildParams(app, gL, lab, P);
    spec.buildResults = @(app,panel)  buildResults(app, panel);
    spec.durationText = @(app) durationText(app, P);
    spec.prepare      = @(app) prepare(app, P);
    spec.analyze      = @(app,f,meta) analyze(app, f, meta, P);
    asdr.App(spec, here);
end

%% ------------------------- 界面 -------------------------

function buildParams(app, gL, lab, P)
    asdr.ImageUI.buildParams(app, gL, lab, P.imgdir);   % 发送图片下拉
    lab('速率');
    app.ui.rate = uidropdown(gL, 'Items', {'2400 bps (16-QAM)','1200 bps (QPSK)'}, ...
                             'Value', '2400 bps (16-QAM)', ...
                             'ValueChangedFcn', @(~,~) app.refreshTiming());
    app.track(app.ui.rate);
end

function buildResults(app, panel)
    g = uigridlayout(panel, [2 3]);  g.RowHeight = {28,'1x'};
    app.ui.berTxt = uilabel(g,'Text','BER: —','FontSize',16,'FontWeight','bold');
    app.ui.berTxt.Layout.Column = [1 3];
    app.ui.axTx = uiaxes(g);  title(app.ui.axTx,'发送点阵');  axis(app.ui.axTx,'off');
    app.ui.axRx = uiaxes(g);  title(app.ui.axRx,'接收还原');  axis(app.ui.axRx,'off');
    % 星座图：16-QAM 解不出时，看一眼星座就知道是噪声、过载还是相位没锁
    app.ui.axC  = uiaxes(g);  title(app.ui.axC,'接收星座');  grid(app.ui.axC,'on');
end

function r = pickRate(app)
    if startsWith(app.ui.rate.Value,'1200'), r = 1200; else, r = 2400; end
end

%% ------------------------- V.22bis 特有部分 -------------------------

% 「信号时长」那一行。走 v22_pack 拿到精确帧长（组帧很便宜，没做调制），
% 再加上成形滤波拖尾——采集窗口 -t 是按这个数算的，宁可算准。
function [txt, dur] = durationText(app, P)
    Pm = v22_params(pickRate(app));
    [payload, NN, MM] = v22_img2payload(P.imgdir, app.ui.img.Value, Pm.bps);
    nbit = numel(v22_pack(payload));                % 含标志与位填充，精确值
    nsym = Pm.preambleSyms + ceil(nbit/Pm.bps) + Pm.postambleSyms;
    dur  = (nsym*Pm.sps + Pm.span*Pm.sps) / Pm.fs;  % 加成形滤波拖尾
    txt  = sprintf('%.2f s（%d 符号 / %d 位 / %d 字节载荷）', ...
                   dur, nsym, NN*MM, numel(payload));
end

% 组帧 + 调制。直接调用与脚本、仿真同一份实现。
function meta = prepare(app, P)
    name = app.ui.img.Value;
    Pm   = v22_params(pickRate(app));
    [payload, NN, MM] = v22_img2payload(P.imgdir, name, Pm.bps);
    x = v22_mod(v22_pack(payload), Pm);

    meta.x       = x / max(abs(x));
    meta.dur     = numel(x) / Pm.fs;
    meta.desc    = sprintf('%s  %dx%d=%d 位  %d bps', name, MM, NN, NN*MM, Pm.rate);
    meta.P       = Pm;
    meta.payload = payload;
    meta.NN = NN;  meta.MM = MM;
end

% 解码：读 v22sym.mat -> 判决/差分/解扰 -> HDLC -> BER + 点阵 + 星座
function analyze(app, matfile, meta, P)
    Pm = meta.P;
    if ~isfile(matfile)
        app.logStep('解码', '✗', '本地没有 %s，先做一次实测', app.spec.outMat); return
    end
    S = load(matfile);
    if ~isfield(S,'v22Sym')
        app.logStep('解码', '✗', '文件里没有 v22Sym 变量'); return
    end
    D = S.v22Sym;
    validateattributes(D, {'numeric'}, {'2d','nrows',121,'nonempty','real','finite'});
    nF = size(D,2);

    V   = D(2:end,:);
    sym = complex(zeros(1, nF*60));
    for k = 1:nF
        c = V(:,k).';
        sym((k-1)*60 + (1:60)) = c(1:2:end) + 1i*c(2:2:end);
    end
    if ~app.deadStreamOK(all(sym == 0)), return, end

    bits = symbolsToBits(sym, Pm);
    frames = v22_unpack(bits);
    good   = frames([frames.ok]);
    app.logStep('HDLC', '✓', '候选帧 %d 个，FCS 通过 %d 个', numel(frames), numel(good));

    img = [];
    for g = 1:numel(good)
        try, img = v22_payload2img(good(g).payload); break, catch, end
    end

    % 星座图先画——即使解不出帧，它也能说明问题出在哪
    act = sym(abs(sym) > 0.1*max(abs(sym)));
    plot(app.ui.axC, real(act), imag(act), '.', 'MarkerSize', 4);
    axis(app.ui.axC,'equal'); grid(app.ui.axC,'on');
    title(app.ui.axC, sprintf('接收星座 (%d 符号)', numel(act)));

    if isempty(img)
        app.ui.berTxt.Text = 'BER: 未解出帧';
        app.ui.berTxt.FontColor = [0.8 0 0];
        app.logStep('解码', '✗', '没有 FCS 通过的图片帧');
        app.logf('  看星座图：散成一团=信噪比不够；方块状但转动=相位没锁；');
        app.logf('  贴边饱和=过载（见 Q&A Q5）。弱信道可把「速率」换成 1200 bps');
        return
    end

    imRef = v22_payload2img(meta.payload);
    if isequal(size(img), size(imRef))
        nbad = sum(img(:) ~= imRef(:));
        L = numel(img);
        app.ui.berTxt.Text = sprintf('BER = %d/%d = %.4f', nbad, L, nbad/L);
        if nbad == 0
            app.ui.berTxt.FontColor = [0 0.5 0];
            app.logStep('BER', '✓', '0/%d，实验四通过', L);
        else
            app.ui.berTxt.FontColor = [0.8 0 0];
            app.logStep('BER', '△', '%.4f 有误码，检查电平/环境噪声', nbad/L);
        end
    end

    asdr.ImageUI.showBitmap(app.ui.axTx, imRef, '发送点阵');
    asdr.ImageUI.showBitmap(app.ui.axRx, img,   '接收还原');
end

% 判决 + 差分解码 + 自同步解扰（与 v22_rev.m 同一套逻辑）
function bits = symbolsToBits(sym, Pm)
    dec = zeros(1, numel(sym)*Pm.bps);  qp = 0;
    for k = 1:numel(sym)
        z = sym(k);
        if     real(z)>=0 && imag(z)>=0, qi = 0;
        elseif real(z)< 0 && imag(z)>=0, qi = 1;
        elseif real(z)< 0 && imag(z)< 0, qi = 2;
        else,                            qi = 3;
        end
        p1 = z * exp(-1i*90*qi*pi/180);
        [~, li] = min(abs(p1 - Pm.inQ));
        dq = mod(90*qi - qp, 360);  qp = 90*qi;
        hi = find(Pm.quadRot == dq, 1) - 1;
        if Pm.bps == 4
            dec((k-1)*4+(1:4)) = [bitget(hi,2) bitget(hi,1) bitget(li-1,2) bitget(li-1,1)];
        else
            dec((k-1)*2+(1:2)) = [bitget(hi,2) bitget(hi,1)];
        end
    end
    st = zeros(1, Pm.scrLen);  bits = zeros(size(dec));
    for i = 1:numel(dec)
        bits(i) = xor(dec(i), xor(st(Pm.scrTaps(1)), st(Pm.scrTaps(2))));
        st = [dec(i) st(1:end-1)];
    end
end
