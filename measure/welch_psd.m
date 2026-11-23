function [frequencies, psd] = welch_psd(samples, sampleRate, windowLength, overlapFraction)
%WELCH_PSD Toolbox-free one-sided density for real stationary samples.
% Inputs: samples real [T x 1], sampleRate Hz, windowLength samples, overlap.
% Outputs: frequencies [N/2+1 x 1] Hz, PSD [N/2+1 x 1] full-scale^2/Hz.
assert(isreal(samples), 'One-sided routine expects real samples.');
windowLength = min(windowLength, numel(samples));
windowLength = 2 * floor(windowLength / 2);
assert(windowLength >= 4, 'Too few samples.');
window = 0.5 - 0.5 * cos(2 * pi * (0:windowLength-1).' / (windowLength - 1));
hop = max(1, round(windowLength * (1 - overlapFraction)));
numberOfSegments = floor((numel(samples) - windowLength) / hop) + 1;
psd = zeros(windowLength / 2 + 1, 1);
for segmentIndex = 1:numberOfSegments
    positions = (segmentIndex - 1) * hop + (1:windowLength);
    segment = samples(positions);
    segment = segment - mean(segment);
    spectrum = fft(segment .* window);
    density = abs(spectrum(1:windowLength/2+1)).^2 / (sampleRate * sum(window.^2));
    density(2:end-1) = 2 * density(2:end-1);
    psd = psd + density;
end
psd = psd / numberOfSegments;
frequencies = (0:windowLength/2).' * sampleRate / windowLength;
end
