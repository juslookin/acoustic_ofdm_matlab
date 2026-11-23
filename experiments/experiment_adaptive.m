function results = experiment_adaptive(settings)
%EXPERIMENT_ADAPTIVE Paired fixed-QPSK, naive and aware packet experiments.
% Input: settings. Output: summary table; raw per-channel counts saved to MAT.
% Every method shares H, pilot noise, payload bytes and data noise samples.
rng(settings.seed + 4, 'twister');
[frequencyBasis, channelCovariance, noiseShape] = channel_statistics(settings);
numberOfChannels = settings.adaptiveRealizations;
channelResponse = draw_channels(frequencyBasis, settings.channelTapPowers, numberOfChannels);
allPilotNoise = (randn(numel(settings.usedBins), numberOfChannels) + 1i * randn(numel(settings.usedBins), numberOfChannels)) / sqrt(2);
bootstrapIndices = randi(numberOfChannels, numberOfChannels, settings.bootstrapReplicates);
methods = {'fixed', 'naive', 'aware'};
metricNames = {'BitErrors', 'ComparedBits', 'PassedPackets', 'AttemptedPackets', ...
    'DeliveredPayloadBits', 'OutageFraction', 'PredictedBer', 'TransmittedDataEnergy', ...
    'ObservedViolatingChunks', 'ActiveChunks'};
rows = {};
rawMetrics = cell(numel(settings.adaptivePilotSpacings), numel(settings.snrDb));
pairedRows = [];
for spacingIndex = 1:numel(settings.adaptivePilotSpacings)
    spacing = settings.adaptivePilotSpacings(spacingIndex);
    [pilotPositions, dataPositions] = carrier_layout(numel(settings.usedBins), spacing);
    pilotSymbols = sqrt(settings.pilotEnergy) * ones(numel(pilotPositions), 1);
    % Restart this stream per SNR: noise and payloads are common across SNR too.
    dataRandomState = rng;
    for snrIndex = 1:numel(settings.snrDb)
        rng(dataRandomState);
        noiseVariance = noiseShape * settings.symbolEnergy / 10^(settings.snrDb(snrIndex) / 10);
        [~, weights, errorCovariance] = estimator_weights(channelCovariance, pilotPositions, diag(noiseVariance(pilotPositions)), pilotSymbols);
        errorVariance = max(real(diag(errorCovariance)), 0);
        observations = channelResponse(pilotPositions, :) + sqrt(noiseVariance(pilotPositions) / settings.pilotEnergy) .* allPilotNoise(pilotPositions, :);
        channelEstimate = weights * observations;
        frameMetrics = zeros(numberOfChannels, 10, numel(methods));
        maxPacketCount = floor(4 * numel(dataPositions) * settings.dataSymbolsPerFrame ...
            / (8 * settings.packetPayloadBytes + settings.crcBits));
        for channelIndex = 1:numberOfChannels
            commonNoise = (randn(numel(dataPositions), settings.dataSymbolsPerFrame) ...
                + 1i * randn(numel(dataPositions), settings.dataSymbolsPerFrame)) / sqrt(2);
            payloadPool = uint8(randi([0, 255], maxPacketCount * settings.packetPayloadBytes, 1));
            for methodIndex = 1:numel(methods)
                frameMetrics(channelIndex, :, methodIndex) = evaluate_adaptive_frame(channelResponse(:, channelIndex), ...
                    channelEstimate(:, channelIndex), errorVariance, noiseVariance, dataPositions, ...
                    commonNoise, payloadPool, settings, methods{methodIndex});
            end
        end
        rawMetrics{spacingIndex, snrIndex} = frameMetrics;
        for methodIndex = 1:numel(methods)
            counts = array2table(frameMetrics(:, :, methodIndex), 'VariableNames', metricNames);
            [ber, berInterval] = cluster_ratio_interval(counts.BitErrors, counts.ComparedBits, bootstrapIndices);
            [packetSuccess, packetInterval] = cluster_ratio_interval(counts.PassedPackets, counts.AttemptedPackets, bootstrapIndices);
            % One comb probe and S data symbols, same duration for all methods.
            transmittedSymbols = settings.dataSymbolsPerFrame + 1;
            [goodput, goodputInterval] = cluster_ratio_interval(counts.DeliveredPayloadBits, repmat(transmittedSymbols, numberOfChannels, 1), bootstrapIndices);
            totalResourceEnergy = counts.TransmittedDataEnergy + settings.pilotEnergy * numel(pilotPositions) * transmittedSymbols;
            budgetEnergy = settings.symbolEnergy * numel(dataPositions) * settings.dataSymbolsPerFrame ...
                + settings.pilotEnergy * numel(pilotPositions) * transmittedSymbols;
            observedChunkViolation = sum(counts.ObservedViolatingChunks) / max(sum(counts.ActiveChunks), 1);
            predictedMean = sum(counts.PredictedBer .* counts.ComparedBits, 'omitnan') / max(sum(counts.ComparedBits), 1);
            rows(end+1, :) = {spacing, settings.snrDb(snrIndex), methods{methodIndex}, ber, ...
                berInterval(1), berInterval(2), sum(counts.BitErrors), sum(counts.ComparedBits), ...
                packetSuccess, packetInterval(1), packetInterval(2), sum(counts.AttemptedPackets), ...
                goodput, goodputInterval(1), goodputInterval(2), mean(counts.OutageFraction), ...
                mean(totalResourceEnergy) / budgetEnergy, observedChunkViolation, numberOfChannels, ...
                nnz(counts.ComparedBits > 0), predictedMean}; %#ok<AGROW>
            fprintf('E5 spacing=%d SNR=%2d %-5s BER=%9.3g bits=%8d CRC=%6.3f goodput=%6.2f bits/symbol\n', ...
                spacing, settings.snrDb(snrIndex), methods{methodIndex}, ber, sum(counts.ComparedBits), packetSuccess, goodput);
        end
        % Paired bootstrap difference, preserving each common-channel triplet.
        payloadMetric = find(strcmp(metricNames, 'DeliveredPayloadBits'));
        awareMinusNaive = frameMetrics(:, payloadMetric, 3) - frameMetrics(:, payloadMetric, 2);
        [difference, differenceInterval] = cluster_ratio_interval(awareMinusNaive, repmat(settings.dataSymbolsPerFrame + 1, numberOfChannels, 1), bootstrapIndices);
        pairedRows = [pairedRows; spacing, settings.snrDb(snrIndex), difference, differenceInterval]; %#ok<AGROW>
    end
end
results = cell2table(rows, 'VariableNames', {'PilotSpacing', 'SnrDb', 'Method', 'Ber', 'BerLower95', 'BerUpper95', ...
    'Errors', 'ComparedBits', 'PacketSuccess', 'PacketLower95', 'PacketUpper95', 'Packets', 'GoodputBitsPerSymbol', ...
    'GoodputLower95', 'GoodputUpper95', 'OutageFraction', 'EnergyBudgetFraction', 'ObservedChunkViolationFraction', 'IndependentChannels', 'ChannelsWithPackets', 'MeanPredictedBer'});
pairedDifferences = array2table(pairedRows, 'VariableNames', {'PilotSpacing', 'SnrDb', 'AwareMinusNaiveGoodput', 'Lower95', 'Upper95'});
writetable(results, fullfile(settings.paths.results, 'adaptive.csv'));
writetable(pairedDifferences, fullfile(settings.paths.results, 'adaptive_paired_differences.csv'));
save(fullfile(settings.paths.results, 'adaptive.mat'), 'results', 'rawMetrics', 'metricNames', 'bootstrapIndices', 'pairedDifferences', 'settings');
figureHandle = figure('Visible', 'off', 'Position', [100, 100, 1200, 700]);
for spacingIndex = 1:numel(settings.adaptivePilotSpacings)
    spacing = settings.adaptivePilotSpacings(spacingIndex);
    subplot(2, 2, spacingIndex);
    hold on;
    for methodIndex = 1:numel(methods)
        selected = results.PilotSpacing == spacing & strcmp(results.Method, methods{methodIndex});
        semilogy(results.SnrDb(selected), results.Ber(selected), 'o-', 'DisplayName', methods{methodIndex});
    end
    yline(settings.targetBer, 'k:', 'target', 'DisplayName', 'BER target');
    set(gca, 'YScale', 'log');
    grid on;
    xlabel('Average E_s/N_0 (dB)');
    ylabel('Packet-bit BER');
    title(sprintf('Pilot spacing %d', spacing));
    legend('Location', 'southwest');
    subplot(2, 2, 2 + spacingIndex);
    hold on;
    for methodIndex = 1:numel(methods)
        selected = results.PilotSpacing == spacing & strcmp(results.Method, methods{methodIndex});
        errorbar(results.SnrDb(selected), results.GoodputBitsPerSymbol(selected), ...
            results.GoodputBitsPerSymbol(selected) - results.GoodputLower95(selected), ...
            results.GoodputUpper95(selected) - results.GoodputBitsPerSymbol(selected), 'o-', 'DisplayName', methods{methodIndex});
    end
    grid on;
    xlabel('Average E_s/N_0 (dB)');
    ylabel('CRC-delivered payload bits / OFDM slot');
end
sgtitle('E5: paired channels, equal per-carrier power limits; 95% channel bootstrap');
save_figure(figureHandle, 'E5_adaptive', settings);
end
