function build_model(modelFile)
%BUILD_MODEL  构建实验五分块接收模型；全部显示注释为中文。
    here=fileparts(fileparts(mfilename('fullpath')));
    addpath(here,fullfile(here,'lib'));
    P=sstv_params();
    if nargin<1,modelFile=fullfile(here,'sstv_receive.slx');end
    [folder,mdl,ext]=fileparts(modelFile);
    assert(isvarname(mdl) && strcmpi(ext,'.slx'),'请指定有效的模型路径。');
    if isempty(folder),folder=pwd;end
    if bdIsLoaded(mdl)
        assert(strcmp(get_param(mdl,'Dirty'),'off'),'模型有未保存修改，请先保存。');close_system(mdl,0);
    end
    new_system(mdl);ws=get_param(mdl,'ModelWorkspace');
    ws.assignin('fc',P.centerHz);ws.assignin('fs',P.fs);
    ws.assignin('lowpassCoefficients',P.lowpass);ws.assignin('minimumEnvelope',P.minimumEnvelope);
    add_block('simulink/Sources/In1',[mdl '/AudioIn'],'OutDataTypeStr','int16', ...
        'PortDimensions','4800','SampleTime','0.1','Position',[30 143 60 157]);
    add_block('simulink/Signal Attributes/Data Type Conversion',[mdl '/ToDouble'], ...
        'OutDataTypeStr','double','Position',[115 125 205 175]);
    add_block('simulink/Math Operations/Gain',[mdl '/Normalize'], ...
        'Gain','1/32768','Position',[265 125 355 175]);
    addFunction(mdl,'Downconvert','downconvert.m',{'fc','fs'},[415 115 535 185],here);
    add_block('simulink/Discrete/Discrete FIR Filter',[mdl '/Lowpass'], ...
        'Coefficients','lowpassCoefficients','InputProcessing','Columns as channels (frame based)', ...
        'Position',[600 125 710 175]);
    addFunction(mdl,'Frequency','frequency_discriminator.m',{'fc','fs','minimumEnvelope'},[780 115 920 185],here);
    add_block('simulink/Sinks/Out1',[mdl '/frequencyOut'],'Position',[1000 143 1030 157]);
    chain={'AudioIn','ToDouble','Normalize','Downconvert','Lowpass','Frequency','frequencyOut'};
    labels={'单声道音频','转为双精度','PCM 归一化','正交下变频','复基带低通','相位差鉴频与静噪','频率输出'};
    signals={'','双精度采样','归一化音频','复基带','滤波后复基带','每个采样点的音频频率（赫兹）'};
    for k=1:numel(chain)
        set_param([mdl '/' chain{k}],'ShowName','off','AttributesFormatString',labels{k});
        if k<numel(chain)
            line=add_line(mdl,[chain{k} '/1'],[chain{k+1} '/1'],'autorouting','on');set_param(line,'Name',signals{k});
        end
    end
    note(mdl,[30 25 1040 65],'SSTV 多模式接收机｜采样率 48000 赫兹｜每帧 0.1 秒：4800 个采样 → 4800 个频率值');
    note(mdl,[110 250 710 310],'① 归一化后以 1900 赫兹为中心下变频。97 抽头低通抑制混频镜像，本振与滤波器状态跨帧保留。');
    note(mdl,[780 250 1090 335],'② 相邻复样本的相位差恢复音频频率。低电平输出零；电脑继续识别 VIS、锁定行同步并还原图片。');
    set_param(mdl,'SolverType','Fixed-step','FixedStep','0.1','StopTime','inf', ...
        'SystemTargetFile','ert.tlc','HardwareBoard','None', ...
        'ProdHWDeviceType','ARM Compatible->ARM Cortex-A (64-bit)', ...
        'GenCodeOnly','on','MatFileLogging','off', ...
        'Toolchain','Automatically locate an installed toolchain', ...
        'RootIOFormat','Part of model data structure','GenerateSampleERTMain','off');
    set_param(mdl,'SimulationCommand','update');save_system(mdl,fullfile(folder,[mdl '.slx']));
    open_system(mdl);set_param(mdl,'ZoomFactor','FitSystem');
end
function addFunction(mdl,name,file,parameters,position,here)
    path=[mdl '/' name];add_block('simulink/User-Defined Functions/MATLAB Function',path,'Position',position);
    root=sfroot;chart=root.find('-isa','Stateflow.EMChart','Path',path);chart.Script=fileread(fullfile(here,'model',file));
    for k=1:numel(parameters)
        data=chart.find('-isa','Stateflow.Data','Name',parameters{k});
        if isempty(data),data=Stateflow.Data(chart);data.Name=parameters{k};end
        data.Scope='Parameter';data.Tunable=false;
    end
    if strcmp(name,'Downconvert'),data=chart.find('-isa','Stateflow.Data','Scope','Output');else,data=chart.find('-isa','Stateflow.Data','Name','baseband');end
    data.Props.Complexity='On';
    set_param(path,'Description',['源文件：model/' file '。修改后运行 build_model 更新模型。']);
end
function note(mdl,position,value)
    annotation=Simulink.Annotation(mdl,value);annotation.Position=position;annotation.FontSize=11;
end
