function meta=sstv_emit(imageFile,binary,playAudio)
%SSTV_EMIT  Martin M1 发射；默认将自带图片二值化，保存 WAV/PCM 后播放。
% sstv_emit('照片.png',false) 保留彩色；第三参数 false 只生成文件。
    here=fileparts(mfilename('fullpath'));
    if nargin<1,imageFile=fullfile(here,'baseband_images','ren512b.bmp');end
    if nargin<2,binary=true;end
    if nargin<3,playAudio=true;end
    P=sstv_params();image=sstv_prepare_image(imageFile,binary,P);
    [audio,meta]=sstv_modulate(image,P);meta.binary=binary;meta.source=imageFile;
    audiowrite(fullfile(here,'sstv_tx.wav'),.8*audio,P.fs,'BitsPerSample',16);
    file=fopen(fullfile(here,'sstv_tx.raw'),'wb');
    assert(file>=0,'sstv:Output','无法创建 sstv_tx.raw。');
    guard=onCleanup(@()fclose(file));
    fwrite(file,int16(round(.8*audio*32767)),'int16');
    clear guard
    save(fullfile(here,'sstv_reference.mat'),'image','binary');
    fprintf('Martin M1：320×256，VIS 44，G/B/R；完整音频 %.3f 秒。\n',meta.duration);
    fprintf('接收端先运行：./build/sstv_rx -d plughw:X,0 -t %d\n',ceil(meta.duration)+5);
    if playAudio,sound([zeros(1,P.fs) .8*audio zeros(1,round(.3*P.fs))],P.fs);end
end
