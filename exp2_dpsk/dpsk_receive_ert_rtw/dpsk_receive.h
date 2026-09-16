/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: dpsk_receive.h
 *
 * Code generated for Simulink model 'dpsk_receive'.
 *
 * Model version                  : 6.0
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Wed Sep 16 20:17:12 2026
 *
 * Target selection: ert.tlc
 * Embedded hardware selection: ARM Compatible->ARM Cortex-A (64-bit)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#ifndef dpsk_receive_h_
#define dpsk_receive_h_
#ifndef dpsk_receive_COMMON_INCLUDES_
#define dpsk_receive_COMMON_INCLUDES_
#include "rtwtypes.h"
#endif                                 /* dpsk_receive_COMMON_INCLUDES_ */

#include "dpsk_receive_types.h"

/* Macros for accessing real-time model data structure */
#ifndef rtmGetErrorStatus
#define rtmGetErrorStatus(rtm)         ((rtm)->errorStatus)
#endif

#ifndef rtmSetErrorStatus
#define rtmSetErrorStatus(rtm, val)    ((rtm)->errorStatus = (val))
#endif

/* Block signals (default storage) */
typedef struct {
  real_T temp[239];
  real_T DigitalFilter[80];            /* '<S4>/Digital Filter' */
  real_T y_b[80];                      /* '<S6>/MATLAB Function10' */
  real_T y_m[80];                      /* '<S9>/MATLAB Function10' */
  real32_T DigitalFilter_a[80];        /* '<S7>/Digital Filter' */
  real32_T Gain[80];                   /* '<S3>/Gain' */
  real_T numAccum;
  real_T denAccum;
  real_T rtb_y_m_m;
  real_T DigitalFilter_FILT_STATES;
  real_T DigitalFilter_FILT_STATES_c;
  real_T DigitalFilter_FILT_STATES_k;
  real_T DigitalFilter_FILT_STATES_cx;
  real_T DigitalFilter_FILT_STATES_b;
  real_T DigitalFilter_FILT_STATES_p;
  real_T DigitalFilter_FILT_STATES_cv;
  real_T DigitalFilter_FILT_STATES_f;
  real_T DigitalFilter_FILT_STATES_g;
  real_T DigitalFilter_FILT_STATES_g1;
  real_T DigitalFilter_FILT_STATES_m;
  real_T DigitalFilter_FILT_STATES_n;
  real_T DigitalFilter_FILT_STATES_pp;
  real_T DigitalFilter_FILT_STATES_l;
  real_T DigitalFilter_FILT_STATES_j;
  real_T DigitalFilter_FILT_STATES_d;
  real_T DigitalFilter_FILT_STATES_gu;
  real_T DigitalFilter_FILT_STATES_ld;
  real_T DigitalFilter_FILT_STATES_dh;
  real_T DigitalFilter_FILT_STATES_dy;
  real_T DigitalFilter_FILT_STATES_lx;
  real_T DigitalFilter_FILT_STATES_o;
  real_T DigitalFilter_FILT_STATES_bj;
  real_T DigitalFilter_FILT_STATES_nu;
  real_T DigitalFilter_FILT_STATES_bs;
  real_T DigitalFilter_FILT_STATES_ln;
  real_T DigitalFilter_FILT_STATES_h;
  real_T DigitalFilter_FILT_STATES_bn;
  real_T DigitalFilter_FILT_STATES_da;
  real_T DigitalFilter_FILT_STATES_e;
  real_T DigitalFilter_FILT_STATES_bjv;
  real_T DigitalFilter_FILT_STATES_jz;
  real_T DigitalFilter_FILT_STATES_fd;
  real_T DigitalFilter_FILT_STATES_a;
  real_T DigitalFilter_FILT_STATES_ju;
  real_T DigitalFilter_FILT_STATES_jz5;
  real_T DigitalFilter_FILT_STATES_o4;
  real_T DigitalFilter_FILT_STATES_ny;
  real_T DigitalFilter_FILT_STATES_i;
  real_T DigitalFilter_FILT_STATES_oy;
  real_T DigitalFilter_FILT_STATES_nv;
  real_T DigitalFilter_FILT_STATES_m3;
  real_T DigitalFilter_FILT_STATES_cz;
} B_dpsk_receive_T;

/* Block states (default storage) for system '<Root>' */
typedef struct {
  real_T Delay_DSTATE[3200];           /* '<S6>/Delay' */
  real_T DigitalFilter_states[200];    /* '<S4>/Digital Filter' */
  real_T DigitalFilter_FILT_STATES[50];/* '<S16>/Digital Filter' */
  real_T Delay1_DSTATE[158];           /* '<Root>/Delay1' */
  real_T Delay2_DSTATE[80];            /* '<Root>/Delay2' */
  real_T DigitalFilter_simContextBuf[400];/* '<S4>/Digital Filter' */
  real_T DigitalFilter_simRevCoeff[201];/* '<S4>/Digital Filter' */
  real_T Am;                           /* '<Root>/Data Store Memory' */
  real_T position;                     /* '<Root>/Data Store Memory3' */
  real_T temp[80];                     /* '<Root>/码元延迟' */
  real_T temp1[40];                    /* '<S9>/MATLAB Function10' */
  real_T code;                         /* '<Root>/抽样' */
  real_T loc;                          /* '<Root>/抽样' */
  real_T count;                        /* '<Root>/抽样' */
  real_T flag;                         /* '<Root>/抽样' */
  real_T temp2[7];                     /* '<S6>/MATLAB Function10' */
  real_T loc_e;                        /* '<S1>/MATLAB Function6' */
  real_T flag_k;                       /* '<S1>/MATLAB Function6' */
  real32_T DigitalFilter_states_b[150];/* '<S7>/Digital Filter' */
  real32_T DigitalFilter_simContextBuf_d[300];/* '<S7>/Digital Filter' */
  real32_T DigitalFilter_simRevCoeff_i[151];/* '<S7>/Digital Filter' */
} DW_dpsk_receive_T;

/* External inputs (root inport signals with default storage) */
typedef struct {
  int16_T AudioIn[160];                /* '<Root>/AudioIn' */
} ExtU_dpsk_receive_T;

/* External outputs (root outports fed by signals with default storage) */
typedef struct {
  real_T out_data;                     /* '<Root>/out_data' */
} ExtY_dpsk_receive_T;

/* Parameters (default storage) */
struct P_dpsk_receive_T_ {
  real_T Delay_InitialCondition;       /* Expression: 0
                                        * Referenced by: '<S6>/Delay'
                                        */
  real_T DigitalFilter_InitialStates;  /* Expression: 0
                                        * Referenced by: '<S4>/Digital Filter'
                                        */
  real_T DigitalFilter_Coefficients[201];
  /* Expression: [-0.00501632713059190719 -0.000665901834798828473 -0.000693234173897483257 -0.000710468166214086238 -0.000714724574045839207 -0.000706932365403110507 -0.000684324601183771428 -0.000648066790156035639 -0.000595719467532377159 -0.000528685942165437448 -0.000444964411008117139 -0.000346590856364114631 -0.000231997389369959542 -0.000103394118463949147 3.99209649635290148e-05 0.000194758101216832016 0.000362202384289025676 0.000537099420720738713 0.00072095528968255313 0.000908099497671731293 0.00109913697659752042 0.00128893590899329703 0.0014780391603588989 0.00166039339571061447 0.00183660300913373676 0.00199935254038204578 0.00214899385064038764 0.00227615002851699411 0.00238328482650735328 0.00246125208299220527 0.00252412697482825741 0.00255108585900171592 0.00253903442032725338 0.00250250959561702747 0.00242343699076961539 0.00231056515305010828 0.0021568986331862057 0.00196629751344765862 0.00173551378484853008 0.00146775971893435921 0.00116192794230163808 0.000821792142476829713 0.000448194074690021866 4.54792319894086229e-05 -0.000384254634920695173 -0.000835227230441063385 -0.00130495804888820506 -0.00178650561924621407 -0.00227566444832685063 -0.00276608536959531632 -0.00325077824042735008 -0.003723199601736392 -0.00417626362616573855 -0.00460260188990645452 -0.00499496763781536422 -0.00534646482789719914 -0.00564979335263077979 -0.00589754907995141894 -0.00608173023812192196 -0.00619586118735133973 -0.0062344812156337609 -0.00619430043813304267 -0.00606292946212081893 -0.00584270752982120247 -0.00552623975711246003 -0.00511062653960497274 -0.00459429668771783525 -0.00397512283406939535 -0.00325319042182964542 -0.00242864805925359795 -0.00150304634289554883 -0.000478621506231333746 0.000641100920046106491 0.00185169946220160994 0.00314799568124806729 0.00452314103014371353 0.0059700081867597116 0.00748080591566030288 0.00904515466976986426 0.0106556524489696408 0.0123000533710266105 0.0139681772597563258 0.0156486423370626217 0.0173297243186874561 0.0189988472960637249 0.0206442518323019623 0.0222538595193951354 0.0238160175300384074 0.0253180981562269765 0.0267484260420697735 0.0280954496956775136 0.0293504012107617743 0.030501500199468512 0.0315394926368621417 0.0324583013155507541 0.0332475926828858723 0.0339031847223049548 0.034418194008669821 0.0347893889073872739 0.0350130587716545316 0.0350880632022486372 0.0350130587716545316 0.0347893889073872739 0.034418194008669821 0.0339031847223049548 0.0332475926828858723 0.0324583013155507541 0.0315394926368621417 0.030501500199468512 0.0293504012107617743 0.0280954496956775136 0.0267484260420697735 0.0253180981562269765 0.0238160175300384074 0.0222538595193951354 0.0206442518323019623 0.0189988472960637249 0.0173297243186874561 0.0156486423370626217 0.0139681772597563258 0.0123000533710266105 0.0106556524489696408 0.00904515466976986426 0.00748080591566030288 0.0059700081867597116 0.00452314103014371353 0.00314799568124806729 0.00185169946220160994 0.000641100920046106491 -0.000478621506231333746 -0.00150304634289554883 -0.00242864805925359795 -0.00325319042182964542 -0.00397512283406939535 -0.00459429668771783525 -0.00511062653960497274 -0.00552623975711246003 -0.00584270752982120247 -0.00606292946212081893 -0.00619430043813304267 -0.0062344812156337609 -0.00619586118735133973 -0.00608173023812192196 -0.00589754907995141894 -0.00564979335263077979 -0.00534646482789719914 -0.00499496763781536422 -0.00460260188990645452 -0.00417626362616573855 -0.003723199601736392 -0.00325077824042735008 -0.00276608536959531632 -0.00227566444832685063 -0.00178650561924621407 -0.00130495804888820506 -0.000835227230441063385 -0.000384254634920695173 4.54792319894086229e-05 0.000448194074690021866 0.000821792142476829713 0.00116192794230163808 0.00146775971893435921 0.00173551378484853008 0.00196629751344765862 0.0021568986331862057 0.00231056515305010828 0.00242343699076961539 0.00250250959561702747 0.00253903442032725338 0.00255108585900171592 0.00252412697482825741 0.00246125208299220527 0.00238328482650735328 0.00227615002851699411 0.00214899385064038764 0.00199935254038204578 0.00183660300913373676 0.00166039339571061447 0.0014780391603588989 0.00128893590899329703 0.00109913697659752042 0.000908099497671731293 0.00072095528968255313 0.000537099420720738713 0.000362202384289025676 0.000194758101216832016 3.99209649635290148e-05 -0.000103394118463949147 -0.000231997389369959542 -0.000346590856364114631 -0.000444964411008117139 -0.000528685942165437448 -0.000595719467532377159 -0.000648066790156035639 -0.000684324601183771428 -0.000706932365403110507 -0.000714724574045839207 -0.000710468166214086238 -0.000693234173897483257 -0.000665901834798828473 -0.00501632713059190719]
   * Referenced by: '<S4>/Digital Filter'
   */
  real_T Unbuffer7_ic;                 /* Expression: 0
                                        * Referenced by: '<Root>/Unbuffer7'
                                        */
  real_T Delay1_InitialCondition;      /* Expression: 0
                                        * Referenced by: '<Root>/Delay1'
                                        */
  real_T Delay2_InitialCondition;      /* Expression: 0
                                        * Referenced by: '<Root>/Delay2'
                                        */
  real_T DataStoreMemory_InitialValue; /* Expression: 0
                                        * Referenced by: '<Root>/Data Store Memory'
                                        */
  real_T DataStoreMemory3_InitialValue;/* Expression: 0
                                        * Referenced by: '<Root>/Data Store Memory3'
                                        */
  real32_T Gain_Gain;                  /* Computed Parameter: Gain_Gain
                                        * Referenced by: '<S3>/Gain'
                                        */
  real32_T DigitalFilter_InitialStates_f;
                            /* Computed Parameter: DigitalFilter_InitialStates_f
                             * Referenced by: '<S7>/Digital Filter'
                             */
  real32_T DigitalFilter_Coefficients_k[151];
                             /* Computed Parameter: DigitalFilter_Coefficients_k
                              * Referenced by: '<S7>/Digital Filter'
                              */
};

/* Real-time Model Data Structure */
struct tag_RTM_dpsk_receive_T {
  const char_T * volatile errorStatus;
};

/* Block parameters (default storage) */
extern P_dpsk_receive_T dpsk_receive_P;

/* Block signals (default storage) */
extern B_dpsk_receive_T dpsk_receive_B;

/* Block states (default storage) */
extern DW_dpsk_receive_T dpsk_receive_DW;

/* External inputs (root inport signals with default storage) */
extern ExtU_dpsk_receive_T dpsk_receive_U;

/* External outputs (root outports fed by signals with default storage) */
extern ExtY_dpsk_receive_T dpsk_receive_Y;

/* Model entry point functions */
extern void dpsk_receive_initialize(void);
extern void dpsk_receive_step(void);
extern void dpsk_receive_terminate(void);

/* Real-time Model object */
extern RT_MODEL_dpsk_receive_T *const dpsk_receive_M;

/*-
 * These blocks were eliminated from the model due to optimizations:
 *
 * Block '<Root>/Data Type Conversion4' : Unused code path elimination
 * Block '<Root>/Data Type Conversion5' : Unused code path elimination
 * Block '<Root>/Data Type Conversion6' : Unused code path elimination
 * Block '<Root>/Data Type Conversion9' : Unused code path elimination
 * Block '<Root>/Display' : Unused code path elimination
 * Block '<Root>/Display2' : Unused code path elimination
 * Block '<S13>/Check Signal Attributes' : Unused code path elimination
 * Block '<S15>/Check Signal Attributes' : Unused code path elimination
 * Block '<S18>/Check Signal Attributes' : Unused code path elimination
 * Block '<Root>/Data Type Conversion7' : Eliminate redundant data type conversion
 */

/*-
 * The generated code includes comments that allow you to trace directly
 * back to the appropriate location in the model.  The basic format
 * is <system>/block_name, where system is the system number (uniquely
 * assigned by Simulink) and block_name is the name of the block.
 *
 * Use the MATLAB hilite_system command to trace the generated code back
 * to the model.  For example,
 *
 * hilite_system('<S3>')    - opens system 3
 * hilite_system('<S3>/Kp') - opens and selects block Kp which resides in S3
 *
 * Here is the system hierarchy for this model
 *
 * '<Root>' : 'dpsk_receive'
 * '<S1>'   : 'dpsk_receive/DPSK信号检测'
 * '<S2>'   : 'dpsk_receive/MATLAB Function7'
 * '<S3>'   : 'dpsk_receive/Sum left & right channels  and to single'
 * '<S4>'   : 'dpsk_receive/低通滤波器'
 * '<S5>'   : 'dpsk_receive/匹配滤波'
 * '<S6>'   : 'dpsk_receive/匹配滤波后延迟'
 * '<S7>'   : 'dpsk_receive/带通滤波器 '
 * '<S8>'   : 'dpsk_receive/抽样'
 * '<S9>'   : 'dpsk_receive/码元同步'
 * '<S10>'  : 'dpsk_receive/码元延迟'
 * '<S11>'  : 'dpsk_receive/DPSK信号检测/MATLAB Function6'
 * '<S12>'  : 'dpsk_receive/DPSK信号检测/MATLAB Function8'
 * '<S13>'  : 'dpsk_receive/低通滤波器/Check Signal Attributes'
 * '<S14>'  : 'dpsk_receive/匹配滤波后延迟/MATLAB Function10'
 * '<S15>'  : 'dpsk_receive/带通滤波器 /Check Signal Attributes'
 * '<S16>'  : 'dpsk_receive/码元同步/Digital Filter Design3'
 * '<S17>'  : 'dpsk_receive/码元同步/MATLAB Function10'
 * '<S18>'  : 'dpsk_receive/码元同步/Digital Filter Design3/Check Signal Attributes'
 */
#endif                                 /* dpsk_receive_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
