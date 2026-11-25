function result = decode_audio_frame(recording, payloadLength, settings)
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
numberOfDataSymbols = audio_data_symbols(packetLengthBits, settings);
numberOfOfdmSymbols = settings.trainingSymbols + numberOfDataSymbols;
lastSample = ofdmStart + numberOfOfdmSymbols * (settings.fftSize + settings.cyclicPrefixLength) - 1;
assert(lastSample <= numel(recording), 'Recording ends before the packet.');

receivedGrid = ofdm_demodulate(recording(ofdmStart:lastSample), settings);
knownSymbols = training_symbols(settings);
channelEstimate = mean(receivedGrid(:, 1:settings.trainingSymbols), 2) ./ knownSymbols;
rawNoiseVariance = abs(receivedGrid(:, 1) - receivedGrid(:, 2)).^2 / 2;
noiseVariance = max(movmean(rawNoiseVariance, settings.noiseSmoothingBins), settings.noiseVarianceFloor);

dataGrid = receivedGrid(:, settings.trainingSymbols+1:end);
[correctedGrid, phaseParameters] = correct_pilot_phase(dataGrid, channelEstimate, pilotPositions, settings);
safeEstimate = channelEstimate;
safeEstimate(abs(safeEstimate) < settings.equalizerFloor) = settings.equalizerFloor;
equalized = correctedGrid(dataPositions, :) ./ safeEstimate(dataPositions) / sqrt(settings.symbolEnergy);

positiveBinSnr = abs(channelEstimate).^2 * settings.symbolEnergy ./ noiseVariance;
fecCorrections = NaN;

if settings.useFec
    carrierSnr = repmat(positiveBinSnr(dataPositions), 1, size(equalized, 2));
    softBits = [real(equalized(:)).'; imag(equalized(:)).'] .* [carrierSnr(:).'; carrierSnr(:).'];
    softBits = softBits(:);
    deinterleaved = zeros(size(softBits));
    deinterleaved(fec_interleaver(numel(softBits), settings.fecInterleaverColumns)) = softBits;
    decodedBits = fec_decode(deinterleaved, packetLengthBits);

    codedLength = 2 * (packetLengthBits + 6);
    fecCorrections = nnz((deinterleaved(1:codedLength) < 0) ~= fec_encode(decodedBits));
else
    decodedBits = demap_symbols(equalized(:), 2);
end

[passed, bytes] = check_packet(decodedBits(1:packetLengthBits));
result.passed = passed;
result.payloadBytes = bytes;
result.decodedBits = decodedBits(1:packetLengthBits);
result.channelEstimate = channelEstimate;
result.noiseVariance = noiseVariance;
result.positiveBinSnr = positiveBinSnr;
result.fecCorrections = fecCorrections;
result.phaseParameters = phaseParameters;
result.equalizedSymbols = equalized;
result.preambleStart = preambleStart;
result.ofdmStart = ofdmStart;
result.preambleScore = score;
result.lastSample = lastSample;
end
