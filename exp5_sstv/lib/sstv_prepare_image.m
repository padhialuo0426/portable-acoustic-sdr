function image = sstv_prepare_image(filename, binary, P)
%SSTV_PREPARE_IMAGE  读任意支持的图片，等比缩放并补白到所选模式的尺寸。
% 默认二值化使用固定的半量程亮度门限；关闭后保留 RGB 颜色。
    [source,map,alpha] = imread(filename);
    if ~isempty(map)
        source = ind2rgb(source,map);
    elseif islogical(source)
        source = double(source);
    elseif isinteger(source)
        source = double(source)/double(intmax(class(source)));
    else
        source = double(source);
    end
    if size(source,3)==1,source=repmat(source,1,1,3);end
    if size(source,3)~=3,error('sstv:Image','图片必须可转换为灰度或 RGB。');end
    if ~isempty(alpha)
        if isinteger(alpha),alpha=double(alpha)/double(intmax(class(alpha)));else,alpha=double(alpha);end
        source=source.*alpha + (1-alpha);   % 透明区域以白色合成
    end
    source=max(0,min(1,source));
    if binary
        gray=0.2989*source(:,:,1)+0.5870*source(:,:,2)+0.1141*source(:,:,3);
        source=repmat(double(gray>=0.5),1,1,3);
    end
    [h,w,~]=size(source);scale=min(P.width/w,P.height/h);
    nh=max(1,round(h*scale));nw=max(1,round(w*scale));
    x=linspace(1,w,nw);y=linspace(1,h,nh).';
    if binary
        resized=source(round(y),round(x),:);
    else
        % 双线性缩放；单行、单列图片也可处理，不额外依赖图像处理工具箱。
        x0=floor(x);x1=min(w,x0+1);dx=x-x0;
        y0=floor(y);y1=min(h,y0+1);dy=y-y0;
        resized=zeros(nh,nw,3);
        for ch=1:3
            a=source(:,:,ch);
            resized(:,:,ch)=(1-dy).*((1-dx).*a(y0,x0)+dx.*a(y0,x1)) ...
                +dy.*((1-dx).*a(y1,x0)+dx.*a(y1,x1));
        end
    end
    image=uint8(255*ones(P.height,P.width,3));
    top=floor((P.height-nh)/2);left=floor((P.width-nw)/2);
    image(top+(1:nh),left+(1:nw),:)=uint8(round(255*resized));
    if strcmp(P.color,'mono')
        channels=sstv_color(image,'encode');image=repmat(uint8(round(channels(:,:,1))),1,1,3);
    end
end
