function P = sstv_params(mode)
%SSTV_PARAMS  用模式简称、完整名称或七位 VIS 编号选择参数，默认 Martin M1。
    if nargin<1,mode='M1';end
    modes=sstv_modes();
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
    if isempty(index),error('sstv:Mode','不支持的 SSTV 模式；可运行 sstv_modes 查看列表。');end
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
    segments=sstv_scan_segments(P,1);P.line=sum(segments(:,1));
    P.header = 0.3 + 0.01 + 0.3 + 10*0.03;
    P.tail = 0.1;
    P.duration = P.header + P.initialSync + P.units*P.line + P.tail;
    P.blackHz = 1500; P.whiteHz = 2300;
    P.syncHz = 1200; P.centerHz = 1900;
    P.lowpass = fir1(96,1500/(P.fs/2));
    P.minimumEnvelope = 1e-5;
end
