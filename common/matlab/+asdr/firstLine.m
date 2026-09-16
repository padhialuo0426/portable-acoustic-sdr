function s = firstLine(txt)
%FIRSTLINE  取多行文本的第一行。ssh/scp 的报错常有好几行，日志里只留最有信息量的那句。
    t = strtrim(txt);
    if isempty(t), s = ''; return, end
    parts = strsplit(t, newline);
    s = strtrim(parts{1});
end
