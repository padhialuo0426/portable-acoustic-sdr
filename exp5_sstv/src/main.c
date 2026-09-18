/* 实验五：ALSA 采集 → 生成模型鉴频 → MAT-v4 写盘。 */
#include "audio_io.h"
#include "model_iface.h"
#include "mat_sink.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <getopt.h>
#include <errno.h>
#include <limits.h>
#include <math.h>

static volatile sig_atomic_t g_stop = 0;
static void on_signal(int sig) { (void)sig; g_stop = 1; }

static void usage(const char *prog)
{
    fprintf(stderr,
        "用法: %s [-d ALSA设备或PCM文件] [-t 秒] [-c 1或2] [-r 原始MAT文件]\n"
        "采样率 48000 Hz；默认单声道，双声道取均值。不给 -t 则读到结束或中止。\n"
        "输出 sstvfreq.mat，变量 sstvFreq：4801×N，每列为时间和 4800 个频率值。\n"
        "频率值为 Hz；低电平采样标为 0。VIS、行同步及图像还原在 PC 上完成。\n",prog);
}

int main(int argc, char **argv)
{
    const char *cap_dev  = "default";
    const char *raw_path = NULL;
    double dur_sec = 0.0;
    int cap_ch = 1;
    int opt;
    char *end;

    while ((opt = getopt(argc, argv, "d:t:c:r:h")) != -1) {
        switch (opt) {
        case 'd': cap_dev  = optarg;       break;
        case 't':
            errno = 0;
            dur_sec = strtod(optarg, &end);
            if (errno || end == optarg || *end || !isfinite(dur_sec) ||
                dur_sec <= 0 || dur_sec * MODEL_FRAME_RATE_HZ >= (double)ULONG_MAX) {
                fprintf(stderr, "错误：-t 必须是有限的正秒数\n");
                return 1;
            }
            break;
        case 'c':
            if (strcmp(optarg,"1") != 0 && strcmp(optarg,"2") != 0) {
                fprintf(stderr, "错误：-c 只能是 1 或 2\n");
                return 1;
            }
            cap_ch = atoi(optarg);
            break;
        case 'r': raw_path = optarg;       break;
        case 'h': usage(argv[0]); return 0;
        default:  usage(argv[0]); return 1;
        }
    }
    if (optind != argc) {
        usage(argv[0]);
        return 1;
    }
    unsigned long max_frames = (dur_sec > 0.0)
        ? (unsigned long)ceil(dur_sec * MODEL_FRAME_RATE_HZ) : 0;

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

    /* 每帧一列：[时间；4800 个频率值]。 */
    const int NROWS = 1 + MODEL_OUT_LEN;
    mat_sink_t *sink = mat_sink_open("sstvfreq.mat", "sstvFreq", NROWS);
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
    if (max_frames)
        fprintf(stderr, "运行中：采集=%s %dHz 帧长%d 帧率%dHz  采集 %.1f 秒后停止\n",
                cap_dev, MODEL_SAMPLE_RATE_HZ, MODEL_FRAME_SAMPLES,
                MODEL_FRAME_RATE_HZ, dur_sec);
    else
        fprintf(stderr, "运行中：采集=%s %dHz 帧长%d 帧率%dHz  按 Ctrl-C 停止\n",
                cap_dev, MODEL_SAMPLE_RATE_HZ, MODEL_FRAME_SAMPLES,
                MODEL_FRAME_RATE_HZ);
    fprintf(stderr, "输出: sstvfreq.mat%s%s\n",
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
