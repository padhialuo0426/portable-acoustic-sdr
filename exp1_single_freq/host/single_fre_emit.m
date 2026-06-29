%% 实验一 · 发射端：PC 端 MATLAB 脚本，用 sound() 经扬声器播放单频信号
%  与实验二的 bok_emit.m 对称——发射端始终是 PC 脚本，不上板、不依赖硬件支持包。
%  接收端是板上的 single_fre_rev（../build/sdr_rx），采集→滤波→记录到 .mat。
% clc
% clear
%% 基本参数设置 %%
time=1;
fs=8000;                   % 采样率
t=0:1/fs:time;
fc=1000;                   % 载波频率

%% 单频 %%
A=1;
s=sin(2*pi*fc*t);
x=A.*s;

%% 两个单频叠加 %%
% A=1;
% B=1;
% s1=sin(2*pi*fc*t);
% s2=sin(2*pi*(fc+50)*t);
% x=A.*s1+B.*s2;

%% 两个单频前后发送 %%
% x=[A.*s1,B.*s2];

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
