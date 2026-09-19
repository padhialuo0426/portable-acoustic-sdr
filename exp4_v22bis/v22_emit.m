%% 实验四 · 纯 MATLAB 单文件发送机：V.22bis 风格的图片传输
%  图片 -> 载荷 -> FCS 与 HDLC -> 首尾 m 序列 -> 扰码 -> 差分映射
%       -> 插零与 RRC 成形 -> 1200 Hz 载波 -> 播放。
%  全部发送算法都在本文件中，不调用工程辅助函数、模型或建模脚本。

%% 1. 图片、速率和播放参数
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
img_name = 'ren512b.bmp';
imageFile = fullfile(here,'baseband_images',img_name);
RATE = 2400;                      % 2400：16-QAM；1200：QPSK
LEAD = 1.0;                       % 播放前的静默，秒
AMPLITUDE = 0.9;
SAVE_RAW = true;
PLAY_AUDIO = true;
SHOW_FIGURE = true;

% GUI 可提供图片或已组帧的比特，只取波形，不播放、不写文件。
if exist('sdrTxRequest','var')
    if isfield(sdrTxRequest,'rate'), RATE = sdrTxRequest.rate; end
    if isfield(sdrTxRequest,'imageFile'), imageFile = sdrTxRequest.imageFile; end
    SAVE_RAW = false;
    PLAY_AUDIO = false;
    SHOW_FIGURE = false;
end

%% 2. 发送端独立参数与完整 127 位 m 序列
P.rate = RATE;
P.fs = 9600;
P.Rs = 600;
P.sps = 16;
P.fc = 1200;
P.beta = 0.75;
P.span = 8;
P.quadRot = [90 0 180 270];       % 00/01/10/11 对应的相对象限旋转
P.scrTaps = [14 17];
P.scrLen = 17;
P.preambleSyms = 300;
P.postambleSyms = 120;
P.syncGuard = 17;
P.syncMaxErrors = 25;             % 接收测量用的每段同步容错上限
switch RATE
    case 2400
        P.bps = 4;
        P.inQ = [1+1i 3+1i 1+3i 3+3i];
    case 1200
        P.bps = 2;
        P.inQ = (1+1i)/sqrt(2);
    otherwise
        error('RATE 只能是 2400 或 1200。');
end
% x^7+x^3+1，初始 7 位全 1；递推 b(n+7)=b(n+3) xor b(n)。
% 以下是完整的一个周期；不是扰码器输出，也不是 HDLC 的 0x7E 标志。
m_seq = [ ...
    1 1 1 1 1 1 1 0 0 0 0 1 1 1 0 1 ...
    1 1 1 0 0 1 0 1 1 0 0 1 0 0 1 0 ...
    0 0 0 0 0 1 0 0 0 1 0 0 1 1 0 0 ...
    0 1 0 1 1 1 0 1 0 1 1 0 1 1 0 0 ...
    0 0 0 1 1 0 0 1 1 0 1 0 1 0 0 1 ...
    1 1 0 0 1 1 1 1 0 1 1 0 1 0 0 0 ...
    0 1 0 1 0 1 0 1 1 1 1 1 0 1 0 0 ...
    1 0 1 0 0 0 1 1 0 1 1 1 0 0 0];
P.syncBits = m_seq;
% 波形入口传入参数时，用同一组协议参数比较两种实现。
if exist('sdrTxRequest','var') && isfield(sdrTxRequest,'P')
    P = sdrTxRequest.P;
end

%% 3. 二值图片按列展开，每 8 位打包一个字节
payload = uint8([]);
if exist('sdrTxRequest','var') && isfield(sdrTxRequest,'frameBits')
    frameBits = double(sdrTxRequest.frameBits(:).');
else
    imdata = imread(imageFile);
    assert(ismatrix(imdata) && all(imdata(:)==0 | imdata(:)==1), ...
        '发送图片必须为只含 0/1 的单通道二值 BMP。');
    [NN,MM] = size(imdata);
    assert(NN<=255 && MM<=255,'载荷用一个字节表示宽和高，图片最大 255×255。');
    imageBits = double(imdata(:).');
    imageBits = [imageBits zeros(1,mod(-numel(imageBits),8))];
    bytes = zeros(1,numel(imageBits)/8,'uint8');
    for k = 1:numel(bytes)
        for b = 1:8
            if imageBits((k-1)*8+b), bytes(k) = bitset(bytes(k),b); end
        end
    end
    % 0x22 | 每符号比特数 | 宽 | 高 | 图片字节
    payload = [uint8(34),uint8(P.bps),uint8(MM),uint8(NN),bytes];

    %% 4. CRC-16/X.25 校验，低字节先发
    fcs = crc16x25(payload);
    body = [payload,uint8(bitand(fcs,255)),uint8(bitshift(fcs,-8))];
    rawBits = zeros(1,numel(body)*8);
    for k = 1:numel(body)
        rawBits((k-1)*8+(1:8)) = bitget(body(k),1:8);
    end

    %% 5. HDLC 位填充：连续 5 个 1 后插入 0，首尾标志不填充
    stuffed = zeros(1,ceil(numel(rawBits)*6/5)+8);
    count = 0;
    onesRun = 0;
    for k = 1:numel(rawBits)
        count = count+1;
        stuffed(count) = rawBits(k);
        if rawBits(k)==1, onesRun = onesRun+1; else, onesRun = 0; end
        if onesRun==5
            count = count+1;
            stuffed(count) = 0;
            onesRun = 0;
        end
    end
    flag = [0 1 1 1 1 1 1 0];    % HDLC 标志 0x7E
    frameBits = [flag,stuffed(1:count),flag];
end
assert(~isempty(frameBits) && all(frameBits==0 | frameBits==1),'帧必须为非空 0/1 序列。');

%% 6. 首尾 m 序列夹住 HDLC 帧，前后导帮助接收机捕获与稳定
% 前导 | m 序列 | 17 个 1 | HDLC 帧 | 17 个 1 | m 序列 | 后导
% m 序列定位测量窗口；HDLC/FCS 判断该帧是否完整，两者作用不同。
measuredFrame = frameBits;
if isfield(P,'syncBits')
    syncGuard = ones(1,P.syncGuard);
    measuredFrame = [P.syncBits,syncGuard,frameBits,syncGuard,P.syncBits];
end
src = [ones(1,P.preambleSyms*P.bps),measuredFrame,ones(1,P.postambleSyms*P.bps)];
src = [src zeros(1,mod(-numel(src),P.bps))]; % 补零凑整符号

%% 7. 自同步扰码：1 + x^(-14) + x^(-17)
st = zeros(1,P.scrLen);
scrambled = zeros(size(src));
for k = 1:numel(src)
    value = xor(src(k),xor(st(P.scrTaps(1)),st(P.scrTaps(2))));
    scrambled(k) = value;
    st = [value st(1:end-1)];
end

%% 8. 差分象限与象限内幅度映射
symbolCount = numel(scrambled)/P.bps;
sym = complex(zeros(1,symbolCount));
quadrant = 0;
for k = 1:symbolCount
    group = scrambled((k-1)*P.bps+(1:P.bps));
    high = 2*group(1)+group(2);
    quadrant = mod(quadrant+P.quadRot(high+1),360);
    low = 0;
    if P.bps==4, low = 2*group(3)+group(4); end
    sym(k) = P.inQ(low+1)*exp(1i*quadrant*pi/180);
end

%% 9. 计算 RRC 系数，插零、卷积成形并上变频
h = rootRaisedCosine(P.beta,P.span,P.sps);
upsampled = complex(zeros(1,(symbolCount-1)*P.sps+1));
upsampled(1:P.sps:end) = sym;
bb = conv(upsampled,h);
n = 0:numel(bb)-1;
x = real(bb.*exp(1i*2*pi*P.fc*n/P.fs));
x = x/max(abs(x));
y = [zeros(1,round(LEAD*P.fs)),x,zeros(1,round(0.3*P.fs))];

%% 10. 保存文件、显示发送图并播放
if SHOW_FIGURE
    figure; imagesc(imdata,[0 1]); colormap(gray(2)); axis image off;
    title(['电脑发送图片: ' img_name]);
end
if SAVE_RAW
    pcm = int16(round(AMPLITUDE*x*32767));
    file = fopen(fullfile(here,'v22_tx.raw'),'w','ieee-le');
    assert(file>=0,'无法创建 v22_tx.raw。');
    fwrite(file,pcm,'int16'); fclose(file);
    audiowrite(fullfile(here,'v22_tx.wav'),double(pcm)/32768,P.fs);
end
if PLAY_AUDIO
    fprintf('发送 %s  %dx%d=%d 位  %dbps  载荷 %d 字节  帧 %d 比特\n', ...
        img_name,MM,NN,NN*MM,P.rate,numel(payload),numel(frameBits));
    fprintf('首尾各 %d 位 m 序列；信号 %.2fs，总播放 %.2fs\n',numel(P.syncBits),numel(x)/P.fs,numel(y)/P.fs);
    fprintf('板上先执行: ./build/v22_rx -b %d -d plughw:X,0 -t %d\n',P.rate,ceil(numel(y)/P.fs)+4);
    sound(AMPLITUDE*y,P.fs);
end
clear sdrTxRequest

%% 本文件内的 CRC 与滤波器公式；不依赖工程外部函数
function crc = crc16x25(bytes)
% 初值/末异或 0xFFFF，反射多项式 0x8408；123456789 的校验值为 0x906E。
    crc = uint16(65535);
    for k = 1:numel(bytes)
        crc = bitxor(crc,uint16(bytes(k)));
        for b = 1:8
            if bitand(crc,1)
                crc = bitxor(bitshift(crc,-1),uint16(33800));
            else
                crc = bitshift(crc,-1);
            end
        end
    end
    crc = bitxor(crc,uint16(65535));
end

function h = rootRaisedCosine(beta,span,sps)
% 单位能量的平方根升余弦；显式处理 t=0 与 t=±1/(4*beta) 的极限。
    t = (-span*sps/2:span*sps/2)/sps;
    h = zeros(size(t));
    atZero = abs(t)<eps;
    atSingularity = abs(abs(4*beta*t)-1)<sqrt(eps);
    regular = ~atZero & ~atSingularity;
    h(atZero) = 1+beta*(4/pi-1);
    h(atSingularity) = beta/sqrt(2)*((1+2/pi)*sin(pi/(4*beta))+(1-2/pi)*cos(pi/(4*beta)));
    u = t(regular);
    h(regular) = (sin(pi*(1-beta)*u)+4*beta*u.*cos(pi*(1+beta)*u)) ...
        ./(pi*u.*(1-(4*beta*u).^2));
    h = h/sqrt(sum(h.^2));
end
