function result = decode_audio_transmission(recording, manifest, settings)
%DECODE_AUDIO_TRANSMISSION Decode sequential packets and reconstruct an image.
% Inputs: real recording [T x 1], known image/packet manifest, settings.
% Output: image with CRC failures gray, packet flags and receiver diagnostics.
receivedBytes = repmat(uint8(128), manifest.numberOfBytes, 1);
passed = false(manifest.numberOfPackets, 1);
diagnostics = cell(manifest.numberOfPackets, 1);
referenceBits = cell2mat(cellfun(@(entry) entry.packetBits(:), manifest.packetMetadata(:).', ...
    'UniformOutput', false));
cursor = 1;
errors = 0;
comparedBits = 0;
for packetIndex = 1:manifest.numberOfPackets
    if cursor + manifest.samplesPerFrameWithGap > numel(recording)
        break;
    end
    try
        decoded = decode_audio_frame(recording(cursor:end), manifest.payloadLengthWithHeader, settings);
        diagnostics{packetIndex} = decoded;
        % Compare with the closest transmitted packet, not the packet with
        % the same position: one missed chirp would otherwise misalign every
        % later comparison and report BER near 0.5 for a working link.
        packetErrors = sum(referenceBits ~= decoded.decodedBits, 1);
        errors = errors + min(packetErrors);
        comparedBits = comparedBits + size(referenceBits, 1);
        cursor = cursor + decoded.lastSample + round(settings.interPacketSilence * settings.sampleRate) - 1;
        if decoded.passed
            header = double(decoded.payloadBytes(1:4));
            receivedId = 256 * header(1) + header(2);
            validLength = 256 * header(3) + header(4);
            if receivedId >= 1 && receivedId <= manifest.numberOfPackets && validLength <= settings.packetPayloadBytes
                bytePositions = (receivedId - 1) * settings.packetPayloadBytes + (1:validLength);
                if all(bytePositions <= manifest.numberOfBytes)
                    receivedBytes(bytePositions) = decoded.payloadBytes(5:4 + validLength);
                    passed(receivedId) = true;
                end
            end
        end
    catch receiverError
        diagnostics{packetIndex} = struct('error', receiverError.message);
        cursor = cursor + manifest.samplesPerFrameWithGap;
    end
end
result.receivedImage = reshape(receivedBytes, manifest.imageSize);
result.passed = passed;
result.packetSuccess = mean(passed);
result.ber = errors / max(comparedBits, 1);
result.comparedBits = comparedBits;
result.errors = errors;
result.diagnostics = diagnostics;
% BER is available only because this demonstration has the transmitted bits.
% A standalone receiver can report CRC success without knowing the original.
end
