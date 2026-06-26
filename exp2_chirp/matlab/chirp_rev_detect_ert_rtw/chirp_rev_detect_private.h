/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: chirp_rev_detect_private.h
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

#ifndef chirp_rev_detect_private_h_
#define chirp_rev_detect_private_h_
#include "rtwtypes.h"
#include "chirp_rev_detect.h"
#include "chirp_rev_detect_types.h"

extern void chirp_rev_d_MATLABFunction8(const real32_T rtu_u[800], real32_T
  *rty_y);
extern void chirp_rev_d_MATLABFunction1(const real32_T rtu_u[800], const real_T
  rtu_u2[800], real32_T rty_y1[799], real32_T rty_y2[800],
  B_MATLABFunction1_chirp_rev_d_T *localB);
extern void chirp_rev_d_MATLABFunction2(const real32_T rtu_u[799], real32_T
  rty_y[800]);

#endif                                 /* chirp_rev_detect_private_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
