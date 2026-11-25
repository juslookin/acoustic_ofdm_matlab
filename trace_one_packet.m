function trace = trace_one_packet()
settings = startup_project();
settings.useFec = true;

picture = load_picture('smiley', settings);
trace.bytes = [uint8([0; 1; 0; 64]); picture(1:64).'];
trace.packetBits = make_packet(trace.bytes);
trace.codedBits = fec_encode(trace.packetBits);
trace.symbols = modulate_bits(trace.codedBits(81:88));

[waveform, ~] = make_audio_frame(trace.bytes, settings);
received = [zeros(500, 1); conv(waveform, settings.demoChannel); zeros(2000, 1)];
trace.decoded = decode_audio_frame(received, numel(trace.bytes), settings);

fprintf('1. Packet bytes:  %s ...\n', mat2str(trace.bytes(1:8).'));
fprintf('2. With CRC32:    %d bits, last 32 are the checksum\n', numel(trace.packetBits));
fprintf('3. Coded bits:    %d bits (2 per data bit + tail)\n', numel(trace.codedBits));
fprintf('4. QPSK symbols:  %s ...\n', mat2str(round(trace.symbols(1:4).', 3)));
fprintf('5. Sound:         %.2f s for this packet\n', numel(waveform) / settings.sampleRate);
fprintf('6. Received:      CRC passed = %d, bytes match = %d\n', trace.decoded.passed, ...
    isequal(trace.decoded.payloadBytes, trace.bytes));
end
