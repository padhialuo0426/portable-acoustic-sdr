function build_tx_model()
%BUILD_TX_MODEL  构建实验三：组帧、斜率映射、扫频相位与余弦输出。
here=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(here,'..','common','matlab'));
    addpath(here);
mdl='chirp_transmit';asdr.TxModel.begin(mdl,struct('imageBits',[0 1 0 1]),.1);
names={'Frame','Slope','Phase'};files={'tx_frame','tx_slope','tx_phase'};labels={'前导与图片组帧','上扫与下扫映射','线性扫频相位'};
for k=1:3
 parameters={};if k==1,parameters={'imageBits'};end
 left=100+(k-1)*280;asdr.TxModel.block(mdl,names{k},fullfile(here,'model',[files{k} '.m']),parameters,[left 150 left+160 250],labels{k});
end
add_block('simulink/Sinks/Terminator',[mdl '/Unused'],'Position',[300 280 320 300],'ShowName','off');
asdr.TxModel.wire(mdl,'Frame/2','Unused/1');
add_block('simulink/Math Operations/Trigonometric Function',[mdl '/Cosine'],'Operator','cos', ...
 'Position',[940 170 1050 230],'ShowName','off','AttributesFormatString','余弦音频');
asdr.TxModel.wire(mdl,'Frame/1','Slope/1','信息位');asdr.TxModel.wire(mdl,'Slope/1','Phase/1','扫频方向');
asdr.TxModel.wire(mdl,'Phase/1','Cosine/1','相位（弧度）');
asdr.TxModel.log(mdl,'Cosine/1','txAudio',[1170 170 1290 230],'仿真音频');
asdr.TxModel.finish(mdl,here,'实验三 · 线性调频发送机｜8000 赫兹采样｜每符号 800 点',1310);
end
