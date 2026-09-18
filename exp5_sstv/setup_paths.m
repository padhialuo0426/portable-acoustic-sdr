function setup_paths()
%SETUP_PATHS  加入实验五入口和共用 GUI；private/ 由 MATLAB 自动解析。
    here=fileparts(mfilename('fullpath'));addpath(here);addpath(fullfile(here,'..','common','matlab'));
    fprintf('实验五入口：sstv_emit / sstv_rev / sstv_wav_decode / gui；模型：sstv_receive。\n');
end
