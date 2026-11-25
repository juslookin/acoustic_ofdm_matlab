function [passed, payloadBytes] = check_packet(packetBits)
bytes = bits_to_bytes(packetBits);
assert(numel(bytes) >= 4, 'Packet is too short.');
payloadBytes = bytes(1:end-4);
expectedBits = make_packet(payloadBytes);
passed = isequal(logical(packetBits(:)), expectedBits);
end
