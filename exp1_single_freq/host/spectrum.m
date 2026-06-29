function spectrum(matfile, varname)
% SPECTRUM  读取本工程产出的 .mat，画时域波形与频谱（FFT）。
%   spectrum                       % 默认读 raw.mat 的 rawAudio
%   spectrum('single_f.mat','toFileData')
%
% 约定：
%   rawAudio    为 80×N（每列一帧，未滤波原始麦克风信号）
%   toFileData  为 81×N（第1行时间，其余80行为样本）
% 本脚本把逐帧多列拼成单列长向量后做 FFT。

    if nargin < 1 || isempty(matfile),  matfile = 'raw.mat';   end
    if nargin < 2 || isempty(varname)
        if strcmp(matfile,'raw.mat'), varname = 'rawAudio';
        else,                          varname = 'toFileData'; end
    end

    fs = 8000;                                   % 采样率
    S  = load(matfile);
    X  = S.(varname);

    % 若含时间行(81行)则去掉第1行；逐列拼成单列
    if size(X,1) == 81, X = X(2:end, :); end
    y = X(:);
    y = y - mean(y);                             % 去直流
    N = numel(y);
    t = (0:N-1)/fs;

    % FFT（双边 -> 移到中心）
    Y  = fft(y);
    f  = (-N/2:N/2-1)*(fs/N);
    Ys = fftshift(abs(Y))/N;

    % 找正频率侧峰值
    pos = f > 0;
    [pk, idx] = max(Ys(pos));
    fpos = f(pos);
    fpeak = fpos(idx);

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
end
