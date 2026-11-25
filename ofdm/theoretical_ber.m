function bitErrorRate = theoretical_ber(symbolSnr, bitsPerSymbol)
qFunction = @(value) 0.5 * erfc(value / sqrt(2));
if bitsPerSymbol == 1
    bitErrorRate = qFunction(sqrt(2 * symbolSnr));
elseif bitsPerSymbol == 2
    bitErrorRate = qFunction(sqrt(symbolSnr));
elseif bitsPerSymbol == 4
    axisSnr = sqrt(symbolSnr / 5);
    bitErrorRate = 0.75 * qFunction(axisSnr) + 0.5 * qFunction(3 * axisSnr) ...
        - 0.25 * qFunction(5 * axisSnr);
else
    error('Unsupported modulation.');
end
end
