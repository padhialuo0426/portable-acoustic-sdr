function setup_paths()
%SETUP_PATHS  把实验一相关目录加入 MATLAB 搜索路径。
% 运行一次后，即可在任意工作目录用名字调用各脚本/模型：
%   single_fre_emit / spectrum / single_fre_rev
%
% 各脚本对自身数据文件已做相对自身定位，不依赖当前目录；
% 本函数只是让"按名字调用"能找到脚本、模型和共用层。
%
% 注意：重新生成模型代码时，仍要先把**当前文件夹**切到 ../board——
% 生成目录默认就是当前文件夹，加进搜索路径并不改变这一点。
    here = fileparts(mfilename('fullpath'));
    addpath(here);                                        % host/ 下的脚本
    addpath(fullfile(here,'..','board'));                 % single_fre_rev.slx
    addpath(fullfile(here,'..','..','common','matlab'));  % gui.m 用的 +asdr 共用层
    fprintf('实验一路径已加入。可用: single_fre_emit / spectrum\n');
end
