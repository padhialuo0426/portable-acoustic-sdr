%% 发射端：用 DPSK（差分相移键控）发送 baseband_images 下的任意 1-bit 图片
%  比特先差分编码成 ±1，经平方根升余弦成形后调制到 1kHz 载波，用 sound() 播放。
%  按图片尺寸自适应组帧，可发送 ren512b/da512b/lan512b/ru512b/yi512b/lzu2048b 等。
% clc
% clear
%% 路径与图片选择（相对脚本自身定位，不依赖当前工作目录）%%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here,'baseband_images');
img_name = 'ren512b.bmp';          % ← 改这里即可切换图片(同目录其它 bmp)

%% 音频参数（对应发送模型） %%
fs=8000;

%% 发送图片转换成二进制数据流（自动读取宽高）%%
imdata = imread(fullfile(imgdir,img_name));
figure;                            % 显示发送图片
imshow(imdata);
title(['电脑发送图片: ' img_name])
data = double(imdata);
[NN,MM] = size(data);              % NN=行(高)，MM=列(宽)，随图片自适应
info_all = zeros(1,NN*MM);
for m = 1:MM
    for n = 1:NN
        info_all(1,(m-1)*NN+n) = data(n,m);   % 列优先展开
    end
end
L = NN*MM;                         % 图片比特数

%% 在 Simulink 中组帧与调制 %%
% GUI 使用同一个模型，不需要生成发送端 C 代码。
code=56+L+80;
save(fullfile(here,'info_all.mat'),'info_all');
dpsk=dpsk_modulate(info_all);

%% 产生声音 %%
fprintf('发送 %s  %dx%d=%d 位  码元数=%d  时长=%.1fs\n', ...
        img_name, MM, NN, L, code, numel(dpsk)/fs);
% 板上要先起采集再放音，采集窗口得盖过信号时长，这里直接把建议的 -t 算好
fprintf('板上先执行: ./build/dpsk_rx -d plughw:X,0 -t %d\n', ceil(numel(dpsk)/fs)+6);
sound(dpsk, fs)
