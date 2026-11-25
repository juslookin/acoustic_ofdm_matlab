function [waveform, manifest] = transmitter(image, settings)
bytes = image(:);
count = ceil(numel(bytes) / settings.packetPayloadBytes);
gap = zeros(round(settings.interPacketSilence * settings.sampleRate), 1);

frames = cell(count, 1);
manifest.packetBits = cell(count, 1);

for id = 1:count
    first = (id - 1) * settings.packetPayloadBytes + 1;
    len = min(settings.packetPayloadBytes, numel(bytes) - first + 1);
    payload = zeros(settings.packetPayloadBytes, 1, 'uint8');
    payload(1:len) = bytes(first:first + len - 1);

    header = uint8([floor(id / 256); mod(id, 256); floor(len / 256); mod(len, 256)]);
    [frame, manifest.packetBits{id}] = packet_sound([header; payload], settings);
    frames{id} = [frame; gap];
end

lead = zeros(round(settings.audioLeadingSilence * settings.sampleRate), 1);
tail = zeros(round(settings.audioTrailingSilence * settings.sampleRate), 1);
waveform = [lead; vertcat(frames{:}); tail];

manifest.numberOfPackets = count;
manifest.imageSize = size(image);
manifest.numberOfBytes = numel(bytes);
manifest.packetBytes = settings.packetPayloadBytes + 4;
manifest.frameLength = numel(frames{1});
manifest.durationSeconds = numel(waveform) / settings.sampleRate;
end

function [sound, bits] = packet_sound(bytes, settings)
[pilots, data] = ofdm.layout(settings);
bits = packets.make(bytes);
symbolCount = ofdm.dataSymbols(numel(bits), settings);
slots = symbolCount * 2 * numel(data);

if settings.useFec
    coded = fec.encode(bits);
    coded = [coded; false(slots - numel(coded), 1)];
    coded = coded(fec.interleaver(slots, settings.fecInterleaverColumns));
else
    coded = [bits; false(slots - numel(bits), 1)];
end

grid = zeros(numel(settings.usedBins), symbolCount);
grid(pilots, :) = sqrt(settings.pilotEnergy);
grid(data, :) = reshape(sqrt(settings.symbolEnergy) * ofdm.qpsk(coded), numel(data), []);

training = repmat(ofdm.training(settings), 1, settings.trainingSymbols);
guard = zeros(round(settings.preambleGuardSeconds * settings.sampleRate), 1);
sound = [ofdm.chirp(settings); guard; ofdm.modulate([training, grid], settings, true)];
sound = settings.audioPeak * sound / max(abs(sound));
end
