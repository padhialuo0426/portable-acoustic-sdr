function report = v22_diagnose(bits, referencePayload)
%V22_DIAGNOSE  区分解帧失败阶段，并在边界明确时比较校验前图片比特。
% 参考载荷只用于诊断与 BER；不修复帧、不放宽 FCS，也不选择最像参考的帧。
    [frames, detail] = v22_unpack(bits);
    report = struct('hdlc',detail,'status','','message','', ...
        'image',[],'frameRange',[],'invalidImages',0, ...
        'diagnostic',struct('available',false,'reason','','errors',NaN, ...
                            'bits',0,'ber',NaN,'frameIndex',[]));

    for k = find([frames.ok])
        try
            candidate = v22_payload2img(frames(k).payload);
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

    % 两端 HDLC 标志、合法去填充、整字节均由 v22_unpack 保证。
    % 再要求完整的 4 字节图片头和载荷长度与参考相同，且候选唯一。
    % 不扫描参考图寻找最小误码窗口，不将误识别或长度损坏强行对齐。
    referencePayload = uint8(referencePayload(:).');
    referenceImage = v22_payload2img(referencePayload);
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
        candidate = v22_payload2img(frames(matched).payload);
        count = sum(candidate(:) ~= referenceImage(:));
        report.diagnostic = struct('available',true,'reason','', ...
            'errors',count,'bits',numel(referenceImage), ...
            'ber',count/numel(referenceImage),'frameIndex',matched);
    end
end
