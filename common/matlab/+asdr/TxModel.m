classdef TxModel
%TXMODEL  发送模型的建模与直接仿真工具，不调用代码生成器。
    methods(Static)
        function begin(mdl,values,period)
            if bdIsLoaded(mdl)
                assert(strcmp(get_param(mdl,'Dirty'),'off'),'模型有未保存修改，请先保存。');
                close_system(mdl,0);
            end
            new_system(mdl);ws=get_param(mdl,'ModelWorkspace');names=fieldnames(values);
            for k=1:numel(names),ws.assignin(names{k},values.(names{k}));end
            set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
                'FixedStep',num2str(period,17),'StopTime','1','SaveOutput','off','SignalLogging','off');
        end
        function block(mdl,name,source,parameters,position,label)
            path=[mdl '/' name];add_block('simulink/User-Defined Functions/MATLAB Function',path,'Position',position);
            config=get_param(path,'MATLABFunctionConfiguration');config.UpdateMethod='Discrete';config.SampleTime=get_param(mdl,'FixedStep');
            root=sfroot;chart=root.find('-isa','Stateflow.EMChart','Path',path);chart.Script=fileread(source);
            for k=1:numel(parameters)
                data=chart.find('-isa','Stateflow.Data','Name',parameters{k});
                if isempty(data),data=Stateflow.Data(chart);data.Name=parameters{k};end
                data.Scope='Parameter';data.Tunable=false;
            end
            set_param(path,'ShowName','off','AttributesFormatString',label);
        end
        function wire(mdl,from,to,label)
            line=add_line(mdl,from,to,'autorouting','on');
            if nargin>3,set_param(line,'Name',label);end
        end
        function log(mdl,from,variable,position,label)
            add_block('simulink/Sinks/To Workspace',[mdl '/' variable], ...
                'VariableName',variable,'SaveFormat','Array','Position',position, ...
                'ShowName','off','AttributesFormatString',label);
            asdr.TxModel.wire(mdl,from,[variable '/1']);
        end
        function finish(mdl,here,titleText,width)
            a=Simulink.Annotation(mdl,titleText);a.Position=[100 20 width 70];a.FontSize=12;
            a=Simulink.Annotation(mdl,'GUI 的模型分支或波形接口直接仿真本模型；收集音频后播放，无需生成发送代码。');
            a.Position=[100 380 width 420];a.FontSize=11;
            set_param(mdl,'SimulationCommand','update');set_param(mdl,'ZoomFactor','FitSystem');
            save_system(mdl,fullfile(here,[mdl '.slx']));open_system(mdl);
        end
        function output=run(here,mdl,values,period,frames)
            load_system(fullfile(here,[mdl '.slx']));input=Simulink.SimulationInput(mdl);
            names=fieldnames(values);
            for k=1:numel(names)
                input=input.setVariable(names{k},values.(names{k}),'Workspace',mdl);
            end
            input=input.setModelParameter('StopTime',num2str((frames-1)*period,17), ...
                'ReturnWorkspaceOutputs','on');
            output=sim(input);
        end
        function audio=audio(output,frameSize,samples,normalize)
            data=output.get('txAudio');
            assert(size(data,1)==frameSize && numel(data)>=samples,'发送模型输出尺寸异常。');
            audio=reshape(data,1,[]);audio=audio(1:samples);
            if normalize
                peak=max(abs(audio));if peak>0,audio=audio/peak;end
            end
        end
    end
end
