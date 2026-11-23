function bits = demap_loaded_frame(dataSymbols, bitsPerCarrier)
%DEMAP_LOADED_FRAME Inverse of map_loaded_frame in the same traversal order.
% Inputs: equalized data [D x S], loading [D x 1]. Output: logical [capacity x 1].
bits = false(sum(bitsPerCarrier) * size(dataSymbols, 2), 1);
carrierOffsets = [0; cumsum(bitsPerCarrier(1:end-1))];
bitOffsets = carrierOffsets + sum(bitsPerCarrier) * (0:size(dataSymbols, 2)-1);
for modulationBits = [1, 2, 4]
    selectedCarriers = find(bitsPerCarrier == modulationBits);
    selectedOffsets = bitOffsets(selectedCarriers, :);
    bitIndices = (1:modulationBits).' + selectedOffsets(:).';
    selectedSymbols = dataSymbols(selectedCarriers, :);
    demappedBits = demap_symbols(selectedSymbols(:), modulationBits);
    bits(bitIndices(:)) = demappedBits;
end
end
