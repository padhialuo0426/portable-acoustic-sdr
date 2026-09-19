%% 实验四 · 独立 MATLAB 顺序解码脚本：V.22bis 点阵恢复
%
%  板上 v22_rx 每帧吐 60 个复符号（I,Q 交替），本脚本接着做：
%    判决 -> 差分解码 -> 自同步解扰 -> HDLC 找帧/去位填充/校验 FCS -> 还原图片
%
%  HDLC/FCS 独立判断接收帧是否完整。首尾 m 序列另外定位实验测量窗口，
%  结合本次发送图片的尺寸及位填充位置，允许坏帧统计图片 BER。
%  因此 img_name 必须与发送端一致；实验对照图不等同于 FCS 有效图片。

%% 1. 输入文件与独立参数
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here, 'baseband_images');
img_name = 'ren512b.bmp';     % ← 与发送端一致，提供实验 BER 的位置与图片参考
RATE     = 2400;              % ← 与发送端一致

P = decodeParameters(RATE);

%% 2. 读入板上数据
S = load(fullfile(here,'v22sym.mat'));       % 接收端(v22_rx)产出，放到本目录
if ~isfield(S,'v22Sym'), error('v22sym.mat 里没有 v22Sym 变量。'); end
D = S.v22Sym;
if size(D,1) ~= 121
    error('v22Sym 应为 121 行（1 行时间 + 120 个 I/Q），实得 %d 行。', size(D,1));
end
nF = size(D,2);
fprintf('读入 %d 帧（%.2f 秒）\n', nF, nF/10);

%% 3. 从 I/Q 数据还原复符号
V   = D(2:end, :);                            % 120 x nF
sym = complex(zeros(1, nF*60));
for k = 1:nF
    c = V(:,k).';
    sym((k-1)*60 + (1:60)) = c(1:2:end) + 1i*c(2:2:end);
end

%% 4. 星座判决、差分解码与自同步解扰
sym = sym(:).';
dec = zeros(1, numel(sym)*P.bps);  qp = 0;
for k = 1:numel(sym)
    z = sym(k);
    if     real(z)>=0 && imag(z)>=0, qi = 0;
    elseif real(z)< 0 && imag(z)>=0, qi = 1;
    elseif real(z)< 0 && imag(z)< 0, qi = 2;
    else,                            qi = 3;
    end
    p1 = z * exp(-1i*90*qi*pi/180);
    [~, li] = min(abs(p1 - P.inQ));
    dq = mod(90*qi - qp, 360);  qp = 90*qi;
    hi = find(P.quadRot == dq, 1) - 1;
    if P.bps == 4
        dec((k-1)*4+(1:4)) = [bitget(hi,2) bitget(hi,1) bitget(li-1,2) bitget(li-1,1)];
    else
        dec((k-1)*2+(1:2)) = [bitget(hi,2) bitget(hi,1)];
    end
end
st = zeros(1, P.scrLen);  bits = zeros(size(dec));
for i = 1:numel(dec)
    bits(i) = xor(dec(i), xor(st(P.scrTaps(1)), st(P.scrTaps(2))));
    st = [dec(i) st(1:end-1)];
end

%% 5. m 序列测量、HDLC/FCS 检查与图片显示
reference = imageToPayload(imgdir,img_name,P.bps);
report = diagnoseFrame(bits,reference,P);
fprintf('%s\n',report.message);
m = report.measurement;
BER = NaN;
if m.available
    BER = m.ber;
    fprintf('m 序列定位成功，首/尾相关 %.3f / %.3f\n',m.scores);
    fprintf('实验图片 BER = %d/%d = %.6f\n',m.errors,m.bits,m.ber);
else
    fprintf('实验 BER 无法计算：%s\n',m.reason);
end
img = report.image;
if ~m.available && ~isempty(img)
    imRef = payloadToImage(reference);
    if isequal(size(img),size(imRef))
        BER = sum(img(:) ~= imRef(:))/numel(img);
        fprintf('有效帧 BER = %.6f（仅比较 FCS 通过的图片）\n',BER);
    end
end
label = '接收还原（FCS 通过）';
if isempty(img) && m.available
    img = m.image;
    label = '实验对照还原（未获得有效图片帧）';
end
if ~isempty(img)
    figure; imshow(logical(img));
    title(sprintf('%s (%dbps)',label,RATE));
end

%% 6. 显示实收星座
act = sym(abs(sym) > 0.1*max(abs(sym)));       % 去掉静噪段
figure;
plot(real(act), imag(act), '.', 'MarkerSize', 4); axis equal; grid on
xlabel('I'); ylabel('Q');
title(sprintf('接收星座图 (%dbps, %d 个符号)', RATE, numel(act)));

%% 本文件局部函数：参数、同步与图像恢复均独立实现
% 无需路径配置，不调用工程算法库或 Simulink 模型。

function P = decodeParameters(rate)
%DECODEPARAMETERS  实验四物理层参数（ITU-T V.22bis，主叫方向）
%
%   P = decodeParameters(2400)   16-QAM，4 bit/符号
%   P = decodeParameters(1200)   QPSK  ，2 bit/符号（V.22bis 的回退速率）
%
%   本解码文件自带参数；独立发送脚本与模型分支分别保存同值参数。
%   修改协议时需分别修改两套发送实现，并比较它们的组帧与波形。
%
%   采样率取 9600 而不是本工程其它实验的 8000：9600/600 = 16 正好是整数，
%   省掉分数倍定时插值。板上让 ALSA 的 plughw 做重采样即可（见实验文档）。

    if nargin < 1, rate = 2400; end

    P.rate = rate;
    P.fs   = 9600;               % 采样率
    P.Rs   = 600;                % 符号率(baud)，V.22bis 规定
    P.sps  = P.fs / P.Rs;        % 每符号 16 点
    P.fc   = 1200;               % 载波，V.22bis 主叫方向（被叫是 2400）
    P.beta = 0.75;               % RRC 滚降，V.22bis 规定 75%
    P.span = 8;                  % 成形滤波器长度(符号)

    % 差分四象限编码：前 2 bit 决定相对前一符号的象限旋转
    P.quadRot = [90 0 180 270];  % 比特 00/01/10/11 -> 旋转角(度)

    switch rate
        case 2400
            P.bps   = 4;                            % 每符号比特数
            P.inQ   = [1+1i, 3+1i, 1+3i, 3+3i];     % 后 2 bit 在象限内选点
        case 1200
            P.bps   = 2;
            P.inQ   = (1+1i)/sqrt(2);               % 象限内只有一个点
        otherwise
            error('rate 只能是 2400 或 1200。');
    end

    % 扰码多项式 GPC = 1 + x^-14 + x^-17（V.22bis 主叫方向，自同步）
    P.scrTaps = [14 17];
    P.scrLen  = 17;

    % 实验测量外层：两段 m 序列夹住 HDLC 帧，不改变其位填充或 FCS。
    P.syncBits = syncSequence();
    P.syncGuard = 17;            % 数据与标记之间留足解扰记忆长度
    P.syncMaxErrors = 25;        % 每段 127 位最多 25 位错，且首尾间距必须匹配

    % 前导：送入扰码器的全 1，出来是伪随机序列，供 AGC/定时/载波捕获。
    % 300 符号是仿真里二阶载波环稳定捕获所需长度的 1.5 倍余量。
    P.preambleSyms = 300;

    % 后导：数据发完不立刻断载波，再送 120 个符号(0.2s)的加扰全 1。
    % 接收端按 60 符号一帧处理，突发若在帧中间结束，那个半空帧会被逐帧 AGC
    % 归一化而把噪声放大成星座——数据若正好落在那一帧就完了。真实 modem
    % 同样不会在最后一个数据符号后立刻掉载波。
    P.postambleSyms = 120;
end

function bits = syncSequence()
%SYNCSEQUENCE  127 位 m 序列，供接收端与模型参数的首尾相关定位。
% 多项式 x^7+x^3+1，初始 7 位全 1；b(n+7)=b(n+3) xor b(n)。
% 这里列出完整数组；独立 MATLAB 发送脚本也保留自己的同值数组。
bits = [ ...
    1 1 1 1 1 1 1 0 0 0 0 1 1 1 0 1 ...
    1 1 1 0 0 1 0 1 1 0 0 1 0 0 1 0 ...
    0 0 0 0 0 1 0 0 0 1 0 0 1 1 0 0 ...
    0 1 0 1 1 1 0 1 0 1 1 0 1 1 0 0 ...
    0 0 0 1 1 0 0 1 1 0 1 0 1 0 0 1 ...
    1 1 0 0 1 1 1 1 0 1 1 0 1 0 0 0 ...
    0 1 0 1 0 1 0 1 1 1 1 1 0 1 0 0 ...
    1 0 1 0 0 0 1 1 0 1 1 1 0 0 0];
end


function report = diagnoseFrame(bits, referencePayload, P)
%DIAGNOSEFRAME  独立报告 m 序列实验 BER 与 HDLC/FCS 接收完整性。
% 参考载荷只用于诊断与 BER；不修复帧、不放宽 FCS，也不选择最像参考的帧。
    if nargin < 3, P = decodeParameters(double(referencePayload(2))*600); end
    measurement = measureImageBits(bits,referencePayload,P);
    if measurement.available
        offset = measurement.range(1)-1;
        [frames, detail] = unpackFrames(bits(measurement.range(1):measurement.range(2)));
        for k = 1:numel(frames)
            frames(k).pos = frames(k).pos + offset;
            frames(k).endPos = frames(k).endPos + offset;
        end
    else
        [frames, detail] = unpackFrames(bits);
    end
    report = struct('hdlc',detail,'status','','message','', ...
        'image',[],'frameRange',[],'invalidImages',0,'measurement',measurement, ...
        'diagnostic',struct('available',false,'reason','','errors',NaN, ...
                            'bits',0,'ber',NaN,'frameIndex',[]));

    for k = find([frames.ok])
        try
            candidate = payloadToImage(frames(k).payload);
        catch
            candidate = [];
        end
        if isempty(candidate)
            report.invalidImages = report.invalidImages + 1;
        elseif isempty(report.image)
            report.image = candidate;
            report.frameRange = [frames(k).pos frames(k).endPos];
        end
    end

    if ~isempty(report.image)
        report.status = 'ok';
        report.message = 'FCS 通过，已还原有效图片帧';
    elseif detail.fcsPassed > 0
        report.status = 'invalid_image';
        report.message = 'FCS 通过，但图片头或图片载荷无效';
    elseif detail.candidateCount > 0
        report.status = 'fcs_failed';
        report.message = '候选帧 FCS 失败：数据有误或帧边界误识别';
    elseif detail.flagCount < 2
        report.status = 'insufficient_flags';
        report.message = '帧标志不足，无法确定完整 HDLC 边界';
    else
        report.status = 'invalid_format';
        report.message = sprintf('无可校验帧：过短 %d，位填充非法 %d，长度异常 %d', ...
            detail.shortCount,detail.stuffingErrorCount,detail.lengthErrorCount);
    end

    % 两端 HDLC 标志、合法去填充、整字节均由 unpackFrames 保证。
    % 再要求完整的 4 字节图片头和载荷长度与参考相同，且候选唯一。
    % 不扫描参考图寻找最小误码窗口，不将误识别或长度损坏强行对齐。
    referencePayload = uint8(referencePayload(:).');
    referenceImage = payloadToImage(referencePayload);
    matched = [];
    for k = 1:numel(frames)
        payload = frames(k).payload;
        if numel(payload) == numel(referencePayload) && ...
                isequal(payload(1:4),referencePayload(1:4))
            matched(end+1) = k; %#ok<AGROW>
        end
    end
    if isempty(frames)
        report.diagnostic.reason = '没有边界和格式完整的候选帧';
    elseif isempty(matched)
        report.diagnostic.reason = '候选帧的图片头或载荷长度与本次参考不一致';
    elseif numel(matched) > 1
        report.diagnostic.reason = '存在多个匹配候选，无法唯一对齐';
    elseif isempty(referenceImage)
        report.diagnostic.reason = '参考图片为空';
    else
        candidate = payloadToImage(frames(matched).payload);
        count = sum(candidate(:) ~= referenceImage(:));
        report.diagnostic = struct('available',true,'reason','', ...
            'errors',count,'bits',numel(referenceImage), ...
            'ber',count/numel(referenceImage),'frameIndex',matched);
    end
end

function result = measureImageBits(bits, referencePayload, P)
%MEASUREIMAGEBITS  用首尾 m 序列独立定位，统计不经过 FCS 筛选的实验图片 BER。
% 参考载荷只决定预期间距、图片大小和发送端填充位置；定位不比较图片内容。
% 坏帧的位填充可能无法正常去除，故按发送端位置映射提取实收图片比特。
% 这是已知发送数据的实验测量，不是无需参考图的正常图片解码或纠错。
    result = struct('available',false,'reason','','errors',NaN,'bits',0, ...
        'ber',NaN,'image',[],'range',[],'markers',[],'scores',[], ...
        'frameErrors',NaN,'frameBits',0);
    if ~isfield(P,'syncBits')
        result.reason = '当前参数未启用 m 序列'; return
    end
    bits = double(bits(:).');
    [frame, positions] = packReferenceFrame(referencePayload);
    reference = payloadToImage(referencePayload);
    seq = P.syncBits; L = numel(seq);
    gap = L + 2*P.syncGuard + numel(frame);
    if numel(bits) < gap + L
        result.reason = '数据不足以容纳首尾 m 序列和完整测量窗口';
        return
    end
    score = conv(2*bits-1,fliplr(2*seq-1),'valid');
    threshold = L - 2*P.syncMaxErrors;
    head = find(score(1:end-gap) >= threshold & score(1+gap:end) >= threshold);
    if isempty(head)
        result.reason = '未找到相关强度和间距均符合要求的首尾 m 序列';
        return
    elseif numel(head) ~= 1
        result.reason = '存在多个匹配的 m 序列窗口，无法唯一定位';
        return
    end
    tail = head + gap;
    first = head + L + P.syncGuard;
    last = tail - P.syncGuard - 1;
    receivedFrame = bits(first:last);
    % 前 32 个载荷比特是图片头；最后不足一字节的填零不计入图片 BER。
    imagePositions = positions(32+(1:numel(reference)));
    receivedImage = reshape(receivedFrame(imagePositions),size(reference));
    count = sum(receivedImage(:) ~= reference(:));
    result = struct('available',true,'reason','','errors',count,'bits',numel(reference), ...
        'ber',count/numel(reference),'image',receivedImage,'range',[first last], ...
        'markers',[head tail],'scores',score([head tail])/L, ...
        'frameErrors',sum(receivedFrame ~= frame),'frameBits',numel(frame));
end

function [frames, detail] = unpackFrames(bits)
%UNPACKFRAMES  从一条连续比特流里找出所有 HDLC 帧并校验 FCS
%
%   frames = unpackFrames(bits)   bits 为 0/1 向量（板上解扰后的判决流）。
%   返回结构体数组，每个元素：
%       .payload  uint8 行向量（已去 FCS）
%       .ok       logical，FCS 是否通过
%       .pos      该帧起始标志在 bits 中的下标
%       .endPos   该帧结束标志最后一位的下标（含标志和位填充的原始位置）
%   第二输出 detail 统计各阶段结果；未通过格式检查的区间不计入 frames。
%
%   本函数只处理 HDLC 边界、位填充与 FCS；外层 m 序列由 measureImageBits 定位。
%   diagnoseFrame 优先在 m 序列确定的窗口中调用本函数，定位失败时也可扫描全流。
%   无误码时，位填充使数据段不含 0x7E；有误码时仍可能出现假标志或非法填充。
%   因此，m 序列测量成功与 HDLC/FCS 检查通过是两个分别报告的结果。
%
%   容错：判决流里难免有误码，可能出现假标志或坏帧。这里不做任何纠错，
%   只是把每个候选帧都算一遍 FCS，让调用者按 .ok 挑——单向传输没有重传，
%   FCS 的作用是「知道这帧不能信」，不是修复它。

    bits  = bits(:).';
    flag  = [0 1 1 1 1 1 1 0];
    frames = struct('payload',{},'ok',{},'pos',{},'endPos',{});
    detail = struct('flagCount',0,'intervalCount',0,'shortCount',0, ...
        'stuffingErrorCount',0,'lengthErrorCount',0,'candidateCount',0, ...
        'fcsPassed',0,'fcsFailed',0);

    % --- 找出所有标志位置 ---
    n = numel(bits);
    if n < 8, return, end
    loc = [];
    for i = 1:n-7
        if isequal(bits(i:i+7), flag), loc(end+1) = i; end %#ok<AGROW>
    end
    detail.flagCount = numel(loc);
    detail.intervalCount = max(0,numel(loc)-1);
    if numel(loc) < 2, return, end

    % --- 相邻两个标志之间即为一帧 ---
    for j = 1:numel(loc)-1
        s = loc(j) + 8;  e = loc(j+1) - 1;
        if e - s + 1 < 24                      % 至少要容下 FCS + 1 字节
            detail.shortCount = detail.shortCount + 1;
            continue
        end

        % 去位填充：连续 5 个 1 之后那个 0 是插进来的，丢掉
        seg = bits(s:e);
        dst = zeros(1, numel(seg)); m = 0; ones_run = 0; bad = false;
        i = 1;
        while i <= numel(seg)
            b = seg(i);
            m = m + 1; dst(m) = b;
            if b == 1
                ones_run = ones_run + 1;
                if ones_run == 5
                    if i+1 > numel(seg), bad = true; break, end
                    if seg(i+1) ~= 0, bad = true; break, end   % 6 个连续 1，非法
                    i = i + 1;                   % 跳过填充位
                    ones_run = 0;
                end
            else
                ones_run = 0;
            end
            i = i + 1;
        end
        if bad
            detail.stuffingErrorCount = detail.stuffingErrorCount + 1;
            continue
        end
        dst = dst(1:m);
        if mod(numel(dst), 8) ~= 0 || numel(dst) < 24
            detail.lengthErrorCount = detail.lengthErrorCount + 1;
            continue
        end

        % 比特 -> 字节（低位先发）
        nb = numel(dst)/8;
        by = zeros(1, nb, 'uint8');
        for k = 1:nb
            v = uint8(0);
            for b = 1:8
                if dst((k-1)*8+b), v = bitset(v, b); end
            end
            by(k) = v;
        end
        if nb < 3, continue, end

        payload = by(1:end-2);
        got     = uint16(by(end-1)) + bitshift(uint16(by(end)), 8);  % FCS 低字节先
        frames(end+1) = struct('payload', payload, ...
                               'ok', got == crc16(payload), ...
                               'pos', loc(j), 'endPos', loc(j+1)+7); %#ok<AGROW>
    end
    detail.candidateCount = numel(frames);
    detail.fcsPassed = sum([frames.ok]);
    detail.fcsFailed = detail.candidateCount - detail.fcsPassed;
end

function [img, NN, MM] = payloadToImage(payload)
%PAYLOADTOIMAGE  HDLC 帧载荷 -> 位图（imageToPayload 的逆）

    if numel(payload) < 4 || payload(1) ~= 34
        error('载荷头不对（幻数应为 0x22），这帧不是实验四的图片帧。');
    end
    MM = double(payload(3));  NN = double(payload(4));
    data = payload(5:end);
    need = ceil(NN*MM/8);
    if numel(data) < need
        error('载荷字节不足：需要 %d，实得 %d。', need, numel(data));
    end
    b = zeros(1, numel(data)*8);
    for k = 1:numel(data)
        for i = 1:8
            b((k-1)*8+i) = bitget(data(k), i);   % 低位先
        end
    end
    img = zeros(NN, MM);
    for m = 1:MM
        for n = 1:NN
            img(n,m) = b((m-1)*NN+n);            % 列优先
        end
    end
end

function [payload, NN, MM] = imageToPayload(imgdir, name, bps)
%IMAGETOPAYLOAD  1-bit BMP -> HDLC 帧载荷字节
%
%   载荷格式（4 字节头 + 位图）：
%       [0] 0x22   幻数，标识实验四
%       [1] bps    每符号比特数(4=2400bps, 2=1200bps)，仅作记录
%       [2] 宽(列) [3] 高(行)   —— 故最大支持 255x255
%       [4..]      位图，列优先展开后每 8 bit 打包成 1 字节（低位先）
%
%   列优先与本工程前三个实验一致，换图不用改任何代码。

    im = imread(fullfile(imgdir, name));
    if ~ismatrix(im) || ~all(im(:)==0 | im(:)==1)
        error('发送图片必须为只含 0/1 的单通道二值 BMP。');
    end
    [NN, MM] = size(im);                       % NN=行(高) MM=列(宽)
    if NN > 255 || MM > 255
        error('本实验载荷头用单字节存宽高，图片最大 255x255。');
    end
    b = zeros(1, NN*MM);
    for m = 1:MM
        for n = 1:NN
            b((m-1)*NN+n) = double(im(n,m));   % 列优先
        end
    end
    pad = mod(-numel(b), 8);
    b   = [b zeros(1,pad)];
    nb  = numel(b)/8;
    data = zeros(1, nb, 'uint8');
    for k = 1:nb
        v = uint8(0);
        for i = 1:8
            if b((k-1)*8+i), v = bitset(v, i); end   % 低位先
        end
        data(k) = v;
    end
    payload = [uint8(34), uint8(bps), uint8(MM), uint8(NN), data];
end

function [bits, payloadPositions] = packReferenceFrame(payload)
%PACKREFERENCEFRAME  把一段字节按 HDLC 组成一帧（V.42 LAPM 的简化形式）
%
%   bits = packReferenceFrame(payload)   payload 为 uint8 向量，返回 0/1 行向量。
%   payloadPositions 给出每个原始载荷比特在 bits 中的位置，供实验 BER 对照；
%   接收端正常解帧仍按实收位填充和 FCS 处理，不使用这份参考映射纠错。
%
%   帧结构：
%       0x7E │ 位填充( payload ‖ FCS-16 ) │ 0x7E
%
%   三条 HDLC 规矩，缺一不可：
%     1. **低位先发**：每个字节按 b0..b7 的顺序送上信道，这是 HDLC 的规定，
%        和本工程其它实验里「图片按列优先展开」是两码事，别混。
%     2. **位填充**：数据段里连续 5 个 1 之后强制插入一个 0，保证除标志
%        以外任何地方都出不来 6 个连续 1，接收端据此唯一地找到帧边界。
%     3. **标志不填充**：0x7E 本身就是 01111110（六个 1），它是故意留出的
%        唯一模式，所以标志字节绕过填充直接送。
%
%   FCS 低字节先发（X.25 规定），接收端 unpackFrames 按同样顺序取回。

    payload = uint8(payload(:)).';
    fcs  = crc16(payload);
    body = [payload, uint8(bitand(fcs,255)), uint8(bitshift(fcs,-8))];

    % --- 字节 -> 比特（低位先发）---
    raw = zeros(1, numel(body)*8);
    for k = 1:numel(body)
        for b = 1:8
            raw((k-1)*8+b) = bitget(body(k), b);
        end
    end

    % --- 位填充：连续 5 个 1 后插 0 ---
    stuffed = zeros(1, ceil(numel(raw)*6/5) + 8);  % 上界（每 5 位最多插 1 位），最后截
    m = 0; ones_run = 0;
    positions = zeros(size(raw));
    for i = 1:numel(raw)
        m = m + 1;  stuffed(m) = raw(i);
        positions(i) = m + 8;                 % 加上前面的 8 位 HDLC 标志
        if raw(i) == 1
            ones_run = ones_run + 1;
            if ones_run == 5
                m = m + 1;  stuffed(m) = 0;   % 插入的 0
                ones_run = 0;
            end
        else
            ones_run = 0;
        end
    end
    stuffed = stuffed(1:m);

    flag = [0 1 1 1 1 1 1 0];                 % 0x7E，不参与填充
    bits = [flag, stuffed, flag];
    payloadPositions = positions(1:numel(payload)*8);
end

function c = crc16(bytes)
%CRC16  CRC-16/X.25（即 HDLC/V.42 的 FCS-16）
%
%   c = crc16(bytes)   bytes 为 uint8 向量，返回 uint16 校验和。
%
%   参数（ITU-T X.25 / V.42 规定）：
%     多项式 0x1021，按位反射后为 0x8408（因为 HDLC 是低位先发）
%     初值 0xFFFF，输入输出均反射，最后异或 0xFFFF
%
%   标准校验值：crc16(uint8('123456789')) == 0x906E

    c = uint16(65535);                       % 0xFFFF
    for k = 1:numel(bytes)
        c = bitxor(c, uint16(bytes(k)));
        for b = 1:8
            if bitand(c, 1)
                c = bitxor(bitshift(c, -1), uint16(33800));   % 0x8408
            else
                c = bitshift(c, -1);
            end
        end
    end
    c = bitxor(c, uint16(65535));
end
