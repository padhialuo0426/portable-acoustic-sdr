function build_tx_model()
%BUILD_TX_MODEL  构建实验四分块发送机，支持 QPSK 与 16-QAM。
here=fileparts(mfilename('fullpath'));addpath(fullfile(here,'..','common','matlab'));P=v22_params();
values=struct('frameBits',[0 1 1 1 1 1 1 0],'bps',P.bps,'preamble',P.preambleSyms, ...
 'postamble',P.postambleSyms,'syncBits',P.syncBits,'syncGuard',P.syncGuard,'syncLength',numel(P.syncBits), ...
 'scrTaps',P.scrTaps,'quadRot',P.quadRot,'inQ',P.inQ,'fc',P.fc, ...
 'rrc',rcosdesign(P.beta,P.span,P.sps,'sqrt'));
mdl='v22_transmit';asdr.TxModel.begin(mdl,values,1/600);
names={'Frame','Scrambler','Mapping','Upsample','Carrier'};
files={'tx_frame','tx_scrambler','tx_mapping','tx_upsample','tx_carrier'};
labels={'前后导与首尾同步标记','自同步扰码','差分象限与幅度映射','每符号插零扩展','复基带上变频'};
params={{'frameBits','bps','preamble','postamble','syncBits','syncGuard','syncLength'},{'bps','scrTaps'}, ...
 {'bps','quadRot','inQ'},{},{'fc'}};left=[100 380 660 940 1480];
for k=1:numel(names)
 asdr.TxModel.block(mdl,names{k},fullfile(here,'model',[files{k} '.m']),params{k},[left(k) 150 left(k)+180 270],labels{k});
end
add_block('simulink/Discrete/Discrete FIR Filter',[mdl '/Shape'],'Coefficients','rrc', ...
 'InputProcessing','Columns as channels (frame based)','Position',[1210 180 1380 240], ...
 'ShowName','off','AttributesFormatString','平方根升余弦成形');
asdr.TxModel.wire(mdl,'Frame/1','Scrambler/1','每符号信息位');asdr.TxModel.wire(mdl,'Frame/2','Scrambler/2','有效符号');
asdr.TxModel.wire(mdl,'Scrambler/1','Mapping/1','加扰比特');asdr.TxModel.wire(mdl,'Frame/2','Mapping/2');
asdr.TxModel.wire(mdl,'Mapping/1','Upsample/1','复数符号');asdr.TxModel.wire(mdl,'Upsample/1','Shape/1');
asdr.TxModel.wire(mdl,'Shape/1','Carrier/1','成形复基带');
asdr.TxModel.log(mdl,'Carrier/1','txAudio',[1760 180 1870 240],'仿真音频');
asdr.TxModel.log(mdl,'Mapping/1','txSymbols',[940 315 1060 345],'调制符号');
asdr.TxModel.finish(mdl,here,'实验四 · V.22bis 发送机｜9600 赫兹采样｜600 波特｜HDLC 与 FCS 在图片打包入口完成',1890);
end
