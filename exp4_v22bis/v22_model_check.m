%% 实验四 · 校验 Simulink 接收模型
%
%  把一段已知能解出来的录音按 960 样本/帧喂进 v22_receive.slx，仿真跑完，
%  拿模型输出的符号做判决/差分/解扰/HDLC，看能不能还原出图片。
%
%  这是「模型 == 黄金参考」的验收：v22_demod.m 能解的，模型也必须能解。
%  模型改完先跑这个，过了再生成代码。
%
%  用法：  WAV = 'mon.wav'; RATE = 2400; v22_model_check

%  WAV = 'sim'（默认）用合成信号，不依赖任何录音，可当回归测试跑；
%  WAV = 某个 .wav 则解真实录音。

if ~exist('WAV','var'),  WAV  = 'sim'; end
if ~exist('RATE','var'), RATE = 2400;  end
if ~exist('SNR','var'),  SNR  = 30;    end

here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
mdl = 'v22_receive';
P   = v22_params(RATE);
FRAME_LEN = 960;  FRAME_SYMS = 60;

%% ---- 取信号：合成 或 读录音 ----
[ref, NN, MM] = v22_img2payload(fullfile(here,'baseband_images'), 'ren512b.bmp', P.bps);
imRef  = v22_payload2img(ref);
expLen = numel(v22_mod(v22_pack(ref), P));

if strcmpi(WAV, 'sim')
    rng(20260918);
    tx = v22_mod(v22_pack(ref), P);
    y  = [zeros(1, round(0.3*P.fs)), tx, zeros(1, round(0.3*P.fs))];
    y  = y + randn(size(y))*std(tx)*10^(-SNR/20);
    fsr = P.fs;
    fprintf('合成信号 SNR=%ddB，长度 %.2fs\n', SNR, numel(y)/fsr);
else
    [y, fsr] = audioread(fullfile(here, WAV));
    if size(y,2) > 1, y = y(:,1); end
    y = y(:).';
    if fsr ~= P.fs, error('采样率不符：%d vs %d', fsr, P.fs); end
    fprintf('读入 %s: %.2fs\n', WAV, numel(y)/fsr);
end

bp = fir1(256, [P.fc-P.Rs*0.9, P.fc+P.Rs*0.9]/(fsr/2));
yb = filter(bp, 1, y);
step = round(0.01*fsr); best = [-inf 1];
for a = 1:step:max(1, numel(yb)-expLen)
    en = sum(yb(a:a+expLen-1).^2);
    if en > best(1), best = [en a]; end
end
a  = best(2);
mar = round(0.25*fsr);                        % 多给余量，让模型的环路先收敛
lo = max(1, a-mar);  hi = min(numel(y), a+expLen-1+mar);
seg = y(lo:hi);

%% ---- 切成整数帧，喂模型 ----
nF  = floor(numel(seg)/FRAME_LEN);
u   = int16(round(reshape(seg(1:nF*FRAME_LEN), FRAME_LEN, nF).' * 32767));
t   = (0:nF-1).' * 0.1;
ts  = timeseries(u, t);
fprintf('喂给模型 %d 帧 (%.2fs)\n', nF, nF*0.1);

si = Simulink.SimulationInput(mdl);
si = si.setModelParameter('StopTime', num2str((nF-1)*0.1), ...
                          'LoadExternalInput','on','ExternalInput','ts', ...
                          'SaveOutput','on','OutputSaveName','yout', ...
                          'SaveFormat','Array');
out = sim(si);
Y = squeeze(out.yout);                         % 120 x nF（信号维在前）
if size(Y,1) ~= FRAME_SYMS*2, Y = Y.'; end

%% ---- 模型输出 -> 符号 -> 比特 -> HDLC -> 图片 ----
sym = complex(zeros(1, nF*FRAME_SYMS));
for k = 1:nF
    row = Y(:,k).';
    sym((k-1)*FRAME_SYMS + (1:FRAME_SYMS)) = row(1:2:end) + 1i*row(2:2:end);
end

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
    hi_ = find(P.quadRot == dq, 1) - 1;
    if P.bps == 4
        dec((k-1)*4+(1:4)) = [bitget(hi_,2) bitget(hi_,1) bitget(li-1,2) bitget(li-1,1)];
    else
        dec((k-1)*2+(1:2)) = [bitget(hi_,2) bitget(hi_,1)];
    end
end

st = zeros(1, P.scrLen);  bits = zeros(size(dec));
for i = 1:numel(dec)
    bits(i) = xor(dec(i), xor(st(P.scrTaps(1)), st(P.scrTaps(2))));
    st = [dec(i) st(1:end-1)];
end

frames = v22_unpack(bits);
good   = frames([frames.ok]);
fprintf('模型输出 %d 个符号  候选帧 %d 个，FCS 通过 %d 个\n', ...
        numel(sym), numel(frames), numel(good));

ok = false;
for g = 1:numel(good)
    try
        im = v22_payload2img(good(g).payload);
        if isequal(size(im), size(imRef))
            nbad = sum(im(:) ~= imRef(:));
            fprintf('★ 模型还原图片 %dx%d，误像素 %d / %d\n', MM, NN, nbad, NN*MM);
            ok = (nbad == 0);  break
        end
    catch
    end
end
if ok
    fprintf('\n✅ 模型校验通过：与 v22_demod.m 结果一致\n');
else
    fprintf('\n❌ 模型校验未通过\n');
end
