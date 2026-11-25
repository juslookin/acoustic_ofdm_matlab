function report = run_tests()
settings = startup_project();
rng(settings.seed, 'twister');
testFunctions = {@test_modulations, @test_crc, @test_ofdm, @test_cyclic_prefix, ...
    @test_real_channel_consistency, @test_awgn, @test_phase_tracking, ...
    @test_audio_packet, @test_sampling_clock, @test_packet_rejection, ...
    @test_resample, @test_fec, @test_pictures};
names = cell(numel(testFunctions), 1);
passed = false(numel(testFunctions), 1);

messages = cell(numel(testFunctions), 1);
for testIndex = 1:numel(testFunctions)
    names{testIndex} = func2str(testFunctions{testIndex});
    try
        testFunctions{testIndex}(settings);
        passed(testIndex) = true;
        messages{testIndex} = 'PASS';
    catch testError
        messages{testIndex} = testError.message;
    end

    fprintf('%s: %s\n', names{testIndex}, messages{testIndex});
end
report = table(names, passed, messages, 'VariableNames', {'Test', 'Passed', 'Message'});
writetable(report, fullfile(settings.paths.results, 'tests.csv'));
save(fullfile(settings.paths.results, 'tests.mat'), 'report', 'settings');
assert(all(passed), '%d tests failed. See results/tests.csv.', nnz(~passed));
fprintf('All %d tests passed.\n', height(report));
end

function test_modulations(~)
bits = logical([0 0 0 1 1 0 1 1]).';
symbols = modulate_bits(bits);

assert(isequal(demap_symbols(symbols), bits));
assert(all(abs(abs(symbols) - 1) < 1e-12));
assert(numel(unique(round(symbols, 9))) == 4);
end

function test_crc(~)
assert(crc32_bytes(uint8('123456789')) == uint32(hex2dec('CBF43926')));
bytes = uint8((0:255).');
assert(isequal(bits_to_bytes(bytes_to_bits(bytes)), bytes));
packet = make_packet(bytes);
assert(check_packet(packet));
packet(73) = ~packet(73);
assert(~check_packet(packet));
end

function test_ofdm(settings)
symbols = modulate_bits(rand(2 * numel(settings.usedBins) * 3, 1) > 0.5);
grid = reshape(symbols, numel(settings.usedBins), 3);
for realWaveform = [false, true]
    waveform = ofdm_modulate(grid, settings, realWaveform);
    recovered = ofdm_demodulate(waveform, settings);
    assert(max(abs(recovered - grid), [], 'all') < 1e-12);
    blocks = reshape(waveform, settings.fftSize + settings.cyclicPrefixLength, []);
    useful = blocks(settings.cyclicPrefixLength+1:end, :);
    mirrorFactor = 1 + double(realWaveform);
    assert(abs(sum(abs(useful).^2, 'all') - mirrorFactor * sum(abs(grid).^2, 'all')) < 1e-9);
    assert(~realWaveform || isreal(waveform));
end
end

function test_cyclic_prefix(settings)
grid = randn(numel(settings.usedBins), 2) + 1i * randn(numel(settings.usedBins), 2);
taps = [1; zeros(8, 1); 0.3 + 0.2i];
waveform = ofdm_modulate(grid, settings, false);
received = conv(waveform, taps);
recovered = ofdm_demodulate(received(1:numel(waveform)), settings);
response = fft(taps, settings.fftSize);
assert(max(abs(recovered - response(settings.usedBins+1) .* grid), [], 'all') < 1e-10);
end

function test_real_channel_consistency(settings)
grid = randn(numel(settings.usedBins), 2) + 1i * randn(numel(settings.usedBins), 2);
waveform = ofdm_modulate(grid, settings, true);
received = conv(waveform, settings.demoChannel);
recovered = ofdm_demodulate(received(1:numel(waveform)), settings);
response = fft(settings.demoChannel, settings.fftSize);
assert(max(abs(recovered - response(settings.usedBins+1) .* grid), [], 'all') < 1e-10);
end

function test_awgn(~)
symbolSnr = 10^(6 / 10);
bits = rand(600000, 1) > 0.5;
symbols = modulate_bits(bits);
noise = (randn(size(symbols)) + 1i * randn(size(symbols))) / sqrt(2 * symbolSnr);
observed = mean(demap_symbols(symbols + noise) ~= bits);
theory = 0.5 * erfc(sqrt(symbolSnr / 2));
standardError = sqrt(theory * (1 - theory) / numel(bits));
assert(abs(observed - theory) < 5 * standardError);
end

function test_phase_tracking(settings)
[pilotPositions, ~] = carrier_layout(numel(settings.usedBins), settings.pilotSpacing);
channelEstimate = ones(numel(settings.usedBins), 1);
grid = repmat(training_symbols(settings), 1, 3);
grid(pilotPositions, :) = sqrt(settings.pilotEnergy);
bins = settings.usedBins - mean(settings.usedBins);
distorted = grid .* exp(1i * (0.3 + 0.002 * bins));
[corrected, ~] = correct_pilot_phase(distorted, channelEstimate, pilotPositions, settings);
assert(max(abs(corrected - grid), [], 'all') < 1e-10);
end

function test_fec(settings)
impulse = fec_encode([true; false(6, 1)]);
pairs = reshape(impulse, 2, []);
assert(isequal(pairs(1, 1:7), logical([1 0 1 1 0 1 1])), 'Generator 133 taps.');
assert(isequal(pairs(2, 1:7), logical([1 1 1 1 0 0 1])), 'Generator 171 taps.');
stream = RandStream('mt19937ar', 'Seed', settings.seed + 30);
bits = rand(stream, 576, 1) > 0.5;
coded = fec_encode(bits);
assert(numel(coded) == 2 * (576 + 6));
llr = 1 - 2 * double(coded);
assert(isequal(fec_decode(llr, 576), bits), 'Noiseless round trip.');
llr(1:97:end) = -llr(1:97:end);
assert(isequal(fec_decode(llr, 576), bits), 'Scattered errors corrected.');
permutation = fec_interleaver(1344, settings.fecInterleaverColumns);
assert(isequal(sort(permutation), (1:1344).'), 'Interleaver is a permutation.');
positions(permutation) = 1:1344;
assert(min(abs(diff(positions))) >= 1344 / settings.fecInterleaverColumns, 'Adjacent bits separated.');
payload = uint8((0:settings.packetPayloadBytes-1).');
passes = zeros(1, 2);
for useFec = [false, true]
    settings.useFec = useFec;
    [waveform, metadata] = make_audio_frame(payload, settings);
    clean = conv(waveform, settings.demoChannel);
    noiseStream = RandStream('mt19937ar', 'Seed', settings.seed + 31);
    for trial = 1:5
        noisy = clean + rms(clean) * 10^(-4 / 20) * randn(noiseStream, numel(clean), 1);
        decoded = decode_audio_frame([zeros(137, 1); noisy; zeros(5000, 1)], numel(payload), settings);
        passes(useFec + 1) = passes(useFec + 1) + decoded.passed;
    end
    if useFec
        assert(isequal(decoded.decodedBits, metadata.packetBits));
    end
end
assert(passes(2) == 5 && passes(1) < passes(2), 'FEC must beat uncoded at 4 dB.');
end

function test_pictures(settings)
files = dir(fullfile(settings.paths.images, '*.png'));
names = [{'checkerboard'}, setdiff(erase({files.name}, '.png'), {'gallery'})];
assert(numel(names) >= 5, 'Picture library missing: run make_picture_library.');
for k = 1:numel(names)
    picture = load_picture(names{k}, settings);
    assert(isa(picture, 'uint8') && isequal(size(picture), settings.imageSize), names{k});
end
settings.useFec = true;
picture = load_picture('smiley', settings);
[waveform, manifest] = make_audio_transmission(picture, settings);
result = decode_audio_transmission([waveform; zeros(2000, 1)], manifest, settings);
assert(all(result.passed) && isequal(result.receivedImage, picture) && result.ber == 0);
firstFrameEnd = round(settings.audioLeadingSilence * settings.sampleRate) + manifest.samplesPerFrameWithGap;
result = decode_audio_transmission([waveform(firstFrameEnd + 1:end); zeros(2000, 1)], manifest, settings);
assert(nnz(result.passed) == manifest.numberOfPackets - 1 && result.ber == 0);
end

function test_audio_packet(settings)
payload = uint8((0:settings.packetPayloadBytes-1).');
[waveform, metadata] = make_audio_frame(payload, settings);
recording = [zeros(137, 1); conv(waveform, settings.demoChannel); zeros(5000, 1)];
decoded = decode_audio_frame(recording, numel(payload), settings);
assert(decoded.passed && isequal(decoded.payloadBytes, payload));
assert(isequal(decoded.decodedBits, metadata.packetBits));
assert(max(abs(waveform)) <= settings.audioPeak + eps);
end

function test_sampling_clock(settings)
payload = uint8((0:settings.packetPayloadBytes-1).');
[waveform, ~] = make_audio_frame(payload, settings);
received = [zeros(137, 1); conv(waveform, settings.demoChannel); zeros(5000, 1)];
clockRatio = 1 + 30e-6;
sampleLocations = (1:clockRatio:numel(received)).';
recording = interp1((1:numel(received)).', received, sampleLocations, 'linear', 0);
decoded = decode_audio_frame(recording, numel(payload), settings);
assert(decoded.passed && isequal(decoded.payloadBytes, payload));
end

function test_packet_rejection(settings)
payload = zeros(settings.packetPayloadBytes, 1, 'uint8');
packet = make_packet(payload);
corrupted = packet;
corrupted(1) = ~corrupted(1);
assert(mean(corrupted ~= packet) < settings.targetBer * 2);
assert(~check_packet(corrupted));
end

function test_resample(settings)
time = (0:47999).' / settings.sampleRate;
tone = sin(2 * pi * 3000 * time) .* (0.5 - 0.5 * cos(2 * pi * (0:47999).' / 47999));
roundTrip = resample_audio(resample_audio(tone, 48000, 44100), 44100, 48000);

assert(numel(roundTrip) == numel(tone));
assert(max(abs(roundTrip - tone)) < 1e-3);
end
