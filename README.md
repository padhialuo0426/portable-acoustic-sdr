# 可移植软件无线电工程（脱离 MathWorks 硬件支持包）

把原树莓派专用的 Simulink 实验工程，改造成在**树莓派 / Jetson / 香橙派 / x86**
等任意 Linux 上都能 `gcc` 直接编译运行的工程。运行时只依赖标准系统库
（`libasound` + `pthread`），**不再需要 MathWorks 树莓派支持包**。

## 目录结构

```
portable/
├── common/             跨实验共享的底层（音频 I/O、MAT 写入）
│   ├── include/        audio_io.h  mat_sink.h
│   └── src/            audio_io.c  audio_io_null.c  mat_sink.c
├── exp1_single_freq/   实验一 · 单频信号测试  ✅ 已完成并实测
└── exp2_chirp/         实验二 · 线性调频(chirp)扩频通信  ✅ 已移植(多速率)
```

每个实验目录自带：`Makefile`、`README.md`、`src/`（main + model_glue）、
`include/`（model_iface 契约）、`matlab/`（改造后的模型 + Simulink 生成代码）、
`tools/`（分析脚本）、`host/`（PC 端 MATLAB 脚本：发射 / 解码）。各实验独立
构建，共用 `../common` 的底层代码。

> 架构：两个实验都是「PC 端 MATLAB 脚本发射 + 板端 slx 接收」的非对称结构。
> `.slx` 只是**接收端**（移植的就是它）；发射端是 `host/` 下的 PC 脚本，用
> `sound()` 经声卡播放，本就与硬件支持包无关。板上结果（`.mat`）用标准
> `scp`/FileZilla 拉回 PC——原工程的 `:6666` TCP 文件服务器已不需要。

## 两个实验对应关系

| 实验 | 原始模型 | 功能 | 状态 |
|---|---|---|---|
| 实验一 | `single frequency/single_fre_rev.slx` | 声学单频信号接收/滤波/记录 | ✅ 已移植、实测通过 |
| 实验二 | `BOK/chirp_rev_detect.slx` | LFM 扩频通信接收检测（多速率 + 15 个 Stateflow） | ✅ 已移植，声学解码实测 BER=0 |

## 构建（以实验一为例）

```bash
cd exp1_single_freq
make                  # 真实模型 + ALSA（板上部署，需 libasound2-dev）
make AUDIO=null       # 真实模型 + 合成音频（无声卡机器上验证算法）
make MOCK=1           # 桩模型 + 合成音频（纯管线联调）
```

详见各实验目录下的 `README.md`。

## 共同设计

所有平台差异收敛到一个命令行参数（`-d plughw:x,0` 声卡设备名），代码全平台一致；
唯一耦合 Simulink 符号名的代码集中在各实验的 `src/model_glue.c`，重新生成模型后
只需核对一处字段名。
