/*
 * model_glue.c ── 把 model_iface.h 契约绑定到 chirp_rev_detect 生成代码。
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

#include <math.h>
static int16_t mock_in[MODEL_IN_LEN];
static double  mock_out;
static unsigned long mock_k;

void model_init(void) { memset(mock_in, 0, sizeof mock_in); mock_k = 0; }
void model_term(void) { }

void model_step_frame(void)
{
    /* 桩：把每帧左声道首样本符号作为输出，模拟 ±1 判决流 */
    mock_out = (mock_in[0] >= 0) ? 1.0 : -1.0;
    mock_k++;
}

int16_t *model_input(void)  { return mock_in; }
double   model_output(void) { return mock_out; }
int      model_stop_requested(void) { return 0; }

/* ============================================================= *
 *  (B) 真实模型 —— chirp_rev_detect 多速率生成代码
 * ============================================================= */
#else

#include "chirp_rev_detect.h"

void model_init(void) { chirp_rev_detect_initialize(); }
void model_term(void) { chirp_rev_detect_terminate(); }

void model_step_frame(void)
{
    /* 10Hz 任务：消费 AudioIn 一帧、产出 out_data（含 1 帧流水延迟） */
    chirp_rev_detect_step1();
    /* 8000Hz 任务 ×800：逐样本处理本帧（经速率转换缓冲） */
    for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i)
        chirp_rev_detect_step0();
}

int16_t *model_input(void)  { return &chirp_rev_detect_U.AudioIn[0]; }
double   model_output(void) { return chirp_rev_detect_Y.out_data; }
int      model_stop_requested(void)
{
    return rtmGetErrorStatus(chirp_rev_detect_M) != 0;
}

#endif /* USE_MOCK_MODEL */
