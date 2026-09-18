function frequency=tx_frequency_map(value,timing)
%#codegen
% 图像分量映射到 1500～2300 赫兹；VIS、同步与间隔采用协议指定音调。
frequency=timing.tone;
for k=1:4800
    if timing.component(k)>0,frequency(k)=1500+800*value(k)/255;end
end
end
