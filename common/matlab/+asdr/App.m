classdef App < handle
%APP  三个实验共用的「一键声学实测」界面骨架与四条流程。
%
%   每个实验的 host/gui.m 只提供一份 spec（见下），界面骨架、板上连接、
%   同步编译、电平校准、启动采集/放音/取回，全部由本类负责。
%
%   spec 必填字段：
%     title      char      窗口标题，如 '实验二 · DPSK —— 一键声学实测'
%     binary     char      板上可执行名，如 'dpsk_rx'
%     outMat     char      板上产出的数据文件名，如 'dpsk5.mat'
%     fs         double    放音采样率
%     prepare    @(app)    -> meta 结构体，至少含 meta.x(待放波形) 与
%                             meta.dur(信号秒数)、meta.desc(日志里描述发什么)
%     analyze    @(app,matfile,meta)  解码/分析并渲染结果面板
%     buildResults @(app,parentGrid)  建结果面板（BER+点阵 / 频谱）
%
%   spec 选填字段：
%     buildParams @(app,grid,lab)  往设置面板插实验特有控件（图片/载波…）
%     showDuration logical         是否显示「信号时长」一行（默认 false）
%     durationText @(app)          该行显示什么（showDuration 为真时必填）
%     auxButton  char              「仅解码…」按钮文字（默认按 outMat 生成）
%     levelAudio @(app)            电平校准放什么（默认取 prepare 波形前 4s）
%     extraRemove cellstr          启动采集前额外删除的板上文件
%
%   spec 回调里用 app.ui 这个结构体存放自己的控件，用 app.track(h) 把需要
%   随忙闲切换 Enable 的控件登记进来。

    properties
        ui struct = struct()        % spec 回调存放自己的控件
    end

    properties (SetAccess = private)
        spec
        here char                   % 实验的 host/ 目录
        fig
    end

    properties (Access = private)
        board
        host, user, pass, rdir
        dev, btnAlsa, odev, lead, tail, amp
        durTxt, capTxt, logBox
        btnCheck, btnSync, btnLevel, btnRun, btnAux, btnStop
        devStrs = {}
        odevIDs = []
        tracked = {}
        rowCount = 0
        cancelled = false
        player = []
        busy = false
    end

    methods
        function app = App(spec, hostDir)
            app.spec = asdr.App.fillDefaults(spec);
            app.here = hostDir;
            app.board = asdr.Board();
            app.board.CancelFcn = @() app.checkCancelled();
            app.build();
        end

        %% ---------------- 给 spec 回调用的接口 ----------------

        function track(app, h)
        %TRACK  登记需要随忙闲切换 Enable 的控件
            if ~iscell(h), h = {h}; end
            app.tracked = [app.tracked, h];
        end

        function refreshTiming(app)
        %REFRESHTIMING  重算「信号时长」「采集窗口」两行。spec 的控件改值时调它。
            try
                if app.spec.showDuration
                    [txt, dur] = app.spec.durationText(app);
                    app.durTxt.Text = txt;
                else
                    dur = app.spec.plainDuration(app);
                end
                app.capTxt.Text = sprintf('-t %d', ceil(app.lead.Value + dur + app.tail.Value));
            catch
                if app.spec.showDuration, app.durTxt.Text = '—'; end
                app.capTxt.Text = '—';
            end
        end

        function logf(app, fmt, varargin)
            msg = sprintf(fmt, varargin{:});
            cur = app.logBox.Value;
            if isscalar(cur) && isempty(strtrim(cur{1})), cur = cell(0,1); end
            app.logBox.Value = [cur; strsplit(msg, newline)'];
            scroll(app.logBox, 'bottom');  drawnow;
        end

        function logStep(app, label, mark, fmt, varargin)
            if nargin < 4 || isempty(fmt)
                app.logf('%s … %s', label, mark);
            else
                app.logf('%s … %s %s', label, mark, sprintf(fmt, varargin{:}));
            end
        end

        % 板上确实跑完了、文件也取回了，但内容是死的——这种情况要把原因说清楚，
        % 否则只会抛一个含糊的"找不到帧头/峰值不对"，排查方向全错。
        function ok = deadStreamOK(app, isDead)
            ok = ~isDead;
            if isDead
                app.logStep('数据检查', '✗', '板上采到的全是 0，麦克风没收到信号');
                app.logf('  常见原因：选中输出设备的音量过低（系统音量只作用于默认输出）、');
                app.logf('  输出设备选错、麦克风没接好。先用「③ 电平校准」看 RMS（见 Q&A Q7/Q4）');
            end
        end
    end

    methods (Access = private)

        %% ---------------- 界面骨架 ----------------

        function build(app)
            s = app.spec;
            app.fig = uifigure('Name', s.title, 'Position', [80 80 1020 660]);
            root = uigridlayout(app.fig, [1 2]);
            root.ColumnWidth = {340, '1x'};

            gL = uigridlayout(uipanel(root, 'Title', '设置与操作'), [30 2]);
            gL.ColumnWidth = {100, '1x'};
            gL.RowSpacing  = 4;   % 默认 10 会把十几个间隙累积成上百 px，末尾按钮被挤出可视区

            lab = @(t) app.addRow(gL, t);

            % 三项都必填。走 MATLAB 自带的 JSch，「IP 地址」填板子的局域网 IP。
            lab('IP 地址');   app.host = uieditfield(gL,'text','Value','', ...
                                  'ValueChangedFcn',@(~,~)app.credentialsChanged());
            lab('用户名');    app.user = uieditfield(gL,'text','Value','', ...
                                  'ValueChangedFcn',@(~,~)app.credentialsChanged());
            lab('密码');      app.pass = uieditfield(gL,'text','Value','', ...
                                  'ValueChangedFcn',@(~,~)app.credentialsChanged());
            lab('板上路径');  app.rdir = uieditfield(gL,'text','Value','','Enable','off', ...
                                  'Placeholder','点「① 自检」后自动填入');
            lab('ALSA 设备');
            gAd = uigridlayout(gL,[1 2]); gAd.ColumnWidth = {'1x',30};
            gAd.RowHeight = {'1x'}; gAd.Padding = [0 0 0 0]; gAd.ColumnSpacing = 4;
            app.dev = uidropdown(gAd,'Items',{'(点「① 自检」后枚举)'},'Enable','off');
            app.btnAlsa = uibutton(gAd,'Text','⟳','Enable','off', ...
                     'Tooltip','重新枚举板上采集设备（换麦克风/重插 USB 后点一下）', ...
                     'ButtonPushedFcn',@(~,~)app.refreshAlsa());

            % 实验特有的参数行（发送图片 / 载波 / 发射时长…）
            s.buildParams(app, gL, lab);

            lab('前导余量 (s)'); app.lead = uieditfield(gL,'numeric','Value',1,'Limits',[0 30], ...
                                     'ValueChangedFcn',@(~,~)app.refreshTiming());
            lab('尾部余量 (s)'); app.tail = uieditfield(gL,'numeric','Value',2,'Limits',[0 60], ...
                                     'ValueChangedFcn',@(~,~)app.refreshTiming());
            lab('播放幅度');     app.amp  = uieditfield(gL,'numeric','Value',0.8,'Limits',[0 1]);
            [odevNames, app.odevIDs] = asdr.App.listOutputs();
            lab('输出设备');
            gOd = uigridlayout(gL,[1 2]); gOd.ColumnWidth = {'1x',30};
            gOd.RowHeight = {'1x'}; gOd.Padding = [0 0 0 0]; gOd.ColumnSpacing = 4;
            app.odev = uidropdown(gOd,'Items',odevNames,'Value',asdr.App.pickSpeaker(odevNames));
            uibutton(gOd,'Text','⟳','Tooltip','重新枚举输出设备（插拔耳机后点一下）', ...
                     'ButtonPushedFcn',@(~,~)app.refreshOutputs());
            if s.showDuration
                lab('信号时长'); app.durTxt = uilabel(gL,'Text','—');
            end
            lab('采集窗口');  app.capTxt = uilabel(gL,'Text','—');

            nLabRows = app.rowCount;
            app.btnCheck = app.addButton(gL,'① 自检（连接 / 枚举声卡）', @(~,~)app.onCheck());
            app.btnSync  = app.addButton(gL,'② 同步源码到板上并编译',   @(~,~)app.onSync());
            app.btnLevel = app.addButton(gL,'③ 电平校准（放测试音测 RMS）', @(~,~)app.onLevel());
            app.btnRun   = app.addButton(gL,'④ 一键声学实测',           @(~,~)app.onRun());
            app.btnAux   = app.addButton(gL, s.auxButton,               @(~,~)app.onAuxOnly());
            app.btnStop  = app.addButton(gL,'中止板上采集',             @(~,~)app.onStop());
            nBtn = 6;
            gL.RowHeight = [repmat({26},1,nLabRows), repmat({32},1,nBtn), {'1x'}];

            gR = uigridlayout(root,[2 1]);  gR.RowHeight = {'1x',180};
            s.buildResults(app, uipanel(gR,'Title','结果'));

            gLog = uigridlayout(uipanel(gR,'Title','日志'),[1 1]);
            gLog.Padding = [5 5 5 5];
            app.logBox = uitextarea(gLog,'Editable','off','Value',cell(0,1),'FontName','Menlo');

            app.fig.CloseRequestFcn = @(~,~) app.closeAll();
            app.refreshTiming();
            app.logf('就绪。顺序：① 自检 → ② 同步并编译 → ③ 电平校准 → ④ 一键实测');
        end

        function h = addRow(app, gL, txt)
            app.rowCount = app.rowCount + 1;
            h = uilabel(gL,'Text',txt,'HorizontalAlignment','right');
        end

        function b = addButton(~, parent, txt, cb)
            b = uibutton(parent,'Text',txt,'ButtonPushedFcn',cb);
            b.Layout.Column = [1 2];
        end

        %% ---------------- 四条流程 ----------------

        function onCheck(app)
            app.setBusy(true);
            % onCleanup 保证按钮一定恢复：try 块里的 return（连不上、枚举失败等
            % 分支都有）是从整个回调返回，会跳过末尾的 setBusy(false)，导致一次
            % 失败之后整个界面永久变灰按不动。
            guard = onCleanup(@() app.setBusy(false));
            try
                app.logf('--- ① 自检 ---');
                % 先清空再重新探测：自检有好几条提前 return 的分支，若不清空，
                % 上一次成功时填的路径会继续显示，而它可能早已不成立了。自检的
                % 语义应当是"显示的一切都是刚刚验证过的"。
                app.rdir.Value = '';  app.rdir.Enable = 'off';
                app.clearCapture();
                tgt = app.board.target();
                % hostname 不是 POSIX 命令，Arch、精简 Debian、多数容器镜像都不装它
                % （远端 shell 会报 command not found，退出码 127，于是连接本来好好的
                % 却被判成失败）。uname -n 才是 POSIX 定义的取主机名方式；末尾 echo
                % 兜底让这条命令必定成功——主机名只用于显示，取不到不该阻断自检。
                [st, out] = app.ssh('uname -n 2>/dev/null || cat /etc/hostname 2>/dev/null || echo unknown');
                if st ~= 0
                    app.logStep(sprintf('连接 %s', tgt), '✗', '%s', asdr.firstLine(out));
                    return
                end
                hn = asdr.firstLine(out);
                if isempty(hn) || strcmp(hn,'unknown'), hn = '(未知)'; end
                app.logStep(sprintf('连接 %s', tgt), '✓', '%s', hn);

                if ~app.refreshAlsa(), return, end

                % 「板上路径」显示的必须是**板上确实存在**的目录，不能是本地推算
                % 出来的预期值——否则板子上被 rm -rf 之后重开界面，日志说"还没
                % 同步"、输入框却显示着路径，自相矛盾。所以先探再填，探不到就清空。
                guess = sprintf('~/portable-acoustic-sdr/%s', app.expName());
                [st, ~] = app.ssh(sprintf('test -d %s', guess));
                if st ~= 0
                    app.rdir.Value = '';  app.rdir.Enable = 'off';
                    app.logStep('板上源码', '△', '板上没有，请点「② 同步源码到板上并编译」');
                    return
                end
                app.rdir.Value = guess;  app.rdir.Enable = 'on';
                app.logStep('板上源码', '✓', '%s', guess);

                if app.binaryExists()
                    app.logStep('板上可执行', '✓', '已就绪');
                else
                    app.logStep('板上可执行', '△', '未编译，请点「② 同步源码到板上并编译」');
                end
            catch e
                app.logStep('自检', '✗', '%s', asdr.firstLine(e.message));
            end
        end

        function onSync(app)
            app.setBusy(true);
            guard = onCleanup(@() app.setBusy(false));
            try
                app.logf('--- ② 同步源码到板上并编译 ---');
                if ~app.ensureConn(), return, end
                if ~app.deployFiles(), return, end
                % make clean 不能省：PC 与板子时钟可能有偏差，新 .c 的时间戳不一定
                % 比旧 .o 新，make 会误判"已是最新"而不重编，跑的还是旧逻辑
                app.logStep('编译', '▶', '板上 gcc，稍候');
                [buildStatus, out] = app.ssh(sprintf('cd %s && make clean && make', app.remoteDir()));
                if buildStatus == 0 && app.binaryExists()
                    app.logStep('编译', '✓', '已生成 build/%s', app.spec.binary);
                    return
                end
                app.logStep('编译', '✗', '编译失败（退出码 %d）', buildStatus);
                if contains(out,'asoundlib.h') || contains(out,'-lasound')
                    app.logf('  板上缺 ALSA 开发库（见 Q&A Q8）');
                end
                tail_ = strsplit(strtrim(out), newline);
                for i = max(1, numel(tail_)-4):numel(tail_)
                    app.logf('  %s', strtrim(tail_{i}));
                end
            catch e
                app.logStep('同步并编译', '✗', '%s', asdr.firstLine(e.message));
            end
        end

        function onLevel(app)
            app.setBusy(true);
            guard = onCleanup(@() app.setBusy(false));
            try
                app.logf('--- ③ 电平校准 ---');
                if ~app.ensureConn(), return, end
                if isempty(app.alsaDev()), app.logf('先点「① 自检」枚举采集设备。'); return, end
                wav = ['/tmp/pasdr_level_' char(java.util.UUID.randomUUID()) '.wav'];
                app.board.startJob(sprintf('arecord -D %s -f S16_LE -r 8000 -c 1 -d 6 %s', ...
                                   asdr.shellQuote(app.alsaDev()), asdr.shellQuote(wav)));
                pause(1);  app.checkCancelled();

                app.playAudio(app.spec.levelAudio(app) * app.amp.Value);
                app.logStep('板上录音 6s / 本机放音 4s', '✓', '');
                if ~app.waitRemoteDone(12), return, end

                local = fullfile(tempdir,'pasdr_level.wav');
                [st, out] = app.board.get(wav, local);
                if st ~= 0, app.logStep('取回录音', '✗', '%s', asdr.firstLine(out)); return, end

                y = audioread(local);
                pk = max(abs(y))*32768;  rms_ = sqrt(mean(y.^2))*32768;
                lv = sprintf('RMS=%.0f 峰值=%.0f', rms_, pk);
                if pk < 300
                    app.logStep('电平', '✗', '%s 太弱，麦克风没接好或音量太低（见 Q&A Q4）', lv);
                elseif pk < 1500
                    app.logStep('电平', '△', '%s 偏低，调高本机音量或板上采集增益', lv);
                elseif pk > 20000
                    app.logStep('电平', '△', '%s 偏高，有过载风险（见 Q&A Q5）', lv);
                else
                    app.logStep('电平', '✓', '%s 合适', lv);
                end
            catch e
                app.logStep('电平校准', '✗', '%s', asdr.firstLine(e.message));
            end
        end

        function onRun(app)
            app.setBusy(true);
            guard = onCleanup(@() app.setBusy(false));
            try
                meta = app.spec.prepare(app);
                tcap = ceil(app.lead.Value + meta.dur + app.tail.Value);

                app.logf('--- ④ 一键实测 ---');
                if ~app.ensureConn() || ~app.ready(), return, end
                app.logf('%s  信号 %.1fs  采集窗口 %ds', meta.desc, meta.dur, tcap);

                % 1) 板上启动采集（后台），旧数据先删掉避免看到上一次的结果
                rm = strjoin([{app.spec.outMat}, app.spec.extraRemove], ' ');
                app.board.startJob(sprintf('cd %s && rm -f %s && ./build/%s -d %s -t %d', ...
                              app.remoteDir(), rm, app.spec.binary, ...
                              asdr.shellQuote(app.alsaDev()), tcap));
                app.logStep('板上采集', '✓', '已启动');
                pause(app.lead.Value);  app.checkCancelled();

                % 2) 本机放音（阻塞，确保放完再往下走）
                app.logStep('本机放音', '▶', '%.1fs', meta.dur);
                app.playAudio(meta.x * app.amp.Value);
                app.logStep('本机放音', '✓', '结束，等板上采集窗口跑完');

                % 3) 等板上进程退出
                if ~app.waitRemoteDone(tcap + 10), return, end

                % 4) 取回
                localMat = fullfile(app.here, app.spec.outMat);
                [st, out] = app.board.get(sprintf('%s/%s', app.rdir.Value, app.spec.outMat), localMat);
                if st ~= 0
                    app.logStep('取回数据', '✗', '%s', asdr.firstLine(out));
                    app.logf('  板上可能没产出 %s（采集设备打不开？见 Q&A Q1/Q2）', app.spec.outMat);
                    return
                end
                app.logStep('取回数据', '✓', '%s', app.spec.outMat);

                % 5) 解码/分析
                app.spec.analyze(app, localMat, meta);
            catch e
                app.logStep('一键实测', '✗', '%s', asdr.firstLine(e.message));
            end
        end

        function onAuxOnly(app)
            app.setBusy(true);
            guard = onCleanup(@() app.setBusy(false));
            try
                meta = app.spec.prepare(app);
                app.spec.analyze(app, fullfile(app.here, app.spec.outMat), meta);
            catch e
                app.logStep('解码', '✗', '%s', asdr.firstLine(e.message));
            end
        end

        function onStop(app)
            app.cancelled = true;
            if ~isempty(app.player), stop(app.player); end
            if isempty(app.board.Job)
                app.logf('没有本界面启动的采集任务。'); return
            end
            app.stopJob();
            app.logf('已请求中止本次采集，本地流程也已取消。');
        end

        %% ---------------- 板上交互 ----------------

        function [st, out] = ssh(app, cmd)
            app.board.setCredentials(app.host.Value, app.user.Value, app.pass.Value);
            [st, out] = app.board.exec(cmd);
        end

        function ok = ensureConn(app)
            app.board.setCredentials(app.host.Value, app.user.Value, app.pass.Value);
            [ok, msg] = app.board.probe();
            if ~ok
                app.logStep(sprintf('连接 %s', app.board.target()), '✗', '%s', msg);
                app.logf('  已中止。先用「① 自检」确认 IP/用户名/密码');
            end
        end

        function tf = binaryExists(app)
            [st, ~] = app.ssh(sprintf('test -x %s/build/%s', app.remoteDir(), app.spec.binary));
            tf = (st == 0);
        end

        % 自检之前，板上路径和采集设备都是空的，直接跑必然失败——提前说清楚
        function ok = ready(app)
            ok = false;
            if isempty(app.alsaDev())
                app.logStep('前置检查', '✗', '还没自检，先点「① 自检」');  return
            end
            if isempty(strtrim(app.rdir.Value))
                app.logStep('前置检查', '✗', '板上没有源码，先点「② 同步源码到板上并编译」');
                return
            end
            ok = app.binaryExists();
            if ~ok
                app.logStep('前置检查', '✗', '板上没有可执行，先点「② 同步源码到板上并编译」');
            end
        end

        function ok = waitRemoteDone(app, timeoutSec)
            t0 = tic;  ok = false;
            while toc(t0) < timeoutSec
                app.checkCancelled();
                [done, ok] = app.jobStatus();
                if done, return, end
                pause(0.2);
            end
            app.stopJob();
            app.logStep('等待采集', '✗', '超时，已中止本次任务，不读取未完成数据');
        end

        function [done, ok] = jobStatus(app)
            app.board.setCredentials(app.host.Value, app.user.Value, app.pass.Value);
            [done, ok, code, detail] = app.board.jobStatus();
            if done && ~ok
                app.logStep('板上采集', '✗', '退出码 %s：%s', code, detail);
            end
        end

        function stopJob(app)
            [st, out] = app.board.stopJob();
            if st ~= 0, app.logStep('中止采集', '✗', '%s', out); end
        end

        % ---- 把板上编译需要的源码送过去 ----
        % 用 MATLAB 自带的 tar 打包，不依赖宿主机有 find/tar（教程第 2 节那条管线
        % 在 Windows 上要 Git Bash 才有）。只挑 Makefile/.c/.h，与教程口径一致：
        % .slx、基带图片不上板；slprj 中编译需要的 _sharedutils 源码也要上传。
        function ok = deployFiles(app)
            ok = false;
            [repoRoot, expName] = fileparts(fileparts(app.here));
            pats = { fullfile('common','include','*.h'), ...
                     fullfile('common','src','*.c'), ...
                     fullfile(expName,'Makefile'), ...
                     fullfile(expName,'include','*.h'), ...
                     fullfile(expName,'src','*.c'), ...
                     fullfile(expName,'simulink_model','*_ert_rtw','*.c'), ...
                     fullfile(expName,'simulink_model','*_ert_rtw','*.h'), ...
                     fullfile(expName,'simulink_model','slprj','ert','_sharedutils','*.c'), ...
                     fullfile(expName,'simulink_model','slprj','ert','_sharedutils','*.h') };
            rel = {};
            for i = 1:numel(pats)
                L = dir(fullfile(repoRoot, pats{i}));
                for k = 1:numel(L)
                    if L(k).isdir, continue, end
                    r = L(k).folder(numel(repoRoot)+2:end);     % 去掉 repoRoot 前缀
                    rel{end+1} = strrep(fullfile(r, L(k).name), '\', '/'); %#ok<AGROW>
                end
            end
            if isempty(rel)
                app.logStep('同步源码', '✗', '本地没找到 Makefile/.c/.h');
                return
            end

            tgz = [tempname '.tgz'];
            tarCleanup = onCleanup(@() asdr.App.deleteIfPresent(tgz));
            if isfile(tgz), delete(tgz); end
            tar(tgz, rel, repoRoot);

            remoteRoot = '~/portable-acoustic-sdr';
            remoteTar  = ['/tmp/pasdr_deploy_' char(java.util.UUID.randomUUID()) '.tgz'];
            [st, out] = app.board.put(tgz, remoteTar);
            if st ~= 0, app.logStep('同步源码', '✗', '上传失败：%s', asdr.firstLine(out)); return, end
            % 先删掉板上旧的生成代码目录：tar 解包只覆盖/新增、不删除，若这次重新
            % 生成让某个 .c 改了名或消失，残留的"孤儿 .c"会被 Makefile 的 *.c 通配
            % 编进去而报错（教程 6.1 提醒过的坑）。手写源码目录不会有这问题，不动。
            %
            % --exclude='._*'：macOS 的扩展属性会被 MATLAB 的 tar 打成 AppleDouble
            % 条目，解包后变成一堆 ._xxx.c 垃圾文件。它们不会被编进去（GNU make 的
            % wildcard 用 glob，* 不匹配点开头的文件），但没必要留在板上。
            [st, out] = app.ssh(sprintf(['tar tzf %s >/dev/null && mkdir -p %s && ' ...
                                    'rm -rf %s/%s/simulink_model && tar xzf %s -C %s ' ...
                                    '--exclude=''._*'' && rm -f %s'], ...
                                   asdr.shellQuote(remoteTar), remoteRoot, remoteRoot, expName, ...
                                   asdr.shellQuote(remoteTar), remoteRoot, asdr.shellQuote(remoteTar)));
            if st ~= 0, app.logStep('同步源码', '✗', '板上解包失败：%s', asdr.firstLine(out)); return, end

            app.rdir.Value  = sprintf('%s/%s', remoteRoot, expName);
            app.rdir.Enable = 'on';
            app.logStep('同步源码', '✓', '%d 个文件 -> %s', numel(rel), app.rdir.Value);
            ok = true;
        end

        function n = expName(app)
            [~, n] = fileparts(fileparts(app.here));
        end

        function q = remoteDir(app)
            p = strtrim(app.rdir.Value);
            if startsWith(p, '~/')
                q = ['$HOME/' asdr.shellQuote(p(3:end))];
            else
                q = asdr.shellQuote(p);
            end
        end

        %% ---------------- 采集设备 / 输出设备 ----------------

        % ---- 板上采集设备：连过去跑 arecord -l 现场枚举 ----
        function ok = refreshAlsa(app)
            ok = false;
            if ~app.ensureConn(), app.clearCapture(); return, end
            [st, out] = app.ssh('LC_ALL=C arecord -l');
            if st ~= 0
                app.clearCapture();
                app.logStep('枚举采集设备', '✗', '%s', asdr.firstLine(out)); return
            end
            [nm, ds] = asdr.App.parseArecord(out);
            if isempty(ds)
                app.dev.Items = {'(板上没有采集设备)'};  app.dev.Enable = 'off';  app.devStrs = {};
                app.logStep('枚举采集设备', '✗', '板上一个都没有，麦克风没插好？（见 Q&A Q4）');
                return
            end
            keep = app.alsaDev();                   % 尽量保住用户已选的那个
            app.devStrs = ds;  app.dev.Items = nm;
            app.dev.Enable = 'on';  app.btnAlsa.Enable = 'on';
            k = find(strcmp(ds, keep), 1);
            if isempty(k), k = asdr.App.pickCapture(nm); end
            app.dev.Value   = nm{k};
            app.dev.Tooltip = strjoin(nm, newline);   % 下拉收起时名字会截断
            app.logStep('枚举采集设备', '✓', '%d 个，选用 %s', numel(nm), nm{k});
            ok = true;
        end

        % 下拉里显示的是带描述的长名字，真正要传给 -d/-D 的是 plughw:X,Y
        function d = alsaDev(app)
            d = '';
            if isempty(app.devStrs), return, end
            k = find(strcmp(app.dev.Items, app.dev.Value), 1);
            if ~isempty(k) && k <= numel(app.devStrs), d = app.devStrs{k}; end
        end

        function clearCapture(app)
            app.devStrs = {};
            app.dev.Items = {'(点「① 自检」后枚举)'};
            app.dev.Enable = 'off';  app.btnAlsa.Enable = 'off';
        end

        function credentialsChanged(app)
            app.board.disconnect();
            app.clearCapture();
            app.rdir.Value = '';  app.rdir.Enable = 'off';
        end

        function refreshOutputs(app)
            if app.busy, return, end
            cur = app.odev.Value;
            [nm, app.odevIDs] = asdr.App.listOutputs();
            app.odev.Items = nm;
            if any(strcmp(nm, cur)), app.odev.Value = cur;
            else,                    app.odev.Value = asdr.App.pickSpeaker(nm); end
            app.logf('输出设备已刷新，共 %d 个：%s', numel(nm), strjoin(nm, ' | '));
        end

        %% ---------------- 放音 ----------------

        % 显式指定输出设备，不依赖系统默认输出——否则接了蓝牙耳机时声音会跑到
        % 耳机里，板上麦克风一无所获（判决流全 0）。这是实测踩过的坑。
        function p = mkPlayer(app, y)
            k = find(strcmp(app.odev.Items, app.odev.Value), 1);
            if isempty(k) || isempty(app.odevIDs)
                p = audioplayer(y, app.spec.fs);
            else
                try
                    p = audioplayer(y, app.spec.fs, 16, app.odevIDs(k));
                catch
                    % 枚举之后把耳机拔了/断了，device ID 已失效。这里不能悄悄退回
                    % 系统默认输出——那正是"声音跑进耳机、板上采到全 0"的成因。
                    error(['输出设备「%s」已不可用（拔掉了？）。' ...
                           '点「输出设备」旁的 ⟳ 重新枚举后再试。'], app.odev.Value);
                end
            end
            if ~isempty(regexpi(app.odev.Value,'airpod|headphone|headset|bluetooth|耳机','once'))
                app.logStep('输出设备', '△', '像是耳机，声音不会经空气传到板上麦克风');
            end
        end

        function playAudio(app, y)
            app.checkCancelled();
            app.player = app.mkPlayer(y);
            play(app.player);
            while isplaying(app.player)
                pause(0.05);  app.checkCancelled();
            end
            app.checkCancelled();
        end

        %% ---------------- 忙闲态与收尾 ----------------

        function checkCancelled(app)
            if app.cancelled || ~isvalid(app.fig), error('本次操作已取消。'); end
        end

        function setBusy(app, tf)
            if ~isvalid(app.fig), return, end
            if tf
                app.cancelled = false;
            elseif ~isempty(app.board.Job)
                app.stopJob();
                app.board.clearJob();
            end
            app.busy = tf;
            s = {'on','off'};  s = s{1+tf};
            app.btnCheck.Enable = s;  app.btnSync.Enable = s;
            app.btnLevel.Enable = s;  app.btnRun.Enable  = s;
            app.btnAux.Enable   = s;
            app.host.Enable = s;  app.user.Enable = s;  app.pass.Enable = s;
            app.lead.Enable = s;  app.tail.Enable = s;  app.amp.Enable  = s;
            app.odev.Enable = s;
            for i = 1:numel(app.tracked)
                if isvalid(app.tracked{i}), app.tracked{i}.Enable = s; end
            end
            if ~isempty(app.rdir.Value), app.rdir.Enable = s; end
            if ~isempty(app.devStrs), app.dev.Enable = s; app.btnAlsa.Enable = s; end
            drawnow;
        end

        function closeAll(app)
            if app.busy
                app.onStop();
                app.logf('请等待本次操作结束后再关闭窗口。'); return
            end
            app.board.disconnect();
            delete(app.fig);
        end
    end

    methods (Static, Access = private)

        function s = fillDefaults(s)
            if ~isfield(s,'buildParams') || isempty(s.buildParams)
                s.buildParams = @(varargin) [];
            end
            if ~isfield(s,'showDuration'), s.showDuration = false; end
            if ~isfield(s,'plainDuration') || isempty(s.plainDuration)
                s.plainDuration = @(app) 0;
            end
            if ~isfield(s,'auxButton') || isempty(s.auxButton)
                s.auxButton = sprintf('仅解码已取回的 %s', s.outMat);
            end
            if ~isfield(s,'extraRemove'), s.extraRemove = {}; end
            if ~isfield(s,'levelAudio') || isempty(s.levelAudio)
                % 默认：拿正式波形的前 4 秒当测试音
                s.levelAudio = @(app) asdr.App.firstSeconds(s.prepare(app).x, s.fs, 4);
            end
        end

        function y = firstSeconds(x, fs, sec)
            y = x(1:min(numel(x), round(sec*fs)));
        end

        % arecord -l 形如：
        %   card 2: K10 [KSS K10], device 0: USB Audio [USB Audio]
        % 解析成设备串 plughw:2,0 和带详细名称的显示串
        function [names, devs] = parseArecord(txt)
            names = {};  devs = {};
            lines = strsplit(txt, newline);
            for i = 1:numel(lines)
                tok = regexp(strtrim(lines{i}), ...
                    '^card\s+(\d+):\s*\S+\s*\[([^\]]*)\].*?device\s+(\d+):\s*(.*?)\s*\[', ...
                    'tokens', 'once');
                if numel(tok) == 4
                    devs{end+1}  = sprintf('plughw:%s,%s', tok{1}, tok{3}); %#ok<AGROW>
                    names{end+1} = sprintf('plughw:%s,%s — %s (%s)', ...
                                           tok{1}, tok{3}, strtrim(tok{2}), strtrim(tok{4})); %#ok<AGROW>
                end
            end
        end

        % 板上常同时有 HDMI 等无关采集口，USB 声卡才是麦克风，优先选它
        function k = pickCapture(names)
            k = find(~cellfun(@isempty, regexpi(names,'usb','once')), 1);
            if isempty(k), k = 1; end
        end

        function [names, ids] = listOutputs()
            names = {};  ids = [];
            try
                d = audiodevinfo;
                for i = 1:numel(d.output)
                    names{end+1} = d.output(i).Name; %#ok<AGROW>
                    ids(end+1)   = d.output(i).ID;   %#ok<AGROW>
                end
            catch
            end
            if isempty(names), names = {'(系统默认)'};  ids = []; end
        end

        % 优先选内置扬声器：接了蓝牙耳机时默认输出会被抢走，而本实验必须走扬声器
        function v = pickSpeaker(names)
            k = find(~cellfun(@isempty, regexpi(names,'speaker|扬声器|built-?in|internal','once')), 1);
            if isempty(k), k = 1; end
            v = names{k};
        end

        function deleteIfPresent(p)
            if isfile(p), delete(p); end
        end
    end
end
