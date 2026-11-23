function dataSymbols = map_loaded_frame(bits, bitsPerCarrier, numberOfSymbols)
%MAP_LOADED_FRAME Traverse OFDM columns, then data carriers within each column.
% Inputs: bits [sum(loading)*numberOfSymbols x 1], loading [D x 1].
% Output: dataSymbols [D x numberOfSymbols]; off carriers are exactly zero.
assert(numel(bits) == sum(bitsPerCarrier) * numberOfSymbols, 'Capacity mismatch.');
dataSymbols = zeros(numel(bitsPerCarrier), numberOfSymbols);
carrierOffsets = [0; cumsum(bitsPerCarrier(1:end-1))];
bitOffsets = carrierOffsets + sum(bitsPerCarrier) * (0:numberOfSymbols-1);
for modulationBits = [1, 2, 4]
    selectedCarriers = find(bitsPerCarrier == modulationBits);
    selectedOffsets = bitOffsets(selectedCarriers, :);
    bitIndices = (1:modulationBits).' + selectedOffsets(:).';
    mappedSymbols = modulate_bits(bits(bitIndices(:)), modulationBits);
    dataSymbols(selectedCarriers, :) = reshape(mappedSymbols, numel(selectedCarriers), numberOfSymbols);
end
end
