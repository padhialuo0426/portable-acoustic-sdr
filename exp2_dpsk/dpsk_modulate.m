function audio=dpsk_modulate(imageBits)
%DPSK_MODULATE  GUI 与发送脚本共用的 Simulink 发送入口。
validateattributes(imageBits,{'numeric','logical'},{'vector','nonempty','real','finite'});
assert(all(imageBits==0 | imageBits==1),'图片数据必须是二值比特。');
here=fileparts(mfilename('fullpath'));addpath(fullfile(here,'..','common','matlab'));
values=struct('imageBits',double(imageBits(:).'));
count=numel(imageBits)+136;samples=count*80 +159;
out=asdr.TxModel.run(here,'dpsk_transmit',values,0.01,ceil(samples/80));
audio=asdr.TxModel.audio(out,80,samples,true);
end
