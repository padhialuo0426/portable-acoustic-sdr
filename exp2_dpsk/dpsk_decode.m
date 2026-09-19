%% 实验二 · 独立 MATLAB 顺序解码脚本：DPSK 点阵恢复
%% 1. 输入文件与参考图片（须与发送端一致）
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
img_name = 'ren512b.bmp';           % ← 与发送端 dpsk_emit 的 img_name 保持一致
imgdir   = fullfile(here,'baseband_images');

%% 2. 读入抽样判决数据和发送参考
load(fullfile(here,'dpsk5.mat'))      % 接收端(dpsk_rx)产出的判决数据，放到本目录
x = toFileData5(2,:);
load(fullfile(here,'info_all.mat'))   % dpsk_emit 发射时生成的原始比特，用于算 BER

%% 3. 确定点阵尺寸与同步标记间距
imdata = imread(fullfile(imgdir,img_name));
[NN,MM] = size(imdata);               % NN=行(高)，MM=列(宽)
L   = NN*MM;                          % 图片比特数
gap = L + 15;                         % 两段 m 序列起点间距

%% 4. 首尾 m 序列定位
% 判决值是相关幅度(量级可达 1e6)，不是 ±1，门限按整段峰值自适应而不是写死
pm  = [-1;1;1;-1;-1;1;-1;1;-1;-1;-1;-1;1;1;1];
thr = max(abs(x)) * 0.02;
loc = [];
for n = 1:length(x)-14
    if x(n:n+14)*pm > sum(abs(x(n:n+11))) && abs(x(n)) > thr
        loc = [loc, n];  %#ok<AGROW>
    end
end
loc1 = []; loc2 = [];
for n = 1:length(loc)-1
    k = find(loc(n+1:end) - loc(n) == gap, 1);
    if ~isempty(k)
        loc1 = loc(n);  loc2 = loc(n) + gap;  break
    end
end
if isempty(loc2)
    error(['未找到相距 %d 的帧头/帧尾 m 序列。检查图片是否与发送端一致、' ...
           '采集时长是否足够。'], gap);
end

%% 5. 判决图片比特并统计 BER
output = x(loc1+15 : loc2-1);
info_decode = zeros(1,L);
ber1 = 0;  loc_error1 = [];
for i = 1:length(output)
    if output(i) > 0
        info_decode(i) = 0;
    else
        info_decode(i) = 1;
    end
    if info_decode(i) ~= info_all(i)
        ber1 = ber1 + 1;
        loc_error1 = [loc_error1, i];  %#ok<AGROW>
    end
end
BER = ber1/length(info_decode)

%% 6. 按实际宽高还原并显示点阵
bmp_figure = zeros(NN,MM);
for m = 1:MM
    for n = 1:NN
        bmp_figure(n,m) = info_decode(1,(m-1)*NN+n);
    end
end
figure;
imshow(logical(bmp_figure));
title(['树莓派接收图片: ' img_name])
