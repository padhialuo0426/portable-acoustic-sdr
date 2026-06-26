# 实验二 · PC 端 MATLAB 脚本（发射 / 解码 / 仿真 / GUI）

这里是跑在 PC（MATLAB）上的那半条链路。板上的接收端 C 程序在上一级目录
（`../`，`make` 构建出 `chirp_rx`）。

## 完整链路

```
[本目录 Bok_emit.m] 读图→chirp调制→扬声器播放
        │ 声波
        ▼
[麦克风] → [板上 ../build/chirp_rx] → chirp5.mat（每帧判决值 toFileData5）
        │ scp / FileZilla 拷回本目录
        ▼
[本目录 Bok_rev.m] 帧同步→硬判决→算 BER→imshow 还原图像
```

## 文件清单

| 文件 | 作用 | 关键数据 |
|---|---|---|
| `Bok_emit.m` | 发射端（128位 `ren128b.bmp`）→ `sound()` 播放 | 读 `../baseband_images/ren128b.bmp`；写 `info_all.mat` |
| `Bok_rev.m`  | 解码端：读 `chirp5.mat` 还原图像、算 BER | 读 `chirp5.mat` + `info_all.mat` |
| `BOK.m`      | 纯 MATLAB 端到端仿真（512位 `ren512b.bmp`，无硬件） | 读 `../baseband_images/ren512b.bmp` |
| `bokgui.m/.fig` | GUIDE 启动器，按钮调上面各脚本 + 打开模型 | — |
| `setup_paths.m` | 把脚本/图片/模型目录加入 MATLAB 路径 | — |
| `sample_data/`  | 一组真实跑出来的样例 `chirp5.mat`+`info_all.mat`，可直接试解码 | — |

## 路径已重构（不依赖当前工作目录）

原脚本用 `imread('ren128b.bmp')`、`load('chirp5.mat')` 等**裸文件名**，换目录就找不到。
现已全部改为**相对脚本自身定位**（`here = fileparts(mfilename('fullpath'))`）：
- 图片统一从 `../baseband_images/` 读
- `info_all.mat` / `chirp5.mat` 读写脚本所在目录（即本 `host/`）

所以这些脚本放在哪、从哪个目录运行都不会出现路径问题。`bokgui` 用名字调脚本/模型，
需先运行一次 `setup_paths`（把本目录、图片目录、模型目录加入路径）。

> 编码：原工程脚本是 GBK/UTF-8 混合，已统一转为 UTF-8（R2025b 默认 UTF-8，
> 否则中文注释乱码）。

## 快速试解码（无需硬件，用样例数据）

```matlab
copyfile('sample_data/chirp5.mat','chirp5.mat');
copyfile('sample_data/info_all.mat','info_all.mat');
Bok_rev      % 应输出 BER 并 imshow 还原的 128 位图像
```

## 完整声学实测

```matlab
setup_paths
Bok_emit                 % 一台机器扬声器播放 chirp 信号（或在发射端 PC 跑）
```
另一端：`cd ..; ./build/chirp_rx -d default -t <足够秒数>` 采集得 `chirp5.mat`。

## 从板子取回 chirp5.mat（用 scp，不用 :6666）

接收端 `chirp_rx` 把 `chirp5.mat` 写到板上本地盘，标准 `scp`/FileZilla 直接拉走：

```bash
scp pi@<板子IP>:~/.../exp2_chirp/chirp5.mat host/
```

> 原工程那套 `client.m` + 板端 `:6666` TCP 文件服务器已废弃删除——它做的事
> 就是 `scp` 一条命令，却用了自定义协议和已弃用的 `tcpip()` API。`bokgui`
> 的“取文件”按钮现改为提示用 scp / FileZilla。
