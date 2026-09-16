classdef Board < handle
%BOARD  开发板连接：JSch 会话复用 + 命令执行 + SFTP 传输 + 后台任务管理。
%
%   三个实验的 gui.m 共用本类，界面层只管显示，连不连得上、怎么传、
%   后台任务活没活着都在这里。
%
%   传输层全部走 MATLAB 自带的 JSch，不调用系统的 ssh/scp/sshpass。
%   JSch 来自 matlabroot/java/jarext/jsch.jar，属于 MATLAB **基础安装**
%   （一个支持包都不装也能用），所以 Windows/macOS/Linux 行为完全一致，
%   填 IP+用户名+密码即可一键部署。
%
%   两点代价，已知并接受：
%     1. 不读 ~/.ssh/config，「IP 地址」栏直接填板子的局域网 IP；
%     2. MATLAB 带的是 JSch 0.1.x，**不支持 ed25519 私钥**（实测 addIdentity
%        直接报 invalid privatekey），所以这里只做密码认证。

    properties (SetAccess = private)
        Host char = ''
        User char = ''
        Pass char = ''
        Job  char = ''          % 当前后台任务的远端目录，空表示没有
    end

    properties
        % 界面层注入：被用户中止时抛错，用来打断放音/等待这类长流程。
        CancelFcn = @() []
    end

    properties (Access = private)
        ses = []                % 复用的 JSch 会话
        key char = ''           % 会话对应的凭据指纹，变了就重连
    end

    methods
        function setCredentials(o, host, user, pass)
            h = strtrim(host);  u = strtrim(user);
            if ~strcmp(h, o.Host) || ~strcmp(u, o.User) || ~strcmp(pass, o.Pass)
                o.disconnect();
            end
            o.Host = h;  o.User = u;  o.Pass = pass;
        end

        function t = target(o)
            if isempty(o.Host),     t = '(未填 IP)';
            elseif isempty(o.User), t = o.Host;
            else,                   t = [o.User '@' o.Host];
            end
        end

        % 用字节流保存完整输出；轮询通道结束，避免 readLine 阻塞 UI。
        %
        % 命令一律套一层 sh -c：JSch 的 exec 通道是拿**用户的登录 shell**跑命令的，
        % 而登录 shell 因人而异（实测树莓派是 bash、Arch 主机是 zsh）。zsh 默认开
        % nomatch——通配符匹配不到文件时整条命令直接报错中止，bash/dash 则是把
        % 字面量原样传下去。不固定成 sh，同一条命令在两台板子上行为就会不一样。
        function [st, out] = exec(o, cmd)
            st = 255;
            try
                s  = o.session();
                ch = s.openChannel('exec');
                closer = onCleanup(@() ch.disconnect());
                ch.setCommand(sprintf('sh -c %s 2>&1', asdr.shellQuote(cmd)));
                bytes = java.io.ByteArrayOutputStream();
                ch.setOutputStream(bytes);
                ch.connect(10000);
                deadline = tic;
                while ~ch.isClosed()
                    if toc(deadline) > 180
                        error('远端命令超过 180 秒未结束。');
                    end
                    pause(0.02);
                end
                st  = double(ch.getExitStatus());
                out = char(bytes.toString('UTF-8'));
            catch e
                out = o.translate(e);
            end
        end

        % 开跑前先探一次连通。否则 IP/密码填错时，会白放完整段音频、再慢慢
        % 等满超时才失败——用户等一分钟才知道是 IP 打错了。
        function [ok, msg] = probe(o)
            [st, out] = o.exec('true');
            ok = (st == 0);
            msg = asdr.firstLine(out);
        end

        % 每次任务独立目录，保存真实退出码/日志，并只中止自己的进程组。
        function startJob(o, cmd)
            o.CancelFcn();
            [st, out] = o.exec('mktemp -d /tmp/pasdr_job.XXXXXXXX');
            if st ~= 0, error('%s', out); end
            o.Job = strtrim(out);
            q = asdr.shellQuote(o.Job);
            body = sprintf('echo $$ > %s/pid; ( %s ); rc=$?; echo "$rc" > %s/status', q, cmd, q);
            [st, out] = o.exec(sprintf('nohup setsid sh -c %s >%s/log 2>&1 </dev/null & launcher=$!', ...
                                       asdr.shellQuote(body), q));
            if st ~= 0, error('后台启动失败：%s', out); end
            % 等到远端包装进程确实启动，不能只等固定 0.2s 就声称成功。
            [st, out] = o.exec(sprintf(['i=0; while [ ! -s %s/pid ] && [ "$i" -lt 50 ]; ' ...
                'do sleep 0.1; i=$((i+1)); done; test -s %s/pid'], q, q));
            if st ~= 0, error('后台进程未启动：%s', out); end
            pause(0.2);  o.CancelFcn();
        end

        % done=进程已结束  ok=退出码为 0  code/detail 仅在失败时有意义
        function [done, ok, code, detail] = jobStatus(o)
            code = '';  detail = '';
            if isempty(o.Job), done = true;  ok = true;  return, end
            q = asdr.shellQuote(o.Job);
            [st, out] = o.exec(sprintf('if test -f %s/status; then cat %s/status; else echo RUN; fi', q, q));
            if st ~= 0, error('查询采集状态失败：%s', out); end
            code = strtrim(out);
            done = ~strcmp(code, 'RUN');
            ok   = done && strcmp(code, '0');
            if done && ~ok
                [~, detail] = o.exec(sprintf('tail -n 8 %s/log', q));
                detail = strtrim(detail);
            end
        end

        function [st, out] = stopJob(o)
            st = 0;  out = '';
            if isempty(o.Job), return, end
            q = asdr.shellQuote(o.Job);
            [st, out] = o.exec(sprintf(['if test -s %s/pid && ! test -f %s/status; then ' ...
                'pid=$(cat %s/pid); case "$pid" in ""|*[!0-9]*) exit 1;; esac; ' ...
                '/bin/kill -TERM -- -"$pid"; fi'], q, q, q));
            out = asdr.firstLine(out);
        end

        function clearJob(o)
            o.Job = '';
        end

        function [st, out] = put(o, localPath, remotePath)
            st = 0;  out = '';
            try
                s  = o.session();
                sf = s.openChannel('sftp');
                closer = onCleanup(@() sf.disconnect());
                sf.connect(10000);
                sf.put(localPath, asdr.Board.sftpPath(remotePath));
            catch e
                st = 1;  out = o.translate(e);
            end
        end

        function [st, out] = get(o, remotePath, localPath)
            st = 0;  out = '';
            try
                s  = o.session();
                sf = s.openChannel('sftp');
                closer = onCleanup(@() sf.disconnect());
                sf.connect(10000);
                % 先落临时文件再改名：中途失败不会留下一个长度不对的半截 .mat，
                % 否则下次「仅解码」会拿它当完整数据去解。
                partial = [tempname(fileparts(localPath)) '.part'];
                cleanup = onCleanup(@() asdr.Board.deleteIfPresent(partial));
                sf.get(asdr.Board.sftpPath(remotePath), partial);
                [ok, msg] = movefile(partial, localPath, 'f');
                if ~ok, error('%s', msg); end
            catch e
                st = 1;  out = o.translate(e);
            end
        end

        function disconnect(o)
            try
                if ~isempty(o.ses) && o.ses.isConnected(), o.ses.disconnect(); end
            catch
            end
            o.ses = [];  o.key = '';
        end
    end

    methods (Access = private)
        % 复用同一条会话：自检/轮询会发很多条短命令，每条都新建 TCP+认证太慢
        % （等待板上进程时是 0.2s 一次）。凭据变了就重建。
        function s = session(o)
            if isempty(o.Host) || isempty(o.User) || isempty(o.Pass)
                error('请先填写「IP 地址」「用户名」「密码」三项。');
            end
            k = sprintf('%s|%s', o.target(), o.Pass);
            if ~isempty(o.ses) && strcmp(o.key, k) && o.ses.isConnected()
                s = o.ses;  return
            end
            o.disconnect();
            j   = javaObject('com.jcraft.jsch.JSch');
            cfg = java.util.Properties();
            cfg.put('StrictHostKeyChecking','no');   % 实验环境沿用不校验主机密钥的策略（并非 accept-new）
            s = j.getSession(o.User, o.Host, 22);
            s.setPassword(o.Pass);
            s.setConfig(cfg);
            s.setTimeout(60000);      % 板上 make 期间输出有间隔，别让读超时打断
            try
                s.connect(10000);
            catch e
                s.disconnect();
                rethrow(e);
            end
            o.ses = s;  o.key = k;
        end

        % Java 异常带一大段栈，日志里只要人看得懂的那句
        function s = translate(~, e)
            s = asdr.firstLine(regexprep(e.message, '^Java exception occurred:\s*', ''));
            s = strtrim(regexprep(s, '^com\.jcraft\.jsch\.\w+:\s*', ''));
            m = e.message;
            if strcmpi(s, 'Auth fail') || strcmpi(s, 'Auth cancel')
                s = '认证失败——用户名或密码不对';
            elseif contains(m, 'UnknownHostException')
                s = 'IP 地址不合法——请填板子的局域网 IP';
            elseif contains(lower(m), 'connection refused')
                % 这条要排在通用的 ConnectException 前面：地址是通的，只是没人听 22 端口
                s = '连接被拒——地址通了但 22 端口没响应，板子上 sshd 开着吗？';
            elseif contains(m, 'NoRouteToHostException') || contains(lower(m), 'no route to host') ...
                    || contains(lower(m), 'host is down') || contains(m, 'ConnectException') ...
                    || contains(m, 'SocketException') || contains(m, 'SocketTimeoutException') ...
                    || contains(lower(m), 'timed out') || contains(lower(m), 'timeout')
                % 以上都是"TCP 层就没连上"，对用户是同一件事，合并处理
                s = ['连不上板子（还没走到密码认证这一步）' asdr.Board.netHint()];
            end
            if isempty(s), s = asdr.firstLine(e.message); end
        end
    end

    methods (Static, Access = private)
        % SFTP 的初始目录就是家目录，但它不展开 ~，去掉前缀用相对路径即可
        function p = sftpPath(p)
            if startsWith(p, '~/'), p = p(3:end); end
        end

        function deleteIfPresent(p)
            if isfile(p), delete(p); end
        end

        % macOS 的「本地网络」隐私限制只挡局域网、不挡公网，且授权按**责任进程**
        % 归属：从 Finder/Dock 启动时责任进程就是 MATLAB 自己，从终端启动时是终端，
        % 这正是"终端启动能连、点图标启动连不上"的原因。环境变量 __CFBundleIdentifier
        % 记的就是这个责任进程，可直接用来判断当前 MATLAB 是怎么起来的。
        % 实测依据：点图标启动的 MATLAB 里，局域网 TCP 失败而 webread 公网正常。
        function s = netHint()
            if ~ismac
                s = '——检查板子地址、本机路由和防火墙';  return
            end
            if strcmp(getenv('__CFBundleIdentifier'), 'com.mathworks.matlab')
                s = ['——这个 MATLAB 是从 Finder/Dock 启动的，几乎可以确定是 macOS' ...
                     '「本地网络」隐私限制：它只挡局域网、不挡公网。最省事的绕法是' ...
                     '在终端执行 matlab -desktop 启动 MATLAB（授权按责任进程归属，' ...
                     '终端启动即可继承）。'];
            else
                s = '——检查板子地址是否填对、板子与本机是否同网段';
            end
        end
    end
end
