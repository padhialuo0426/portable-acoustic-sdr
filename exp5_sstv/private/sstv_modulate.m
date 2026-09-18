function [audio,meta] = sstv_modulate(image,P,backend)
%SSTV_MODULATE  SSTV 音频；backend 默认 matlab，可选 simulink。
    if nargin<3,backend='matlab';end
    backend=validatestring(backend,{'matlab','simulink'});
    if strcmp(backend,'matlab')
        [audio,meta]=sstv_modulate_matlab(image,P);
    else
        [audio,meta]=sstv_simulate_transmitter(image,P);
    end
end
