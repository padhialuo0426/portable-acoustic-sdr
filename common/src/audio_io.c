/*
 * audio_io.c ── POSIX/ALSA 音频输入输出实现
 *
 * 仅依赖 libasound（-lasound）。在树莓派 / Jetson / 香橙派等任意带 ALSA
 * 的 Linux 上均可编译运行。彻底取代 MathWorks 树莓派支持包的音频驱动。
 */
#include "audio_io.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <alsa/asoundlib.h>

struct audio_dev {
    snd_pcm_t   *pcm;
    unsigned     channels;
    snd_pcm_stream_t stream;  /* CAPTURE 或 PLAYBACK */
};

/* 公共配置流程 */
static audio_dev_t *audio_open(snd_pcm_stream_t stream, const char *device,
                               unsigned sample_rate, unsigned channels,
                               unsigned frames)
{
    const char *dev = device ? device : "default";
    int err;

    audio_dev_t *d = calloc(1, sizeof(*d));
    if (!d) {
        fprintf(stderr, "audio_io: 内存分配失败\n");
        return NULL;
    }
    d->channels = channels;
    d->stream   = stream;

    if ((err = snd_pcm_open(&d->pcm, dev, stream, 0)) < 0) {
        fprintf(stderr, "audio_io: 打开设备 '%s' 失败: %s\n",
                dev, snd_strerror(err));
        free(d);
        return NULL;
    }

    snd_pcm_hw_params_t *hw;
    snd_pcm_hw_params_alloca(&hw);
    snd_pcm_hw_params_any(d->pcm, hw);

    err  = snd_pcm_hw_params_set_access(d->pcm, hw,
                                        SND_PCM_ACCESS_RW_INTERLEAVED);
    err |= snd_pcm_hw_params_set_format(d->pcm, hw, SND_PCM_FORMAT_S16_LE);
    err |= snd_pcm_hw_params_set_channels(d->pcm, hw, channels);

    unsigned rate = sample_rate;
    err |= snd_pcm_hw_params_set_rate_near(d->pcm, hw, &rate, 0);

    /* 周期大小设为一帧的处理量，缓冲取 4 个周期，兼顾延迟与稳定 */
    snd_pcm_uframes_t period = frames;
    snd_pcm_uframes_t bufsz  = frames * 4;
    snd_pcm_hw_params_set_period_size_near(d->pcm, hw, &period, 0);
    snd_pcm_hw_params_set_buffer_size_near(d->pcm, hw, &bufsz);

    if (err < 0 || (err = snd_pcm_hw_params(d->pcm, hw)) < 0) {
        fprintf(stderr, "audio_io: 设置硬件参数失败: %s\n", snd_strerror(err));
        snd_pcm_close(d->pcm);
        free(d);
        return NULL;
    }

    if (rate != sample_rate)
        fprintf(stderr, "audio_io: 警告，实际采样率 %u != 请求 %u\n",
                rate, sample_rate);

    snd_pcm_prepare(d->pcm);
    return d;
}

audio_dev_t *audio_capture_open(const char *device, unsigned sample_rate,
                                unsigned channels, unsigned frames)
{
    return audio_open(SND_PCM_STREAM_CAPTURE, device, sample_rate,
                      channels, frames);
}

audio_dev_t *audio_playback_open(const char *device, unsigned sample_rate,
                                 unsigned channels, unsigned frames)
{
    return audio_open(SND_PCM_STREAM_PLAYBACK, device, sample_rate,
                      channels, frames);
}

int audio_capture_read(audio_dev_t *d, int16_t *buf, unsigned frames)
{
    if (!d) return -1;
    snd_pcm_sframes_t n = snd_pcm_readi(d->pcm, buf, frames);
    if (n < 0) {
        /* overrun 等可恢复错误：复位后重试一次 */
        n = snd_pcm_recover(d->pcm, (int)n, 1);
        if (n == 0)
            n = snd_pcm_readi(d->pcm, buf, frames);
    }
    if (n < 0)
        fprintf(stderr, "audio_io: 采集读取失败: %s\n", snd_strerror((int)n));
    return (int)n;
}

int audio_playback_write(audio_dev_t *d, const int16_t *buf, unsigned frames)
{
    if (!d) return -1;
    snd_pcm_sframes_t n = snd_pcm_writei(d->pcm, buf, frames);
    if (n < 0) {
        n = snd_pcm_recover(d->pcm, (int)n, 1);
        if (n == 0)
            n = snd_pcm_writei(d->pcm, buf, frames);
    }
    if (n < 0)
        fprintf(stderr, "audio_io: 播放写入失败: %s\n", snd_strerror((int)n));
    return (int)n;
}

void audio_close(audio_dev_t *d)
{
    if (!d) return;
    if (d->pcm) {
        snd_pcm_drain(d->pcm);
        snd_pcm_close(d->pcm);
    }
    free(d);
}
