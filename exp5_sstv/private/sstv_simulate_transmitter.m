function [audio,meta]=sstv_simulate_transmitter(image,P)
%SSTV_SIMULATE_TRANSMITTER  向发送模型提供图片，收集连续音频并去掉末帧补零。
    validateattributes(image,{'uint8'},{'size',[P.height P.width 3]});
    here=fileparts(fileparts(mfilename('fullpath')));mdl='sstv_transmit';
    load_system(fullfile(here,[mdl '.slx']));
    padded=zeros(616,800,3,'uint8');padded(1:P.height,1:P.width,:)=image;
    inputs=Simulink.SimulationData.Dataset;
    inputs=inputs.addElement(timeseries(padded(:).',0),'ImageIn');
    inputs=inputs.addElement(timeseries(uint8(P.vis),0),'ModeVIS');
    inputs=inputs.addElement(timeseries([true;false],[0;.1]),'Restart');
    frames=ceil(round(P.duration*P.fs)/P.frameSamples);
    in=Simulink.SimulationInput(mdl);in=in.setExternalInput(inputs);
    in=in.setModelParameter('StopTime',sprintf('%.12g',(frames-1)*.1),'ReturnWorkspaceOutputs','on');
    output=sim(in);data=output.get('txAudio');counts=double(output.get('txCount'));
    assert(size(data,1)==P.frameSamples && numel(data)==P.frameSamples*frames ...
        && numel(counts)==frames,'sstv:Model','发送模型输出尺寸异常。');
    audio=reshape(data,1,[]);audio=audio(1:sum(counts));
    assert(numel(audio)==round(P.duration*P.fs),'sstv:Model','模型与模式表时长不一致；请重建发送模型。');
    meta=struct('mode',P.mode,'vis',P.vis,'samples',numel(audio),'duration',numel(audio)/P.fs,'image',image);
end
