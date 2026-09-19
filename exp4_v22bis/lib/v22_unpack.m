function [frames, detail] = v22_unpack(bits)
%V22_UNPACK  从一条连续比特流里找出所有 HDLC 帧并校验 FCS
%
%   frames = v22_unpack(bits)   bits 为 0/1 向量（板上解扰后的判决流）。
%   返回结构体数组，每个元素：
%       .payload  uint8 行向量（已去 FCS）
%       .ok       logical，FCS 是否通过
%       .pos      该帧起始标志在 bits 中的下标
%       .endPos   该帧结束标志最后一位的下标（含标志和位填充的原始位置）
%   第二输出 detail 统计各阶段结果；未通过格式检查的区间不计入 frames。
%
%   本函数只处理 HDLC 边界、位填充与 FCS；外层 m 序列由 v22_measure 定位。
%   v22_diagnose 优先在 m 序列确定的窗口中调用本函数，定位失败时也可扫描全流。
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
                               'ok', got == v22_crc16(payload), ...
                               'pos', loc(j), 'endPos', loc(j+1)+7); %#ok<AGROW>
    end
    detail.candidateCount = numel(frames);
    detail.fcsPassed = sum([frames.ok]);
    detail.fcsFailed = detail.candidateCount - detail.fcsPassed;
end
