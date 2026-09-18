function frequency = frequency_discriminator(baseband,fc,fs,minimumEnvelope)
%#codegen
% 相邻复样本共轭相乘，取相位差得到瞬时频率；低电平以 0 标为不可用。
persistent previous
if isempty(previous),previous=complex(0);end
frequency=zeros(4800,1);
for k=1:4800
    current=baseband(k);
    if abs(current)>=minimumEnvelope && abs(previous)>=minimumEnvelope
        product=current*conj(previous);
        frequency(k)=fc+fs/(2*pi)*atan2(imag(product),real(product));
    end
    previous=current;
end
end
