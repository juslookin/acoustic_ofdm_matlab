function result = run_audio_measurements(measurement, recordingPath)
settings = startup_project();
if nargin < 1
    measurement = 'noise';
end
if strcmp(measurement, 'variation')
    result = measure_channel_variation(settings);
    return;
end
if strcmp(measurement, 'channel')
    probe = settings.audioPeak * make_chirp(settings.sweepDuration, settings.sweepStartHz, settings.sweepEndHz, settings.sampleRate, true);
    playback = [probe; zeros(round(settings.sweepTailSeconds * settings.sampleRate), 1)];
elseif strcmp(measurement, 'tones')
    time = (0:round(settings.toneDuration * settings.sampleRate)-1).' / settings.sampleRate;
    probe = zeros(numel(time), 1);

    for frequencyHz = settings.toneFrequencies
        probe = probe + settings.audioPeak / numel(settings.toneFrequencies) * sin(2 * pi * frequencyHz * time);
    end

    playback = probe;
elseif strcmp(measurement, 'noise')
    probe = [];
    playback = [];
else
    error('Unknown measurement.');
end
if nargin >= 2
    [recording, sampleRate] = audioread(recordingPath);
    assert(sampleRate == settings.sampleRate, 'Sample rate mismatch.');
    recording = mean(recording, 2);
elseif strcmp(measurement, 'noise')
    fprintf('Record room noise: remain silent for %.1f seconds.\n', settings.noiseRecordingSeconds);
    if settings.audioInputDevice < 0
        recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1);
    else
        recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1, settings.audioInputDevice);
    end
    recordblocking(recorder, settings.noiseRecordingSeconds);
    recording = getaudiodata(recorder, 'double');
else
    recording = play_record_audio(playback, settings);
end
result.measurement = measurement;
if strcmp(measurement, 'channel')
    [impulseResponse, statistics] = estimate_impulse_response(probe, recording, settings);
    result.impulseResponse = impulseResponse;
    result.statistics = statistics;
    result.decisions = measurement_decisions(statistics, settings);
    disp(result.decisions);
    figureHandle = figure('Visible', 'off');
    plot((0:numel(impulseResponse)-1) / settings.sampleRate * 1000, impulseResponse);
    xline(settings.cyclicPrefixLength / settings.sampleRate * 1000, 'r--', 'current CP');
    xlabel('Delay relative to strongest arrival (ms)');
    ylabel('Estimated real FIR amplitude');
    title('E2: measured regularized sweep response');
else
    [frequencies, psd] = welch_psd(recording, settings.sampleRate, settings.psdWindowLength, settings.psdOverlapFraction);
    result.frequencies = frequencies;
    result.psd = psd;
    result.positiveBinNoiseVariance = settings.sampleRate / 2 * interp1(frequencies, psd, settings.usedBins * settings.sampleRate / settings.fftSize, 'linear');
    if strcmp(measurement, 'tones')
        result.toneReport = analyze_tones(recording, probe, settings);
        disp(result.toneReport);
    end
    figureHandle = figure('Visible', 'off');
    plot(frequencies, 10 * log10(max(psd, realmin)));
    xline(settings.usedBins(1) * settings.sampleRate / settings.fftSize, 'r--');
    xline(settings.usedBins(end) * settings.sampleRate / settings.fftSize, 'r--');
    xlabel('Frequency (Hz)');
    ylabel('PSD (dB full-scale^2/Hz)');
    title(['E1: ', measurement, ' recording (no synthetic replacement)']);
end
save_figure(figureHandle, ['measurement_', measurement], settings);
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
save(fullfile(settings.paths.data, [measurement, '_', timestamp, '.mat']), 'recording', 'probe', 'result', 'settings');
end
