/*
 * model_iface.h ── 实验四(V.22bis 声学 modem) 板级运行时 <-> Simulink 生成代码 契约
 *
 * 与前三个实验的三处不同，都是有意的：
 *
 *   1) 采样率 9600 而非 8000。V.22bis 的符号率是 600 baud，9600/600 = 16
 *      正好是整数，省掉分数倍定时插值。板上用 plughw 让 ALSA 做重采样
 *      （实测 plughw 能精确给出 9600Hz，见实验文档）。
 *
 *   2) 输入是单声道 int16[960]，不是前三个实验那种 [L0..N, R0..N] 双声道
 *      去交织布局。本实验的模型里没有「左右求和」那一步——声道合并在
 *      main.c 里做完再喂进来，模型只管单路基带处理。
 *
 *   3) 输出是 120 个 double（60 个符号的 I,Q 交替），不是标量判决值。
 *      16-QAM 的判决要看幅度，PC 端必须拿到完整复符号才能画星座图定位
 *      问题；标量判决流不够用。帧同步/解扰/HDLC 仍在 PC 端做，分层不变。
 *
 * 模型改造：ALSA Audio Capture → Inport AudioIn(int16[960])；
 *           输出 Outport symOut(real_T[120])。
 */
#ifndef MODEL_IFACE_H_
#define MODEL_IFACE_H_

#include <stdint.h>

#define MODEL_SAMPLE_RATE_HZ  9600   /* 采样率 */
#define MODEL_FRAME_SAMPLES   960    /* 每帧样本数 = 60 符号 × 16 */
#define MODEL_SYMS_PER_FRAME  60     /* 每帧符号数 */
#define MODEL_OUT_LEN         120    /* 输出长度 = 60 符号 × (I,Q) */
#define MODEL_FRAME_RATE_HZ   (MODEL_SAMPLE_RATE_HZ / MODEL_FRAME_SAMPLES)  /* 10 */
#define MODEL_IN_LEN          MODEL_FRAME_SAMPLES

#ifdef __cplusplus
extern "C" {
#endif

void model_init(void);
void model_term(void);
/* 初始化后、第一帧之前设置接收速率：1200(QPSK) 或 2400(16-QAM)。 */
void model_set_rate(int rate);

/* 跑一帧：单速率，一次 step 就是一帧 */
void model_step_frame(void);

/* 输入缓冲指针：写入一帧单声道 int16，长度 MODEL_IN_LEN */
int16_t *model_input(void);

/* 输出缓冲指针：MODEL_OUT_LEN 个 double，I,Q 交替 */
const double *model_output(void);

/* 模型是否请求停止 */
int model_stop_requested(void);

#ifdef __cplusplus
}
#endif

#endif /* MODEL_IFACE_H_ */
