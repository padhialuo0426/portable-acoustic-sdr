function timing = tx_scan_timing(modeVIS,restart,modeTable,durations,components,tones,counts)
%#codegen
% 逐采样生成 VIS、行同步及像素地址。累计时间确定边界，状态跨处理帧保留。
% 模式表列：VIS、宽、高、行组数、每组行数、起始同步秒数、颜色类型、共享色差。
persistent sample elapsed duration boundary stage segment unit modeIndex channel hz done
if isempty(sample) || restart
    sample=0;elapsed=0;duration=.3;boundary=14400;stage=0;segment=1;unit=1;
    modeIndex=1;channel=0;hz=1900;done=true;
    for m=1:20
        if modeTable(m,1)==double(modeVIS),modeIndex=m;done=false;break,end
    end
end
timing=struct('unit',zeros(4800,1,'uint16'),'elapsed',zeros(4800,1),'duration',zeros(4800,1), ...
    'component',zeros(4800,1,'uint8'),'tone',zeros(4800,1),'valid',uint16(0),'finished',false, ...
    'width',modeTable(modeIndex,2),'rowsPerUnit',modeTable(modeIndex,5), ...
    'color',uint8(modeTable(modeIndex,7)),'pair',logical(modeTable(modeIndex,8)));
for k=1:4800
    if done,break,end
    if sample>=boundary
        elapsed=elapsed+duration;
        if stage==0
            segment=segment+1;
            if segment>13
                segment=1;
                if modeTable(modeIndex,6)>0,stage=1;else,stage=2;end
            end
        elseif stage==1
            stage=2;segment=1;
        elseif stage==2
            segment=segment+1;
            if segment>counts(modeIndex)
                segment=1;unit=unit+1;
                if unit>modeTable(modeIndex,4),stage=3;end
            end
        else
            done=true;break
        end
        channel=0;
        if stage==0
            duration=.03;hz=1200;
            if segment==2,duration=.01;
            elseif segment==3,duration=.3;hz=1900;
            elseif segment>=5 && segment<=11
                hz=1300-200*double(bitget(modeVIS,segment-4));
            elseif segment==12
                onesCount=0;for bit=1:7,onesCount=onesCount+double(bitget(modeVIS,bit));end
                hz=1300-200*mod(onesCount,2);
            end
        elseif stage==1
            duration=modeTable(modeIndex,6);hz=1200;
        elseif stage==2
            variant=1+mod(unit-1,2);
            duration=durations(modeIndex,segment,variant);
            channel=components(modeIndex,segment,variant);hz=tones(modeIndex,segment,variant);
        else
            duration=.1;hz=1500;
        end
        boundary=round((elapsed+duration)*48000);
    end
    timing.component(k)=uint8(channel);timing.tone(k)=hz;
    if channel>0
        timing.unit(k)=uint16(unit);
        timing.elapsed(k)=sample/48000-elapsed;timing.duration(k)=duration;
    end
    timing.valid=timing.valid+1;sample=sample+1;
end
% 最后一个有效样本恰好位于帧尾时，也在本帧给出结束标记。
timing.finished=done || (stage==3 && sample>=boundary);
end
