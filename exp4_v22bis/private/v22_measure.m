function result = v22_measure(bits, referencePayload, P)
%V22_MEASURE  用首尾 m 序列独立定位，统计不经过 FCS 筛选的实验图片 BER。
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
    [frame, positions] = v22_pack(referencePayload);
    reference = v22_payload2img(referencePayload);
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
