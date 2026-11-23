function metrics = evaluate_adaptive_frame(channelResponse, channelEstimate, errorVariance, noiseVariance, dataPositions, commonNoise, payloadPool, settings, method)
%EVALUATE_ADAPTIVE_FRAME Send real CRC packets through one quasi-static fade.
% Inputs: H/Hhat/error/noise [K x 1], data indices [D x 1], unit CN noise
% [D x S], shared payload pool uint8 [bytes x 1], settings and method text.
% Output: row [errors,bits,passed,packets,goodPayloadBits,outageFraction,
% meanPredictedBER,usedDataEnergy,violatingChunks,activeChunks].
[loading, predictedBer] = select_loading(channelEstimate, errorVariance, noiseVariance, dataPositions, settings, method);
capacity = sum(loading) * settings.dataSymbolsPerFrame;
packetBits = settings.packetPayloadBytes * 8 + settings.crcBits;
numberOfPackets = floor(capacity / packetBits);
sharedPaddingBits = bytes_to_bits(payloadPool);
paddingIndices = mod((0:capacity-1).', numel(sharedPaddingBits)) + 1;
transmittedBits = sharedPaddingBits(paddingIndices);
for packetIndex = 1:numberOfPackets
    bytePositions = (packetIndex - 1) * settings.packetPayloadBytes + (1:settings.packetPayloadBytes);
    bitPositions = (packetIndex - 1) * packetBits + (1:packetBits);
    transmittedBits(bitPositions) = make_packet(payloadPool(bytePositions));
end
% Unused tail capacity carries shared random padding. Random padding preserves
% QAM's unit ensemble energy; all-zero QAM padding would have energy 1.8.
% Padding is excluded from packet BER and delivered payload throughput.
dataSymbols = sqrt(settings.symbolEnergy) * map_loaded_frame(transmittedBits, loading, settings.dataSymbolsPerFrame);
received = channelResponse(dataPositions) .* dataSymbols + sqrt(noiseVariance(dataPositions)) .* commonNoise;
safeEstimate = channelEstimate(dataPositions);
safeEstimate(abs(safeEstimate) < settings.equalizerFloor) = settings.equalizerFloor;
equalized = received ./ safeEstimate / sqrt(settings.symbolEnergy);
decodedBits = demap_loaded_frame(equalized, loading);
numberOfComparedBits = numberOfPackets * packetBits;
numberOfErrors = nnz(decodedBits(1:numberOfComparedBits) ~= transmittedBits(1:numberOfComparedBits));
passedPackets = 0;
for packetIndex = 1:numberOfPackets
    bitPositions = (packetIndex - 1) * packetBits + (1:packetBits);
    passedPackets = passedPackets + check_packet(decodedBits(bitPositions));
end
% Chunk diagnostics use ALL decision bits, including tail padding. A chunk
% count is not a confidence statement that its latent BER exceeds the target.
violatingChunks = 0;
activeChunks = 0;
nextBit = 1;
chunkErrors = zeros(ceil(numel(loading) / settings.chunkSize), 1);
chunkBits = zeros(size(chunkErrors));
for symbolIndex = 1:settings.dataSymbolsPerFrame
    for carrierIndex = 1:numel(loading)
        modulationBits = loading(carrierIndex);
        if modulationBits > 0
            positions = nextBit:nextBit + modulationBits - 1;
            chunkIndex = ceil(carrierIndex / settings.chunkSize);
            chunkErrors(chunkIndex) = chunkErrors(chunkIndex) + nnz(decodedBits(positions) ~= transmittedBits(positions));
            chunkBits(chunkIndex) = chunkBits(chunkIndex) + modulationBits;
            nextBit = nextBit + modulationBits;
        end
    end
end
for chunkIndex = 1:numel(chunkBits)
    if chunkBits(chunkIndex) > 0
        activeChunks = activeChunks + 1;
        violatingChunks = violatingChunks + (chunkErrors(chunkIndex) / chunkBits(chunkIndex) > settings.targetBer);
    end
end
activePrediction = predictedBer(isfinite(predictedBer));
activeLoading = loading(loading > 0);
if isempty(activePrediction)
    predictedAverage = NaN;
else
    predictedAverage = sum(activePrediction .* activeLoading) / sum(activeLoading);
end
metrics = [numberOfErrors, numberOfComparedBits, passedPackets, numberOfPackets, ...
    passedPackets * settings.packetPayloadBytes * 8, mean(loading == 0), ...
    predictedAverage, sum(abs(dataSymbols).^2, 'all'), violatingChunks, activeChunks];
end
