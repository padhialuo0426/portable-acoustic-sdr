# 实验一 · PC 端 MATLAB 脚本（发射）

跑在 PC（MATLAB）上的发射端。板上的接收端 C 程序在上一级目录（`../`，`make`
构建出 `sdr_rx`）。与实验二一样，发射端是 PC 脚本，不上板、不依赖硬件支持包。

## 完整链路

```
[本目录 single_fre_emit.m] 生成 1kHz 单频 → sound() 扬声器播放
        │ 声波
        ▼
[麦克风] → [板上 ../build/sdr_rx] → single_f.mat / single_f2.mat（滤波后样本）
        │ scp / FileZilla 拷回 PC
        ▼
[PC] load + tools/spectrum.m  → FFT 看频谱峰值（应在 1000 Hz）
```

## 文件

| 文件 | 作用 |
|---|---|
| `single_fre_emit.m` | 发射端：生成单频（默认 1kHz，可改 `fc`）→ `sound()` 播放；含双频叠加/前后发送的注释变体 |

## 用法

```matlab
single_fre_emit          % 一台机器扬声器播放单频信号
```
另一端：`cd ..; ./build/sdr_rx -d default -t <秒数>` 采集得 `single_f.mat`，
用 `scp` 拷回 PC 后 `load` + `tools/spectrum.m` 看频谱。
