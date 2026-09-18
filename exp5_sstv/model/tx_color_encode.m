function encoded=tx_color_encode(pixels)
%#codegen
% 选择 RGB 分量，或按全范围亮度/色差公式编码；限幅后再交给双行平均。
encoded=struct('value',zeros(4800,1),'other',zeros(4800,1),'average',false(4800,1));
for k=1:4800
    ch=double(pixels.component(k));if ch==0,continue,end
    if pixels.color==0
        encoded.value(k)=pixels.rgb(k,ch);
    else
        encoded.value(k)=color(pixels.rgb(k,:),ch);
        encoded.average(k)=pixels.pair && ch>1;
        if encoded.average(k),encoded.other(k)=color(pixels.otherRGB(k,:),ch);end
    end
end
end
function value=color(rgb,ch)
y=.299*rgb(1)+.587*rgb(2)+.114*rgb(3);
if ch==1,value=y;
elseif ch==2,value=128+(rgb(1)-y)/1.402;
else,value=128+(rgb(3)-y)/1.772;
end
value=max(0,min(255,value));
end
