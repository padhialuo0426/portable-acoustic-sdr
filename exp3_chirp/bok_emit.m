%% 实验三 · 纯 MATLAB 单文件发送机：BOK chirp 二值图片传输
%  图片 -> 首尾 m 序列组帧 -> 上/下扫频映射 -> 逐符号拼接音频。
%  本文件包含全部发送算法，只需一张二值图片，不依赖其他工程源码或模型。

%% 1. 图片与音频参数
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
img_name = 'ren128b.bmp';
imageFile = fullfile(here,'baseband_images',img_name);
fs = 8000;
fc = 1000;                       % 扫频起点，赫兹
T = 0.1;                         % 每符号时长，秒
B = 200;                         % 扫频范围，赫兹
N = round(fs*T);                 % 每符号 800 点
PLAY_AUDIO = true;
SHOW_FIGURE = true;
SAVE_REFERENCE = true;

% GUI/波形入口可直接提供图片比特；教学时直接运行，无需设置此结构。
if exist('sdrTxRequest','var')
    info_all = double(sdrTxRequest.imageBits(:).');
    PLAY_AUDIO = false;
    SHOW_FIGURE = false;
    SAVE_REFERENCE = false;
else
    imdata = imread(imageFile);
    assert(ismatrix(imdata) && all(imdata(:)==0 | imdata(:)==1), ...
        '发送图片必须为只含 0/1 的单通道二值 BMP。');
    [NN,MM] = size(imdata);
    info_all = double(imdata(:).'); % 按列展开图片
end
assert(~isempty(info_all) && all(info_all==0 | info_all==1),'图片比特必须为非空 0/1 序列。');
L = numel(info_all);

%% 2. 明确写出 15 位 m 序列，并组成信息帧
m_seq = [1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
% 10 位前导 | 10 位交替段 | m 序列 | L 位图片 | m 序列 | 5 位尾部保护
info = [zeros(1,10), repmat([1 0],1,5), m_seq, info_all, m_seq, zeros(1,5)];
code = numel(info);

%% 3. 每个符号生成上扫频或下扫频
% 保留原脚本包含符号末端的采样方式，两套实现必须使用相同的采样时刻。
t = linspace(0,T,N);
LFM = zeros(1,code*N);
for k = 1:code
    direction = 1-2*info(k);      % 0 -> +1，上扫；1 -> -1，下扫
    phase = 2*pi*fc*t + pi*direction*(B/T)*t.^2;
    LFM((k-1)*N+(1:N)) = real(exp(1i*phase));
end

%% 4. 保存发送真值、显示图片并播放
if SAVE_REFERENCE, save(fullfile(here,'info_all.mat'),'info_all'); end
if SHOW_FIGURE
    figure; imagesc(imdata,[0 1]); colormap(gray(2)); axis image off;
    title(['电脑发送图片: ' img_name]);
end
if PLAY_AUDIO
    fprintf('发送 %s  %dx%d=%d 位  符号数=%d  时长=%.1fs\n',img_name,MM,NN,L,code,code*T);
    fprintf('板上先执行: ./build/chirp_rx -d plughw:X,0 -t %d\n',ceil(code*T)+6);
    sound(LFM,fs);
end
clear sdrTxRequest
