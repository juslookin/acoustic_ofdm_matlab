function results = experiment_model_diagnostics(settings)
rng(settings.seed + 7, 'twister');
whiteNoise = randn(round(settings.noiseRecordingSeconds * settings.sampleRate), 1);
colouredNoise = filter(1, [1, -settings.demoNoiseCoefficient], whiteNoise);
colouredNoise = colouredNoise / std(colouredNoise);
[frequencies, whitePsd] = welch_psd(whiteNoise, settings.sampleRate, settings.psdWindowLength, settings.psdOverlapFraction);

[~, colouredPsd] = welch_psd(colouredNoise, settings.sampleRate, settings.psdWindowLength, settings.psdOverlapFraction);
figureHandle = figure('Visible', 'off');
plot(frequencies, 10 * log10(whitePsd), frequencies, 10 * log10(colouredPsd));

xline(settings.usedBins(1) * settings.sampleRate / settings.fftSize, 'k:');
xline(settings.usedBins(end) * settings.sampleRate / settings.fftSize, 'k:');
xlabel('Frequency (Hz)');

ylabel('PSD (dB amplitude^2/Hz)');
legend('Synthetic white', 'Synthetic AR(1)');
title('E1 software diagnostic: synthetic signals, no room recording');

save_figure(figureHandle, 'E1_synthetic_noise', settings);
assumedImpulse = zeros(max(settings.channelDelays) + 1, 1);
assumedImpulse(settings.channelDelays + 1) = sqrt(settings.channelTapPowers);
results = delay_statistics(assumedImpulse, settings.sampleRate);
results.decisions = measurement_decisions(results, settings);

figureHandle = figure('Visible', 'off');
stem(settings.channelDelays / settings.sampleRate * 1000, settings.channelTapPowers, 'filled');
xline(settings.cyclicPrefixLength / settings.sampleRate * 1000, 'r--', 'CP');

xlabel('Tap delay (ms)');
ylabel('Expected normalized tap power');
title('E2 software diagnostic: assumed PDP, not a measured room');

save_figure(figureHandle, 'E2_assumed_pdp', settings);
save(fullfile(settings.paths.results, 'model_diagnostics.mat'), 'results', 'frequencies', 'whitePsd', 'colouredPsd', 'settings');
end
