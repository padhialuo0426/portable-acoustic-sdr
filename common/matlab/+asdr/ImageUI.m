classdef ImageUI
%IMAGEUI  实验二/实验三共用的「发图片」界面部件与解码收尾。
%
%   两个实验都是把一张 1-bit 图片当基带信息发出去，板上每个码元/符号吐一个
%   判决值，PC 端帧同步后算 BER 并还原点阵——界面和收尾完全一样，不一样的
%   只有调制方式（DPSK / chirp）和帧同步的判据。前者由各自的 gui.m 提供。

    methods (Static)

        % 「发送图片」下拉。改图片要重算时长，所以挂 refreshTiming。
        function buildParams(app, gL, lab, imgdir)
            items = asdr.ImageUI.listImages(imgdir);
            lab('发送图片');
            app.ui.img = uidropdown(gL, 'Items', items, ...
                                    'Value', asdr.ImageUI.pickDefault(items), ...
                                    'ValueChangedFcn', @(~,~) app.refreshTiming());
            app.track(app.ui.img);
        end

        % 结果面板：一行 BER + 左右两张点阵
        function buildResults(app, panel)
            g = uigridlayout(panel, [2 2]);  g.RowHeight = {28,'1x'};
            app.ui.berTxt = uilabel(g,'Text','BER: —','FontSize',16,'FontWeight','bold');
            app.ui.berTxt.Layout.Column = [1 2];
            app.ui.axTx = uiaxes(g);  title(app.ui.axTx,'发送点阵');  axis(app.ui.axTx,'off');
            app.ui.axRx = uiaxes(g);  title(app.ui.axRx,'接收还原');  axis(app.ui.axRx,'off');
        end

        % 读回 .mat -> 帧同步/判决 -> BER -> 画点阵。
        %   decodeFn(xs, info_all, NN, MM) -> [ber, bmp, l1, l2, flag]
        function analyze(app, matfile, meta, imgdir, expLabel, decodeFn)
            outMat = app.spec.outMat;
            if ~isfile(matfile)
                app.logStep('解码', '✗', '本地没有 %s，先做一次实测', outMat); return
            end
            S = load(matfile);
            if ~isfield(S,'toFileData5')
                app.logStep('解码', '✗', '文件里没有 toFileData5 变量'); return
            end
            validateattributes(S.toFileData5, {'numeric'}, ...
                               {'2d','nrows',2,'nonempty','real','finite'});
            xs = S.toFileData5(2,:);            % 第 1 行是时间，第 2 行是判决值
            if ~app.deadStreamOK(all(xs == 0)), return, end

            [ber, bmp, l1, l2, flag] = decodeFn(xs, meta.info_all, meta.NN, meta.MM);
            app.logStep('帧同步', '✓', '帧头 %d / 帧尾 %d（极性 %+d）', l1, l2, flag);

            L = meta.NN * meta.MM;
            app.ui.berTxt.Text = sprintf('BER = %d/%d = %.4f', round(ber*L), L, ber);
            if ber == 0
                app.ui.berTxt.FontColor = [0 0.5 0];
                app.logStep('BER', '✓', '0/%d，%s通过', L, expLabel);
            else
                app.ui.berTxt.FontColor = [0.8 0 0];
                app.logStep('BER', '△', '%.4f 有误码，检查电平/环境噪声', ber);
            end

            asdr.ImageUI.showBitmap(app.ui.axTx, imread(fullfile(imgdir, app.ui.img.Value)), '发送点阵');
            asdr.ImageUI.showBitmap(app.ui.axRx, bmp, '接收还原');
        end

        % 读图并按列优先展开成比特流（与各实验的 *_emit.m 一致）
        function [info_all, NN, MM] = readBits(imgdir, name)
            imdata = imread(fullfile(imgdir, name));
            if ~ismatrix(imdata) || ~all(imdata(:) == 0 | imdata(:) == 1)
                error('发送图片必须为只含 0/1 的单通道二值 BMP。');
            end
            data = double(imdata);
            [NN, MM] = size(data);              % NN=行(高)  MM=列(宽)
            info_all = zeros(1, NN*MM);
            for m = 1:MM
                for nn = 1:NN
                    info_all((m-1)*NN+nn) = data(nn,m);
                end
            end
        end

        % 帧头/帧尾两段 m 序列相距 L+15，据此在判决流里定位。
        %   corrOK(xs, p, fl) 由各实验给出：DPSK 的判决值是相关幅度要按峰值
        %   自适应定门限，chirp 的判决值就是 ±1 可以直接比。
        function [ber, bmp, l1, l2, flag] = syncAndDecide(xs, info_all, NN, MM, corrOK)
            L = NN*MM;  gap = L + 15;
            best = [];
            for fl = [1 -1]
                loc = [];
                for p = 1:numel(xs)-14
                    if corrOK(xs, p, fl)
                        loc(end+1) = p; %#ok<AGROW>
                    end
                end
                for i = 1:numel(loc)-1
                    if any(loc(i+1:end) - loc(i) == gap)
                        best = [fl, loc(i), loc(i)+gap];  break
                    end
                end
                if ~isempty(best), break, end
            end
            if isempty(best)
                error(['未找到相距 %d 的帧头/帧尾 m 序列。可能原因：图片选错、' ...
                       '采集时长不够、信号太弱或过载。'], gap);
            end
            flag = best(1);  l1 = best(2);  l2 = best(3);
            dec  = double(xs(l1+15 : l2-1)*flag <= 0);   % >0 判为码元 0，否则为 1
            ber  = sum(dec ~= info_all) / L;
            bmp  = reshape(dec, NN, MM);                 % 列优先，与组帧时一致
        end

        function showBitmap(ax, bw, ttl)
            imagesc(ax, double(bw) > 0);
            colormap(ax, flipud(gray(2)));       % 1 -> 黑，0 -> 白
            axis(ax,'image');  axis(ax,'off');  title(ax, ttl);
        end

        function items = listImages(d)
            L = dir(fullfile(d,'*.bmp'));
            if isempty(L)
                items = {'(baseband_images 下没有 bmp)'};
            else
                items = {L.name};
            end
        end

        % 默认选最短的 ren128b（约 18s），跑通链路最快；没有就用第一张
        function v = pickDefault(items)
            k = find(strcmpi(items,'ren128b.bmp'), 1);
            if isempty(k), k = 1; end
            v = items{k};
        end
    end
end
