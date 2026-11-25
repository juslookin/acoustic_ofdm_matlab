function packetBits = make_packet(payloadBytes)
checksum = crc32_bytes(uint8(payloadBytes));
checksumBytes = zeros(4, 1, 'uint8');

for byteIndex = 1:4
    checksumBytes(byteIndex) = uint8(bitand(bitshift(checksum, -8 * (4 - byteIndex)), uint32(255)));
end

packetBits = bytes_to_bits([uint8(payloadBytes(:)); checksumBytes]);
end
