function value=tx_chroma_average(encoded)
%#codegen
% 仅 Robot 36 与 PD 的色差共享两行，亮度及其他模式直接通过。
value=encoded.value;
for k=1:4800
    if encoded.average(k),value(k)=(value(k)+encoded.other(k))/2;end
end
end
