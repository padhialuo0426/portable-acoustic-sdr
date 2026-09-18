function [connection,note] = readConnection(file)
%READCONNECTION  读取 GUI 本地连接配置；不执行文件中的代码，不输出账号密码。
% 文件缺失时保留空输入框；格式错误时给出提示，仍允许在 GUI 手工填写。
    if nargin<1
        common=fileparts(fileparts(fileparts(mfilename('fullpath'))));
        file=fullfile(common,'connection.json');
    end
    connection=struct('ip','','username','','password','');note='';
    if ~isfile(file),return,end
    try
        value=jsondecode(fileread(file));
        names=fieldnames(connection);
        assert(isstruct(value) && isscalar(value));
        for k=1:numel(names)
            assert(isfield(value,names{k}));
            field=value.(names{k});
            assert(ischar(field) && (isrow(field) || isempty(field)));
        end
        connection.ip=strtrim(value.ip);
        connection.username=strtrim(value.username);
        connection.password=value.password; % 密码中的空格也是有效字符。
        note='已读取 common/connection.json；连接信息仍可在界面修改。';
    catch
        note=['common/connection.json 格式错误：需要 ip、username、password 三个文本字段。' ...
              '请参照 connection.example.json 修改，或在界面手工填写。'];
    end
end
