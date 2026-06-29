/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: single_fre_rev.h
 *
 * Code generated for Simulink model 'single_fre_rev'.
 *
 * Model version                  : 12.1
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Fri Jun 26 16:20:25 2026
 *
 * Target selection: ert.tlc
 * Embedded hardware selection: ARM Compatible->ARM Cortex-A (64-bit)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#ifndef single_fre_rev_h_
#define single_fre_rev_h_
#ifndef single_fre_rev_COMMON_INCLUDES_
#define single_fre_rev_COMMON_INCLUDES_
#include "rtwtypes.h"
#endif                                 /* single_fre_rev_COMMON_INCLUDES_ */

#include "single_fre_rev_types.h"

/* Macros for accessing real-time model data structure */
#ifndef rtmGetErrorStatus
#define rtmGetErrorStatus(rtm)         ((rtm)->errorStatus)
#endif

#ifndef rtmSetErrorStatus
#define rtmSetErrorStatus(rtm, val)    ((rtm)->errorStatus = (val))
#endif

/* Block states (default storage) for system '<Root>' */
typedef struct {
  real32_T DigitalFilter_states[150];  /* '<S3>/Digital Filter' */
  real32_T DigitalFilter_states_b[150];/* '<S2>/Digital Filter' */
  real32_T DigitalFilter_simContextBuf[300];/* '<S3>/Digital Filter' */
  real32_T DigitalFilter_simRevCoeff[151];/* '<S3>/Digital Filter' */
  real32_T DigitalFilter_simContextBuf_d[300];/* '<S2>/Digital Filter' */
  real32_T DigitalFilter_simRevCoeff_i[151];/* '<S2>/Digital Filter' */
} DW_single_fre_rev_T;

/* External inputs (root inport signals with default storage) */
typedef struct {
  int16_T AudioIn[160];                /* '<Root>/AudioIn' */
} ExtU_single_fre_rev_T;

/* External outputs (root outports fed by signals with default storage) */
typedef struct {
  real_T out_f1[80];                   /* '<Root>/out_f1' */
  real_T out_f2[80];                   /* '<Root>/out_f2' */
} ExtY_single_fre_rev_T;

/* Parameters (default storage) */
struct P_single_fre_rev_T_ {
  real32_T Gain_Gain;                  /* Computed Parameter: Gain_Gain
                                        * Referenced by: '<S1>/Gain'
                                        */
  real32_T DigitalFilter_InitialStates;
                              /* Computed Parameter: DigitalFilter_InitialStates
                               * Referenced by: '<S3>/Digital Filter'
                               */
  real32_T DigitalFilter_Coefficients[151];
                               /* Computed Parameter: DigitalFilter_Coefficients
                                * Referenced by: '<S3>/Digital Filter'
                                */
  real32_T DigitalFilter_InitialStates_f;
                            /* Computed Parameter: DigitalFilter_InitialStates_f
                             * Referenced by: '<S2>/Digital Filter'
                             */
  real32_T DigitalFilter_Coefficients_k[151];
                             /* Computed Parameter: DigitalFilter_Coefficients_k
                              * Referenced by: '<S2>/Digital Filter'
                              */
};

/* Real-time Model Data Structure */
struct tag_RTM_single_fre_rev_T {
  const char_T * volatile errorStatus;
};

/* Block parameters (default storage) */
extern P_single_fre_rev_T single_fre_rev_P;

/* Block states (default storage) */
extern DW_single_fre_rev_T single_fre_rev_DW;

/* External inputs (root inport signals with default storage) */
extern ExtU_single_fre_rev_T single_fre_rev_U;

/* External outputs (root outports fed by signals with default storage) */
extern ExtY_single_fre_rev_T single_fre_rev_Y;

/* Model entry point functions */
extern void single_fre_rev_initialize(void);
extern void single_fre_rev_step(void);
extern void single_fre_rev_terminate(void);

/* Real-time Model object */
extern RT_MODEL_single_fre_rev_T *const single_fre_rev_M;

/*-
 * These blocks were eliminated from the model due to optimizations:
 *
 * Block '<S4>/Check Signal Attributes' : Unused code path elimination
 * Block '<S5>/Check Signal Attributes' : Unused code path elimination
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
 * '<Root>' : 'single_fre_rev'
 * '<S1>'   : 'single_fre_rev/Sum left & right channels  and to single'
 * '<S2>'   : 'single_fre_rev/低通滤波器'
 * '<S3>'   : 'single_fre_rev/带通滤波器'
 * '<S4>'   : 'single_fre_rev/低通滤波器/Check Signal Attributes'
 * '<S5>'   : 'single_fre_rev/带通滤波器/Check Signal Attributes'
 */
#endif                                 /* single_fre_rev_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
