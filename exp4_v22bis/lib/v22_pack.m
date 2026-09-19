function [bits, payloadPositions] = v22_pack(payload)
%V22_PACK  把一段字节按 HDLC 组成一帧（V.42 LAPM 的简化形式）
%
%   bits = v22_pack(payload)   payload 为 uint8 向量，返回 0/1 行向量。
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
%   FCS 低字节先发（X.25 规定），接收端 v22_unpack 按同样顺序取回。

    payload = uint8(payload(:)).';
    fcs  = v22_crc16(payload);
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
