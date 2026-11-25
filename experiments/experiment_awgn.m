function results = experiment_awgn(settings)
rng(settings.seed + 1, 'twister');
rows = [];
figureHandle = figure('Visible', 'off');

hold on;
for modulationBits = [1, 2, 4]
    numberOfBits = modulationBits * floor(settings.awgnBits / modulationBits);
    bits = rand(numberOfBits, 1) > 0.5;
    transmitted = modulate_bits(bits, modulationBits);
    commonNoise = (randn(size(transmitted)) + 1i * randn(size(transmitted))) / sqrt(2);

    berCurve = zeros(size(settings.awgnSnrDb));
    for snrIndex = 1:numel(settings.awgnSnrDb)
        snrDb = settings.awgnSnrDb(snrIndex);
        symbolSnr = 10^(snrDb / 10);
        decoded = demap_symbols(transmitted + commonNoise / sqrt(symbolSnr), modulationBits);
        errors = nnz(bits ~= decoded);
        [~, interval] = symbol_ber_interval(bits ~= decoded, modulationBits, settings.confidenceZ);
        theory = theoretical_ber(symbolSnr, modulationBits);
        berCurve(snrIndex) = errors / numberOfBits;
        rows = [rows; modulationBits, snrDb, errors, numberOfBits, berCurve(snrIndex), interval, theory]; %#ok<AGROW>
    end

    semilogy(settings.awgnSnrDb, max(berCurve, 0.5 / numberOfBits), 'o-', 'DisplayName', sprintf('%d bits/symbol MC', modulationBits));
    semilogy(settings.awgnSnrDb, theoretical_ber(10.^(settings.awgnSnrDb / 10), modulationBits), '--', 'DisplayName', sprintf('%d bits/symbol theory', modulationBits));
end
set(gca, 'YScale', 'log');
grid on;
xlabel('E_s/N_0 (dB), unit-energy symbols');
ylabel('Bit error rate');
title('E3a: AWGN check; zero-error points shown at 0.5 / bit count');
legend('Location', 'southwest');
save_figure(figureHandle, 'E3a_awgn', settings);
results = array2table(rows, 'VariableNames', {'BitsPerSymbol', 'SnrDb', 'Errors', 'Bits', 'Ber', 'Lower95', 'Upper95', 'Theory'});
writetable(results, fullfile(settings.paths.results, 'awgn.csv'));
save(fullfile(settings.paths.results, 'awgn.mat'), 'results', 'settings');
end
