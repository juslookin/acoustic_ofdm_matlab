function bits = bytes_to_bits(bytes)
%BYTES_TO_BITS Serialize bytes most-significant bit first.
% Input: bytes [numberOfBytes x 1] uint8. Output: logical [8*numberOfBytes x 1].
bytes = uint8(bytes(:));
bitGroups = false(numel(bytes), 8);
for bitIndex = 1:8
    bitGroups(:, bitIndex) = bitget(bytes, 9 - bitIndex) ~= 0;
end
bits = reshape(bitGroups.', [], 1);
end
