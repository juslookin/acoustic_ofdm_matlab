function result = run_speaker_demo(mode, varargin)
settings = config();
if nargin < 1
    mode = 'check';
end

useFec = cellfun(@(v) ischar(v) && strcmpi(v, 'fec'), varargin);
settings.useFec = any(useFec);
varargin = varargin(~useFec);

pictureName = 'checkerboard';
k = find(cellfun(@(v) ischar(v) && strcmpi(v, 'picture'), varargin), 1);
if ~isempty(k)
    pictureName = varargin{k + 1};
    varargin(k:k + 1) = [];
end
if ~isempty(varargin)
    recordingPath = varargin{1};
end

fecTag = '';
if settings.useFec
    fecTag = '_fec';
    fprintf('Error correction on.\n');
end

image = pictures.load(pictureName, settings);
[~, baseName] = fileparts(pictureName);
pictureTag = '';
if ~strcmpi(pictureName, 'checkerboard')
    pictureTag = ['_', baseName];
end

if strcmp(mode, 'prepare')
    [waveform, manifest] = transmitter(image, settings);
    wavPath = fullfile(settings.paths.transmit, [baseName, fecTag, '.wav']);
    audiowrite(wavPath, waveform, settings.sampleRate);
    fprintf('Saved %s (%.1f s, %d packets).\n', wavPath, manifest.durationSeconds, manifest.numberOfPackets);
    result = manifest;
    return;
end

if strcmp(mode, 'check')
    image = image(:, 1:settings.speakerCheckPackets);
end
[waveform, manifest] = transmitter(image, settings);

switch mode
    case {'check', 'image'}
        fprintf('Playing %.1f s and recording.\n', manifest.durationSeconds);
        recording = play_and_record(waveform, settings);
        source = 'speaker -> microphone';

    case 'listen'
        seconds = ceil(manifest.durationSeconds + settings.listenMarginSeconds);
        recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1);
        fprintf('\n>>> RECORDING %d s. Press play on the other device now.\n\n', seconds);
        recordblocking(recorder, seconds);
        recording = getaudiodata(recorder, 'double');
        source = 'other device -> microphone';

    case 'file'
        [recording, rate] = audioread(recordingPath);
        recording = mean(recording, 2);
        if rate ~= settings.sampleRate
            recording = resample_audio(recording, rate, settings.sampleRate);
        end
        [~, name, ext] = fileparts(recordingPath);
        source = ['file ', name, ext];

    otherwise
        error('Unknown mode. Use check, image, prepare, listen or file.');
end

raw = recording;
if any(strcmp(mode, {'file', 'listen'}))
    recording = recording / max(max(abs(recording)), eps);
end

result = receiver(recording, manifest, settings);
summary = summarize(result, raw, settings);
result.summary = summary;
result.rate = summary.packetsPassed * settings.packetPayloadBytes * 8 / manifest.durationSeconds;
print_summary(summary, result, mode, manifest, settings);

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
stem = ['speaker_', mode, pictureTag, fecTag, '_', stamp];
audiowrite(fullfile(settings.paths.data, [stem, '.wav']), max(min(raw, 1), -1), settings.sampleRate);
save(fullfile(settings.paths.data, [stem, '.mat']), 'recording', 'result', 'manifest', 'settings', 'image');
imwrite(result.receivedImage, fullfile(settings.paths.data, [stem, '_image.png']));

figureHandle = plot_result(result, summary, image, settings, sprintf('%s (%s), %s', mode, source, stamp));
save_figure(figureHandle, ['E7_', stem], settings);
fprintf('Saved data/%s.wav and figures/E7_%s.png\n', stem, stem);
end

function recording = play_and_record(waveform, settings)
recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1);
player = audioplayer(waveform, settings.sampleRate, settings.audioBits);

record(recorder);
pause(settings.recordLeadSeconds);
playblocking(player);
pause(settings.recordTailSeconds);
stop(recorder);

recording = getaudiodata(recorder, 'double');
end

function output = resample_audio(input, inRate, outRate)
input = input(:);
n = numel(input);
m = round(n * outRate / inRate);

spectrum = fft(input);
kept = floor((min(n, m) - 1) / 2);
out = zeros(m, 1);
out(1:kept+1) = spectrum(1:kept+1);
out(end-kept+1:end) = spectrum(end-kept+1:end);
output = real(ifft(out)) * (m / n);
end

function s = summarize(result, recording, settings)
found = result.packets(cellfun(@(p) isstruct(p) && isfield(p, 'channel'), result.packets));
[~, data] = ofdm.layout(settings);

s.packetsSent = numel(result.passed);
s.packetsFound = numel(found);
s.packetsPassed = nnz(result.passed);
s.peak = max(abs(recording));
s.clipped = nnz(abs(recording) >= settings.speakerClipLevel);
s.frequenciesHz = settings.usedBins * settings.sampleRate / settings.fftSize;

if isempty(found)
    s.snrDb = nan(numel(settings.usedBins), 1);
    s.medianSnrDb = NaN;
    s.evmDb = NaN;
    s.packetSnrDb = [];
    s.packetPassed = [];
    s.constellation = [];
    s.outsideCpDb = NaN;
    s.latency = NaN;
    return;
end

snr = cellfun(@(p) p.snr, found, 'UniformOutput', false);
snr = [snr{:}];
s.snrDb = 10 * log10(median(snr, 2));
s.medianSnrDb = median(s.snrDb(data));
s.packetSnrDb = 10 * log10(median(snr(data, :), 1)).';
s.packetPassed = cellfun(@(p) p.passed, found);

symbols = cell2mat(cellfun(@(p) p.symbols(:), found, 'UniformOutput', false));
ideal = (sign(real(symbols)) + 1i * sign(imag(symbols))) / sqrt(2);
s.evmDb = 10 * log10(mean(abs(symbols - ideal).^2));
s.constellation = symbols(round(linspace(1, numel(symbols), min(numel(symbols), 20000))));

[~, order] = sort(s.packetSnrDb);
typical = found{order(ceil(end / 2))};
spectrum = zeros(settings.fftSize, 1);
spectrum(settings.usedBins + 1) = typical.channel .* hann(numel(settings.usedBins));
profile = abs(ifft(spectrum)).^2;

s.delayMs = (0:settings.fftSize-1).' / settings.sampleRate * 1000;
s.delayDb = 10 * log10(max(profile / max(profile), 1e-12));
s.outsideCpDb = 10 * log10(max(sum(profile(settings.cyclicPrefixLength+1:end)), realmin) / sum(profile));
s.latency = (found{1}.chirpStart - 1) / settings.sampleRate;
end

function w = hann(n)
w = 0.5 - 0.5 * cos(2 * pi * (1:n).' / (n + 1));
end

function print_summary(s, result, mode, manifest, settings)
fprintf('\n--- %s result ---\n', mode);
fprintf('Recording peak %.3f, %d clipped samples.\n', s.peak, s.clipped);
fprintf('Found %d/%d packets; CRC passed %d/%d; BER %.3g.\n', s.packetsFound, s.packetsSent, ...
    s.packetsPassed, s.packetsSent, result.ber);

if settings.useFec && s.packetsFound > 0
    fixed = cellfun(@(p) p.corrections, result.packets(cellfun(@(p) isfield(p, 'corrections'), result.packets)));
    fprintf('Error correction fixed a median of %g bits per packet (max %g).\n', median(fixed), max(fixed));
end

fprintf('Median SNR %.1f dB; EVM %.1f dB; echo outside guard %.1f dB.\n', s.medianSnrDb, s.evmDb, s.outsideCpDb);
fprintf('Data rate %.0f bit/s over %.1f s.\n', result.rate, manifest.durationSeconds);

if s.peak < 1e-4
    fprintf('Advice: the microphone is silent. Allow MATLAB microphone access and restart it.\n');
elseif s.clipped > 0
    fprintf('Advice: the recording clipped. Lower the volume.\n');
elseif s.peak < settings.speakerQuietPeak
    fprintf('Advice: the recording is quiet. Raise the volume or move closer.\n');
elseif s.packetsFound < s.packetsSent
    fprintf('Advice: some packets were missed. Move closer and start recording before playing.\n');
elseif s.medianSnrDb < settings.speakerGoodSnrDb
    fprintf('Advice: SNR is low. Move closer or reduce background noise.\n');
elseif s.packetsPassed < s.packetsSent
    fprintf('Advice: packets fail despite good SNR. Move closer and switch off audio effects.\n');
else
    fprintf('Every packet passed.\n');
end
end

function f = plot_result(result, s, image, settings, label)
f = figure('Visible', 'off', 'Position', [100, 100, 1400, 800]);
layout = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('%s | peak %.2f | BER %.2g', label, s.peak, result.ber), 'Interpreter', 'none');

ax = nexttile(layout);
imagesc(ax, image, [0, 255]);
colormap(ax, gray);
axis(ax, 'image', 'off');
title(ax, 'Sent');

ax = nexttile(layout);
imagesc(ax, result.receivedImage, [0, 255]);
colormap(ax, gray);
axis(ax, 'image', 'off');
title(ax, sprintf('Received: %d/%d packets (gray = lost)', s.packetsPassed, s.packetsSent));

ax = nexttile(layout);
if ~isempty(s.packetSnrDb)
    k = (1:numel(s.packetSnrDb)).';
    hold(ax, 'on');
    plot(ax, k(s.packetPassed), s.packetSnrDb(s.packetPassed), 'o', 'Color', [0.1, 0.55, 0.2], 'DisplayName', 'passed');
    plot(ax, k(~s.packetPassed), s.packetSnrDb(~s.packetPassed), 'rx', 'MarkerSize', 9, 'DisplayName', 'failed');
    legend(ax, 'Location', 'best');
end
grid(ax, 'on');
xlabel(ax, 'Packet');
ylabel(ax, 'SNR (dB)');
title(ax, sprintf('%d/%d packets found', s.packetsFound, s.packetsSent));

ax = nexttile(layout);
plot(ax, s.frequenciesHz / 1000, s.snrDb, 'LineWidth', 1.2);
yline(ax, 10, 'k:', 'QPSK needs ~10 dB');
grid(ax, 'on');
xlabel(ax, 'Tone frequency (kHz)');
ylabel(ax, 'SNR (dB)');
title(ax, sprintf('SNR per tone: median %.1f dB', s.medianSnrDb));

ax = nexttile(layout);
plot(ax, real(s.constellation), imag(s.constellation), '.', 'MarkerSize', 3, 'Color', [0.3, 0.3, 0.3]);
hold(ax, 'on');
plot(ax, [1, 1, -1, -1] / sqrt(2), [1, -1, 1, -1] / sqrt(2), 'r+', 'MarkerSize', 14, 'LineWidth', 2);
axis(ax, 'equal');
axis(ax, [-2, 2, -2, 2]);
grid(ax, 'on');
title(ax, sprintf('QPSK points, EVM %.1f dB', s.evmDb));

ax = nexttile(layout);
if isfield(s, 'delayMs')
    plot(ax, s.delayMs, s.delayDb);
    xline(ax, settings.cyclicPrefixLength / settings.sampleRate * 1000, 'r--', 'guard end');
    ylim(ax, [-50, 3]);
end
grid(ax, 'on');
xlabel(ax, 'Delay (ms)');
ylabel(ax, 'Echo power (dB)');
title(ax, sprintf('Echoes: %.1f dB outside guard', s.outsideCpDb));
end

function save_figure(f, stem, settings)
if isprop(f, 'Theme') && exist('theme', 'file')
    theme(f, 'light');
end
exportgraphics(f, fullfile(settings.paths.figures, [stem, '.png']), 'Resolution', 160);
close(f);
end
