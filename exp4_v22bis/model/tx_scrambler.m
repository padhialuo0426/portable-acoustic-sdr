function output=tx_scrambler(bits,active,bps,scrTaps)
%#codegen
% 自同步扰码：当前信息位异或第 14 与第 17 个历史输出。
persistent state
if isempty(state),state=false(1,17);end
output=zeros(4,1);
if ~active,return,end
for k=1:bps
 value=xor(bits(k)~=0,xor(state(scrTaps(1)),state(scrTaps(2))));
 output(k)=double(value);state=[value state(1:end-1)];
end
end
