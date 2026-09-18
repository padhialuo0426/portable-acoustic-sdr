function [x,sym]=v22_mod(bits,P)
%V22_MOD  保留原内部入口，统一调用 Simulink 发送机。
[x,sym]=v22_modulate(bits,P);
end
