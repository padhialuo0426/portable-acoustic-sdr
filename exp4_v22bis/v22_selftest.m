%% 实验四 · 协议层自检（不需要板子、不需要声卡）
%  跑一遍 v22_crc16 / v22_pack / v22_unpack，确认 HDLC 组帧这一层是对的。
%  物理层的验证在 v22_sim.m 里。

clear; rng(4321);
pass = 0; fail = 0;

fprintf('\n实验四 协议层自检\n%s\n', repmat('=',1,46));

%% 1. CRC-16/X.25 标准校验值
got = v22_crc16(uint8('123456789'));
ok  = (got == hex2dec('906E'));
fprintf('%-38s %s  (0x%04X)\n', 'CRC-16/X.25 校验值 "123456789"', ...
        string(ok)+"", got);
pass = pass + ok; fail = fail + ~ok;

%% 2. 组帧/解帧往返
allok = true;
for t = 1:200
    n  = randi([1 80]);
    pl = uint8(randi([0 255],1,n));
    f  = v22_unpack(v22_pack(pl));
    if numel(f)~=1 || ~f(1).ok || ~isequal(f(1).payload, pl), allok = false; break, end
end
fprintf('%-38s %s\n', '组帧/解帧往返 200 次随机载荷', string(allok)+"");
pass = pass + allok; fail = fail + ~allok;

%% 3. 位填充：帧体内不得出现 6 个连续 1
%  用全 0xFF 载荷逼出最坏情况（连续 1 最多）
bits = v22_pack(uint8(255*ones(1,32)));
body = bits(9:end-8);                       % 去掉首尾标志
run = 0; worst = 0;
for i = 1:numel(body)
    if body(i)==1, run = run+1; worst = max(worst,run); else, run = 0; end
end
ok = (worst <= 5);
fprintf('%-38s %s  (最长连 1 = %d)\n', '位填充：全 0xFF 载荷', string(ok)+"", worst);
pass = pass + ok; fail = fail + ~ok;

%% 4. 误码必须被 FCS 抓到
caught = 0;
for t = 1:200
    pl = uint8(randi([0 255],1,40));
    b  = v22_pack(pl);
    k  = randi([9 numel(b)-8]);             % 只翻帧体里的位
    b(k) = 1 - b(k);
    f = v22_unpack(b);
    % 翻位可能破坏帧结构（解不出帧）或让 FCS 失败，两者都算"抓到"
    if isempty(f) || ~any([f.ok]) || ~isequal(f(find([f.ok],1)).payload, pl)
        caught = caught + 1;
    end
end
ok = (caught == 200);
fprintf('%-38s %s  (%d/200)\n', '单比特误码被 FCS/帧结构抓到', string(ok)+"", caught);
pass = pass + ok; fail = fail + ~ok;

%% 5. 连续两帧背靠背
p1 = uint8(1:20); p2 = uint8(100:140);
f  = v22_unpack([v22_pack(p1), v22_pack(p2)]);
good = f([f.ok]);
ok = numel(good)>=2 && isequal(good(1).payload,p1) && isequal(good(2).payload,p2);
fprintf('%-38s %s  (解出 %d 个好帧)\n', '背靠背两帧', string(ok)+"", numel(good));
pass = pass + ok; fail = fail + ~ok;

%% 6. 前后有垃圾比特时仍能定位（模拟载波环捕获段的乱码）
pl = uint8(randi([0 255],1,50));
junk1 = randi([0 1],1,137); junk2 = randi([0 1],1,91);
f = v22_unpack([junk1, v22_pack(pl), junk2]);
ok = any(arrayfun(@(s) s.ok && isequal(s.payload,pl), f));
fprintf('%-38s %s\n', '首尾有垃圾比特时仍能定位帧', string(ok)+"");
pass = pass + ok; fail = fail + ~ok;

fprintf('%s\n通过 %d / %d\n\n', repmat('=',1,46), pass, pass+fail);
