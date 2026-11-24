function impulseResponse = synthetic_room(rt60Seconds, directToReverberantDb, sampleRate, randomStream)
%SYNTHETIC_ROOM Direct path plus an exponentially decaying diffuse tail.
% Inputs: RT60 in seconds (energy falls 60 dB), direct-to-reverberant energy
% ratio in dB, sample rate in Hz, RandStream. Output: real FIR [L x 1] whose
% first tap is the unit-amplitude direct path. A SYNTHETIC stress model
% (Gaussian noise times exp decay), not a measured or geometric room.
if rt60Seconds <= 0 || isinf(directToReverberantDb)
    impulseResponse = 1;
    return;
end
tailStart = round(0.001 * sampleRate); % first reflections after about 1 ms
tailLength = round(rt60Seconds * sampleRate);
time = (0:tailLength-1).' / sampleRate;
% Amplitude envelope exp(-3 ln(10) t / RT60) gives -60 dB energy at RT60.
tail = randn(randomStream, tailLength, 1) .* exp(-3 * log(10) * time / rt60Seconds);
tail = tail * sqrt(10^(-directToReverberantDb / 10) / sum(tail.^2));
impulseResponse = [1; zeros(tailStart - 1, 1); tail];
end
