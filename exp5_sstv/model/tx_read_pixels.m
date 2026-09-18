function pixels=tx_read_pixels(image,address)
%#codegen
% 读取当前像素和伙伴行同列像素。图片以 616×800×3 列优先数组存储。
pixels=struct('rgb',zeros(4800,3),'otherRGB',zeros(4800,3), ...
    'component',address.component,'color',address.color,'pair',address.pair);
for k=1:4800
    if address.component(k)==0,continue,end
    for ch=1:3
        base=616*(double(address.column(k))-1)+616*800*(ch-1);
        pixels.rgb(k,ch)=double(image(base+double(address.row(k))));
        if address.pair
            pixels.otherRGB(k,ch)=double(image(base+double(address.other(k))));
        end
    end
end
end
