function meta=sstv_emit_simulink(imageFile,binary,playAudio,mode)
%SSTV_EMIT_SIMULINK  独立调用 SSTV 发送模型，默认二值化、Martin M1。
% sstv_emit_simulink('照片.png',false,false,'PD120') 保留彩色并只生成文件。
% 不调用纯 MATLAB 发送脚本；无需生成发送 C。
    here=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(here,'lib'));
    if nargin<1,imageFile=fullfile(here,'baseband_images','ren512b.bmp');end
    if nargin<2,binary=true;end
    if nargin<3,playAudio=true;end
    if nargin<4,mode='M1';end
    P=sstv_params(mode);image=sstv_prepare_image(imageFile,binary,P);
    [audio,meta]=sstv_simulate_transmitter(image,P);meta.binary=binary;meta.source=imageFile;
    meta.backend='simulink';
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
