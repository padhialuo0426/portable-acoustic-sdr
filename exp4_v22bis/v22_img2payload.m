function [payload, NN, MM] = v22_img2payload(imgdir, name, bps)
%V22_IMG2PAYLOAD  1-bit BMP -> HDLC 帧载荷字节
%
%   载荷格式（4 字节头 + 位图）：
%       [0] 0x22   幻数，标识实验四
%       [1] bps    每符号比特数(4=2400bps, 2=1200bps)，仅作记录
%       [2] 宽(列) [3] 高(行)   —— 故最大支持 255x255
%       [4..]      位图，列优先展开后每 8 bit 打包成 1 字节（低位先）
%
%   列优先与本工程前三个实验一致，换图不用改任何代码。

    im = imread(fullfile(imgdir, name));
    if ~ismatrix(im) || ~all(im(:)==0 | im(:)==1)
        error('发送图片必须为只含 0/1 的单通道二值 BMP。');
    end
    [NN, MM] = size(im);                       % NN=行(高) MM=列(宽)
    if NN > 255 || MM > 255
        error('本实验载荷头用单字节存宽高，图片最大 255x255。');
    end
    b = zeros(1, NN*MM);
    for m = 1:MM
        for n = 1:NN
            b((m-1)*NN+n) = double(im(n,m));   % 列优先
        end
    end
    pad = mod(-numel(b), 8);
    b   = [b zeros(1,pad)];
    nb  = numel(b)/8;
    data = zeros(1, nb, 'uint8');
    for k = 1:nb
        v = uint8(0);
        for i = 1:8
            if b((k-1)*8+i), v = bitset(v, i); end   % 低位先
        end
        data(k) = v;
    end
    payload = [uint8(34), uint8(bps), uint8(MM), uint8(NN), data];
end
