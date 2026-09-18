function symbols = timing_recovery(x, sps, frameSymbols)
%#codegen
% 16 个候选抽样相位：按帧平滑幅度和，再选最大者抽取 60 个符号。
% 状态跨帧保留；静噪时也继续更新，保持旧接收机的定时行为。
persistent energy
if isempty(energy),energy=zeros(sps,1);end
SPS=int32(sps);NS=int32(frameSymbols);
for p=1:SPS
    total=0;
    for k=1:NS
        total=total+abs(x(int32(p)+(k-1)*SPS));
    end
    energy(p)=0.9*energy(p)+0.1*total;
end
phase=int32(1);best=energy(1);
for p=2:SPS
    if energy(p)>best,best=energy(p);phase=int32(p);end
end
symbols=complex(zeros(frameSymbols,1));
for k=1:NS,symbols(k)=x(phase+(k-1)*SPS);end
end
