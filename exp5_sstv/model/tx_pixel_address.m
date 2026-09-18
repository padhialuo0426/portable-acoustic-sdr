function address=tx_pixel_address(timing)
%#codegen
% 扫描行组和段内时间转换为像素地址；双行模式另给出共享色差的伙伴行。
address=struct('row',zeros(4800,1,'uint16'),'column',zeros(4800,1,'uint16'), ...
    'other',zeros(4800,1,'uint16'),'component',timing.component,'color',timing.color,'pair',timing.pair);
for k=1:4800
    if timing.component(k)==0,continue,end
    row=(double(timing.unit(k))-1)*timing.rowsPerUnit+1;
    if timing.component(k)==4,row=row+1;address.component(k)=uint8(1);end
    address.row(k)=uint16(row);
    address.column(k)=uint16(max(1,min(timing.width,1+floor(timing.elapsed(k)/(timing.duration(k)/timing.width)))));
    other=2*floor((row-1)/2)+1;if other==row,other=other+1;end
    address.other(k)=uint16(other);
end
end
