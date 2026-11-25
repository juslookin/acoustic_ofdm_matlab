function waveform = make_chirp(duration, startHz, endHz, sampleRate, exponentialSweep)
numberOfSamples = round(duration * sampleRate);
time = (0:numberOfSamples-1).' / sampleRate;

if exponentialSweep
    rate = log(endHz / startHz) / duration;
    phase = 2 * pi * startHz * (exp(rate * time) - 1) / rate;
else
    phase = 2 * pi * (startHz * time + (endHz - startHz) * time.^2 / (2 * duration));
end

window = 0.5 - 0.5 * cos(2 * pi * (0:numberOfSamples-1).' / (numberOfSamples - 1));
waveform = sin(phase) .* window;
end
