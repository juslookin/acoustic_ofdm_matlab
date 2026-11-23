function results = experiment_fading(settings)
%EXPERIMENT_FADING All fixed modulations with perfect and estimated fading CSI.
% Input: settings. Output: table of BER and independent-channel bootstrap CIs.
% CSI means channel state information. Rayleigh theory includes coloured N_k.
rng(settings.seed + 3, 'twister');
[frequencyBasis, channelCovariance, noiseShape] = channel_statistics(settings);
numberOfChannels = settings.estimationRealizations;
channelResponse = draw_channels(frequencyBasis, settings.channelTapPowers, numberOfChannels);
[pilotPositions, dataPositions] = carrier_layout(numel(settings.usedBins), settings.pilotSpacing);
numberOfDataCarriers = numel(dataPositions);
pilotNoise = (randn(numel(pilotPositions), numberOfChannels) + 1i * randn(numel(pilotPositions), numberOfChannels)) / sqrt(2);
dataNoise = (randn(numberOfDataCarriers, numberOfChannels) + 1i * randn(numberOfDataCarriers, numberOfChannels)) / sqrt(2);
bootstrapIndices = randi(numberOfChannels, numberOfChannels, settings.bootstrapReplicates);
rows = [];
figureHandle = figure('Visible', 'off');
hold on;
for modulationBits = [1, 2, 4]
    bits = rand(modulationBits * numberOfDataCarriers * numberOfChannels, 1) > 0.5;
    symbols = reshape(modulate_bits(bits, modulationBits), numberOfDataCarriers, numberOfChannels);
    bitColumns = reshape(bits, modulationBits * numberOfDataCarriers, numberOfChannels);
    perfectCurve = zeros(size(settings.snrDb));
    estimatedCurve = zeros(size(settings.snrDb));
    theoryCurve = zeros(size(settings.snrDb));
    for snrIndex = 1:numel(settings.snrDb)
        noiseVariance = noiseShape / 10^(settings.snrDb(snrIndex) / 10);
        [~, weights] = estimator_weights(channelCovariance, pilotPositions, diag(noiseVariance(pilotPositions)), sqrt(settings.pilotEnergy) * ones(numel(pilotPositions), 1));
        observations = channelResponse(pilotPositions, :) + sqrt(noiseVariance(pilotPositions) / settings.pilotEnergy) .* pilotNoise;
        channelEstimate = weights * observations;
        received = channelResponse(dataPositions, :) .* symbols + sqrt(noiseVariance(dataPositions)) .* dataNoise;
        perfectBits = reshape(demap_symbols(received(:) ./ reshape(channelResponse(dataPositions, :), [], 1), modulationBits), size(bitColumns));
        estimatedBits = reshape(demap_symbols(received(:) ./ reshape(channelEstimate(dataPositions, :), [], 1), modulationBits), size(bitColumns));
        errorsPerfect = sum(perfectBits ~= bitColumns, 1).';
        errorsEstimated = sum(estimatedBits ~= bitColumns, 1).';
        bitsPerFrame = repmat(size(bitColumns, 1), numberOfChannels, 1);
        [berPerfect, intervalPerfect] = cluster_ratio_interval(errorsPerfect, bitsPerFrame, bootstrapIndices);
        [berEstimated, intervalEstimated] = cluster_ratio_interval(errorsEstimated, bitsPerFrame, bootstrapIndices);
        averageSnr = 1 ./ noiseVariance(dataPositions);
        averageQ = @(coefficient) 0.5 * (1 - sqrt(coefficient * averageSnr ./ (2 + coefficient * averageSnr)));
        if modulationBits == 1
            rayleighTheory = mean(averageQ(2));
        elseif modulationBits == 2
            rayleighTheory = mean(averageQ(1));
        else
            rayleighTheory = mean(0.75 * averageQ(1 / 5) + 0.5 * averageQ(9 / 5) - 0.25 * averageQ(5));
        end
        perfectCurve(snrIndex) = berPerfect;
        estimatedCurve(snrIndex) = berEstimated;
        theoryCurve(snrIndex) = rayleighTheory;
        rows = [rows; modulationBits, settings.snrDb(snrIndex), berPerfect, intervalPerfect, berEstimated, intervalEstimated, rayleighTheory, sum(bitsPerFrame), numberOfChannels]; %#ok<AGROW>
    end
    semilogy(settings.snrDb, perfectCurve, 'o-', 'DisplayName', sprintf('%d bits perfect', modulationBits));
    semilogy(settings.snrDb, estimatedCurve, 's--', 'DisplayName', sprintf('%d bits estimated', modulationBits));
    semilogy(settings.snrDb, theoryCurve, ':', 'HandleVisibility', 'off');
end
set(gca, 'YScale', 'log');
grid on;
xlabel('Average E_s/N_0 (dB)');
ylabel('BER');
title('E3b: quasi-static Rayleigh fading; dotted = perfect-CSI theory');
legend('Location', 'southwest');
save_figure(figureHandle, 'E3b_fading', settings);
results = array2table(rows, 'VariableNames', {'BitsPerSymbol', 'SnrDb', 'PerfectBer', 'PerfectLower95', 'PerfectUpper95', 'EstimatedBer', 'EstimatedLower95', 'EstimatedUpper95', 'RayleighTheory', 'Bits', 'IndependentChannels'});
writetable(results, fullfile(settings.paths.results, 'fading.csv'));
save(fullfile(settings.paths.results, 'fading.mat'), 'results', 'settings');
end
