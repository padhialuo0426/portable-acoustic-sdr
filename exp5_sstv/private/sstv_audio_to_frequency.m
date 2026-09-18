function frequency = sstv_audio_to_frequency(audio,fs,P)
%SSTV_AUDIO_TO_FREQUENCY  与板上链路对应的离线正交下变频与差分鉴频。
    audio=double(audio(:).');
    if fs~=P.fs,audio=resample(audio,P.fs,fs);end
    n=0:numel(audio)-1;
    baseband=filter(P.lowpass,1,audio.*exp(-1i*2*pi*P.centerHz*n/P.fs));
    previous=[0 baseband(1:end-1)];
    frequency=P.centerHz+P.fs/(2*pi)*angle(baseband.*conj(previous));
    frequency(abs(baseband)<P.minimumEnvelope | abs(previous)<P.minimumEnvelope)=0;
end
