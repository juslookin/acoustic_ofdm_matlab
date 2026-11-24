function output = fft_convolve(signal, impulseResponse)
%FFT_CONVOLVE Linear convolution via zero-padded FFTs (fast for long room FIRs).
% Inputs: real columns signal [T x 1], impulseResponse [L x 1].
% Output: real column [T+L-1 x 1], equal to conv(signal, impulseResponse).
outputLength = numel(signal) + numel(impulseResponse) - 1;
fftLength = 2^nextpow2(outputLength);
output = real(ifft(fft(signal(:), fftLength) .* fft(impulseResponse(:), fftLength)));
output = output(1:outputLength);
end
