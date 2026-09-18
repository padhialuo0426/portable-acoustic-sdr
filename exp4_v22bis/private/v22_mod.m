function [x,sym]=v22_mod(bits,P,backend)
%V22_MOD  保留原内部入口，默认使用纯 MATLAB 发送机。
if nargin<3,backend='matlab';end
[x,sym]=v22_modulate(bits,P,backend);
end
