function figureHandle = plot_speaker_diagnostics(result, summary, imageBytes, settings, label)
figureHandle = figure('Visible', 'off', 'Position', [100, 100, 1400, 800]);
layout = tiledlayout(figureHandle, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('%s | peak %.2f FS, %d clipped samples | BER %.2g (known bits)', ...
    label, summary.peakLevel, summary.clippedSamples, summary.ber), 'Interpreter', 'none');
axesHandle = nexttile(layout);
imagesc(axesHandle, imageBytes, [0, 255]);

colormap(axesHandle, gray);
axis(axesHandle, 'image', 'off');
title(axesHandle, 'Transmitted image');

axesHandle = nexttile(layout);
imagesc(axesHandle, result.receivedImage, [0, 255]);
colormap(axesHandle, gray);
axis(axesHandle, 'image', 'off');
title(axesHandle, sprintf('Received: %d/%d packets pass CRC (gray = lost)', ...
    summary.packetsPassed, summary.packetsSent));

axesHandle = nexttile(layout);
if isempty(summary.packetMedianSnrDb)
    show_message(axesHandle, 'No packet synchronised');
else
    attempt = (1:numel(summary.packetMedianSnrDb)).';
    hold(axesHandle, 'on');
    plot(axesHandle, attempt(summary.packetPassed), summary.packetMedianSnrDb(summary.packetPassed), ...
        'o', 'Color', [0.10, 0.55, 0.20], 'DisplayName', 'CRC pass');
    plot(axesHandle, attempt(~summary.packetPassed), summary.packetMedianSnrDb(~summary.packetPassed), ...
        'x', 'Color', [0.80, 0.10, 0.10], 'MarkerSize', 9, 'LineWidth', 1.5, 'DisplayName', 'CRC fail');

    grid(axesHandle, 'on');
    xlabel(axesHandle, 'Packet (decode order)');
    ylabel(axesHandle, 'Median data-carrier SNR (dB)');

    title(axesHandle, sprintf('%d/%d packets synchronised', summary.packetsSynchronised, summary.packetsSent));
    legend(axesHandle, 'Location', 'best');
end
axesHandle = nexttile(layout);
if all(isnan(summary.binSnrDb))
    show_message(axesHandle, 'No SNR estimate');
else
    frequenciesKhz = summary.frequenciesHz / 1000;
    hold(axesHandle, 'on');
    fill(axesHandle, [frequenciesKhz; flipud(frequenciesKhz)], [summary.binSnrDbLow; flipud(summary.binSnrDbHigh)], ...
        [0.30, 0.45, 0.80], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'DisplayName', '10-90% over packets');
    plot(axesHandle, frequenciesKhz, summary.binSnrDb, 'Color', [0.15, 0.30, 0.70], 'LineWidth', 1.2, 'DisplayName', 'median');
    yline(axesHandle, 10, 'k:', 'QPSK BER 1e-3 \approx 10 dB', 'HandleVisibility', 'off');
    grid(axesHandle, 'on');
    xlabel(axesHandle, 'Subcarrier frequency (kHz)');
    ylabel(axesHandle, 'Training-symbol SNR (dB)');
    title(axesHandle, sprintf('Per-carrier SNR: median %.1f dB, %.0f%% below 10 dB', ...
        summary.medianSnrDb, 100 * summary.weakCarrierFraction));
    legend(axesHandle, 'Location', 'best');
end
axesHandle = nexttile(layout);
if isempty(summary.constellation)
    show_message(axesHandle, 'No equalized symbols');
else
    plot(axesHandle, real(summary.constellation), imag(summary.constellation), '.', ...
        'MarkerSize', 3, 'Color', [0.30, 0.30, 0.30]);
    hold(axesHandle, 'on');
    plot(axesHandle, [1, 1, -1, -1] / sqrt(2), [1, -1, 1, -1] / sqrt(2), 'r+', 'MarkerSize', 14, 'LineWidth', 2);
    axis(axesHandle, 'equal');
    xlim(axesHandle, [-2, 2]);
    ylim(axesHandle, [-2, 2]);
    grid(axesHandle, 'on');
    xlabel(axesHandle, 'In-phase');
    ylabel(axesHandle, 'Quadrature');
    title(axesHandle, sprintf('Equalized QPSK data, EVM %.1f dB', summary.evmDb));
end
axesHandle = nexttile(layout);
if isempty(summary.delayMs)
    show_message(axesHandle, 'No channel estimate');
else
    plot(axesHandle, summary.delayMs, summary.delayProfileDb, 'Color', [0.15, 0.30, 0.70]);
    xline(axesHandle, settings.cyclicPrefixLength / settings.sampleRate * 1000, 'r--', 'CP end');
    ylim(axesHandle, [-50, 3]);
    xlim(axesHandle, [0, summary.delayMs(end)]);
    grid(axesHandle, 'on');
    xlabel(axesHandle, 'Delay from FFT window start (ms); aliases after 21.3 ms');
    ylabel(axesHandle, 'Relative power (dB)');
    title(axesHandle, sprintf('Channel delay profile: %.1f dB of energy outside CP', summary.energyOutsideCpDb));
end
end

function show_message(axesHandle, message)
axis(axesHandle, 'off');
text(axesHandle, 0.5, 0.5, message, 'HorizontalAlignment', 'center', 'FontSize', 12);
end
