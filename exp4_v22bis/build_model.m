function build_model(modelFile)
%BUILD_MODEL  可复现地构建实验四分块接收模型，并保存到本实验目录。
% PCM 归一化 -> 下变频 -> RRC -> 定时 -> AGC/静噪 -> 载波恢复 -> I/Q 打包。
% model/*.m 是 MATLAB Function 块的源文件；修改后重新运行本入口和 slbuild。
% 2400/1200 共用一个模型；RxRate 输入选择增益目标和鉴相参考。
% 可传入另一个 .slx 文件路径，在副本中验证重建而不覆盖当前模型。
    here=fileparts(mfilename('fullpath'));
    if nargin<1,modelFile=fullfile(here,'v22_receive.slx');end
    [folder,mdl,extension]=fileparts(modelFile);
    assert(isvarname(mdl) && strcmpi(extension,'.slx'),'v22:ModelFile','请指定有效的 .slx 模型路径。');
    if isempty(folder),folder=pwd;end
    modelFile=fullfile(folder,[mdl extension]);
    P=v22_params(2400);frameSymbols=60;
    if bdIsLoaded(mdl)
        assert(strcmp(get_param(mdl,'Dirty'),'off'),'v22:UnsavedModel', ...
            '模型有未保存修改；请先保存或另存，避免重建时丢失。');
        close_system(mdl,0);
    end
    new_system(mdl);
    ws=get_param(mdl,'ModelWorkspace');
    % 旧建模脚本用 %%g 写入 AGC 常数（6 位有效数字）；拆块保持原数值。
    refMagnitude=str2double(sprintf('%.6g',mean(abs(P.inQ))));
    parameters=struct('fc',P.fc,'fs',P.fs,'sps',P.sps,'frameSymbols',frameSymbols, ...
        'refMagnitude',refMagnitude,'squelch',1e-3,'Kp',0.05,'Ki',2e-4, ...
        'rrcCoefficients',rcosdesign(P.beta,P.span,P.sps,'sqrt'));
    names=fieldnames(parameters);
    for k=1:numel(names),ws.assignin(names{k},parameters.(names{k}));end

    add_block('simulink/Sources/In1',[mdl '/AudioIn'], ...
        'OutDataTypeStr','int16','PortDimensions',num2str(frameSymbols*P.sps), ...
        'SampleTime','0.1','Position',[25 148 55 162]);
    add_block('simulink/Sources/In1',[mdl '/RxRate'], ...
        'Port','2','OutDataTypeStr','uint16','PortDimensions','1', ...
        'SampleTime','0.1','Position',[635 375 665 395], ...
        'ShowName','off','AttributesFormatString','接收速率（1200／2400）');
    add_block('built-in/Subsystem',[mdl '/PCM Normalize'],'Position',[95 120 195 190]);
    buildNormalize([mdl '/PCM Normalize']);
    addFunction(mdl,'Downconvert','downconvert.m',{'fc','fs'},[235 120 345 190],here);
    add_block('simulink/Discrete/Discrete FIR Filter',[mdl '/RRC Matched Filter'], ...
        'Coefficients','rrcCoefficients','InputProcessing','Columns as channels (frame based)', ...
        'Position',[390 120 500 190]);
    addFunction(mdl,'Timing Recovery','timing_recovery.m',{'sps','frameSymbols'},[545 120 655 190],here);
    addFunction(mdl,'AGC and Squelch','agc_squelch.m',{'refMagnitude','squelch'},[705 120 815 190],here);
    addFunction(mdl,'Carrier Recovery','carrier_recovery.m',{'Kp','Ki'},[880 120 990 190],here);
    add_block('built-in/Subsystem',[mdl '/IQ Pack'],'Position',[1040 120 1140 190]);
    buildPack([mdl '/IQ Pack'],frameSymbols);
    add_block('simulink/Sinks/Out1',[mdl '/symOut'],'Position',[1190 148 1220 162]);

    chain={'AudioIn','PCM Normalize','Downconvert','RRC Matched Filter', ...
        'Timing Recovery','AGC and Squelch','Carrier Recovery','IQ Pack','symOut'};
    % 根输入连线不另起信号名，保证生成 C 的输入字段仍为 AudioIn。
    signalNames={'','归一化采样','复基带','匹配滤波采样', ...
        '60 个复符号','幅度归一化符号','相位校正符号','I1 Q1 … I60 Q60'};
    for k=1:numel(chain)-1
        line=add_line(mdl,[chain{k} '/1'],[chain{k+1} '/1'],'autorouting','on');
        set_param(line,'Name',signalNames{k});
    end
    line=add_line(mdl,'AGC and Squelch/2','Carrier Recovery/2','autorouting','on');
    set_param(line,'Name','载波有效／静噪复位');
    % 根速率连线同样保持无名，生成 C 的字段名才能稳定为 RxRate。
    add_line(mdl,'RxRate/1','AGC and Squelch/2','autorouting','on');
    add_line(mdl,'RxRate/1','Carrier Recovery/3','autorouting','on');
    displayNames={'音频输入','PCM 归一化','正交下变频','RRC 匹配滤波', ...
        '定时恢复与抽样','AGC 与静噪','载波相位恢复','I/Q 交替打包','符号输出'};
    for k=1:numel(chain)
        set_param([mdl '/' chain{k}],'ShowName','off','AttributesFormatString',displayNames{k});
    end
    for k=2:numel(chain)-1
        set_param([mdl '/' chain{k}],'BackgroundColor','lightBlue');
    end
    set_param([mdl '/Timing Recovery'],'BackgroundColor','[0.85, 0.95, 0.85]');
    set_param([mdl '/AGC and Squelch'],'BackgroundColor','[0.85, 0.95, 0.85]');
    set_param([mdl '/Carrier Recovery'],'BackgroundColor','[0.85, 0.95, 0.85]');
    note(mdl,[30 25 1210 65],'V.22bis 接收机｜采样率 9600 Hz｜符号率 600 波特｜每帧 0.1 秒：960 点采样 → 60 个复符号');
    note(mdl,[95 250 500 305],'① 采样处理：PCM 归一化、相位连续的正交下变频、129 抽头 RRC 匹配滤波。');
    note(mdl,[545 250 990 325],'② 符号处理：选择抽样相位、归一化幅度、跟踪载波相位。状态跨帧保留；静噪仅复位载波环。');
    note(mdl,[1040 250 1240 335],'③ 输出 120 个实数。电脑继续完成判决、差分解码、解扰、HDLC/FCS 校验和图片还原。');
    applyLayout(mdl,fullfile(here,'model','layout.json'));

    set_param(mdl,'SolverType','Fixed-step','FixedStep','0.1','StopTime','inf', ...
        'SystemTargetFile','ert.tlc','HardwareBoard','None', ...
        'ProdHWDeviceType','ARM Compatible->ARM Cortex-A (64-bit)', ...
        'GenCodeOnly','on','MatFileLogging','off', ...
        'Toolchain','Automatically locate an installed toolchain', ...
        'RootIOFormat','Part of model data structure','GenerateSampleERTMain','off');
    set_param(mdl,'SimulationCommand','update');
    % 编译新增端口时 Simulink 可能微调块高度；保存前恢复用户布局。
    applyLayout(mdl,fullfile(here,'model','layout.json'));
    save_system(mdl,modelFile);
    open_system(mdl);set_param(mdl,'ZoomFactor','FitSystem');
    fprintf('已生成分块模型 %s.slx：960 样本 -> 60 个复符号 -> 120 个 I/Q 值。\n',mdl);
end
function addFunction(mdl,name,file,parameters,position,here)
    path=[mdl '/' name];
    add_block('simulink/User-Defined Functions/MATLAB Function',path, ...
        'Position',position,'ShowPortLabels','none');
    root=sfroot;chart=root.find('-isa','Stateflow.EMChart','Path',path);
    chart.Script=fileread(fullfile(here,'model',file));
    for k=1:numel(parameters)
        data=chart.find('-isa','Stateflow.Data','Name',parameters{k});
        if isempty(data),data=Stateflow.Data(chart);data.Name=parameters{k};end
        data.Scope='Parameter';data.Tunable=false;
    end
    % 符号数据口明确为复数，与标量布尔静噪控制口区分。
    outputs=chart.find('-isa','Stateflow.Data','Scope','Output');
    for k=1:numel(outputs)
        if ~strcmp(outputs(k).Name,'carrierPresent'),outputs(k).Props.Complexity='On';end
    end
    if ~strcmp(file,'downconvert.m')
        input=chart.find('-isa','Stateflow.Data','Name','x');input.Props.Complexity='On';
    end
    set_param(path,'Description',sprintf('源文件: model/%s\n修改后运行 build_model 重新嵌入模型。',file));
end
function buildNormalize(path)
    add_block('simulink/Sources/In1',[path '/PCM'],'Position',[25 48 55 62]);
    add_block('simulink/Signal Attributes/Data Type Conversion',[path '/ToDouble'], ...
        'OutDataTypeStr','double','Position',[95 35 165 75]);
    add_block('simulink/Math Operations/Gain',[path '/Scale'], ...
        'Gain','1/32768','Position',[205 35 275 75]);
    add_block('simulink/Sinks/Out1',[path '/Audio'],'Position',[320 48 350 62]);
    add_line(path,'PCM/1','ToDouble/1');add_line(path,'ToDouble/1','Scale/1');add_line(path,'Scale/1','Audio/1');
    labelBlocks(path,{'PCM','ToDouble','Scale','Audio'},{'整数音频','转为双精度','除以 32768','归一化音频'});
end
function buildPack(path,n)
    add_block('simulink/Sources/In1',[path '/Symbols'],'Position',[25 93 55 107]);
    add_block('simulink/Math Operations/Complex to Real-Imag',[path '/Split IQ'], ...
        'Position',[95 75 155 125]);
    add_block('simulink/Math Operations/Reshape',[path '/I row'], ...
        'OutputDimensionality','Customize','OutputDimensions',sprintf('[1 %d]',n),'Position',[205 45 275 85]);
    add_block('simulink/Math Operations/Reshape',[path '/Q row'], ...
        'OutputDimensionality','Customize','OutputDimensions',sprintf('[1 %d]',n),'Position',[205 140 275 180]);
    add_block('simulink/Math Operations/Matrix Concatenate',[path '/IQ rows'], ...
        'NumInputs','2','ConcatenateDimension','1','Position',[325 75 395 130]);
    add_block('simulink/Math Operations/Reshape',[path '/Interleave'], ...
        'OutputDimensionality','1-D array','Position',[445 85 525 125]);
    add_block('simulink/Sinks/Out1',[path '/IQ'],'Position',[575 98 605 112]);
    add_line(path,'Symbols/1','Split IQ/1');
    add_line(path,'Split IQ/1','I row/1');add_line(path,'Split IQ/2','Q row/1');
    add_line(path,'I row/1','IQ rows/1');add_line(path,'Q row/1','IQ rows/2');
    add_line(path,'IQ rows/1','Interleave/1');add_line(path,'Interleave/1','IQ/1');
    labelBlocks(path,{'Symbols','Split IQ','I row','Q row','IQ rows','Interleave','IQ'}, ...
        {'复符号','分离实部与虚部','实部行向量','虚部行向量','上下拼成两行','按列展开','交替 I/Q'});
    note(path,[90 225 555 275],'先将实部、虚部排成两行，再按列展开，得到 I1、Q1、I2、Q2……；不改变接收符号数值。');
end
function labelBlocks(path,names,labels)
    for k=1:numel(names)
        set_param([path '/' names{k}],'ShowName','off','AttributesFormatString',labels{k});
    end
end
function note(mdl,position,text)
    a=Simulink.Annotation(mdl,text);a.Position=position;a.FontSize=11;
end
function applyLayout(mdl,file)
    % 保存用户调整的模块间距与连线路径，重建模型时复用。
    if ~isfile(file),return,end
    layout=jsondecode(fileread(file));
    for k=1:numel(layout.blocks)
        set_param(modelPath(mdl,layout.blocks(k).path),'Position',layout.blocks(k).position);
    end
    annotations=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','annotation');
    for k=1:numel(annotations)
        a=get_param(annotations(k),'Object');
        for j=1:numel(layout.annotations)
            if strcmp(a.Text,layout.annotations(j).text),a.Position=layout.annotations(j).position;break,end
        end
    end
    for k=1:numel(layout.lines)
        item=layout.lines(k);ports=get_param(modelPath(mdl,item.source),'PortHandles');
        line=get_param(ports.Outport(item.sourcePort),'Line');
        set_param(line,'Points',item.points);
    end
end
function path=modelPath(mdl,savedPath)
    separator=find(savedPath=='/',1);
    path=[mdl savedPath(separator:end)];
end
