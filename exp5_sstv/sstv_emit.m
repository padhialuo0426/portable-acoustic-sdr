%% 实验五 · 纯 MATLAB 单文件发送机：SSTV 图像传输
% 图片 -> VIS 模式头 -> 逐行扫描 -> 亮度到频率 -> 连续相位音频。
% 所有算法与参数均在本文件内；不调用模型或工程辅助函数。

%% 1. 图片、模式和播放参数
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
img_name = 'ren512b.bmp';
imageFile = fullfile(here,'baseband_images',img_name);
MODE = 'M1';                      % 默认 Martin M1；其余模式见文件末尾模式表
BINARY = true;                    % true：二值化；false：保留彩色
AMPLITUDE = 0.8;
LEAD = 1.0;
PLAY_AUDIO = true;
SHOW_FIGURE = true;
SAVE_FILES = true;

% GUI 可提供输入，只取波形，不播放、不显示、不写盘。
% 直接运行本脚本时无需设置此结构，与实验二、三的调用约定一致。
if exist('sdrTxRequest','var')
    if isfield(sdrTxRequest,'imageFile'), imageFile = sdrTxRequest.imageFile; end
    if isfield(sdrTxRequest,'mode'), MODE = sdrTxRequest.mode; end
    if isfield(sdrTxRequest,'binary'), BINARY = sdrTxRequest.binary; end
    PLAY_AUDIO = false;
    SHOW_FIGURE = false;
    SAVE_FILES = false;
end

%% 2. 独立模式参数与图片预处理
P = modeParameters(MODE);
if exist('sdrTxRequest','var') && isfield(sdrTxRequest,'parameters')
    P = sdrTxRequest.parameters;
end
source = imageFile;
if exist('sdrTxRequest','var') && isfield(sdrTxRequest,'image')
    image = sdrTxRequest.image;source = '';
else
    image = prepareImage(imageFile,BINARY,P); % 二值化/保留颜色，等比缩放并补白
end
validateattributes(image,{'uint8'},{'size',[P.height P.width 3]});
if SHOW_FIGURE
    figure;imshow(image);title(sprintf('发送图片：%s',P.mode));
end

%% 3. VIS 头：引导音、七位模式号、偶校验与停止音
% 每段都按累计时刻取采样边界，避免逐段舍入引入行长漂移。
frequency = zeros(1,round(P.duration*P.fs));
t = 0;cursor = 0;
visBits = double(bitget(uint8(P.vis),1:7)); % 低位先发
parity = mod(sum(visBits),2);              % 加上校验位后，1 的总数为偶数
header = [1900 .3;1200 .01;1900 .3;1200 .03; ...
          (1300-200*[visBits parity]).' repmat(.03,8,1);1200 .03];
if P.initialSync>0,header=[header;P.syncHz P.initialSync];end
for k = 1:size(header,1)
    duration = header(k,2);
    finish = round((t+duration)*P.fs);
    frequency(cursor+1:finish) = header(k,1);
    t = t+duration;cursor = finish;
end

%% 4. 颜色编码与逐行扫描
if strcmp(P.color,'rgb'),channels=double(image);else,channels=encodeColor(image,'encode');end
% 每个扫描单元输出一行，PD 模式输出两行；M1 按 G、B、R 顺序扫描。
for unit = 1:P.units
    row = (unit-1)*P.rowsPerUnit+1;
    line = squeeze(channels(row,:,:));
    if strcmp(P.family,'pd')
        line(:,2:3) = squeeze(mean(channels(row:row+1,:,2:3),1));
        line(:,4) = channels(row+1,:,1).';
    elseif strcmp(P.family,'robot36')
        pair = 2*floor((row-1)/2)+1;
        line(:,2:3) = squeeze(mean(channels(pair:pair+1,:,2:3),1));
    end
    segments = scanSegments(P,unit);       % 同步音、间隔音与各颜色扫描段
    for k = 1:size(segments,1)
        duration = segments(k,1);ch = segments(k,2);
        finish = round((t+duration)*P.fs);
        if ch==0
            frequency(cursor+1:finish) = segments(k,3);
        else
            time = (cursor:finish-1)/P.fs-t;
            pixel = max(1,min(P.width,1+floor(time/(duration/P.width))));
            % 像素亮度 0～255 线性映射为 1500～2300 Hz。
            frequency(cursor+1:finish) = P.blackHz+line(pixel,ch).'*(P.whiteHz-P.blackHz)/255;
        end
        t = t+duration;cursor = finish;
    end
end
finish = round((t+P.tail)*P.fs);
frequency(cursor+1:finish) = P.blackHz;   % 尾部保护音
frequency = frequency(1:finish);

%% 5. 连续相位调制
% 当前采样相位由此前频率积分得到；切换音调时不重置相位。
phase = 2*pi/P.fs*[0 cumsum(frequency(1:end-1))];
x = sin(phase);
meta = struct('mode',P.mode,'vis',P.vis,'samples',numel(x), ...
    'duration',numel(x)/P.fs,'image',image,'binary',BINARY,'source',source,'backend','matlab');

%% 6. 保存音频、图片参考并播放
if SAVE_FILES
    audiowrite(fullfile(here,'sstv_tx.wav'),AMPLITUDE*x,P.fs,'BitsPerSample',16);
    fid = fopen(fullfile(here,'sstv_tx.raw'),'w','ieee-le');
    assert(fid>=0,'无法创建 sstv_tx.raw。');
    fwrite(fid,int16(round(AMPLITUDE*x*32767)),'int16');
    fclose(fid);
    binary = BINARY;mode = P.id;
    save(fullfile(here,'sstv_reference.mat'),'image','binary','mode');
end
if PLAY_AUDIO || SAVE_FILES
    fprintf('%s：%d×%d，VIS %d；完整音频 %.3f 秒。\n',P.mode,P.width,P.height,P.vis,meta.duration);
    fprintf('接收端先运行：./build/sstv_rx -d plughw:X,0 -t %d\n',ceil(meta.duration)+5);
end
if PLAY_AUDIO
    sound([zeros(1,round(LEAD*P.fs)),AMPLITUDE*x,zeros(1,round(.3*P.fs))],P.fs);
end

%% 本文件局部函数：独立模式表、扫描段和图片处理

function P = modeParameters(mode)
% 本发送脚本自己的模式参数，不读取工程其他参数文件。
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
    if isempty(index),error('sstv:Mode','不支持的 SSTV 模式，请查看本文件的模式表。');end
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
% 独立模式表：VIS 为不含偶校验位的七位编号。
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
% 模式扫描段：  一次扫描的 [时长秒, 分量编号, 固定音调Hz]。
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

function image = prepareImage(filename, binary, P)
% 图片预处理：  读任意支持的图片，等比缩放并补白到所选模式的尺寸。
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
        channels=encodeColor(image,'encode');image=repmat(uint8(round(channels(:,:,1))),1,1,3);
    end
end

function output = encodeColor(input,~)
% 满量程 BT.601：RGB -> Y/Cr/Cb，色度以 128 为中心。
    x = double(input);
    y = .299*x(:,:,1)+.587*x(:,:,2)+.114*x(:,:,3);
    output = cat(3,y,128+(x(:,:,1)-y)/1.402,128+(x(:,:,3)-y)/1.772);
    output = max(0,min(255,output));
end
