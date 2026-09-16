#!/usr/bin/env python3
"""
dpsk_emit.py ── 复刻 dpsk_emit.m 的 DPSK 发射，生成测试信号。
不需要 MATLAB。**支持 baseband_images/ 下任意 1-bit BMP**（自动读宽高、
按图片比特数组帧）。输出:
  dpsk_tx.raw  (单声道 int16, 喂 `dpsk_rx -d dpsk_tx.raw` 做无噪声链路测试)
  dpsk_tx.wav  (8kHz 单声道, 用 `aplay dpsk_tx.wav` 经扬声器发射)
  tx_truth.txt (发送的全部图片比特真值, 供解码算 BER)

用法: python3 dpsk_emit.py [图片.bmp]    # 默认 ../baseband_images/ren512b.bmp
"""
import struct, math, wave, sys, os, random

fs, fm, fc = 8000, 100, 1000          # 采样率 / 符号率 / 载波
N     = fs // fm                      # 每符号样本数 = 80
T     = 1.0 / fm                      # 符号时间 = 0.01s
beta  = 0.5                           # 滚降系数
mdel  = 1                             # 成形滤波器延迟(符号)
GUARD = 80                            # 帧尾保护符号：必须盖过模型的流水延迟
                                      # （匹配滤波后延迟 3200 样本 = 40 符号），
                                      # 否则帧尾 m 序列还没流出管线信号就结束了
m_seq = [1,0,0,1,1,0,1,0,1,1,1,1,0,0,0]

here = os.path.dirname(os.path.abspath(__file__))
bmp = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'baseband_images', 'ren512b.bmp')

# 读 1-bit BMP（自动宽高）。列优先: info_all((m-1)*NN+n)=data(n,m)
d = open(bmp, 'rb').read()
off = struct.unpack('<I', d[10:14])[0]
w   = struct.unpack('<i', d[18:22])[0]
h   = struct.unpack('<i', d[22:26])[0]
bpp = struct.unpack('<H', d[28:30])[0]
if bpp != 1:
    sys.exit(f'仅支持 1-bit BMP，{os.path.basename(bmp)} 为 {bpp}-bit')
H = abs(h); rowsize = ((w + 31) // 32) * 4
def px(row, col):
    fr = (H - 1 - row) if h > 0 else row
    return (d[off + fr * rowsize + col // 8] >> (7 - col % 8)) & 1
info_all = [px(nn, mm) for mm in range(w) for nn in range(H)]
L = len(info_all)

# 组帧（与 dpsk_emit.m 一致，长度随图片自适应）:
#   [0:18]=0 静默/信号检测   [18:26]=01010101 交替段
#   [26:41]=m_seq 帧头       [41:41+L]=图片   [41+L:56+L]=m_seq 帧尾
#   末尾 GUARD 个 0
code = 56 + L + GUARD
random.seed(20260611)                  # 原脚本用 rand 填充尾部，这里固定种子保证可复现
info = [random.randint(0, 1) for _ in range(code)]
info[0:18]      = [0]*18
info[18:26]     = [0,1,0,1,0,1,0,1]
info[26:41]     = m_seq
info[41:41+L]   = info_all
info[41+L:56+L] = m_seq
info[56+L:]     = [0]*(code - 56 - L)

# 差分编码：与参考相位相同 -> +1，不同 -> -1
temp = [0]*(code+1)
ds   = [0]*code
for i in range(code):
    if info[i] == temp[i]:
        temp[i+1] = 0;  ds[i] = 1
    else:
        temp[i+1] = 1;  ds[i] = -1

# 平方根升余弦成形滤波器 h1（与 .m 逐式对应；z 加 eps 避开 0/0 可去奇点）
eps = 2.220446049250313e-16
h1 = []
for n in range(1, 2*mdel*N + 1):
    z   = n / N - mdel + eps
    t1  = math.cos((1 + beta) * math.pi * z)
    t2  = math.sin((1 - beta) * math.pi * z)
    t3  = 1.0 / (4 * beta * z)
    den = 1 - 16 * beta * beta * z * z
    h1.append((4 * beta / (math.pi * math.sqrt(T))) * (t1 + t2 * t3) / den)

# conv(upsample(ds,N), h1)：st1 只在 i*N 处非零，直接叠加省去 6400 万次乘加
out_len = code * N + len(h1) - 1
sq = [0.0] * out_len
for i, v in enumerate(ds):
    base = i * N
    for j, hv in enumerate(h1):
        sq[base + j] += v * hv

# DPSK 调制：成形基带 × 1kHz 载波
peak = max(abs(v) for v in sq) or 1.0
amp  = 10000.0 / peak
pcm  = []
for i, v in enumerate(sq):
    s = amp * v * math.sin(2 * math.pi * fc * i / fs)
    pcm.append(max(-32768, min(32767, int(s))))

raw = struct.pack('<%dh' % len(pcm), *pcm)
open(os.path.join(here, '..', 'dpsk_tx.raw'), 'wb').write(raw)
wv = wave.open(os.path.join(here, '..', 'dpsk_tx.wav'), 'wb')
wv.setnchannels(1); wv.setsampwidth(2); wv.setframerate(fs); wv.writeframes(raw); wv.close()
open(os.path.join(here, '..', 'tx_truth.txt'), 'w').write(''.join(map(str, info_all)))
dur = len(pcm) / fs
print(f'图片={os.path.basename(bmp)} {w}x{H}={L}位  符号数={code} '
      f'时长={dur:.1f}s -> dpsk_tx.raw/.wav, tx_truth.txt')
print(f'声学采集建议: ./build/dpsk_rx -d plughw:2,0 -t {math.ceil(dur)+6}')
