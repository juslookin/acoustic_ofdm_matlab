function report = analyze_tones(recording, probe, settings)
%ANALYZE_TONES Locate a two-tone probe and report FFT peaks and residual SNR.
% Inputs: real columns recording/probe, settings. Output: diagnostic structure.
% Latency is approximate: periodic tones have ambiguous correlation peaks.
[~, score] = matched_filter(recording, probe);
[~, startSample] = max(score);
segment = recording(startSample:startSample + numel(probe) - 1);
window = 0.5 - 0.5 * cos(2 * pi * (0:numel(segment)-1).' / (numel(segment)-1));
spectrumPower = abs(fft(segment .* window)).^2;
frequencies = (0:numel(segment)-1).' * settings.sampleRate / numel(segment);
toneMask = false(size(spectrumPower));
estimatedHz = zeros(size(settings.toneFrequencies));
for toneIndex = 1:numel(settings.toneFrequencies)
    targetHz = settings.toneFrequencies(toneIndex);
    neighbourhood = find(abs(frequencies - targetHz) <= 50);
    [~, peakIndex] = max(spectrumPower(neighbourhood));
    selectedBin = neighbourhood(peakIndex);
    estimatedHz(toneIndex) = frequencies(selectedBin);
    toneMask(abs(frequencies - estimatedHz(toneIndex)) <= 4 * settings.sampleRate / numel(segment)) = true;
end
positiveBins = frequencies > 0 & frequencies < settings.sampleRate / 2;
report.estimatedFrequenciesHz = estimatedHz;
report.frequencyErrorsHz = estimatedHz - settings.toneFrequencies;
report.approximateLatencySeconds = (startSample - 1) / settings.sampleRate;
report.spectralToneToResidualDb = 10 * log10(sum(spectrumPower(toneMask)) / max(sum(spectrumPower(positiveBins & ~toneMask)), realmin));
end
