function output = fft_convolve(signal, impulseResponse)
outputLength = numel(signal) + numel(impulseResponse) - 1;
fftLength = 2^nextpow2(outputLength);

output = real(ifft(fft(signal(:), fftLength, 1) .* fft(impulseResponse(:), fftLength, 1), [], 1));
output = output(1:outputLength);
end
