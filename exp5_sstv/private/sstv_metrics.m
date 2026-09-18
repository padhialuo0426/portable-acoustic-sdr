function metrics=sstv_metrics(result,reference,binary)
%SSTV_METRICS  只对本次完整还原的行比较像素，不把缺失行当作零误差。
    metrics=struct('available',false,'psnr',NaN,'mae',NaN,'pixelErrors',NaN,'pixels',0,'pixelErrorRate',NaN);
    if isempty(result.image) || ~any(result.validRows) || ~isequal(size(reference),size(result.image)),return,end
    received=double(result.image(result.validRows,:,:));ref=double(reference(result.validRows,:,:));
    difference=received-ref;mse=mean(difference(:).^2);
    metrics.available=true;metrics.psnr=10*log10(255^2/mse);metrics.mae=mean(abs(difference(:)));
    if binary
        errors=(mean(received,3)>=127.5)~=(mean(ref,3)>=127.5);
        metrics.pixelErrors=sum(errors(:));metrics.pixels=numel(errors);metrics.pixelErrorRate=mean(errors(:));
    end
end
