/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: rtmodel.h
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

#ifndef rtmodel_h_
#define rtmodel_h_
#include "chirp_rev_detect.h"

/* Macros generated for backwards compatibility  */
#ifndef rtmGetStopRequested
#define rtmGetStopRequested(rtm)       ((void*) 0)
#endif

/* Model wrapper function */
/* Use this function only if you need to maintain compatibility with an existing static main program. */
extern void chirp_rev_detect_step(int_T tid);

#endif                                 /* rtmodel_h_ */

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
