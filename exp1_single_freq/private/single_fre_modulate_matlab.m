function audio=single_fre_modulate_matlab(fc,samples,amplitude)
%SINGLE_FRE_MODULATE_MATLAB  原单频发送公式，直接在 MATLAB 中生成采样点。
audio=amplitude*sin(2*pi*fc*(0:samples-1)/8000);
end
