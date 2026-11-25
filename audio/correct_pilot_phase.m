function [correctedSymbols, phaseParameters] = correct_pilot_phase(receivedSymbols, channelEstimate, pilotPositions, settings)
correctedSymbols = receivedSymbols;
phaseParameters = zeros(2, size(receivedSymbols, 2));
pilotMagnitude = abs(channelEstimate(pilotPositions));
valid = pilotMagnitude > settings.phasePilotRelativeFloor * max(pilotMagnitude);
assert(nnz(valid) >= settings.phaseFitMinimumPilots, 'Too few reliable pilots.');

selectedPositions = pilotPositions(valid);
centredBins = settings.usedBins - mean(settings.usedBins);
designMatrix = [ones(nnz(valid), 1), centredBins(selectedPositions)];
weights = abs(channelEstimate(selectedPositions));
weightedDesign = designMatrix .* weights;

for symbolIndex = 1:size(receivedSymbols, 2)
    expectedPilots = channelEstimate(selectedPositions) * sqrt(settings.pilotEnergy);
    phaseDifference = unwrap(angle(receivedSymbols(selectedPositions, symbolIndex) ./ expectedPilots));
    parameters = weightedDesign \ (phaseDifference .* weights);
    fittedPhase = parameters(1) + parameters(2) * centredBins;
    correctedSymbols(:, symbolIndex) = receivedSymbols(:, symbolIndex) .* exp(-1i * fittedPhase);
    phaseParameters(:, symbolIndex) = parameters;
end
end
