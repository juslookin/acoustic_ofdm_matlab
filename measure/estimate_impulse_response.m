function [impulseResponse, statistics] = estimate_impulse_response(probe, recording, settings)
%ESTIMATE_IMPULSE_RESPONSE Regularized FFT least-squares sweep deconvolution.
% Inputs: probe [T x 1], recording [R x 1] real samples, settings.
% Outputs: real FIR [round(IRseconds*fs) x 1] and delay statistics.
% Delays are relative to strongest arrival. Latency is retained separately;
% weaker precursor paths may be omitted. Do not call this a Farina inverse.
fftLength = 2^nextpow2(numel(probe) + numel(recording) - 1);
probeSpectrum = fft(probe, fftLength);
recordingSpectrum = fft(recording, fftLength);
regularization = settings.sweepRegularization * max(abs(probeSpectrum).^2);
response = recordingSpectrum .* conj(probeSpectrum) ./ (abs(probeSpectrum).^2 + regularization);
fullImpulseResponse = real(ifft(response));
[~, strongestArrival] = max(abs(fullImpulseResponse(1:numel(recording))));
responseLength = round(settings.impulseResponseSeconds * settings.sampleRate);
impulseResponse = fullImpulseResponse(strongestArrival:strongestArrival + responseLength - 1);
statistics = delay_statistics(impulseResponse, settings.sampleRate);
statistics.strongestArrivalSeconds = (strongestArrival - 1) / settings.sampleRate;
statistics.regularization = regularization;
end
