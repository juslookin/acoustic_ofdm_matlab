function numberOfDataSymbols = audio_data_symbols(packetLengthBits, settings)
%AUDIO_DATA_SYMBOLS Data OFDM symbols needed for one audio packet.
% Input: packet length in bits (payload + CRC), settings. With FEC the
% packet is convolutionally coded (2*(N+6) bits) before QPSK mapping.
[~, dataPositions] = carrier_layout(numel(settings.usedBins), settings.pilotSpacing);
bitsPerOfdmSymbol = 2 * numel(dataPositions);
if settings.useFec
    transmittedBits = 2 * (packetLengthBits + 6);
else
    transmittedBits = packetLengthBits;
end
numberOfDataSymbols = ceil(transmittedBits / bitsPerOfdmSymbol);
end
