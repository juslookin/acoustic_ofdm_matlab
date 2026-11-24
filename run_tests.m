function report = run_tests()
%RUN_TESTS Deterministic base-MATLAB correctness and statistical regression tests.
% Input: none. Output: table. Throws an error if any test fails; no physical I/O.
settings = startup_project();
rng(settings.seed, 'twister');
testFunctions = {@test_modulations, @test_crc, @test_loaded_mapping, ...
    @test_ofdm, @test_cyclic_prefix, @test_real_channel_consistency, ...
    @test_covariance, @test_outage, @test_awgn, @test_psd, ...
    @test_deconvolution, @test_phase_tracking, @test_audio_packet, ...
    @test_sampling_clock, @test_packet_rejection, @test_adaptive_power, ...
    @test_resample_convolve, @test_fec};
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
% Exhaustively check every constellation point, energy and Gray neighbours.
for modulationBits = [1, 2, 4]
    integers = uint8((0:2^modulationBits-1).');
    groups = false(numel(integers), modulationBits);
    for bitIndex = 1:modulationBits
        groups(:, bitIndex) = bitget(integers, modulationBits-bitIndex+1) ~= 0;
    end
    bits = reshape(groups.', [], 1);
    symbols = modulate_bits(bits, modulationBits);
    assert(isequal(demap_symbols(symbols, modulationBits), bits));
    assert(abs(mean(abs(symbols).^2) - 1) < 1e-12);
    distances = abs(symbols - symbols.');
    minimumDistance = min(distances(distances > 1e-10));
    [first, second] = find(abs(distances - minimumDistance) < 1e-10);
    assert(all(sum(groups(first, :) ~= groups(second, :), 2) == 1));
end
end

function test_crc(~)
% External CRC check vector, reversible serialization and single-bit detection.
assert(crc32_bytes(uint8('123456789')) == uint32(hex2dec('CBF43926')));
bytes = uint8((0:255).');
assert(isequal(bits_to_bytes(bytes_to_bits(bytes)), bytes));
packet = make_packet(bytes);
assert(check_packet(packet));
packet(73) = ~packet(73);
assert(~check_packet(packet));
end

function test_loaded_mapping(~)
% Mixed loading includes off, BPSK, QPSK and QAM in one serialized frame.
loading = [0; 1; 4; 2; 0; 4];
bits = rand(sum(loading) * 3, 1) > 0.5;
symbols = map_loaded_frame(bits, loading, 3);
assert(all(symbols(loading == 0, :) == 0, 'all'));
assert(isequal(demap_loaded_frame(symbols, loading), bits));
end

function test_ofdm(settings)
% Both complex and Hermitian waveforms invert exactly; verify Parseval scaling.
symbols = modulate_bits(rand(2 * numel(settings.usedBins) * 3, 1) > 0.5, 2);
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
% Actual linear convolution equals one-tap frequency multiplication with CP.
grid = randn(numel(settings.usedBins), 2) + 1i * randn(numel(settings.usedBins), 2);
taps = [1; zeros(8, 1); 0.3 + 0.2i];
waveform = ofdm_modulate(grid, settings, false);
received = conv(waveform, taps);
recovered = ofdm_demodulate(received(1:numel(waveform)), settings);
response = fft(taps, settings.fftSize);
assert(max(abs(recovered - response(settings.usedBins+1) .* grid), [], 'all') < 1e-10);
end

function test_real_channel_consistency(settings)
% Real FIR + mirrored bins produces the same positive-bin complex channel law.
grid = randn(numel(settings.usedBins), 2) + 1i * randn(numel(settings.usedBins), 2);
waveform = ofdm_modulate(grid, settings, true);
received = conv(waveform, settings.demoChannel);
recovered = ofdm_demodulate(received(1:numel(waveform)), settings);
response = fft(settings.demoChannel, settings.fftSize);
assert(max(abs(recovered - response(settings.usedBins+1) .* grid), [], 'all') < 1e-10);
end

function test_covariance(settings)
% General correlated pilot noise and non-unit pilot phases/energies.
[basis, covariance, ~] = channel_statistics(settings);
positions = (1:8:numel(settings.usedBins)).';
pilots = sqrt(2) * exp(1i * (1:numel(positions)).');
noiseCovariance = 0.1 * toeplitz(0.5.^(0:numel(positions)-1));
[~, weights, errorCovariance] = estimator_weights(covariance, positions, noiseCovariance, pilots);
channels = draw_channels(basis, settings.channelTapPowers, 12000);
noise = chol(noiseCovariance, 'lower') * (randn(numel(positions), 12000) + 1i * randn(numel(positions), 12000)) / sqrt(2);
observations = channels(positions, :) + noise ./ pilots;
errors = weights * observations - channels;
empirical = mean(abs(errors).^2, 'all');
theory = mean(real(diag(errorCovariance)));
assert(abs(empirical / theory - 1) < 0.06);
assert(min(eig(errorCovariance)) > -1e-10);
end

function test_outage(settings)
% Zero channel must turn adaptive carriers off; fixed QPSK stays fixed.
carriers = numel(settings.usedBins);
[~, dataPositions] = carrier_layout(carriers, settings.pilotSpacing);
for method = {'naive', 'aware'}
    loading = select_loading(zeros(carriers, 1), ones(carriers, 1), ones(carriers, 1), dataPositions, settings, method{1});
    assert(all(loading == 0));
end
loading = select_loading(ones(carriers, 1), zeros(carriers, 1), 1e-6 * ones(carriers, 1), dataPositions, settings, 'aware');
assert(all(loading == 4));
end

function test_awgn(~)
% A finite Monte Carlo need not land inside every 95% interval. Use a 5-sigma
% regression tolerance here; the full experiment saves honest 95% intervals.
symbolSnr = 10^(6 / 10);
for modulationBits = [1, 2, 4]
    bits = rand(300000 * modulationBits, 1) > 0.5;
    symbols = modulate_bits(bits, modulationBits);
    noise = (randn(size(symbols)) + 1i * randn(size(symbols))) / sqrt(2 * symbolSnr);
    observed = mean(demap_symbols(symbols + noise, modulationBits) ~= bits);
    theory = theoretical_ber(symbolSnr, modulationBits);
    standardError = sqrt(theory * (1 - theory) / numel(bits));
    assert(abs(observed - theory) < 5 * standardError);
end
end

function test_psd(settings)
% Integrated one-sided PSD estimates variance; real positive FFT bins have
% complex noise variance sigma_time^2 under unitary FFT normalization.
noise = 0.2 * randn(200000, 1);
[frequencies, psd] = welch_psd(noise, settings.sampleRate, 4096, 0.5);
assert(abs(trapz(frequencies, psd) / var(noise, 1) - 1) < 0.03);
blocks = reshape(noise(1:settings.fftSize*100), settings.fftSize, 100);
spectra = fft(blocks, [], 1) / sqrt(settings.fftSize);
assert(abs(mean(abs(spectra(settings.usedBins+1, :)).^2, 'all') / 0.04 - 1) < 0.05);
end

function test_deconvolution(settings)
% Recover a known delayed real FIR from a sweep without physical hardware.
probe = make_chirp(settings.sweepDuration, settings.sweepStartHz, settings.sweepEndHz, settings.sampleRate, true);
recording = [zeros(200, 1); conv(probe, settings.demoChannel); zeros(5000, 1)];
[estimated, statistics] = estimate_impulse_response(probe, recording, settings);
assert(abs(statistics.strongestArrivalSeconds * settings.sampleRate - 200) <= 1);
assert(abs(estimated(25) / estimated(1) - 0.25) < 0.08);
assert(statistics.energy99Seconds <= 0.005);
end

function test_phase_tracking(settings)
% Recover an imposed common rotation and modest linear phase slope exactly.
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
% Convolutional code: generator taps, round trip, correction, interleaver,
% and a full audio packet at an SNR where uncoded QPSK usually fails.
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
llr(1:97:end) = -llr(1:97:end); % 12 scattered hard errors
assert(isequal(fec_decode(llr, 576), bits), 'Scattered errors corrected.');
permutation = fec_interleaver(1344, settings.fecInterleaverColumns);
assert(isequal(sort(permutation), (1:1344).'), 'Interleaver is a permutation.');
positions(permutation) = 1:1344;
assert(min(abs(diff(positions))) >= 1344 / settings.fecInterleaverColumns, 'Adjacent bits separated.');
% Audio packet at 4 dB broadband SNR: coded must pass, uncoded mostly fails.
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

function test_audio_packet(settings)
% Full packet through actual real waveform, multipath, latency and CRC.
payload = uint8((0:settings.packetPayloadBytes-1).');
[waveform, metadata] = make_audio_frame(payload, settings);
recording = [zeros(137, 1); conv(waveform, settings.demoChannel); zeros(5000, 1)];
decoded = decode_audio_frame(recording, numel(payload), settings);
assert(decoded.passed && isequal(decoded.payloadBytes, payload));
assert(isequal(decoded.decodedBits, metadata.packetBits));
assert(max(abs(waveform)) <= settings.audioPeak + eps);
end

function test_sampling_clock(settings)
% Inputs: settings; output: assertion. Modest synthetic sample-clock mismatch.
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
% Inputs: settings; output: assertion. CRC failure is distinct from bit BER.
payload = zeros(settings.packetPayloadBytes, 1, 'uint8');
packet = make_packet(payload);
corrupted = packet;
corrupted(1) = ~corrupted(1);
assert(mean(corrupted ~= packet) < settings.targetBer * 2);
assert(~check_packet(corrupted));
end

function test_adaptive_power(settings)
% Inputs: settings; output: assertion. Outage stays silent and no data is
% delivered when the entire estimated channel is zero.
carriers = numel(settings.usedBins);
[~, dataPositions] = carrier_layout(carriers, settings.pilotSpacing);
noise = zeros(numel(dataPositions), settings.dataSymbolsPerFrame);
payload = uint8(randi([0, 255], 1024, 1));
metrics = evaluate_adaptive_frame(ones(carriers, 1), zeros(carriers, 1), ones(carriers, 1), ...
    ones(carriers, 1), dataPositions, noise, payload, settings, 'aware');
assert(metrics(2) == 0 && metrics(5) == 0 && metrics(6) == 1 && metrics(8) == 0);
end

function test_resample_convolve(settings)
% Inputs: settings; output: assertion. FFT convolution equals conv, and
% band-limited resampling 48 -> 44.1 -> 48 kHz preserves an in-band tone.
signal = randn(5000, 1);
taps = randn(300, 1);
assert(max(abs(fft_convolve(signal, taps) - conv(signal, taps))) < 1e-9);
% Direct-path-only room is a scalar FIR; output must stay a column.
assert(isequal(size(fft_convolve(signal, 1)), [numel(signal), 1]));
assert(max(abs(fft_convolve(signal, 1) - signal(:))) < 1e-12);
time = (0:47999).' / settings.sampleRate;
tone = sin(2 * pi * 3000 * time) .* (0.5 - 0.5 * cos(2 * pi * (0:47999).' / 47999));
roundTrip = resample_audio(resample_audio(tone, 48000, 44100), 44100, 48000);
assert(numel(roundTrip) == numel(tone));
assert(max(abs(roundTrip - tone)) < 1e-3);
end
