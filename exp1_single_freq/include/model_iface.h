/*
 * model_iface.h ── 板级运行时 <-> Simulink 生成代码 的契约层
 *
 * 这是整个可移植工程中，唯一“知道”模型存在的接口。main.c / audio_io.c
 * 都只通过下面这几个函数和常量与模型交互，从而与具体的 Simulink
 * 生成符号名解耦。真正把这些函数绑定到生成代码的实现，在 model_glue.c。
 *
 * 设计目标：完全脱离 MathWorks 硬件支持包。模型在 MATLAB 端用
 *   - Inport  取代  ALSA Audio Capture 块   (音频输入移到模型外)
 *   - Outport 取代  To File 块（可选）        (结果输出移到模型外)
 * 然后以 ert.tlc / HardwareBoard=None 重新生成纯算法 C 代码。
 *
 * 音频采集/播放、TCP、文件落盘等所有“与硬件/OS 打交道”的事，
 * 都由本工程的手写 POSIX 代码完成，不再依赖支持包。
 */
#ifndef MODEL_IFACE_H_
#define MODEL_IFACE_H_

#include <stdint.h>

/* ===== 模型固有参数（来自原 Simulink 模型，重新生成后保持一致）===== */
#define MODEL_SAMPLE_RATE_HZ  8000   /* 音频采样率 */
#define MODEL_FRAME_SAMPLES   80     /* 每个基采样步处理的采样点数 */
#define MODEL_NUM_CHANNELS    2      /* 采集通道数 (L/R) */
#define MODEL_STEP_RATE_HZ    (MODEL_SAMPLE_RATE_HZ / MODEL_FRAME_SAMPLES) /* =100 */

/* 输入缓冲长度：去交织布局 [L0..L79, R0..R79]，int16 */
#define MODEL_IN_LEN   (MODEL_FRAME_SAMPLES * MODEL_NUM_CHANNELS)  /* 160 */
/* 每路输出长度（double）；模型有两路滤波输出 out_f1 / out_f2 */
#define MODEL_OUT_LEN     (MODEL_FRAME_SAMPLES)                     /* 80 */
#define MODEL_NUM_OUTPUTS 2

#ifdef __cplusplus
extern "C" {
#endif

/* 生命周期 ── 包装 *_initialize / *_step / *_terminate */
void model_init(void);
void model_step(void);
void model_term(void);

/*
 * 输入缓冲指针：板级代码把一帧去交织后的 int16 音频写到这里，
 * 长度 MODEL_IN_LEN。返回模型外部输入结构体内对应数组的地址。
 */
int16_t *model_input(void);

/*
 * 第 which 路输出缓冲指针(which: 0..MODEL_NUM_OUTPUTS-1)：model_step() 执行后
 * 结果在此处可读，长度 MODEL_OUT_LEN。越界或无该输出返回 NULL。
 */
const double *model_output(int which);

/* 模型是否请求停止（错误/仿真结束）。0=继续，非0=停止 */
int model_stop_requested(void);

#ifdef __cplusplus
}
#endif

#endif /* MODEL_IFACE_H_ */
