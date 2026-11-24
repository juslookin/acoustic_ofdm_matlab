function result = decode_audio_frame(recording, payloadLength, settings)
%DECODE_AUDIO_FRAME Chirp sync -> training timing -> FFT -> LS -> phase -> CRC.
% Inputs: real recording [T x 1], known payloadLength bytes, settings.
% Output: structure with CRC, bytes, diagnostics and consumed sample count.
[preambleStart, score] = find_preamble(recording, settings);
preambleSamples = round(settings.preambleDuration * settings.sampleRate);
guardSamples = round(settings.preambleGuardSeconds * settings.sampleRate);
expectedOfdmStart = preambleStart + preambleSamples + guardSamples;
knownTraining = ofdm_modulate(training_symbols(settings), settings, true);
firstCandidate = max(1, expectedOfdmStart - settings.syncSearchRadius);
lastCandidate = min(numel(recording) - numel(knownTraining) + 1, expectedOfdmStart + settings.syncSearchRadius);
searchRecording = recording(firstCandidate:lastCandidate + numel(knownTraining) - 1);
[~, trainingCorrelation] = matched_filter(searchRecording, knownTraining);
[~, bestIndex] = max(trainingCorrelation);
ofdmStart = max(1, firstCandidate + bestIndex - 1 - settings.timingBackoffSamples);
[pilotPositions, dataPositions] = carrier_layout(numel(settings.usedBins), settings.pilotSpacing);
packetLengthBits = payloadLength * 8 + settings.crcBits;
numberOfDataSymbols = ceil(packetLengthBits / (2 * numel(dataPositions)));
numberOfOfdmSymbols = settings.trainingSymbols + numberOfDataSymbols;
lastSample = ofdmStart + numberOfOfdmSymbols * (settings.fftSize + settings.cyclicPrefixLength) - 1;
assert(lastSample <= numel(recording), 'Recording ends before the packet.');
receivedGrid = ofdm_demodulate(recording(ofdmStart:lastSample), settings);
knownSymbols = training_symbols(settings);
channelEstimate = mean(receivedGrid(:, 1:settings.trainingSymbols), 2) ./ knownSymbols;
% Difference cancels a constant channel: E|Y1-Y2|^2 / 2 = per-bin noise.
rawNoiseVariance = abs(receivedGrid(:, 1) - receivedGrid(:, 2)).^2 / 2;
noiseVariance = max(movmean(rawNoiseVariance, settings.noiseSmoothingBins), settings.noiseVarianceFloor);
dataGrid = receivedGrid(:, settings.trainingSymbols+1:end);
[correctedGrid, phaseParameters] = correct_pilot_phase(dataGrid, channelEstimate, pilotPositions, settings);
safeEstimate = channelEstimate;
safeEstimate(abs(safeEstimate) < settings.equalizerFloor) = settings.equalizerFloor;
equalized = correctedGrid(dataPositions, :) ./ safeEstimate(dataPositions) / sqrt(settings.symbolEnergy);
decodedBits = demap_symbols(equalized(:), 2);
[passed, bytes] = check_packet(decodedBits(1:packetLengthBits));
result.passed = passed;
result.payloadBytes = bytes;
result.decodedBits = decodedBits(1:packetLengthBits);
result.channelEstimate = channelEstimate;
result.noiseVariance = noiseVariance;
result.positiveBinSnr = abs(channelEstimate).^2 * settings.symbolEnergy ./ noiseVariance;
result.phaseParameters = phaseParameters;
result.equalizedSymbols = equalized;
result.preambleStart = preambleStart;
result.ofdmStart = ofdmStart;
result.preambleScore = score;
result.lastSample = lastSample;
end
