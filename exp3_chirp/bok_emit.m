%% 发射端：发送 baseband_images 下的任意 1-bit 图片，用 Up Chrip(miu=1)/Down Chrip(miu=-1) 表示二进制 0/1
%  改为按图片尺寸自适应组帧，可发送 ren128b/ren512b/lan336/lzu2048b 等任意图片。
% clc
% clear
%% 路径与图片选择（相对脚本自身定位，不依赖当前工作目录）%%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here,'baseband_images');
img_name = 'ren128b.bmp';          % ← 改这里即可切换图片(同目录其它 bmp)
%% 音频参数（对应发送模型） %%
fs=8000;
T=.1;

%% 发送图片转换成二进制数据流（自动读取宽高） %%
imdata = imread(fullfile(imgdir,img_name));   %输入图片(baseband_images/)
figure;                              % 显示发送图片
imshow(imdata);
title(['电脑发送图片: ' img_name])
data=double(imdata);
[NN,MM]=size(data);                  %NN=行(高)，MM=列(宽)，随图片自适应
info_all=zeros(1,NN*MM);
for m=1:MM
    for nn=1:NN
        info_all(1,(m-1)*NN+nn)=data(nn,m);   %列优先展开
    end
end
L=NN*MM;                             %图片比特数

%% 在 Simulink 中组帧与调制 %%
% GUI 使用同一个模型，不需要生成发送端 C 代码。
code=50+L+5;
save(fullfile(here,'info_all.mat'),'info_all');
LFM=chirp_modulate(info_all);

%% 产生声音 %%
fprintf('发送 %s  %dx%d=%d 位  符号数=%d  时长=%.1fs\n', img_name, MM, NN, L, code, code*T);
% 板上要先起采集再放音，采集窗口得盖过信号时长，这里直接把建议的 -t 算好
fprintf('板上先执行: ./build/chirp_rx -d plughw:X,0 -t %d\n', ceil(code*T)+6);
sound(real(LFM),fs)
