function numberOfDataSymbols = audio_data_symbols(packetLengthBits, settings)
[~, dataPositions] = carrier_layout(numel(settings.usedBins), settings.pilotSpacing);
bitsPerOfdmSymbol = 2 * numel(dataPositions);

if settings.useFec
    transmittedBits = 2 * (packetLengthBits + 6);
else
    transmittedBits = packetLengthBits;
end

numberOfDataSymbols = ceil(transmittedBits / bitsPerOfdmSymbol);
end
