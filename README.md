# portable-acoustic-sdr

一套 Simulink 声学软件无线电教学工程：PC 播放音频，开发板采集并解调，可使用扬声器/麦克风或有线音频通路。
接收端在**支持 ALSA 的 Linux**（x86 / 树莓派 / Jetson / 香橙派 / 其它 ARM 板）上 `gcc` 直接编译运行，
只依赖 `libasound`(ALSA) + `pthread`，**不需要 MathWorks 硬件支持包**。

含五个实验：**实验一 单频信号测试**、**实验二 DPSK 差分相移键控**、
**实验三 线性调频(chirp)扩频通信**、**实验四 V.22bis 风格的 QPSK/16-QAM 图片传输**、
**实验五 SSTV 多模式 图像传输**。

## 文档

详细说明都在 [`documents/`](documents/)：

- [`documents/README.md`](documents/README.md) — 按任务查找教程、原理、部署和参考文档
- [`documents/实验一_单频信号.md`](documents/实验一_单频信号.md) — 单音、滤波和 FFT 原理
- [`documents/实验二_DPSK.md`](documents/实验二_DPSK.md) — 差分编码、成形和帧同步原理
- [`documents/实验三_chirp扩频.md`](documents/实验三_chirp扩频.md) — 扫频、相关检测和多速率模型原理
- [`documents/实验四_V22bis.md`](documents/实验四_V22bis.md) — QPSK/16-QAM、符号恢复和 HDLC/FCS 原理
- [`documents/实验五_SSTV.md`](documents/实验五_SSTV.md) — 二值/彩色图像、VIS、逐行扫描和鉴频接收原理
- [`documents/构建与部署.md`](documents/构建与部署.md) — 从裸工程开始生成 C、命令行部署、MATLAB 收发与解码；含 GUI 简介和文件回放
- [`documents/接口与参数参考.md`](documents/接口与参数参考.md) — 环境、入口、参数、模型接口和数据格式
- [`documents/Q&A.md`](documents/Q&A.md) — **常见问题与坑点**（先看这个）

## 快速开始

1. 按[构建与部署](documents/构建与部署.md#准备环境)准备 MATLAB 及代码生成产品、Linux 开发板和音频通路。
2. 按[构建与部署](documents/构建与部署.md#生成模型代码)生成接收模型 C，再上传到板上编译。生成 C 不入库，新克隆后需先生成一次；发送 GUI 可切换 MATLAB 脚本与 Simulink 模型，默认 MATLAB；两种方式均无需生成发送 C。
3. 按[实验一操作步骤](documents/构建与部署.md#实验一)先启动采集，再播放 1 kHz 单音，取回数据查看频谱。
4. 再切换到图片实验，检查还原点阵、BER 和实验四星座图；实验五观察逐行图像恢复与像素误差。

没有声卡或 MATLAB 生成代码时，可以先做[桩模型管线检查](documents/构建与部署.md#构建模式)。

## 目录结构

```text
.
├── documents/           全部说明文档
├── common/              跨实验共享：板级底层(ALSA + MAT) + matlab/(GUI 共用层)
├── exp1_single_freq/    实验一 · 单频信号测试
├── exp2_dpsk/           实验二 · DPSK 差分相移键控
├── exp3_chirp/          实验三 · chirp 扩频通信
├── exp4_v22bis/         实验四 · QPSK / 16-QAM 图片传输
└── exp5_sstv/           实验五 · SSTV 多模式，默认二值化，可保留彩色
```

五个实验的根目录保留纯 MATLAB 发送机、Simulink 收发模型、MATLAB 解码器和 `gui.m` 入口。GUI 适配、共用算法和构建工具按用途放入子目录。例如实验二：

```text
portable-acoustic-sdr/
├── common/                       共用音频运行时与 GUI 框架
└── exp2_dpsk/
    ├── dpsk_emit.m               独立、单文件 MATLAB 发送机
    ├── dpsk_transmit.slx         Simulink 发送机
    ├── dpsk_receive.slx          Simulink 接收机
    ├── dpsk_decode.m             独立、单文件 MATLAB 解码器
    ├── gui.m                     GUI 入口，直接运行
    ├── gui_support/              GUI 波形适配函数
    ├── tools/                    模型构建工具
    ├── model/                    模型内部模块源代码
    ├── baseband_images/          发送图片
    ├── sample_data/              随仓库提供的接收样例
    ├── src/                      板上接收程序
    └── Makefile                  板上构建入口
```

五个纯 MATLAB 发送机均为实验根目录下的单文件实现：`single_fre_emit.m`、`dpsk_emit.m`、`bok_emit.m`、`v22_emit.m`、`sstv_emit.m`。复制发送文件和所选图片即可运行；算法、参数与模型发送分支分别实现。实验二至五的解码入口分别为 `dpsk_decode.m`、`bok_decode.m`、`v22_decode.m`、`sstv_decode.m`，所需算法和参数均在各自文件内。复制解码文件和接收数据、参考数据即可运行，不需要发送机或 GUI；实验一的 `single_fre_decode.m` 独立完成频谱分析。实验四、五的 `lib/` 供 GUI 和模型分支使用；实验五的 `sstv_transmit.sldd` 是发送模型必需的总线类型字典，与模型一起保留在根目录。接收模型生成与发送模型直接仿真的分工见[构建与部署](documents/构建与部署.md)。

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
