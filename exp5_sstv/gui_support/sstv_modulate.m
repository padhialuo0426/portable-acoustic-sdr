function [audio,meta] = sstv_modulate(image,P,backend,binary)
%SSTV_MODULATE  SSTV 波形适配；MATLAB 分支运行独立顺序脚本。
    if nargin<3,backend='matlab';end
    if nargin<4,binary=false;end
    backend=validatestring(backend,{'matlab','simulink'});
    if strcmp(backend,'matlab')
        % 文件输入走脚本自己的图片处理与模式表；数组输入已含所需像素。
        if isa(image,'uint8')
            sdrTxRequest=struct('image',image,'parameters',P,'mode',P.id,'binary',binary);
        else
            sdrTxRequest=struct('imageFile',image,'mode',P.id,'binary',binary);
        end
        x=[];meta=struct;
        run(fullfile(fileparts(fileparts(mfilename('fullpath'))),'sstv_emit.m'));
        audio=x;
    else
        [audio,meta]=sstv_simulate_transmitter(image,P);
    end
end
