# 常见问题 Q&A

做实验时容易撞上的坑，按「现象 → 原因 → 解决」速查。
详细操作步骤看 [手把手部署运行教程](手把手部署运行教程.md)。

---

## 一、板上采集

### Q1. 打不开采集设备：`capture slave is not defined` / `Invalid argument`

**原因**：没带 `-d` 时默认用 `default` 设备，而板子的 `default` PCM 常只定义了播放、
没定义采集 slave。
**解决**：用 `-d` 显式指定麦克风，**不要用 `default` 采集**。设备名怎么选见 Q2。

### Q2. `-d` 该填什么

```bash
arecord -l                      # 看麦克风是 card 几（device 号通常 0）
./build/chirp_rx -d plughw:2,0 -t 28
```

- 用 `plughw:` 而不是 `hw:`——`plug` 会自动做采样率/声道转换，直接 `hw:` 常因格式不匹配打不开。
- **card 号在 USB 重插或重启后会变**，跑之前 `arecord -l` 现查。
- 采集看 `arecord -l`、播放看 `aplay -l`，两者 card 号可能不同。

### Q3. 判决流恒为 −1、帧同步失败（信号明明很强）

**原因**：某些板子（如香橙派）2 声道交织流里单独取左/右任一路都解不出。
**解决**：接收端**默认就是单声道 `-c 1`**，无需改命令。确需立体声取左声道才用 `-c 2`。

### Q4. 麦克风录到的全是静音（RMS 个位数）

**原因**：麦克风没接好/接错孔——不是软件问题。
**排查**：对着话筒说话，看 RMS 是否跳到几百。

```bash
arecord -D plughw:2,0 -f S16_LE -r 8000 -c 1 -d 1 /tmp/m.wav
python3 -c "import wave,struct,math;w=wave.open(open('/tmp/m.wav','rb'));n=w.getnframes();s=struct.unpack('<%dh'%n,w.readframes(n));print('RMS=%.0f 峰值=%d'%(math.sqrt(sum(v*v for v in s)/n),max(abs(v) for v in s)))"
```

### Q5. 信号过载，峰值顶到 32767 解不出

**原因**：扬声器音量 + 麦克风增益都拉满 → 削顶失真。
**解决**：降低宿主机播放音量或板上采集增益，让峰值落在**几千**量级。

```bash
amixer -c <card> sset <控件> 70% cap      # 控件名因声卡而异，先 amixer -c <card> scontrols 查
```

### Q6. 大图解不出，小图却正常

**原因**：采集时长 `-t` 不够，帧尾还没采到就停了。
**解决**：`host/bok_emit.py` 会打印建议的 `-t` 秒数，按它给足（2048 位的图约需 `-t 217`）。

---

## 二、宿主机放音

### Q7. 判决流 / 录音全是 0

**原因**：声音没从扬声器发出去。两种情形：

1. 宿主机接着蓝牙耳机，系统默认输出被耳机抢走；
2. 更隐蔽——**音量是按设备分别记忆的**，系统音量滑块只作用于"当前默认输出"。
   于是默认输出是耳机、系统音量 70%，而扬声器仍停在很低的旧音量：
   **声音确实出来了、人耳也听得见，但弱到板上麦克风收不到**。

**解决**：`gui.m` 里选好「输出设备」（默认优先内置扬声器），然后点「③ 电平校准」看
RMS——它就是用来定位这类问题的。偏低就把系统输出临时切到该设备再调音量，或断开耳机。
手动跑 `bok_emit` 时没有这层保护，要自己确认系统输出在扬声器上。

---

## 三、编译与部署

### Q8. 板上 `make` 报找不到 `asoundlib.h` / `-lasound`

**原因**：没装 ALSA 开发库（运行时只需 `libasound2`，编译才需 `-dev`）。
**解决**：`sudo apt install libasound2-dev`；Fedora 系 `sudo dnf install alsa-lib-devel`。

### Q9. 宿主机需要装什么？能不能一键部署？

- **宿主机不需要 C 编译器**——编译在板上跑，用板子自己的 `gcc`。
- **手动流程是教学正路**：传代码、板上 `make`、声学实测，每条命令都是要学的 Linux 过程。
  **首次学习请按[教程](手把手部署运行教程.md)手动走一遍。**
- 理解之后，`host/gui.m` 可以把这套流程一键化：① 自检 → ② 同步源码到板上并编译
  → ③ 电平校准 → ④ 一键声学实测。它用 MATLAB 自带的 JSch，填 IP + 用户名 + 密码即可，
  三个平台一致、不需要配密钥。注意它**不读 `~/.ssh/config`**，主机栏要填真实 IP。

---

## 四、MATLAB / 代码生成

### Q10. `slbuild` 报 `Toolchain 'GNU GCC Embedded Linux' is not registered`

**原因**：`.slx` 里存的 toolchain 是原树莓派支持包留下的，只在装了该支持包的 Linux 上注册。
**即使 `GenCodeOnly='on'` 也绕不过**——`slbuild` 会先校验 toolchain 再决定生成什么。

**解决**（本仓库入库的 `.slx` 已改好，这条留作说明）：

```matlab
set_param(mdl,'Toolchain','Automatically locate an installed toolchain');
```

之后会多打印一条 `Unable to detect supported compiler` 警告，**可以无视**：`GenCodeOnly`
下 MATLAB 本来就不调编译器，宿主机不需要装任何 C 编译器。

### Q11. 改了模型怎么重新生成代码？

脚本（`slbuild`）和界面（APPS → Embedded Coder → `Ctrl+B`）产物一致。关键配置：
`ert.tlc` + `HardwareBoard=None` + `GenCodeOnly=on` + `MatFileLogging=off`
+ `Device Type=ARM Cortex-A (64-bit)` + `Toolchain=Automatically locate an installed toolchain`
（**少最后一条会报错，见 Q10**）。生成到 `simulink_model/*_ert_rtw/`，再 `make`。
若 Inport/Outport 改了名，同步改 `src/model_glue.c` 一处。详见各实验文档。

### Q12. 模型里为什么不能用 `To File`？`MatFileLogging` 为什么必须关？

`ert.tlc` 下这两件事互相矛盾：`MatFileLogging=off` 时 `To File` 会被块归约删掉、
`step()` 变空；`MatFileLogging=on` 又会拉入 `rt_logging.c`（牵 MEX 头，板上编不了）。
所以模型用 **Outport** 输出，落盘交给板级手写的 `mat_sink.c`。

### Q13. 高版本 MATLAB 的模型能在低版本打开吗？

**低→高安全，高→低有风险**。`Simulink.exportToVersion` 可能丢信息，尤其 Stateflow
（实验二有 15 个）。本工程统一用较高版本，不回退。

### Q14. MATLAB 脚本中文注释乱码

原工程是 GBK/UTF-8 混编，现已统一转 UTF-8。新增脚本一律存 UTF-8。

---

## 五、排错方法

### Q15. 实采解不出码，怎么判断是"算法错"还是"采集错"？

分层隔离，**先验 DSP、再验声学信号、最后才怀疑实采路径**：

1. **文件直喂**：`make AUDIO=file` 喂干净的 `chirp_tx.raw`。BER=0 → 算法和编译没问题。
2. **录音喂文件**：`arecord -c1` 把声学信号录成文件再喂进去。BER=0 → 声学信号本身是好的，
   问题在实采的 ALSA 代码路径（声道/交织）。
3. 到这一步才去查采集参数（声道数、设备名、增益）。

Q3 那个双声道 bug 就是这么定位出来的。
