/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: chirp_rev_detect.h
 *
 * Code generated for Simulink model 'chirp_rev_detect'.
 *
 * Model version                  : 12.0
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Fri Jun 26 01:35:56 2026
 *
 * Target selection: ert.tlc
 * Embedded hardware selection: ARM Compatible->ARM Cortex-A (32-bit)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#ifndef chirp_rev_detect_h_
#define chirp_rev_detect_h_
#ifndef chirp_rev_detect_COMMON_INCLUDES_
#define chirp_rev_detect_COMMON_INCLUDES_
#include "rtwtypes.h"
#endif                                 /* chirp_rev_detect_COMMON_INCLUDES_ */

#include "chirp_rev_detect_types.h"
#include "rt_nonfinite.h"

/* Macros for accessing real-time model data structure */
#ifndef rtmCounterLimit
#define rtmCounterLimit(rtm, idx)      ((rtm)->Timing.TaskCounters.cLimit[(idx)])
#endif

#ifndef rtmGetErrorStatus
#define rtmGetErrorStatus(rtm)         ((rtm)->errorStatus)
#endif

#ifndef rtmSetErrorStatus
#define rtmSetErrorStatus(rtm, val)    ((rtm)->errorStatus = (val))
#endif

#ifndef rtmStepTask
#define rtmStepTask(rtm, idx)          ((rtm)->Timing.TaskCounters.TID[(idx)] == 0)
#endif

#ifndef rtmTaskCounter
#define rtmTaskCounter(rtm, idx)       ((rtm)->Timing.TaskCounters.TID[(idx)])
#endif

/* Block signals for system '<Root>/MATLAB Function1' */
typedef struct {
  real32_T temp[1599];
} B_MATLABFunction1_chirp_rev_d_T;

/* Block signals (default storage) */
typedef struct {
  real_T y_a[800];                     /* '<Root>/MATLAB Function4' */
  real32_T temp[1599];
  real32_T DigitalFilter[800];         /* '<S13>/Digital Filter' */
  real32_T DigitalFilter_c[800];       /* '<S2>/Digital Filter' */
  real32_T DigitalFilter_i[800];       /* '<S1>/Digital Filter' */
  B_MATLABFunction1_chirp_rev_d_T sf_MATLABFunction3;/* '<Root>/MATLAB Function3' */
  B_MATLABFunction1_chirp_rev_d_T sf_MATLABFunction1;/* '<Root>/MATLAB Function1' */
} B_chirp_rev_detect_T;

/* Block states (default storage) for system '<Root>' */
typedef struct {
  real_T Am;                           /* '<Root>/Data Store Memory1' */
  real_T pos2;                         /* '<Root>/Data Store Memory2' */
  real_T position;                     /* '<Root>/Data Store Memory3' */
  real_T aa;                           /* '<Root>/Data Store Memory4' */
  real_T loc;                          /* '<S14>/MATLAB Function14' */
  real_T aa_h;                         /* '<S14>/MATLAB Function14' */
  real_T flag;                         /* '<S14>/MATLAB Function14' */
  real_T loc_b;                        /* '<S3>/MATLAB Function6' */
  real_T flag_a;                       /* '<S3>/MATLAB Function6' */
  real32_T Delay1_DSTATE[799];         /* '<Root>/Delay1' */
  real32_T DigitalFilter_states[150];  /* '<S13>/Digital Filter' */
  real32_T DigitalFilter_states_e[100];/* '<S2>/Digital Filter' */
  real32_T Delay2_DSTATE[799];         /* '<Root>/Delay2' */
  real32_T DigitalFilter_states_g[100];/* '<S1>/Digital Filter' */
  real32_T Delay7_DSTATE[799];         /* '<S14>/Delay7' */
  real32_T Delay8_DSTATE[800];         /* '<S14>/Delay8' */
  real32_T Delay9_DSTATE[1600];        /* '<S14>/Delay9' */
  real32_T DigitalFilter_simContextBuf[300];/* '<S13>/Digital Filter' */
  real32_T DigitalFilter_simRevCoeff[151];/* '<S13>/Digital Filter' */
  real32_T DigitalFilter_simContextBuf_k[200];/* '<S2>/Digital Filter' */
  real32_T DigitalFilter_simRevCoeff_m[101];/* '<S2>/Digital Filter' */
  real32_T DigitalFilter_simContextBuf_j[200];/* '<S1>/Digital Filter' */
  real32_T DigitalFilter_simRevCoeff_o[101];/* '<S1>/Digital Filter' */
} DW_chirp_rev_detect_T;

/* External inputs (root inport signals with default storage) */
typedef struct {
  int16_T AudioIn[1600];               /* '<Root>/AudioIn' */
} ExtU_chirp_rev_detect_T;

/* External outputs (root outports fed by signals with default storage) */
typedef struct {
  real_T out_data;                     /* '<Root>/out_data' */
} ExtY_chirp_rev_detect_T;

/* Parameters (default storage) */
struct P_chirp_rev_detect_T_ {
  real_T Constant1_Value;              /* Expression: 1
                                        * Referenced by: '<Root>/Constant1'
                                        */
  real_T Constant_Value;               /* Expression: -1
                                        * Referenced by: '<Root>/Constant'
                                        */
  real_T Constant2_Value;              /* Expression: 1
                                        * Referenced by: '<S14>/Constant2'
                                        */
  real_T DataStoreMemory1_InitialValue;/* Expression: 0
                                        * Referenced by: '<Root>/Data Store Memory1'
                                        */
  real_T DataStoreMemory2_InitialValue;/* Expression: 0
                                        * Referenced by: '<Root>/Data Store Memory2'
                                        */
  real_T DataStoreMemory3_InitialValue;/* Expression: 0
                                        * Referenced by: '<Root>/Data Store Memory3'
                                        */
  real_T DataStoreMemory4_InitialValue;/* Expression: 0
                                        * Referenced by: '<Root>/Data Store Memory4'
                                        */
  real32_T Delay1_InitialCondition;
                                  /* Computed Parameter: Delay1_InitialCondition
                                   * Referenced by: '<Root>/Delay1'
                                   */
  real32_T Gain_Gain;                  /* Computed Parameter: Gain_Gain
                                        * Referenced by: '<S12>/Gain'
                                        */
  real32_T DigitalFilter_InitialStates;
                              /* Computed Parameter: DigitalFilter_InitialStates
                               * Referenced by: '<S13>/Digital Filter'
                               */
  real32_T DigitalFilter_Coefficients[151];
                               /* Computed Parameter: DigitalFilter_Coefficients
                                * Referenced by: '<S13>/Digital Filter'
                                */
  real32_T DigitalFilter_InitialStates_o;
                            /* Computed Parameter: DigitalFilter_InitialStates_o
                             * Referenced by: '<S2>/Digital Filter'
                             */
  real32_T DigitalFilter_Coefficients_o[101];
                             /* Computed Parameter: DigitalFilter_Coefficients_o
                              * Referenced by: '<S2>/Digital Filter'
                              */
  real32_T Delay2_InitialCondition;
                                  /* Computed Parameter: Delay2_InitialCondition
                                   * Referenced by: '<Root>/Delay2'
                                   */
  real32_T DigitalFilter_InitialStates_n;
                            /* Computed Parameter: DigitalFilter_InitialStates_n
                             * Referenced by: '<S1>/Digital Filter'
                             */
  real32_T DigitalFilter_Coefficients_d[101];
                             /* Computed Parameter: DigitalFilter_Coefficients_d
                              * Referenced by: '<S1>/Digital Filter'
                              */
  real32_T Delay7_InitialCondition;
                                  /* Computed Parameter: Delay7_InitialCondition
                                   * Referenced by: '<S14>/Delay7'
                                   */
  real32_T Delay8_InitialCondition;
                                  /* Computed Parameter: Delay8_InitialCondition
                                   * Referenced by: '<S14>/Delay8'
                                   */
  real32_T Delay9_InitialCondition;
                                  /* Computed Parameter: Delay9_InitialCondition
                                   * Referenced by: '<S14>/Delay9'
                                   */
};

/* Real-time Model Data Structure */
struct tag_RTM_chirp_rev_detect_T {
  const char_T * volatile errorStatus;

  /*
   * Timing:
   * The following substructure contains information regarding
   * the timing information for the model.
   */
  struct {
    struct {
      uint16_T TID[2];
      uint16_T cLimit[2];
    } TaskCounters;
  } Timing;
};

/* Block parameters (default storage) */
extern P_chirp_rev_detect_T chirp_rev_detect_P;

/* Block signals (default storage) */
extern B_chirp_rev_detect_T chirp_rev_detect_B;

/* Block states (default storage) */
extern DW_chirp_rev_detect_T chirp_rev_detect_DW;

/* External inputs (root inport signals with default storage) */
extern ExtU_chirp_rev_detect_T chirp_rev_detect_U;

/* External outputs (root outports fed by signals with default storage) */
extern ExtY_chirp_rev_detect_T chirp_rev_detect_Y;

/* Model entry point functions */
extern void chirp_rev_detect_initialize(void);
extern void chirp_rev_detect_step0(void);/* Sample time: [0.000125s, 0.0s] */
extern void chirp_rev_detect_step1(void);/* Sample time: [0.1s, 0.0s] */
extern void chirp_rev_detect_terminate(void);

/* Real-time Model object */
extern RT_MODEL_chirp_rev_detect_T *const chirp_rev_detect_M;

/*-
 * These blocks were eliminated from the model due to optimizations:
 *
 * Block '<Root>/Data Type Conversion1' : Unused code path elimination
 * Block '<Root>/Data Type Conversion2' : Unused code path elimination
 * Block '<Root>/Data Type Conversion3' : Unused code path elimination
 * Block '<Root>/Data Type Conversion5' : Unused code path elimination
 * Block '<Root>/Data Type Conversion6' : Unused code path elimination
 * Block '<Root>/Data Type Conversion7' : Unused code path elimination
 * Block '<S15>/Check Signal Attributes' : Unused code path elimination
 * Block '<S16>/Check Signal Attributes' : Unused code path elimination
 * Block '<Root>/Display1' : Unused code path elimination
 * Block '<Root>/Display2' : Unused code path elimination
 * Block '<S19>/Check Signal Attributes' : Unused code path elimination
 * Block '<S14>/Data Type Conversion10' : Unused code path elimination
 * Block '<S14>/Data Type Conversion13' : Unused code path elimination
 * Block '<S14>/Data Type Conversion14' : Unused code path elimination
 * Block '<S14>/Data Type Conversion8' : Unused code path elimination
 * Block '<S14>/Unbuffer10' : Unused code path elimination
 * Block '<S14>/Unbuffer13' : Unused code path elimination
 * Block '<S14>/Unbuffer14' : Unused code path elimination
 * Block '<S14>/Unbuffer8' : Unused code path elimination
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
 * '<Root>' : 'chirp_rev_detect'
 * '<S1>'   : 'chirp_rev_detect/Digital Filter Design1'
 * '<S2>'   : 'chirp_rev_detect/Digital Filter Design2'
 * '<S3>'   : 'chirp_rev_detect/LFM信号检测'
 * '<S4>'   : 'chirp_rev_detect/MATLAB Function1'
 * '<S5>'   : 'chirp_rev_detect/MATLAB Function10'
 * '<S6>'   : 'chirp_rev_detect/MATLAB Function12'
 * '<S7>'   : 'chirp_rev_detect/MATLAB Function2'
 * '<S8>'   : 'chirp_rev_detect/MATLAB Function3'
 * '<S9>'   : 'chirp_rev_detect/MATLAB Function4'
 * '<S10>'  : 'chirp_rev_detect/MATLAB Function6'
 * '<S11>'  : 'chirp_rev_detect/MATLAB Function7'
 * '<S12>'  : 'chirp_rev_detect/Sum left & right channels  and to single1'
 * '<S13>'  : 'chirp_rev_detect/带通滤波器 '
 * '<S14>'  : 'chirp_rev_detect/抽样位置检测'
 * '<S15>'  : 'chirp_rev_detect/Digital Filter Design1/Check Signal Attributes'
 * '<S16>'  : 'chirp_rev_detect/Digital Filter Design2/Check Signal Attributes'
 * '<S17>'  : 'chirp_rev_detect/LFM信号检测/MATLAB Function6'
 * '<S18>'  : 'chirp_rev_detect/LFM信号检测/MATLAB Function8'
 * '<S19>'  : 'chirp_rev_detect/带通滤波器 /Check Signal Attributes'
 * '<S20>'  : 'chirp_rev_detect/抽样位置检测/MATLAB Function11'
 * '<S21>'  : 'chirp_rev_detect/抽样位置检测/MATLAB Function13'
 * '<S22>'  : 'chirp_rev_detect/抽样位置检测/MATLAB Function14'
 * '<S23>'  : 'chirp_rev_detect/抽样位置检测/MATLAB Function15'
 * '<S24>'  : 'chirp_rev_detect/抽样位置检测/MATLAB Function9'
 */
#endif                                 /* chirp_rev_detect_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
