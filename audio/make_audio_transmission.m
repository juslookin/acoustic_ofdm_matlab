function [waveform, manifest] = make_audio_transmission(imageBytes, settings)
%MAKE_AUDIO_TRANSMISSION Fixed-length audio packets with protected IDs/lengths.
% Input: uint8 image matrix, settings. Outputs: real mono samples and manifest.
% Each packet has 2-byte ID, 2-byte valid-data length, 64 data bytes, CRC32.
bytes = imageBytes(:);
numberOfPackets = ceil(numel(bytes) / settings.packetPayloadBytes);
frames = cell(numberOfPackets, 1);
manifest.packetMetadata = cell(numberOfPackets, 1);
for packetIndex = 1:numberOfPackets
    firstByte = (packetIndex - 1) * settings.packetPayloadBytes + 1;
    validLength = min(settings.packetPayloadBytes, numel(bytes) - firstByte + 1);
    payload = zeros(settings.packetPayloadBytes, 1, 'uint8');
    payload(1:validLength) = bytes(firstByte:firstByte + validLength - 1);
    header = uint8([floor(packetIndex / 256); mod(packetIndex, 256); floor(validLength / 256); mod(validLength, 256)]);
    [frame, metadata] = make_audio_frame([header; payload], settings);
    frames{packetIndex} = [frame; zeros(round(settings.interPacketSilence * settings.sampleRate), 1)];
    manifest.packetMetadata{packetIndex} = metadata;
end
waveform = [zeros(round(settings.audioLeadingSilence * settings.sampleRate), 1); ...
    vertcat(frames{:}); zeros(round(settings.audioTrailingSilence * settings.sampleRate), 1)];
manifest.numberOfPackets = numberOfPackets;
manifest.imageSize = size(imageBytes);
manifest.numberOfBytes = numel(bytes);
manifest.payloadLengthWithHeader = settings.packetPayloadBytes + 4;
manifest.samplesPerFrameWithGap = numel(frames{1});
manifest.durationSeconds = numel(waveform) / settings.sampleRate;
end
