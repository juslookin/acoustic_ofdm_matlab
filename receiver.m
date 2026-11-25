function result = receiver(recording, manifest, settings)
bytes = repmat(uint8(128), manifest.numberOfBytes, 1);
passed = false(manifest.numberOfPackets, 1);
packetsFound = cell(manifest.numberOfPackets, 1);
sent = [manifest.packetBits{:}];

cursor = 1;
errors = 0;
compared = 0;

for k = 1:manifest.numberOfPackets
    if cursor + manifest.frameLength > numel(recording)
        break;
    end

    try
        found = decode_packet(recording(cursor:end), manifest.packetBytes, settings);
        packetsFound{k} = found;
        errors = errors + min(sum(sent ~= found.bits, 1));
        compared = compared + size(sent, 1);
        cursor = cursor + found.lastSample + round(settings.interPacketSilence * settings.sampleRate) - 1;

        if found.passed
            header = double(found.payload(1:4));
            id = 256 * header(1) + header(2);
            len = 256 * header(3) + header(4);
            where = (id - 1) * settings.packetPayloadBytes + (1:len);

            if id >= 1 && id <= manifest.numberOfPackets && all(where <= manifest.numberOfBytes)
                bytes(where) = found.payload(5:4 + len);
                passed(id) = true;
            end
        end
    catch problem
        packetsFound{k} = struct('error', problem.message);
        cursor = cursor + manifest.frameLength;
    end
end

result.receivedImage = reshape(bytes, manifest.imageSize);
result.passed = passed;
result.ber = errors / max(compared, 1);
result.packets = packetsFound;
end

function out = decode_packet(recording, packetBytes, settings)
[chirpStart, score] = ofdm.findChirp(recording, settings);
expected = chirpStart + round((settings.preambleDuration + settings.preambleGuardSeconds) * settings.sampleRate);

known = ofdm.modulate(ofdm.training(settings), settings, true);
from = max(1, expected - settings.syncSearchRadius);
to = min(numel(recording) - numel(known) + 1, expected + settings.syncSearchRadius);
[~, match] = ofdm.matchedFilter(recording(from:to + numel(known) - 1), known);
[~, best] = max(match);
start = max(1, from + best - 1 - settings.timingBackoffSamples);

[pilots, data] = ofdm.layout(settings);
bitCount = packetBytes * 8 + settings.crcBits;
symbolCount = settings.trainingSymbols + ofdm.dataSymbols(bitCount, settings);
lastSample = start + symbolCount * (settings.fftSize + settings.cyclicPrefixLength) - 1;
assert(lastSample <= numel(recording), 'Recording ends early.');

grid = ofdm.demodulate(recording(start:lastSample), settings);
channel = mean(grid(:, 1:settings.trainingSymbols), 2) ./ ofdm.training(settings);
noise = abs(grid(:, 1) - grid(:, 2)).^2 / 2;
noise = max(movmean(noise, settings.noiseSmoothingBins), settings.noiseVarianceFloor);
snr = abs(channel).^2 * settings.symbolEnergy ./ noise;

dataGrid = ofdm.fixPhase(grid(:, settings.trainingSymbols+1:end), channel, pilots, settings);
safe = channel;
safe(abs(safe) < settings.equalizerFloor) = settings.equalizerFloor;
symbols = dataGrid(data, :) ./ safe(data) / sqrt(settings.symbolEnergy);

corrections = NaN;
if settings.useFec
    weight = repmat(snr(data), 1, size(symbols, 2));
    soft = [real(symbols(:)).'; imag(symbols(:)).'] .* [weight(:).'; weight(:).'];
    soft = soft(:);
    soft(fec.interleaver(numel(soft), settings.fecInterleaverColumns)) = soft;

    bits = fec.decode(soft, bitCount);
    coded = 2 * (bitCount + 6);
    corrections = nnz((soft(1:coded) < 0) ~= fec.encode(bits));
else
    bits = ofdm.qpskBits(symbols);
end

bits = bits(1:bitCount);
[out.passed, out.payload] = packets.check(bits);
out.bits = bits;
out.channel = channel;
out.snr = snr;
out.symbols = symbols;
out.corrections = corrections;
out.chirpStart = chirpStart;
out.score = score;
out.lastSample = lastSample;
end
