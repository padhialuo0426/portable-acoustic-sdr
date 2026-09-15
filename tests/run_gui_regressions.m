function run_gui_regressions()
% Run with MATLAB -batch "addpath('tests'); run_gui_regressions".
% Optional real SSH checks: PASDR_TEST_HOST / USER / PASS environment variables.
% Instrument temporary copies to exercise actual nested functions without
% adding test-only entry points or credentials to the shipped GUIs.
    root = fileparts(fileparts(mfilename('fullpath')));
    work = tempname; mkdir(work); addpath(work);
    cleanup = onCleanup(@() cleanupWork(work));
    folders = {'exp1_single_freq','exp2_chirp'};
    for idx = 1:2
        here = fullfile(root,folders{idx},'host');
        src = fileread(fullfile(here,'gui.m'));
        name = sprintf('gui_test_%d',idx);
        src = strrep(src,'function gui()', ['function api = ' name '()']);
        src = strrep(src,"fileparts(mfilename('fullpath'))", ['''' strrep(here,'''','''''') '''']);
        remoteRoot = ['/tmp/pasdr_regression_' char(java.util.UUID.randomUUID())];
        src = strrep(src, '''~/portable-acoustic-sdr''', ['''' remoteRoot '''']);
        exports = ['api.state = @testState; api.exec = @jexec; api.start = @jexecDetached; ' ...
            'api.wait = @waitRemoteDone; api.stop = @onStop; api.busy = @setBusy; ' ...
            'api.put = @jput; api.get = @jget; api.dir = @remoteDir; api.sync = @onSync; ' ...
            'api.err = @jerr; api.credentialsChanged = @credentialsChanged;' newline];
        if idx == 1
            exports = [exports 'api.analyze = @doAnalyze;' newline];
        end
        if idx == 2
            exports = [exports 'api.wave = @buildWaveform; api.decode = @decodeStream;' newline];
        end
        marker = '    %% ------------------------- 回调';
        src = strrep(src, marker, [exports marker]);
        marker = '    function logf(fmt, varargin)';
        src = strrep(src, marker, ['    function state = testState()' newline ...
            '        state = A;' newline '    end' newline marker]);
        fid = fopen(fullfile(work,[name '.m']),'w'); fwrite(fid,src); fclose(fid);
        issues = checkcode(fullfile(here,'gui.m'),'-id');
        assert(isempty(issues), 'checkcode must pass');
        api = feval(name); a = api.state(); fig = ancestor(a.host,'figure');
        closeGuard = onCleanup(@() delete(fig));
        cb = a.btnCheck.ButtonPushedFcn; cb([],[]);
        assert(strcmp(a.btnCheck.Enable,'on'), 'Failed check must restore buttons');
        assert(isempty(a.rdir.Value));
        err = api.err(MException('test:route','java.net.NoRouteToHostException: No route to host'));
        assert(contains(err,'密码认证'));
        if ismac, assert(contains(err,'桌面启动进程')); end
        err = api.err(MException('test:route','java.net.ConnectException: No route to host (connect failed)'));
        assert(contains(err,'密码认证'));
        if idx == 1
            toFileData = sin(2*pi*100*(0:800)/801);
            sample = fullfile(work,'odd_fft.mat'); save(sample,'toFileData');
            api.analyze(sample);
            assert(contains(a.pkTxt.Text,'998.8 Hz'));
        end
        if idx == 2
            [x,bits,code,n,m] = api.wave();
            assert(numel(x) == code*800 && numel(bits) == n*m);
            seq = 1-2*a.mseq;
            xs = [zeros(1,7) seq 1-2*bits seq zeros(1,5)];
            for polarity = [1 -1]
                [ber,bmp,l1,l2,fl] = api.decode(polarity*xs,bits,n,m);
                assert(ber == 0 && isequal(bmp,reshape(bits,n,m)));
                assert(l2-l1 == numel(bits)+15 && fl == polarity);
            end
        end
        host = getenv('PASDR_TEST_HOST');
        if ~isempty(host)
            a.host.Value = host; a.user.Value = getenv('PASDR_TEST_USER');
            a.pass.Value = getenv('PASDR_TEST_PASS');
            cb([],[]); a = api.state();
            assert(~isempty(a.devStrs), 'Real SSH and ALSA enumeration must succeed');
            api.sync([],[]); a = api.state();
            assert(contains(strjoin(a.log.Value,newline),'已生成 build/'));
            api.exec(['rm -rf ' remoteRoot]);
            [st,out] = api.exec('printf ''first\n\nlast\n''; exit 7');
            assert(st == 7 && strcmp(out,sprintf('first\n\nlast\n')));
            [st,out] = api.exec('i=0; while [ "$i" -lt 3000 ]; do echo output; i=$((i+1)); done');
            assert(st == 0 && count(out,newline) == 3000);
            a.rdir.Value = '~/space and ''quote';
            [st,out] = api.exec(['printf ''%s'' ' api.dir()]);
            assert(st == 0 && endsWith(out,'/space and ''quote'));
            remote = ['/tmp/pasdr_test_' char(java.util.UUID.randomUUID())];
            local = fullfile(work,'upload.txt');
            fid=fopen(local,'w'); fprintf(fid,'round trip\n'); fclose(fid);
            [st,out]=api.put(local,remote); assert(st==0,out);
            target=fullfile(work,'download.txt');
            [st,out]=api.get(remote,target); assert(st==0,out);
            assert(strcmp(fileread(local),fileread(target)));
            [st,~]=api.get([remote '_missing'],target); assert(st~=0);
            assert(strcmp(fileread(local),fileread(target)), 'Failed transfer must preserve old file');
            api.exec(['rm -f ' remote]);
            api.busy(true);
            failed = false;
            try, api.start('echo intentional_failure >&2; exit 7'); catch, failed=true; end
            assert(failed, 'Failed background command must propagate');
            api.busy(false);
            api.busy(true); api.start('sleep 1; exit 0'); assert(api.wait(5)); api.busy(false);
            api.busy(true); api.start('sleep 30'); api.stop([],[]);
            job = api.state();
            pause(0.3);
            [st,~] = api.exec(['pid=$(cat ' job.job '/pid); /bin/kill -0 -- -"$pid" 2>/dev/null']);
            assert(st ~= 0, 'Stop must terminate the remote process group');
            cancelled = false;
            try, api.wait(5); catch, cancelled=true; end
            assert(cancelled, 'Stop must cancel the local workflow');
            api.busy(false);
            api.busy(true); api.start('sleep 30'); assert(~api.wait(0.1)); api.busy(false);
            api.credentialsChanged(); a = api.state();
            assert(isempty(a.devStrs) && isempty(a.rdir.Value));
        end
        fprintf('PASS %s GUI regressions\n',folders{idx});
        clear closeGuard
    end
end

function cleanupWork(work)
    rmpath(work);
    rmdir(work,'s');
end
