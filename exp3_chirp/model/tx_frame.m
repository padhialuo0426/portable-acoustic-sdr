function [bit,active]=tx_frame(imageBits)
%#codegen
% 前导、交替段、首尾 m 序列、图片比特及尾部保护，均在模型内产生。
persistent index
if isempty(index),index=1;end
mseq=[1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];alternate=[1 0 1 0 1 0 1 0 1 0];
L=numel(imageBits);active=index<=50+L+5;bit=0;
if index>=11 && index<21,bit=alternate(index-10);
elseif index>=21 && index<36,bit=mseq(index-20);
elseif index>=36 && index<36+L,bit=imageBits(index-35);
elseif index>=36+L && index<51+L,bit=mseq(index-35-L);
end
index=index+1;
end
