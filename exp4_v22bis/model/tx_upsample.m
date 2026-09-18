function pulse=tx_upsample(symbol)
%#codegen
% 每符号 16 个采样点。
pulse=complex(zeros(16,1));pulse(1)=symbol;
end
