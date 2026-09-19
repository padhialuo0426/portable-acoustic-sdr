%% 实验五 · 独立 MATLAB 顺序解码脚本：SSTV 频率数据还原图片
% 输入板上接收模型产出的频率 MAT；参考图仅用于评价，不用于找同步。
% 全部参数、模式表和算法均在本文件内，无需发送机、GUI 或模型。

%% 1. 输入文件与独立参数
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
MAT_FILE = 'sstvfreq.mat';
REFERENCE_FILE = 'sstv_reference.mat'; % 不存在时只解图，不计算参考误差
matFile = fullfile(here,MAT_FILE);
referenceFile = fullfile(here,REFERENCE_FILE);
P = decodeParameters();
metrics = [];

%% 2. 读入并展开逐帧频率
S = load(matFile);
if ~isfield(S,'sstvFreq'),error('sstv:Data','文件缺少 sstvFreq。');end
validateattributes(S.sstvFreq,{'numeric'},{'2d','nrows',P.frameSamples+1,'nonempty','real','finite'});
frequency = reshape(S.sstvFreq(2:end,:),1,[]);

%% 3. VIS 头、偶校验与模式识别
f=double(frequency(:).');
result=struct('status','no_vis','message','未检测到有效的 SSTV VIS 头', ...
    'vis',NaN,'mode','','modeId','','width',0,'height',0,'image',[],'validRows',false(P.height,1),'rowStart',nan(P.height,1), ...
    'headerStart',NaN,'clockPpm',NaN,'frequencyOffsetHz',NaN,'complete',false);
if numel(f)<P.fs || any(~isfinite(f)),fprintf('%s\n',result.message);return,end
% 1 ms 粗搜索；原始采样用于精定位和像素积分。
block=round(P.fs/1000);n=floor(numel(f)/block);
coarse=median(reshape(f(1:n*block),block,n),1);
leader=abs(coarse-1900)<80;
edge=diff([false leader false]);beg=find(edge==1);fin=find(edge==-1)-1;
smooth=movmean(f,max(1,round(.00025*P.fs)));
modes=modeTable();
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
if ~isfinite(result.headerStart),fprintf('%s\n',result.message);return,end
P=decodeParameters(result.vis);
result.mode=P.mode;result.modeId=P.id;result.width=P.width;result.height=P.height;
result.validRows=false(P.height,1);result.rowStart=nan(P.height,1);
%% 4. 逐行同步与行时钟估计
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
    result.status='no_lines';result.message=sprintf('%s（VIS %d）已识别，但行同步不足',P.mode,P.vis);fprintf('%s\n',result.message);return
end
scale=median(diff(starts(good))./diff(good))/(P.line*P.fs);
if abs(scale-1)>.01
    result.status='line_timing';result.message=sprintf('行周期与 %s 不符，无法可靠还原',P.mode);fprintf('%s\n',result.message);return
end
offset=median(syncTone(good))*scale-P.syncHz;
%% 5. 像素积分、颜色恢复与完整行标记
channels=128*ones(P.height,P.width,3);valid=false(P.height,1);
for unit=good.'
    segments=scanSegments(P,unit);elapsed=0;line=nan(P.width,4);complete=true;
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
if strcmp(P.color,'ycc'),channels=convertColor(channels,'decode');end
decodedImage=uint8(round(channels));decodedImage(~valid,:,:)=128;
result.image=decodedImage;result.validRows=valid;result.rowStart=repelem(starts,P.rowsPerUnit);
result.clockPpm=(scale-1)*1e6;result.frequencyOffsetHz=offset;
result.complete=all(valid);
if result.complete
    result.status='ok';result.message=sprintf('%s（VIS %d）偶校验通过，%d 行已还原（图片无 FCS）',P.mode,P.vis,P.height);
else
    result.status='partial';result.message=sprintf('%s（VIS %d）已识别，已还原 %d/%d 行；未解行显示灰色',P.mode,P.vis,sum(valid),P.height);
end

%% 6. 显示还原图并比较有效行的参考误差
fprintf('%s\n',result.message);
if ~isempty(result.image)
    figure;imshow(result.image);title(result.message);
    if isfile(referenceFile)
        R=load(referenceFile);
        if ~isfield(R,'mode'),R.mode='M1';end % 兼容最初的 Martin M1 参考文件。
        if ~strcmp(result.modeId,R.mode)
            fprintf('参考模式与收到的 %s 不符，仅显示实收图片。\n',result.mode);return
        end
        metrics=imageMetrics(result,R.image,R.binary);
        if metrics.available
            fprintf('有效行 MAE %.3f，PSNR %.2f dB\n',metrics.mae,metrics.psnr);
            if R.binary,fprintf('二值像素误差率 %d/%d = %.6f\n',metrics.pixelErrors,metrics.pixels,metrics.pixelErrorRate);end
        else
            fprintf('参考尺寸不符或没有可比较的完整行，不计算图像质量。\n');
        end
    end
end

%% 本文件局部函数：模式表、扫描段、颜色转换和质量计算
function P = decodeParameters(mode)
%DECODEPARAMETERS  用模式简称、完整名称或七位 VIS 编号选择参数，默认 Martin M1。
    if nargin<1,mode='M1';end
    modes=modeTable();
    if isnumeric(mode) && isscalar(mode)
        index=find([modes.vis]==mode,1);
    elseif (ischar(mode) && isrow(mode)) || (isstring(mode) && isscalar(mode))
        key=regexprep(upper(char(mode)),'[^A-Z0-9]','');
        names=regexprep(upper(string({modes.mode})),'[^A-Z0-9]','');
        ids=regexprep(upper(string({modes.id})),'[^A-Z0-9]','');
        index=find(names==key | ids==key,1);
    else
        index=[];
    end
    if isempty(index),error('sstv:Mode','不支持的 SSTV 模式；请查看本文件的模式表。');end
    P=modes(index);
    P.fs = 48000;
    P.frameSamples = 4800;
    P.pixel = P.scan/P.width;
    P.rowsPerUnit=1+strcmp(P.family,'pd');P.units=P.height/P.rowsPerUnit;
    P.initialSync=0;P.syncOffset=0;
    if strcmp(P.family,'scottie')
        P.initialSync=P.sync;P.syncOffset=2*(P.porch+P.scan);
    end
    P.channelOrder=[1 2 3];
    if startsWith(P.id,'M') || strcmp(P.family,'scottie'),P.channelOrder=[2 3 1];end
    segments=scanSegments(P,1);P.line=sum(segments(:,1));
    P.header = 0.3 + 0.01 + 0.3 + 10*0.03;
    P.tail = 0.1;
    P.duration = P.header + P.initialSync + P.units*P.line + P.tail;
    P.blackHz = 1500; P.whiteHz = 2300;
    P.syncHz = 1200; P.centerHz = 1900;
end

function modes = modeTable()
%MODETABLE  支持的模拟 SSTV 模式；VIS 为不含偶校验位的七位编号。
% 时序依据 N7CXI 的模式说明；黑白模式采用 7 ms 同步的扫描格式。
% 列：简称、名称、扫描结构、颜色、VIS、宽、高、同步、间隔、分量扫描秒数。
    rows={ ...
        'M1','Martin M1','rgb','rgb',44,320,256,.004862,.000572,.146432; ...
        'M2','Martin M2','rgb','rgb',40,320,256,.004862,.000572,.073216; ...
        'S1','Scottie S1','scottie','rgb',60,320,256,.009,.0015,.138240; ...
        'S2','Scottie S2','scottie','rgb',56,320,256,.009,.0015,.088064; ...
        'SDX','Scottie DX','scottie','rgb',76,320,256,.009,.0015,.345600; ...
        'R36','Robot 36','robot36','ycc',8,320,240,.009,.003,.088; ...
        'R72','Robot 72','robot72','ycc',12,320,240,.009,.003,.138; ...
        'BW8','Robot B&W 8','mono','mono',2,160,120,.007,0,.0599; ...
        'BW12','Robot B&W 12','mono','mono',6,160,120,.007,0,.093; ...
        'PD50','PD50','pd','ycc',93,320,256,.020,.002080,.091520; ...
        'PD90','PD90','pd','ycc',99,320,256,.020,.002080,.170240; ...
        'PD120','PD120','pd','ycc',95,640,496,.020,.002080,.121600; ...
        'PD160','PD160','pd','ycc',98,512,400,.020,.002080,.195584; ...
        'PD180','PD180','pd','ycc',96,640,496,.020,.002080,.183040; ...
        'PD240','PD240','pd','ycc',97,640,496,.020,.002080,.244480; ...
        'PD290','PD290','pd','ycc',94,800,616,.020,.002080,.228800; ...
        'SC2-180','Wraase SC2-180','wraase','rgb',55,320,256,.0055225,.0005,.235; ...
        'P3','Pasokon P3','rgb','rgb',113,640,496,25/4800,5/4800,640/4800; ...
        'P5','Pasokon P5','rgb','rgb',114,640,496,25/3200,5/3200,640/3200; ...
        'P7','Pasokon P7','rgb','rgb',115,640,496,25/2400,5/2400,640/2400};
    fields={'id','mode','family','color','vis','width','height','sync','porch','scan'};
    modes=cell2struct(rows,fields,2);
end

function segments = scanSegments(P,unit)
%SCANSEGMENTS  一次扫描的 [时长秒, 分量编号, 固定音调Hz]。
% 编号 0 为音调；RGB 为 R/G/B，色差为 Y/Cr/Cb，PD 的 4 为第二行 Y。
    sync=[P.sync 0 1200];porch=[P.porch 0 1500];
    switch P.family
        case 'rgb'
            segments=[sync;porch];
            for ch=P.channelOrder,segments=[segments;P.scan ch 0;porch];end %#ok<AGROW>
        case 'scottie'
            segments=[porch;P.scan 2 0;porch;P.scan 3 0;sync;porch;P.scan 1 0];
        case 'wraase'
            segments=[sync;porch;P.scan 1 0;P.scan 2 0;P.scan 3 0];
        case 'pd'
            segments=[sync;porch;P.scan 1 0;P.scan 2 0;P.scan 3 0;P.scan 4 0];
        case 'robot36'
            ch=2+mod(unit-1,2);separator=1500+800*mod(unit-1,2);
            segments=[sync;porch;.088 1 0;.0045 0 separator;.0015 0 1900;.044 ch 0];
        case 'robot72'
            segments=[sync;porch;.138 1 0;.0045 0 1500;.0015 0 1900; ...
                .069 2 0;.0045 0 2300;.0015 0 1500;.069 3 0];
        case 'mono'
            segments=[sync;P.scan 1 0];
        otherwise
            error('sstv:Mode','未知扫描结构。');
    end
end

function value=windowMedian(f,range)
    value=median(f(max(1,round(range(1))):min(numel(f),round(range(2)))));
end

function output = convertColor(input,direction)
%CONVERTCOLOR  满量程 BT.601 RGB 与 Y/Cr/Cb 转换，分量范围 0～255。
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

function metrics=imageMetrics(result,reference,binary)
%IMAGEMETRICS  只对本次完整还原的行比较像素，不把缺失行当作零误差。
    metrics=struct('available',false,'psnr',NaN,'mae',NaN,'pixelErrors',NaN,'pixels',0,'pixelErrorRate',NaN);
    if isempty(result.image) || ~any(result.validRows) || ~isequal(size(reference),size(result.image)),return,end
    received=double(result.image(result.validRows,:,:));ref=double(reference(result.validRows,:,:));
    difference=received-ref;mse=mean(difference(:).^2);
    metrics.available=true;metrics.psnr=10*log10(255^2/mse);metrics.mae=mean(abs(difference(:)));
    if binary
        errors=(mean(received,3)>=127.5)~=(mean(ref,3)>=127.5);
        metrics.pixelErrors=sum(errors(:));metrics.pixels=numel(errors);metrics.pixelErrorRate=mean(errors(:));
    end
end
