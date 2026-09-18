function audio=chirp_modulate_matlab(imageBits)
%CHIRP_MODULATE_MATLAB  原脚本逐符号生成上扫频或下扫频的实部。
imageBits=double(imageBits(:).');
mseq=[1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
info=[zeros(1,10) repmat([1 0],1,5) mseq imageBits mseq zeros(1,5)];
t=linspace(0,.1,800); % 与原脚本一致，保留符号末端采样点。
audio=zeros(1,numel(info)*800);
for k=1:numel(info)
    slope=1-2*info(k);
    audio((k-1)*800+(1:800))=real(exp(1i*(2*pi*1000*t+pi*slope*2000*t.^2)));
end
end
