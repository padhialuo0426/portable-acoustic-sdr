function meta=sstv_emit(imageFile,binary,playAudio,mode,backend)
%SSTV_EMIT  SSTV 发射，默认二值化、Martin M1；第四参数选择模式。
% sstv_emit('照片.png',false,false,'PD120') 保留彩色并只生成文件。
% 第五参数默认 'matlab'，设为 'simulink' 时直接仿真发送模型。
    here=fileparts(mfilename('fullpath'));
    if nargin<1,imageFile=fullfile(here,'baseband_images','ren512b.bmp');end
    if nargin<2,binary=true;end
    if nargin<3,playAudio=true;end
    if nargin<4,mode='M1';end
    if nargin<5,backend='matlab';end
    P=sstv_params(mode);image=sstv_prepare_image(imageFile,binary,P);
    [audio,meta]=sstv_modulate(image,P,backend);meta.binary=binary;meta.source=imageFile;
    meta.backend=backend;
    audiowrite(fullfile(here,'sstv_tx.wav'),.8*audio,P.fs,'BitsPerSample',16);
    file=fopen(fullfile(here,'sstv_tx.raw'),'wb');
    assert(file>=0,'sstv:Output','无法创建 sstv_tx.raw。');
    guard=onCleanup(@()fclose(file));
    fwrite(file,int16(round(.8*audio*32767)),'int16');
    clear guard
    mode=P.id;save(fullfile(here,'sstv_reference.mat'),'image','binary','mode');
    fprintf('%s：%d×%d，VIS %d；完整音频 %.3f 秒。\n',P.mode,P.width,P.height,P.vis,meta.duration);
    fprintf('接收端先运行：./build/sstv_rx -d plughw:X,0 -t %d\n',ceil(meta.duration)+5);
    if playAudio,sound([zeros(1,P.fs) .8*audio zeros(1,round(.3*P.fs))],P.fs);end
end
