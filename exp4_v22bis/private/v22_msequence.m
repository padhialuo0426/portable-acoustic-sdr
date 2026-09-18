function bits = v22_msequence()
%V22_MSEQUENCE  127 位 m 序列，供实验测量的首尾相关定位。
% 多项式 x^7+x^3+1，初始 7 位全 1；递推 b(n+7)=b(n+3) xor b(n)。
    bits = ones(1,127);
    for n = 1:120
        bits(n+7) = xor(bits(n+3),bits(n));
    end
end
