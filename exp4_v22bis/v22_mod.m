function [x, sym] = v22_mod(bits, P)
%V22_MOD  V.22bis 发射：比特流 -> 通带波形
%
%   [x, sym] = v22_mod(bits, P)
%     bits  0/1 向量（HDLC 帧比特，未加扰）
%     P     v22_params 返回的参数结构
%     x     实通带波形（已归一化到 ±1），可直接喂 sound(x, P.fs)
%     sym   调制符号（复基带），供仿真算 EVM 用
%
%   链路：加前导 -> 自同步扰码 -> 差分四象限映射 -> RRC 成形 -> 上变频取实部
%
%   前导是「送进扰码器的全 1」——V.22bis 就是这么做的。全 1 经自同步扰码
%   器出来是伪随机序列，频谱平坦、无直流，正好供接收端做 AGC、定时捕获和
%   载波环牵引；而接收端解扰后看到的又是规整的全 1，不会被误当成数据。

    bits = bits(:).';

    % --- 前导 + 数据 + 后导，一起过扰码器 ---
    pre  = ones(1, P.preambleSyms * P.bps);
    post = ones(1, P.postambleSyms * P.bps);
    src  = [pre, bits, post];

    % 末尾补零凑整符号
    r = mod(numel(src), P.bps);
    if r ~= 0, src = [src, zeros(1, P.bps-r)]; end

    % --- 自同步扰码 GPC = 1 + x^-14 + x^-17 ---
    st = zeros(1, P.scrLen);
    sb = zeros(size(src));
    for i = 1:numel(src)
        v = xor(src(i), xor(st(P.scrTaps(1)), st(P.scrTaps(2))));
        sb(i) = v;
        st = [v st(1:end-1)];
    end

    % --- 差分四象限映射 ---
    Nsym = numel(sb) / P.bps;
    sym  = zeros(1, Nsym);
    q = 0;
    for k = 1:Nsym
        qb = sb((k-1)*P.bps + (1:P.bps));
        hi = qb(1)*2 + qb(2);                    % 前 2 bit -> 象限旋转
        q  = mod(q + P.quadRot(hi+1), 360);
        if P.bps == 4, lo = qb(3)*2 + qb(4); else, lo = 0; end
        sym(k) = P.inQ(lo+1) * exp(1i*q*pi/180);
    end

    % --- RRC 成形 + 上变频 ---
    h  = rcosdesign(P.beta, P.span, P.sps, 'sqrt');
    bb = upfirdn(sym, h, P.sps);
    n  = 0:numel(bb)-1;
    x  = real(bb .* exp(1i*2*pi*P.fc*n/P.fs));
    x  = x / max(abs(x));
end
