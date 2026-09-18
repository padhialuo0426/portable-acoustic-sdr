function setup_paths()
%SETUP_PATHS  把实验四相关目录加入 MATLAB 搜索路径。
% 运行一次后，即可在任意工作目录用名字调用各脚本/模型：
%   v22_emit / v22_rev / v22_wav_decode / v22_receive
%
% 各脚本对自身数据文件已做相对自身定位，不依赖当前目录；
% 本函数只是让"按名字调用"能找到脚本、模型和共用层。
%
% 注意：重新生成模型代码时要先把**当前文件夹**切到本实验目录——生成目录
% 默认就是当前文件夹，加进搜索路径并不改变这一点。
    here = fileparts(mfilename('fullpath'));
    addpath(here);                                % 入口脚本/函数与模型
    addpath(fullfile(here,'..','common','matlab')); % gui.m 用的 +asdr 共用层
    % private/ 由 MATLAB 自动解析，不加入路径；model/ 是建模源文件而非入口。
    fprintf(['实验四路径已加入。可用: v22_emit / v22_rev / v22_wav_decode / gui\n' ...
             '模型: build_model / v22_receive\n']);
end
