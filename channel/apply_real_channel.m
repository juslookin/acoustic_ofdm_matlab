function recording = apply_real_channel(waveform, impulseResponse, noiseRecording, noiseScale)
assert(isreal(waveform) && isreal(impulseResponse) && isreal(noiseRecording), ...
    'Acoustic channel and waveforms must be real.');
recording = conv(waveform(:), impulseResponse(:));
assert(numel(noiseRecording) >= numel(recording), 'Noise recording too short; do not repeat it silently.');
recording = recording + noiseScale * noiseRecording(1:numel(recording));
end
