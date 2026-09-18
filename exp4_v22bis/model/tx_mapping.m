function symbol=tx_mapping(bits,active,bps,quadRot,inQ)
%#codegen
% 前两位控制相对旋转；16-QAM 后两位选择象限内幅度。
persistent quadrant
if isempty(quadrant),quadrant=0;end
symbol=complex(0);
if ~active,return,end
hi=2*bits(1)+bits(2);quadrant=mod(quadrant+quadRot(hi+1),360);
lo=0;if bps==4,lo=2*bits(3)+bits(4);end
symbol=inQ(lo+1)*exp(1i*quadrant*pi/180);
end
