function [correlation, normalizedCorrelation] = matched_filter(recording, reference)
%MATCHED_FILTER FFT implementation of valid sliding cross-correlation.
% Inputs: real/complex columns recording [T x 1], reference [L x 1], T>=L.
% Outputs: correlation and magnitude normalized correlation [T-L+1 x 1].
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
