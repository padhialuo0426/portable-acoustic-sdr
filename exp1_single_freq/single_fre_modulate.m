function audio=single_fre_modulate(fc,samples,amplitude,backend)
%SINGLE_FRE_MODULATE  单频音频；backend 默认 matlab，可选 simulink。
if nargin<3,amplitude=1;end
validateattributes(fc,{'numeric'},{'scalar','real','finite','positive','<',4000});
validateattributes(samples,{'numeric'},{'scalar','integer','positive'});
validateattributes(amplitude,{'numeric'},{'scalar','real','finite'});
if nargin<4,backend='matlab';end
backend=validatestring(backend,{'matlab','simulink'});
if strcmp(backend,'matlab')
 audio=single_fre_modulate_matlab(fc,samples,amplitude);
 return
end
here=fileparts(mfilename('fullpath'));addpath(fullfile(here,'..','common','matlab'));
out=asdr.TxModel.run(here,'single_fre_transmit',struct('fc',fc,'amplitude',amplitude),.01,ceil(samples/80));
audio=asdr.TxModel.audio(out,80,samples,false);
end
