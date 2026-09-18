function y = downconvert(x, fc, fs)
%#codegen
% 连续相位下变频：输入实数采样帧，输出同长度复基带。
persistent phase
if isempty(phase), phase=0; end
step=2*pi*fc/fs;
y=complex(zeros(size(x)));
for k=1:numel(x)
    y(k)=x(k)*complex(cos(-phase),sin(-phase))*2;
    phase=phase+step;
    if phase>2*pi,phase=phase-2*pi;end
end
end
