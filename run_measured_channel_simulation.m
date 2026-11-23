function result = run_measured_channel_simulation(channelMeasurementPath, noiseMeasurementPath)
%RUN_MEASURED_CHANNEL_SIMULATION Offline fixed-QPSK test using real measurements.
% Inputs: MAT paths saved by run_audio_measurements('channel') and ('noise').
% Output: decoded image metrics, saved MAT and PNG. No physical I/O.
% This is a replay simulation, not a live measurement of packet performance.
settings = startup_project();
channelMeasurement = load(channelMeasurementPath, 'result', 'settings');
noiseMeasurement = load(noiseMeasurementPath, 'recording', 'settings');
assert(channelMeasurement.settings.sampleRate == settings.sampleRate, 'Channel sample rate mismatch.');
assert(noiseMeasurement.settings.sampleRate == settings.sampleRate, 'Noise sample rate mismatch.');
impulseResponse = channelMeasurement.result.impulseResponse;
imageBytes = make_demo_image(settings);
[waveform, manifest] = make_audio_transmission(imageBytes, settings);
convolved = conv(waveform, impulseResponse);
recordedNoise = noiseMeasurement.recording;
assert(numel(recordedNoise) >= numel(convolved), ...
    'Noise clip is too short. Increase config.noiseRecordingSeconds; do not repeat a short clip.');
rng(settings.seed + 8, 'twister');
firstNoiseSample = randi(numel(recordedNoise) - numel(convolved) + 1);
noiseSegment = recordedNoise(firstNoiseSample:firstNoiseSample + numel(convolved) - 1);
noiseScale = sqrt(mean(convolved.^2) / (mean(noiseSegment.^2) * 10^(settings.demoSnrDb / 10)));
recording = apply_real_channel(waveform, impulseResponse, noiseSegment, noiseScale);
result = decode_audio_transmission(recording, manifest, settings);
result.mode = 'measured-FIR replay with scaled recorded noise';
result.noiseScale = noiseScale;
result.firstNoiseSample = firstNoiseSample;
save(fullfile(settings.paths.results, 'measured_replay.mat'), 'result', 'settings', 'manifest', 'channelMeasurementPath', 'noiseMeasurementPath');
imwrite(result.receivedImage, fullfile(settings.paths.data, 'received_image_measured_replay.png'));
fprintf('Measured replay: %d/%d CRC packets; BER %.4g.\n', nnz(result.passed), numel(result.passed), result.ber);
end
