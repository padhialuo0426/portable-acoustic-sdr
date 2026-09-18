%% 实验四 · 解码：读板上产出的 v22sym.mat，还原图片
%
%  板上 v22_rx 每帧吐 60 个复符号（I,Q 交替），本脚本接着做：
%    判决 -> 差分解码 -> 自同步解扰 -> HDLC 找帧/去位填充/校验 FCS -> 还原图片
%
%  与实验二/三的解码脚本对照：那两个要靠 img_name 算出帧头帧尾该相距多远
%  （gap = L+15），图片选错就报「未找到 m 序列」；本实验不需要——帧长写在
%  帧里，HDLC 标志自带边界。这里读 img_name 只为算 BER 和并排显示原图。

%% 路径与参数 %%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here, 'baseband_images');
img_name = 'ren512b.bmp';     % ← 仅用于算 BER / 对照显示，解码本身不依赖它
RATE     = 2400;              % ← 与发送端一致

P = v22_params(RATE);

%% 读板上数据 %%
S = load(fullfile(here,'v22sym.mat'));       % 接收端(v22_rx)产出，放到本目录
if ~isfield(S,'v22Sym'), error('v22sym.mat 里没有 v22Sym 变量。'); end
D = S.v22Sym;
if size(D,1) ~= 121
    error('v22Sym 应为 121 行（1 行时间 + 120 个 I/Q），实得 %d 行。', size(D,1));
end
nF = size(D,2);
fprintf('读入 %d 帧（%.2f 秒）\n', nF, nF/10);

%% 复符号序列 %%
V   = D(2:end, :);                            % 120 x nF
sym = complex(zeros(1, nF*60));
for k = 1:nF
    c = V(:,k).';
    sym((k-1)*60 + (1:60)) = c(1:2:end) + 1i*c(2:2:end);
end

%% 判决 + 差分解码 + 自同步解扰 %%
bits = v22_symbols_to_bits(sym, P);

%% HDLC 解帧 %%
frames = v22_unpack(bits);
good   = frames([frames.ok]);
fprintf('候选帧 %d 个，FCS 通过 %d 个\n', numel(frames), numel(good));
if isempty(good)
    error(['没有 FCS 通过的帧。可能原因：信号太弱或过载、采集时长不够、' ...
           '速率档位与发送端不一致（当前按 %d bps 解）。'], RATE);
end

%% 还原图片 %%
img = [];
for g = 1:numel(good)
    try
        img = v22_payload2img(good(g).payload);  break
    catch
    end
end
if isempty(img), error('帧解出来了但载荷不是图片格式。'); end
[NN, MM] = size(img);

imRef = imread(fullfile(imgdir, img_name));
if isequal(size(imRef), size(img))
    BER = sum(img(:) ~= double(imRef(:))) / numel(img)      %#ok<NOPTS>
else
    fprintf('注意：还原图片 %dx%d 与 %s 尺寸不同，跳过 BER\n', MM, NN, img_name);
end

figure;
imshow(logical(img));
title(sprintf('接收还原图片 (%dx%d, %dbps)', MM, NN, RATE));

%% 星座图——16-QAM 出问题时这是最直接的诊断手段 %%
act = sym(abs(sym) > 0.1*max(abs(sym)));       % 去掉静噪段
figure;
plot(real(act), imag(act), '.', 'MarkerSize', 4); axis equal; grid on
xlabel('I'); ylabel('Q');
title(sprintf('接收星座图 (%dbps, %d 个符号)', RATE, numel(act)));
