/*
 * model_glue.c ── 把 model_iface.h 契约绑定到 dpsk_receive 生成代码。
 * 全工程唯一依赖 Simulink 生成符号名的文件。
 *
 *   -DUSE_MOCK_MODEL：纯软件桩，便于无 MATLAB/声卡时联调管线。
 */
#include "model_iface.h"
#include <string.h>

/* ============================================================= *
 *  (A) MOCK 桩模型
 * ============================================================= */
#ifdef USE_MOCK_MODEL

static int16_t mock_in[MODEL_IN_LEN];
static double  mock_out;

void model_init(void) { memset(mock_in, 0, sizeof mock_in); mock_out = 0.0; }
void model_term(void) { }

void model_step_frame(void)
{
    /* 桩：把每帧左声道首样本符号当判决值，模拟 ±1 判决流 */
    mock_out = (mock_in[0] >= 0) ? 1.0 : -1.0;
}

int16_t *model_input(void)  { return mock_in; }
double   model_output(void) { return mock_out; }
int      model_stop_requested(void) { return 0; }

/* ============================================================= *
 *  (B) 真实模型 —— dpsk_receive 生成代码（单速率）
 * ============================================================= */
#else

#include "dpsk_receive.h"

void model_init(void) { dpsk_receive_initialize(); }
void model_term(void) { dpsk_receive_terminate(); }

/* 单速率：一帧就是一次 step，没有实验三那种 step0/step1 的多速率封装 */
void model_step_frame(void) { dpsk_receive_step(); }

int16_t *model_input(void)  { return &dpsk_receive_U.AudioIn[0]; }
double   model_output(void) { return dpsk_receive_Y.out_data; }
int      model_stop_requested(void)
{
    return rtmGetErrorStatus(dpsk_receive_M) != 0;
}

#endif /* USE_MOCK_MODEL */
