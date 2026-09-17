%% 实验四 · 直接解一段录音 .wav（不经过板子）
%
%  用途：把声学问题和板上/模型问题分开。同一段录音——
%    用本脚本解得出来  -> 声学链路没问题，问题在板上 C 或模型
%    用本脚本也解不出  -> 问题在声学侧（电平、噪声、换能器频响）
%  实测中正是靠它把「RDP 音频失真」和「扬声器+麦克风失真」切开的：
%  数字环回的录音能解出 BER=0，而同一套参数走空气就不行。
%
%  含突发检测：先带通到信号频段，再用「已知突发长度」的滑窗找能量最大处。
%  这样带外噪声(风扇/空调)不会把门限抬高，也不会把突发截短。
%
%  用法：  WAV = 'xxx.wav'; RATE = 2400; v22_wav_decode
if ~exist('RATE','var'), RATE = 2400; end
if ~exist('WAV','var'),  WAV  = 'rx.wav'; end

here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
P = v22_params(RATE);
[y, fsr] = audioread(fullfile(here, WAV));
if size(y,2) > 1, y = y(:,1); end
y = y(:).';
fprintf('读入 %s: %.2fs @ %dHz\n', WAV, numel(y)/fsr, fsr);

[ref, NN, MM] = v22_img2payload(fullfile(here,'baseband_images'), 'ren512b.bmp', P.bps);
imRef = v22_payload2img(ref);
expLen = numel(v22_mod(v22_pack(ref), P));       % 预期突发长度(样本)

% --- 带通到 V.22bis 占带 ---
bp = fir1(256, [P.fc-P.Rs*0.9, P.fc+P.Rs*0.9]/(fsr/2));
yb = filter(bp, 1, y);

% --- 滑窗找能量最大的 expLen 段 ---
step = round(0.01*fsr);
best = [-inf 1];
for a = 1:step:max(1, numel(yb)-expLen)
    en = sum(yb(a:a+expLen-1).^2);
    if en > best(1), best = [en a]; end
end
a = best(2);
mar = round(0.10*fsr);
lo = max(1, a-mar); hi = min(numel(y), a+expLen-1+mar);

sigR = rms(yb(a:a+expLen-1));
nz   = [yb(1:max(1,a-round(0.3*fsr))), yb(min(end,a+expLen+round(0.3*fsr)):end)];
nzR  = rms(nz);
fprintf('突发定位 t=%.2f~%.2fs  带内信号RMS=%.4f 本底=%.4f  SNR≈%.1fdB  峰值=%.3f dBFS\n', ...
        lo/fsr, hi/fsr, sigR, nzR, 20*log10(sigR/max(nzR,1e-9)), ...
        20*log10(max(abs(y(lo:hi)))));

[bits, info] = v22_demod(y(lo:hi), P);
frames = v22_unpack(bits);
good = frames([frames.ok]);
fprintf('解调 %d 符号  EVM=%.1f%%   候选帧 %d 个，FCS 通过 %d 个\n', ...
        info.nsym, info.evm*100, numel(frames), numel(good));

done = false;
for g = 1:numel(good)
    try
        im = v22_payload2img(good(g).payload);
        if isequal(size(im), size(imRef))
            nbad = sum(im(:) ~= imRef(:));
            fprintf('★ 还原图片 %dx%d，误像素 %d / %d\n', MM, NN, nbad, NN*MM);
            for r = 1:NN
                fprintf('  %s\n', strrep(strrep(num2str(im(r,:)),'1','#'),'0','.'));
            end
            done = true; break
        end
    catch
    end
end
if ~done, fprintf('✗ 没有可用的图片帧\n'); end
