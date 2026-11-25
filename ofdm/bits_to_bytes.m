function bytes = bits_to_bytes(bits)
assert(mod(numel(bits), 8) == 0, 'Incomplete byte.');
bitGroups = reshape(double(bits(:)), 8, []).';
bytes = uint8(bitGroups * (2.^(7:-1:0)).');
end
