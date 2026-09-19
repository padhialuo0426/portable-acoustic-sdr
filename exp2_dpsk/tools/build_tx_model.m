function build_tx_model()
%BUILD_TX_MODEL  构建实验二：组帧、差分编码、插零、成形与载波调制。
here=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(here,'..','common','matlab'));
    addpath(here);
mdl='dpsk_transmit';z=(1:160)/80-1+eps;beta=.5;
h=(4*beta/(pi*sqrt(.01)))*(cos((1+beta)*pi*z)+sin((1-beta)*pi*z)./(4*beta*z))./(1-16*beta^2*z.^2);
asdr.TxModel.begin(mdl,struct('imageBits',[0 1 0 1],'rrc',h),.01);
names={'Frame','Differential','Upsample','Carrier'};files={'tx_frame','tx_differential','tx_upsample','tx_carrier'};
labels={'前导与图片组帧','差分编码','每符号插零扩展','载波调制'};left=[100 360 620 1130];
for k=1:4
 parameters={};if k==1,parameters={'imageBits'};end
 asdr.TxModel.block(mdl,names{k},fullfile(here,'model',[files{k} '.m']),parameters,[left(k) 150 left(k)+150 260],labels{k});
end
add_block('simulink/Discrete/Discrete FIR Filter',[mdl '/Shape'],'Coefficients','rrc', ...
 'InputProcessing','Columns as channels (frame based)','Position',[870 175 1030 235], ...
 'ShowName','off','AttributesFormatString','平方根升余弦成形');
asdr.TxModel.wire(mdl,'Frame/1','Differential/1','信息位');asdr.TxModel.wire(mdl,'Frame/2','Differential/2','有效符号');
asdr.TxModel.wire(mdl,'Differential/1','Upsample/1','差分符号');asdr.TxModel.wire(mdl,'Upsample/1','Shape/1');
asdr.TxModel.wire(mdl,'Shape/1','Carrier/1','成形基带');
asdr.TxModel.log(mdl,'Carrier/1','txAudio',[1380 175 1500 235],'仿真音频');
asdr.TxModel.finish(mdl,here,'实验二 · DPSK 发送机｜8000 赫兹采样｜100 波特｜每帧一个符号',1530);
end
