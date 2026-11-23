function result = measure_channel_variation(settings)
%MEASURE_CHANNEL_VARIATION Repeated short probes at feasible wall-clock intervals.
% Input: settings. Output: aligned frequency-response shape correlation vs lag.
% Physical I/O is required. Timing includes record/play overhead; actual start
% times are saved. This is shape coherence, not calibrated Doppler coherence.
probe = settings.audioPeak * make_chirp(settings.variationProbeDuration, settings.sweepStartHz, settings.sweepEndHz, settings.sampleRate, true);
playback = [probe; zeros(round(settings.variationTailSeconds * settings.sampleRate), 1)];
variationSettings = settings;
variationSettings.recordLeadSeconds = settings.variationRecordLeadSeconds;
variationSettings.recordTailSeconds = settings.variationRecordTailSeconds;
minimumInterval = variationSettings.recordLeadSeconds + numel(playback) / settings.sampleRate + variationSettings.recordTailSeconds;
assert(settings.variationRequestedInterval >= minimumInterval, 'Probe interval is shorter than acquisition.');
responses = zeros(numel(settings.usedBins), settings.variationRepetitions);
times = zeros(settings.variationRepetitions, 1);
recordings = cell(settings.variationRepetitions, 1);
clockStart = tic;
for repetition = 1:settings.variationRepetitions
    targetTime = (repetition - 1) * settings.variationRequestedInterval;
    remaining = targetTime - toc(clockStart);
    if remaining > 0
        pause(remaining);
    end
    times(repetition) = toc(clockStart);
    recordings{repetition} = play_record_audio(playback, variationSettings);
    [impulseResponse, ~] = estimate_impulse_response(probe, recordings{repetition}, settings);
    % Preserve the entire measured FIR: direct DTFT, not truncating fft(h,N).
    frequencyBasis = exp(-1i * 2 * pi * settings.usedBins * (0:numel(impulseResponse)-1) / settings.fftSize);
    responses(:, repetition) = frequencyBasis * impulseResponse;
end
lagSeconds = zeros(settings.variationRepetitions, 1);
correlation = zeros(settings.variationRepetitions, 1);
for lag = 0:settings.variationRepetitions-1
    first = responses(:, 1:end-lag);
    second = responses(:, 1+lag:end);
    pairCorrelation = abs(sum(conj(first) .* second, 1)) ./ sqrt(sum(abs(first).^2, 1) .* sum(abs(second).^2, 1));
    correlation(lag + 1) = mean(pairCorrelation);
    lagSeconds(lag + 1) = mean(times(1+lag:end) - times(1:end-lag));
end
firstCrossing = find(correlation < settings.coherenceThreshold, 1);
if isempty(firstCrossing)
    coherenceTimeSeconds = NaN;
else
    coherenceTimeSeconds = lagSeconds(firstCrossing);
end
result.lagSeconds = lagSeconds;
result.shapeCorrelation = correlation;
result.shapeCoherenceTimeSeconds = coherenceTimeSeconds;
result.actualStartTimesSeconds = times;
result.minimumAcquisitionSeconds = minimumInterval;
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
save(fullfile(settings.paths.data, ['variation_', timestamp, '.mat']), 'result', 'responses', 'recordings', 'probe', 'settings');
figureHandle = figure('Visible', 'off');
plot(lagSeconds, correlation, 'o-');
yline(settings.coherenceThreshold, 'r:');
xlabel('Actual mean lag (seconds)');
ylabel('Normalized aligned response-shape correlation');
title('Measured variation: latency-aligned shape, not absolute phase');
save_figure(figureHandle, 'measurement_variation', settings);
end
