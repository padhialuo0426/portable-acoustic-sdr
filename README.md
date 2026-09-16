# portable-acoustic-sdr

一套 Simulink 声学软件无线电教学工程：PC 用扬声器发射，开发板用麦克风接收。
接收端在**任意 Linux**（x86 / 树莓派 / Jetson / 香橙派 / 其它 ARM 板）上 `gcc` 直接编译运行，
只依赖 `libasound`(ALSA) + `pthread`，**不需要 MathWorks 硬件支持包**。

含三个实验：**实验一 单频信号测试**、**实验二 DPSK 差分相移键控**、
**实验三 线性调频(chirp)扩频通信**

## 文档

详细说明都在 [`documents/`](documents/)：

- [`documents/README.md`](documents/README.md) — 工程总览：架构、运行条件、共享底层、构建总览
- [`documents/实验一_单频信号.md`](documents/实验一_单频信号.md) — 实验一逐目录文件说明 + 用法
- [`documents/实验二_DPSK.md`](documents/实验二_DPSK.md) — 实验二逐目录文件说明 + 用法
- [`documents/实验三_chirp扩频.md`](documents/实验三_chirp扩频.md) — 实验三逐目录文件说明 + 用法
- [`documents/手把手部署运行教程.md`](documents/手把手部署运行教程.md) — **从零到实测分步操作**（传代码上板→编译→实测→解码）
- [`documents/Q&A.md`](documents/Q&A.md) — **常见问题与坑点**（先看这个）

## 快速开始

```bash
cd exp3_chirp
make                                 # 需 libasound2-dev（apt install / dnf install alsa-lib-devel）
arecord -l                           # 看麦克风是 card 几
./build/chirp_rx -d plughw:1,0 -t 28 # card 号按实际改
```

## 目录结构

```
.
├── documents/           全部说明文档
├── common/              跨实验共享：板级底层(ALSA + MAT) + matlab/(GUI 共用层)
├── exp1_single_freq/    实验一 · 单频信号测试
├── exp2_dpsk/           实验二 · DPSK 差分相移键控
└── exp3_chirp/          实验三 · chirp 扩频通信

每个实验目录固定分三块——「板上的 / PC 上的 / 两边共用的」：

    exp2_dpsk/
    ├── Makefile             板上构建入口
    ├── board/               板上要的一切
    │   ├── main.c  model_glue.c  model_iface.h     手写
    │   ├── model/           Simulink 生成的 C（可整个删掉重生成）
    │   └── py/              免 MATLAB 的板上发射/解码脚本
    ├── host/                PC 上 MATLAB 要的
    │   ├── dpsk_receive.slx     模型
    │   ├── dpsk_emit.m  dpsk_rev.m  gui.m  setup_paths.m
    │   └── sample_data/         离线试解码用的样例
    └── baseband_images/     基带图片，MATLAB 与板上 py 都读它（实验一无此项）
```

## 致谢与许可

本项目**基于一套现成的树莓派 + Simulink 声学软件无线电教学工程改写**（原工程用
MathWorks 树莓派支持包，含单频、DPSK 与 chirp 扩频三个实验，基带图片之一为「兰州大学」点阵）。
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
