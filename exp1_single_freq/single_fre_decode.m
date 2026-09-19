%% 实验一 · 独立 MATLAB 顺序分析脚本：时域与频谱
% 输入接收端保存的 MAT，输出工作区中的时域、频谱及谱峰 fpeak。
% raw.mat/rawAudio 是原始样本；single_f.mat/toFileData 含接收模型输出。

%% 1. 输入文件与采样率
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
MAT_FILE = 'raw.mat';
MAT_VARIABLE = 'rawAudio';
matfile = fullfile(here,MAT_FILE);
varname = MAT_VARIABLE;

fs = 8000;                                   % 采样率
S  = load(matfile);
X  = S.(varname);

%% 2. 样本还原：去掉时间行并去直流
% 若含时间行(81行)则去掉第1行；逐列拼成单列
if size(X,1) == 81, X = X(2:end, :); end
y = X(:);
y = y - mean(y);                             % 去直流
N = numel(y);
t = (0:N-1)/fs;

%% 3. FFT 与谱峰定位
Y  = fft(y);
f  = (-N/2:N/2-1)*(fs/N);
Ys = fftshift(abs(Y))/N;

% 找正频率侧峰值
pos = f > 0;
[pk, idx] = max(Ys(pos));
fpos = f(pos);
fpeak = fpos(idx);

%% 4. 显示时域和频谱
figure('Name', sprintf('%s / %s', matfile, varname));
subplot(2,1,1);
plot(t, y); grid on;
xlabel('时间 (s)'); ylabel('幅度'); title('时域波形');

subplot(2,1,2);
plot(f, Ys); grid on; xlim([0 fs/2]);
xlabel('频率 (Hz)'); ylabel('|Y|'); title('频谱 (FFT)');
hold on; plot(fpeak, pk, 'rv', 'MarkerFaceColor','r');
text(fpeak, pk, sprintf('  峰值 %.1f Hz', fpeak), 'Color','r');

fprintf('样本数=%d  时长=%.2fs  频谱峰值 ≈ %.1f Hz\n', N, N/fs, fpeak);
