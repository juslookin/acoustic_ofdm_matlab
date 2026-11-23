function results = experiment_effective_snr(settings)
%EXPERIMENT_EFFECTIVE_SNR Conditional Gaussian estimation-error hypothesis test.
% Input: settings. Output: table comparing observed and predicted BER.
% Fix a representative Hhat=sqrt(1-Ce), draw independent E~CN(0,Ce).
% Constant-modulus BPSK/QPSK are exact in this scalar conditional experiment;
% QAM's E*X has symbol-dependent variance, so the formula is approximate.
rng(settings.seed + 5, 'twister');
rows = [];
for modulationBits = [1, 2, 4]
    bits = rand(settings.effectiveSnrSymbols * modulationBits, 1) > 0.5;
    symbols = modulate_bits(bits, modulationBits);
    commonError = (randn(size(symbols)) + 1i * randn(size(symbols))) / sqrt(2);
    commonNoise = (randn(size(symbols)) + 1i * randn(size(symbols))) / sqrt(2);
    for errorVariance = settings.effectiveSnrErrorVariances
        channelEstimate = sqrt(1 - errorVariance);
        for noiseDb = settings.effectiveSnrNoiseDb
            noiseVariance = 10^(-noiseDb / 10);
            received = (channelEstimate + sqrt(errorVariance) * commonError) .* symbols + sqrt(noiseVariance) * commonNoise;
            decodedBits = demap_symbols(received / channelEstimate, modulationBits);
            errors = nnz(decodedBits ~= bits);
            predictedSnr = abs(channelEstimate)^2 / (errorVariance + noiseVariance);
            predictedBer = theoretical_ber(predictedSnr, modulationBits);
            [~, interval] = symbol_ber_interval(decodedBits ~= bits, modulationBits, settings.confidenceZ);
            rows = [rows; modulationBits, errorVariance, noiseDb, predictedSnr, predictedBer, errors / numel(bits), interval, errors, numel(bits)]; %#ok<AGROW>
        end
    end
end
results = array2table(rows, 'VariableNames', {'BitsPerSymbol', 'ErrorVariance', 'NoiseDb', 'EffectiveSnr', 'PredictedBer', 'ObservedBer', 'Lower95', 'Upper95', 'Errors', 'Bits'});
writetable(results, fullfile(settings.paths.results, 'effective_snr.csv'));
save(fullfile(settings.paths.results, 'effective_snr.mat'), 'results', 'settings');
figureHandle = figure('Visible', 'off');
hold on;
for modulationBits = [1, 2, 4]
    selected = results.BitsPerSymbol == modulationBits;
    loglog(max(results.PredictedBer(selected), 1e-8), max(results.ObservedBer(selected), 1e-8), 'o', 'DisplayName', sprintf('%d bits/symbol', modulationBits));
end
loglog([1e-8, 1], [1e-8, 1], 'k:', 'DisplayName', 'exact agreement');
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on;
xlabel('Predicted BER from effective SNR');
ylabel('Observed conditional BER (zeros plotted at 10^{-8})');
legend('Location', 'northwest');
title('Effective-SNR hypothesis: QAM is a mixture, not Gaussian');
save_figure(figureHandle, 'E5_effective_snr', settings);
end
