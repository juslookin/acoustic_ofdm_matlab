function [waveform, metadata] = make_audio_frame(payloadBytes, settings)
[pilotPositions, dataPositions] = carrier_layout(numel(settings.usedBins), settings.pilotSpacing);
packetBits = make_packet(payloadBytes);
bitsPerOfdmSymbol = 2 * numel(dataPositions);
numberOfDataSymbols = audio_data_symbols(numel(packetBits), settings);

if settings.useFec
    codedBits = fec_encode(packetBits);
    paddedBits = [codedBits; false(numberOfDataSymbols * bitsPerOfdmSymbol - numel(codedBits), 1)];
    paddedBits = paddedBits(fec_interleaver(numel(paddedBits), settings.fecInterleaverColumns));
else
    paddedBits = [packetBits; false(numberOfDataSymbols * bitsPerOfdmSymbol - numel(packetBits), 1)];
end

dataGrid = zeros(numel(settings.usedBins), numberOfDataSymbols);
dataGrid(pilotPositions, :) = sqrt(settings.pilotEnergy);
dataGrid(dataPositions, :) = reshape(sqrt(settings.symbolEnergy) * modulate_bits(paddedBits), numel(dataPositions), []);

training = repmat(training_symbols(settings), 1, settings.trainingSymbols);
ofdmWaveform = ofdm_modulate([training, dataGrid], settings, true);
preamble = make_chirp(settings.preambleDuration, settings.preambleStartHz, settings.preambleEndHz, settings.sampleRate, false);

guard = zeros(round(settings.preambleGuardSeconds * settings.sampleRate), 1);
unscaledWaveform = [preamble; guard; ofdmWaveform];
transmitGain = settings.audioPeak / max(abs(unscaledWaveform));
waveform = transmitGain * unscaledWaveform;

metadata.packetBits = packetBits;
metadata.transmitGain = transmitGain;
metadata.numberOfDataSymbols = numberOfDataSymbols;
metadata.numberOfSamples = numel(waveform);
end
