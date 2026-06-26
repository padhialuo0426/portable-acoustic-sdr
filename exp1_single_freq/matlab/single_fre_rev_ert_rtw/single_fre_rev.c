/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: single_fre_rev.c
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

#include "single_fre_rev.h"
#include <string.h>
#include "rtwtypes.h"

/* Block states (default storage) */
DW_single_fre_rev_T single_fre_rev_DW;

/* External inputs (root inport signals with default storage) */
ExtU_single_fre_rev_T single_fre_rev_U;

/* External outputs (root outports fed by signals with default storage) */
ExtY_single_fre_rev_T single_fre_rev_Y;

/* Real-time model */
static RT_MODEL_single_fre_rev_T single_fre_rev_M_;
RT_MODEL_single_fre_rev_T *const single_fre_rev_M = &single_fre_rev_M_;

/* Model step function */
void single_fre_rev_step(void)
{
  int32_T n;
  int32_T srcIdx;
  real32_T rtb_DigitalFilter[80];
  real32_T rtb_Gain[80];
  real32_T acc;
  for (srcIdx = 0; srcIdx < 80; srcIdx++) {
    /* Gain: '<S1>/Gain' incorporates:
     *  DataTypeConversion: '<S1>/ 1'
     *  Inport: '<Root>/AudioIn'
     *  Sum: '<S1>/Matrix Sum'
     */
    rtb_Gain[srcIdx] = (real32_T)(int16_T)(single_fre_rev_U.AudioIn[srcIdx + 80]
      + single_fre_rev_U.AudioIn[srcIdx]) * single_fre_rev_P.Gain_Gain;
  }

  /* DiscreteFir: '<S3>/Digital Filter' incorporates:
   *  DiscreteFir: '<S2>/Digital Filter'
   *  Gain: '<S1>/Gain'
   */
  /* Reverse the coefficients */
  for (srcIdx = 0; srcIdx < 151; srcIdx++) {
    single_fre_rev_DW.DigitalFilter_simRevCoeff[150 - srcIdx] =
      single_fre_rev_P.DigitalFilter_Coefficients[srcIdx];
  }

  /* Reverse copy the states from States_Dwork to ContextBuff_Dwork */
  for (srcIdx = 0; srcIdx < 150; srcIdx++) {
    single_fre_rev_DW.DigitalFilter_simContextBuf[149 - srcIdx] =
      single_fre_rev_DW.DigitalFilter_states[srcIdx];
  }

  /* Copy the initial part of input to ContextBuff_Dwork */
  memcpy(&single_fre_rev_DW.DigitalFilter_simContextBuf[150], &rtb_Gain[0], 80U *
         sizeof(real32_T));
  for (srcIdx = 0; srcIdx < 80; srcIdx++) {
    acc = 0.0F;
    for (n = 0; n < 151; n++) {
      acc += single_fre_rev_DW.DigitalFilter_simContextBuf[srcIdx + n] *
        single_fre_rev_DW.DigitalFilter_simRevCoeff[n];
    }

    /* store output sample */
    rtb_DigitalFilter[srcIdx] = acc;
  }

  /* Shift state buffer when input buffer is shorter than state buffer */
  for (srcIdx = 69; srcIdx >= 0; srcIdx--) {
    single_fre_rev_DW.DigitalFilter_states[srcIdx + 80] =
      single_fre_rev_DW.DigitalFilter_states[srcIdx];
  }

  /* Reverse copy the states from input to States_Dwork */
  for (srcIdx = 0; srcIdx < 80; srcIdx++) {
    single_fre_rev_DW.DigitalFilter_states[79 - srcIdx] = rtb_Gain[srcIdx];

    /* Outport: '<Root>/out_f1' incorporates:
     *  DataTypeConversion: '<Root>/Data Type Conversion6'
     *  DiscreteFir: '<S2>/Digital Filter'
     */
    single_fre_rev_Y.out_f1[srcIdx] = rtb_DigitalFilter[srcIdx];
  }

  /* End of DiscreteFir: '<S3>/Digital Filter' */

  /* DiscreteFir: '<S2>/Digital Filter' incorporates:
   *  Gain: '<S1>/Gain'
   */
  /* Reverse the coefficients */
  for (srcIdx = 0; srcIdx < 151; srcIdx++) {
    single_fre_rev_DW.DigitalFilter_simRevCoeff_i[150 - srcIdx] =
      single_fre_rev_P.DigitalFilter_Coefficients_k[srcIdx];
  }

  /* Reverse copy the states from States_Dwork to ContextBuff_Dwork */
  for (srcIdx = 0; srcIdx < 150; srcIdx++) {
    single_fre_rev_DW.DigitalFilter_simContextBuf_d[149 - srcIdx] =
      single_fre_rev_DW.DigitalFilter_states_b[srcIdx];
  }

  /* Copy the initial part of input to ContextBuff_Dwork */
  memcpy(&single_fre_rev_DW.DigitalFilter_simContextBuf_d[150], &rtb_Gain[0],
         80U * sizeof(real32_T));
  for (srcIdx = 0; srcIdx < 80; srcIdx++) {
    acc = 0.0F;
    for (n = 0; n < 151; n++) {
      acc += single_fre_rev_DW.DigitalFilter_simContextBuf_d[srcIdx + n] *
        single_fre_rev_DW.DigitalFilter_simRevCoeff_i[n];
    }

    /* store output sample */
    rtb_DigitalFilter[srcIdx] = acc;
  }

  /* Shift state buffer when input buffer is shorter than state buffer */
  for (srcIdx = 69; srcIdx >= 0; srcIdx--) {
    single_fre_rev_DW.DigitalFilter_states_b[srcIdx + 80] =
      single_fre_rev_DW.DigitalFilter_states_b[srcIdx];
  }

  /* Reverse copy the states from input to States_Dwork */
  for (srcIdx = 0; srcIdx < 80; srcIdx++) {
    single_fre_rev_DW.DigitalFilter_states_b[79 - srcIdx] = rtb_Gain[srcIdx];

    /* Outport: '<Root>/out_f2' incorporates:
     *  DataTypeConversion: '<Root>/Data Type Conversion7'
     *  DiscreteFir: '<S2>/Digital Filter'
     */
    single_fre_rev_Y.out_f2[srcIdx] = rtb_DigitalFilter[srcIdx];
  }

  /* End of DiscreteFir: '<S2>/Digital Filter' */
}

/* Model initialize function */
void single_fre_rev_initialize(void)
{
  {
    int32_T i;
    for (i = 0; i < 150; i++) {
      /* InitializeConditions for DiscreteFir: '<S3>/Digital Filter' */
      single_fre_rev_DW.DigitalFilter_states[i] =
        single_fre_rev_P.DigitalFilter_InitialStates;

      /* InitializeConditions for DiscreteFir: '<S2>/Digital Filter' */
      single_fre_rev_DW.DigitalFilter_states_b[i] =
        single_fre_rev_P.DigitalFilter_InitialStates_f;
    }
  }
}

/* Model terminate function */
void single_fre_rev_terminate(void)
{
  /* (no terminate code required) */
}

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
