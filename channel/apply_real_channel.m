function recording = apply_real_channel(waveform, impulseResponse, noiseRecording, noiseScale)
%APPLY_REAL_CHANNEL Convolve real acoustic samples and add a recorded noise clip.
% Inputs: waveform [T x 1], real FIR [L x 1], real noise [>=T+L-1 x 1],
% noiseScale scalar amplitude. Output: real recording [T+L-1 x 1].
assert(isreal(waveform) && isreal(impulseResponse) && isreal(noiseRecording), ...
    'Acoustic channel and waveforms must be real.');
recording = conv(waveform(:), impulseResponse(:));
assert(numel(noiseRecording) >= numel(recording), 'Noise recording too short; do not repeat it silently.');
recording = recording + noiseScale * noiseRecording(1:numel(recording));
end
