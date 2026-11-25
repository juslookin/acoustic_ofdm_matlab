function [ber, interval] = symbol_ber_interval(errorMask, bitsPerSymbol, confidenceZ)
ber = mean(errorMask);
if bitsPerSymbol <= 2
    interval = wilson_interval(nnz(errorMask), numel(errorMask), confidenceZ);
else
    symbolErrorFractions = mean(reshape(double(errorMask), bitsPerSymbol, []), 1);
    if nnz(errorMask) == 0
        interval = [0, NaN];
    else
        standardError = std(symbolErrorFractions, 0) / sqrt(numel(symbolErrorFractions));
        interval = [max(0, ber - confidenceZ * standardError), min(1, ber + confidenceZ * standardError)];
    end
end
end
