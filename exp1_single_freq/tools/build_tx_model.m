function build_tx_model()
%BUILD_TX_MODEL  构建实验一单频发送模型。
here=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(here,'..','common','matlab'));
    addpath(here);
mdl='single_fre_transmit';asdr.TxModel.begin(mdl,struct('fc',1000,'amplitude',1),.01);
asdr.TxModel.block(mdl,'Phase',fullfile(here,'model','tx_phase.m'),{'fc'},[120 150 290 240],'连续相位');
add_block('simulink/Math Operations/Trigonometric Function',[mdl '/Sine'],'Operator','sin', ...
    'Position',[430 165 540 225],'ShowName','off','AttributesFormatString','正弦波');
add_block('simulink/Math Operations/Gain',[mdl '/Amplitude'],'Gain','amplitude', ...
    'Position',[680 165 780 225],'ShowName','off','AttributesFormatString','幅度设置');
asdr.TxModel.wire(mdl,'Phase/1','Sine/1','相位（弧度）');asdr.TxModel.wire(mdl,'Sine/1','Amplitude/1');
asdr.TxModel.log(mdl,'Amplitude/1','txAudio',[920 165 1040 225],'仿真音频');
asdr.TxModel.finish(mdl,here,'实验一 · 单频发送机｜8000 赫兹采样｜每帧 80 点',1060);
end
