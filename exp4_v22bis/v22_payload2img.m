function [img, NN, MM] = v22_payload2img(payload)
%V22_PAYLOAD2IMG  HDLC 帧载荷 -> 位图（v22_img2payload 的逆）

    if numel(payload) < 4 || payload(1) ~= 34
        error('载荷头不对（幻数应为 0x22），这帧不是实验四的图片帧。');
    end
    MM = double(payload(3));  NN = double(payload(4));
    data = payload(5:end);
    need = ceil(NN*MM/8);
    if numel(data) < need
        error('载荷字节不足：需要 %d，实得 %d。', need, numel(data));
    end
    b = zeros(1, numel(data)*8);
    for k = 1:numel(data)
        for i = 1:8
            b((k-1)*8+i) = bitget(data(k), i);   % 低位先
        end
    end
    img = zeros(NN, MM);
    for m = 1:MM
        for n = 1:NN
            img(n,m) = b((m-1)*NN+n);            % 列优先
        end
    end
end
