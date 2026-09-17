/*
 * mat_sink.c ── MATLAB Level-4 (.mat) 流式写入器
 *
 * MAT v4 数值矩阵格式：
 *   20 字节头: int32 type, int32 mrows, int32 ncols, int32 imagf, int32 namelen
 *   namelen 字节: 变量名(含结尾 '\0')
 *   mrows*ncols 个 double: 列优先
 * type = 1000*M + 100*O + 10*P + T；本机小端 double 全矩阵 => 0,0,0,0 = 0。
 *
 * 列数 N 在运行结束才知道，故先写占位 0，逐列追加，关闭时 fseek 回填。
 */
#include "mat_sink.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

struct mat_sink {
    FILE   *fp;
    long    ncols_off;   /* 头中 ncols 字段的文件偏移，用于回填 */
    int32_t nrows;
    int32_t ncols;
    int failed;
};

mat_sink_t *mat_sink_open(const char *path, const char *varname, int nrows)
{
    mat_sink_t *s = calloc(1, sizeof(*s));
    if (!s) return NULL;

    s->fp = fopen(path, "wb");
    if (!s->fp) {
        fprintf(stderr, "mat_sink: 无法创建 %s\n", path);
        free(s);
        return NULL;
    }
    s->nrows = (int32_t)nrows;
    s->ncols = 0;

    int32_t namelen = (int32_t)strlen(varname) + 1;
    int32_t type = 0, imagf = 0;

    int32_t header[5] = {type, s->nrows, 0, imagf, namelen};
    s->ncols_off = 2 * (long)sizeof(int32_t);
    if (fwrite(header, sizeof(header), 1, s->fp) != 1 ||
        fwrite(varname, 1, (size_t)namelen, s->fp) != (size_t)namelen ||
        fflush(s->fp) != 0) {
        fprintf(stderr, "mat_sink: 写入文件头失败: %s\n", path);
        fclose(s->fp);
        free(s);
        return NULL;
    }
    return s;
}

int mat_sink_write_col(mat_sink_t *s, const double *col)
{
    if (!s || !s->fp || s->failed) return -1;
    if (s->ncols == INT32_MAX ||
        fwrite(col, sizeof(double), (size_t)s->nrows, s->fp) != (size_t)s->nrows) {
        s->failed = 1;
        fprintf(stderr, "mat_sink: 写入数据失败\n");
        return -1;
    }
    s->ncols++;
    return 0;
}

int mat_sink_close(mat_sink_t *s)
{
    if (!s) return 0;
    int failed = s->failed;
    if (s->fp) {
        /* 先确认数据写入成功，再提交列数；缓冲写入错误可能到此才出现。 */
        if (fflush(s->fp) != 0) failed = 1;
        if (!failed &&
            (fseek(s->fp, s->ncols_off, SEEK_SET) != 0 ||
             fwrite(&s->ncols, sizeof(int32_t), 1, s->fp) != 1))
            failed = 1;
        if (fclose(s->fp) != 0) failed = 1;
    }
    free(s);
    if (failed) fprintf(stderr, "mat_sink: 输出文件未完整写入\n");
    return failed ? -1 : 0;
}
