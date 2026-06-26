# 实验二 · 线性调频(chirp)扩频通信 ✅ 已移植

把原树莓派 `chirp_rev_detect.slx` 改造成通用 Linux 工程。脱离 MathWorks 硬件
支持包，只需 `gcc + libasound`。本目录含**完整链路**（发射+接收+解码）。

## 目录结构

```
exp2_chirp/
├── 嵌入式接收端 (C, 跑在板上)
│   ├── Makefile  src/  include/
│   └── matlab/chirp_rev_detect.slx + 生成代码   ← Simulink 模型(已改造)
├── baseband_images/      基带图片(待传信息) ren128b/ren512b/lan336/lzu2048
└── host/                 PC 端 MATLAB 脚本(发射/解码/仿真/GUI)
    ├── Bok_emit.m  Bok_rev.m  BOK.m  client.m  bokgui.m
    ├── setup_paths.m   sample_data/(离线试解码用)
    └── README.md       ← PC 端用法与路径说明
```

完整声学链路：`host/Bok_emit.m`(发射) → 扬声器 → 麦克风 → `build/chirp_rx`(本接收端)
→ `chirp5.mat` → `host/Bok_rev.m`(解码/BER/还原图像)。详见 `host/README.md`。

## 功能

声学 chirp 扩频通信接收：麦克风采集 → 匹配滤波/相关检测（Stateflow）→ 输出
每帧 ±1 判决值。PC 端 `Bok_rev.m` 据此做帧同步、硬判决、算 BER、还原 128 位图像。

## 已做的改造

- `ALSA Audio Capture` → `Inport AudioIn`（int16[1600] = 800样本×2声道，`[L0..799,R0..799]`）
- **仅保留** `toFileData5` → `Outport out_data`（标量判决值），删除其余 10 个未用 To File
  （PC 端只用 `chirp5.mat/toFileData5`）
- `ert.tlc` + `HardwareBoard=None` + `GenCodeOnly` + `MatFileLogging=off`

## 多速率（与实验一的关键不同）

模型是双速率：`step0`@8000Hz（逐样本 chirp 相关）、`step1`@10Hz（每800样本一帧，
读音频/出判决）。运行时 `model_step_frame()` = `step1()` + `step0()×800`，
由 ALSA 阻塞读（800帧@8000Hz=100ms）提供 10Hz 实时节拍。

## 构建与运行

```bash
make                       # 真实模型 + ALSA（需 libasound2-dev）
make AUDIO=null            # 真实模型 + 合成音频（无声卡验证）
make MOCK=1                # 桩模型 + 合成音频

./build/chirp_rx -d default -t 15        # 采集 15 秒
```

产出 `chirp5.mat`（变量 `toFileData5`，2×N：第1行时间，第2行判决值），格式与原
工程一致，可直接喂给 `Bok_rev.m`。

## 验证状态 ✅ 全部通过

- ✅ 多速率 Stateflow 模型脱离支持包成功生成、零警告编译链接
- ✅ 实跑 10Hz 正确、`chirp5.mat` 格式正确
- ✅ **文件直喂（无噪声）解码 BER = 0/128**，帧同步锁定 [21,164]
- ✅ **真实声学（扬声器→麦克风）解码 BER = 0/128**，像素级还原 ren128b 图像

接收模型的符号检测、定时恢复、判决输出全部正确——真实声学信道上零误码。

## 任意图片支持（兼容 baseband_images 下全部图片）

发射/解码已做成**按图片尺寸自适应**——传入哪张 1-bit BMP，就自动读其宽高、
按 `图片比特数+15` 设帧间距、按真实宽高还原点阵。**接收端 C 代码与 Simulink
模型无需任何改动**：模型是符号无关的（每 0.1s 符号输出一个 ±1 判决），帧长仅由
发射端与采集时长决定。

| 图片 | 尺寸(宽×高) | 比特 | 帧符号数 | 信号时长 |
|---|---|---|---|---|
| ren128b  | 16×8  | 128  | 183  | 18.3s  |
| lan336   | 21×16 | 336  | 391  | 39.1s  |
| ren512b  | 32×16 | 512  | 567  | 56.7s  |
| lzu2048b(兰州大学) | 64×32 | 2048 | 2103 | 210.3s |

四张图均已**文件直喂实测 BER = 0/比特、像素级还原**。注意大图(lzu2048b)信号长
达 ~210s，声学采集需 `-t` 给足（`chirp_tx.py` 会打印建议秒数）。

## 复现测试（两种方式，无需 MATLAB）

`tools/` 下两个 Python 脚本复刻了 `Bok_emit`/`Bok_rev`，**均接受图片路径参数**：

```bash
IMG=baseband_images/lzu2048b.bmp     # 换任意图片；缺省为 ren128b.bmp

# 1) 生成发射信号(复刻 Bok_emit, 自动读该图片的全部比特)
python3 tools/chirp_tx.py $IMG       # -> chirp_tx.raw / chirp_tx.wav / tx_truth.txt
                                     #    并打印「声学采集建议」的 -t 秒数

# 2a) 文件直喂(无声学噪声, 纯测 DSP/解码)
make AUDIO=file && ./build/chirp_rx -d chirp_tx.raw

# 2b) 真实声学(扬声器播放 + 麦克风采集; -t 用上面打印的建议值)
make && (aplay -q chirp_tx.wav &) ; ./build/chirp_rx -d default -t 24

# 3) 解码(复刻 Bok_rev): 帧同步 + BER + 还原图像(尺寸自适应)
python3 tools/chirp_decode.py $IMG
```

也可用 PC 端 MATLAB 的 `host/Bok_emit.m`(发射) + `host/Bok_rev.m`(解码)：把两个
脚本顶部的 `img_name` 改成同一张图片即可，效果等价。
