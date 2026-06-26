# 可移植软件无线电工程（脱离 MathWorks 硬件支持包）

把原树莓派专用的 Simulink 实验工程，改造成在**树莓派 / Jetson / 香橙派 / x86**
等任意 Linux 上都能 `gcc` 直接编译运行的工程。运行时只依赖标准系统库
（`libasound` + `pthread`），**不再需要 MathWorks 树莓派支持包**。

## 目录结构

```
.
├── common/             跨实验共享的底层（音频 I/O、MAT 写入）
│   ├── include/        audio_io.h  mat_sink.h
│   └── src/            audio_io.c  audio_io_null.c  audio_io_file.c  mat_sink.c
├── exp1_single_freq/   实验一 · 单频信号测试  ✅ 已完成并实测
├── exp2_chirp/         实验二 · 线性调频(chirp)扩频通信  ✅ 已移植、声学实测 BER=0
└── slx_backup_.../     原生 R2025b slx 模型备份
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

## 致谢与许可

本项目**基于一套现成的树莓派 + Simulink 声学软件无线电教学工程改写**（原工程用
MathWorks 树莓派支持包，含单频与 chirp 扩频两个实验，基带图片之一为「兰州大学」
点阵）。在此向**原工程作者**致谢——原始的实验思路、Simulink 模型与 MATLAB 端
发射/解码脚本均来自原作者。

> 原工程**未声明任何开源许可证**（默认即"保留所有权利"）。本仓库以学习/改写为
> 目的公开；原作者部分的版权归原作者所有。若原作者认为不妥，请联系我处理。

**我的改动（"portable 化"方向，本人的 idea）**：
- 让接收端**完全脱离 MathWorks 硬件支持包**——把 Simulink 模型的硬件块换成通用
  Inport/Outport，重新生成纯算法 C 代码；
- 手写跨平台板级运行时（POSIX/ALSA 音频 I/O、MAT-v4 写入、调度），使其在
  树莓派 / Jetson / 香橙派 / x86 任意 Linux 上 `gcc` 直接编译运行；
- 发射/解码工具多图自适应、路径重构、取文件改用标准 `scp`。

**许可证**：本仓库**新增/改写的代码**（`common/`、各实验 `src/` `include/`
`Makefile`、`tools/`、对 `host/` 脚本与模型的改造）以 **GNU GPLv3** 发布（见
`LICENSE`）。注：GPLv3 是作者的主动选择；使用 POSIX 接口或链接 LGPL 的
`libasound`(ALSA 用户态库) 本身并不强制 copyleft。原工程未授权部分不在本许可
覆盖范围内。
