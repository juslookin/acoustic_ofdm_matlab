function symbols = modulate_bits(bits, bitsPerSymbol)
bits = double(bits(:));
assert(any(bitsPerSymbol == [1, 2, 4]), 'Unsupported modulation.');
assert(all(bits == 0 | bits == 1), 'Bits must be zero or one.');
assert(mod(numel(bits), bitsPerSymbol) == 0, 'Incomplete symbol.');
bitGroups = reshape(bits, bitsPerSymbol, []).';

if bitsPerSymbol == 1
    symbols = 1 - 2 * bitGroups(:, 1);
elseif bitsPerSymbol == 2
    symbols = ((1 - 2 * bitGroups(:, 1)) + 1i * (1 - 2 * bitGroups(:, 2))) / sqrt(2);
else
    inPhase = (1 - 2 * bitGroups(:, 1)) .* (3 - 2 * bitGroups(:, 2));
    quadrature = (1 - 2 * bitGroups(:, 3)) .* (3 - 2 * bitGroups(:, 4));
    symbols = (inPhase + 1i * quadrature) / sqrt(10);
end
end
