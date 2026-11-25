function bits = demap_loaded_frame(dataSymbols, bitsPerCarrier)
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
