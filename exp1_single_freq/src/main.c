/*
 * main.c ── 可移植软件无线电接收端运行时（脱离 MathWorks 支持包）
 *
 * 取代支持包生成的 ert_main.c + MW_raspi_init + MW_Pyserver + XCP/ExtMode。
 * 职责：
 *   1. 用 POSIX/ALSA 采集音频（audio_io）
 *   2. 去交织后喂给 Simulink 生成的模型 step（model_iface / model_glue）
 *   3. 处理停止信号，优雅退出
 *
 * 时序：ALSA 阻塞式 readi(80帧) 天然把循环卡在 8000/80 = 100 Hz，
 * 即模型的基采样率，无需额外 POSIX 定时器。若将来改用非阻塞采集，
 * 再引入 clock_nanosleep 定时即可。
 *
 * 输出：mat_sink.c（纯 stdio）把 .mat 写到本地盘，格式与原 To File 一致。
 * 取文件用标准 scp/FileZilla 即可，不需要原工程那套 :6666 TCP 文件服务器。
 */
#include "audio_io.h"
#include "model_iface.h"
#include "mat_sink.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <getopt.h>

static volatile sig_atomic_t g_stop = 0;
static void on_signal(int sig) { (void)sig; g_stop = 1; }

static void usage(const char *prog)
{
    fprintf(stderr,
        "用法: %s [选项]\n"
        "  -d <设备>   ALSA 采集设备 (默认 \"default\"，本机麦克风用 plughw:1,0)\n"
        "  -t <秒>     采集指定秒数后自动停止 (如 -t 5)；不给则一直跑到 Ctrl-C\n"
        "  -r <文件>   额外把未滤波的原始麦克风信号存为 .mat (变量 rawAudio)\n"
        "  -p          同时把每帧结果回放到默认播放设备\n"
        "  -h          显示帮助\n"
        "\n各开发板采集设备名示例：\n"
        "  树莓派 USB 声卡:  plughw:2,0     Jetson:  plughw:1,0     香橙派:  plughw:0,0\n"
        "  （用 `arecord -l` 查看实际声卡/设备号）\n",
        prog);
}

int main(int argc, char **argv)
{
    const char *cap_dev = "default";
    const char *raw_path = NULL;     /* -r: 额外存原始麦克风信号 */
    double dur_sec = 0.0;            /* -t: >0 则到时自动停止 */
    int do_playback = 0;
    int opt;

    while ((opt = getopt(argc, argv, "d:t:r:ph")) != -1) {
        switch (opt) {
        case 'd': cap_dev   = optarg;        break;
        case 't': dur_sec   = atof(optarg);  break;
        case 'r': raw_path  = optarg;        break;
        case 'p': do_playback = 1;           break;
        case 'h': usage(argv[0]);   return 0;
        default:  usage(argv[0]);   return 1;
        }
    }
    /* 采集满 dur_sec 秒所需帧数（基采样率 100Hz） */
    unsigned long max_ticks = (dur_sec > 0.0)
        ? (unsigned long)(dur_sec * MODEL_STEP_RATE_HZ) : 0;

    /* Ctrl-C / kill 时置位停止标志 */
    struct sigaction sa = {0};
    sa.sa_handler = on_signal;
    sigaction(SIGINT,  &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    /* 打开采集设备 */
    audio_dev_t *cap = audio_capture_open(cap_dev, MODEL_SAMPLE_RATE_HZ,
                                          MODEL_NUM_CHANNELS, MODEL_FRAME_SAMPLES);
    if (!cap) {
        fprintf(stderr, "致命错误：无法打开采集设备 '%s'\n", cap_dev);
        return 1;
    }

    /* 可选播放设备 */
    audio_dev_t *play = NULL;
    if (do_playback) {
        play = audio_playback_open("default", MODEL_SAMPLE_RATE_HZ,
                                   1 /*单声道*/, MODEL_FRAME_SAMPLES);
    }

    /* 两路输出落盘为 .mat（与原 To File 兼容：变量名 toFileData，81×N）*/
    const int NROWS = 1 + MODEL_OUT_LEN;              /* 时间 + 80 样本 */
    mat_sink_t *sink[MODEL_NUM_OUTPUTS] = {0};
    const char *mat_path[MODEL_NUM_OUTPUTS] = {"single_f.mat",  "single_f2.mat"};
    const char *mat_var [MODEL_NUM_OUTPUTS] = {"toFileData",    "toFileData2"};
    for (int j = 0; j < MODEL_NUM_OUTPUTS; ++j)
        sink[j] = mat_sink_open(mat_path[j], mat_var[j], NROWS);

    /* 可选：原始麦克风信号（左右合一，未经滤波），变量 rawAudio (80×N) */
    mat_sink_t *raw_sink = raw_path ? mat_sink_open(raw_path, "rawAudio",
                                                    MODEL_OUT_LEN) : NULL;

    model_init();
    if (max_ticks)
        fprintf(stderr, "运行中：采集=%s  %dHz  %d声道  采集 %.1f 秒后自动停止\n",
                cap_dev, MODEL_SAMPLE_RATE_HZ, MODEL_NUM_CHANNELS, dur_sec);
    else
        fprintf(stderr, "运行中：采集=%s  %dHz  %d声道  按 Ctrl-C 停止\n",
                cap_dev, MODEL_SAMPLE_RATE_HZ, MODEL_NUM_CHANNELS);
    fprintf(stderr, "输出: %s, %s%s%s\n", mat_path[0], mat_path[1],
            raw_path ? ", 原始=" : "", raw_path ? raw_path : "");

    /* 交织采集缓冲：frames * channels 个 int16 */
    int16_t inter[MODEL_FRAME_SAMPLES * MODEL_NUM_CHANNELS];
    int16_t play_buf[MODEL_FRAME_SAMPLES];
    double  col[1 + MODEL_OUT_LEN];                   /* [时间; 样本...] 一列 */
    double  raw_col[MODEL_OUT_LEN];                   /* 原始单声道一帧 */
    unsigned long tick = 0;

    while (!g_stop && !model_stop_requested()) {
        if (max_ticks && tick >= max_ticks) break;    /* -t 到时停止 */
        int n = audio_capture_read(cap, inter, MODEL_FRAME_SAMPLES);
        if (n <= 0) break;

        /* 去交织：交织 L R L R...  ->  [L0..L79, R0..R79]（模型期望布局） */
        int16_t *in = model_input();
        for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i) {
            in[i]                       = inter[2 * i];      /* 左 */
            in[i + MODEL_FRAME_SAMPLES] = inter[2 * i + 1];  /* 右 */
        }

        /* 原始麦克风信号（左右合一，未滤波）落盘 */
        if (raw_sink) {
            for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i)
                raw_col[i] = (double)(in[i] + in[i + MODEL_FRAME_SAMPLES]);
            mat_sink_write_col(raw_sink, raw_col);
        }

        model_step();

        double t = (double)tick / MODEL_STEP_RATE_HZ;   /* 时间戳 */
        for (int j = 0; j < MODEL_NUM_OUTPUTS; ++j) {
            const double *out = model_output(j);
            if (!sink[j] || !out) continue;
            col[0] = t;
            memcpy(&col[1], out, MODEL_OUT_LEN * sizeof(double));
            mat_sink_write_col(sink[j], col);
        }

        /* 可选：把第 0 路输出回放出来 */
        if (play) {
            const double *out = model_output(0);
            if (out) {
                for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i) {
                    double v = out[i];
                    if (v >  32767.0) v =  32767.0;
                    if (v < -32768.0) v = -32768.0;
                    play_buf[i] = (int16_t)v;
                }
                audio_playback_write(play, play_buf, MODEL_FRAME_SAMPLES);
            }
        }
        tick++;
    }

    fprintf(stderr, "正在停止... 共 %lu 帧 (%.2f 秒)\n",
            tick, (double)tick / MODEL_STEP_RATE_HZ);
    model_term();
    for (int j = 0; j < MODEL_NUM_OUTPUTS; ++j) mat_sink_close(sink[j]);
    mat_sink_close(raw_sink);
    audio_close(play);
    audio_close(cap);
    return 0;
}
