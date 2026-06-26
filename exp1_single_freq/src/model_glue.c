/*
 * model_glue.c ── 把 model_iface.h 的契约绑定到具体的 Simulink 生成代码。
 *
 * 这是全工程唯一依赖 Simulink 生成符号名的文件。重新生成模型后，
 * 通常只需在本文件里核对/修改“输入输出结构体的字段名”这一处即可。
 *
 * 两种构建：
 *   - 默认：链接真实的 single_fre_rev 生成代码（需先把生成代码放进 model/）
 *   - -DUSE_MOCK_MODEL：用下面的纯软件桩模型，便于在没有 MATLAB/声卡的
 *     机器上先跑通音频管线与调度逻辑。
 */
#include "model_iface.h"
#include <string.h>

/* ============================================================= *
 *  (A) MOCK 桩模型 —— 仅用于联调音频管线，不含真实算法
 * ============================================================= */
#ifdef USE_MOCK_MODEL

static int16_t mock_in[MODEL_IN_LEN];
static double  mock_out[MODEL_OUT_LEN];

void model_init(void) { memset(mock_in, 0, sizeof mock_in); }
void model_term(void) { }

void model_step(void)
{
    /* 桩算法：左右声道求和，转 double（模拟原模型“两声道合一”那步） */
    for (int i = 0; i < MODEL_FRAME_SAMPLES; ++i)
        mock_out[i] = (double)(mock_in[i] + mock_in[i + MODEL_FRAME_SAMPLES]);
}

int16_t *model_input(void) { return mock_in; }
const double *model_output(int which)
{
    /* 桩模型只有一路，两路都返回同一缓冲便于联调 */
    return (which >= 0 && which < MODEL_NUM_OUTPUTS) ? mock_out : NULL;
}
int model_stop_requested(void) { return 0; }

/* ============================================================= *
 *  (B) 真实模型 —— 链接 Simulink 重新生成的 ert.tlc 代码
 * ============================================================= */
#else

#include "single_fre_rev.h"   /* 由 model/ 下的生成代码提供 */

void model_init(void) { single_fre_rev_initialize(); }
void model_step(void) { single_fre_rev_step(); }
void model_term(void) { single_fre_rev_terminate(); }

int model_stop_requested(void)
{
    /* 生成代码出错或请求停止时，errorStatus 会被置位 */
    return rtmGetErrorStatus(single_fre_rev_M) != 0;
}

/* ------------------------------------------------------------- *
 *  输入：ALSA 块 -> Inport 'AudioIn'，外部输入结构体
 *      ExtU_single_fre_rev_T { int16_T AudioIn[160]; } single_fre_rev_U;
 *  布局 [L0..L79, R0..R79]，与 main.c 去交织一致。
 *
 *  输出：两个 To File -> Outport，外部输出结构体
 *      ExtY_single_fre_rev_T { real_T out_f1[80]; real_T out_f2[80]; }
 *  （均已在 single_fre_rev.h 中 extern 声明，无需重复）
 * ------------------------------------------------------------- */
int16_t *model_input(void)
{
    return &single_fre_rev_U.AudioIn[0];
}

const double *model_output(int which)
{
    switch (which) {
    case 0:  return &single_fre_rev_Y.out_f1[0];
    case 1:  return &single_fre_rev_Y.out_f2[0];
    default: return NULL;
    }
}

#endif /* USE_MOCK_MODEL */
