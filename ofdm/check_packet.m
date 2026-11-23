function [passed, payloadBytes] = check_packet(packetBits)
%CHECK_PACKET Verify CRC; return payload even if corrupt for BER debugging.
% Input: packetBits logical [(payloadBytes+4)*8 x 1]. Outputs: scalar logical,
% payloadBytes uint8 [payloadLength x 1]. Frame length must be known externally.
bytes = bits_to_bytes(packetBits);
assert(numel(bytes) >= 4, 'Packet is too short.');
payloadBytes = bytes(1:end-4);
expectedBits = make_packet(payloadBytes);
passed = isequal(logical(packetBits(:)), expectedBits);
end
