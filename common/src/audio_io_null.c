/*
 * audio_io_null.c ── audio_io.h 的“无硬件”实现，用于在没有 ALSA / 声卡
 * 的开发机上联调（构建时用 -DAUDIO_NULL 选择本文件取代 audio_io.c）。
 *
 * 采集：合成一个 1000 Hz 正弦（对应实验里 fc=1000 的单频信号），按真实
 *       采样率节流，方便观察整条管线。播放：丢弃。
 */
#include "audio_io.h"

#include <stdlib.h>
#include <math.h>
#include <time.h>

struct audio_dev {
    unsigned sample_rate;
    unsigned channels;
    double   phase;       /* 正弦相位累积 */
};

static audio_dev_t *mk(unsigned sr, unsigned ch)
{
    audio_dev_t *d = calloc(1, sizeof(*d));
    if (d) { d->sample_rate = sr; d->channels = ch; }
    return d;
}

audio_dev_t *audio_capture_open(const char *device, unsigned sample_rate,
                                unsigned channels, unsigned frames)
{
    (void)device; (void)frames;
    return mk(sample_rate, channels);
}

audio_dev_t *audio_playback_open(const char *device, unsigned sample_rate,
                                 unsigned channels, unsigned frames)
{
    (void)device; (void)frames;
    return mk(sample_rate, channels);
}

int audio_capture_read(audio_dev_t *d, int16_t *buf, unsigned frames)
{
    if (!d) return -1;
    const double f = 1000.0;                 /* 单频信号频率 */
    const double w = 2.0 * M_PI * f / d->sample_rate;
    for (unsigned i = 0; i < frames; ++i) {
        int16_t s = (int16_t)(8000.0 * sin(d->phase));
        d->phase += w;
        for (unsigned c = 0; c < d->channels; ++c)
            buf[i * d->channels + c] = s;     /* 交织写入各声道 */
    }
    if (d->phase > 2.0 * M_PI) d->phase -= 2.0 * M_PI;

    /* 按真实采样率节流，模拟阻塞采集的节拍 */
    struct timespec ts = {0, (long)(1e9 * frames / d->sample_rate)};
    nanosleep(&ts, NULL);
    return (int)frames;
}

int audio_playback_write(audio_dev_t *d, const int16_t *buf, unsigned frames)
{
    (void)buf;
    return d ? (int)frames : -1;             /* 丢弃 */
}

void audio_close(audio_dev_t *d) { free(d); }
