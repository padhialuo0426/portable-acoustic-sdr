%% 发射端：发送 baseband_images 下的任意 1-bit 图片，用 Up Chrip(miu=1)/Down Chrip(miu=-1) 表示二进制 0/1
%  改为按图片尺寸自适应组帧，可发送 ren128b/ren512b/lan336/lzu2048b 等任意图片。
% clc
% clear
%% 路径与图片选择（相对脚本自身定位，不依赖当前工作目录）%%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here,'..','baseband_images');
img_name = 'ren128b.bmp';          % ← 改这里即可切换图片(同目录其它 bmp)
%% 基本参数设置　%%
fs=8000;                             %采样率
T=1e-1;                              %0.1
B=200;                               %信号高频带宽，BT>>1
k=B/T;                               %调频斜率
n=round(T*fs);                       %采样点个数，800
t=linspace(0,T,n);                   %0-T之间n等分
fc=1000;

%% 发送图片转换成二进制数据流（自动读取宽高） %%
imdata = imread(fullfile(imgdir,img_name));   %输入图片(../baseband_images/)
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

%% 组成数据帧（帧头/帧尾各 15 位 m 序列，间距 = L+15）%%
m_seq=[1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];  %15位m序列，用于帧同步
GUARD=5;                             %帧尾保护符号，补偿接收 1 符号时延、防 EOF 截断
code=50+L+GUARD;                     %总符号数
info=zeros(1,code);
info(1:10)=0;                           %用于信号检测
info(11:20)=[1 0 1 0 1 0 1 0 1 0];      %交替段
info(21:35)=m_seq;                      %帧头
info(36:35+L)=info_all;                 %图片信息序列
info(36+L:50+L)=m_seq;                  %帧尾
save(fullfile(here,'info_all.mat'),'info_all')   %存到脚本所在目录，供 bok_rev 算 BER

%% 信息与斜率miu进行映射 %%
miu=zeros(1,code);
for i=1:code                             %当发送码元0时，miu=1，为Up Chrip信号
    if info(i)==0
        miu(i)=1;
    else
        miu(i)=-1;                       %发送码元1时，miu=-1时，为Down Chrip信号
    end
end
LFM=[];

%% 线性调频信号产生 %%
for i=1:length(miu)
    lfm = exp(j*(2*pi*fc*t + pi*miu(i)*k*t.^2));     %线性调频信号
    LFM=[LFM,lfm];
end

%% 产生声音 %%
fprintf('发送 %s  %dx%d=%d 位  符号数=%d  时长=%.1fs\n', img_name, MM, NN, L, code, code*T);
sound(real(LFM),fs)
