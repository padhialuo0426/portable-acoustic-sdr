# 可移植软件无线电接收端（脱离 MathWorks 硬件支持包）

把原树莓派专用的 Simulink 工程，改造成在**树莓派 / Jetson / 香橙派 / x86**
等任意 Linux 上都能 `gcc` 直接编译运行的工程。运行时只依赖标准系统库
（`libasound` + `pthread`），**不再需要 MathWorks 树莓派支持包**。

## 思路

原工程的硬件耦合极少：模型里唯一的硬件块是 `ALSA Audio Capture`，结果走
`To File` 写 `.mat`，落到板上本地盘（PC 端用 `scp`/FileZilla 拉走）。
调度/线程在生成代码里本就是 POSIX（pthread + 信号量）。

> 注：原工程是「PC 端 MATLAB 脚本发射 + 板端 slx 接收」的非对称结构——
> `.slx` 只是**接收端**；发射端是 PC 脚本 `host/single_fre_emit.m`，用
> `sound()` 经声卡播放单频，与硬件支持包无关。详见 `host/README.md`。

因此移植 = 把音频 I/O 移出模型、用手写 POSIX/ALSA 代码替代支持包：

```
            ┌─────────────────── 本工程（手写，可移植）───────────────────┐
  麦克风 ──► audio_io(ALSA采集) ──► 去交织 ──► [模型输入] ─┐
            │                                              │  model_step()
            │                          [模型输出] ◄────────┘  (Simulink 生成的纯算法)
            │                              │
            └──► 文件落盘(.mat, scp 拉走) / 回放 ◄────┘
```

| 文件 | 作用 | 跨平台 |
|---|---|---|
| `src/audio_io.c` | POSIX/ALSA 采集+播放，取代支持包音频驱动 | ✅ 改设备名即可 |
| `src/audio_io_null.c` | 合成音频后端（无声卡联调用） | ✅ |
| `src/main.c` | 采集→喂模型→调度→落盘，取代 `ert_main.c`+`MW_*`+XCP | ✅ |
| `src/mat_sink.c` | MAT-v4 写入器，复刻 To File 的 `.mat` 输出 | ✅ |
| `src/model_glue.c` | 唯一耦合 Simulink 符号名的薄层 | — |
| `include/model_iface.h` | 运行时↔模型 的契约 | — |
| `matlab/single_fre_rev.slx` | 改造后适配当前 MATLAB 的模型 | — |
| `matlab/single_fre_rev_ert_rtw/*.c` | Simulink 生成的纯算法代码 | ✅ |

模型已改造并重新生成：ALSA Audio Capture → `Inport AudioIn(int16[160])`；
两个 To File → `Outport out_f1/out_f2(double[80])`；目标 `ert.tlc` +
`HardwareBoard=None`，关 MAT 日志。生成代码无任何支持包 / rt_logging 依赖。

**Makefile 直接读取生成目录 `matlab/single_fre_rev_ert_rtw/`，无需手动拷贝**：
在 MATLAB 里重新生成代码（覆盖该目录）后，直接 `make` 即可。如生成位置不同，
用 `make MODEL_DIR=路径` 覆盖。

## 三种构建（两个独立开关 MODEL / AUDIO）

```bash
make                       # 真实模型 + ALSA          —— 板上部署（需 libasound）
make AUDIO=null            # 真实模型 + 合成1kHz音频  —— 无声卡机器上验证算法
make MOCK=1                # 桩模型 + 合成音频         —— 纯管线/调度联调
```

运行产出 `single_f.mat`(变量 `toFileData`) 与 `single_f2.mat`(`toFileData2`)，
均为 81×N double（第 1 行时间，其余 80 行样本），与原工程 / PC 端 GUI 的
`load(...)` 完全兼容。

## 部署到目标板

1. 安装 ALSA 开发库：
   - Debian/Ubuntu/树莓派/香橙派: `sudo apt install libasound2-dev`
   - Jetson(L4T): `sudo apt install libasound2-dev`
   - Fedora: `sudo dnf install alsa-lib-devel`
2. 构建并运行：
   ```bash
   make
   ./build/sdr_rx -d plughw:2,0      # 用 arecord -l 查实际设备号
   ```

> 若日后修改 `.slx`，按 `matlab/单频模型说明.md` 在 MATLAB 里重新生成
> （直接覆盖 `matlab/single_fre_rev_ert_rtw/`），再 `make` 即可，运行时代码无需改动。

### 交叉编译（在 x86 上为 ARM 板编译）
```bash
make CC=aarch64-linux-gnu-gcc        # 目标板需有对应的 libasound
```

## 各板差异：只有声卡设备名

代码完全一致，唯一区别是 `-d` 指定的 ALSA 设备：

| 平台 | 查看命令 | 典型设备名 |
|---|---|---|
| 树莓派 | `arecord -l` | `plughw:2,0`（USB 声卡） |
| Jetson | `arecord -l` | `plughw:1,0` |
| 香橙派 | `arecord -l` | `plughw:0,0` / `default` |

用 `arecord -l` 找到麦克风那张卡的 **card 号 x**，跑时用 **`-d plughw:x,0`**。

> **不要用 `default`**：树莓派的 `default` 多是 asym 配置（只接了播放、没有采集
> slave），开采集会报 `capture slave is not defined / Invalid argument`。用
> `plughw:` 而非 `hw:`（前者自动做采样率/声道转换）。card 号在 USB 插拔/重启后可能变。

## 发射端与取文件

- **发射端**：PC 端 MATLAB 脚本 `host/single_fre_emit.m`，`sound()` 经扬声器
  播放单频信号（默认 1kHz）。详见 `host/README.md`。
- **取文件**：运行时由 `mat_sink.c`（纯 stdio）直接把 `single_f.mat` /
  `single_f2.mat` 写到板上本地盘，用标准 `scp`/FileZilla 拉回 PC：
  ```bash
  scp pi@<板子IP>:~/.../single_f.mat .
  ```
  原工程那套 `:6666` TCP 文件服务器 + `client.m` 已不需要（scp 一条命令的事）。
  `.mat` 格式与原 To File 一致，PC 端 `load(...)` / `tools/spectrum.m` 直接可用。
