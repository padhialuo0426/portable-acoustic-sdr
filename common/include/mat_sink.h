/*
 * mat_sink.h ── 把逐帧数据落盘为 MATLAB Level-4 (.mat) 文件，复刻原模型
 * To File 块的输出：一个名为 <varname> 的 nrows×N double 矩阵，按列追加
 * （第 0 行为时间，其后为该帧样本）。生成的 .mat 可被 PC 端 GUI 的
 * `load(...)` 直接读取，与原树莓派工程的数据格式兼容。
 *
 * 纯标准 C (stdio)，无任何 MathWorks / 支持包依赖，全平台可用。
 */
#ifndef MAT_SINK_H_
#define MAT_SINK_H_

typedef struct mat_sink mat_sink_t;

/*
 * 打开一个 .mat 输出。
 *   path    : 文件路径，如 "single_f.mat"
 *   varname : MATLAB 变量名，如 "toFileData"
 *   nrows   : 每列元素个数（如 81 = 1 时间 + 80 样本）
 * 失败返回 NULL。
 */
mat_sink_t *mat_sink_open(const char *path, const char *varname, int nrows);

/* 追加一列（nrows 个 double，列优先）。返回 0 成功，<0 失败。 */
int mat_sink_write_col(mat_sink_t *s, const double *col);

/* 回填列数并关闭。允许传入 NULL。 */
void mat_sink_close(mat_sink_t *s);

#endif /* MAT_SINK_H_ */
