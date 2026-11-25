function [bitsPerCarrier, predictedBer] = select_loading(channelEstimate, estimationErrorVariance, noiseVariance, dataPositions, settings, method)
if strcmp(method, 'aware')
    denominator = noiseVariance + settings.symbolEnergy * estimationErrorVariance;
else
    denominator = noiseVariance;
end

effectiveSnr = abs(channelEstimate).^2 * settings.symbolEnergy ./ denominator;
bitsPerCarrier = zeros(numel(dataPositions), 1);
predictedBer = nan(numel(dataPositions), 1);

if strcmp(method, 'fixed')
    bitsPerCarrier(:) = 2;
    predictedBer = theoretical_ber(effectiveSnr(dataPositions), 2);
    return;
end

assert(any(strcmp(method, {'naive', 'aware'})), 'Unknown loading method.');
for firstPosition = 1:settings.chunkSize:numel(dataPositions)
    chunkPositions = firstPosition:min(firstPosition + settings.chunkSize - 1, numel(dataPositions));
    weakestSnr = min(effectiveSnr(dataPositions(chunkPositions)));
    chosenBits = 0;

    for candidateBits = settings.modulationBits(2:end)
        if theoretical_ber(weakestSnr, candidateBits) <= settings.targetBer
            chosenBits = candidateBits;
        end
    end

    bitsPerCarrier(chunkPositions) = chosenBits;
    if chosenBits > 0
        predictedBer(chunkPositions) = theoretical_ber(effectiveSnr(dataPositions(chunkPositions)), chosenBits);
    end
end
end
