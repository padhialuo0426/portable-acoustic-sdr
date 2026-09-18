function result=sstv_wav_decode(wavFile)
%SSTV_WAV_DECODE  从单声道或立体声录音识别 VIS 并还原 Martin M1 图片。
    if nargin<1,wavFile='sstv_tx.wav';end
    [audio,fs]=audioread(wavFile);audio=mean(audio,2);P=sstv_params();
    result=sstv_decode_frequency(sstv_audio_to_frequency(audio,fs,P),P);
    fprintf('%s\n',result.message);
    if ~isempty(result.image),figure;image(result.image);axis image off;title(result.message);end
end
