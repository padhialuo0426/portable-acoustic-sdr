#!/usr/bin/env python3
"""
chirp_decode.py ── 复刻 bok_rev.m 的解码：读 chirp_rx 产出的 chirp5.mat
(toFileData5 判决流)，相关 m 序列做帧同步、硬判决、算 BER、还原图像。
不需要 MATLAB。**支持任意尺寸图片**：从原始 BMP 自动读宽高，
帧头/帧尾两段 m 序列间距 = 图片比特数+15，按真实宽高还原点阵。

用法: python3 chirp_decode.py [图片.bmp] [chirp5.mat]
      默认 ../baseband_images/ren128b.bmp 与 ../chirp5.mat
"""
import struct, array, sys, os

here = os.path.dirname(os.path.abspath(__file__))
bmp  = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'baseband_images', 'ren128b.bmp')
matf = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, '..', 'chirp5.mat')
mseq_pm = [-1,1,1,-1,-1,1,-1,1,-1,-1,-1,-1,1,1,1]

# 原始图片：自动宽高 + 真值比特（列优先, 与 chirp_tx 一致）
d = open(bmp, 'rb').read()
off = struct.unpack('<I', d[10:14])[0]
w   = struct.unpack('<i', d[18:22])[0]
h   = struct.unpack('<i', d[22:26])[0]
H = abs(h); rowsize = ((w + 31) // 32) * 4
def px(row, col):
    fr = (H - 1 - row) if h > 0 else row
    return (d[off + fr * rowsize + col // 8] >> (7 - col % 8)) & 1
truth = [px(nn, mm) for mm in range(w) for nn in range(H)]
L   = len(truth)          # 图片比特数
gap = L + 15              # 两段 m 序列起点间距 = 图片长度 + m序列长度

f = open(matf, 'rb')
ty, m, n, im, nl = struct.unpack('<5i', f.read(20)); f.read(nl)
a = array.array('d'); a.frombytes(f.read(8 * m * n))
x = [a[k * m + 1] for k in range(n)]            # 第2行 = 判决值

def find_sync(x, flag):
    loc = []
    for nn in range(len(x) - 14):
        corr = sum(x[nn+i] * flag * mseq_pm[i] for i in range(15))
        if corr > sum(abs(x[nn+i]) for i in range(11)) and abs(x[nn]) == 1:
            loc.append(nn)
    return loc

best = None
for flag in (1, -1):
    loc = find_sync(x, flag)
    for i in range(len(loc)):
        for j in range(i+1, len(loc)):
            if loc[j] - loc[i] == gap:
                best = (flag, loc[i], loc[j]); break
        if best: break
    if best: break

if not best:
    print(f'未找到帧同步(相距{gap}的两段m序列)。判决流可能未对齐/信号太弱/采集时长不足。')
    sys.exit(1)

flag, l1, l2 = best
dec = [(0 if v > 0 else 1) for v in x[l1+15:l2]]
if flag == -1: dec = [1-b for b in dec]
print(f'图片={os.path.basename(bmp)} {w}x{H}={L}位  帧同步: flag={flag} '
      f'帧头={l1} 帧尾={l2} (相距{l2-l1})')

err = sum(1 for a_, b_ in zip(dec, truth) if a_ != b_)
print(f'BER = {err}/{len(truth)} = {err/len(truth):.4f}')

print(f'=== 还原图像 ({H}x{w}) ===')
for nn in range(H):
    print(''.join('  ' if dec[mm*H+nn] else '##' for mm in range(w)))
