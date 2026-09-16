function q = shellQuote(s)
%SHELLQUOTE  POSIX shell 单引号转义，允许板上路径含空格/单引号。
    quote = char(39);
    q = [quote strrep(char(s), quote, [quote char(34) quote char(34) quote]) quote];
end
