function [bits, info] = v22_demod(y, P)
%V22_DEMOD  V.22bis 接收：通带波形 -> 解扰后的比特流
%
%   [bits, info] = v22_demod(y, P)
%     y     实通带波形（麦克风采到的信号）
%     P     v22_params 返回的参数结构
%     bits  解扰后的 0/1 行向量，直接喂 v22_unpack 找 HDLC 帧
%     info  .evm 误差矢量幅度  .sym 均衡后符号  .theta 载波环相位轨迹
%
%   链路：下变频 -> RRC 匹配滤波 -> 定时 -> AGC -> 判决引导载波环
%         -> 象限判决 -> 差分解码 -> 自同步解扰
%
%   ★ 本文件是 Simulink 接收模型 v22_receive.slx 的**黄金参考**：模型里
%     每个块都要能和这里的某一步对上，改算法先改这里、仿真验过再动模型。
%
%   两个设计决定的来由（依据见 v22_sim.m 末尾的实测结论）：
%
%   1. 没有判决反馈均衡器。房间混响在符号率上是「又长又薄」的拖尾，
%      十几个抽头的 DFE 抓不住，实测加了 EVM 几乎不动、高 DRR 下反而更差。
%      对策是要求麦克风摆近（DRR≥20dB 跑 2400、≥10dB 跑 1200）。
%
%   2. 载波环是必需的，不是可选优化。收发两块声卡各有晶振，失配 0.8Hz
%      就能在 1 秒里转掉 288° 相位，单次相位校正完全无效。

    y = y(:).';
    h = rcosdesign(P.beta, P.span, P.sps, 'sqrt');
    d = P.span * P.sps;                       % 收发两次 RRC 的总群时延

    % --- 下变频 + 匹配滤波 ---
    n  = 0:numel(y)-1;
    z  = y .* exp(-1i*2*pi*P.fc*n/P.fs) * 2;
    mf = conv(z, h);

    % --- 定时：在一个符号周期内找能量最大的抽样相位 ---
    % 单向短突发下，全局搜一次比跑 Gardner 环更稳也更好讲。板上模型里
    % 要换成逐符号的定时误差检测器（见实验文档「与本参考实现的差异」）。
    Nsym = floor((numel(mf) - d - P.sps) / P.sps);
    pk = zeros(1, P.sps);
    for off = 0:P.sps-1
        idx = d + off + (0:Nsym-1)*P.sps + 1;
        pk(off+1) = mean(abs(mf(idx)));
    end
    [~, bo] = max(pk);  bo = bo - 1;
    r = mf(d + bo + (0:Nsym-1)*P.sps + 1);

    % --- AGC ---
    r = r / (mean(abs(r)) / mean(abs(P.inQ)));

    % --- 判决引导二阶载波环 + 象限判决 + 差分解码 ---
    Kp = 0.05;  Ki = 2e-4;
    th = 0;  integ = 0;  qp = 0;
    dec   = zeros(1, Nsym*P.bps);
    err   = zeros(1, Nsym);
    theta = zeros(1, Nsym);
    for k = 1:Nsym
        yk = r(k) * exp(-1i*th);

        if     real(yk)>=0 && imag(yk)>=0, qi = 0;
        elseif real(yk)< 0 && imag(yk)>=0, qi = 1;
        elseif real(yk)< 0 && imag(yk)< 0, qi = 2;
        else,                              qi = 3;
        end
        p = yk * exp(-1i*90*qi*pi/180);
        [~, li] = min(abs(p - P.inQ));
        dhat = P.inQ(li) * exp(1i*90*qi*pi/180);

        err(k)   = yk - dhat;
        theta(k) = th;
        e = angle(yk * conj(dhat));
        integ = integ + Ki*e;
        th    = th + Kp*e + integ;

        dq = mod(90*qi - qp, 360);  qp = 90*qi;
        hi = find(P.quadRot == dq, 1) - 1;
        if P.bps == 4
            dec((k-1)*4+(1:4)) = [bitget(hi,2) bitget(hi,1) ...
                                  bitget(li-1,2) bitget(li-1,1)];
        else
            dec((k-1)*2+(1:2)) = [bitget(hi,2) bitget(hi,1)];
        end
    end

    % --- 自同步解扰（不需要与发端对齐，17 位后自动同步）---
    st = zeros(1, P.scrLen);
    bits = zeros(size(dec));
    for i = 1:numel(dec)
        bits(i) = xor(dec(i), xor(st(P.scrTaps(1)), st(P.scrTaps(2))));
        st = [dec(i) st(1:end-1)];
    end

    info.evm   = sqrt(mean(abs(err(min(201,end):end)).^2)) / mean(abs(P.inQ));
    info.sym   = r;
    info.theta = theta;
    info.nsym  = Nsym;
end
