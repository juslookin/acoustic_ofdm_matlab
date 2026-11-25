function [correlation, normalizedCorrelation] = matched_filter(recording, reference)
recording = recording(:);
reference = reference(:);
assert(numel(recording) >= numel(reference), 'Recording is shorter than reference.');
fftLength = 2^nextpow2(numel(recording) + numel(reference) - 1);
fullCorrelation = ifft(fft(recording, fftLength) .* fft(conj(flipud(reference)), fftLength));
correlation = fullCorrelation(numel(reference):numel(recording));

cumulativeEnergy = [0; cumsum(abs(recording).^2)];
windowEnergy = cumulativeEnergy(numel(reference)+1:end) - cumulativeEnergy(1:end-numel(reference));
normalizedCorrelation = abs(correlation) ./ sqrt(max(windowEnergy * sum(abs(reference).^2), eps));
end
