function phaseOut=tx_phase_accumulator(frequency,timing,restart)
%#codegen
% 频率积分为相位；像素、颜色分量与处理帧之间均保持相位连续。
persistent phase
if isempty(phase) || restart,phase=0;end
phaseOut=zeros(4800,1);
for k=1:double(timing.valid)
    phaseOut(k)=phase;
    phase=phase+2*pi*frequency(k)/48000;
    if phase>=2*pi,phase=phase-2*pi;end
end
end
