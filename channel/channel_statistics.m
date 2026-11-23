function [frequencyBasis, channelCovariance, noiseShape] = channel_statistics(settings)
%CHANNEL_STATISTICS Proper-complex Rayleigh tap prior and diagonal coloured noise.
% Input: settings. Outputs: F [K x L], R=E[H*H'] [K x K], shape [K x 1].
% H=F*h, h_l~CN(0,p_l), sum(p_l)=1 => E|H_k|^2=1 on every used bin.
frequencyBasis = exp(-1i * 2 * pi * settings.usedBins * settings.channelDelays.' / settings.fftSize);
channelCovariance = (frequencyBasis .* settings.channelTapPowers.') * frequencyBasis';
carrierCoordinate = linspace(0, 1, numel(settings.usedBins)).';
noiseShape = settings.noiseColourFloor + settings.noiseColourStrength ...
    * (0.5 + 0.5 * cos(2 * pi * carrierCoordinate)).^2;
noiseShape = noiseShape / mean(noiseShape);
end
