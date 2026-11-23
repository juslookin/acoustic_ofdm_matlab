function bits = demap_symbols(symbols, bitsPerSymbol)
%DEMAP_SYMBOLS Minimum-distance hard decisions, inverse of modulate_bits.
% Input: symbols [numberOfSymbols x 1]; bitsPerSymbol 1,2,4.
% Output: bits [numberOfSymbols*bitsPerSymbol x 1] logical.
symbols = symbols(:);
assert(any(bitsPerSymbol == [1, 2, 4]), 'Unsupported modulation.');
bitGroups = false(numel(symbols), bitsPerSymbol);
bitGroups(:, 1) = real(symbols) < 0;
if bitsPerSymbol == 2
    bitGroups(:, 2) = imag(symbols) < 0;
elseif bitsPerSymbol == 4
    bitGroups(:, 2) = abs(real(symbols)) < 2 / sqrt(10);
    bitGroups(:, 3) = imag(symbols) < 0;
    bitGroups(:, 4) = abs(imag(symbols)) < 2 / sqrt(10);
end
bits = reshape(bitGroups.', [], 1);
end
