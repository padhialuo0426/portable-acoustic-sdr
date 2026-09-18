function gui()
%GUI  实验五 SSTV Martin M1：默认发送二值图，也可选择任意图片保留彩色。
    here=fileparts(mfilename('fullpath'));addpath(fullfile(here,'..','common','matlab'));
    spec.title='实验五 · SSTV Martin M1 图像传输';
    spec.binary='sstv_rx';spec.outMat='sstvfreq.mat';spec.fs=48000;spec.showDuration=true;
    spec.buildParams=@(app,g,lab)buildParams(app,g,lab,here);
    spec.buildResults=@(app,panel)buildResults(app,panel);
    spec.durationText=@(~)durationText();
    spec.prepare=@(app)prepare(app);
    spec.analyze=@(app,file,meta)analyze(app,file,meta);
    % 校准只播放 1900 Hz 音调，不必先生成两分钟图像波形。
    spec.levelAudio=@(~)sin(2*pi*1900*(0:4*spec.fs-1)/spec.fs);
    asdr.App(spec,here);
end
function buildParams(app,g,lab,here)
    lab('SSTV 模式');uilabel(g,'Text','Martin M1 · 320×256');
    lab('发送图片');row=uigridlayout(g,[1 2]);row.ColumnWidth={'1x',50};row.Padding=[0 0 0 0];row.ColumnSpacing=4;
    app.ui.imageFile=uieditfield(row,'text','Editable','off', ...
        'Value',fullfile(here,'baseband_images','ren512b.bmp'));
    app.ui.chooseImage=uibutton(row,'Text','选择', 'ButtonPushedFcn',@(~,~)chooseImage(app));
    app.track(app.ui.chooseImage);
    lab('图片处理');app.ui.binary=uicheckbox(g,'Text','二值化发送','Value',true, ...
        'Tooltip','关闭后发送原图颜色；图片均等比缩放并补白到 320×256。', ...
        'ValueChangedFcn',@(~,~)preview(app));app.track(app.ui.binary);
end
function chooseImage(app)
    [name,folder]=uigetfile({'*.bmp;*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.gif','图片文件';'*.*','全部文件'},'选择发送图片');
    if isequal(name,0),return,end
    file=fullfile(folder,name);
    try
        sstv_prepare_image(file,app.ui.binary.Value,sstv_params());
    catch e
        app.logStep('图片','✗','%s',asdr.firstLine(e.message));return
    end
    app.ui.imageFile.Value=file;app.ui.imageFile.Tooltip=file;preview(app);
end
function buildResults(app,panel)
    app.fig.Position(3:4)=[1200 850];
    g=uigridlayout(panel,[5 2]);g.RowHeight={28,22,22,'1x','1x'};g.ColumnWidth={'1x','1.2x'};g.RowSpacing=4;
    app.ui.qualityTxt=uilabel(g,'FontSize',16,'FontWeight','bold');app.ui.qualityTxt.Layout.Column=[1 2];
    app.ui.qualityTxt.Tooltip='二值像素误差率只比较完整接收行的黑白判决；它不是数字通信中的信道 BER。';
    app.ui.statusTxt=uilabel(g);app.ui.statusTxt.Layout.Column=[1 2];
    app.ui.detailTxt=uilabel(g);app.ui.detailTxt.Layout.Column=[1 2];
    app.ui.axTx=uiaxes(g);app.ui.axTx.Layout.Row=4;app.ui.axTx.Layout.Column=1;
    app.ui.axRx=uiaxes(g);app.ui.axRx.Layout.Row=5;app.ui.axRx.Layout.Column=1;
    app.ui.axF=uiaxes(g);app.ui.axF.Layout.Row=[4 5];app.ui.axF.Layout.Column=2;
    resetResults(app);
end
function [text,duration]=durationText()
    P=sstv_params();duration=round(P.duration*P.fs)/P.fs;
    text=sprintf('%.2f s（320×256，VIS 44，G/B/R）',duration);
end
function preview(app)
    resetResults(app);app.refreshTiming();
    try
        source=sstv_prepare_image(app.ui.imageFile.Value,app.ui.binary.Value,sstv_params());
        showImage(app.ui.axTx,source,'本次发送图片');
    catch e
        app.logStep('图片','✗','%s',asdr.firstLine(e.message));
    end
end
function meta=prepare(app)
    resetResults(app);P=sstv_params();binary=app.ui.binary.Value;
    reference=sstv_prepare_image(app.ui.imageFile.Value,binary,P);
    [audio,tx]=sstv_modulate(reference,P);
    meta=struct('x',audio,'dur',tx.duration,'desc','Martin M1 · 320×256', ...
        'reference',reference,'binary',binary,'P',P);
    showImage(app.ui.axTx,reference,'本次发送图片');
end
function analyze(app,file,meta)
    resetResults(app);showImage(app.ui.axTx,meta.reference,'本次发送图片');
    if ~isfile(file)
        app.ui.statusTxt.Text='接收状态：数据文件不存在';app.logStep('解码','✗','没有 %s',file);return
    end
    try
        S=load(file);
        if ~isfield(S,'sstvFreq'),error('sstv:Data','文件缺少 sstvFreq。');end
        validateattributes(S.sstvFreq,{'numeric'}, ...
            {'2d','nrows',meta.P.frameSamples+1,'nonempty','real','finite'});
    catch e
        app.ui.statusTxt.Text='接收状态：数据格式无效';app.logStep('数据检查','✗','%s',asdr.firstLine(e.message));return
    end
    f=reshape(S.sstvFreq(2:end,:),1,[]);
    if ~app.deadStreamOK(all(f==0)),app.ui.statusTxt.Text='接收状态：全零频率，没有可用信号';return,end
    result=sstv_decode_frequency(f,meta.P);app.ui.lastReport=result;
    app.ui.statusTxt.Text=['接收状态：' result.message];app.ui.statusTxt.Tooltip=result.message;
    if isfinite(result.headerStart),start=max(1,round(result.headerStart-.65*meta.P.fs));else,start=1;end
    stop=min(numel(f),start+round(1.5*meta.P.fs));ix=start:24:stop;
    plot(app.ui.axF,(ix-1)/meta.P.fs,f(ix));ylim(app.ui.axF,[800 2600]);grid(app.ui.axF,'on');
    xlabel(app.ui.axF,'采集时间（秒）');ylabel(app.ui.axF,'音频频率（赫兹）');title(app.ui.axF,'VIS 与首行音调');
    app.logStep('SSTV','·','%s',result.message);
    if isempty(result.image),return,end
    showImage(app.ui.axRx,result.image,sprintf('本次接收：%d/256 行（未解行灰色）',sum(result.validRows)));
    metrics=sstv_metrics(result,meta.reference,meta.binary);app.ui.lastMetrics=metrics;
    if metrics.available
        if meta.binary
            app.ui.qualityTxt.Text=sprintf('二值像素误差率：%d/%d = %.6f',metrics.pixelErrors,metrics.pixels,metrics.pixelErrorRate);
        else
            app.ui.qualityTxt.Text=sprintf('有效行图像质量：PSNR %.2f dB',metrics.psnr);
        end
        app.ui.detailTxt.Text=sprintf('有效行 MAE %.2f / 255，PSNR %.2f dB；行时钟偏差 %+.0f ppm',metrics.mae,metrics.psnr,result.clockPpm);
        app.logStep('图像质量','·','MAE %.3f，PSNR %.2f dB，完整行 %d/256',metrics.mae,metrics.psnr,sum(result.validRows));
        if meta.binary,app.logf('二值像素误差：%d/%d；缺失行不参与比较。',metrics.pixelErrors,metrics.pixels);end
    end
end
function resetResults(app)
    if app.ui.binary.Value,app.ui.qualityTxt.Text='二值像素误差率：—';else,app.ui.qualityTxt.Text='图像质量：—';end
    app.ui.statusTxt.Text='接收状态：等待本次结果';app.ui.statusTxt.Tooltip='';
    app.ui.detailTxt.Text='SSTV 传输模拟亮度，VIS 偶校验只检查模式标识，图片不带 FCS。';
    app.ui.lastReport=[];app.ui.lastMetrics=[];
    cla(app.ui.axTx);axis(app.ui.axTx,'off');title(app.ui.axTx,'发送图片');
    cla(app.ui.axRx);axis(app.ui.axRx,'off');title(app.ui.axRx,'接收还原（等待本次结果）');
    cla(app.ui.axF);title(app.ui.axF,'VIS 与首行音调');
end
function showImage(ax,rgb,label)
    image(ax,rgb);axis(ax,'image');axis(ax,'off');title(ax,label);
end
