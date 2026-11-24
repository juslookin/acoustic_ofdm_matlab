function summary = summarize_audio_result(result, recording, settings)
%SUMMARIZE_AUDIO_RESULT Level, SNR, EVM and delay-profile statistics of a run.
% Inputs: decode_audio_transmission result, real recording [T x 1], settings.
% Output: structure used for printed advice and the diagnostics figure.
% SNR comes from the two training symbols (noise only; residual ISI from late
% reverberation is NOT included). EVM is decision-directed on QPSK data.
isDecoded = cellfun(@(entry) isstruct(entry) && isfield(entry, 'channelEstimate'), result.diagnostics);
decoded = result.diagnostics(isDecoded);
numberOfCarriers = numel(settings.usedBins);
[~, dataPositions] = carrier_layout(numberOfCarriers, settings.pilotSpacing);
summary.packetsSent = numel(result.passed);
summary.packetsSynchronised = numel(decoded);
summary.packetsPassed = nnz(result.passed);
summary.peakLevel = max(abs(recording));
summary.clippedSamples = nnz(abs(recording) >= settings.speakerClipLevel);
summary.frequenciesHz = settings.usedBins * settings.sampleRate / settings.fftSize;
summary.ber = result.ber;
if isempty(decoded)
    summary.binSnrDb = nan(numberOfCarriers, 1);
    summary.binSnrDbLow = summary.binSnrDb;
    summary.binSnrDbHigh = summary.binSnrDb;
    summary.medianSnrDb = NaN;
    summary.weakCarrierFraction = NaN;
    summary.packetMedianSnrDb = zeros(0, 1);
    summary.packetPassed = false(0, 1);
    summary.preambleScores = zeros(0, 1);
    summary.evmDb = NaN;
    summary.constellation = complex(zeros(0, 1));
    summary.delayMs = zeros(0, 1);
    summary.delayProfileDb = zeros(0, 1);
    summary.energyOutsideCpDb = NaN;
    summary.latencySeconds = NaN;
    return;
end
snrMatrix = cell2mat(cellfun(@(entry) entry.positiveBinSnr, decoded(:).', 'UniformOutput', false));
summary.binSnrDb = 10 * log10(median(snrMatrix, 2));
summary.binSnrDbLow = 10 * log10(row_quantile(snrMatrix, 0.1));
summary.binSnrDbHigh = 10 * log10(row_quantile(snrMatrix, 0.9));
summary.medianSnrDb = median(summary.binSnrDb(dataPositions));
% Uncoded QPSK needs about 9.8 dB for BER 1e-3 on a carrier.
summary.weakCarrierFraction = mean(summary.binSnrDb(dataPositions) < 10);
summary.packetMedianSnrDb = 10 * log10(median(snrMatrix(dataPositions, :), 1)).';
summary.packetPassed = cellfun(@(entry) entry.passed, decoded(:));
summary.preambleScores = cellfun(@(entry) entry.preambleScore, decoded(:));
symbols = cell2mat(cellfun(@(entry) entry.equalizedSymbols(:), decoded(:), 'UniformOutput', false));
decisions = (sign(real(symbols)) + 1i * sign(imag(symbols))) / sqrt(2);
summary.evmDb = 10 * log10(mean(abs(symbols - decisions).^2));
summary.constellation = symbols(round(linspace(1, numel(symbols), min(numel(symbols), 20000))));
% Delay profile of the median-SNR packet: Hann-tapered 2-8 kHz band, so the
% resolution is about 0.3 ms and delays beyond N/fs = 21.3 ms alias.
[~, order] = sort(summary.packetMedianSnrDb);
representative = decoded{order(ceil(numel(order) / 2))};
taper = 0.5 - 0.5 * cos(2 * pi * (1:numberOfCarriers).' / (numberOfCarriers + 1));
grid = zeros(settings.fftSize, 1);
grid(settings.usedBins + 1) = representative.channelEstimate .* taper;
profile = abs(ifft(grid)).^2;
summary.delayMs = (0:settings.fftSize-1).' / settings.sampleRate * 1000;
summary.delayProfileDb = 10 * log10(max(profile / max(profile), 1e-12));
% The FFT window starts timingBackoffSamples before the strongest path, so
% ISI-free delays are indices 1..CP; anything else (late or wrapped) leaks.
summary.energyOutsideCpDb = 10 * log10(max(sum(profile(settings.cyclicPrefixLength+1:end)), realmin) / sum(profile));
summary.latencySeconds = (decoded{1}.preambleStart - 1) / settings.sampleRate;
end

function values = row_quantile(matrix, probability)
%ROW_QUANTILE Nearest-rank quantile of each row without toolboxes.
sorted = sort(matrix, 2);
values = sorted(:, 1 + round(probability * (size(sorted, 2) - 1)));
end
