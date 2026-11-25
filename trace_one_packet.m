function trace = trace_one_packet()
settings = config();
settings.useFec = true;

column = pictures.load('smiley', settings);
column = column(:, 1);
trace.bytes = [uint8([0; 1; 0; 64]); column];
trace.bits = packets.make(trace.bytes);
trace.coded = fec.encode(trace.bits);
trace.symbols = ofdm.qpsk(trace.coded(81:88));

[waveform, manifest] = transmitter(column, settings);
recording = [zeros(500, 1); conv(waveform, settings.demoChannel)];
result = receiver(recording, manifest, settings);
trace.received = result.packets{1};

fprintf('1. Packet bytes:  %s ...\n', mat2str(trace.bytes(1:8).'));
fprintf('2. With CRC32:    %d bits, last 32 are the checksum\n', numel(trace.bits));
fprintf('3. Coded bits:    %d bits (2 per data bit + tail)\n', numel(trace.coded));
fprintf('4. QPSK symbols:  %s ...\n', mat2str(round(trace.symbols(1:4).', 3)));
fprintf('5. Sound:         %.2f s for this packet\n', manifest.frameLength / settings.sampleRate);
fprintf('6. Received:      CRC passed = %d, bytes match = %d\n', trace.received.passed, ...
    isequal(trace.received.payload, trace.bytes));
end
