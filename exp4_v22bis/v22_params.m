function P = v22_params(rate)
%V22_PARAMS  实验四物理层参数（ITU-T V.22bis，主叫方向）
%
%   P = v22_params(2400)   16-QAM，4 bit/符号
%   P = v22_params(1200)   QPSK  ，2 bit/符号（V.22bis 的回退速率）
%
%   发射端、接收端、仿真、GUI 全部从这里取参数，避免各写一份对不上。
%
%   采样率取 9600 而不是本工程其它实验的 8000：9600/600 = 16 正好是整数，
%   省掉分数倍定时插值。板上让 ALSA 的 plughw 做重采样即可（见实验文档）。

    if nargin < 1, rate = 2400; end

    P.rate = rate;
    P.fs   = 9600;               % 采样率
    P.Rs   = 600;                % 符号率(baud)，V.22bis 规定
    P.sps  = P.fs / P.Rs;        % 每符号 16 点
    P.fc   = 1200;               % 载波，V.22bis 主叫方向（被叫是 2400）
    P.beta = 0.75;               % RRC 滚降，V.22bis 规定 75%
    P.span = 8;                  % 成形滤波器长度(符号)

    % 差分四象限编码：前 2 bit 决定相对前一符号的象限旋转
    P.quadRot = [90 0 180 270];  % 比特 00/01/10/11 -> 旋转角(度)

    switch rate
        case 2400
            P.bps   = 4;                            % 每符号比特数
            P.inQ   = [1+1i, 3+1i, 1+3i, 3+3i];     % 后 2 bit 在象限内选点
        case 1200
            P.bps   = 2;
            P.inQ   = (1+1i)/sqrt(2);               % 象限内只有一个点
        otherwise
            error('rate 只能是 2400 或 1200。');
    end

    % 扰码多项式 GPC = 1 + x^-14 + x^-17（V.22bis 主叫方向，自同步）
    P.scrTaps = [14 17];
    P.scrLen  = 17;

    % 前导：送入扰码器的全 1，出来是伪随机序列，供 AGC/定时/载波捕获。
    % 300 符号是仿真里二阶载波环稳定捕获所需长度的 1.5 倍余量。
    P.preambleSyms = 300;

    % 后导：数据发完不立刻断载波，再送 120 个符号(0.2s)的加扰全 1。
    % 接收端按 60 符号一帧处理，突发若在帧中间结束，那个半空帧会被逐帧 AGC
    % 归一化而把噪声放大成星座——数据若正好落在那一帧就完了。真实 modem
    % 同样不会在最后一个数据符号后立刻掉载波。
    P.postambleSyms = 120;
end
