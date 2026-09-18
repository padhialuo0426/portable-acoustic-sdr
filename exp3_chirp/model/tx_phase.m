function phase=tx_phase(slope)
%#codegen
% 每符号从零相位开始；保留原实现的 800 点闭区间扫描网格。
t=linspace(0,.1,800)';phase=2*pi*1000*t+pi*slope*2000*t.^2;
end
