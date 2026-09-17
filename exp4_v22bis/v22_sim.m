%% 实验四 · V.22bis 声学 modem —— 端到端仿真（无硬件）
%
%  完整走一遍：图片 -> HDLC 帧 -> V.22bis 调制 -> 带混响的声学信道
%              -> 解调 -> 解帧校验 FCS -> 还原图片
%  两档速率 × 四种信道条件，看各自在什么条件下图片能完整还原。
%
%  与实验三的 bok_sim.m 定位相同：不碰板子、不碰声卡，纯算法验证。
%  动 Simulink 之前先在这里把参数调对——v22_demod.m 是接收模型的黄金参考。

clear;
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
imgdir = fullfile(here, 'baseband_images');
img_name = 'ren512b.bmp';

%% ---------------- 声学信道模型 ----------------
% 直达波 + 指数衰减混响尾。DRR（直达/混响比）由麦克风离扬声器多远、
% 房间多空决定，比信噪比更能决定本实验成败——600 baud 时一个符号只有
% 1.67ms，而 RT60=0.3s 的混响尾长达 180 个符号。
RT60   = 0.30;                 % 混响时间(s)，普通实验室量级
SNR_dB = 25;                   % 加性噪声
df_Hz  = 0.8;                  % 收发两块声卡晶振失配引起的载波频偏

fsr = 9600;
Lh  = round(0.35*fsr);  tt = (0:Lh-1)/fsr;
rng(7);
tail = randn(1,Lh) .* exp(-6.9*tt/RT60);     % -60dB @ RT60
tail(1:round(0.004*fsr)) = 0;                % 4ms 内无反射（最近的墙）
tail = tail / sqrt(sum(tail.^2));

%% ---------------- 扫描 ----------------
fprintf('\n实验四 V.22bis 端到端仿真   图片=%s  (RT60=%.2fs, SNR=%ddB, 频偏=%.1fHz)\n', ...
        img_name, RT60, SNR_dB, df_Hz);
fprintf('%-9s %-8s %-8s %-7s %-7s %-9s %s\n', ...
        '模式','DRR(dB)','时长(s)','EVM(%)','好帧','误像素','结论');
fprintf('%s\n', repmat('-',1,66));

for rate = [2400 1200]
  P = v22_params(rate);
  [payload, NN, MM] = v22_img2payload(imgdir, img_name, P.bps);
  frameBits = v22_pack(payload);
  [tx, ~]   = v22_mod(frameBits, P);
  imRef = v22_payload2img(payload);

  for DRR = [10 15 20 25]
    rng(20260918);

    % --- 信道 ---
    hh = zeros(1,Lh);  hh(1) = 1;
    hh = hh + tail*10^(-DRR/20);
    y  = filter(hh, 1, tx);
    y  = y + randn(size(y))*std(y)*10^(-SNR_dB/20);

    % 晶振失配 -> 载波频偏。注意实通带信号不能直接乘 exp(1i*2*pi*df*t) 再
    % 取实部——那是双边带调制不是频移（本文件第一版就栽在这里，EVM 恒高
    % 且与信道条件无关）。要先用 hilbert 取解析信号再搬移。
    ny = 0:numel(y)-1;
    y  = real(hilbert(y) .* exp(1i*2*pi*df_Hz*ny/P.fs));

    % --- 接收 ---
    [bits, info] = v22_demod(y, P);
    frames = v22_unpack(bits);
    good   = frames([frames.ok]);

    % --- 还原图片并逐像素比对 ---
    nbad = NaN;  note = '✗ 没解出好帧';
    for g = 1:numel(good)
        try
            im = v22_payload2img(good(g).payload);
            if isequal(size(im), size(imRef))
                nbad = sum(im(:) ~= imRef(:));
                if nbad == 0, note = '✓ 像素级还原'; else, note = '△ 有误像素'; end
                break
            end
        catch
        end
    end

    if isnan(nbad), sbad = '—'; else, sbad = sprintf('%d', nbad); end
    fprintf('%-9d %-8d %-8.2f %-7.1f %-7d %-9s %s\n', rate, DRR, ...
            numel(tx)/P.fs, info.evm*100, numel(good), sbad, note);
  end
end

fprintf('\n图片 %dx%d=%d 位   载荷 %d 字节   占带 %.0f~%.0f Hz\n', ...
        MM, NN, NN*MM, numel(payload), ...
        1200-600*1.75/2, 1200+600*1.75/2);

%% ---------------- 实测结论 ----------------
%
%  端到端（本脚本，ren512b 图片一帧，含 300 符号前导）：
%
%  模式        需要的 DRR    说明
%  ---------   ----------   --------------------------------------------
%  1200bps     ≥ 10 dB      QPSK，四档全部像素级还原
%  2400bps     ≥ 15 dB      16-QAM，10dB 时 EVM 32% 解不出帧
%
%  注：早先只测物理层 BER 时，2400bps 的门槛是 20dB——比这里严。差别有二：
%  那次是在 1200 符号的长突发上算 BER 且没有前导，载波环边收敛边计误码；
%  这里的帧只有 0.79s，且前面 300 符号前导已让环路稳住，之后整帧要么过
%  FCS 要么不过。两个数都对，只是问的问题不同：BER 问「平均错多少」，
%  FCS 问「这一帧能不能信」。做实验时按 20dB 留余量更稳妥。
%
%  两条推论，直接决定了接收模型的设计：
%
%  1) 判决反馈均衡器(DFE)可以不做。房间混响在符号率上表现为「又长又薄」
%     的拖尾——DRR=10dB 时主抽头占 91%，要 ±48 个符号才收满 99.9%。这种
%     散布的残余 ISI 等效于加性噪声，十几个抽头的 DFE 原理上抓不住（实测
%     15 前馈 + 12 反馈的 LMS DFE，EVM 几乎不变，高 DRR 下反而因失调噪声
%     更差：DRR=25dB 时 5.3% -> 7.1%）。与其做均衡，不如把麦克风摆近。
%
%  2) 速率回退是本实验的核心演示点，而不是附加功能。V.22bis 本就规定
%     2400/1200 两档，而声学信道恰好让这两档的分界清晰可见：麦克风摆远、
%     或换到空旷房间，16-QAM 就解不出而 QPSK 照常——这是真实 modem 协商
%     速率的物理原因，比任何文字解释都直观。
%
%  载波环：0.8Hz 的晶振失配在 1 秒里会转掉 288°，单次相位校正完全无效，
%  必须上环路。二阶环 Kp=0.05/Ki=2e-4 在两档下都能在 200 符号内捕获。
