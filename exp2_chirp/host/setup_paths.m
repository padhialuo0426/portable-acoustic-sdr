function setup_paths()
%SETUP_PATHS  把实验二相关目录加入 MATLAB 搜索路径。
% 运行一次后，即可在任意工作目录用名字调用各脚本/模型：
%   bok_sim / bok_emit / bok_rev / chirp_rev_detect
%
% 各脚本对自身数据文件(图片/info_all/chirp5)已做相对自身定位，不依赖当前目录；
% 本函数只是让“按名字调用”能找到脚本和模型。
    here = fileparts(mfilename('fullpath'));
    addpath(here);                                   % host/ 下的脚本
    addpath(fullfile(here,'..','baseband_images'));  % 基带图片
    addpath(fullfile(here,'..','matlab'));           % chirp_rev_detect.slx
    fprintf('实验二路径已加入。可用: bok_sim / bok_emit / bok_rev\n');
end
