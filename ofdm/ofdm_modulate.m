function waveform = ofdm_modulate(carrierSymbols, settings, realWaveform)
frequencyGrid = zeros(settings.fftSize, size(carrierSymbols, 2));
frequencyGrid(settings.usedBins + 1, :) = carrierSymbols;

if realWaveform
    frequencyGrid(settings.fftSize - settings.usedBins + 1, :) = conj(carrierSymbols);
end

timeSymbols = sqrt(settings.fftSize) * ifft(frequencyGrid, [], 1);
if realWaveform
    assert(max(abs(imag(timeSymbols)), [], 'all') < 1e-12, 'Hermitian symmetry failed.');
    timeSymbols = real(timeSymbols);
end

withPrefix = [timeSymbols(end-settings.cyclicPrefixLength+1:end, :); timeSymbols];
waveform = withPrefix(:);
end
