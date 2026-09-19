%% 实验二 · 纯 MATLAB 单文件发送机：DPSK 二值图片传输
%  图片 -> 首尾 m 序列组帧 -> 差分编码 -> 插零 -> 成形 -> 载波调制。
%  本文件包含全部发送算法，只需一张二值图片，不依赖其他工程源码或模型。

%% 1. 图片与音频参数
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
img_name = 'ren512b.bmp';
imageFile = fullfile(here,'baseband_images',img_name);
fs = 8000;
fc = 1000;
fm = 100;                        % 每秒 100 个符号
N = fs/fm;                       % 每符号 80 点
beta = 0.5;                      % 成形滤波器滚降系数
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
    info_all = double(imdata(:).'); % MATLAB 按列展开，与接收端点阵顺序一致
end
assert(~isempty(info_all) && all(info_all==0 | info_all==1),'图片比特必须为非空 0/1 序列。');
L = numel(info_all);

%% 2. 明确写出 15 位 m 序列，并组成信息帧
m_seq = [1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
% 18 位前导 | 8 位交替段 | m 序列 | L 位图片 | m 序列 | 80 位尾部保护
info = [zeros(1,18), repmat([0 1],1,4), m_seq, info_all, m_seq, zeros(1,80)];
code = numel(info);

%% 3. 差分编码：输入 0 保持相位，输入 1 翻转相位
previous = 0;
symbols = zeros(1,code);
for k = 1:code
    previous = xor(previous,info(k));
    symbols(k) = 1-2*double(previous); % 绝对相位用 +1 / -1 表示
end

%% 4. 计算平方根升余弦成形滤波器
% 保留原脚本 160 抽头和采样位置，用 eps 处理公式的可去奇点。
z = (1:2*N)/N-1+eps;
t1 = cos((1+beta)*pi*z);
t2 = sin((1-beta)*pi*z);
t3 = 1./(4*beta*z);
h = (4*beta/(pi*sqrt(1/fm)))*(t1+t2.*t3)./(1-16*beta*beta*z.*z);

%% 5. 每个符号后插入 79 个零，再做卷积成形
upsampled = zeros(1,code*N);
upsampled(1:N:end) = symbols;
baseband = conv(upsampled,h);

%% 6. 调制到 1 kHz 载波，并按峰值归一化
n = 0:numel(baseband)-1;
dpsk = baseband.*sin(2*pi*fc*n/fs);
dpsk = dpsk/max(abs(dpsk));

%% 7. 保存发送真值、显示图片并播放
if SAVE_REFERENCE, save(fullfile(here,'info_all.mat'),'info_all'); end
if SHOW_FIGURE
    figure; imagesc(imdata,[0 1]); colormap(gray(2)); axis image off;
    title(['电脑发送图片: ' img_name]);
end
if PLAY_AUDIO
    fprintf('发送 %s  %dx%d=%d 位  码元数=%d  时长=%.1fs\n', ...
        img_name,MM,NN,L,code,numel(dpsk)/fs);
    fprintf('板上先执行: ./build/dpsk_rx -d plughw:X,0 -t %d\n',ceil(numel(dpsk)/fs)+6);
    sound(dpsk,fs);
end
clear sdrTxRequest
