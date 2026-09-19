%% 实验一 · 纯 MATLAB 单文件发送机：单频正弦信号
%  直接运行本文件即可播放；不需要模型、建模脚本或工程内的辅助函数。
%  教学时依次阅读参数、采样、正弦公式和播放四步。

%% 1. 参数
fs = 8000;                       % 采样率，赫兹
fc = 1000;                       % 载波频率，赫兹
time = 1;                        % 时长，秒（保留原脚本的末端采样点）
A = 1;                           % 正弦幅度
PLAY_AUDIO = true;
SHOW_FIGURE = true;
samples = round(time*fs)+1;

% GUI 的 MATLAB 分支只传参数、取波形；直接运行时不需要此结构。
if exist('sdrTxRequest','var')
    fc = sdrTxRequest.fc;
    samples = sdrTxRequest.samples;
    A = sdrTxRequest.amplitude;
    PLAY_AUDIO = false;
    SHOW_FIGURE = false;
end
validateattributes(fc,{'numeric'},{'scalar','real','finite','positive','<',fs/2});
validateattributes(samples,{'numeric'},{'scalar','integer','positive'});
validateattributes(A,{'numeric'},{'scalar','real','finite'});

%% 2. 离散采样时刻
n = 0:samples-1;
t = n/fs;

%% 3. 正弦调制：x[n] = A sin(2*pi*fc*n/fs)
x = A*sin(2*pi*fc*n/fs);

%% 4. 播放与显示
if PLAY_AUDIO, sound(x,fs); end
if SHOW_FIGURE
    figure;
    plot(t,x);
    xlabel('时间（秒）'); ylabel('幅度'); title('发送端的单频信号');
end
clear sdrTxRequest
