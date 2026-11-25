function channelResponse = draw_channels(frequencyBasis, tapPowers, numberOfRealizations)
channelTaps = sqrt(tapPowers(:) / 2) .* (randn(numel(tapPowers), numberOfRealizations) ...
    + 1i * randn(numel(tapPowers), numberOfRealizations));
channelResponse = frequencyBasis * channelTaps;
end
