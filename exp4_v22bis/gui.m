function gui()
%GUI  实验四 · V.22bis 声学 modem —— 一键声学实测界面
%
%   用法：cd 到本文件所在目录(exp4_v22bis/)后直接运行 gui
%
%   把手动流程串成一次点击：
%     板上启动 v22_rx 采集 → 宿主机扬声器播放 V.22bis 信号 → 等采集窗口跑完
%     → 取回 v22sym.mat → 判决/差分/解扰/HDLC → 显示 BER 与还原点阵
%
%   界面骨架、板上连接、同步编译、电平校准都在 common/matlab/+asdr 里，
%   四个实验共用；本文件只提供 V.22bis 特有的组帧/调制/解码。
%
%   与实验二/三的 gui.m 有一处结构差别：那两个能直接用
%   asdr.ImageUI.analyze（板上出的是 2×N 的标量判决流，解码就是扫 m 序列）；
%   本实验板上出的是 121×N 的复符号，解码走 HDLC，所以 analyze 自己写。
%   发图下拉、结果面板、点阵显示仍然复用 ImageUI。
%
%   注意：本界面是便利封装。教学正路仍是 v22_emit / v22_rev 两个脚本手动跑。
%   与前三个实验不同，本文件**不重复**组帧/调制/解码逻辑——那些已经抽成
%   v22_mod / v22_demod / v22_pack / v22_unpack 等函数，界面直接调用，
%   不存在"改帧结构要改两边"的问题。

    here = fileparts(mfilename('fullpath'));
    if isempty(here), here = pwd; end
    addpath(fullfile(here,'..','common','matlab'));   % +asdr 共用层

    P.imgdir = fullfile(here,'baseband_images');

    spec.title    = '实验四 · V.22bis 声学 modem —— 一键声学实测';
    spec.binary   = 'v22_rx';
    spec.outMat   = 'v22sym.mat';
    spec.fs       = 9600;                  % 本实验采样率，不是其它实验的 8000
    spec.showDuration = true;
    spec.buildParams  = @(app,gL,lab) buildParams(app, gL, lab, P);
    spec.buildResults = @(app,panel)  buildResults(app, panel);
    spec.durationText = @(app) durationText(app, P);
    spec.prepare      = @(app) prepare(app, P);
    spec.analyze      = @(app,f,meta) analyze(app, f, meta, P);
    asdr.App(spec, here);
end

%% ------------------------- 界面 -------------------------

function buildParams(app, gL, lab, P)
    asdr.ImageUI.buildParams(app, gL, lab, P.imgdir);   % 发送图片下拉
    lab('速率');
    app.ui.rate = uidropdown(gL, 'Items', {'2400 bps (16-QAM)','1200 bps (QPSK)'}, ...
                             'Value', '2400 bps (16-QAM)', ...
                             'ValueChangedFcn', @(~,~) rateChanged(app));
    app.track(app.ui.rate);
end

function buildResults(app, panel)
    % 为诊断行留出空间，发送与接收点阵仍上下排列。
    app.fig.Position(3:4) = max(app.fig.Position(3:4),[1120 800]);
    g = uigridlayout(panel, [6 2]);
    g.RowHeight = {28,22,22,28,'1x','1x'};
    g.RowSpacing = 4;
    g.ColumnWidth = {'1x','1.5x'};
    app.ui.berTxt = uilabel(g,'Text','BER: —','FontSize',16,'FontWeight','bold');
    app.ui.berTxt.Layout.Row = 1; app.ui.berTxt.Layout.Column = [1 2];
    app.ui.berTxt.Tooltip = '仅比较通过 FCS 的还原图片与本次参考图片。';
    app.ui.diagnosticTxt = uilabel(g,'Text','校验前图片 BER: —');
    app.ui.diagnosticTxt.Layout.Row = 2; app.ui.diagnosticTxt.Layout.Column = [1 2];
    app.ui.diagnosticTxt.Tooltip = '仅诊断：完整边界、合法去填充、图片头和长度匹配且候选唯一时比较图片比特；不含帧头、FCS、填充位和前后导。';
    app.ui.statusTxt = uilabel(g,'Text','接收状态: —');
    app.ui.statusTxt.Layout.Row = 3; app.ui.statusTxt.Layout.Column = [1 2];
    sg = uigridlayout(g,[1 2]);
    sg.Layout.Row = 4; sg.Layout.Column = [1 2];
    sg.Padding = [0 0 0 0]; sg.ColumnWidth = {'1x',80};
    app.ui.statsTxt = uilabel(sg);
    app.ui.statsTxt.Tooltip = '本窗口按速率累计：仅计已取回且数据格式有效的实采；FCS 通过并可还原图片算成功。仅解码、取消、连接或文件异常不计数。';
    app.ui.resetStats = uibutton(sg,'Text','清零统计', ...
        'ButtonPushedFcn',@(~,~) resetStats(app));
    app.track(app.ui.resetStats);
    resetStats(app);
    app.ui.axTx = uiaxes(g);  title(app.ui.axTx,'发送点阵');  axis(app.ui.axTx,'off');
    app.ui.axTx.Layout.Row = 5; app.ui.axTx.Layout.Column = 1;
    app.ui.axRx = uiaxes(g);  title(app.ui.axRx,'接收还原');  axis(app.ui.axRx,'off');
    app.ui.axRx.Layout.Row = 6; app.ui.axRx.Layout.Column = 1;
    cg = uigridlayout(g,[2 1]); cg.RowHeight = {28,'1x'};
    cg.Layout.Row = [5 6]; cg.Layout.Column = 2;
    app.ui.constellationScope = uidropdown(cg, ...
        'Items',{'有效图片帧','全部接收符号'}, 'Value','有效图片帧', ...
        'Tooltip','有效图片帧仅显示本次通过 FCS 的图片帧；全部符号包含静音与捕获过程。', ...
        'ValueChangedFcn',@(~,~) drawConstellation(app));
    app.track(app.ui.constellationScope);
    app.ui.axC = uiaxes(cg);
    resetResults(app);
end

function r = pickRate(app)
    if startsWith(app.ui.rate.Value,'1200'), r = 1200; else, r = 2400; end
end

function rateChanged(app)
    app.refreshTiming();
    resetResults(app);
    refreshStats(app);
end

function resetStats(app)
    app.ui.captureStats = struct('rate',{1200,2400},'total',{0,0}, ...
                                'passed',{0,0},'ids',{{},{}});
    refreshStats(app);
end

function refreshStats(app)
    s = app.ui.captureStats([app.ui.captureStats.rate] == pickRate(app));
    if s.total == 0
        value = sprintf('%d bps：实采 0 次，成功率 —，帧错误率 —',s.rate);
    else
        value = sprintf('%d bps：成功 %d/%d (%.1f%%)，帧错误率 %.1f%%', ...
            s.rate,s.passed,s.total,100*s.passed/s.total,100*(s.total-s.passed)/s.total);
    end
    app.ui.statsTxt.Text = value;
end

function recordCapture(app, meta, passed)
    % 仅实采回调有唯一标识；校准和重复解码不会把同一份数据计为新发送。
    if ~isfield(meta,'captureId'), return, end
    k = find([app.ui.captureStats.rate] == meta.P.rate,1);
    s = app.ui.captureStats(k);
    if any(strcmp(s.ids,meta.captureId)), return, end
    s.ids{end+1} = meta.captureId;
    s.total = s.total + 1;
    s.passed = s.passed + double(passed);
    app.ui.captureStats(k) = s;
    refreshStats(app);
    app.logStep('累计实采','·','%d bps：有效图片帧 %d/%d，失败 %d', ...
        s.rate,s.passed,s.total,s.total-s.passed);
end

%% ------------------------- V.22bis 特有部分 -------------------------

% 「信号时长」那一行。走 v22_pack 拿到精确帧长（组帧很便宜，没做调制），
% 再加上成形滤波拖尾——采集窗口 -t 是按这个数算的，宁可算准。
function [txt, dur] = durationText(app, P)
    Pm = v22_params(pickRate(app));
    [payload, NN, MM] = v22_img2payload(P.imgdir, app.ui.img.Value, Pm.bps);
    nbit = numel(v22_pack(payload));                % 含标志与位填充，精确值
    nsym = Pm.preambleSyms + ceil(nbit/Pm.bps) + Pm.postambleSyms;
    dur  = (nsym*Pm.sps + Pm.span*Pm.sps) / Pm.fs;  % 加成形滤波拖尾
    txt  = sprintf('%.2f s（%d 符号 / %d 位 / %d 字节载荷）', ...
                   dur, nsym, NN*MM, numel(payload));
end

% 组帧 + 调制。直接调用与脚本、仿真同一份实现。
function meta = prepare(app, P)
    % 新任务在连接/采集之前就清空旧结果；中止或下载失败也不会遗留成功图。
    resetResults(app);
    name = app.ui.img.Value;
    Pm   = v22_params(pickRate(app));
    [payload, NN, MM] = v22_img2payload(P.imgdir, name, Pm.bps);
    x = v22_mod(v22_pack(payload), Pm);

    meta.x       = x / max(abs(x));
    meta.dur     = numel(x) / Pm.fs;
    meta.desc    = sprintf('%s  %dx%d=%d 位  %d bps', name, MM, NN, NN*MM, Pm.rate);
    meta.P       = Pm;
    meta.receiverArgs = {'-b',num2str(Pm.rate)};
    meta.payload = payload;
    meta.NN = NN;  meta.MM = MM;
    asdr.ImageUI.showBitmap(app.ui.axTx, v22_payload2img(payload), '本次发送点阵');
end

% 解码：读 v22sym.mat -> 判决/差分/解扰 -> HDLC -> BER + 点阵 + 星座
function analyze(app, matfile, meta, ~)
    resetResults(app);
    app.ui.berTxt.Text = 'BER: 未解出帧';
    app.ui.berTxt.FontColor = [0.8 0 0];
    Pm = meta.P;
    imRef = v22_payload2img(meta.payload);
    asdr.ImageUI.showBitmap(app.ui.axTx, imRef, '本次发送点阵');
    if ~isfile(matfile)
        app.ui.statusTxt.Text = '接收状态: 本地数据文件不存在（不计入实采统计）';
        app.logStep('解码', '✗', '本地没有 %s，先做一次实测', app.spec.outMat); return
    end
    try
        S = load(matfile);
    catch e
        app.ui.statusTxt.Text = '接收状态: 无法读取数据文件（不计入实采统计）';
        app.logStep('数据检查','✗','%s',asdr.firstLine(e.message));
        return
    end
    if ~isfield(S,'v22Sym')
        app.ui.statusTxt.Text = '接收状态: 文件缺少 v22Sym（不计入实采统计）';
        app.logStep('解码', '✗', '文件里没有 v22Sym 变量'); return
    end
    D = S.v22Sym;
    try
        validateattributes(D, {'numeric'}, {'2d','nrows',121,'nonempty','real','finite'});
    catch e
        app.ui.statusTxt.Text = '接收状态: 符号数据格式无效（不计入实采统计）';
        app.logStep('数据检查','✗','%s',asdr.firstLine(e.message));
        return
    end
    nF = size(D,2);

    V   = D(2:end,:);
    sym = complex(zeros(1, nF*60));
    for k = 1:nF
        c = V(:,k).';
        sym((k-1)*60 + (1:60)) = c(1:2:end) + 1i*c(2:2:end);
    end
    app.ui.constellation.all = sym;
    app.ui.constellation.rate = Pm.rate;
    drawConstellation(app);
    if ~app.deadStreamOK(all(sym == 0))
        app.ui.statusTxt.Text = '接收状态: 全零符号，未检测到可用接收数据';
        app.ui.diagnosticTxt.Text = '校验前图片 BER: 无法计算（全零符号）';
        recordCapture(app,meta,false);
        return
    end

    bits = v22_symbols_to_bits(sym, Pm);
    report = v22_diagnose(bits,meta.payload);
    app.ui.lastReport = report;
    d = report.hdlc;
    app.ui.statusTxt.Text = ['接收状态: ' report.message];
    app.ui.statusTxt.Tooltip = report.message;
    app.logStep('帧边界','·','标志 %d 个，相邻区间 %d 个（可能包含误识别）', ...
        d.flagCount,d.intervalCount);
    app.logStep('帧格式','·','过短 %d，位填充非法 %d，去填充后长度异常 %d', ...
        d.shortCount,d.stuffingErrorCount,d.lengthErrorCount);
    if d.fcsPassed == 0, mark = '✗'; else, mark = '✓'; end
    app.logStep('HDLC',mark,'候选帧 %d 个，FCS 通过 %d 个，失败 %d 个', ...
        d.candidateCount,d.fcsPassed,d.fcsFailed);
    app.logStep('图片格式','·','FCS 通过但图片无效 %d 个',report.invalidImages);
    diag = report.diagnostic;
    if diag.available
        app.ui.diagnosticTxt.Text = sprintf('校验前图片 BER: %d/%d = %.4f（仅诊断）', ...
            diag.errors,diag.bits,diag.ber);
        app.logStep('校验前图片 BER','·','%d/%d = %.6f，仅诊断，不放宽 FCS', ...
            diag.errors,diag.bits,diag.ber);
    else
        app.ui.diagnosticTxt.Text = '校验前图片 BER: 无法可靠对齐（详见日志）';
        app.logStep('校验前图片 BER','—','无法计算：%s',diag.reason);
    end

    img = report.image;
    recordCapture(app,meta,~isempty(img));
    if ~isempty(img)
        % 解扰不改变比特数。用接收帧的真实边界映射回原始复符号，
        % 包括 HDLC 标志和位填充；不按理想星座判决值重画。
        first = floor((report.frameRange(1)-1)/Pm.bps)+1;
        last = ceil(report.frameRange(2)/Pm.bps);
        app.ui.constellation.frame = sym(first:last);
        app.ui.constellation.range = [first last];
    end

    drawConstellation(app);

    if isempty(img)
        app.ui.berTxt.Text = 'BER: 未解出帧';
        app.ui.berTxt.FontColor = [0.8 0 0];
        app.logStep('解码', '✗', '%s',report.message);
        app.logf('  可将星座范围切换为「全部接收符号」检查捕获过程；其中也包含静音和噪声。');
        return
    end

    if isequal(size(img), size(imRef))
        nbad = sum(img(:) ~= imRef(:));
        L = numel(img);
        app.ui.berTxt.Text = sprintf('BER = %d/%d = %.4f', nbad, L, nbad/L);
        if nbad == 0
            app.ui.berTxt.FontColor = [0 0.5 0];
            app.logStep('BER', '✓', '0/%d，实验四通过', L);
        else
            app.ui.berTxt.FontColor = [0.8 0 0];
            app.logStep('BER', '△', '%.4f 有误码，检查电平/环境噪声', nbad/L);
        end
    else
        app.ui.berTxt.Text = 'BER: 图片尺寸不同，无法比较';
        app.ui.berTxt.FontColor = [0.7 0.4 0];
        app.logStep('BER', '△', '收到 %dx%d，本次参考 %dx%d，跳过误码率比较', ...
                    size(img,2),size(img,1),size(imRef,2),size(imRef,1));
    end

    asdr.ImageUI.showBitmap(app.ui.axRx, img,   '接收还原');
end

function resetResults(app)
    cla(app.ui.axTx); axis(app.ui.axTx,'off'); title(app.ui.axTx,'发送点阵');
    cla(app.ui.axRx); axis(app.ui.axRx,'off'); title(app.ui.axRx,'接收还原（等待本次结果）');
    app.ui.berTxt.Text = 'BER: —';
    app.ui.berTxt.FontColor = [0 0 0];
    app.ui.diagnosticTxt.Text = '校验前图片 BER: —';
    app.ui.statusTxt.Text = '接收状态: —';
    app.ui.statusTxt.Tooltip = '';
    app.ui.lastReport = [];
    app.ui.constellation = struct('all',[],'frame',[],'range',[],'rate',[]);
    drawConstellation(app);
end

function drawConstellation(app)
    ax = app.ui.axC;
    cla(ax); legend(ax,'off'); hold(ax,'off');
    d = app.ui.constellation;
    if strcmp(app.ui.constellationScope.Value,'有效图片帧')
        points = d.frame; label = '有效图片帧星座';
        emptyText = '暂无有效图片帧';
    else
        points = d.all; label = '全部接收符号（含静音与捕获过程）';
        emptyText = '暂无本次接收数据';
    end
    if isempty(points)
        axis(ax,'normal'); xlim(ax,[-1 1]); ylim(ax,[-1 1]);
        text(ax,0.5,0.5,emptyText,'Units','normalized','HorizontalAlignment','center');
        title(ax,label);
    else
        plot(ax,real(points),imag(points),'.','MarkerSize',5,'DisplayName','实收符号');
        extent = max([abs(real(points)), abs(imag(points))]);
        % 参考点只作对照，实收点保持原始幅度和相位，不做吸附或美化。
        if ismember(d.rate,[1200 2400])
            Pm = v22_params(d.rate);
            ref = reshape(Pm.inQ(:) * [1 1i -1 -1i],1,[]);
            extent = max([extent, abs(real(ref)), abs(imag(ref))]);
            hold(ax,'on');
            if d.rate==1200,referenceLabel='QPSK 参考';else,referenceLabel='16-QAM 参考';end
            plot(ax,real(ref),imag(ref),'kx','MarkerSize',8,'DisplayName',referenceLabel);
            hold(ax,'off'); legend(ax,'show','Location','best');
        end
        % 两轴同尺度且关于零对称，让坐标原点始终位于星座图中央。
        lim = max(1, 1.1*extent);
        axis(ax,'equal'); xlim(ax,[-lim lim]); ylim(ax,[-lim lim]);
        title(ax,sprintf('%s（%d 符号）',label,numel(points)));
    end
    ax.XAxisLocation = 'origin'; ax.YAxisLocation = 'origin';
    xlabel(ax,'I'); ylabel(ax,'Q'); grid(ax,'on');
end
