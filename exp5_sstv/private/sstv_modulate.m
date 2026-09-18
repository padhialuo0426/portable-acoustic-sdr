function [audio,meta] = sstv_modulate(image,P)
%SSTV_MODULATE  标准 Martin M1：VIS 头 + 256 行 G/B/R 扫描。
% 所有段按累计时刻取采样边界，避免逐像素舍入导致行长漂移；相位连续。
    validateattributes(image,{'uint8'},{'size',[P.height P.width 3]});
    frequency=zeros(1,round(P.duration*P.fs));t=0;cursor=0;
    tone(1900,.3);tone(1200,.01);tone(1900,.3);tone(1200,.03);
    code=double(bitget(uint8(P.vis),1:7));
    for bit=[code mod(sum(code),2)],tone(1300-200*bit,.03);end
    tone(1200,.03);
    for row=1:P.height
        tone(P.syncHz,P.sync);tone(P.blackHz,P.porch);
        for ch=P.channelOrder
            finish=round((t+P.scan)*P.fs);
            time=(cursor:finish-1)/P.fs-t;
            pixel=max(1,min(P.width,1+floor(time/P.pixel)));
            frequency(cursor+1:finish)=P.blackHz+double(image(row,pixel,ch))*(P.whiteHz-P.blackHz)/255;
            t=t+P.scan;cursor=finish;tone(P.blackHz,P.porch);
        end
    end
    tone(P.blackHz,P.tail);
    frequency=frequency(1:cursor);
    % 当前采样的相位由此前频率积分得到，与连续相位音调生成器一致。
    phase=2*pi/P.fs*[0 cumsum(frequency(1:end-1))];
    audio=sin(phase);
    meta=struct('mode',P.mode,'vis',P.vis,'samples',numel(audio), ...
        'duration',numel(audio)/P.fs,'image',image);
    function tone(hz,duration)
        finish=round((t+duration)*P.fs);
        frequency(cursor+1:finish)=hz;t=t+duration;cursor=finish;
    end
end
