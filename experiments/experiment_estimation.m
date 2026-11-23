function results = experiment_estimation(settings)
%EXPERIMENT_ESTIMATION LS/L-MMSE empirical MSE and analytical error covariance.
% Input: settings. Output: table; independent channels are statistical units.
rng(settings.seed + 2, 'twister');
[frequencyBasis, channelCovariance, noiseShape] = channel_statistics(settings);
channelResponse = draw_channels(frequencyBasis, settings.channelTapPowers, settings.estimationRealizations);
commonNoise = (randn(size(channelResponse)) + 1i * randn(size(channelResponse))) / sqrt(2);
bootstrapIndices = randi(settings.estimationRealizations, settings.estimationRealizations, settings.bootstrapReplicates);
rows = [];
figureHandle = figure('Visible', 'off');
hold on;
for spacing = settings.pilotSpacings
    [pilotPositions, dataPositions] = carrier_layout(numel(settings.usedBins), spacing);
    pilotSymbols = sqrt(settings.pilotEnergy) * ones(numel(pilotPositions), 1);
    mseLsCurve = zeros(size(settings.snrDb));
    mseMmseCurve = zeros(size(settings.snrDb));
    theoreticalCurve = zeros(size(settings.snrDb));
    for snrIndex = 1:numel(settings.snrDb)
        noiseVariance = settings.symbolEnergy * noiseShape / 10^(settings.snrDb(snrIndex) / 10);
        [lsWeights, mmseWeights, errorCovariance] = estimator_weights(channelCovariance, pilotPositions, diag(noiseVariance(pilotPositions)), pilotSymbols);
        observations = channelResponse(pilotPositions, :) + sqrt(noiseVariance(pilotPositions) / settings.pilotEnergy) .* commonNoise(pilotPositions, :);
        lsError = lsWeights * observations - channelResponse;
        mmseError = mmseWeights * observations - channelResponse;
        lsFrameMse = mean(abs(lsError(dataPositions, :)).^2, 1).';
        mmseFrameMse = mean(abs(mmseError(dataPositions, :)).^2, 1).';
        [lsMse, lsInterval] = cluster_ratio_interval(lsFrameMse, ones(size(lsFrameMse)), bootstrapIndices);
        [mmseMse, mmseInterval] = cluster_ratio_interval(mmseFrameMse, ones(size(mmseFrameMse)), bootstrapIndices);
        theoreticalMse = mean(real(diag(errorCovariance(dataPositions, dataPositions))));
        mseLsCurve(snrIndex) = lsMse;
        mseMmseCurve(snrIndex) = mmseMse;
        theoreticalCurve(snrIndex) = theoreticalMse;
        rows = [rows; spacing, settings.snrDb(snrIndex), lsMse, lsInterval, mmseMse, mmseInterval, theoreticalMse, settings.estimationRealizations]; %#ok<AGROW>
    end
    semilogy(settings.snrDb, mseLsCurve, 'o--', 'DisplayName', sprintf('LS spacing %d', spacing));
    semilogy(settings.snrDb, mseMmseCurve, 's-', 'DisplayName', sprintf('L-MMSE spacing %d', spacing));
    semilogy(settings.snrDb, theoreticalCurve, ':', 'HandleVisibility', 'off');
end
set(gca, 'YScale', 'log');
grid on;
xlabel('Average E_s/N_0 (dB)');
ylabel('MSE on data carriers');
title('E4: coloured-noise estimation; dotted curves are covariance theory');
legend('Location', 'southwest');
save_figure(figureHandle, 'E4_estimation', settings);
results = array2table(rows, 'VariableNames', {'PilotSpacing', 'SnrDb', 'LsMse', 'LsLower95', 'LsUpper95', 'LmmseMse', 'LmmseLower95', 'LmmseUpper95', 'TheoryMse', 'IndependentChannels'});
writetable(results, fullfile(settings.paths.results, 'estimation.csv'));
save(fullfile(settings.paths.results, 'estimation.mat'), 'results', 'settings');
end
