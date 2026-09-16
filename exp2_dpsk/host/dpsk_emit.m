%% 发射端：用 DPSK（差分相移键控）发送 baseband_images 下的任意 1-bit 图片
%  比特先差分编码成 ±1，经平方根升余弦成形后调制到 1kHz 载波，用 sound() 播放。
%  按图片尺寸自适应组帧，可发送 ren512b/da512b/lan512b/ru512b/yi512b/lzu2048b 等。
% clc
% clear
%% 路径与图片选择（相对脚本自身定位，不依赖当前工作目录）%%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here,'..','baseband_images');
img_name = 'ren512b.bmp';          % ← 改这里即可切换图片(同目录其它 bmp)

%% 基本参数设置 %%
fs = 8000;                         % 采样率
fm = 100;                          % 码元速率
fc = 1000;                         % 载波频率
N  = fs/fm;                        % 每码元采样点数 = 80
T  = 1/fm;                         % 码元时间

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

%% 组成数据帧（帧头/帧尾各 15 位 m 序列，间距 = L+15）%%
m_seq = [1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
GUARD = 80;                        % 帧尾保护码元：必须盖过接收模型的流水延迟
                                   % （匹配滤波后延迟 3200 点 = 40 码元），
                                   % 否则帧尾 m 序列还没流出管线信号就结束了
code = 56 + L + GUARD;             % 总码元数
info = zeros(1,code);
info(1:18)        = 0;                          % 静默/信号检测
info(19:26)       = [0 1 0 1 0 1 0 1];          % 交替段
info(27:41)       = m_seq;                      % 帧头
info(42:41+L)     = info_all;                   % 图片信息序列
info(42+L:56+L)   = m_seq;                      % 帧尾
save(fullfile(here,'info_all.mat'),'info_all')  % 供 dpsk_rev 算 BER

%% 差分编码：与参考相位相同 -> +1，不同 -> -1 %%
temp = zeros(1,code+1);            % 参考相位为 0
ds   = zeros(1,code);
for i = 1:code
    if info(i) == temp(i)
        temp(i+1) = 0;  ds(i) =  1;
    else
        temp(i+1) = 1;  ds(i) = -1;
    end
end
st1 = upsample(ds, N);             % 上采样

%% 平方根升余弦成形 %%
k = N;  m = 1;  beta = 0.5;
n = 1:2*m*k;
z = (n/k) - m + eps;               % 加 eps 避开 0/0 的可去奇点
t1 = cos((1+beta)*pi*z);
t2 = sin((1-beta)*pi*z);
t3 = 1./(4*beta*z);
den = 1 - 16*beta*beta*z.*z;
num = t1 + t2.*t3;
c  = 4*beta/(pi*sqrt(T));
h1 = c*num./den;                   % 成形滤波器
dpsk_sqrc = conv(st1, h1);

%% DPSK 调制 %%
idx  = 0:numel(dpsk_sqrc)-1;
dpsk = dpsk_sqrc .* sin(2*pi*fc*idx/fs);
dpsk = dpsk / max(abs(dpsk));      % 归一化，避免 sound() 削顶

%% 产生声音 %%
fprintf('发送 %s  %dx%d=%d 位  码元数=%d  时长=%.1fs\n', ...
        img_name, MM, NN, L, code, numel(dpsk)/fs);
% 板上要先起采集再放音，采集窗口得盖过信号时长，这里直接把建议的 -t 算好
fprintf('板上先执行: ./build/dpsk_rx -d plughw:X,0 -t %d\n', ceil(numel(dpsk)/fs)+6);
sound(dpsk, fs)
