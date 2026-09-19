/*
 * main.c ── 实验四(V.22bis 声学 modem) 可移植接收端运行时（脱离支持包）
 *
 * 流程：ALSA 采集 960 样本/帧(10Hz) → 合并声道喂模型 → model_step_frame()
 *       → 取 120 个 double(60 个符号的 I,Q) → 写 v22sym.mat(v22Sym)。
 * PC 端 v22_decode.m 读 v22sym.mat 做判决/差分/解扰/HDLC/还原图片。
 *
 * 时序：ALSA 阻塞读 960 帧@9600Hz 天然 100ms = 10Hz 实时节拍。
 *
 * 与前三个实验的不同：采样率是 9600 不是 8000（V.22bis 600 baud，
 * 9600/600=16 整除），且喂给模型的是单声道——声道合并在这里做完，
 * 模型只管单路基带处理。
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
        "  -d <设备>   ALSA 采集设备 (默认 \"default\"；用 arecord -l 查)\n"
        "  -t <秒>     采集指定秒数后自动停止；不给则跑到 Ctrl-C\n"
        "  -c <声道>   采集声道数 1=单声道(默认,最稳) 2=立体声取均值\n"
        "  -b <速率>   1200=QPSK，2400=16-QAM（默认）；须与发送端一致\n"
        "  -r <文件>   额外把原始麦克风信号存为 .mat (变量 rawAudio)\n"
        "  -h          显示帮助\n"
        "输出: v22sym.mat (变量 v22Sym, 121×N: 第1行时间, 其余 120 行为\n"
        "      60 个符号的 I,Q 交替)\n"
        "注意: 本实验采样率是 %d Hz(不是其它实验的 8000)，因为 V.22bis 是\n"
        "      600 baud，%d/600=16 正好整除。用 plughw: 让 ALSA 做重采样。\n",
        prog, MODEL_SAMPLE_RATE_HZ, MODEL_SAMPLE_RATE_HZ);
}

int main(int argc, char **argv)
{
    const char *cap_dev  = "default";
    const char *raw_path = NULL;
    double dur_sec = 0.0;
    int cap_ch = 1;
    int rate = 2400;
    int opt;

    while ((opt = getopt(argc, argv, "d:t:c:r:b:h")) != -1) {
        switch (opt) {
        case 'd': cap_dev  = optarg;       break;
        case 't': dur_sec  = atof(optarg); break;
        case 'c': cap_ch   = atoi(optarg); break;
        case 'r': raw_path = optarg;       break;
        case 'b':
            if (strcmp(optarg, "1200") && strcmp(optarg, "2400")) {
                fprintf(stderr, "错误：-b 只能是 1200 或 2400\n");
                return 1;
            }
            rate = atoi(optarg);
            break;
        case 'h': usage(argv[0]); return 0;
        default:  usage(argv[0]); return 1;
        }
    }
    if (cap_ch != 1 && cap_ch != 2) {
        fprintf(stderr, "错误：-c 只能是 1 或 2\n");
        return 1;
    }
    unsigned long max_frames = (dur_sec > 0.0)
        ? (unsigned long)(dur_sec * MODEL_FRAME_RATE_HZ) : 0;

    struct sigaction sa = {0};
    sa.sa_handler = on_signal;
    sigaction(SIGINT,  &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    audio_dev_t *cap = audio_capture_open(cap_dev, MODEL_SAMPLE_RATE_HZ,
                                          cap_ch, MODEL_FRAME_SAMPLES);
    if (!cap) {
        fprintf(stderr, "致命错误：无法打开采集设备 '%s'\n", cap_dev);
        return 1;
    }

    /* 输出 v22sym.mat：变量 v22Sym，每帧一列 [时间; 120 个 I/Q] (121×N) */
    const int NROWS = 1 + MODEL_OUT_LEN;
    mat_sink_t *sink = mat_sink_open("v22sym.mat", "v22Sym", NROWS);
    mat_sink_t *raw_sink = raw_path ? mat_sink_open(raw_path, "rawAudio",
                                                    MODEL_FRAME_SAMPLES) : NULL;

    if (!sink || (raw_path && !raw_sink)) {
        mat_sink_close(sink);
        mat_sink_close(raw_sink);
        audio_close(cap);
        return 1;
    }
    int result = 0;
    model_init();
    model_set_rate(rate);
    fprintf(stderr, "接收模式: %d bps (%s)\n", rate, rate == 1200 ? "QPSK" : "16-QAM");
    if (max_frames)
        fprintf(stderr, "运行中：采集=%s %dHz 帧长%d 帧率%dHz  采集 %.1f 秒后停止\n",
                cap_dev, MODEL_SAMPLE_RATE_HZ, MODEL_FRAME_SAMPLES,
                MODEL_FRAME_RATE_HZ, dur_sec);
    else
        fprintf(stderr, "运行中：采集=%s %dHz 帧长%d 帧率%dHz  按 Ctrl-C 停止\n",
                cap_dev, MODEL_SAMPLE_RATE_HZ, MODEL_FRAME_SAMPLES,
                MODEL_FRAME_RATE_HZ);
    fprintf(stderr, "输出: v22sym.mat%s%s\n",
            raw_path ? ", 原始=" : "", raw_path ? raw_path : "");

    int16_t inter[MODEL_FRAME_SAMPLES * 2];
    double  raw_col[MODEL_FRAME_SAMPLES];
    double  col[1 + MODEL_OUT_LEN];
    unsigned long frame = 0;

    while (!g_stop && !model_stop_requested()) {
        if (max_frames && frame >= max_frames) break;
        memset(inter, 0, sizeof inter); /* 防止后端半帧返回时混入旧采样 */
        int n = audio_capture_read(cap, inter, MODEL_FRAME_SAMPLES);
        if (n < 0) {
            if (!g_stop) {
                fprintf(stderr, "采集失败，输出可能不完整\n");
                result = 1;
            }
            break;
        }
        if (n == 0 || g_stop) break;

        /* 合并声道 -> 单路喂模型。立体声时取左右均值（不是求和：模型内部
           按 ±1 归一化的信号处理，求和会平白多 6dB，逼近 int16 上限）。 */
        int16_t *in = model_input();
        for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i) {
            if (cap_ch == 1) {
                in[i] = inter[i];
            } else {
                in[i] = (int16_t)(((int32_t)inter[2*i] + inter[2*i + 1]) / 2);
            }
        }
        if (raw_sink) {
            for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i)
                raw_col[i] = (double)in[i];
            if (mat_sink_write_col(raw_sink, raw_col) < 0) {
                result = 1;
                break;
            }
        }

        model_step_frame();

        col[0] = (double)frame / MODEL_FRAME_RATE_HZ;
        const double *out = model_output();
        for (int j = 0; j < MODEL_OUT_LEN; ++j) col[1 + j] = out[j];
        if (mat_sink_write_col(sink, col) < 0) {
            result = 1;
            break;
        }
        frame++;
    }

    fprintf(stderr, "正在停止... 共 %lu 帧 (%.2f 秒)\n",
            frame, (double)frame / MODEL_FRAME_RATE_HZ);
    if (model_stop_requested()) {
        fprintf(stderr, "模型出错，输出可能不完整\n");
        result = 1;
    }
    model_term();
    if (mat_sink_close(sink) < 0) result = 1;
    if (mat_sink_close(raw_sink) < 0) result = 1;
    audio_close(cap);
    return result;
}
