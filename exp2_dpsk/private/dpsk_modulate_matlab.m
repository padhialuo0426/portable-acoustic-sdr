function audio=dpsk_modulate_matlab(imageBits)
%DPSK_MODULATE_MATLAB  原脚本的组帧、差分编码、成形与载波调制。
imageBits=double(imageBits(:).');
mseq=[1 0 0 1 1 0 1 0 1 1 1 1 0 0 0];
info=[zeros(1,18) repmat([0 1],1,4) mseq imageBits mseq zeros(1,80)];
symbols=1-2*mod(cumsum(info),2);
% 保留原脚本的 160 抽头与采样位置，包括可去奇点处的 eps。
z=(1:160)/80-1+eps;beta=.5;
t1=cos((1+beta)*pi*z);t2=sin((1-beta)*pi*z);t3=1./(4*beta*z);
h=(4*beta/(pi*sqrt(.01)))*(t1+t2.*t3)./(1-16*beta*beta*z.*z);
baseband=conv(upsample(symbols,80),h);
audio=baseband.*sin(2*pi*1000*(0:numel(baseband)-1)/8000);
audio=audio/max(abs(audio));
end
