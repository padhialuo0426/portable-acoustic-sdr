function segments = sstv_scan_segments(P,unit)
%SSTV_SCAN_SEGMENTS  一次扫描的 [时长秒, 分量编号, 固定音调Hz]。
% 编号 0 为音调；RGB 为 R/G/B，色差为 Y/Cr/Cb，PD 的 4 为第二行 Y。
    sync=[P.sync 0 1200];porch=[P.porch 0 1500];
    switch P.family
        case 'rgb'
            segments=[sync;porch];
            for ch=P.channelOrder,segments=[segments;P.scan ch 0;porch];end %#ok<AGROW>
        case 'scottie'
            segments=[porch;P.scan 2 0;porch;P.scan 3 0;sync;porch;P.scan 1 0];
        case 'wraase'
            segments=[sync;porch;P.scan 1 0;P.scan 2 0;P.scan 3 0];
        case 'pd'
            segments=[sync;porch;P.scan 1 0;P.scan 2 0;P.scan 3 0;P.scan 4 0];
        case 'robot36'
            ch=2+mod(unit-1,2);separator=1500+800*mod(unit-1,2);
            segments=[sync;porch;.088 1 0;.0045 0 separator;.0015 0 1900;.044 ch 0];
        case 'robot72'
            segments=[sync;porch;.138 1 0;.0045 0 1500;.0015 0 1900; ...
                .069 2 0;.0045 0 2300;.0015 0 1500;.069 3 0];
        case 'mono'
            segments=[sync;P.scan 1 0];
        otherwise
            error('sstv:Mode','未知扫描结构。');
    end
end
