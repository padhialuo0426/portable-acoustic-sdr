function setup_paths()
%SETUP_PATHS  把实验四相关目录加入 MATLAB 搜索路径。
% 运行一次后，即可在任意工作目录用名字调用各脚本/模型：
%   v22_emit / v22_rev / v22_sim / v22_receive
%
% 各脚本对自身数据文件已做相对自身定位，不依赖当前目录；
% 本函数只是让"按名字调用"能找到脚本、模型和共用层。
%
% 注意：重新生成模型代码时要先把**当前文件夹**切到本实验目录——生成目录
% 默认就是当前文件夹，加进搜索路径并不改变这一点。
    here = fileparts(mfilename('fullpath'));
    addpath(here);                                  % 本实验的 .m 与 v22_receive.slx
    addpath(fullfile(here,'..','common','matlab')); % gui.m 用的 +asdr 共用层
    fprintf(['实验四路径已加入。可用: v22_emit / v22_rev / v22_sim / gui\n' ...
             '自检: v22_selftest(协议层) / v22_model_check(模型)\n']);
end
