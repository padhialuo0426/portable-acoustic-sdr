function [sig, info] = v22_prepare_recording(y, fs, P)
%V22_PREPARE_RECORDING  重采样并按带内能量定位突发，不依赖发送图片。
% 输入为 audioread 的样本布局；多声道取第一路。返回 P.fs Hz 行向量。
% 同一次录音应包含一个突发；首尾静音不参与解调器的幅度归一化。
    validateattributes(y, {'numeric'}, {'2d','real','finite','nonempty'});
    validateattributes(fs, {'numeric'}, {'scalar','real','finite','positive'});
    if ~isvector(y), y = y(:,1); end
    y = double(y(:).');
    if fs ~= P.fs
        [up, down] = rat(P.fs/fs);
        y = resample(y, up, down);
    end
    minLen = P.preambleSyms * P.sps;
    if numel(y) < minLen
        error('v22:ShortRecording', '录音仅 %.3f 秒，短于 %.3f 秒前导。', ...
              numel(y)/P.fs, minLen/P.fs);
    end

    bp = fir1(256, [P.fc-P.Rs*0.9, P.fc+P.Rs*0.9]/(P.fs/2));
    % same 补偿线性相位 FIR 的群延迟，定位索引可直接用于原始信号。
    band = conv(y, bp, 'same');
    win = round(0.01*P.fs);
    power = conv(band.^2, ones(1,win)/win, 'same');
    % 插拔/开始播放的短促脉冲不能决定整段突发门限。
    power = movmedian(power, round(0.03*P.fs));
    peak = max(power);
    if peak < 1e-12
        error('v22:NoSignal', '录音中没有可检测的带内信号。');
    end
    sorted = sort(power);
    floorPower = sorted(max(1, round(0.1*numel(sorted))));
    threshold = max(0.08*peak, min(4*floorPower, 0.3*peak));
    active = find(power >= threshold);
    margin = round(0.02*P.fs);
    first = max(1, active(1)-margin);
    last = min(numel(y), active(end)+margin);
    if last-first+1 < minLen
        error('v22:ShortBurst', '检测到的突发短于前导，录音可能不完整。');
    end
    sig = y(first:last);
    info.fs = P.fs;
    info.first = first;
    info.last = last;
    info.duration = numel(y)/P.fs;
    info.peak = max(abs(sig));
    info.bandRms = sqrt(mean(band(first:last).^2));
end
