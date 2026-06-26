%线性调频信号的BOK调制，采用Chrip信号的斜率正负传输二进制信息0、1
%（纯 MATLAB 端到端仿真：512位 ren512b.bmp，发射→信道→接收→还原，无硬件）
clc
clear
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir = fullfile(here,'..','baseband_images');
%% 基本参数设置 %%
fs=8000;                        %采样率
T=1e-1;                         %0.1s 
B=200;                          %信号高频带宽，BT>>1
k=B/T;                          %调频斜率     
n=round(T*fs);                  %采样点个数，800 
t=linspace(0,T,n);              %生成0-T之间的n个行向量
fc=1000;
code=560;
info=round(rand(1,code));
info(1:10)=0;                    %令前10为0000，前导码，用于信号检测

%% 发送图片转换成二进制数据流 %%
imdata = imread(fullfile(imgdir,'ren512b.bmp')); %图片(../baseband_images/)
figure;                         %显示发送图片  
imshow(imdata);
title('发送图片')
data=double(imdata);            %将图片数据存为double型数据
NN=16;                           %根据图片数据大小定义
MM=32;
for m=1:MM
    for n=1:NN
        info_all(1,(m-1)*NN+n)=data(n,m);
    end
end

%% 组成数据帧 %%
m_seq=[1 0 0 1 1 0 1 0 1 1 1 1 0 0 0]; %m序列，用于帧同步
info(11:25)=m_seq;                     %帧头
info(26:537)=info_all;                 %图片信息
info(538:552)=m_seq;                   %帧尾

%% 信息与斜率miu进行映射 %%
miu=zeros(1,code);
for i=1:code
    if info(i)==0
        miu(i)=1;                        %miu=1时，为Up Chrip信号；miu=-1时，为Down Chrip信号
    else
        miu(i)=-1;
    end
end
LFM=[];

%% chrip信号产生 %%
for i=1:length(miu)
    lfm = exp(j*(2*pi*fc*t + pi*miu(i)*k*t.^2));     %线性调频信号复数表达式
    LFM=[LFM,lfm];
end
% sound(real(LFM),fs);                                 %产生声音
% figure;
% plot(real(LFM));                                     %发送出去的声音是实信号

%% 加入高斯噪声 (miu，sigma^2) %%
snr=20;
sigma=1/(10^(snr/10));
noise=sqrt(sigma)*randn(1,length(t)*code);
LFM_noise=real(LFM)+noise;

%% 带通滤波
[b,a]=butter(4,[800 1200]/(fs/2));
LFM_bandpass=filter(b,a,LFM_noise);
% figure;
% plot(LFM_bandpass)

 %% 低通滤波器 %%
% [b,a]=butter(4,3000/(fs/2));                         %归一化截止频率fc/(fs/2)
% LFM_bandpass=filter(b,a,LFM_noise);
% figure;
% plot(LFM_bandpass)

%% 匹配滤波 %%
fs=8000;
T=1e-1;
B=200;                                               %信号高频带宽，BT>>1
k=B/T;                                               %调频斜率
n=round(T*fs);                                       %采样点个数
t=linspace(0,T,n);
fc=1000;
miu=1;                                               %miu为1的chrip信号
LFM2 = exp(j*(2*pi*fc*t + pi*miu*k*t.^2));           %线性调频信号复数表达式
si=LFM2;                                             %取chrip信号实部
ht=conj(fliplr(si));                                 %时域上的匹配滤波：ht=Ks(t0-t),系统冲击响应
% ht=fliplr(si);
s1=conv(LFM_bandpass,ht);                            %卷积   
u1=real(s1);

miu=-1;                                              % miu为-1的chrip信号
LFM3 = exp(j*(2*pi*fc*t + pi*miu*k*t.^2));           %线性调频信号复数表达式
si=LFM3;
ht=conj(fliplr(si));
% ht=fliplr(si);
s2=conv(LFM_bandpass,ht);
u2=real(s2);
figure;
plot(u1);
hold on
plot(u2);

% %加入延迟，解决信号检测问题，模拟真实通信中未知信号到达时刻的场景
%% 信号检测 %%
%在simulink程序中通过判定信号功率>噪声功率找出信号抽样判决位置
delay=zeros(1,fs*T);              %延迟
y11=[u1,delay,delay];             %未延迟的信号，与y12、y13保持数据长度一致
y12=[delay,u1,delay];             %延迟一个delay的信号
y13=[delay,delay,u1];             %延迟两个delay的信号
yy1=y11+y12+y13;
% figure;
% plot(yy1,'g');
% hold on;
% plot(yy2,'b');
for n=1:length(yy1)                                 %抽样
    if (yy1(n)>300 && yy1(n+fs*T)>600 && yy1(n+2*fs*T)>900)%根据画yy1的图确定数值
        [e f]=max(yy1(n-fs*T/2:n+fs*T/2-1));        %找一个符号的采样点里的最大值索引
        position=f+n-fs*T/2-1;                      %第一个开始抽样的地方                          
        break;
    end     
end
pos=[];
for n=position:fs*T:length(u1)                      %判决
    if abs(u1(n)) > abs(u2(n))
        y2=single(1);
    elseif abs(u2(n)) > abs(u1(n))
        y2=single(-1);
    else
        y2=single(0);
    end
    pos=[pos,y2];
end

x=pos;
%% 寻找帧开始符和结束符的位置 %% 
loc=[]; 
flag=1;
for n=1:length(x)-14
    if x(n:n+14)*(flag)*[-1;1;1;-1;-1;1;-1;1;-1;-1;-1;-1;1;1;1] > sum(abs(x(n:n+10))) && abs(x(n))==1
        loc=[loc,n];
    end
end
for n=1:length(loc)-1
    for m=n+1:length(loc)
        if (loc(m)-loc(n))==537                    %图片信息长度512，m序列长度15，故537
            loc2=loc(m);
            loc1=loc(n);
            break
        else
            loc2=loc(2);
            loc1=loc(1);
        end
    end
    if (loc(m)-loc(n))==537
        loc2=loc(m);
        loc1=loc(n);
        break
    else
        loc2=loc(2);
        loc1=loc(1);
    end
end

%% 判决，统计BER %%
output=x(loc1+15:loc2-1);
ber1=0;
loc_error1=[];
for i=1:length(output)
    if output(i)>0                               %与发射端对应，miu=1，为码元0；miu=-1时，为码元1
        info_decode(i)=0;
    else
        info_decode(i)=1;
    end
    if info_decode(i)~=info_all(i)
        ber1=ber1+1;
        loc_error1= [loc_error1,i];
    end
end
BER=ber1/length(info_decode)

%% 恢复图片 %%
NN=16;
MM=32;
for m=1:MM
    for n=1:NN
        bmp_figure(n,m)=info_decode(1,(m-1)*NN+n);
    end
end
figure;
imshow(logical(bmp_figure));
title('接收图片')