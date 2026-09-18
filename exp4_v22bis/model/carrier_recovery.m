function symbols = carrier_recovery(x, carrierPresent, Kp, Ki)
%#codegen
% 二阶判决引导载波环。输出校正后的实收符号，不输出理想判决点。
% 每个符号更新环路；跨帧保存相位/积分，仅在静噪或重新捕获时复位。
persistent phase integral wasActive
if isempty(phase),phase=0;integral=0;wasActive=false;end
if ~carrierPresent || ~wasActive,phase=0;integral=0;end
wasActive=carrierPresent;
reference=[1+1i,3+1i,1+3i,3+3i];
symbols=complex(zeros(size(x)));
for k=1:numel(x)
    z=x(k)*complex(cos(-phase),sin(-phase));
    re=real(z);im=imag(z);
    if re>=0 && im>=0,quadrant=0;
    elseif re<0 && im>=0,quadrant=1;
    elseif re<0 && im<0,quadrant=2;
    else,quadrant=3;
    end
    a=-pi/2*double(quadrant);
    firstQuadrant=z*complex(cos(a),sin(a));
    bestIndex=1;bestDistance=inf;
    for q=1:4
        distance=abs(firstQuadrant-reference(q));
        if distance<bestDistance,bestDistance=distance;bestIndex=q;end
    end
    decision=reference(bestIndex)*complex(cos(-a),sin(-a));
    error=angle(z*conj(decision));
    integral=integral+Ki*error;
    phase=phase+Kp*error+integral;
    symbols(k)=z;
end
end
