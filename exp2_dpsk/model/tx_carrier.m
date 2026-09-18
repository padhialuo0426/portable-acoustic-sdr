function audio=tx_carrier(baseband)
%#codegen
% 成形基带乘以连续的 1000 赫兹正弦载波。
persistent sample
if isempty(sample),sample=0;end
audio=baseband.*sin(2*pi*1000*(sample+(0:79)')/8000);sample=sample+80;
end
