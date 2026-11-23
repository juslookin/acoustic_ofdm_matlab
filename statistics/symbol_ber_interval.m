function [ber, interval] = symbol_ber_interval(errorMask, bitsPerSymbol, confidenceZ)
%SYMBOL_BER_INTERVAL BER uncertainty with each independent symbol as a cluster.
% Inputs: errorMask [bits x 1] logical, modulation order 1/2/4, normal quantile.
% Outputs: BER scalar, [lower,upper] 95% interval. For BPSK/QPSK, independent
% bit decisions permit Wilson. For QAM, bits sharing an axis are dependent;
% use the CLT across independent symbols. Zero-error upper limits are NaN.
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
