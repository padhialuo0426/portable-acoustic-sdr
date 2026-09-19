function gui()
%GUI  实验二 · DPSK 差分相移键控 —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp2_dpsk/)后直接运行 gui
%
%   把《构建与部署》中实验二的手动流程串成一次点击：
%     板上启动 dpsk_rx 采集 → 宿主机扬声器播放 DPSK 信号 → 等采集窗口跑完
%     → 取回 dpsk5.mat → 帧同步/判决/算 BER → 显示还原点阵
%
%   时序不必掐秒表：板上程序从启动到真正开始采集的死区实测只有 70~175ms，
%   而帧同步是在整条判决流里扫 m 序列、不要求对齐——只要信号完整落在采集
%   窗口内就能解。默认 1s 前导 + 2s 尾部余量足够。
%
%   界面骨架、板上连接、同步编译、电平校准都在 common/matlab/+asdr 里，
%   五个实验共用；本文件只提供 DPSK 特有的组帧/调制/解码。
%
%   注意：本界面是便利封装。教学正路仍是 dpsk_emit / dpsk_rev 两个脚本手动跑
%   （见 documents/构建与部署.md）。GUI 可选择 MATLAB 脚本或 Simulink 模型发送。

    here = fileparts(mfilename('fullpath'));
    if isempty(here), here = pwd; end
    addpath(fullfile(here,'..','common','matlab'));   % +asdr 共用层

    P.fs   = 8000;             % 采样率
    P.N    = 80;               % 发送模型每码元采样点数
    P.GUARD = 80;              % 帧尾保护码元：盖过模型 40 码元的流水延迟
    P.imgdir = fullfile(here,'baseband_images');

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
    x = dpsk_modulate(info_all,app.ui.txBackend.Value);

    meta.x        = x;
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
