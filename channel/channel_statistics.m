function [frequencyBasis, channelCovariance, noiseShape] = channel_statistics(settings)
frequencyBasis = exp(-1i * 2 * pi * settings.usedBins * settings.channelDelays.' / settings.fftSize);
channelCovariance = (frequencyBasis .* settings.channelTapPowers.') * frequencyBasis';
carrierCoordinate = linspace(0, 1, numel(settings.usedBins)).';
noiseShape = settings.noiseColourFloor + settings.noiseColourStrength ...
    * (0.5 + 0.5 * cos(2 * pi * carrierCoordinate)).^2;
noiseShape = noiseShape / mean(noiseShape);
end
