function P = sstv_params()
%SSTV_PARAMS  实验五 Martin M1 的协议与音频参数。
    P.mode = 'Martin M1';
    P.fs = 48000;
    P.frameSamples = 4800;
    P.width = 320; P.height = 256;
    P.vis = 44;                  % 7 位 VIS，低位先发，另带偶校验
    P.sync = 4.862e-3;
    P.porch = 0.572e-3;
    P.scan = 146.432e-3;
    P.pixel = P.scan/P.width;
    P.line = P.sync + 4*P.porch + 3*P.scan;
    P.header = 0.3 + 0.01 + 0.3 + 10*0.03;
    P.tail = 0.1;
    P.duration = P.header + P.height*P.line + P.tail;
    P.blackHz = 1500; P.whiteHz = 2300;
    P.syncHz = 1200; P.centerHz = 1900;
    P.channelOrder = [2 3 1];   % 绿、蓝、红
    P.lowpass = fir1(96,1500/(P.fs/2));
    P.minimumEnvelope = 1e-5;
end
