# portable-acoustic-sdr

一套 Simulink 声学软件无线电教学工程：PC 播放音频，开发板采集并解调，可使用扬声器/麦克风或有线音频通路。
接收端在**支持 ALSA 的 Linux**（x86 / 树莓派 / Jetson / 香橙派 / 其它 ARM 板）上 `gcc` 直接编译运行，
只依赖 `libasound`(ALSA) + `pthread`，**不需要 MathWorks 硬件支持包**。

含四个实验：**实验一 单频信号测试**、**实验二 DPSK 差分相移键控**、
**实验三 线性调频(chirp)扩频通信**、**实验四 V.22bis 风格的 QPSK/16-QAM 图片传输**

## 文档

详细说明都在 [`documents/`](documents/)：

- [`documents/README.md`](documents/README.md) — 按任务查找教程、原理、部署和参考文档
- [`documents/实验一_单频信号.md`](documents/实验一_单频信号.md) — 单音、滤波和 FFT 原理
- [`documents/实验二_DPSK.md`](documents/实验二_DPSK.md) — 差分编码、成形和帧同步原理
- [`documents/实验三_chirp扩频.md`](documents/实验三_chirp扩频.md) — 扫频、相关检测和多速率模型原理
- [`documents/实验四_V22bis.md`](documents/实验四_V22bis.md) — QPSK/16-QAM、符号恢复和 HDLC/FCS 原理
- [`documents/手把手部署运行教程.md`](documents/手把手部署运行教程.md) — **从零到实测分步操作**（传代码上板→编译→实测→解码）
- [`documents/构建与部署.md`](documents/构建与部署.md) — 代码生成、上传、重建和文件回放
- [`documents/接口与参数参考.md`](documents/接口与参数参考.md) — 环境、入口、参数、模型接口和数据格式
- [`documents/Q&A.md`](documents/Q&A.md) — **常见问题与坑点**（先看这个）

## 快速开始

1. 按[部署运行教程](documents/手把手部署运行教程.md#准备环境)准备 MATLAB 及代码生成产品、Linux 开发板和音频通路。
2. 按[构建与部署](documents/构建与部署.md#生成模型代码)生成接收模型 C，再上传到板上编译。生成 C 不入库，新克隆后需先生成一次。
3. 按[实验一操作步骤](documents/手把手部署运行教程.md#实验一)先启动采集，再播放 1 kHz 单音，取回数据查看频谱。
4. 再切换到图片实验，检查还原点阵、BER 和实验四星座图。

没有声卡或 MATLAB 生成代码时，可以先做[桩模型管线检查](documents/构建与部署.md#构建模式)。实验二、三的 Python 脚本支持在已有真实接收程序的环境中发射与解码；它们不代替模型 C 的生成。

## 目录结构

```text
.
├── documents/           全部说明文档
├── common/              跨实验共享：板级底层(ALSA + MAT) + matlab/(GUI 共用层)
├── exp1_single_freq/    实验一 · 单频信号测试
├── exp2_dpsk/           实验二 · DPSK 差分相移键控
├── exp3_chirp/          实验三 · chirp 扩频通信
└── exp4_v22bis/         实验四 · QPSK / 16-QAM 图片传输
```

实验一至三的入口是扁平的，`.slx` 与各 `.m` 脚本都直接放在根下，子目录只有
`src/`（手写 C）和 `py/`（板上脚本）这两类代码，外加存数据的 `sample_data/`
与 `baseband_images/`（实验一只有 `src/`）：

```text
    exp2_dpsk/
    ├── Makefile             板上构建入口
    ├── dpsk_receive.slx         Simulink 模型（只在 PC 上打开，不上板）
    ├── dpsk_receive_ert_rtw/    模型生成的 C（**不入库**，MATLAB 里生成）
    ├── src/                 手写 C：main.c  model_glue.c  model_iface.h
    ├── py/                  板上 Python 发射/解码脚本
    ├── dpsk_emit.m  dpsk_rev.m  gui.m  setup_paths.m
    ├── sample_data/         离线试解码用的样例
    └── baseband_images/     基带图片，MATLAB 与板上 py 都读它（实验一无此项）
```

实验四将内部算法放在 `private/`、模型源文件放在 `model/`；收发、GUI 和建模入口留在实验根目录。

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
