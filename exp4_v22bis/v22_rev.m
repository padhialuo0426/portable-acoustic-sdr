%% 实验四 · 解码：读板上产出的 v22sym.mat，还原图片
%
%  板上 v22_rx 每帧吐 60 个复符号（I,Q 交替），本脚本接着做：
%    判决 -> 差分解码 -> 自同步解扰 -> HDLC 找帧/去位填充/校验 FCS -> 还原图片
%
%  HDLC/FCS 独立判断接收帧是否完整。首尾 m 序列另外定位实验测量窗口，
%  结合本次发送图片的尺寸及位填充位置，允许坏帧统计图片 BER。
%  因此 img_name 必须与发送端一致；实验对照图不等同于 FCS 有效图片。

%% 路径与参数 %%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir   = fullfile(here, 'baseband_images');
img_name = 'ren512b.bmp';     % ← 与发送端一致，提供实验 BER 的位置与图片参考
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

%% 独立的实验 BER 与 HDLC/FCS 检查 %%
reference = v22_img2payload(imgdir,img_name,P.bps);
report = v22_diagnose(bits,reference,P);
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
    imRef = v22_payload2img(reference);
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

%% 星座图——16-QAM 出问题时这是最直接的诊断手段 %%
act = sym(abs(sym) > 0.1*max(abs(sym)));       % 去掉静噪段
figure;
plot(real(act), imag(act), '.', 'MarkerSize', 4); axis equal; grid on
xlabel('I'); ylabel('Q');
title(sprintf('接收星座图 (%dbps, %d 个符号)', RATE, numel(act)));
