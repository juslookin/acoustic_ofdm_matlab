function trace = trace_one_packet()
settings = startup_project();
payloadBytes = uint8((0:settings.packetPayloadBytes-1).');
[waveform, transmitter] = make_audio_frame(payloadBytes, settings);
recording = [zeros(settings.demoDelaySamples, 1); conv(waveform, settings.demoChannel); ...
    zeros(round(settings.audioTrailingSilence * settings.sampleRate), 1)];
receiver = decode_audio_frame(recording, numel(payloadBytes), settings);
assert(receiver.passed && isequal(receiver.payloadBytes, payloadBytes), 'Trace packet failed.');

trace.payloadBytes = payloadBytes;
trace.packetBits = transmitter.packetBits;
trace.firstQpskSymbols = modulate_bits(transmitter.packetBits(1:16), 2);
trace.transmitWaveform = waveform;
trace.recording = recording;
trace.transmitter = transmitter;
trace.receiver = receiver;

save(fullfile(settings.paths.results, 'packet_trace.mat'), 'trace', 'settings');
fprintf('Trace: bytes [0 1 2 3 ...] -> %d CRC-protected bits -> %d QPSK data slots -> real waveform.\n', ...
    numel(trace.packetBits), transmitter.numberOfDataSymbols);
fprintf('Transmit gain %.5f, preamble sample %d, OFDM sample %d, CRC pass %d.\n', ...
    transmitter.transmitGain, receiver.preambleStart, receiver.ofdmStart, receiver.passed);

disp(table((1:8).', trace.firstQpskSymbols, 'VariableNames', {'SymbolIndex', 'FirstQpskSymbols'}));
end
