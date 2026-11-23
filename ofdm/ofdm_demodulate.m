function carrierSymbols = ofdm_demodulate(waveform, settings)
%OFDM_DEMODULATE Remove CP then unitary FFT; transmitter timing is required.
% Input: waveform [(N+CP)*ofdmSymbols x 1]. Output: [usedCarriers x ofdmSymbols].
symbolLength = settings.fftSize + settings.cyclicPrefixLength;
assert(mod(numel(waveform), symbolLength) == 0, 'Incomplete OFDM block.');
withPrefix = reshape(waveform, symbolLength, []);
timeSymbols = withPrefix(settings.cyclicPrefixLength+1:end, :);
frequencyGrid = fft(timeSymbols, [], 1) / sqrt(settings.fftSize);
carrierSymbols = frequencyGrid(settings.usedBins + 1, :);
end
