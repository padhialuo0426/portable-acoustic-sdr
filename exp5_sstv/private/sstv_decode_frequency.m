function result = sstv_decode_frequency(frequency,P)
%SSTV_DECODE_FREQUENCY  从实收 VIS 自动选择模式，再同步并重组图像。
% 不用参考图片找同步。无同步或截短的行不参与图片质量计算。
    f=double(frequency(:).');
    result=struct('status','no_vis','message','未检测到有效的 SSTV VIS 头', ...
        'vis',NaN,'mode','','modeId','','width',0,'height',0,'image',[],'validRows',false(P.height,1),'rowStart',nan(P.height,1), ...
        'headerStart',NaN,'clockPpm',NaN,'frequencyOffsetHz',NaN,'complete',false);
    if numel(f)<P.fs || any(~isfinite(f)),return,end
    % 1 ms 粗搜索；原始采样用于精定位和像素积分。
    block=round(P.fs/1000);n=floor(numel(f)/block);
    coarse=median(reshape(f(1:n*block),block,n),1);
    leader=abs(coarse-1900)<80;
    edge=diff([false leader false]);beg=find(edge==1);fin=find(edge==-1)-1;
    smooth=movmean(f,max(1,round(.00025*P.fs)));
    modes=sstv_modes();
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
        if ~any([modes.vis]==vis)
            result.status='unsupported_mode';result.message=sprintf('检测到 VIS %d；当前不支持此模式',vis);
            continue
        end
        result.headerStart=start;break
    end
    if ~isfinite(result.headerStart),return,end
    P=sstv_params(result.vis);
    result.mode=P.mode;result.modeId=P.id;result.width=P.width;result.height=P.height;
    result.validRows=false(P.height,1);result.rowStart=nan(P.height,1);
    starts=nan(P.units,1);syncTone=nan(P.units,1);
    predicted=result.headerStart+(.300+P.initialSync)*P.fs;period=P.line*P.fs;
    for unit=1:P.units
        expectedEnd=predicted+(P.syncOffset+P.sync)*P.fs;
        % Scottie 首个常规同步在行中；容纳外部发射器对起始同步的不同处理。
        search=.006;if unit==1,search=.030;end
        span=max(2,round(expectedEnd-search*P.fs)):min(numel(f),round(expectedEnd+search*P.fs));
        if isempty(span),break,end
        crossings=span(smooth(span-1)<1350 & smooth(span)>=1350);
        [~,order]=sort(abs(crossings-expectedEnd));
        for j=order
            edgeSample=crossings(j);
            finish=edgeSample-1+(1350-smooth(edgeSample-1))/(smooth(edgeSample)-smooth(edgeSample-1));
            steady=round(finish+[-min(.012,.75*P.sync) -.0008]*P.fs);
            if steady(1)<1,continue,end
            samples=f(steady(1):steady(2));
            if mean(abs(samples-1200)<90)<.85,continue,end
            % 黑白扫描没有固定黑电平间隔，用后续亮度的中点校正边沿。
            if strcmp(P.family,'mono')
                right=windowMedian(f,finish+[.0005 .0015]*P.fs);
                level=(1200+max(1500,min(2300,right)))/2;
                local=max(2,round(finish-.0005*P.fs)):min(numel(f),round(finish+.001*P.fs));
                edges=local(smooth(local-1)<level & smooth(local)>=level);
                if ~isempty(edges)
                    [~,ix]=min(abs(edges-finish));at=edges(ix);
                    finish=at-1+(level-smooth(at-1))/(smooth(at)-smooth(at-1));
                end
            end
            starts(unit)=finish-(P.syncOffset+P.sync)*P.fs;
            syncTone(unit)=median(samples);break
        end
        if isfinite(starts(unit))
            if unit>1 && isfinite(starts(unit-1))
                observed=starts(unit)-starts(unit-1);
                if abs(observed/P.fs-P.line)<.004,period=.8*period+.2*observed;end
            end
            predicted=starts(unit)+period;
        else
            predicted=predicted+period;
        end
    end
    good=find(isfinite(starts));
    if numel(good)<2
        result.status='no_lines';result.message=sprintf('%s（VIS %d）已识别，但行同步不足',P.mode,P.vis);return
    end
    scale=median(diff(starts(good))./diff(good))/(P.line*P.fs);
    if abs(scale-1)>.01
        result.status='line_timing';result.message=sprintf('行周期与 %s 不符，无法可靠还原',P.mode);return
    end
    offset=median(syncTone(good))*scale-P.syncHz;
    channels=128*ones(P.height,P.width,3);valid=false(P.height,1);
    for unit=good.'
        segments=sstv_scan_segments(P,unit);elapsed=0;line=nan(P.width,4);complete=true;
        for k=1:size(segments,1)
            duration=segments(k,1);ch=segments(k,2);
            if ch>0
                begin=starts(unit)+elapsed*P.fs*scale;
                query=begin+((0:P.width-1).'+linspace(.25,.75,5))*(duration/P.width)*P.fs*scale;
                ix=floor(query);weight=query-ix;
                if min(ix,[],'all')<1 || max(ix,[],'all')+1>numel(f),complete=false;break,end
                samples=reshape(f(ix),size(ix)).*(1-weight)+reshape(f(ix+1),size(ix)).*weight;
                values=(median(samples,2)*scale-offset-P.blackHz)*255/(P.whiteHz-P.blackHz);
                line(:,ch)=max(0,min(255,values));
            end
            elapsed=elapsed+duration;
        end
        if ~complete,continue,end
        row=(unit-1)*P.rowsPerUnit+1;
        if strcmp(P.family,'pd')
            channels(row,:,:)=reshape(line(:,1:3),[1 P.width 3]);
            channels(row+1,:,:)=reshape(line(:,[4 2 3]),[1 P.width 3]);
            valid(row:row+1)=true;
        elseif strcmp(P.family,'mono')
            channels(row,:,:)=repmat(line(:,1).',[1 1 3]);valid(row)=true;
        elseif strcmp(P.family,'robot36')
            ch=2+mod(unit-1,2);channels(row,:,1)=line(:,1);channels(row,:,ch)=line(:,ch);valid(row)=true;
        else
            channels(row,:,:)=reshape(line(:,1:3),[1 P.width 3]);valid(row)=true;
        end
    end
    if strcmp(P.family,'robot36')
        % 一对行各携带一种色差；缺少任一行时不能伪造另一种颜色。
        for row=1:2:P.height
            if all(valid(row:row+1))
                channels(row+1,:,2)=channels(row,:,2);channels(row,:,3)=channels(row+1,:,3);
            else
                valid(row:row+1)=false;
            end
        end
    end
    if strcmp(P.color,'ycc'),channels=sstv_color(channels,'decode');end
    image=uint8(round(channels));image(~valid,:,:)=128;
    result.image=image;result.validRows=valid;result.rowStart=repelem(starts,P.rowsPerUnit);
    result.clockPpm=(scale-1)*1e6;result.frequencyOffsetHz=offset;
    result.complete=all(valid);
    if result.complete
        result.status='ok';result.message=sprintf('%s（VIS %d）偶校验通过，%d 行已还原（图片无 FCS）',P.mode,P.vis,P.height);
    else
        result.status='partial';result.message=sprintf('%s（VIS %d）已识别，已还原 %d/%d 行；未解行显示灰色',P.mode,P.vis,sum(valid),P.height);
    end
end
function value=windowMedian(f,range)
    value=median(f(max(1,round(range(1))):min(numel(f),round(range(2)))));
end
