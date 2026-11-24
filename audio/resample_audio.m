function output = resample_audio(input, inputRate, outputRate)
%RESAMPLE_AUDIO Band-limited FFT resampling with base MATLAB only.
% Inputs: real column [T x 1], rates in Hz (any ratio, e.g. 44100 -> 48000 or
% a 20 ppm clock offset). Output: real column [round(T*outputRate/inputRate) x 1].
% The clip is treated as periodic, so it should start and end with silence.
input = input(:);
inputLength = numel(input);
outputLength = round(inputLength * outputRate / inputRate);
if outputLength == inputLength
    output = input;
    return;
end
spectrum = fft(input);
% Keep positive/negative bins common to both lengths; drop any Nyquist bin.
kept = floor((min(inputLength, outputLength) - 1) / 2);
outputSpectrum = zeros(outputLength, 1);
outputSpectrum(1:kept+1) = spectrum(1:kept+1);
outputSpectrum(end-kept+1:end) = spectrum(end-kept+1:end);
% ifft divides by the new length; rescale so amplitudes are preserved.
output = real(ifft(outputSpectrum)) * (outputLength / inputLength);
end
