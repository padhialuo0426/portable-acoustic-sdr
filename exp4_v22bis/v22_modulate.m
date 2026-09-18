function [x,sym]=v22_modulate(bits,P)
%V22_MODULATE  直接仿真发送模型，HDLC 比特经过同步扩展、扰码、映射和成形。
if nargin<2,P=v22_params();end
validateattributes(bits,{'numeric','logical'},{'vector','nonempty','real','finite'});
assert(all(bits==0 | bits==1),'帧必须是二值比特。');
assert(P.fs==9600 && P.sps==16 && P.Rs==600,'采样率或符号率变化后需同步修改发送模型。');
here=fileparts(mfilename('fullpath'));addpath(fullfile(here,'..','common','matlab'));
sync=[];guard=0;if isfield(P,'syncBits'),sync=P.syncBits;guard=P.syncGuard;end
syncData=sync;if isempty(syncData),syncData=0;end % 参数保留存储空间，长度单独传入。
points=complex(zeros(1,4));points(1:numel(P.inQ))=P.inQ;
values=struct('frameBits',double(bits(:).'),'bps',P.bps,'preamble',P.preambleSyms, ...
 'postamble',P.postambleSyms,'syncBits',syncData,'syncGuard',guard,'syncLength',numel(sync), ...
 'scrTaps',P.scrTaps,'quadRot',P.quadRot,'inQ',points,'fc',P.fc, ...
 'rrc',rcosdesign(P.beta,P.span,P.sps,'sqrt'));
n=ceil((numel(bits)+2*numel(sync)+2*guard)/P.bps)+P.preambleSyms+P.postambleSyms;
samples=(n-1)*P.sps+numel(values.rrc);
out=asdr.TxModel.run(here,'v22_transmit',values,1/P.Rs,ceil(samples/P.sps));
x=asdr.TxModel.audio(out,P.sps,samples,true);
symbols=out.get('txSymbols');sym=reshape(symbols(1:n),1,[]);
end
