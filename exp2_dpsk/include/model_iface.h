/*
 * model_iface.h ── 实验二(DPSK) 板级运行时 <-> Simulink 生成代码 的契约
 *
 * 与实验一同为单速率、100Hz 帧率：每帧 80 个采样点、2 声道。与实验三(chirp)
 * 不同的是输出——这里每帧只出一个标量判决值，等同于一个 DPSK 符号
 * （发射端 N = fs/符号率 = 8000/100 = 80 样本/符号，正好一帧一符号）。
 *
 * 模型接口：
 *   Inport  AudioIn  int16[160]，去交织布局 [L0..79, R0..79]
 *   Outport out_data 标量，即原 To File7(toFileData5) 的每帧判决值
 */
#ifndef MODEL_IFACE_H_
#define MODEL_IFACE_H_

#include <stdint.h>

#define MODEL_SAMPLE_RATE_HZ  8000   /* 音频采样率 */
#define MODEL_FRAME_SAMPLES   80     /* 每帧样本数 = 每符号样本数 */
#define MODEL_NUM_CHANNELS    2
#define MODEL_FRAME_RATE_HZ   (MODEL_SAMPLE_RATE_HZ / MODEL_FRAME_SAMPLES) /* 100 */
#define MODEL_IN_LEN          (MODEL_FRAME_SAMPLES * MODEL_NUM_CHANNELS)   /* 160 */

#ifdef __cplusplus
extern "C" {
#endif

void model_init(void);
void model_term(void);

/* 跑一帧（= 一个 DPSK 符号） */
void model_step_frame(void);

/* 输入缓冲指针：写入一帧去交织 int16，长度 MODEL_IN_LEN */
int16_t *model_input(void);

/* 标量输出 out_data（原 toFileData5 的每帧判决值） */
double model_output(void);

/* 模型是否请求停止 */
int model_stop_requested(void);

#ifdef __cplusplus
}
#endif

#endif /* MODEL_IFACE_H_ */
