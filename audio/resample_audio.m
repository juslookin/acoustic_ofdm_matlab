function output = resample_audio(input, inputRate, outputRate)
input = input(:);
inputLength = numel(input);
outputLength = round(inputLength * outputRate / inputRate);

if outputLength == inputLength
    output = input;
    return;
end

spectrum = fft(input);
kept = floor((min(inputLength, outputLength) - 1) / 2);
outputSpectrum = zeros(outputLength, 1);
outputSpectrum(1:kept+1) = spectrum(1:kept+1);
outputSpectrum(end-kept+1:end) = spectrum(end-kept+1:end);
output = real(ifft(outputSpectrum)) * (outputLength / inputLength);
end
