function impulseResponse = synthetic_room(rt60Seconds, directToReverberantDb, sampleRate, randomStream)
if rt60Seconds <= 0 || isinf(directToReverberantDb)
    impulseResponse = 1;
    return;
end

tailStart = round(0.001 * sampleRate);
tailLength = round(rt60Seconds * sampleRate);
time = (0:tailLength-1).' / sampleRate;
tail = randn(randomStream, tailLength, 1) .* exp(-3 * log(10) * time / rt60Seconds);
tail = tail * sqrt(10^(-directToReverberantDb / 10) / sum(tail.^2));
impulseResponse = [1; zeros(tailStart - 1, 1); tail];
end
