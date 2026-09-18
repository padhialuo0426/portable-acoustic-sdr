/* 实验五：48 kHz 单声道 PCM → 逐样本音频频率；每次处理 0.1 秒。 */
#ifndef MODEL_IFACE_H_
#define MODEL_IFACE_H_
#include <stdint.h>
#define MODEL_SAMPLE_RATE_HZ 48000
#define MODEL_FRAME_SAMPLES 4800
#define MODEL_OUT_LEN 4800
#define MODEL_IN_LEN MODEL_FRAME_SAMPLES
#define MODEL_FRAME_RATE_HZ 10
void model_init(void);
void model_term(void);
void model_step_frame(void);
int16_t *model_input(void);
const double *model_output(void);
int model_stop_requested(void);
#endif
