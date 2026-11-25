function report = run_tests()
settings = config();
rng(settings.seed, 'twister');

tests = {@test_qpsk, @test_crc, @test_ofdm, @test_cyclic_prefix, @test_noise, ...
    @test_pilots, @test_packet, @test_clock_drift, @test_bad_packet, @test_fec, @test_pictures};
names = cellfun(@func2str, tests, 'UniformOutput', false).';
passed = false(numel(tests), 1);
messages = repmat({'PASS'}, numel(tests), 1);

for k = 1:numel(tests)
    try
        tests{k}(settings);
        passed(k) = true;
    catch problem
        messages{k} = problem.message;
    end
    fprintf('%s: %s\n', names{k}, messages{k});
end

report = table(names, passed, messages, 'VariableNames', {'Test', 'Passed', 'Message'});
writetable(report, fullfile(settings.paths.results, 'tests.csv'));
assert(all(passed), '%d tests failed.', nnz(~passed));
fprintf('All %d tests passed.\n', numel(tests));
end

function test_qpsk(~)
bits = logical([0 0 0 1 1 0 1 1]).';
symbols = ofdm.qpsk(bits);

assert(isequal(ofdm.qpskBits(symbols), bits));
assert(all(abs(abs(symbols) - 1) < 1e-12));
assert(numel(unique(round(symbols, 9))) == 4);
end

function test_crc(~)
assert(packets.crc32(uint8('123456789')) == uint32(hex2dec('CBF43926')));

bytes = uint8((0:255).');
assert(isequal(packets.toBytes(packets.toBits(bytes)), bytes));

bits = packets.make(bytes);
assert(packets.check(bits));
bits(73) = ~bits(73);
assert(~packets.check(bits));
end

function test_ofdm(settings)
grid = reshape(ofdm.qpsk(rand(2 * numel(settings.usedBins) * 3, 1) > 0.5), [], 3);

for realWaveform = [false, true]
    waveform = ofdm.modulate(grid, settings, realWaveform);
    assert(max(abs(ofdm.demodulate(waveform, settings) - grid), [], 'all') < 1e-12);
    assert(~realWaveform || isreal(waveform));
end
end

function test_cyclic_prefix(settings)
grid = randn(numel(settings.usedBins), 2) + 1i * randn(numel(settings.usedBins), 2);
waveform = ofdm.modulate(grid, settings, true);

received = conv(waveform, settings.demoChannel);
recovered = ofdm.demodulate(received(1:numel(waveform)), settings);
response = fft(settings.demoChannel, settings.fftSize);
assert(max(abs(recovered - response(settings.usedBins + 1) .* grid), [], 'all') < 1e-10);
end

function test_noise(~)
snr = 10^(6 / 10);
bits = rand(600000, 1) > 0.5;
symbols = ofdm.qpsk(bits);
noise = (randn(size(symbols)) + 1i * randn(size(symbols))) / sqrt(2 * snr);

measured = mean(ofdm.qpskBits(symbols + noise) ~= bits);
theory = 0.5 * erfc(sqrt(snr / 2));
assert(abs(measured - theory) < 5 * sqrt(theory / numel(bits)));
end

function test_pilots(settings)
[pilots, ~] = ofdm.layout(settings);
grid = repmat(ofdm.training(settings), 1, 3);
grid(pilots, :) = sqrt(settings.pilotEnergy);

bins = settings.usedBins - mean(settings.usedBins);
drifted = grid .* exp(1i * (0.3 + 0.002 * bins));
fixed = ofdm.fixPhase(drifted, ones(numel(settings.usedBins), 1), pilots, settings);
assert(max(abs(fixed - grid), [], 'all') < 1e-10);
end

function test_packet(settings)
payload = uint8((0:63).');
[waveform, manifest] = transmitter(payload, settings);

recording = [zeros(137, 1); conv(waveform, settings.demoChannel)];
result = receiver(recording, manifest, settings);
assert(result.passed && isequal(result.receivedImage, payload));
assert(max(abs(waveform)) <= settings.audioPeak + eps);
end

function test_clock_drift(settings)
payload = uint8((0:63).');
[waveform, manifest] = transmitter(payload, settings);

clean = conv(waveform, settings.demoChannel);
drifted = interp1((1:numel(clean)).', clean, (1:1 + 30e-6:numel(clean)).', 'linear', 0);
result = receiver(drifted, manifest, settings);
assert(result.passed);
end

function test_bad_packet(~)
bits = packets.make(zeros(64, 1, 'uint8'));
bits(1) = ~bits(1);
assert(~packets.check(bits));
end

function test_fec(settings)
impulse = reshape(fec.encode([true; false(6, 1)]), 2, []);
assert(isequal(impulse(1, 1:7), logical([1 0 1 1 0 1 1])));
assert(isequal(impulse(2, 1:7), logical([1 1 1 1 0 0 1])));

bits = rand(576, 1) > 0.5;
llr = 1 - 2 * double(fec.encode(bits));
assert(isequal(fec.decode(llr, 576), bits));
llr(1:97:end) = -llr(1:97:end);
assert(isequal(fec.decode(llr, 576), bits));

order = fec.interleaver(1344, settings.fecInterleaverColumns);
assert(isequal(sort(order), (1:1344).'));

payload = uint8((0:63).');
passes = [0, 0];
for useFec = [false, true]
    settings.useFec = useFec;
    [waveform, manifest] = transmitter(payload, settings);
    clean = conv(waveform, settings.demoChannel);
    level = rms(clean(clean ~= 0));
    stream = RandStream('mt19937ar', 'Seed', settings.seed + 31);

    for trial = 1:5
        noisy = clean + level * 10^(-4 / 20) * randn(stream, numel(clean), 1);
        result = receiver(noisy, manifest, settings);
        passes(useFec + 1) = passes(useFec + 1) + result.passed;
    end
end
assert(passes(2) == 5 && passes(1) < passes(2), 'Error correction should win at 4 dB.');
end

function test_pictures(settings)
for name = {'checkerboard', 'smiley', 'heart', 'ofdm', 'landscape'}
    image = pictures.load(name{1}, settings);
    assert(isa(image, 'uint8') && isequal(size(image), settings.imageSize), name{1});
end

settings.useFec = true;
image = pictures.load('smiley', settings);
[waveform, manifest] = transmitter(image, settings);

result = receiver(waveform, manifest, settings);
assert(all(result.passed) && isequal(result.receivedImage, image) && result.ber == 0);

skip = round(settings.audioLeadingSilence * settings.sampleRate) + manifest.frameLength;
result = receiver(waveform(skip + 1:end), manifest, settings);
assert(nnz(result.passed) == manifest.numberOfPackets - 1 && result.ber == 0);
end
