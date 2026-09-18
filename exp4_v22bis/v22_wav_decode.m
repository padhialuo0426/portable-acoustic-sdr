%% 实验四 · 直接解一段录音 .wav（不经过板子）
%
%  用途：把声学问题和板上/模型问题分开。同一段录音——
%    用本脚本解得出来  -> 声学链路没问题，问题在板上 C 或模型
%    用本脚本也解不出  -> 问题在声学侧（电平、噪声、换能器频响）
%  实测中正是靠它把「RDP 音频失真」和「扬声器+麦克风失真」切开的：
%  数字环回的录音能解出 BER=0，而同一套参数走空气就不行。
%
%  按带内能量检测突发边界，并自动重采样到 9600 Hz；不依赖已知图片长度。
%  IMG_NAME 可选；指定后还用首尾 m 序列测量实验 BER，不改变 FCS 判定。
%
%  用法：  WAV = 'xxx.wav'; RATE = 2400; v22_wav_decode
if ~exist('RATE','var'), RATE = 2400; end
if ~exist('WAV','var'),  WAV  = 'rx.wav'; end

here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
P = v22_params(RATE);
wavPath = WAV;
if ~isfile(wavPath), wavPath = fullfile(here, WAV); end
[y, fsr] = audioread(wavPath);
if size(y,2) > 1, y = y(:,1); end
y = y(:).';
fprintf('读入 %s: %.2fs @ %dHz\n', WAV, numel(y)/fsr, fsr);

[sig, capture] = v22_prepare_recording(y, fsr, P);
fprintf('突发定位 t=%.3f~%.3fs  带内RMS=%.4f  峰值=%.1f dBFS\n', ...
        (capture.first-1)/P.fs, capture.last/P.fs, capture.bandRms, ...
        20*log10(max(capture.peak,eps)));
[bits, info] = v22_demod(sig, P);
frames = v22_unpack(bits);
good = frames([frames.ok]);
fprintf('解调 %d 符号  EVM=%.1f%%   候选帧 %d 个，FCS 通过 %d 个\n', ...
        info.nsym, info.evm*100, numel(frames), numel(good));

done = false; im = []; nbad = NaN;
for g = 1:numel(good)
    try
        im = v22_payload2img(good(g).payload);
    catch
        continue
    end
    [NN, MM] = size(im);
    fprintf('★ 还原图片 %dx%d，FCS 通过\n', MM, NN);
    if exist('IMG_NAME','var') && ~isempty(IMG_NAME)
        ref = v22_img2payload(fullfile(here,'baseband_images'), IMG_NAME, P.bps);
        imRef = v22_payload2img(ref);
        if isequal(size(im), size(imRef))
            nbad = sum(im(:) ~= imRef(:));
            fprintf('对照 %s：误像素 %d / %d\n', IMG_NAME, nbad, numel(im));
        else
            fprintf('对照图片尺寸不同，跳过 BER\n');
        end
    end
    done = true; break
end
if ~done, fprintf('✗ 没有可用的图片帧\n'); end

% 即使 FCS 失败，可靠的首尾 m 序列仍可提供参考辅助的实验 BER。
if exist('IMG_NAME','var') && ~isempty(IMG_NAME)
    ref = v22_img2payload(fullfile(here,'baseband_images'),IMG_NAME,P.bps);
    measurement = v22_measure(bits,ref,P);
    if measurement.available
        fprintf('实验图片 BER = %d/%d = %.6f（FCS 单独检查）\n', ...
            measurement.errors,measurement.bits,measurement.ber);
    else
        fprintf('实验 BER 无法计算：%s\n',measurement.reason);
    end
end
