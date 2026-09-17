%% 实验四 · V.22bis 声学 modem —— 纯 MATLAB 端到端仿真（无硬件）
%
%  作用：在动 Simulink 之前，先在仿真里回答两个问题——
%    1) 600 baud 的 V.22bis 波形在有混响的房间里还能不能解？
%    2) 2400bps(16-QAM) 与 1200bps(QPSK) 两档各自需要多好的信道？
%  结论直接决定接收模型要做多复杂（见本文件末尾的「实测结论」）。
%
%  与实验三的 bok_sim.m 定位相同：不碰板子、不碰声卡，纯算法验证。
%
%  物理层参数取自 ITU-T V.22bis（主叫方向）：
%    符号率 600 baud、载波 1200 Hz、RRC 滚降 75%、
%    自同步扰码 GPC = 1 + x^-14 + x^-17、差分四象限编码。
%  采样率取 9600 Hz 而非工程其它实验的 8000 Hz——9600/600 = 16 是整数，
%  省掉分数倍定时插值；板上用 plughw 让 ALSA 做重采样即可。

clear; rng(20260918);

%% ---------------- 物理层参数 ----------------
fs   = 9600;              % 采样率（16 samples/symbol）
Rs   = 600;               % 符号率 (baud)，V.22bis 规定
sps  = fs/Rs;             % 每符号采样点数 = 16
fc   = 1200;              % 载波，V.22bis 主叫方向
beta = 0.75;              % RRC 滚降，V.22bis 规定 75%
span = 8;                 % 成形滤波器长度（符号）
h    = rcosdesign(beta,span,sps,'sqrt');
d    = span*sps;          % 收发两次 RRC 的总群时延（样本）

% 差分四象限编码表：前 2 bit 决定相对前一符号的象限旋转
quadRot = [90 0 180 270];             % 比特 00/01/10/11 -> 旋转角(度)
Q16     = [1+1i, 3+1i, 1+3i, 3+3i];   % 16-QAM：后 2 bit 在象限内选点
Q4      = (1+1i)/sqrt(2);             % QPSK：象限内只有一个点

%% ---------------- 声学信道模型 ----------------
% 直达波 + 指数衰减混响尾。DRR(直达/混响比) 是本实验的关键指标——
% 它由麦克风离扬声器多远、房间多空决定，比信噪比更能决定成败。
RT60 = 0.30;                          % 混响时间(s)，普通实验室量级
Lh   = round(0.35*fs);
tt   = (0:Lh-1)/fs;
rng(7);
tail = randn(1,Lh).*exp(-6.9*tt/RT60);      % -60dB @ RT60
tail(1:round(0.004*fs)) = 0;                % 4ms 内无反射（最近的墙）
tail = tail/sqrt(sum(tail.^2));

SNR_dB  = 25;             % 加性噪声
df_Hz   = 0.8;            % 收发两块声卡晶振失配引起的载波频偏

%% ---------------- 扫描：两档速率 × 四种信道 ----------------
fprintf('\nV.22bis 声学信道仿真  (RT60=%.2fs, SNR=%ddB, 频偏=%.1fHz)\n', RT60, SNR_dB, df_Hz);
fprintf('%-9s %-9s %-9s %-10s %s\n','模式','DRR(dB)','EVM(%)','BER','结论');
fprintf('%s\n', repmat('-',1,52));

for mode = [4 2]                      % 每符号比特数：4=16QAM(2400bps) 2=QPSK(1200bps)
  if mode==4, inQ = Q16; name = '2400bps'; else, inQ = Q4; name = '1200bps'; end

  for DRR = [10 15 20 25]
    rng(20260918);
    Nsym = 1200;
    bits = randi([0 1],1,Nsym*mode);

    % --- 发射：扰码 ---
    st = zeros(1,17); sb = zeros(size(bits));
    for i = 1:numel(bits)
        v = xor(bits(i), xor(st(14),st(17)));   % GPC = 1 + x^-14 + x^-17
        sb(i) = v;  st = [v st(1:16)];
    end

    % --- 发射：差分四象限 + 象限内选点 ---
    sym = zeros(1,Nsym);  q = 0;
    for k = 1:Nsym
        qb = sb((k-1)*mode+(1:mode));
        hi = qb(1)*2 + qb(2);                   % 前 2 bit -> 象限旋转
        q  = mod(q + quadRot(hi+1), 360);
        if mode==4, lo = qb(3)*2 + qb(4); else, lo = 0; end
        sym(k) = inQ(lo+1) * exp(1i*q*pi/180);
    end

    % --- 发射：RRC 成形 + 上变频 ---
    bb = upfirdn(sym,h,sps);
    n  = 0:numel(bb)-1;
    tx = real(bb .* exp(1i*2*pi*fc*n/fs));
    tx = tx/max(abs(tx));

    % --- 信道 ---
    hh = zeros(1,Lh); hh(1) = 1;
    hh = hh + tail*10^(-DRR/20);
    y  = filter(hh,1,tx);
    ny = 0:numel(y)-1;
    y  = y + randn(size(y))*std(y)*10^(-SNR_dB/20);

    % --- 接收：下变频（本振带频偏）+ 匹配滤波 ---
    z  = y .* exp(-1i*2*pi*(fc+df_Hz)*ny/fs) * 2;
    m2 = conv(z,h);

    % --- 接收：定时（这里用全局最优相位；板上换成 Gardner 环）---
    pk = zeros(1,sps);
    for off = 0:sps-1
        q1 = m2(d+1+off : sps : d+off+(Nsym-1)*sps+1);
        pk(off+1) = mean(abs(q1));
    end
    [~,bo] = max(pk);
    r  = m2(d+bo : sps : d+bo-1+(Nsym-1)*sps+1);
    r  = r / (mean(abs(r))/mean(abs(sym)));     % AGC

    % --- 接收：判决引导二阶载波环 + 差分解码 ---
    th = 0; integ = 0; Kp = 0.05; Ki = 2e-4;
    dec = zeros(1,Nsym*mode);  qp = 0;  ev = zeros(1,Nsym);
    for k = 1:Nsym
        yk = r(k) * exp(-1i*th);
        if     real(yk)>=0 && imag(yk)>=0, qi = 0;
        elseif real(yk)< 0 && imag(yk)>=0, qi = 1;
        elseif real(yk)< 0 && imag(yk)< 0, qi = 2;
        else,                              qi = 3;
        end
        p = yk * exp(-1i*90*qi*pi/180);
        [~,li] = min(abs(p - inQ));
        dhat = inQ(li) * exp(1i*90*qi*pi/180);
        ev(k) = yk - dhat;

        e = angle(yk*conj(dhat));               % 相位误差
        integ = integ + Ki*e;
        th    = th + Kp*e + integ;

        dq = mod(90*qi - qp, 360);  qp = 90*qi;
        hi = find(quadRot==dq,1) - 1;
        if mode==4
            dec((k-1)*4+(1:4)) = [bitget(hi,2) bitget(hi,1) bitget(li-1,2) bitget(li-1,1)];
        else
            dec((k-1)*2+(1:2)) = [bitget(hi,2) bitget(hi,1)];
        end
    end

    % --- 接收：解扰（自同步，无需对齐）---
    st = zeros(1,17); db = zeros(size(dec));
    for i = 1:numel(dec)
        db(i) = xor(dec(i), xor(st(14),st(17)));
        st = [dec(i) st(1:16)];
    end

    sk  = 200*mode;                             % 跳过载波环捕获段
    ber = sum(db(sk+1:end) ~= bits(sk+1:end)) / (numel(bits)-sk);
    evm = sqrt(mean(abs(ev(201:end)).^2)) / sqrt(mean(abs(sym).^2));

    if     ber==0,      cc = '✓ 无误码';
    elseif ber < 1e-2,  cc = '△ 可用(需 FEC)';
    else,               cc = '✗ 不可用';
    end
    fprintf('%-9s %-9d %-9.1f %-10.2g %s\n', name, DRR, evm*100, ber, cc);
  end
end

fprintf('\n占用带宽: %.0f ~ %.0f Hz (载波 %d ± %.0f)\n', ...
        fc-Rs*(1+beta)/2, fc+Rs*(1+beta)/2, fc, Rs*(1+beta)/2);

%% ---------------- 实测结论（2026-09-18 跑出） ----------------
%
%  模式        需要的 DRR    说明
%  ---------   ----------   --------------------------------------------
%  1200bps     ≥ 10 dB      QPSK，DRR 10dB 就 BER=0，几乎放哪都能解
%  2400bps     ≥ 20 dB      16-QAM，低于 20dB 迅速崩（15dB 时 BER=0.017）
%
%  两条推论，直接决定接收模型的设计：
%
%  1) 判决反馈均衡器(DFE)可以不做。房间混响在符号率上表现为「又长又薄」的
%     拖尾——DRR=10dB 时主抽头占 91%，要 ±48 个符号才收满 99.9%。这种散布
%     的残余 ISI 等效于加性噪声，十几个抽头的 DFE 原理上就抓不住（实测加
%     15+12 抽头的 LMS DFE，EVM 几乎不变，高 DRR 下反而因失调噪声更差）。
%     与其做均衡，不如靠「麦克风摆近一点」把 DRR 提上去。
%
%  2) 速率回退是本实验的核心演示点，而不是附加功能。V.22bis 本来就规定了
%     2400/1200 两档，而声学信道恰好让这两档的分界清晰可见：麦克风摆远、
%     或换到空旷的房间，16-QAM 就解不出而 QPSK 照常——这是真实 modem
%     协商速率的物理原因，比任何文字解释都直观。
%
%  载波环：0.8Hz 的晶振失配（两块声卡各自的晶振）在 1 秒里会转掉 288°，
%  单次相位校正完全无效，必须上环路。二阶环 Kp=0.05/Ki=2e-4 在两档下都能
%  在 200 符号内捕获。
