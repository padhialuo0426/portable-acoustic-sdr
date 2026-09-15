# 常见问题与坑点 Q&A

按"现象 → 原因 → 解决"组织。很多坑本身就是 Linux / 音频 / 嵌入式部署的学习点，
建议遇到时对照理解，而不是直接抄命令。

---

## 一、声卡与设备选择

### Q1. 直接跑 `./build/chirp_rx` 报 `capture slave is not defined` / `Invalid argument`

**现象**
```
ALSA lib pcm_asym.c: (_snd_pcm_asym_open) capture slave is not defined
audio_io: 打开设备 'default' 失败: Invalid argument
致命错误：无法打开采集设备 'default'
```
**原因**：不带 `-d` 时默认用 `default` 设备。树莓派等板子的 `default` PCM 常是
asym 配置——**只接了播放、没有定义采集 slave**，所以拿 `default` 开采集就失败。
**解决**：用 `-d` 显式指定麦克风设备，**不要用 `default` 采集**。见 Q2。

### Q2. 怎么选 `-d` 参数（采集设备名）？

1. `arecord -l` 列出采集设备，找到麦克风那张卡的 **card 号 x**（`device` 号通常 0）。
2. 跑时用 **`-d plughw:x,0`**（card 2 → `plughw:2,0`，card 1 → `plughw:1,0`）。

```bash
arecord -l
./build/chirp_rx -d plughw:1,0 -t 28
```

要点：
- 用 **`plughw:`** 而非 `hw:`——`plug` 插件自动做采样率/声道转换（程序要 8000Hz、
  单声道，设备不一定原生支持）；直接 `hw:` 可能因格式不匹配打不开。
- **card 号在 USB 重新插拔或重启后可能变**，跑之前 `arecord -l` 瞟一眼最稳。
  （实测：同一个 USB 麦克风在树莓派是 card 2、在香橙派是 card 1。）
- 采集看 `arecord -l`、播放看 `aplay -l`，两者 card 号可能不同，别混。

### Q3. 判决流恒为 −1、帧同步失败（信号明明很强）

**现象**：某些板（实测香橙派 Ascend310B）上实采时判决流几乎全是 −1、找不到帧同步；
但**文件直喂正常、把麦克风录音(`arecord -c1`)喂文件路径也正常**。
**原因**：接收端原来开 **2 声道**采集、按 `inter[2i]/inter[2i+1]` 去交织。该板
`plughw` 的 2 声道交织流里**单独取左/右任一路都解不出**（两路峰值都很强但都解不出），
而 `plughw` 的**单声道下混**能正确解码。树莓派恰好 ch0 即麦克风信号，所以之前 2 声道能用。
**解决**：接收端已**默认单声道采集 `-c 1`**（`plughw` 把任意设备下混为单声道，跨板最稳），
单声道同时填模型左右两路。若确需立体声取左声道用 `-c 2`。**这是默认行为，无需改命令。**

### Q4. 麦克风录到的全是静音（RMS≈2、峰值≈10）

**现象**：实采全 0 判决；用下面的电平表测，安静环境 RMS 也只有 1~6。
**原因**：麦克风没真正接好/接错孔/线路输入没信号——不是软件问题。
**排查**（实时电平表，对着话筒说话看 RMS 是否跳到几百）：
```bash
while :; do
  arecord -D plughw:1,0 -f S16_LE -r 8000 -c 1 -d 1 /tmp/m.wav 2>/dev/null
  python3 -c "import wave,struct,math;w=wave.open(open('/tmp/m.wav','rb'));n=w.getnframes();s=struct.unpack('<%dh'%n,w.readframes(n));print('RMS=%.0f 峰值=%d'%(math.sqrt(sum(v*v for v in s)/n),max(abs(v) for v in s)))"
done
```
说话时 RMS 从个位数跳到几百~上千 = 麦克风正常；一直个位数 = 接触/接线问题。

### Q5. 信号过载/削顶导致解不出

**现象**：增益拉满后判决异常、峰值顶到 32767。
**原因**：扬声器音量 + 麦克风增益都拉满 → 削顶失真。
**解决**：适当降低宿主机播放音量与板上采集增益（`amixer -c <card> sset <控件> <百分比> cap`，
控件名因设备而异，如某 USB 卡是 `Line Capture Volume`），让峰值在几千~一万、不顶满。

> 补充：模型里"左右声道求和转 single"那一步的输出是 `int16`。它原先**没开饱和**，
> 单声道采集时左右填同一路 ⇒ 求和等于 `2x`，峰值一过 16383 就**按位回绕、符号翻转**
> （比削顶更恶劣的失真）。现已在两个模型的 `Matrix Sum` 上勾选
> *Saturate on integer overflow*，超限时钳到 ±32767。实测在无噪声文件直喂下，
> 回绕与饱和两版在满量程输入时 **BER 都是 0**（匹配滤波/带通把失真产物滤掉了），
> 所以这条改动是**防御性的**——真实声学信道有噪声时才会体现出余量差别。

### Q6. 大图声学采集解不出（小图却没问题）

**原因**：信号太长、采集时长 `-t` 不够，帧尾还没采到就停了。
**解决**：`host/bok_emit.py` 会**打印建议的 `-t` 秒数**，按它给足（如兰州大学 2048 位
信号 ~210s，要 `-t 217` 以上）。

---

## 二、跨平台 / 编译

### Q7. 模型 Device Type 是 ARM aarch64，为什么生成的 C 在 x86 宿主机也能编译运行？

Device Type **只描述目标平台的数据模型**（整数/指针字长、字节序、char 符号性），
代码生成器据此选 typedef、做定点/溢出推理，产出的是**可移植 ISO C**，不含任何架构汇编。
真正决定机器码的是你调用的编译器（宿主 `gcc`→x86-64、板上 `gcc`→aarch64）。
能两边通吃，是因为 **x86-64 Linux 与 aarch64 Linux 数据模型相同**（都是 LP64、小端），
所以按 aarch64 写下的假设在 x86-64 上也成立。只有当目标数据模型与编译平台不一致、
且代码对宽度/字节序敏感时才会出问题——本工程用固定宽度类型，两边都安全。

### Q8. 交叉编译 / 一键上板需要在宿主机装什么？

- **交叉编译**（在 x86 上为 ARM 板编译）：`make CC=aarch64-linux-gnu-gcc`，目标板需有对应 `libasound`。
- **部署到板上**：宿主机只负责"传文件 + 触发板上编译"，**真正编译在板上跑**，
  宿主机**不需要 C 编译器、也不是非得 GNU make**。最省事是用板子自己 `git pull` +
  `ssh "make && run"`（Windows 10/11 自带 `ssh`，零安装）。
- **手动流程是教学正路，也是本文档的主线**：第 2 节传代码、第 3/4 节板上 `make`
  与声学实测，每条命令（`tar`/`ssh`/`scp`/`arecord`/`make`）都是要学的 Linux 过程。
  **首次学习请按 [手把手教程](手把手部署运行教程.md) 手动走一遍。**
- **理解之后，图形界面** `host/gui.m`（两个实验各一个）**可以把这套流程一键化**：
  ① 自检（连上板子 + `arecord -l` 枚举采集设备 + 报板上源码/可执行现状）
  → ② 同步源码到板上并编译（打包传 Makefile/.c/.h 过去 + ssh 触发板上 `make`，
  真正的编译仍在板子上用板子自己的 gcc 做）
  → ③ 电平校准 → ④ 一键声学实测（板上启动采集 + 本机放音 + 取回 + 解码）。
  这些步骤要反复跑很多遍，手动做时还要盯着板子输出、卡着秒表切到 MATLAB 放音，
  容易失手——界面解决的是重复劳动，不是替你理解流程。

### Q9. 用 `gui.m` 实测，判决流/录音全是 0

**现象**：界面提示"板上采到的数据全为 0——麦克风没收到任何信号"。
**原因（实测踩过）**：宿主机接着**蓝牙耳机**（AirPods 等），系统默认输出被耳机抢走，
`sound()`/`audioplayer` 的声音全进了耳机，**根本没从扬声器发出去**，板上麦克风自然
一无所获。手动跑 `bok_emit` 时同样会中招，而且现象更迷惑——脚本一切正常、就是解不出。
**解决**：界面里有「输出设备」下拉，默认已优先选内置扬声器，并用 `audioplayer` 的
device ID **显式指定**，不依赖系统默认输出；选到名字像耳机的设备时会给出告警。
手动跑脚本时，则要自己先确认系统输出切回扬声器。

> **还有个更隐蔽的变种**（实测踩过）：`audioplayer` 的 device ID 确实能把声音送到指定
> 设备，但**音量是按设备分别记忆的**——系统音量滑块只作用于"当前默认输出"。于是会出现：
> 默认输出是蓝牙耳机、系统音量显示 70%，而界面选的内置扬声器仍停在很低的旧音量，
> 结果**声音确实从扬声器出来了、人耳也听得见，但弱到板上麦克风收不到**，判决流照样全 0。
> 排查时先点「③ 电平校准」看 RMS——这正是它存在的意义；确认偏低就把系统输出临时切到
> 扬声器再调音量，或干脆断开耳机。

### Q10. 板子上 `make` 报找不到 `asoundlib.h` / `-lasound`

**原因**：没装 ALSA 开发库。
**解决**：Debian/Ubuntu/树莓派/香橙派/Jetson `sudo apt install libasound2-dev`；
Fedora `sudo dnf install alsa-lib-devel`。（运行时只需 `libasound2`，编译才需 `-dev`。）

---

## 三、MATLAB / 模型生成

### Q11. `slbuild` 报 `Toolchain 'GNU GCC Embedded Linux' is not registered`

**现象**（macOS / Windows 宿主上重新生成代码时）
```
BUILD-ERR: Toolchain 'GNU GCC Embedded Linux' is not registered.
It must be in the Toolchain registry in order to be valid.
```
**原因**：`.slx` 里存着的 `Toolchain` 是原树莓派支持包留下的 **`GNU GCC Embedded Linux`**，
这个 toolchain 只在装了对应支持包的 Linux 宿主上注册。关键在于——**即使
`GenCodeOnly='on'`，`slbuild` 也会先校验 toolchain 再决定生成什么**，所以"我只生成代码
不编译，应该不需要编译器"这个直觉在这里不成立；改 `GenerateMakefile='off'` 同样挡不住。

**解决**：把 toolchain 换成自动定位（本仓库入库的 `.slx` 已经改好，这条留作说明）：
```matlab
set_param(mdl,'Toolchain','Automatically locate an installed toolchain');
```
之后 `slbuild` 会正常生成代码，只是额外打印一条
`Unable to detect supported compiler` 的**警告**——**可以无视**：`GenCodeOnly` 下
MATLAB 本来就不调用编译器，本工程的 C 代码是拿到板上用板子自己的 `gcc` 编的，
**宿主机根本不需要装任何 C 编译器**（macOS 上不需要完整 Xcode，Windows 上不需要 MSVC）。

> 实测：R2025b + macOS(仅 Command Line Tools)，`single_fre_rev` 9 s、
> `chirp_rev_detect` 27 s 生成完成，产物与入库代码一致。

### Q12. `To File` 块的坑：为什么改成 Outport + 自写 mat_sink？

在 `ert.tlc` 下：`MatFileLogging=off` 时 `To File` 会被**块归约删掉**，整个 `step()`
变空；`MatFileLogging=on` 又会拉入 `rt_logging.c`（牵 `matrix.h` 等 MEX 头，板上无法编译）。
**解决**：把 `To File` 换成 **Outport**，输出在模型外由板级 `mat_sink.c`（手写 MAT-v4 写入器）落盘。

### Q13. `matlab -batch` 跑完留下僵尸进程 / 卡住

**现象**：`-batch` 退出时 ServiceHost 常卡住，留下后台 shell。
**解决**：批处理结束后 `pkill -9 -f "MATLAB.*-batch"` 清理。建议批处理脚本里把日志
写文件、用后台跑，跑完显式清进程。

### Q14. 高版本 MATLAB 的模型，能在低版本（如原工程 R2022a）打开吗？

**低→高安全**（向前兼容）；**高→低有风险**：用 `Simulink.exportToVersion` 导出到低版本
可能丢信息、尤其 **Stateflow**（实验二有 15 个）。本工程统一用较高版本 MATLAB，不回退。

### Q15. 改了模型怎么重新生成代码？

见各实验文档"重新生成模型"，**脚本（`slbuild`）和 Simulink 界面（APPS→Embedded Coder→
`Ctrl+B`）两种方式产物一致**，按习惯选。关键配置一样：`ert.tlc` + `HardwareBoard=None`
+ `GenCodeOnly=on` + `MatFileLogging=off` + `Device Type=ARM Cortex-A (64-bit)`
+ `Toolchain=Automatically locate an installed toolchain`（少这一条会报错，见 [Q11](#q11-slbuild-报-toolchain-gnu-gcc-embedded-linux-is-not-registered)），
生成到 `simulink_model/*_ert_rtw/`，再 `make`。若 Inport/Outport 改了名，同步改
`src/model_glue.c` 一处。

### Q16. MATLAB 脚本中文注释乱码

**原因**：原工程脚本是 GBK/UTF-8 混编。**解决**：已统一转 UTF-8（R2025b 默认 UTF-8）。
新增/改写脚本一律存 UTF-8。

---

## 四、跨板排错方法论（重要）

### Q17. 实采解不出码，怎么判断是"算法错"还是"采集错"？

**分层隔离**，逐步缩小范围：

1. **文件直喂**（`make AUDIO=file` + 干净的 `chirp_tx.raw`）→ 若 BER=0，**DSP/模型正确**，
   排除算法/编译器问题。
2. **录音喂文件路径**：`arecord -c1` 把声学信号录成单声道文件，再喂文件路径解码 →
   若 BER=0，**声学信号本身是好的**，问题出在**实采的 ALSA 代码路径**（如声道/交织）。
3. 再针对实采路径排查（声道数、设备、增益）。

Q3 的香橙派双声道 bug 就是这么定位出来的。**先验 DSP、再验声学信号、最后才怀疑实采路径**。

---

## 附：被移除/废弃的东西（别再找了）

- **`:6666` TCP 文件服务器 + `client.m`**：原工程用来从板子取文件，已删除——
  现在直接用 `scp`/FileZilla（一条命令的事，且 `client.m` 用的 `tcpip()` 已被新版 MATLAB 弃用）。
- **生成代码里的 xcp / Pyserver 残留**：原是 External Mode 的，本工程数据通路不用它，已不参与。
