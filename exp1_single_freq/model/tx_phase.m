function phase=tx_phase(fc)
%#codegen
% 每次推进 80 个采样，相位沿整段波形连续。
persistent sample
if isempty(sample),sample=0;end
phase=2*pi*fc*(sample+(0:79)')/8000;sample=sample+80;
end
