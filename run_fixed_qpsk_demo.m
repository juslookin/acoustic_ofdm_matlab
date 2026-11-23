function result = run_fixed_qpsk_demo(mode, recordingPath)
%RUN_FIXED_QPSK_DEMO Image-to-sound demo; default mode uses a synthetic room.
% Inputs: mode 'simulation' (default), 'hardware', 'file', or 'prepare';
% recordingPath WAV file for 'file'. Output: result structure, saved artifacts.
% 'hardware' requires speaker/microphone interaction; it is never run by tests.
settings = startup_project();
if nargin < 1
    mode = 'simulation';
end
rng(settings.seed + 6, 'twister');
imageBytes = make_demo_image(settings);
[waveform, manifest] = make_audio_transmission(imageBytes, settings);
audiowrite(fullfile(settings.paths.data, 'fixed_qpsk_transmit.wav'), waveform, settings.sampleRate);
save(fullfile(settings.paths.data, 'fixed_qpsk_manifest.mat'), 'manifest', 'settings', 'imageBytes');
if strcmp(mode, 'prepare')
    result = manifest;
    fprintf('Prepared %.2f seconds of audio; no playback performed.\n', manifest.durationSeconds);
    return;
elseif strcmp(mode, 'simulation')
    convolved = conv(waveform, settings.demoChannel);
    whiteNoise = randn(numel(convolved), 1);
    colouredNoise = filter(1, [1, -settings.demoNoiseCoefficient], whiteNoise);
    noiseScale = sqrt(mean(convolved.^2) / (mean(colouredNoise.^2) * 10^(settings.demoSnrDb / 10)));
    recording = [zeros(settings.demoDelaySamples, 1); ...
        apply_real_channel(waveform, settings.demoChannel, colouredNoise, noiseScale)];
elseif strcmp(mode, 'hardware')
    recording = play_record_audio(waveform, settings);
elseif strcmp(mode, 'file')
    assert(nargin >= 2, 'Provide a recording WAV file.');
    [recording, sampleRate] = audioread(recordingPath);
    assert(sampleRate == settings.sampleRate, 'Recording sample rate must match config.');
    recording = mean(recording, 2);
else
    error('Unknown demonstration mode.');
end
result = decode_audio_transmission(recording, manifest, settings);
result.mode = mode;
result.durationSeconds = manifest.durationSeconds;
result.netPayloadBitsPerSecond = nnz(result.passed) * settings.packetPayloadBytes * 8 / manifest.durationSeconds;
save(fullfile(settings.paths.results, ['fixed_qpsk_', mode, '.mat']), 'result', 'manifest', 'settings');
audiowrite(fullfile(settings.paths.data, ['fixed_qpsk_recording_', mode, '.wav']), max(min(recording, 1), -1), settings.sampleRate);
imwrite(imageBytes, fullfile(settings.paths.data, 'transmitted_image.png'));
imwrite(result.receivedImage, fullfile(settings.paths.data, ['received_image_', mode, '.png']));
figureHandle = figure('Visible', 'off');
subplot(1, 2, 1);
imagesc(imageBytes, [0, 255]);
axis image off;
title('Transmitted');
subplot(1, 2, 2);
imagesc(result.receivedImage, [0, 255]);
axis image off;
title(sprintf('%s: CRC %.1f%%', mode, 100 * result.packetSuccess));
colormap gray;
save_figure(figureHandle, ['E6_fixed_qpsk_', mode], settings);
fprintf('Fixed QPSK %s: %d/%d CRC packets, BER %.4g, %.1f payload bits/s, %.2f s.\n', ...
    mode, nnz(result.passed), numel(result.passed), result.ber, result.netPayloadBitsPerSecond, manifest.durationSeconds);
end
