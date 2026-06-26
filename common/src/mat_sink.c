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

    fwrite(&type,      sizeof(int32_t), 1, s->fp);
    fwrite(&s->nrows,  sizeof(int32_t), 1, s->fp);
    s->ncols_off = ftell(s->fp);                 /* 记录 ncols 位置 */
    fwrite(&s->ncols,  sizeof(int32_t), 1, s->fp);   /* 占位 0 */
    fwrite(&imagf,     sizeof(int32_t), 1, s->fp);
    fwrite(&namelen,   sizeof(int32_t), 1, s->fp);
    fwrite(varname,    1, (size_t)namelen, s->fp);
    return s;
}

int mat_sink_write_col(mat_sink_t *s, const double *col)
{
    if (!s || !s->fp) return -1;
    if (fwrite(col, sizeof(double), (size_t)s->nrows, s->fp) != (size_t)s->nrows)
        return -1;
    s->ncols++;
    return 0;
}

void mat_sink_close(mat_sink_t *s)
{
    if (!s) return;
    if (s->fp) {
        fseek(s->fp, s->ncols_off, SEEK_SET);    /* 回填真实列数 */
        fwrite(&s->ncols, sizeof(int32_t), 1, s->fp);
        fclose(s->fp);
    }
    free(s);
}
