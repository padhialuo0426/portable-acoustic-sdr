/*
 * audio_io.h ── 跨平台 POSIX/ALSA 音频输入输出接口
 *
 * 用标准 ALSA (libasound) 重写，取代树莓派支持包里的 MW_alsa_audio.c /
 * MW_AudioRead。ALSA 是 Linux 通用音频 API，在树莓派、Jetson、香橙派上
 * 都可用——区别只是声卡设备名（如 "hw:2,0" / "plughw:1,0" / "default"），
 * 因此设备名做成可配置参数即可跨平台。
 *
 * 数据格式固定为：S16_LE（16-bit 有符号小端），采样率与通道数可配。
 */
#ifndef AUDIO_IO_H_
#define AUDIO_IO_H_

#include <stdint.h>
#include <stddef.h>

typedef struct audio_dev audio_dev_t;  /* 不透明句柄 */

/*
 * 打开采集设备。
 *   device      : ALSA 设备名，如 "plughw:2,0"、"default"。NULL -> "default"
 *   sample_rate : 采样率 Hz（如 8000）
 *   channels    : 通道数（如 2）
 *   frames      : 每次读取的帧数（一帧 = channels 个采样点，如 80）
 * 返回句柄，失败返回 NULL（并向 stderr 打印原因）。
 */
audio_dev_t *audio_capture_open(const char *device, unsigned sample_rate,
                                unsigned channels, unsigned frames);

/*
 * 打开播放设备（用于发射端 / 回放）。参数同上。
 */
audio_dev_t *audio_playback_open(const char *device, unsigned sample_rate,
                                 unsigned channels, unsigned frames);

/*
 * 读取一帧。buf 长度须 >= frames*channels（交织 L R L R ... 排布）。
 * 阻塞直到读满；遇到 xrun(overrun) 会自动恢复。
 * 返回实际读取帧数(>0)，<=0 表示出错。
 */
int audio_capture_read(audio_dev_t *d, int16_t *buf, unsigned frames);

/*
 * 写入一帧（交织排布）。遇到 xrun(underrun) 自动恢复。
 * 返回实际写入帧数(>0)，<=0 表示出错。
 */
int audio_playback_write(audio_dev_t *d, const int16_t *buf, unsigned frames);

/* 关闭并释放。允许传入 NULL。 */
void audio_close(audio_dev_t *d);

#endif /* AUDIO_IO_H_ */
