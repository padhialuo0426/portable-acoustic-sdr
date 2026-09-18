%% 实验一 · 发射端：PC 端 MATLAB 脚本，用 sound() 经扬声器播放单频信号
%  默认纯 MATLAB；TX_BACKEND 改为 'simulink' 可仿真发送模型，无需生成发送 C。
%  接收端是板上的 single_fre_rev（build/sdr_rx），采集→滤波→记录到 .mat。
% clc
% clear
%% 基本参数设置 %%
time=1;
fs=8000;                   % 采样率
t=0:1/fs:time;
fc=1000;                   % 载波频率
TX_BACKEND='matlab';        % 'matlab' 或 'simulink'

%% 单频 %%
A=1;
x=single_fre_modulate(fc,numel(t),A,TX_BACKEND);

%% 产生声音信号 %%
sound(x, fs)

figure;
plot(x);
title('发送端的发送信号')

% X_fft=fft(x(1:8000));      % 快速傅里叶变换
% nn=length(X_fft);
% f=(-nn/2:nn/2-1)*(fs/nn);
% X_shift= fftshift(X_fft);
% figure;
% plot(f,abs(X_shift))
