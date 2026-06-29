/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: rtmodel.c
 *
 * Code generated for Simulink model 'chirp_rev_detect'.
 *
 * Model version                  : 12.1
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Fri Jun 26 16:20:47 2026
 *
 * Target selection: ert.tlc
 * Embedded hardware selection: ARM Compatible->ARM Cortex-A (64-bit)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#include "rtmodel.h"

/* Use this function only if you need to maintain compatibility with an existing static main program. */
void chirp_rev_detect_step(int_T tid)
{
  switch (tid) {
   case 0 :
    chirp_rev_detect_step0();
    break;

   case 1 :
    chirp_rev_detect_step1();
    break;

   default :
    /* do nothing */
    break;
  }
}

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
