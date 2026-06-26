/*
 * model_iface.h ── 实验二(chirp扩频) 板级运行时 <-> Simulink 生成代码 契约
 *
 * 与实验一不同点：chirp 模型是【多速率】的——
 *   step0 @ 8000Hz：逐样本处理（chirp 匹配滤波/相关）
 *   step1 @ 10Hz  ：每 800 样本一帧，读 AudioIn、出 out_data
 * 二者通过 Data Store/速率转换缓冲交互。本契约把「跑一个 10Hz 超帧」
 * 封装成 model_step_frame()（内部 = step1 + 800×step0）。
 *
 * 模型改造：ALSA Audio Capture → Inport AudioIn(int16[1600], [L0..799,R0..799])；
 *           仅保留 toFileData5 → Outport out_data(标量)，其余 To File 删除。
 */
#ifndef MODEL_IFACE_H_
#define MODEL_IFACE_H_

#include <stdint.h>

#define MODEL_SAMPLE_RATE_HZ  8000   /* 音频采样率 = step0 速率 */
#define MODEL_FRAME_SAMPLES   800    /* 每个 10Hz 帧的样本数 */
#define MODEL_NUM_CHANNELS    2
#define MODEL_FRAME_RATE_HZ   (MODEL_SAMPLE_RATE_HZ / MODEL_FRAME_SAMPLES) /* 10 */
#define MODEL_IN_LEN          (MODEL_FRAME_SAMPLES * MODEL_NUM_CHANNELS)   /* 1600 */

#ifdef __cplusplus
extern "C" {
#endif

void model_init(void);
void model_term(void);

/* 跑一个 10Hz 超帧：step1() 一次 + step0() 共 MODEL_FRAME_SAMPLES 次 */
void model_step_frame(void);

/* 输入缓冲指针：写入一帧去交织 int16，长度 MODEL_IN_LEN */
int16_t *model_input(void);

/* 标量输出 out_data（即原 toFileData5 的每帧判决值） */
double model_output(void);

/* 模型是否请求停止 */
int model_stop_requested(void);

#ifdef __cplusplus
}
#endif

#endif /* MODEL_IFACE_H_ */
