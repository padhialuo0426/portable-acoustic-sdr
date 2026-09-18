function build_tx_model(modelFile)
%BUILD_TX_MODEL  构建多模式 SSTV 发送机：扫描寻址、颜色编码、连续相位调制。
    here=fileparts(mfilename('fullpath'));
    if nargin<1,modelFile=fullfile(here,'sstv_transmit.slx');end
    [folder,mdl,ext]=fileparts(modelFile);if isempty(folder),folder=pwd;end
    assert(isvarname(mdl) && strcmpi(ext,'.slx'),'请指定有效的模型路径。');
    if bdIsLoaded(mdl)
        assert(strcmp(get_param(mdl,'Dirty'),'off'),'模型有未保存修改，请先保存。');close_system(mdl,0);
    end
    modes=sstv_modes();modeTable=zeros(20,8);durations=zeros(20,9,2);
    components=durations;tones=durations;counts=zeros(20,1);
    for m=1:numel(modes)
        P=sstv_params(modes(m).id);
        modeTable(m,:)=[P.vis P.width P.height P.units P.rowsPerUnit P.initialSync ...
            ~strcmp(P.color,'rgb') any(strcmp(P.family,{'pd','robot36'}))];
        for variant=1:2
            sequence=sstv_scan_segments(P,variant);n=size(sequence,1);counts(m)=n;
            durations(m,1:n,variant)=sequence(:,1);components(m,1:n,variant)=sequence(:,2);
            tones(m,1:n,variant)=sequence(:,3);
        end
    end
    new_system(mdl);defineBuses(here,mdl);ws=get_param(mdl,'ModelWorkspace');
    names={'modeTable','durations','components','tones','counts'};
    values={modeTable,durations,components,tones,counts};
    for k=1:numel(names),ws.assignin(names{k},values{k});end
    port(mdl,'ImageIn',1,'uint8','1478400',[35 35 65 55],'图片像素');
    port(mdl,'ModeVIS',2,'uint8','1',[35 145 65 165],'模式编号');
    port(mdl,'Restart',3,'boolean','1',[35 235 65 255],'开始新图');
    block(mdl,'Timing','tx_scan_timing.m',names,[150 120 330 270],'① 协议时序',here);
    block(mdl,'Address','tx_pixel_address.m',{},[470 140 650 240],'② 像素寻址',here);
    block(mdl,'Read','tx_read_pixels.m',{},[790 120 970 240],'③ 读取图片像素',here);
    block(mdl,'Color','tx_color_encode.m',{},[150 425 320 515],'④ 颜色编码',here);
    block(mdl,'Average','tx_chroma_average.m',{},[420 425 590 515],'⑤ 双行色差平均',here);
    block(mdl,'Map','tx_frequency_map.m',{},[690 410 850 520],'⑥ 音调频率映射',here);
    block(mdl,'Phase','tx_phase_accumulator.m',{},[950 410 1110 540],'⑦ 相位累加',here);
    busOutput(mdl,'Timing','sstvTxTiming');busOutput(mdl,'Address','sstvTxAddress');
    busOutput(mdl,'Read','sstvTxPixels');busOutput(mdl,'Color','sstvTxEncoded');
    add_block('simulink/Math Operations/Trigonometric Function',[mdl '/Sine'], ...
        'Operator','sin','Position',[1210 445 1280 485],'ShowName','off','AttributesFormatString','⑧ 正弦输出');
    connect(mdl,'ModeVIS/1','Timing/1','');connect(mdl,'Restart/1','Timing/2','');
    connect(mdl,'Timing/1','Address/1','扫描时序');connect(mdl,'ImageIn/1','Read/1','');
    connect(mdl,'Address/1','Read/2','像素地址');
    connect(mdl,'Color/1','Average/1','亮度与色差');connect(mdl,'Average/1','Map/1','分量值');
    connect(mdl,'Map/1','Phase/1','频率（赫兹）');connect(mdl,'Phase/1','Sine/1','相位（弧度）');
    % 跨行信号采用具名接续，避免长折线穿过整排模块。
    tag(mdl,'PixelsTo','Goto','PixelData',[1050 160 1160 190],'图片像素数据');connect(mdl,'Read/1','PixelsTo/1','像素数据');
    tag(mdl,'PixelsFrom','From','PixelData',[20 450 120 480],'图片像素数据');connect(mdl,'PixelsFrom/1','Color/1','');
    tag(mdl,'TimingTo','Goto','ProtocolTiming',[380 285 490 315],'协议时序');connect(mdl,'Timing/1','TimingTo/1','协议时序');
    tag(mdl,'MapTiming','From','ProtocolTiming',[525 550 635 580],'协议时序');connect(mdl,'MapTiming/1','Map/2','');
    tag(mdl,'PhaseTiming','From','ProtocolTiming',[795 600 905 630],'协议时序');connect(mdl,'PhaseTiming/1','Phase/2','');
    tag(mdl,'ResetTo','Goto','RestartPulse',[150 320 260 350],'开始新图');connect(mdl,'Restart/1','ResetTo/1','开始新图');
    tag(mdl,'PhaseReset','From','RestartPulse',[795 665 905 695],'开始新图');connect(mdl,'PhaseReset/1','Phase/3','');
    add_block('simulink/Signal Routing/Bus Selector',[mdl '/Status'], ...
        'OutputSignals','valid,finished','Position',[580 280 585 350],'ShowName','off');
    connect(mdl,'Timing/1','Status/1','');
    out(mdl,'AudioOut',1,[1360 457 1390 477],'音频输出');connect(mdl,'Sine/1','AudioOut/1','');
    out(mdl,'ValidSamples',2,[750 285 780 305],'有效采样数');connect(mdl,'Status/1','ValidSamples/1','');
    out(mdl,'Finished',3,[750 330 780 350],'本图结束');connect(mdl,'Status/2','Finished/1','');
    add_block('simulink/Sinks/To Workspace',[mdl '/AudioLog'],'VariableName','txAudio', ...
        'SaveFormat','Array','Position',[1280 580 1390 610],'ShowName','off','AttributesFormatString','仿真音频');
    connect(mdl,'Sine/1','AudioLog/1','');
    add_block('simulink/Sinks/To Workspace',[mdl '/CountLog'],'VariableName','txCount', ...
        'SaveFormat','Array','Position',[930 295 1040 325],'ShowName','off','AttributesFormatString','帧内有效长度');
    connect(mdl,'Status/1','CountLog/1','');
    annotation=Simulink.Annotation(mdl,'SSTV 多模式发送机｜每帧 4800 点，采样率 48000 赫兹｜GUI 直接仿真，无需生成发送代码');
    annotation.Position=[150 -65 1330 -20];annotation.FontSize=12;
    annotation=Simulink.Annotation(mdl,'上排：协议与图片寻址。下排：颜色处理与调制。图片像素数据与协议时序通过同名标签接续。');
    annotation.Position=[150 760 1290 800];annotation.FontSize=11;
    set_param(mdl,'SolverType','Fixed-step','FixedStep','0.1','StopTime','120', ...
        'SaveOutput','off','SignalLogging','off');
    set_param(mdl,'SimulationCommand','update');set_param(mdl,'ZoomFactor','FitSystem');
    save_system(mdl,fullfile(folder,[mdl '.slx']));open_system(mdl);
end
function port(mdl,name,number,type,dimensions,position,label)
    add_block('simulink/Sources/In1',[mdl '/' name],'Port',num2str(number),'OutDataTypeStr',type, ...
        'PortDimensions',dimensions,'SampleTime','0.1','Position',position,'ShowName','off','AttributesFormatString',label);
end
function out(mdl,name,number,position,label)
    add_block('simulink/Sinks/Out1',[mdl '/' name],'Port',num2str(number), ...
        'Position',position,'ShowName','off','AttributesFormatString',label);
end
function block(mdl,name,file,parameters,position,label,here)
    path=[mdl '/' name];add_block('simulink/User-Defined Functions/MATLAB Function',path,'Position',position);
    root=sfroot;chart=root.find('-isa','Stateflow.EMChart','Path',path);chart.Script=fileread(fullfile(here,'model',file));
    for k=1:numel(parameters)
        data=chart.find('-isa','Stateflow.Data','Name',parameters{k});
        if isempty(data),data=Stateflow.Data(chart);data.Name=parameters{k};end
        data.Scope='Parameter';data.Tunable=false;
    end
    set_param(path,'ShowName','off','AttributesFormatString',label);
end
function connect(mdl,from,to,name)
    line=add_line(mdl,from,to,'autorouting','on');if ~isempty(name),set_param(line,'Name',name);end
end

function tag(mdl,name,type,value,position,label)
    add_block(['simulink/Signal Routing/' type],[mdl '/' name], ...
        'GotoTag',value,'IconDisplay','Signal name','Position',position,'ShowName','off','AttributesFormatString',label);
end

function busOutput(mdl,name,type)
    root=sfroot;chart=root.find('-isa','Stateflow.EMChart','Path',[mdl '/' name]);
    data=chart.find('-isa','Stateflow.Data','Scope','Output');data.DataType=['Bus: ' type];
end
function defineBuses(here,mdl)
    file=fullfile(here,'sstv_transmit.sldd');
    if isfile(file),dictionary=Simulink.data.dictionary.open(file);
    else,dictionary=Simulink.data.dictionary.create(file);end
    cleanup=onCleanup(@()close(dictionary));section=getSection(dictionary,'Design Data');
    vector=zeros(4800,1);word=zeros(4800,1,'uint16');byte=zeros(4800,1,'uint8');
    timing=struct('unit',word,'elapsed',vector,'duration',vector,'component',byte,'tone',vector, ...
        'valid',uint16(0),'finished',false,'width',0,'rowsPerUnit',0,'color',uint8(0),'pair',false);
    address=struct('row',word,'column',word,'other',word,'component',byte,'color',uint8(0),'pair',false);
    pixels=struct('rgb',zeros(4800,3),'otherRGB',zeros(4800,3),'component',byte,'color',uint8(0),'pair',false);
    encoded=struct('value',vector,'other',vector,'average',false(4800,1));
    values={timing,address,pixels,encoded};names={'sstvTxTiming','sstvTxAddress','sstvTxPixels','sstvTxEncoded'};
    for k=1:numel(names)
        fields=fieldnames(values{k});elements=Simulink.BusElement.empty;
        for j=1:numel(fields)
            v=values{k}.(fields{j});element=Simulink.BusElement;element.Name=fields{j};
            element.Dimensions=size(v);element.DataType=class(v);
            if islogical(v),element.DataType='boolean';end
            elements(j)=element;
        end
        bus=Simulink.Bus;bus.Elements=elements;
        if exist(section,names{k}),entry=getEntry(section,names{k});setValue(entry,bus);
        else,addEntry(section,names{k},bus);end
    end
    saveChanges(dictionary);set_param(mdl,'DataDictionary','sstv_transmit.sldd');
end
