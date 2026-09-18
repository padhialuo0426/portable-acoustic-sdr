function baseband = downconvert(audio,fc,fs)
%#codegen
% 相位连续地把音频移到以 1900 Hz 为中心的复基带，跨帧保存本振相位。
persistent phase
if isempty(phase),phase=0;end
baseband=complex(zeros(4800,1));
for k=1:4800
    baseband(k)=audio(k)*complex(cos(phase),-sin(phase));
    phase=phase+2*pi*fc/fs;
    if phase>=2*pi,phase=phase-2*pi;end
end
end
