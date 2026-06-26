# 工程文档 · 总览与导航

本目录集中存放工程的全部说明文档（之前散落在各子目录的 README 已汇总到这里）。

## 文档导航

| 文档 | 内容 |
|---|---|
| 本文（`README.md`） | 工程总览：架构、运行条件、共享底层、构建总览、重新生成模型 |
| [`实验一_单频信号.md`](实验一_单频信号.md) | 实验一逐目录文件说明 + 用法 + 模型改造 |
| [`实验二_chirp扩频.md`](实验二_chirp扩频.md) | 实验二逐目录文件说明 + 多速率/多图自适应 + 用法 |
| [`Q&A.md`](Q&A.md) | **常见问题与坑点**（部署、声卡、跨板差异、MATLAB、git 等） |

> 项目根目录的 `README.md` 只做**简要介绍 + 许可声明**；细节都在本目录。

---

## 这是什么

把一套原本**绑死树莓派**的 Simulink 声学软件无线电教学工程，移植成在**任意 Linux**
（x86 / 树莓派 / Jetson / 香橙派 / 其它 ARM 板）上 `gcc` 直接编译运行的工程。

**运行条件**：任意 Linux + `libasound`(ALSA 用户态库) + `pthread` + `gcc`。
**与具体板子无关**——平台差异只剩一个命令行参数 `-d <声卡设备名>`。

> 原工程靠 **Simulink Support Package for Raspberry Pi**（硬件支持包）才能跑：
> 模型里嵌 MathWorks 硬件块、生成树莓派专用代码。移植后**运行端完全脱离支持包**，
> 也不再需要树莓派——它只是"碰巧第一块验证板"。

## 整体架构：非对称「PC 发射 + 板端接收」

两个实验都是同一种结构——**`.slx` 模型只是接收端**，发射是 PC 端 MATLAB 脚本：

```
 PC: host/*_emit.m  --sound()-->  扬声器 ))) 空气 ))) 麦克风  -->  开发板: 接收端 C 程序
     (生成波形/播放)                  声学信道                       (ALSA 采集→模型→判决)
                                                                         │ 写 .mat
 PC: 解码/还原 (Bok_rev.m / spectrum.m / python) <--- scp/FileZilla 拉回 ---┘
```

- **发射端**（`host/`）：纯 PC MATLAB，用 `sound()` 经声卡播放，本就与硬件支持包无关。
  移植时等价复刻；exp2 另提供免 MATLAB 的 Python 版（`tools/chirp_tx.py`）。
- **接收端**（板上 C）：移植的核心。Simulink 只负责生成**纯算法 C**，音频 I/O、
  落盘、调度全部由手写的 POSIX/ALSA 代码（`common/`）承担。
- **取文件**：接收端把 `.mat` 写到板上本地盘，用标准 **`scp`/FileZilla** 拉回 PC。
  （原工程的 `:6666` TCP 文件服务器 + `client.m` 已废弃删除——它做的就是 `scp` 的事。）

## 顶层目录结构

```
.
├── README.md            根说明（简介 + 许可）
├── LICENSE              GNU GPLv3
├── documents/           ← 本文档目录
├── common/              跨实验共享的板级底层（音频 I/O + MAT 写入）
├── exp1_single_freq/    实验一 · 单频信号测试
├── exp2_chirp/          实验二 · 线性调频(chirp)扩频通信
└── slx_backup_.../      原生 R2025b .slx 模型备份
```

## 共享底层 `common/`

两个实验共用的板级运行时，全部手写 POSIX，零支持包依赖：

| 文件 | 作用 |
|---|---|
| `include/audio_io.h`、`src/audio_io.c` | POSIX/ALSA 采集+播放（S16_LE，设备/速率/声道/帧长可配，`snd_pcm_recover` 处理 xrun），取代支持包音频驱动 |
| `src/audio_io_null.c` | 合成 1kHz 单音后端（无声卡机器联调，编译开关 `AUDIO=null`） |
| `src/audio_io_file.c` | 原始 int16 文件输入后端（无噪声链路验证，`AUDIO=file`） |
| `include/mat_sink.h`、`src/mat_sink.c` | MAT-v4 流式写入器，复刻原 `To File` 的 `.mat` 输出 |

平台差异收敛到一个参数 `-d`；唯一耦合 Simulink 符号名的代码集中在各实验
`src/model_glue.c`（重新生成模型后只需核对一处字段名）。

## 两个实验对照

| 实验 | 原始模型 | 功能 | 接收端可执行 |
|---|---|---|---|
| [实验一](实验一_单频信号.md) | `single frequency/single_fre_rev.slx` | 声学单频接收/滤波/记录 | `sdr_rx` |
| [实验二](实验二_chirp扩频.md) | `BOK/chirp_rev_detect.slx` | LFM 扩频接收检测（多速率 + 15 个 Stateflow） | `chirp_rx` |

两实验均已在 **x86 + 树莓派(aarch64) + 香橙派(Ascend310B)** 三平台实测，
实验二声学解码 **BER = 0**。

## 构建总览（两个独立开关 MODEL / AUDIO）

每个实验目录下：

```bash
make                       # 真实模型 + ALSA      —— 板上部署（需 libasound2-dev）
make AUDIO=null            # 真实模型 + 合成音频   —— 无声卡机器验证算法
make AUDIO=file            # 真实模型 + 文件输入   —— 无噪声链路验证（喂 .raw）
make MOCK=1                # 桩模型 + 合成音频     —— 纯管线/调度联调
```

安装 ALSA 开发库：Debian/Ubuntu/树莓派/香橙派/Jetson `sudo apt install libasound2-dev`；
Fedora `sudo dnf install alsa-lib-devel`。交叉编译：`make CC=aarch64-linux-gnu-gcc`。

## 重新生成模型（改算法后，需 MATLAB）

`.slx` 与生成的 C 代码（`matlab/*_ert_rtw/*.c/.h`）都已入库，**运行端不需要 MATLAB**。
只有当你要改算法时才需要在 MATLAB 里重新生成：配置 `ert.tlc` + `HardwareBoard=None`
+ `GenCodeOnly` + 关 MAT 日志，`slbuild` 直接覆盖 `matlab/*_ert_rtw/`，再 `make` 即可。
Device Type 已设为 `ARM Cortex-A (64-bit)`。详细步骤见各实验文档；踩坑见 [Q&A](Q&A.md)。

## 致谢与许可

见根目录 `README.md`。本工程基于一套现成的树莓派 + Simulink 声学 SDR 教学工程改写
（原工程未声明许可证）；新增/改写的代码以 **GNU GPLv3** 发布。
