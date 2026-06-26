portable 工程内 .slx 模型的备份（R2025b 格式，已做 Inport/Outport 改造版）
备份时间见目录名时间戳。

文件名编码：原相对路径中的 / 用 __ 代替。
  exp1_single_freq__matlab__single_fre_rev.slx  <- exp1_single_freq/matlab/single_fre_rev.slx
  exp2_chirp__matlab__chirp_rev_detect.slx      <- exp2_chirp/matlab/chirp_rev_detect.slx

注意：这些是 R2025b 原生模型。若要回 R2022a 属"高→低导出"，可能有不可预知问题
(exp1基础块基本无忧；exp2含15个Stateflow图，风险集中在此，导出后须实测)。
原始未改动的 R2022a 模型在 ../../wireless_comm_expe_2024_backup_20260625_191636/ 下。
