# portable-acoustic-sdr

把一套原本**绑死树莓派**的 Simulink 声学软件无线电教学工程，移植成在**任意 Linux**
（x86 / 树莓派 / Jetson / 香橙派 / 其它 ARM 板）上 `gcc` 直接编译运行的工程。
运行时只依赖 `libasound`(ALSA) + `pthread`，**不再需要 MathWorks 树莓派硬件支持包**。

含两个实验：**实验一 单频信号测试**、**实验二 线性调频(chirp)扩频通信**

## 文档

详细说明都在 [`documents/`](documents/)：

- [`documents/README.md`](documents/README.md) — 工程总览：架构、运行条件、共享底层、构建总览
- [`documents/实验一_单频信号.md`](documents/实验一_单频信号.md) — 实验一逐目录文件说明 + 用法
- [`documents/实验二_chirp扩频.md`](documents/实验二_chirp扩频.md) — 实验二逐目录文件说明 + 用法
- [`documents/Q&A.md`](documents/Q&A.md) — **常见问题与坑点**（先看这个）

## 快速开始

```bash
cd exp2_chirp
make                                 # 需 libasound2-dev（apt install / dnf install alsa-lib-devel）
arecord -l                           # 看麦克风是 card 几
./build/chirp_rx -d plughw:1,0 -t 28 # card 号按实际改
```

## 目录结构

```
.
├── documents/           全部说明文档
├── common/              跨实验共享的板级底层（ALSA 音频 I/O + MAT 写入）
├── exp1_single_freq/    实验一 · 单频信号测试
├── exp2_chirp/          实验二 · chirp 扩频通信
└── slx_backup_.../      原生 R2025b .slx 模型备份
```

## 致谢与许可

本项目**基于一套现成的树莓派 + Simulink 声学软件无线电教学工程改写**（原工程用
MathWorks 树莓派支持包，含单频与 chirp 扩频两个实验，基带图片之一为「兰州大学」点阵）。
在此向**原工程作者**致谢——原始的实验思路、Simulink 模型与 MATLAB 端发射/解码脚本均来自原作者。

> 原工程**未声明任何开源许可证**（默认即"保留所有权利"）。本仓库以学习/改写为目的公开；
> 原作者部分的版权归原作者所有。若原作者认为不妥，请联系我处理。

**本人改动（"portable 化"方向）**：让接收端**完全脱离硬件支持包**（Simulink 模型的硬件块
换成通用 Inport/Outport，重新生成纯算法 C）；手写跨平台板级运行时（POSIX/ALSA 音频 I/O、
MAT-v4 写入、调度），使其在任意 Linux 上 `gcc` 直接编译运行；发射/解码工具多图自适应、
取文件改用标准 `scp`。

**许可证**：本仓库**新增/改写的代码**以 **GNU GPLv3** 发布（见 `LICENSE`）。
注：GPLv3 是作者主动选择；使用 POSIX 接口或链接 LGPL 的 `libasound` 本身并不强制 copyleft。
原工程未授权部分不在本许可覆盖范围内。
