function symbol=tx_differential(bit,active)
%#codegen
% 当前相位由信息位与上一相位异或得到；冲洗滤波器时输出零。
persistent state
if isempty(state),state=false;end
symbol=0;
if active,state=xor(bit~=0,state);symbol=1-2*double(state);end
end
