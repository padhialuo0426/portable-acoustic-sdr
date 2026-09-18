function [audio,meta] = sstv_modulate_matlab(image,P)
%SSTV_MODULATE  VIS 头与所选模式的逐行音频，按累计时刻取采样边界。
% 所有段按累计时刻取采样边界，避免逐像素舍入导致行长漂移；相位连续。
    validateattributes(image,{'uint8'},{'size',[P.height P.width 3]});
    frequency=zeros(1,round(P.duration*P.fs));t=0;cursor=0;
    tone(1900,.3);tone(1200,.01);tone(1900,.3);tone(1200,.03);
    code=double(bitget(uint8(P.vis),1:7));
    for bit=[code mod(sum(code),2)],tone(1300-200*bit,.03);end
    tone(1200,.03);
    if P.initialSync>0,tone(P.syncHz,P.initialSync);end
    if strcmp(P.color,'rgb'),channels=double(image);else,channels=sstv_color(image,'encode');end
    for unit=1:P.units
        row=(unit-1)*P.rowsPerUnit+1;line=squeeze(channels(row,:,:));
        if strcmp(P.family,'pd')
            line(:,2:3)=squeeze(mean(channels(row:row+1,:,2:3),1));
            line(:,4)=channels(row+1,:,1).';
        elseif strcmp(P.family,'robot36')
            pair=2*floor((row-1)/2)+1;
            line(:,2:3)=squeeze(mean(channels(pair:pair+1,:,2:3),1));
        end
        segments=sstv_scan_segments(P,unit);
        for k=1:size(segments,1)
            duration=segments(k,1);ch=segments(k,2);
            if ch==0,tone(segments(k,3),duration);continue,end
            finish=round((t+duration)*P.fs);
            time=(cursor:finish-1)/P.fs-t;
            pixel=max(1,min(P.width,1+floor(time/(duration/P.width))));
            frequency(cursor+1:finish)=P.blackHz+line(pixel,ch).'*(P.whiteHz-P.blackHz)/255;
            t=t+duration;cursor=finish;
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
