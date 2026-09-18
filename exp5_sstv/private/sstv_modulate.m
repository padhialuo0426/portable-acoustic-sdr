function [audio,meta] = sstv_modulate(image,P)
%SSTV_MODULATE  在 Simulink 中完成所选 SSTV 模式的发送调制。
    [audio,meta]=sstv_simulate_transmitter(image,P);
end
