function c = v22_crc16(bytes)
%V22_CRC16  CRC-16/X.25（即 HDLC/V.42 的 FCS-16）
%
%   c = v22_crc16(bytes)   bytes 为 uint8 向量，返回 uint16 校验和。
%
%   参数（ITU-T X.25 / V.42 规定）：
%     多项式 0x1021，按位反射后为 0x8408（因为 HDLC 是低位先发）
%     初值 0xFFFF，输入输出均反射，最后异或 0xFFFF
%
%   标准校验值：v22_crc16(uint8('123456789')) == 0x906E
%   （本文件末尾的自检就是跑这一条）

    c = uint16(65535);                       % 0xFFFF
    for k = 1:numel(bytes)
        c = bitxor(c, uint16(bytes(k)));
        for b = 1:8
            if bitand(c, 1)
                c = bitxor(bitshift(c, -1), uint16(33800));   % 0x8408
            else
                c = bitshift(c, -1);
            end
        end
    end
    c = bitxor(c, uint16(65535));
end
