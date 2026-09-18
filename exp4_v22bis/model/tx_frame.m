function [bits,active]=tx_frame(frameBits,bps,preamble,postamble,syncBits,syncGuard,syncLength)
%#codegen
% 已组装的 HDLC 比特外，加入前后导及用于实验测量的首尾 m 序列。
persistent symbolIndex
if isempty(symbolIndex),symbolIndex=0;end
nSync=syncLength;nFrame=numel(frameBits);pre=preamble*bps;
total=pre+2*nSync+2*syncGuard+nFrame+postamble*bps;
active=symbolIndex<ceil(total/bps);bits=zeros(4,1);
for k=1:bps
 index=symbolIndex*bps+k;value=1;
 if index>total,value=0;
 elseif index>pre
  index=index-pre;
  if index<=nSync,value=syncBits(index);
  elseif index<=nSync+syncGuard,value=1;
  elseif index<=nSync+syncGuard+nFrame,value=frameBits(index-nSync-syncGuard);
  elseif index<=nSync+2*syncGuard+nFrame,value=1;
  elseif index<=2*nSync+2*syncGuard+nFrame,value=syncBits(index-nSync-2*syncGuard-nFrame);
  end
 end
 bits(k)=value;
end
symbolIndex=symbolIndex+1;
end
