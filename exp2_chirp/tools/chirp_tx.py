#!/usr/bin/env python3
"""
chirp_tx.py ── 复刻 Bok_emit.m 的 BOK chirp 扩频发射，生成测试信号。
不需要 MATLAB。**支持 baseband_images/ 下任意 1-bit BMP**（自动读宽高、
按图片比特数组帧，帧头/帧尾各一段 15 位 m 序列）。输出:
  chirp_tx.raw  (单声道 int16, 喂 `chirp_rx -d chirp_tx.raw` 做无噪声链路测试)
  chirp_tx.wav  (8kHz 单声道, 用 `aplay chirp_tx.wav` 经扬声器发射)
  tx_truth.txt  (发送的全部图片比特真值, 供解码算 BER)

用法: python3 chirp_tx.py [图片.bmp]    # 默认 ../baseband_images/ren128b.bmp
"""
import struct, math, wave, sys, os

fs, T, B, n, fc = 8000, 0.1, 200, 800, 1000
k = B / T
t = [i * T / (n - 1) for i in range(n)]
m_seq = [1,0,0,1,1,0,1,0,1,1,1,1,0,0,0]

here = os.path.dirname(os.path.abspath(__file__))
bmp = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'baseband_images', 'ren128b.bmp')

# 读 1-bit BMP（自动宽高）。MATLAB 列优先: info_all((m-1)*NN+nn)=data(nn,m)
# 即按列遍历: 外层列 mm(宽 w)、内层行 nn(高 h)，长度 = w*h。
d = open(bmp, 'rb').read()
off = struct.unpack('<I', d[10:14])[0]
w   = struct.unpack('<i', d[18:22])[0]
h   = struct.unpack('<i', d[22:26])[0]
bpp = struct.unpack('<H', d[28:30])[0]
if bpp != 1:
    sys.exit(f'仅支持 1-bit BMP，{os.path.basename(bmp)} 为 {bpp}-bit')
H = abs(h); rowsize = ((w + 31) // 32) * 4
def px(row, col):
    fr = (H - 1 - row) if h > 0 else row          # h>0 自底向上存储
    return (d[off + fr * rowsize + col // 8] >> (7 - col % 8)) & 1
info_all = [px(nn, mm) for mm in range(w) for nn in range(H)]
L = len(info_all)                                  # 图片比特数 = w*H

# 组帧（与 Bok_emit 帧结构一致，长度随图片自适应）:
#   [0:10]=0 前导/信号检测  [10:20]=1010… 交替段
#   [20:35]=m_seq 帧头      [35:35+L]=图片  [35+L:35+L+15]=m_seq 帧尾
#   末尾 GUARD 个 0：补偿接收模型 1 符号检测时延 + 防止帧尾 m 序列落在 EOF 被截断
GUARD = 5
info = [0] * (50 + L + GUARD)
info[10:20] = [1,0,1,0,1,0,1,0,1,0]
info[20:35] = m_seq
info[35:35 + L] = info_all
info[35 + L:50 + L] = m_seq

# BOK chirp 调制: bit0->上扫(miu=+1), bit1->下扫(miu=-1)
amp = 10000
pcm = []
for b in info:
    miu = 1 if b == 0 else -1
    for i in range(n):
        s = math.cos(2 * math.pi * fc * t[i] + math.pi * miu * k * t[i] ** 2)
        pcm.append(max(-32768, min(32767, int(amp * s))))

raw = struct.pack('<%dh' % len(pcm), *pcm)
open(os.path.join(here, '..', 'chirp_tx.raw'), 'wb').write(raw)
wv = wave.open(os.path.join(here, '..', 'chirp_tx.wav'), 'wb')
wv.setnchannels(1); wv.setsampwidth(2); wv.setframerate(fs); wv.writeframes(raw); wv.close()
open(os.path.join(here, '..', 'tx_truth.txt'), 'w').write(''.join(map(str, info_all)))
dur = len(pcm) / fs
print(f'图片={os.path.basename(bmp)} {w}x{H}={L}位  符号数={len(info)} '
      f'时长={dur:.1f}s -> chirp_tx.raw/.wav, tx_truth.txt')
print(f'声学采集建议: ./build/chirp_rx -d default -t {math.ceil(dur)+6}')
