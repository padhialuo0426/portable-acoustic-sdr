function [result,metrics]=sstv_rev(matFile,referenceFile)
%SSTV_REV  解码接收机的 sstvfreq.mat；有发送参考时额外计算图片质量。
    here=fileparts(mfilename('fullpath'));
    if nargin<1,matFile=fullfile(here,'sstvfreq.mat');end
    if nargin<2,referenceFile=fullfile(here,'sstv_reference.mat');end
    P=sstv_params();S=load(matFile);
    if ~isfield(S,'sstvFreq'),error('sstv:Data','文件缺少 sstvFreq。');end
    validateattributes(S.sstvFreq,{'numeric'},{'2d','nrows',P.frameSamples+1,'nonempty','real','finite'});
    f=reshape(S.sstvFreq(2:end,:),1,[]);result=sstv_decode_frequency(f,P);
    metrics=[];fprintf('%s\n',result.message);
    if ~isempty(result.image)
        figure;image(result.image);axis image off;title(result.message);
        if isfile(referenceFile)
            R=load(referenceFile);metrics=sstv_metrics(result,R.image,R.binary);
            fprintf('有效行 MAE %.3f，PSNR %.2f dB\n',metrics.mae,metrics.psnr);
            if R.binary,fprintf('二值像素误差率 %d/%d = %.6f\n',metrics.pixelErrors,metrics.pixels,metrics.pixelErrorRate);end
        end
    end
end
