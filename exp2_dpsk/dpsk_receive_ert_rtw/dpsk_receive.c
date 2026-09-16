/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * File: dpsk_receive.c
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

#include "dpsk_receive.h"
#include <string.h>
#include <math.h>
#include "rtwtypes.h"

/* Block signals (default storage) */
B_dpsk_receive_T dpsk_receive_B;

/* Block states (default storage) */
DW_dpsk_receive_T dpsk_receive_DW;

/* External inputs (root inport signals with default storage) */
ExtU_dpsk_receive_T dpsk_receive_U;

/* External outputs (root outports fed by signals with default storage) */
ExtY_dpsk_receive_T dpsk_receive_Y;

/* Real-time model */
static RT_MODEL_dpsk_receive_T dpsk_receive_M_;
RT_MODEL_dpsk_receive_T *const dpsk_receive_M = &dpsk_receive_M_;

/* Model step function */
void dpsk_receive_step(void)
{
  real_T DigitalFilter_FILT_STATES;
  real_T DigitalFilter_FILT_STATES_0;
  real_T DigitalFilter_FILT_STATES_1;
  real_T DigitalFilter_FILT_STATES_2;
  real_T DigitalFilter_FILT_STATES_3;
  real_T DigitalFilter_FILT_STATES_4;
  int32_T out;
  int32_T q0;
  int32_T q1;
  real32_T rtb_y_p;
  static const real_T B[160] = { -0.981852785849589, -0.89703246776328183,
    -0.80655153455225215, -0.71039929565209281, -0.60857499718200858,
    -0.50108796507300257, -0.38795772871854378, -0.2692141246963472,
    -0.14489738015246487, -0.015058175482673629, 0.12024231400899653,
    0.26093239774868554, 0.40692987105534889, 0.55814203800712392,
    0.714465756142439, 0.875787503077922, 1.0419834650755577, 1.2129196475416884,
    1.3884520073903457, 1.5684266071530781, 1.7526797906672862,
    1.9410383801248605, 2.1333198942130962, 2.3293327870303511,
    2.5288767074098564, 2.7317427782367734, 2.9377138952958188,
    3.1465650451400782, 3.3580636414257503, 3.5719698791127694,
    3.7880371058878368, 4.0060122101239948, 4.2256360246502105,
    4.4466437455650389, 4.6687653652908416, 4.891726119029121,
    5.1152469437431574, 5.3390449487624148, 5.5628338970723323,
    5.5704230082163377, 6.0092258985838143, 6.2312442077777268,
    6.4520849938466931, 6.6714528125065407, 6.8890519295716572,
    7.104586848746453, 7.3177628417882312, 7.5282864799340663,
    7.7358661654781464, 7.9402126623809286, 8.14103962479054, 8.3380641223573289,
    8.53100716122616, 8.7195941995972586, 8.9035556567549712, 9.0826274144752261,
    9.2565513097362473, 9.42507561767352, 9.5879555237388168, 9.74495358404433,
    9.89584017289691, 10.040393916553151, 10.17840211225464, 10.309661131633202,
    10.433976807608666, 10.55116480393656, 10.66105096659988, 10.763471656277895,
    10.858274061165401, 10.945316489458245, 11.024468640864733,
    11.095611856548016, 11.158639346951484, 11.213456397007187,
    11.259980548276875, 11.298141757625469, 11.327882532078341,
    11.349158039565909, 11.361936195311969, 11.366197723675814,
    11.361936195311969, 11.349158039565909, 11.327882532078341,
    11.298141757625469, 11.259980548276875, 11.213456397007187,
    11.158639346951482, 11.095611856548015, 11.024468640864729,
    10.945316489458243, 10.858274061165398, 10.763471656277895,
    10.661050966599879, 10.551164803936558, 10.43397680760866,
    10.309661131633199, 10.17840211225464, 10.040393916553146,
    9.8958401728969054, 9.7449535840443229, 9.5879555237388132,
    9.4250756176735173, 9.25655130973624, 9.0826274144752173, 8.9035556567549641,
    8.7195941995972532, 8.5310071612261549, 8.3380641223573182,
    8.141039624790535, 7.9402126623809188, 7.735866165478142, 7.528286479934061,
    7.3177628417882215, 7.1045868487464556, 6.8890519295716439,
    6.6714528125065282, 6.45208499384668, 6.2312442077777019, 6.0092258985838152,
    5.5704230082163377, 5.5628338970723226, 5.339044948762429,
    5.1152469437431618, 4.8917261190291166, 4.6687653652908407,
    4.4466437455650247, 4.2256360246502034, 4.0060122101239868, 3.78803710588783,
    3.5719698791127628, 3.3580636414257414, 3.1465650451400733,
    2.9377138952958108, 2.7317427782367663, 2.5288767074098488,
    2.329332787030344, 2.1333198942130913, 1.9410383801248525,
    1.7526797906672793, 1.5684266071530715, 1.3884520073903397,
    1.2129196475416839, 1.0419834650755502, 0.87578750307791631,
    0.71446575614243313, 0.55814203800711937, 0.40692987105534523,
    0.2609323977486791, 0.1202423140089906, -0.015058175482678061,
    -0.14489738015246895, -0.26921412469635114, -0.38795772871854917,
    -0.50108796507300746, -0.60857499718201158, -0.71039929565209536,
    -0.80655153455225526, -0.8970324677632856, -0.98185278584959279,
    -1.0610329539459695 };

  /* MATLAB Function: '<S6>/MATLAB Function10' incorporates:
   *  Delay: '<S6>/Delay'
   */
  for (out = 0; out < 7; out++) {
    dpsk_receive_B.y_b[out] = dpsk_receive_DW.temp2[out];
  }

  memcpy(&dpsk_receive_B.y_b[7], &dpsk_receive_DW.Delay_DSTATE[0], 73U * sizeof
         (real_T));
  for (out = 0; out < 7; out++) {
    dpsk_receive_DW.temp2[out] = dpsk_receive_DW.Delay_DSTATE[out + 73];
  }

  /* End of MATLAB Function: '<S6>/MATLAB Function10' */
  for (out = 0; out < 80; out++) {
    /* Sum: '<S3>/Matrix Sum' incorporates:
     *  Inport: '<Root>/AudioIn'
     */
    q0 = dpsk_receive_U.AudioIn[out];
    q1 = dpsk_receive_U.AudioIn[out + 80];
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

    /* Gain: '<S3>/Gain' incorporates:
     *  DataTypeConversion: '<S3>/ 1'
     *  Sum: '<S3>/Matrix Sum'
     */
    dpsk_receive_B.Gain[out] = dpsk_receive_P.Gain_Gain * (real32_T)(int16_T)q0;
  }

  /* DiscreteFir: '<S7>/Digital Filter' incorporates:
   *  Gain: '<S3>/Gain'
   */
  /* Reverse the coefficients */
  for (out = 0; out < 151; out++) {
    dpsk_receive_DW.DigitalFilter_simRevCoeff_i[150 - out] =
      dpsk_receive_P.DigitalFilter_Coefficients_k[out];
  }

  /* Reverse copy the states from States_Dwork to ContextBuff_Dwork */
  for (out = 0; out < 150; out++) {
    dpsk_receive_DW.DigitalFilter_simContextBuf_d[149 - out] =
      dpsk_receive_DW.DigitalFilter_states_b[out];
  }

  /* Copy the initial part of input to ContextBuff_Dwork */
  memcpy(&dpsk_receive_DW.DigitalFilter_simContextBuf_d[150],
         &dpsk_receive_B.Gain[0], 80U * sizeof(real32_T));
  for (out = 0; out < 80; out++) {
    rtb_y_p = 0.0F;
    for (q0 = 0; q0 < 151; q0++) {
      rtb_y_p += dpsk_receive_DW.DigitalFilter_simContextBuf_d[out + q0] *
        dpsk_receive_DW.DigitalFilter_simRevCoeff_i[q0];
    }

    /* store output sample */
    dpsk_receive_B.DigitalFilter_a[out] = rtb_y_p;
  }

  /* Shift state buffer when input buffer is shorter than state buffer */
  for (out = 69; out >= 0; out--) {
    dpsk_receive_DW.DigitalFilter_states_b[out + 80] =
      dpsk_receive_DW.DigitalFilter_states_b[out];
  }

  /* Reverse copy the states from input to States_Dwork */
  for (out = 0; out < 80; out++) {
    dpsk_receive_DW.DigitalFilter_states_b[79 - out] = dpsk_receive_B.Gain[out];

    /* MATLAB Function: '<Root>/码元延迟' incorporates:
     *  DiscreteFir: '<S7>/Digital Filter'
     */
    dpsk_receive_B.rtb_y_m_m = dpsk_receive_DW.temp[out];
    rtb_y_p = dpsk_receive_B.DigitalFilter_a[out];
    dpsk_receive_DW.temp[out] = rtb_y_p;

    /* Product: '<Root>/Product' incorporates:
     *  DiscreteFir: '<S7>/Digital Filter'
     *  Product: '<S9>/Product2'
     */
    dpsk_receive_B.y_m[out] = rtb_y_p * dpsk_receive_B.rtb_y_m_m;
  }

  /* End of DiscreteFir: '<S7>/Digital Filter' */

  /* DiscreteFir: '<S4>/Digital Filter' incorporates:
   *  Product: '<S9>/Product2'
   */
  /* Reverse the coefficients */
  for (out = 0; out < 201; out++) {
    dpsk_receive_DW.DigitalFilter_simRevCoeff[200 - out] =
      dpsk_receive_P.DigitalFilter_Coefficients[out];
  }

  /* Reverse copy the states from States_Dwork to ContextBuff_Dwork */
  for (out = 0; out < 200; out++) {
    dpsk_receive_DW.DigitalFilter_simContextBuf[199 - out] =
      dpsk_receive_DW.DigitalFilter_states[out];
  }

  /* Copy the initial part of input to ContextBuff_Dwork */
  memcpy(&dpsk_receive_DW.DigitalFilter_simContextBuf[200], &dpsk_receive_B.y_m
         [0], 80U * sizeof(real_T));
  for (out = 0; out < 80; out++) {
    dpsk_receive_B.rtb_y_m_m = 0.0;
    for (q0 = 0; q0 < 201; q0++) {
      dpsk_receive_B.rtb_y_m_m +=
        dpsk_receive_DW.DigitalFilter_simContextBuf[out + q0] *
        dpsk_receive_DW.DigitalFilter_simRevCoeff[q0];
    }

    /* store output sample */
    dpsk_receive_B.DigitalFilter[out] = dpsk_receive_B.rtb_y_m_m;
  }

  /* Shift state buffer when input buffer is shorter than state buffer */
  for (out = 119; out >= 0; out--) {
    dpsk_receive_DW.DigitalFilter_states[out + 80] =
      dpsk_receive_DW.DigitalFilter_states[out];
  }

  /* Reverse copy the states from input to States_Dwork */
  for (out = 0; out < 80; out++) {
    dpsk_receive_DW.DigitalFilter_states[79 - out] = dpsk_receive_B.y_m[out];
  }

  /* End of DiscreteFir: '<S4>/Digital Filter' */

  /* MATLAB Function: '<S9>/MATLAB Function10' incorporates:
   *  DiscreteFir: '<S4>/Digital Filter'
   */
  for (out = 0; out < 40; out++) {
    dpsk_receive_B.y_m[out] = dpsk_receive_DW.temp1[out];
    dpsk_receive_B.y_m[out + 40] = dpsk_receive_B.DigitalFilter[out];
    dpsk_receive_DW.temp1[out] = dpsk_receive_B.DigitalFilter[out + 40];
  }

  /* End of MATLAB Function: '<S9>/MATLAB Function10' */

  /* S-Function (sdspbiquad): '<S16>/Digital Filter' */
  dpsk_receive_B.rtb_y_m_m = dpsk_receive_DW.DigitalFilter_FILT_STATES[0];
  dpsk_receive_B.DigitalFilter_FILT_STATES =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[1];
  dpsk_receive_B.DigitalFilter_FILT_STATES_c =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[2];
  dpsk_receive_B.DigitalFilter_FILT_STATES_k =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[3];
  dpsk_receive_B.DigitalFilter_FILT_STATES_cx =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[4];
  dpsk_receive_B.DigitalFilter_FILT_STATES_b =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[5];
  dpsk_receive_B.DigitalFilter_FILT_STATES_p =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[6];
  dpsk_receive_B.DigitalFilter_FILT_STATES_cv =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[7];
  dpsk_receive_B.DigitalFilter_FILT_STATES_f =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[8];
  dpsk_receive_B.DigitalFilter_FILT_STATES_g =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[9];
  dpsk_receive_B.DigitalFilter_FILT_STATES_g1 =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[10];
  dpsk_receive_B.DigitalFilter_FILT_STATES_m =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[11];
  dpsk_receive_B.DigitalFilter_FILT_STATES_n =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[12];
  dpsk_receive_B.DigitalFilter_FILT_STATES_pp =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[13];
  dpsk_receive_B.DigitalFilter_FILT_STATES_l =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[14];
  dpsk_receive_B.DigitalFilter_FILT_STATES_j =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[15];
  dpsk_receive_B.DigitalFilter_FILT_STATES_d =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[16];
  dpsk_receive_B.DigitalFilter_FILT_STATES_gu =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[17];
  dpsk_receive_B.DigitalFilter_FILT_STATES_ld =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[18];
  dpsk_receive_B.DigitalFilter_FILT_STATES_dh =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[19];
  dpsk_receive_B.DigitalFilter_FILT_STATES_dy =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[20];
  dpsk_receive_B.DigitalFilter_FILT_STATES_lx =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[21];
  dpsk_receive_B.DigitalFilter_FILT_STATES_o =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[22];
  dpsk_receive_B.DigitalFilter_FILT_STATES_bj =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[23];
  dpsk_receive_B.DigitalFilter_FILT_STATES_nu =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[24];
  dpsk_receive_B.DigitalFilter_FILT_STATES_bs =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[25];
  dpsk_receive_B.DigitalFilter_FILT_STATES_ln =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[26];
  dpsk_receive_B.DigitalFilter_FILT_STATES_h =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[27];
  dpsk_receive_B.DigitalFilter_FILT_STATES_bn =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[28];
  dpsk_receive_B.DigitalFilter_FILT_STATES_da =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[29];
  dpsk_receive_B.DigitalFilter_FILT_STATES_e =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[30];
  dpsk_receive_B.DigitalFilter_FILT_STATES_bjv =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[31];
  dpsk_receive_B.DigitalFilter_FILT_STATES_jz =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[32];
  dpsk_receive_B.DigitalFilter_FILT_STATES_fd =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[33];
  dpsk_receive_B.DigitalFilter_FILT_STATES_a =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[34];
  dpsk_receive_B.DigitalFilter_FILT_STATES_ju =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[35];
  dpsk_receive_B.DigitalFilter_FILT_STATES_jz5 =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[36];
  dpsk_receive_B.DigitalFilter_FILT_STATES_o4 =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[37];
  dpsk_receive_B.DigitalFilter_FILT_STATES_ny =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[38];
  dpsk_receive_B.DigitalFilter_FILT_STATES_i =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[39];
  dpsk_receive_B.DigitalFilter_FILT_STATES_oy =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[40];
  dpsk_receive_B.DigitalFilter_FILT_STATES_nv =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[41];
  dpsk_receive_B.DigitalFilter_FILT_STATES_m3 =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[42];
  dpsk_receive_B.DigitalFilter_FILT_STATES_cz =
    dpsk_receive_DW.DigitalFilter_FILT_STATES[43];
  DigitalFilter_FILT_STATES = dpsk_receive_DW.DigitalFilter_FILT_STATES[44];
  DigitalFilter_FILT_STATES_0 = dpsk_receive_DW.DigitalFilter_FILT_STATES[45];
  DigitalFilter_FILT_STATES_1 = dpsk_receive_DW.DigitalFilter_FILT_STATES[46];
  DigitalFilter_FILT_STATES_2 = dpsk_receive_DW.DigitalFilter_FILT_STATES[47];
  DigitalFilter_FILT_STATES_3 = dpsk_receive_DW.DigitalFilter_FILT_STATES[48];
  DigitalFilter_FILT_STATES_4 = dpsk_receive_DW.DigitalFilter_FILT_STATES[49];
  for (out = 0; out < 80; out++) {
    /* S-Function (sdspbiquad): '<S16>/Digital Filter' incorporates:
     *  DiscreteFir: '<S4>/Digital Filter'
     *  Product: '<S9>/Product2'
     */
    dpsk_receive_B.denAccum = (dpsk_receive_B.y_m[out] *
      dpsk_receive_B.DigitalFilter[out] * 0.0039260127855105477 -
      -1.9926885993155952 * dpsk_receive_B.rtb_y_m_m) - 0.99948242481080218 *
      dpsk_receive_B.DigitalFilter_FILT_STATES;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.rtb_y_m_m +
      dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES;
    dpsk_receive_B.DigitalFilter_FILT_STATES = dpsk_receive_B.rtb_y_m_m;
    dpsk_receive_B.rtb_y_m_m = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039260127855105477 * dpsk_receive_B.numAccum -
      -1.9939672350124602 * dpsk_receive_B.DigitalFilter_FILT_STATES_c) -
      0.99953151783529937 * dpsk_receive_B.DigitalFilter_FILT_STATES_k;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_c
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_k;
    dpsk_receive_B.DigitalFilter_FILT_STATES_k =
      dpsk_receive_B.DigitalFilter_FILT_STATES_c;
    dpsk_receive_B.DigitalFilter_FILT_STATES_c = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.00392409429108312 * dpsk_receive_B.numAccum -
      -1.9916776810697203 * dpsk_receive_B.DigitalFilter_FILT_STATES_cx) -
      0.9984573772836477 * dpsk_receive_B.DigitalFilter_FILT_STATES_b;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_cx
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_b;
    dpsk_receive_B.DigitalFilter_FILT_STATES_b =
      dpsk_receive_B.DigitalFilter_FILT_STATES_cx;
    dpsk_receive_B.DigitalFilter_FILT_STATES_cx = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.00392409429108312 * dpsk_receive_B.numAccum -
      -1.9930310110078724 * dpsk_receive_B.DigitalFilter_FILT_STATES_p) -
      0.99860144200763878 * dpsk_receive_B.DigitalFilter_FILT_STATES_cv;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_p
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_cv;
    dpsk_receive_B.DigitalFilter_FILT_STATES_cv =
      dpsk_receive_B.DigitalFilter_FILT_STATES_p;
    dpsk_receive_B.DigitalFilter_FILT_STATES_p = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.003922224011216403 * dpsk_receive_B.numAccum -
      -1.990705787503122 * dpsk_receive_B.DigitalFilter_FILT_STATES_f) -
      0.99746103378932127 * dpsk_receive_B.DigitalFilter_FILT_STATES_g;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_f
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_g;
    dpsk_receive_B.DigitalFilter_FILT_STATES_g =
      dpsk_receive_B.DigitalFilter_FILT_STATES_f;
    dpsk_receive_B.DigitalFilter_FILT_STATES_f = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.003922224011216403 * dpsk_receive_B.numAccum -
      -1.9921056129968959 * dpsk_receive_B.DigitalFilter_FILT_STATES_g1) -
      0.99769087776152576 * dpsk_receive_B.DigitalFilter_FILT_STATES_m;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_g1
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_m;
    dpsk_receive_B.DigitalFilter_FILT_STATES_m =
      dpsk_receive_B.DigitalFilter_FILT_STATES_g1;
    dpsk_receive_B.DigitalFilter_FILT_STATES_g1 = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039204311781902094 * dpsk_receive_B.numAccum -
      -1.9897900445329011 * dpsk_receive_B.DigitalFilter_FILT_STATES_n) -
      0.99651101256242625 * dpsk_receive_B.DigitalFilter_FILT_STATES_pp;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_n
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_pp;
    dpsk_receive_B.DigitalFilter_FILT_STATES_pp =
      dpsk_receive_B.DigitalFilter_FILT_STATES_n;
    dpsk_receive_B.DigitalFilter_FILT_STATES_n = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039204311781902094 * dpsk_receive_B.numAccum -
      -1.9912034788501347 * dpsk_receive_B.DigitalFilter_FILT_STATES_l) -
      0.99681209868830367 * dpsk_receive_B.DigitalFilter_FILT_STATES_j;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_l
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_j;
    dpsk_receive_B.DigitalFilter_FILT_STATES_j =
      dpsk_receive_B.DigitalFilter_FILT_STATES_l;
    dpsk_receive_B.DigitalFilter_FILT_STATES_l = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039187436963530548 * dpsk_receive_B.numAccum -
      -1.9889462818238415 * dpsk_receive_B.DigitalFilter_FILT_STATES_d) -
      0.99562382297871344 * dpsk_receive_B.DigitalFilter_FILT_STATES_gu;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_d
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_gu;
    dpsk_receive_B.DigitalFilter_FILT_STATES_gu =
      dpsk_receive_B.DigitalFilter_FILT_STATES_d;
    dpsk_receive_B.DigitalFilter_FILT_STATES_d = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039187436963530548 * dpsk_receive_B.numAccum -
      -1.9903369465925218 * dpsk_receive_B.DigitalFilter_FILT_STATES_ld) -
      0.99597718303666449 * dpsk_receive_B.DigitalFilter_FILT_STATES_dh;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_ld
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_dh;
    dpsk_receive_B.DigitalFilter_FILT_STATES_dh =
      dpsk_receive_B.DigitalFilter_FILT_STATES_ld;
    dpsk_receive_B.DigitalFilter_FILT_STATES_ld = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039171877255021869 * dpsk_receive_B.numAccum -
      -1.9881886987966033 * dpsk_receive_B.DigitalFilter_FILT_STATES_dy) -
      0.9948145122404779 * dpsk_receive_B.DigitalFilter_FILT_STATES_lx;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_dy
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_lx;
    dpsk_receive_B.DigitalFilter_FILT_STATES_lx =
      dpsk_receive_B.DigitalFilter_FILT_STATES_dy;
    dpsk_receive_B.DigitalFilter_FILT_STATES_dy = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039171877255021869 * dpsk_receive_B.numAccum -
      -1.9895181760263445 * dpsk_receive_B.DigitalFilter_FILT_STATES_o) -
      0.995197932703587 * dpsk_receive_B.DigitalFilter_FILT_STATES_bj;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_o
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_bj;
    dpsk_receive_B.DigitalFilter_FILT_STATES_bj =
      dpsk_receive_B.DigitalFilter_FILT_STATES_o;
    dpsk_receive_B.DigitalFilter_FILT_STATES_o = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039157872968031329 * dpsk_receive_B.numAccum -
      -1.9875295862164095 * dpsk_receive_B.DigitalFilter_FILT_STATES_nu) -
      0.994096363551665 * dpsk_receive_B.DigitalFilter_FILT_STATES_bs;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_nu
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_bs;
    dpsk_receive_B.DigitalFilter_FILT_STATES_bs =
      dpsk_receive_B.DigitalFilter_FILT_STATES_nu;
    dpsk_receive_B.DigitalFilter_FILT_STATES_nu = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039157872968031329 * dpsk_receive_B.numAccum -
      -1.9887590500053363 * dpsk_receive_B.DigitalFilter_FILT_STATES_ln) -
      0.99448577146780726 * dpsk_receive_B.DigitalFilter_FILT_STATES_h;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_ln
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_h;
    dpsk_receive_B.DigitalFilter_FILT_STATES_h =
      dpsk_receive_B.DigitalFilter_FILT_STATES_ln;
    dpsk_receive_B.DigitalFilter_FILT_STATES_ln = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039145639655143805 * dpsk_receive_B.numAccum -
      -1.9869791111685691 * dpsk_receive_B.DigitalFilter_FILT_STATES_bn) -
      0.99348065457919621 * dpsk_receive_B.DigitalFilter_FILT_STATES_da;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_bn
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_da;
    dpsk_receive_B.DigitalFilter_FILT_STATES_da =
      dpsk_receive_B.DigitalFilter_FILT_STATES_bn;
    dpsk_receive_B.DigitalFilter_FILT_STATES_bn = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039145639655143805 * dpsk_receive_B.numAccum -
      -1.9880710510747635 * dpsk_receive_B.DigitalFilter_FILT_STATES_e) -
      0.99385161869602667 * dpsk_receive_B.DigitalFilter_FILT_STATES_bjv;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_e
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_bjv;
    dpsk_receive_B.DigitalFilter_FILT_STATES_bjv =
      dpsk_receive_B.DigitalFilter_FILT_STATES_e;
    dpsk_receive_B.DigitalFilter_FILT_STATES_e = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039135365040263524 * dpsk_receive_B.numAccum -
      -1.9865451701715173 * dpsk_receive_B.DigitalFilter_FILT_STATES_jz) -
      0.99297648196738009 * dpsk_receive_B.DigitalFilter_FILT_STATES_fd;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_jz
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_fd;
    dpsk_receive_B.DigitalFilter_FILT_STATES_fd =
      dpsk_receive_B.DigitalFilter_FILT_STATES_jz;
    dpsk_receive_B.DigitalFilter_FILT_STATES_jz = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039135365040263524 * dpsk_receive_B.numAccum -
      -1.9874651114118582 * dpsk_receive_B.DigitalFilter_FILT_STATES_a) -
      0.993305737146747 * dpsk_receive_B.DigitalFilter_FILT_STATES_ju;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_a
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_ju;
    dpsk_receive_B.DigitalFilter_FILT_STATES_ju =
      dpsk_receive_B.DigitalFilter_FILT_STATES_a;
    dpsk_receive_B.DigitalFilter_FILT_STATES_a = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039127206380320679 * dpsk_receive_B.numAccum -
      -1.9862333125041784 * dpsk_receive_B.DigitalFilter_FILT_STATES_jz5) -
      0.99259065507069344 * dpsk_receive_B.DigitalFilter_FILT_STATES_o4;
    dpsk_receive_B.numAccum = (0.0 *
      dpsk_receive_B.DigitalFilter_FILT_STATES_jz5 + dpsk_receive_B.denAccum) -
      dpsk_receive_B.DigitalFilter_FILT_STATES_o4;
    dpsk_receive_B.DigitalFilter_FILT_STATES_o4 =
      dpsk_receive_B.DigitalFilter_FILT_STATES_jz5;
    dpsk_receive_B.DigitalFilter_FILT_STATES_jz5 = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039127206380320679 * dpsk_receive_B.numAccum -
      -1.9869514359569194 * dpsk_receive_B.DigitalFilter_FILT_STATES_ny) -
      0.9928575554941198 * dpsk_receive_B.DigitalFilter_FILT_STATES_i;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_ny
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_i;
    dpsk_receive_B.DigitalFilter_FILT_STATES_i =
      dpsk_receive_B.DigitalFilter_FILT_STATES_ny;
    dpsk_receive_B.DigitalFilter_FILT_STATES_ny = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039121288280308869 * dpsk_receive_B.numAccum -
      -1.9860467321113791 * dpsk_receive_B.DigitalFilter_FILT_STATES_oy) -
      0.99232765852208293 * dpsk_receive_B.DigitalFilter_FILT_STATES_nv;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_oy
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_nv;
    dpsk_receive_B.DigitalFilter_FILT_STATES_nv =
      dpsk_receive_B.DigitalFilter_FILT_STATES_oy;
    dpsk_receive_B.DigitalFilter_FILT_STATES_oy = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039121288280308869 * dpsk_receive_B.numAccum -
      -1.9865393017489448 * dpsk_receive_B.DigitalFilter_FILT_STATES_m3) -
      0.99251546916361733 * dpsk_receive_B.DigitalFilter_FILT_STATES_cz;
    dpsk_receive_B.numAccum = (0.0 * dpsk_receive_B.DigitalFilter_FILT_STATES_m3
      + dpsk_receive_B.denAccum) - dpsk_receive_B.DigitalFilter_FILT_STATES_cz;
    dpsk_receive_B.DigitalFilter_FILT_STATES_cz =
      dpsk_receive_B.DigitalFilter_FILT_STATES_m3;
    dpsk_receive_B.DigitalFilter_FILT_STATES_m3 = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039117700978301747 * dpsk_receive_B.numAccum -
      -1.9859863240782722 * DigitalFilter_FILT_STATES) - 0.99218968052768863 *
      DigitalFilter_FILT_STATES_0;
    dpsk_receive_B.numAccum = (0.0 * DigitalFilter_FILT_STATES +
      dpsk_receive_B.denAccum) - DigitalFilter_FILT_STATES_0;
    DigitalFilter_FILT_STATES_0 = DigitalFilter_FILT_STATES;
    DigitalFilter_FILT_STATES = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039117700978301747 * dpsk_receive_B.numAccum -
      -1.9862368383909228 * DigitalFilter_FILT_STATES_1) - 0.99228662523168421 *
      DigitalFilter_FILT_STATES_2;
    dpsk_receive_B.numAccum = (0.0 * DigitalFilter_FILT_STATES_1 +
      dpsk_receive_B.denAccum) - DigitalFilter_FILT_STATES_2;
    DigitalFilter_FILT_STATES_2 = DigitalFilter_FILT_STATES_1;
    DigitalFilter_FILT_STATES_1 = dpsk_receive_B.denAccum;
    dpsk_receive_B.denAccum = (0.0039116499112486908 * dpsk_receive_B.numAccum -
      -1.9860507979463005 * DigitalFilter_FILT_STATES_3) - 0.99217670017750259 *
      DigitalFilter_FILT_STATES_4;
    dpsk_receive_B.y_m[out] = (0.0 * DigitalFilter_FILT_STATES_3 +
      dpsk_receive_B.denAccum) - DigitalFilter_FILT_STATES_4;
    DigitalFilter_FILT_STATES_4 = DigitalFilter_FILT_STATES_3;
    DigitalFilter_FILT_STATES_3 = dpsk_receive_B.denAccum;
  }

  /* S-Function (sdspbiquad): '<S16>/Digital Filter' */
  dpsk_receive_DW.DigitalFilter_FILT_STATES[49] = DigitalFilter_FILT_STATES_4;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[48] = DigitalFilter_FILT_STATES_3;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[47] = DigitalFilter_FILT_STATES_2;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[46] = DigitalFilter_FILT_STATES_1;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[45] = DigitalFilter_FILT_STATES_0;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[44] = DigitalFilter_FILT_STATES;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[43] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_cz;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[42] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_m3;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[41] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_nv;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[40] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_oy;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[39] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_i;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[38] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_ny;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[37] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_o4;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[36] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_jz5;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[35] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_ju;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[34] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_a;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[33] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_fd;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[32] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_jz;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[31] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_bjv;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[30] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_e;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[29] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_da;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[28] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_bn;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[27] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_h;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[26] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_ln;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[25] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_bs;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[24] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_nu;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[23] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_bj;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[22] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_o;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[21] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_lx;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[20] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_dy;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[19] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_dh;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[18] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_ld;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[17] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_gu;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[16] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_d;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[15] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_j;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[14] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_l;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[13] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_pp;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[12] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_n;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[11] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_m;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[10] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_g1;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[9] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_g;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[8] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_f;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[7] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_cv;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[6] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_p;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[5] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_b;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[4] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_cx;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[3] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_k;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[2] =
    dpsk_receive_B.DigitalFilter_FILT_STATES_c;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[1] =
    dpsk_receive_B.DigitalFilter_FILT_STATES;
  dpsk_receive_DW.DigitalFilter_FILT_STATES[0] = dpsk_receive_B.rtb_y_m_m;

  /* MATLAB Function: '<Root>/抽样' incorporates:
   *  S-Function (sdspbiquad): '<S16>/Digital Filter'
   */
  if (dpsk_receive_DW.Am > 0.0) {
    for (q0 = 0; q0 < 79; q0++) {
      if ((dpsk_receive_B.y_m[q0] < 0.0) && (dpsk_receive_B.y_m[q0 + 2] > 0.0) &&
          (dpsk_receive_B.y_m[q0 + 1] > 0.0)) {
        dpsk_receive_DW.loc = (real_T)q0 + 2.0;
      }
    }

    if (dpsk_receive_B.y_b[(int32_T)dpsk_receive_DW.loc - 1] > 0.0) {
      out = 1;
    } else {
      out = -1;
    }

    if (dpsk_receive_DW.code * (real_T)out < 0.0) {
      dpsk_receive_DW.count++;
    } else {
      dpsk_receive_DW.count = 0.0;
    }

    dpsk_receive_DW.code = out;
  } else {
    dpsk_receive_DW.count = 0.0;
  }

  if (dpsk_receive_DW.count == 4.0) {
    dpsk_receive_DW.flag++;
    if (dpsk_receive_DW.flag == 1.0) {
      dpsk_receive_DW.position = dpsk_receive_DW.loc;
      dpsk_receive_DW.flag = 2.0;
    }
  }

  if (dpsk_receive_DW.position > 0.0) {
    /* Outport: '<Root>/out_data' */
    dpsk_receive_Y.out_data = dpsk_receive_B.y_b[(int32_T)
      dpsk_receive_DW.position - 1] / 80.0;
  } else {
    /* Outport: '<Root>/out_data' */
    dpsk_receive_Y.out_data = 0.0;
  }

  /* End of MATLAB Function: '<Root>/抽样' */

  /* Delay: '<Root>/Delay2' */
  memcpy(&dpsk_receive_B.y_b[0], &dpsk_receive_DW.Delay2_DSTATE[0], 80U * sizeof
         (real_T));

  /* MATLAB Function: '<Root>/匹配滤波' incorporates:
   *  Delay: '<Root>/Delay2'
   *  DiscreteFir: '<S4>/Digital Filter'
   */
  memset(&dpsk_receive_B.temp[0], 0, 239U * sizeof(real_T));
  for (out = 0; out < 80; out++) {
    for (q0 = 0; q0 < 160; q0++) {
      q1 = out + q0;
      dpsk_receive_B.temp[q1] += dpsk_receive_B.DigitalFilter[out] * B[q0];
    }
  }

  for (out = 0; out < 80; out++) {
    dpsk_receive_DW.Delay2_DSTATE[out] = dpsk_receive_B.temp[out + 80];

    /* Product: '<S1>/Product2' incorporates:
     *  Delay: '<Root>/Delay2'
     *  DiscreteFir: '<S7>/Digital Filter'
     */
    rtb_y_p = dpsk_receive_B.DigitalFilter_a[out];
    dpsk_receive_B.Gain[out] = rtb_y_p * rtb_y_p;
  }

  /* MATLAB Function: '<S1>/MATLAB Function8' incorporates:
   *  Product: '<S1>/Product2'
   */
  rtb_y_p = dpsk_receive_B.Gain[0];
  for (out = 0; out < 79; out++) {
    rtb_y_p += dpsk_receive_B.Gain[out + 1];
  }

  rtb_y_p = (real32_T)sqrt(rtb_y_p / 80.0F * 2.0F);

  /* End of MATLAB Function: '<S1>/MATLAB Function8' */

  /* MATLAB Function: '<S1>/MATLAB Function6' */
  if (rtb_y_p > 8.0F) {
    dpsk_receive_DW.loc_e++;
  } else {
    dpsk_receive_DW.loc_e = 0.0;
  }

  if (dpsk_receive_DW.loc_e > 10.0) {
    dpsk_receive_DW.flag_k++;
  }

  if (dpsk_receive_DW.flag_k == 1.0) {
    dpsk_receive_DW.Am = rtb_y_p;
  }

  /* End of MATLAB Function: '<S1>/MATLAB Function6' */

  /* Update for Delay: '<S6>/Delay' incorporates:
   *  Delay: '<Root>/Delay1'
   *  MATLAB Function: '<Root>/MATLAB Function7'
   *  MATLAB Function: '<Root>/匹配滤波'
   *  Sum: '<Root>/Add'
   */
  for (out = 0; out < 3120; out++) {
    dpsk_receive_DW.Delay_DSTATE[out] = dpsk_receive_DW.Delay_DSTATE[out + 80];
  }

  dpsk_receive_DW.Delay_DSTATE[3199] = dpsk_receive_B.y_b[79] +
    dpsk_receive_B.temp[79];
  for (out = 0; out < 79; out++) {
    dpsk_receive_DW.Delay_DSTATE[out + 3120] =
      (dpsk_receive_DW.Delay1_DSTATE[out] + dpsk_receive_B.y_b[out]) +
      dpsk_receive_B.temp[out];

    /* Update for Delay: '<Root>/Delay1' incorporates:
     *  MATLAB Function: '<Root>/MATLAB Function7'
     */
    dpsk_receive_DW.Delay1_DSTATE[out] = dpsk_receive_DW.Delay1_DSTATE[out + 79];
    dpsk_receive_DW.Delay1_DSTATE[out + 79] = dpsk_receive_B.temp[out + 160];
  }

  /* End of Update for Delay: '<S6>/Delay' */
}

/* Model initialize function */
void dpsk_receive_initialize(void)
{
  {
    int32_T i;

    /* Start for DataStoreMemory: '<Root>/Data Store Memory' */
    dpsk_receive_DW.Am = dpsk_receive_P.DataStoreMemory_InitialValue;

    /* Start for DataStoreMemory: '<Root>/Data Store Memory3' */
    dpsk_receive_DW.position = dpsk_receive_P.DataStoreMemory3_InitialValue;

    /* InitializeConditions for Delay: '<S6>/Delay' */
    for (i = 0; i < 3200; i++) {
      dpsk_receive_DW.Delay_DSTATE[i] = dpsk_receive_P.Delay_InitialCondition;
    }

    /* End of InitializeConditions for Delay: '<S6>/Delay' */

    /* InitializeConditions for DiscreteFir: '<S7>/Digital Filter' */
    for (i = 0; i < 150; i++) {
      dpsk_receive_DW.DigitalFilter_states_b[i] =
        dpsk_receive_P.DigitalFilter_InitialStates_f;
    }

    /* End of InitializeConditions for DiscreteFir: '<S7>/Digital Filter' */

    /* InitializeConditions for DiscreteFir: '<S4>/Digital Filter' */
    for (i = 0; i < 200; i++) {
      dpsk_receive_DW.DigitalFilter_states[i] =
        dpsk_receive_P.DigitalFilter_InitialStates;
    }

    /* End of InitializeConditions for DiscreteFir: '<S4>/Digital Filter' */

    /* InitializeConditions for Delay: '<Root>/Delay1' */
    for (i = 0; i < 158; i++) {
      dpsk_receive_DW.Delay1_DSTATE[i] = dpsk_receive_P.Delay1_InitialCondition;
    }

    /* End of InitializeConditions for Delay: '<Root>/Delay1' */

    /* InitializeConditions for Delay: '<Root>/Delay2' */
    for (i = 0; i < 80; i++) {
      dpsk_receive_DW.Delay2_DSTATE[i] = dpsk_receive_P.Delay2_InitialCondition;
    }

    /* End of InitializeConditions for Delay: '<Root>/Delay2' */
  }
}

/* Model terminate function */
void dpsk_receive_terminate(void)
{
  /* (no terminate code required) */
}

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
