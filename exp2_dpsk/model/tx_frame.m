function [bit,active]=tx_frame(imageBits)
%#codegen
% 前导、交替段、首尾 m 序列、图片比特及尾部保护，均在模型内产生。
persistent index
if isempty(index),index=1;end
mseq=[1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];alternate=[0 1 0 1 0 1 0 1];
L=numel(imageBits);active=index<=56+L+80;bit=0;
if index>=19 && index<27,bit=alternate(index-18);
elseif index>=27 && index<42,bit=mseq(index-26);
elseif index>=42 && index<42+L,bit=imageBits(index-41);
elseif index>=42+L && index<57+L,bit=mseq(index-41-L);
end
index=index+1;
end
