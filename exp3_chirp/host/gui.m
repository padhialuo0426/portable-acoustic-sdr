function gui()
%GUI  实验三 · 线性调频(chirp)扩频 —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp3_chirp/host)后直接运行 gui
%
%   把「手把手部署运行教程」第 5 节的动作串成一次点击：
%     板上启动 chirp_rx 采集 → 宿主机扬声器播放 chirp 信号 → 等采集窗口跑完
%     → 取回 chirp5.mat → 帧同步/判决/算 BER → 显示还原点阵
%
%   时序不必掐秒表：板上程序从启动到真正开始采集的死区实测只有 70~175ms，
%   而帧同步是在整条判决流里扫 m 序列、不要求对齐——只要信号完整落在采集
%   窗口内就能解。默认 1s 前导 + 2s 尾部余量足够。
%
%   界面骨架、板上连接、同步编译、电平校准都在 common/matlab/+asdr 里，
%   三个实验共用；本文件只提供 chirp 特有的组帧/调制/解码。
%
%   注意：本界面是便利封装。教学正路仍是 bok_emit / bok_rev 两个脚本手动跑
%   （见 documents/手把手部署运行教程.md）。为了让那两个脚本保持可独立通读，
%   本文件自带了等价的组帧/解码逻辑，没有把它们重构成函数——**改帧结构时
%   两边都要改**。

    here = fileparts(mfilename('fullpath'));
    if isempty(here), here = pwd; end
    addpath(fullfile(here,'..','..','common','matlab'));   % +asdr 共用层

    P.fs = 8000;               % 采样率
    P.T  = 0.1;                % 符号时间
    P.B  = 200;                % 扫频带宽
    P.fc = 1000;               % 中心频率
    P.n  = 800;                % 每符号采样点数 = fs*T
    P.mseq  = [1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
    P.GUARD = 5;               % 补偿接收 1 符号时延、防 EOF 截断
    P.imgdir = fullfile(here,'..','baseband_images');

    spec.title    = '实验三 · chirp 扩频 —— 一键声学实测';
    spec.binary   = 'chirp_rx';
    spec.outMat   = 'chirp5.mat';
    spec.fs       = P.fs;
    spec.showDuration = true;
    spec.buildParams  = @(app,gL,lab) asdr.ImageUI.buildParams(app, gL, lab, P.imgdir);
    spec.buildResults = @(app,panel)  asdr.ImageUI.buildResults(app, panel);
    spec.durationText = @(app) durationText(app, P);
    spec.prepare      = @(app) prepare(app, P);
    spec.analyze      = @(app,f,meta) asdr.ImageUI.analyze(app, f, meta, P.imgdir, ...
                                          '实验三', @decodeStream);
    asdr.App(spec, here);
end

%% ------------------------- chirp 特有部分 -------------------------

% 「信号时长」那一行。只看图片尺寸，不真的算波形——改下拉时要即时刷新。
function [txt, dur] = durationText(app, P)
    inf_ = imfinfo(fullfile(P.imgdir, app.ui.img.Value));
    L    = inf_.Width * inf_.Height;
    code = 50 + L + P.GUARD;
    dur  = code * P.T;
    txt  = sprintf('%.1f s（%d 符号 / %d 位）', dur, code, L);
end

% 组帧 + BOK chirp 调制（与 bok_emit.m 等价，但不放音、不写 info_all.mat）
function meta = prepare(app, P)
    name = app.ui.img.Value;
    [info_all, NN, MM] = asdr.ImageUI.readBits(P.imgdir, name);
    L    = NN*MM;
    code = 50 + L + P.GUARD;
    info = zeros(1, code);
    info(1:10)      = 0;                          % 信号检测前导
    info(11:20)     = [1 0 1 0 1 0 1 0 1 0];      % 交替段
    info(21:35)     = P.mseq;                     % 帧头
    info(36:35+L)   = info_all;                   % 图片信息
    info(36+L:50+L) = P.mseq;                     % 帧尾
    % 其余为 GUARD 个 0：补偿接收 1 符号时延、防 EOF 截断

    t = linspace(0, P.T, P.n);
    k = P.B / P.T;
    miu = ones(1, code);  miu(info == 1) = -1;    % 码元0->上扫, 1->下扫
    x = zeros(1, code*P.n);
    for i = 1:code
        x((i-1)*P.n+1 : i*P.n) = real(exp(1i*(2*pi*P.fc*t + pi*miu(i)*k*t.^2)));
    end

    meta.x        = x;
    meta.dur      = code * P.T;
    meta.desc     = sprintf('%s  %dx%d=%d 位', name, MM, NN, L);
    meta.info_all = info_all;
    meta.NN = NN;  meta.MM = MM;
end

% 帧同步 + 硬判决（与 bok_rev.m 等价；另外把 flag=-1 的极性反转也试一遍）
function [ber, bmp, l1, l2, flag] = decodeStream(xs, info_all, NN, MM)
    pm = [-1;1;1;-1;-1;1;-1;1;-1;-1;-1;-1;1;1;1];
    % 模型输出的判决值本身就是 ±1，门限直接比 1 即可
    corrOK = @(x,p,fl) x(p:p+14)*fl*pm > sum(abs(x(p:p+10))) && abs(x(p)) == 1;
    [ber, bmp, l1, l2, flag] = asdr.ImageUI.syncAndDecide(xs, info_all, NN, MM, corrOK);
end
