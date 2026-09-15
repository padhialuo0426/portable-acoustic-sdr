/*
 * audio_io_file.c ── audio_io.h 的“文件输入”实现（构建时 -DAUDIO_FILE）。
 * 从一个 raw 单声道 int16 文件按帧读取，复制成交织立体声输出，用于离线、
 * 无声学噪声地验证 DSP/解码链路。文件路径由 audio_capture_open 的 device 参数给出
 * （即命令行 -d <文件>）。读到文件尾返回 0（让主循环正常结束）。
 */
#include "audio_io.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct audio_dev {
    FILE    *fp;
    unsigned channels;
};

audio_dev_t *audio_capture_open(const char *device, unsigned sample_rate,
                                unsigned channels, unsigned frames)
{
    (void)sample_rate; (void)frames;
    if (!device) { fprintf(stderr, "audio_io_file: 需用 -d 指定 raw 文件\n"); return NULL; }
    audio_dev_t *d = calloc(1, sizeof(*d));
    if (!d) return NULL;
    d->fp = fopen(device, "rb");
    if (!d->fp) { fprintf(stderr, "audio_io_file: 打不开 %s\n", device); free(d); return NULL; }
    d->channels = channels;
    return d;
}

audio_dev_t *audio_playback_open(const char *device, unsigned sample_rate,
                                 unsigned channels, unsigned frames)
{
    (void)device; (void)sample_rate; (void)channels; (void)frames;
    return NULL;
}

int audio_capture_read(audio_dev_t *d, int16_t *buf, unsigned frames)
{
    if (!d || !d->fp) return -1;
    for (unsigned i = 0; i < frames; ++i) {
        int16_t mono;
        if (fread(&mono, sizeof(int16_t), 1, d->fp) != 1) {
            /* EOF：把本帧剩余部分补零，避免上一帧残留数据被当成有效样本
               喂进模型（主循环把任何 n>0 都当满帧处理）。 */
            memset(&buf[i * d->channels], 0,
                   (frames - i) * d->channels * sizeof(int16_t));
            return (int)i;                 /* 返回已读帧数(可能 0 -> 主循环结束) */
        }
        for (unsigned c = 0; c < d->channels; ++c)
            buf[i * d->channels + c] = mono; /* 单声道复制到各声道 */
    }
    return (int)frames;
}

int audio_playback_write(audio_dev_t *d, const int16_t *buf, unsigned frames)
{
    (void)d; (void)buf; return (int)frames;
}

void audio_close(audio_dev_t *d)
{
    if (!d) return;
    if (d->fp) fclose(d->fp);
    free(d);
}
