function channelResponse = draw_channels(frequencyBasis, tapPowers, numberOfRealizations)
%DRAW_CHANNELS Independent channels, fixed within a frame.
% Inputs: F [K x L], powers [L x 1], count scalar. Output: H [K x count].
channelTaps = sqrt(tapPowers(:) / 2) .* (randn(numel(tapPowers), numberOfRealizations) ...
    + 1i * randn(numel(tapPowers), numberOfRealizations));
channelResponse = frequencyBasis * channelTaps;
end
