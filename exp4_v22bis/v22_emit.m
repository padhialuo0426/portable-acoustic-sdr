%% 实验四 · 发射端：把一张 1-bit 图片用 V.22bis 发出去
%
%  链路：图片 -> HDLC 帧(含 CRC-16) -> 加扰 -> 差分四象限 -> RRC 成形
%        -> 1200Hz 载波 -> sound() 经扬声器播放
%
%  与实验二/三的发射脚本对照：那两个把图片直接当基带比特流发，靠两段 m
%  序列找帧头帧尾，解码端必须预先知道图片多大；本实验走真正的数据链路
%  协议——帧长写在帧里，HDLC 标志自带边界，解码端不需要知道图片尺寸。

% clc
% clear
%% 路径与参数 %%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here, 'baseband_images');
img_name = 'ren512b.bmp';     % ← 改这里即可切换图片(同目录其它 bmp)
RATE     = 2400;              % ← 2400(16-QAM) 或 1200(QPSK，弱信道用这档)
LEAD     = 1.0;               % 前置静默(秒)，给板上采集留启动余量
SAVE_RAW = true;              % 同时存 .raw/.wav，供 AUDIO=file 离线验证

P = v22_params(RATE);

%% 图片 -> 帧载荷 -> HDLC 帧 %%
[payload, NN, MM] = v22_img2payload(imgdir, img_name, P.bps);
frameBits = v22_pack(payload);

imdata = imread(fullfile(imgdir, img_name));
figure; imshow(imdata); title(['电脑发送图片: ' img_name])

%% 调制 %%
x = v22_mod(frameBits, P);
y = [zeros(1, round(LEAD*P.fs)), x, zeros(1, round(0.3*P.fs))];

%% 产生声音 %%
fprintf('发送 %s  %dx%d=%d 位  %dbps  载荷 %d 字节  帧 %d 比特\n', ...
        img_name, MM, NN, NN*MM, RATE, numel(payload), numel(frameBits));
fprintf('信号 %.2fs（前导 %d 符号 + 数据 + 后导 %d 符号），总长 %.2fs\n', ...
        numel(x)/P.fs, P.preambleSyms, P.postambleSyms, numel(y)/P.fs);
% 板上要先起采集再放音，采集窗口得盖过信号时长，这里直接把建议的 -t 算好
fprintf('板上先执行: ./build/v22_rx -d plughw:X,0 -t %d\n', ceil(numel(y)/P.fs)+4);

if SAVE_RAW
    pcm = int16(round(0.9 * x * 32767));
    f = fopen(fullfile(here,'v22_tx.raw'),'wb');  fwrite(f, pcm, 'int16');  fclose(f);
    audiowrite(fullfile(here,'v22_tx.wav'), double(pcm)/32768, P.fs);
    fprintf('已存 v22_tx.raw / v22_tx.wav（供 make AUDIO=file 离线验证）\n');
end

sound(0.9*y, P.fs)
