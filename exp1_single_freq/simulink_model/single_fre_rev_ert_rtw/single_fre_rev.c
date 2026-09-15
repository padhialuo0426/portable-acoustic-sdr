/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: single_fre_rev.c
 *
 * Code generated for Simulink model 'single_fre_rev'.
 *
 * Model version                  : 12.2
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Tue Sep 15 12:28:55 2026
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
  int32_T q0;
  int32_T q0_0;
  int32_T q1;
  real32_T rtb_DigitalFilter[80];
  real32_T rtb_Gain[80];
  real32_T acc;
  for (q0_0 = 0; q0_0 < 80; q0_0++) {
    /* Sum: '<S1>/Matrix Sum' incorporates:
     *  Inport: '<Root>/AudioIn'
     */
    q0 = single_fre_rev_U.AudioIn[q0_0];
    q1 = single_fre_rev_U.AudioIn[q0_0 + 80];
    if ((q0 < 0) && (q1 < MIN_int32_T - q0)) {
      q0 = MIN_int32_T;
    } else if ((q0 > 0) && (q1 > MAX_int32_T - q0)) {
      q0 = MAX_int32_T;
    } else {
      q0 += q1;
    }

    if (q0 > 32767) {
      q0 = 32767;
    } else if (q0 < -32768) {
      q0 = -32768;
    }

    /* Gain: '<S1>/Gain' incorporates:
     *  DataTypeConversion: '<S1>/ 1'
     *  Sum: '<S1>/Matrix Sum'
     */
    rtb_Gain[q0_0] = single_fre_rev_P.Gain_Gain * (real32_T)(int16_T)q0;
  }

  /* DiscreteFir: '<S3>/Digital Filter' incorporates:
   *  DiscreteFir: '<S2>/Digital Filter'
   *  Gain: '<S1>/Gain'
   */
  /* Reverse the coefficients */
  for (q0_0 = 0; q0_0 < 151; q0_0++) {
    single_fre_rev_DW.DigitalFilter_simRevCoeff[150 - q0_0] =
      single_fre_rev_P.DigitalFilter_Coefficients[q0_0];
  }

  /* Reverse copy the states from States_Dwork to ContextBuff_Dwork */
  for (q0_0 = 0; q0_0 < 150; q0_0++) {
    single_fre_rev_DW.DigitalFilter_simContextBuf[149 - q0_0] =
      single_fre_rev_DW.DigitalFilter_states[q0_0];
  }

  /* Copy the initial part of input to ContextBuff_Dwork */
  memcpy(&single_fre_rev_DW.DigitalFilter_simContextBuf[150], &rtb_Gain[0], 80U *
         sizeof(real32_T));
  for (q0_0 = 0; q0_0 < 80; q0_0++) {
    acc = 0.0F;
    for (q0 = 0; q0 < 151; q0++) {
      acc += single_fre_rev_DW.DigitalFilter_simContextBuf[q0_0 + q0] *
        single_fre_rev_DW.DigitalFilter_simRevCoeff[q0];
    }

    /* store output sample */
    rtb_DigitalFilter[q0_0] = acc;
  }

  /* Shift state buffer when input buffer is shorter than state buffer */
  for (q0_0 = 69; q0_0 >= 0; q0_0--) {
    single_fre_rev_DW.DigitalFilter_states[q0_0 + 80] =
      single_fre_rev_DW.DigitalFilter_states[q0_0];
  }

  /* Reverse copy the states from input to States_Dwork */
  for (q0_0 = 0; q0_0 < 80; q0_0++) {
    single_fre_rev_DW.DigitalFilter_states[79 - q0_0] = rtb_Gain[q0_0];

    /* Outport: '<Root>/out_f1' incorporates:
     *  DataTypeConversion: '<Root>/Data Type Conversion6'
     *  DiscreteFir: '<S2>/Digital Filter'
     */
    single_fre_rev_Y.out_f1[q0_0] = rtb_DigitalFilter[q0_0];
  }

  /* End of DiscreteFir: '<S3>/Digital Filter' */

  /* DiscreteFir: '<S2>/Digital Filter' incorporates:
   *  Gain: '<S1>/Gain'
   */
  /* Reverse the coefficients */
  for (q0_0 = 0; q0_0 < 151; q0_0++) {
    single_fre_rev_DW.DigitalFilter_simRevCoeff_i[150 - q0_0] =
      single_fre_rev_P.DigitalFilter_Coefficients_k[q0_0];
  }

  /* Reverse copy the states from States_Dwork to ContextBuff_Dwork */
  for (q0_0 = 0; q0_0 < 150; q0_0++) {
    single_fre_rev_DW.DigitalFilter_simContextBuf_d[149 - q0_0] =
      single_fre_rev_DW.DigitalFilter_states_b[q0_0];
  }

  /* Copy the initial part of input to ContextBuff_Dwork */
  memcpy(&single_fre_rev_DW.DigitalFilter_simContextBuf_d[150], &rtb_Gain[0],
         80U * sizeof(real32_T));
  for (q0_0 = 0; q0_0 < 80; q0_0++) {
    acc = 0.0F;
    for (q0 = 0; q0 < 151; q0++) {
      acc += single_fre_rev_DW.DigitalFilter_simContextBuf_d[q0_0 + q0] *
        single_fre_rev_DW.DigitalFilter_simRevCoeff_i[q0];
    }

    /* store output sample */
    rtb_DigitalFilter[q0_0] = acc;
  }

  /* Shift state buffer when input buffer is shorter than state buffer */
  for (q0_0 = 69; q0_0 >= 0; q0_0--) {
    single_fre_rev_DW.DigitalFilter_states_b[q0_0 + 80] =
      single_fre_rev_DW.DigitalFilter_states_b[q0_0];
  }

  /* Reverse copy the states from input to States_Dwork */
  for (q0_0 = 0; q0_0 < 80; q0_0++) {
    single_fre_rev_DW.DigitalFilter_states_b[79 - q0_0] = rtb_Gain[q0_0];

    /* Outport: '<Root>/out_f2' incorporates:
     *  DataTypeConversion: '<Root>/Data Type Conversion7'
     *  DiscreteFir: '<S2>/Digital Filter'
     */
    single_fre_rev_Y.out_f2[q0_0] = rtb_DigitalFilter[q0_0];
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
