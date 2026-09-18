function [symbols, carrierPresent] = agc_squelch(x, rxRate, refMagnitude, squelch)
%#codegen
% 按当前 60 符号帧归一化；门限以下输出零，并通知载波环复位。
meanMagnitude=0;
for k=1:numel(x),meanMagnitude=meanMagnitude+abs(x(k));end
meanMagnitude=meanMagnitude/double(numel(x));
carrierPresent=meanMagnitude>squelch;
% QPSK 为单位圆；16-QAM 保留原有平均幅度。
if rxRate==1200,refMagnitude=1;end
if carrierPresent,gain=refMagnitude/meanMagnitude;else,gain=0;end
symbols=complex(zeros(size(x)));
for k=1:numel(x),symbols(k)=x(k)*gain;end
end
