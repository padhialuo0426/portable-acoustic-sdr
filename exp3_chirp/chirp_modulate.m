function audio=chirp_modulate(imageBits)
%CHIRP_MODULATE  GUI 与发送脚本共用的 Simulink 发送入口。
validateattributes(imageBits,{'numeric','logical'},{'vector','nonempty','real','finite'});
assert(all(imageBits==0 | imageBits==1),'图片数据必须是二值比特。');
here=fileparts(mfilename('fullpath'));addpath(fullfile(here,'..','common','matlab'));
values=struct('imageBits',double(imageBits(:).'));
count=numel(imageBits)+55;samples=count*800;
out=asdr.TxModel.run(here,'chirp_transmit',values,0.1,ceil(samples/800));
audio=asdr.TxModel.audio(out,800,samples,false);
end
