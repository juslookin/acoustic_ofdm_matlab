function result = run_speaker_demo(mode, varargin)
settings = startup_project();
if nargin < 1
    mode = 'check';
end

isFecFlag = cellfun(@(value) ischar(value) && strcmpi(value, 'fec'), varargin);
settings.useFec = any(isFecFlag);
varargin = varargin(~isFecFlag);

pictureName = 'checkerboard';
pictureIndex = find(cellfun(@(value) ischar(value) && strcmpi(value, 'picture'), varargin), 1);

if ~isempty(pictureIndex)
    assert(numel(varargin) > pictureIndex, 'Give a picture name after ''picture''.');
    pictureName = varargin{pictureIndex + 1};
    varargin(pictureIndex:pictureIndex + 1) = [];
end
if ~isempty(varargin)
    recordingPath = varargin{1};
end

fecTag = '';
if settings.useFec
    fecTag = '_fec';
    fprintf('FEC on: rate-1/2 K=7 convolutional code with soft Viterbi decoding.\n');
end

imageBytes = load_picture(pictureName, settings);
pictureTag = '';

if ~strcmpi(pictureName, 'checkerboard')
    [~, pictureTag] = fileparts(pictureName);
    pictureTag = ['_', pictureTag];
end
if strcmp(mode, 'prepare')
    [waveform, manifest] = make_audio_transmission(imageBytes, settings);
    [~, baseName] = fileparts(pictureName);
    wavPath = fullfile(settings.paths.transmit, [baseName, fecTag, '.wav']);
    audiowrite(wavPath, waveform, settings.sampleRate);
    fprintf('Saved %s (%.1f s, %d packets). Play it once; record with margin.\n', ...
        wavPath, manifest.durationSeconds, manifest.numberOfPackets);
    result = manifest;

    return;
end
if strcmp(mode, 'stress')
    result = run_stress(settings, imageBytes);
    return;
end
if strcmp(mode, 'check')
    imageBytes = imageBytes(:, 1:settings.speakerCheckPackets);
end

[waveform, manifest] = make_audio_transmission(imageBytes, settings);
switch mode
    case {'check', 'image'}
        fprintf('Playing %.1f s through the default speaker, recording the default microphone.\n', ...
            manifest.durationSeconds);
        recording = play_record_audio(waveform, settings);
        sourceText = 'live speaker -> microphone';
    case 'listen'
        seconds = ceil(manifest.durationSeconds + settings.listenMarginSeconds);
        if settings.audioInputDevice < 0
            recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1);
        else
            recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1, settings.audioInputDevice);
        end

        fprintf('\n>>> RECORDING %d s. Press play on the other device now (within %d s).\n\n', ...
            seconds, settings.listenMarginSeconds);
        recordblocking(recorder, seconds);
        recording = getaudiodata(recorder, 'double');

        fprintf('Recording finished, decoding...\n');
        sourceText = 'other device -> this microphone';
    case 'file'
        assert(exist('recordingPath', 'var') == 1, 'Provide the path of the recording.');
        [recording, fileRate] = audioread(recordingPath);
        recording = mean(recording, 2);

        if fileRate ~= settings.sampleRate
            fprintf('Resampling recording from %d Hz to %d Hz.\n', fileRate, settings.sampleRate);
            recording = resample_audio(recording, fileRate, settings.sampleRate);
        end
        [~, fileName, fileExtension] = fileparts(recordingPath);
        sourceText = ['file ', fileName, fileExtension];
    otherwise
        error('Unknown mode. Use stress, check, image, prepare, listen or file.');
end
rawRecording = recording;
if any(strcmp(mode, {'file', 'listen'}))
    recording = recording / max(max(abs(recording)), eps);
end
result = decode_audio_transmission(recording, manifest, settings);
summary = summarize_audio_result(result, rawRecording, settings);
result.summary = summary;
result.mode = mode;
result.source = sourceText;
result.durationSeconds = manifest.durationSeconds;
result.netPayloadBitsPerSecond = summary.packetsPassed * settings.packetPayloadBytes * 8 / manifest.durationSeconds;
print_summary(summary, result, mode, settings);
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
fileStem = ['speaker_', mode, pictureTag, fecTag, '_', timestamp];
audiowrite(fullfile(settings.paths.data, [fileStem, '.wav']), max(min(rawRecording, 1), -1), settings.sampleRate);
save(fullfile(settings.paths.data, [fileStem, '.mat']), 'recording', 'result', 'manifest', 'settings', 'imageBytes');
imwrite(result.receivedImage, fullfile(settings.paths.data, [fileStem, '_image.png']));
figureHandle = plot_speaker_diagnostics(result, summary, imageBytes, settings, ...
    sprintf('E7 %s (%s), %s', mode, sourceText, timestamp));
save_figure(figureHandle, ['E7_', fileStem], settings);
fprintf('Saved data/%s.wav, data/%s.mat and figures/E7_%s.png\n', fileStem, fileStem, fileStem);
end

function print_summary(summary, result, mode, settings)
fprintf('\n--- %s result ---\n', mode);
fprintf('Recording peak %.3f of full scale, %d clipped samples.\n', summary.peakLevel, summary.clippedSamples);
fprintf('Synchronised %d/%d packets; CRC passed %d/%d; BER %.3g.\n', summary.packetsSynchronised, ...
    summary.packetsSent, summary.packetsPassed, summary.packetsSent, result.ber);
if settings.useFec
    corrections = cellfun(@(entry) fec_count(entry), result.diagnostics);
    corrections = corrections(~isnan(corrections));
    if ~isempty(corrections)
        fprintf('FEC corrected a median of %g coded bits per packet (max %g).\n', ...
            median(corrections), max(corrections));
    end
end
fprintf('Median data-carrier SNR %.1f dB; %.0f%% of carriers below 10 dB; EVM %.1f dB.\n', ...
    summary.medianSnrDb, 100 * summary.weakCarrierFraction, summary.evmDb);
fprintf('Channel energy outside the %.1f ms cyclic prefix: %.1f dB. Latency %.3f s.\n', ...
    settings.cyclicPrefixLength / settings.sampleRate * 1000, summary.energyOutsideCpDb, summary.latencySeconds);
fprintf('Net payload rate %.0f bit/s over %.1f s.\n', result.netPayloadBitsPerSecond, result.durationSeconds);
fprintf('Advice: ');
if summary.peakLevel < 1e-4
    fprintf(['The microphone returned silence. On macOS open System Settings > Privacy & Security >\n', ...
        'Microphone, allow MATLAB, then restart MATLAB. Also check the input device in audiodevinfo.\n']);
elseif summary.clippedSamples > 0
    fprintf('The recording clipped. Lower the speaker volume or increase the distance.\n');
elseif summary.peakLevel < settings.speakerQuietPeak
    fprintf('The recording is quiet. Raise the speaker volume (keep it below clipping).\n');
elseif summary.packetsSynchronised < summary.packetsSent
    fprintf('Some chirps were not found. Raise the volume, reduce distance, and check that sound is audible.\n');
elseif summary.medianSnrDb < settings.speakerGoodSnrDb
    fprintf('SNR is low. Move closer, raise the volume, or reduce fan/background noise.\n');
elseif summary.packetsPassed < summary.packetsSent
    fprintf(['SNR is adequate but packets fail. Likely reverberation, an echo path or OS audio processing:\n', ...
        'shorten the distance, point the speaker at the microphone, move away from walls, and\n', ...
        'disable microphone enhancements. Compare the delay-profile panel with the CP line.\n']);
elseif strcmp(mode, 'check')
    fprintf('Link looks good. Run run_speaker_demo(''image'') without moving anything.\n');
else
    fprintf('Every packet passed CRC.\n');
end
end

function count = fec_count(entry)
count = NaN;
if isstruct(entry) && isfield(entry, 'fecCorrections')
    count = entry.fecCorrections;
end
end

function result = run_stress(settings, imageBytes)
stressTag = '';
if settings.useFec
    stressTag = '_fec';
end
[waveform, manifest] = make_audio_transmission(imageBytes, settings);
roomStream = RandStream('mt19937ar', 'Seed', settings.seed + 20);
noiseStream = RandStream('mt19937ar', 'Seed', settings.seed + 21);
roomCount = numel(settings.stressRoomNames);
snrCount = numel(settings.stressSnrDb);
packetSuccess = nan(roomCount, snrCount);
measuredSnrDb = nan(roomCount, snrCount);
outsideCpDb = nan(roomCount, 1);
rows = {};
for roomIndex = 1:roomCount
    room = synthetic_room(settings.stressRoomRt60(roomIndex), settings.stressRoomDrrDb(roomIndex), ...
        settings.sampleRate, roomStream);
    convolved = fft_convolve(waveform, room);
    convolved = resample_audio(convolved, settings.sampleRate, ...
        settings.sampleRate * (1 + settings.stressClockPpm * 1e-6));
    convolved = [zeros(settings.demoDelaySamples, 1); convolved];
    noise = filter(1, [1, -settings.demoNoiseCoefficient], randn(noiseStream, numel(convolved), 1));
    for snrIndex = 1:snrCount
        snrDb = settings.stressSnrDb(snrIndex);
        noiseScale = sqrt(mean(convolved.^2) / (mean(noise.^2) * 10^(snrDb / 10)));
        recording = convolved + noiseScale * noise;
        decoded = decode_audio_transmission(recording, manifest, settings);
        summary = summarize_audio_result(decoded, recording, settings);
        packetSuccess(roomIndex, snrIndex) = summary.packetsPassed / summary.packetsSent;
        measuredSnrDb(roomIndex, snrIndex) = summary.medianSnrDb;
        outsideCpDb(roomIndex) = summary.energyOutsideCpDb;
        rows(end+1, :) = {settings.stressRoomNames{roomIndex}, settings.stressRoomRt60(roomIndex), ...
            settings.stressRoomDrrDb(roomIndex), snrDb, summary.medianSnrDb, summary.packetsPassed, ...
            summary.packetsSent, decoded.ber, summary.evmDb, summary.energyOutsideCpDb}; %#ok<AGROW>
        fprintf('Stress %-16s SNR %2d dB: CRC %2d/%d, carrier SNR %5.1f dB, BER %.3g\n', ...
            settings.stressRoomNames{roomIndex}, snrDb, summary.packetsPassed, summary.packetsSent, ...
            summary.medianSnrDb, decoded.ber);
    end
end
stressTable = cell2table(rows, 'VariableNames', {'Room', 'Rt60Seconds', 'DrrDb', 'RecordingSnrDb', ...
    'MedianCarrierSnrDb', 'PacketsPassed', 'PacketsSent', 'Ber', 'EvmDb', 'EnergyOutsideCpDb'});
writetable(stressTable, fullfile(settings.paths.results, ['speaker_stress', stressTag, '.csv']));
save(fullfile(settings.paths.results, ['speaker_stress', stressTag, '.mat']), 'stressTable', 'packetSuccess', 'measuredSnrDb', 'settings');
figureHandle = figure('Visible', 'off', 'Position', [100, 100, 1200, 450]);
layout = tiledlayout(figureHandle, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
codingText = 'uncoded QPSK';
if settings.useFec
    codingText = 'QPSK + rate-1/2 convolutional code';
end
title(layout, sprintf(['E7 stress test: real waveform (%s), SYNTHETIC rooms, AR(1) noise, ', ...
    '%d ppm clock offset, %d packets'], codingText, settings.stressClockPpm, manifest.numberOfPackets));
legendText = cell(roomCount, 1);
for roomIndex = 1:roomCount
    if isinf(settings.stressRoomDrrDb(roomIndex))
        legendText{roomIndex} = settings.stressRoomNames{roomIndex};
    else
        legendText{roomIndex} = sprintf('%s (RT60 %.1f s, DRR %+d dB; %.0f dB outside CP)', ...
            settings.stressRoomNames{roomIndex}, settings.stressRoomRt60(roomIndex), ...
            settings.stressRoomDrrDb(roomIndex), outsideCpDb(roomIndex));
    end
end
axesHandle = nexttile(layout);
plot(axesHandle, settings.stressSnrDb, 100 * packetSuccess.', 'o-', 'LineWidth', 1.2);
grid(axesHandle, 'on');
ylim(axesHandle, [0, 105]);
xlabel(axesHandle, 'Broadband recording SNR (dB)');
ylabel(axesHandle, 'Packets passing CRC (%)');
legend(axesHandle, legendText, 'Location', 'southeast');
axesHandle = nexttile(layout);
plot(axesHandle, measuredSnrDb.', 100 * packetSuccess.', 'o-', 'LineWidth', 1.2);
grid(axesHandle, 'on');
ylim(axesHandle, [0, 105]);
xlabel(axesHandle, 'Receiver-measured median carrier SNR (dB) - compare with ''check''');
ylabel(axesHandle, 'Packets passing CRC (%)');
legend(axesHandle, settings.stressRoomNames, 'Location', 'southeast');
save_figure(figureHandle, ['E7_speaker_stress', stressTag], settings);
result.table = stressTable;
result.packetSuccess = packetSuccess;
result.measuredSnrDb = measuredSnrDb;
fprintf('Saved results/speaker_stress%s.csv and figures/E7_speaker_stress%s.png\n', stressTag, stressTag);
end
