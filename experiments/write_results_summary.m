function write_results_summary(results, settings, runtime)
reportPath = fullfile(settings.paths.results, 'RESULTS.md');
fileId = fopen(reportPath, 'w');
assert(fileId >= 0, 'Cannot write results summary.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '# Recorded software results\n\n');

fprintf(fileId, 'Run: %s. MATLAB %s. Seed %d. Elapsed %.1f s.\n\n', runtime.runTimestamp, runtime.matlabVersion, settings.seed, results.elapsedSeconds);
fprintf(fileId, 'All %d software tests passed. No speaker/microphone experiment was performed.\n\n', height(results.tests));
fprintf(fileId, '## AWGN validation\n\n');
inside = results.awgn.Theory >= results.awgn.Lower95 & results.awgn.Theory <= results.awgn.Upper95;
fprintf(fileId, '%d/%d exact-theory values fall inside available pointwise 95%% intervals (Wilson for BPSK/QPSK, independent-symbol CLT for QAM). Multiple comparisons can produce misses even for correct code.\n\n', nnz(inside), numel(inside));
fprintf(fileId, '## Channel estimation\n\n');
ratio = results.estimation.LmmseMse ./ results.estimation.TheoryMse;
fprintf(fileId, '%d independent channels per point. Empirical/theoretical L-MMSE MSE ratio ranges %.4f to %.4f.\n\n', settings.estimationRealizations, min(ratio), max(ratio));
fadingInside = results.fading.RayleighTheory >= results.fading.PerfectLower95 ...
    & results.fading.RayleighTheory <= results.fading.PerfectUpper95;
fprintf(fileId, 'Perfect-CSI Rayleigh theory lies within %d/%d pointwise channel-bootstrap BER intervals. Estimated-channel BER is reported separately; it is not expected to equal perfect-CSI theory.\n\n', nnz(fadingInside), numel(fadingInside));
fprintf(fileId, '## Adaptive packet results\n\n');
fprintf(fileId, 'Each point uses %d independent quasi-static channels, %d data slots plus one comb probe, %d-byte payloads plus CRC32.\n\n', settings.adaptiveRealizations, settings.dataSymbolsPerFrame, settings.packetPayloadBytes);
fprintf(fileId, '| Spacing | SNR dB | Method | BER [95%% channel bootstrap] | Compared bits | CRC success | Payload bits/slot [95%%] | Off fraction | Energy/budget |\n');
fprintf(fileId, '|---|---|---|---|---|---|---|---|---|\n');
for row = 1:height(results.adaptive)
    item = results.adaptive(row, :);
    fprintf(fileId, '| %d | %g | %s | %.4g [%.4g, %.4g] | %d | %.4f | %.3f [%.3f, %.3f] | %.3f | %.3f |\n', ...
        item.PilotSpacing, item.SnrDb, item.Method{1}, item.Ber, item.BerLower95, item.BerUpper95, item.ComparedBits, ...
        item.PacketSuccess, item.GoodputBitsPerSymbol, item.GoodputLower95, item.GoodputUpper95, item.OutageFraction, item.EnergyBudgetFraction);
end
aware = strcmp(results.adaptive.Method, 'aware');
naive = strcmp(results.adaptive.Method, 'naive');
fprintf(fileId, '\nAware has point BER above target at %d/%d points with transmitted packets; naive at %d/%d. These are observations, not proof of a universal guarantee.\n\n', ...
    nnz(results.adaptive.Ber(aware) > settings.targetBer), nnz(isfinite(results.adaptive.Ber(aware))), ...
    nnz(results.adaptive.Ber(naive) > settings.targetBer), nnz(isfinite(results.adaptive.Ber(naive))));
fprintf(fileId, 'Low-SNR adaptive points may have zero packets or fewer than one million compared bits; NaN in the estimate means no BER/CRC trials. NaN in an interval upper endpoint means zero observed events: bootstrap cannot provide an upper limit from this sample. Rare-event points are exploratory and do not establish BER-target compliance.\n\n');
fprintf(fileId, 'Paired aware-minus-naive goodput intervals are in `adaptive_paired_differences.csv`. `ObservedChunkViolationFraction` counts short empirical chunk samples above the target; it does not estimate how many latent chunk BERs truly exceed the target.\n\n');
exampleSpacing = settings.adaptivePilotSpacings(end);
exampleSnr = settings.snrDb(ceil(numel(settings.snrDb) / 2));
exampleRows = results.adaptive.PilotSpacing == exampleSpacing & results.adaptive.SnrDb == exampleSnr;
exampleNaive = results.adaptive(exampleRows & naive, :);
exampleAware = results.adaptive(exampleRows & aware, :);
fprintf(fileId, 'At spacing %d, %g dB: naive BER %.4g, CRC success %.3f, goodput %.2f bits/slot; aware BER %.4g, CRC success %.3f, goodput %.2f bits/slot. This is a measured reliability/rate trade-off. Weakest-carrier chunk loading already makes the naive policy conservative in this model.\n\n', ...
    exampleSpacing, exampleSnr, exampleNaive.Ber, exampleNaive.PacketSuccess, exampleNaive.GoodputBitsPerSymbol, ...
    exampleAware.Ber, exampleAware.PacketSuccess, exampleAware.GoodputBitsPerSymbol);
fprintf(fileId, '## Effective-SNR hypothesis\n\n');
qamRows = results.effectiveSnr.BitsPerSymbol == 4;
qam = results.effectiveSnr(qamRows, :);
qamMiss = qam.PredictedBer < qam.Lower95 | qam.PredictedBer > qam.Upper95;
fprintf(fileId, 'For scalar conditional 16-QAM trials, %d/%d predictions lie outside the pointwise 95%% intervals. See `effective_snr.csv`; this directly tests the Gaussian replacement of E*X.\n\n', nnz(qamMiss), height(qam));
fprintf(fileId, '## Real-waveform software demonstration\n\n');
fprintf(fileId, 'Synthetic real FIR, coloured AR noise, %d-sample latency: %d/%d CRC packets, BER %.5g, duration %.3f s, %.2f payload bits/s. This is not over-the-air evidence.\n\n', ...
    settings.demoDelaySamples, nnz(results.audio.passed), numel(results.audio.passed), results.audio.ber, results.audio.durationSeconds, results.audio.netPayloadBitsPerSecond);
fprintf(fileId, '## Scope and statistical limits\n\n');
fprintf(fileId, 'Synthetic PDP/noise are assumed, not measured. L-MMSE uses the correct Gaussian prior and known coloured covariance. Frequency-domain noise is exactly diagonal by construction; measured finite-window noise need not be. Methods share channel/noise/payload samples and equal Es/Ep carrier limits; off power is not reallocated.\n\n');
fprintf(fileId, 'Bootstrap units are independent channel frames. Wilson intervals are used for BPSK/QPSK independent AWGN/conditional bits; QAM uses independent-symbol CLT intervals. Trials sharing a fade are never treated as independent bits for BER uncertainty. Sparse/zero errors do not establish a strict 1e-3 BER guarantee.\n\n');
fprintf(fileId, 'Hardware I/O, measured room/noise, physical clock drift, distance trials and adaptive acoustic feedback remain untested or unimplemented. No live 90%% CRC claim is made.\n');
clear cleanup;
vivaPath = fullfile(settings.projectRoot, 'docs', 'VIVA_NOTES.md');
vivaText = fileread(vivaPath);
marker = '<!-- GENERATED RESULTS BELOW -->';
markerPosition = strfind(vivaText, marker);
if ~isempty(markerPosition)
    vivaText = vivaText(1:markerPosition(1)-1);
end
fileId = fopen(vivaPath, 'w');
assert(fileId >= 0);
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n%s\n\n%s', vivaText, marker, fileread(reportPath));
clear cleanup;
end
