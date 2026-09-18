function audio=tx_carrier(baseband,fc)
%#codegen
% 复基带上变频为实通带音频，载波相位跨符号连续。
persistent sample
if isempty(sample),sample=0;end
audio=real(baseband.*exp(1i*2*pi*fc*(sample+(0:15)')/9600));sample=sample+16;
end
