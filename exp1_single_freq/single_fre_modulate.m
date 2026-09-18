function audio=single_fre_modulate(fc,samples,amplitude)
%SINGLE_FRE_MODULATE  直接仿真单频发送模型，按指定采样数取出音频。
if nargin<3,amplitude=1;end
validateattributes(fc,{'numeric'},{'scalar','real','finite','positive','<',4000});
validateattributes(samples,{'numeric'},{'scalar','integer','positive'});
validateattributes(amplitude,{'numeric'},{'scalar','real','finite'});
here=fileparts(mfilename('fullpath'));addpath(fullfile(here,'..','common','matlab'));
out=asdr.TxModel.run(here,'single_fre_transmit',struct('fc',fc,'amplitude',amplitude),.01,ceil(samples/80));
audio=asdr.TxModel.audio(out,80,samples,false);
end
