function audio=chirp_modulate(imageBits,backend)
%CHIRP_MODULATE  chirp 音频；backend 默认 matlab，可选 simulink。
validateattributes(imageBits,{'numeric','logical'},{'vector','nonempty','real','finite'});
assert(all(imageBits==0 | imageBits==1),'图片数据必须是二值比特。');
if nargin<2,backend='matlab';end
backend=validatestring(backend,{'matlab','simulink'});
if strcmp(backend,'matlab')
 % 输入结构由下面的独立脚本在当前工作区读取。
 sdrTxRequest=struct('imageBits',imageBits); %#ok<NASGU>
 run(fullfile(fileparts(fileparts(mfilename('fullpath'))),'bok_emit.m'));
 audio=LFM;
 return
end
here=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(here,'..','common','matlab'));
values=struct('imageBits',double(imageBits(:).'));
count=numel(imageBits)+55;samples=count*800;
out=asdr.TxModel.run(here,'chirp_transmit',values,0.1,ceil(samples/800));
audio=asdr.TxModel.audio(out,800,samples,false);
end
