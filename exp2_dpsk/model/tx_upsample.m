function pulse=tx_upsample(symbol)
%#codegen
% 每符号 80 点，首点放置脉冲，其余补零。
pulse=zeros(80,1);pulse(1)=symbol;
end
