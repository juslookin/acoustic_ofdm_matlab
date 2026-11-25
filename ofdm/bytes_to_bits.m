function bits = bytes_to_bits(bytes)
bytes = uint8(bytes(:));
bitGroups = false(numel(bytes), 8);

for bitIndex = 1:8
    bitGroups(:, bitIndex) = bitget(bytes, 9 - bitIndex) ~= 0;
end

bits = reshape(bitGroups.', [], 1);
end
