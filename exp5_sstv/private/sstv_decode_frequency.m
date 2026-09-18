function result = sstv_decode_frequency(frequency,P)
%SSTV_DECODE_FREQUENCY  从实收频率识别 VIS，再逐行锁定并还原 Martin M1。
% 不用参考图片找同步。无同步或截短的行不参与图片质量计算。
    f=double(frequency(:).');
    result=struct('status','no_vis','message','未检测到有效的 SSTV VIS 头', ...
        'vis',NaN,'image',[],'validRows',false(P.height,1),'rowStart',nan(P.height,1), ...
        'headerStart',NaN,'clockPpm',NaN,'frequencyOffsetHz',NaN,'complete',false);
    if numel(f)<P.fs || any(~isfinite(f)),return,end
    % 1 ms 粗搜索；原始采样用于精定位和像素积分。
    block=round(P.fs/1000);n=floor(numel(f)/block);
    coarse=median(reshape(f(1:n*block),block,n),1);
    leader=abs(coarse-1900)<80;
    edge=diff([false leader false]);beg=find(edge==1);fin=find(edge==-1)-1;
    smooth=movmean(f,max(1,round(.00025*P.fs)));
    for k=find(fin-beg+1>=240)
        approximate=fin(k)*block+1;
        span=max(2,approximate-round(.003*P.fs)):min(numel(f),approximate+round(.003*P.fs));
        crossings=span(smooth(span-1)>=1550 & smooth(span)<1550);
        if isempty(crossings),continue,end
        [~,j]=min(abs(crossings-approximate));start=crossings(j);
        start=start-1+(1550-smooth(start-1))/(smooth(start)-smooth(start-1));
        if start<.61*P.fs || start+.300*P.fs>numel(f),continue,end
        lead1=windowMedian(f,start+[-.60 -.34]*P.fs);
        lead2=windowMedian(f,start+[-.28 -.03]*P.fs);
        breakHz=windowMedian(f,start+[-.307 -.303]*P.fs);
        if abs(lead1-1900)>80 || abs(lead2-1900)>80 || abs(breakHz-1200)>90,continue,end
        tones=zeros(1,10);
        for slot=0:9,tones(slot+1)=windowMedian(f,start+(.03*slot+[.008 .022])*P.fs);end
        if any(abs(tones([1 10])-1200)>80),continue,end
        code=tones(2:9)<1200;expected=1300-200*code;
        if any(abs(tones(2:9)-expected)>70) || mod(sum(code),2)~=0,continue,end
        vis=sum(double(code(1:7)).*2.^(0:6));result.vis=vis;
        if vis~=P.vis
            result.status='unsupported_mode';result.message=sprintf('检测到 VIS %d；当前只支持 Martin M1（VIS 44）',vis);
            continue
        end
        result.headerStart=start;break
    end
    if ~isfinite(result.headerStart),return,end
    starts=nan(P.height,1);syncTone=nan(P.height,1);
    predicted=result.headerStart+.300*P.fs;period=P.line*P.fs;
    for row=1:P.height
        expectedEnd=predicted+P.sync*P.fs;
        span=max(2,round(expectedEnd-.006*P.fs)):min(numel(f),round(expectedEnd+.006*P.fs));
        if isempty(span),break,end
        crossings=span(smooth(span-1)<1350 & smooth(span)>=1350);
        [~,order]=sort(abs(crossings-expectedEnd));
        for j=order
            edgeSample=crossings(j);
            finish=edgeSample-1+(1350-smooth(edgeSample-1))/(smooth(edgeSample)-smooth(edgeSample-1));
            steady=round(finish+[-.0037 -.0008]*P.fs);
            if steady(1)<1,continue,end
            samples=f(steady(1):steady(2));
            if mean(abs(samples-1200)<90)<.85,continue,end
            starts(row)=finish-P.sync*P.fs;syncTone(row)=median(samples);break
        end
        if isfinite(starts(row))
            if row>1 && isfinite(starts(row-1))
                observed=starts(row)-starts(row-1);
                if abs(observed/P.fs-P.line)<.004,period=.8*period+.2*observed;end
            end
            predicted=starts(row)+period;
        else
            predicted=predicted+period;
        end
    end
    good=find(isfinite(starts));
    if numel(good)<2
        result.status='no_lines';result.message='VIS 44 已识别，但没有足够的完整行同步';return
    end
    scale=median(diff(starts(good))./diff(good))/(P.line*P.fs);
    if abs(scale-1)>.01
        result.status='line_timing';result.message='行周期与 Martin M1 不符，无法可靠还原';return
    end
    offset=median(syncTone(good))*scale-P.syncHz;
    image=uint8(128*ones(P.height,P.width,3));valid=false(P.height,1);
    for row=good.'
        last=starts(row)+(P.line-P.porch)*P.fs*scale;
        if last+1>numel(f),continue,end
        for chIndex=1:3
            begin=starts(row)+(P.sync+P.porch+(chIndex-1)*(P.scan+P.porch))*P.fs*scale;
            query=begin+((0:P.width-1).'+linspace(.25,.75,5))*P.pixel*P.fs*scale;
            ix=floor(query);weight=query-ix;
            samples=reshape(f(ix),size(ix)).*(1-weight)+reshape(f(ix+1),size(ix)).*weight;
            values=(median(samples,2)*scale-offset-P.blackHz)*255/(P.whiteHz-P.blackHz);
            image(row,:,P.channelOrder(chIndex))=uint8(round(max(0,min(255,values))));
        end
        valid(row)=true;
    end
    result.image=image;result.validRows=valid;result.rowStart=starts;
    result.clockPpm=(scale-1)*1e6;result.frequencyOffsetHz=offset;
    result.complete=all(valid);
    if result.complete
        result.status='ok';result.message='VIS 44 偶校验通过，256 行已还原（SSTV 不带图片 FCS）';
    else
        result.status='partial';result.message=sprintf('VIS 44 已识别，已还原 %d/256 行；未解行显示灰色',sum(valid));
    end
end
function value=windowMedian(f,range)
    value=median(f(max(1,round(range(1))):min(numel(f),round(range(2)))));
end
