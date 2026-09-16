function gui()
%GUI  实验二 · DPSK 差分相移键控 —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp2_dpsk/host)后直接运行 gui
%
%   把「手把手部署运行教程」第 4 节的动作串成一次点击：
%     板上启动 dpsk_rx 采集 → 宿主机扬声器播放 DPSK 信号 → 等采集窗口跑完
%     → 取回 dpsk5.mat → 帧同步/判决/算 BER → 显示还原点阵
%
%   时序不必掐秒表：板上程序从启动到真正开始采集的死区实测只有 70~175ms，
%   而帧同步是在整条判决流里扫 m 序列、不要求对齐——只要信号完整落在采集
%   窗口内就能解。默认 1s 前导 + 2s 尾部余量足够。
%
%   界面骨架、板上连接、同步编译、电平校准都在 common/matlab/+asdr 里，
%   三个实验共用；本文件只提供 DPSK 特有的组帧/调制/解码。
%
%   注意：本界面是便利封装。教学正路仍是 dpsk_emit / dpsk_rev 两个脚本手动跑
%   （见 documents/手把手部署运行教程.md）。为了让那两个脚本保持可独立通读，
%   本文件自带了等价的组帧/解码逻辑，没有把它们重构成函数——**改帧结构时
%   两边都要改**。

    here = fileparts(mfilename('fullpath'));
    if isempty(here), here = pwd; end
    addpath(fullfile(here,'..','..','common','matlab'));   % +asdr 共用层

    P.fs   = 8000;             % 采样率
    P.fm   = 100;              % 码元速率
    P.fc   = 1000;             % 载波
    P.N    = P.fs/P.fm;        % 每码元采样点数 = 80
    P.T    = 1/P.fm;           % 码元时间
    P.beta = 0.5;              % 成形滤波滚降系数
    P.mseq  = [1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
    P.GUARD = 80;              % 帧尾保护码元：盖过模型 40 码元的流水延迟
    P.imgdir = fullfile(here,'..','baseband_images');

    spec.title    = '实验二 · DPSK —— 一键声学实测';
    spec.binary   = 'dpsk_rx';
    spec.outMat   = 'dpsk5.mat';
    spec.fs       = P.fs;
    spec.showDuration = true;
    spec.buildParams  = @(app,gL,lab) asdr.ImageUI.buildParams(app, gL, lab, P.imgdir);
    spec.buildResults = @(app,panel)  asdr.ImageUI.buildResults(app, panel);
    spec.durationText = @(app) durationText(app, P);
    spec.prepare      = @(app) prepare(app, P);
    spec.analyze      = @(app,f,meta) asdr.ImageUI.analyze(app, f, meta, P.imgdir, ...
                                          '实验二', @decodeStream);
    asdr.App(spec, here);
end

%% ------------------------- DPSK 特有部分 -------------------------

% 「信号时长」那一行。只看图片尺寸，不真的算波形——改下拉时要即时刷新。
function [txt, dur] = durationText(app, P)
    inf_ = imfinfo(fullfile(P.imgdir, app.ui.img.Value));
    L    = inf_.Width * inf_.Height;
    code = 56 + L + P.GUARD;
    dur  = (code*P.N + 2*P.N - 1) / P.fs;     % 含成形滤波器拖尾
    txt  = sprintf('%.1f s（%d 码元 / %d 位）', dur, code, L);
end

% 组帧 + DPSK 调制（与 dpsk_emit.m 等价，但不放音、不写 info_all.mat）
function meta = prepare(app, P)
    name = app.ui.img.Value;
    [info_all, NN, MM] = asdr.ImageUI.readBits(P.imgdir, name);
    L    = NN*MM;
    code = 56 + L + P.GUARD;
    info = zeros(1, code);
    info(1:18)      = 0;                          % 静默/信号检测
    info(19:26)     = [0 1 0 1 0 1 0 1];          % 交替段
    info(27:41)     = P.mseq;                     % 帧头
    info(42:41+L)   = info_all;                   % 图片信息
    info(42+L:56+L) = P.mseq;                     % 帧尾
    % 其余为 GUARD 个 0：盖过接收模型 40 码元的流水延迟，否则帧尾
    % m 序列还没流出管线信号就结束了

    % 差分编码：与参考相位相同 -> +1，不同 -> -1
    temp = zeros(1, code+1);  ds = zeros(1, code);
    for i = 1:code
        if info(i) == temp(i)
            temp(i+1) = 0;  ds(i) =  1;
        else
            temp(i+1) = 1;  ds(i) = -1;
        end
    end

    % 平方根升余弦成形（z 加 eps 避开 0/0 的可去奇点）
    k = P.N;  md = 1;  b = P.beta;
    n = 1:2*md*k;
    z = (n/k) - md + eps;
    num = cos((1+b)*pi*z) + sin((1-b)*pi*z) .* (1./(4*b*z));
    den = 1 - 16*b*b*z.*z;
    h1  = (4*b/(pi*sqrt(P.T))) * num ./ den;

    % conv(upsample(ds,N), h1) 后调制到载波
    sq  = conv(upsample(ds, P.N), h1);
    idx = 0:numel(sq)-1;
    x   = sq .* sin(2*pi*P.fc*idx/P.fs);

    meta.x        = x / max(abs(x));
    meta.dur      = numel(x) / P.fs;
    meta.desc     = sprintf('%s  %dx%d=%d 位', name, MM, NN, L);
    meta.info_all = info_all;
    meta.NN = NN;  meta.MM = MM;
end

% 帧同步 + 判决（与 dpsk_rev.m 等价；另外把 flag=-1 的极性反转也试一遍）
function [ber, bmp, l1, l2, flag] = decodeStream(xs, info_all, NN, MM)
    pm = [-1;1;1;-1;-1;1;-1;1;-1;-1;-1;-1;1;1;1];
    % 判决值是相关幅度（量级可达 1e6），不是 ±1，门限按整段峰值自适应
    thr = max(abs(xs)) * 0.02;
    corrOK = @(x,p,fl) x(p:p+14)*fl*pm > sum(abs(x(p:p+11))) && abs(x(p)) > thr;
    [ber, bmp, l1, l2, flag] = asdr.ImageUI.syncAndDecide(xs, info_all, NN, MM, corrOK);
end
