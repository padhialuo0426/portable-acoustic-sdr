/*
 * main.c ── 实验二(chirp 扩频通信) 可移植接收端运行时（脱离支持包）
 *
 * 流程：ALSA 采集 800 样本/帧(10Hz) → 去交织喂模型 → model_step_frame()
 *       (step1 + 800×step0) → 取标量 out_data → 写 chirp5.mat(toFileData5)。
 * PC 端 bok_rev.m 读 chirp5.mat 的 toFileData5(2,:) 做帧同步/解码/BER/还原图像。
 *
 * 时序：ALSA 阻塞读 800 帧@8000Hz 天然 100ms = 10Hz 实时节拍；每帧内的
 * 800 次 step0 是计算性的，在该 100ms 预算内完成。
 */
#include "audio_io.h"
#include "model_iface.h"
#include "mat_sink.h"

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <getopt.h>

static volatile sig_atomic_t g_stop = 0;
static void on_signal(int sig) { (void)sig; g_stop = 1; }

static void usage(const char *prog)
{
    fprintf(stderr,
        "用法: %s [选项]\n"
        "  -d <设备>   ALSA 采集设备 (默认 \"default\"，树莓派常为 plughw:2,0)\n"
        "  -t <秒>     采集指定秒数后自动停止；不给则跑到 Ctrl-C\n"
        "  -c <声道>   采集声道数 1=单声道(默认,最稳) 2=立体声取左声道\n"
        "  -r <文件>   额外把未滤波原始麦克风信号存为 .mat (变量 rawAudio)\n"
        "  -h          显示帮助\n"
        "输出: chirp5.mat (变量 toFileData5, 2×N: 第1行时间, 第2行判决值)\n"
        "      用 arecord -l 查看实际声卡/设备号\n", prog);
}

int main(int argc, char **argv)
{
    const char *cap_dev = "default";
    const char *raw_path = NULL;
    double dur_sec = 0.0;
    int cap_ch = 1;                 /* 默认单声道：plughw 会把任意设备下混为单声道，
                                       跨板最稳（某些板 2 声道交织布局不一致会解码失败）*/
    int opt;

    while ((opt = getopt(argc, argv, "d:t:c:r:h")) != -1) {
        switch (opt) {
        case 'd': cap_dev  = optarg;       break;
        case 't': dur_sec  = atof(optarg); break;
        case 'c': cap_ch   = atoi(optarg); break;
        case 'r': raw_path = optarg;       break;
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

    /* 输出 chirp5.mat：变量 toFileData5，每帧一列 [时间; 判决值] (2×N) */
    mat_sink_t *sink = mat_sink_open("chirp5.mat", "toFileData5", 2);
    mat_sink_t *raw_sink = raw_path ? mat_sink_open(raw_path, "rawAudio",
                                                    MODEL_FRAME_SAMPLES) : NULL;

    model_init();
    if (max_frames)
        fprintf(stderr, "运行中：采集=%s 8000Hz 帧长800 帧率%dHz  采集 %.1f 秒后停止\n",
                cap_dev, MODEL_FRAME_RATE_HZ, dur_sec);
    else
        fprintf(stderr, "运行中：采集=%s 8000Hz 帧长800 帧率%dHz  按 Ctrl-C 停止\n",
                cap_dev, MODEL_FRAME_RATE_HZ);
    fprintf(stderr, "输出: chirp5.mat%s%s\n",
            raw_path ? ", 原始=" : "", raw_path ? raw_path : "");

    int16_t inter[MODEL_FRAME_SAMPLES * MODEL_NUM_CHANNELS];
    double  raw_col[MODEL_FRAME_SAMPLES];
    double  col[2];
    unsigned long frame = 0;

    while (!g_stop && !model_stop_requested()) {
        if (max_frames && frame >= max_frames) break;
        int n = audio_capture_read(cap, inter, MODEL_FRAME_SAMPLES);
        if (n <= 0) break;

        /* 去交织 -> 模型输入 [L0..799, R0..799]。
           单声道(cap_ch=1)：左右都填该单声道；立体声(cap_ch=2)：取左/右两路 */
        int16_t *in = model_input();
        for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i) {
            in[i]                       = inter[cap_ch * i];
            in[i + MODEL_FRAME_SAMPLES] = inter[cap_ch * i + (cap_ch > 1 ? 1 : 0)];
        }
        if (raw_sink) {
            for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i)
                raw_col[i] = (double)(in[i] + in[i + MODEL_FRAME_SAMPLES]);
            mat_sink_write_col(raw_sink, raw_col);
        }

        model_step_frame();

        col[0] = (double)frame / MODEL_FRAME_RATE_HZ;   /* 时间 */
        col[1] = model_output();                        /* 判决值 */
        if (sink) mat_sink_write_col(sink, col);
        frame++;
    }

    fprintf(stderr, "正在停止... 共 %lu 帧 (%.2f 秒)\n",
            frame, (double)frame / MODEL_FRAME_RATE_HZ);
    model_term();
    mat_sink_close(sink);
    mat_sink_close(raw_sink);
    audio_close(cap);
    return 0;
}
