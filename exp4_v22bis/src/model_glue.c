/*
 * model_glue.c ── 把 model_iface.h 契约绑定到 v22_receive 生成代码。
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
static double  mock_out[MODEL_OUT_LEN];

void model_init(void) { memset(mock_in, 0, sizeof mock_in);
                        memset(mock_out, 0, sizeof mock_out); }
void model_term(void) { }
void model_set_rate(int rate) { (void)rate; }

void model_step_frame(void)
{
    /* 桩：把每 16 个输入样本折成一个"符号"，实部取均值、虚部取差分，
       只为让管线跑起来，没有任何解调意义。 */
    for (int k = 0; k < MODEL_SYMS_PER_FRAME; ++k) {
        double s = 0.0, d = 0.0;
        for (int i = 0; i < 16; ++i) {
            double v = (double)mock_in[k*16 + i] / 32768.0;
            s += v;
            d += (i < 8) ? v : -v;
        }
        mock_out[2*k]     = s / 16.0;
        mock_out[2*k + 1] = d / 16.0;
    }
}

int16_t      *model_input(void)  { return mock_in; }
const double *model_output(void) { return mock_out; }
int           model_stop_requested(void) { return 0; }

/* ============================================================= *
 *  (B) 真实模型 —— v22_receive 生成代码（单速率）
 * ============================================================= */
#else

#include "v22_receive.h"

void model_init(void) { v22_receive_initialize(); model_set_rate(2400); }
void model_term(void) { v22_receive_terminate(); }
void model_set_rate(int rate) { v22_receive_U.RxRate = (uint16_T)rate; }

/* 单速率：一帧就是一次 step，没有实验三那种 step0/step1 的多速率封装 */
void model_step_frame(void) { v22_receive_step(); }

int16_t      *model_input(void)  { return &v22_receive_U.AudioIn[0]; }
const double *model_output(void) { return &v22_receive_Y.symOut[0]; }
int           model_stop_requested(void)
{
    return rtmGetErrorStatus(v22_receive_M) != 0;
}

#endif /* USE_MOCK_MODEL */
