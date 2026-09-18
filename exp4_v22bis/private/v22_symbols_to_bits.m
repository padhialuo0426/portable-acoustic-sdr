function bits = v22_symbols_to_bits(sym, Pm)
%V22_SYMBOLS_TO_BITS  模型输出复符号的判决、差分解码和自同步解扰。
    sym = sym(:).';
    dec = zeros(1, numel(sym)*Pm.bps);  qp = 0;
    for k = 1:numel(sym)
        z = sym(k);
        if     real(z)>=0 && imag(z)>=0, qi = 0;
        elseif real(z)< 0 && imag(z)>=0, qi = 1;
        elseif real(z)< 0 && imag(z)< 0, qi = 2;
        else,                            qi = 3;
        end
        p1 = z * exp(-1i*90*qi*pi/180);
        [~, li] = min(abs(p1 - Pm.inQ));
        dq = mod(90*qi - qp, 360);  qp = 90*qi;
        hi = find(Pm.quadRot == dq, 1) - 1;
        if Pm.bps == 4
            dec((k-1)*4+(1:4)) = [bitget(hi,2) bitget(hi,1) bitget(li-1,2) bitget(li-1,1)];
        else
            dec((k-1)*2+(1:2)) = [bitget(hi,2) bitget(hi,1)];
        end
    end
    st = zeros(1, Pm.scrLen);  bits = zeros(size(dec));
    for i = 1:numel(dec)
        bits(i) = xor(dec(i), xor(st(Pm.scrTaps(1)), st(Pm.scrTaps(2))));
        st = [dec(i) st(1:end-1)];
    end
end
