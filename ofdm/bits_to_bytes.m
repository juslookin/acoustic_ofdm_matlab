function bytes = bits_to_bytes(bits)
%BITS_TO_BYTES Inverse byte serialization, most-significant bit first.
% Input: bits logical [8*numberOfBytes x 1]. Output: uint8 [numberOfBytes x 1].
assert(mod(numel(bits), 8) == 0, 'Incomplete byte.');
bitGroups = reshape(double(bits(:)), 8, []).';
bytes = uint8(bitGroups * (2.^(7:-1:0)).');
end
