function output = sstv_color(input,direction)
%SSTV_COLOR  满量程 BT.601 RGB 与 Y/Cr/Cb 转换，分量范围 0～255。
% 色度以 128 为中点；采用常见软件的满量程表示，不使用视频限量程 16～235。
    x=double(input);
    if strcmp(direction,'encode')
        y=.299*x(:,:,1)+.587*x(:,:,2)+.114*x(:,:,3);
        output=cat(3,y,128+(x(:,:,1)-y)/1.402,128+(x(:,:,3)-y)/1.772);
    elseif strcmp(direction,'decode')
        y=x(:,:,1);cr=x(:,:,2)-128;cb=x(:,:,3)-128;
        output=cat(3,y+1.402*cr,y-.714136*cr-.344136*cb,y+1.772*cb);
    else
        error('sstv:Color','转换方向必须为 encode 或 decode。');
    end
    output=max(0,min(255,output));
end
