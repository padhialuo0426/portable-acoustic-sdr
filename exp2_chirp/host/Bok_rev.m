%% 利用回传数据恢复并显示图片（支持任意尺寸：帧间距与点阵尺寸自适应）
%% 路径与图片选择（须与 Bok_emit 发送的同一张图片一致）%%
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
img_name = 'lzu2048b.bmp';            % ← 与发送端 Bok_emit 的 img_name 保持一致
imgdir   = fullfile(here,'..','baseband_images');

%% 抽样值 %%
load(fullfile(here,'chirp5.mat'))     %接收端(chirp_rx)产出的抽样判决数据，放到本目录
x=toFileData5(2,:);
load(fullfile(here,'info_all.mat'))   %Bok_emit 发射时生成的原始比特，用于算 BER

%% 由发送图片确定点阵尺寸与帧间距 %%
imdata=imread(fullfile(imgdir,img_name));
[NN,MM]=size(imdata);                 %NN=行(高)，MM=列(宽)
L=NN*MM;                              %图片比特数
gap=L+15;                             %两段 m 序列起点间距 = 图片长度 + m序列长度

%% 寻找帧开始符和结束符的位置 %% ;
loc=[];
flag=1;
for n=1:length(x)-14
    if x(n:n+14)*(flag)*[-1;1;1;-1;-1;1;-1;1;-1;-1;-1;-1;1;1;1] > sum(abs(x(n:n+10))) && abs(x(n))==1
        loc=[loc,n];
    end
end
loc1=[]; loc2=[];
for n=1:length(loc)-1
    for m=n+1:length(loc)
        if (loc(m)-loc(n))==gap        %图片信息长度 L，m序列长度15，间距 L+15
            loc1=loc(n); loc2=loc(m);
            break
        end
    end
    if ~isempty(loc2), break, end
end
if isempty(loc2)
    error('未找到相距 %d 的帧头/帧尾 m 序列，检查图片是否与发送端一致、采集时长是否足够。', gap);
end

%% 硬判决，统计BER %%
output=x(loc1+15:loc2-1);
ber1=0;
loc_error1=[];
for i=1:length(output)
    if output(i)>0               %与发射端对应，miu=1，为码元0；miu=-1时，为码元1
        info_decode(i)=0;
    else
        info_decode(i)=1;
    end
    if info_decode(i)~=info_all(i)
        ber1=ber1+1;
        loc_error1= [loc_error1,i];
    end
end
BER=ber1/length(info_decode)

%% 恢复图片（按真实宽高还原）%%
bmp_figure=zeros(NN,MM);
for m=1:MM
    for n=1:NN
        bmp_figure(n,m)=info_decode(1,(m-1)*NN+n);
    end
end
figure;
imshow(logical(bmp_figure));
title(['树莓派接收图片: ' img_name])
