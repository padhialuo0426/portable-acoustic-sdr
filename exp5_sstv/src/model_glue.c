/* 板级接口与 Simulink 的 sstv_receive 生成代码绑定。 */
#include "model_iface.h"
#ifdef USE_MOCK_MODEL
#include <string.h>
static int16_t input[MODEL_IN_LEN];
static double output[MODEL_OUT_LEN];
void model_init(void) { memset(input,0,sizeof input); memset(output,0,sizeof output); }
void model_term(void) { }
void model_step_frame(void) { } /* 桩只验证采集写盘，不伪造有效 SSTV 频率。 */
int16_t *model_input(void) { return input; }
const double *model_output(void) { return output; }
int model_stop_requested(void) { return 0; }
#else
#include "sstv_receive.h"
void model_init(void) { sstv_receive_initialize(); }
void model_term(void) { sstv_receive_terminate(); }
void model_step_frame(void) { sstv_receive_step(); }
int16_t *model_input(void) { return &sstv_receive_U.AudioIn[0]; }
const double *model_output(void) { return &sstv_receive_Y.frequencyOut[0]; }
int model_stop_requested(void) { return rtmGetErrorStatus(sstv_receive_M)!=0; }
#endif
