function [correctedSymbols, phaseParameters] = correct_pilot_phase(receivedSymbols, channelEstimate, pilotPositions, settings)
%CORRECT_PILOT_PHASE Weighted common phase and frequency-slope tracking.
% Inputs: received [K x S], training Hhat [K x 1], pilot indices [P x 1].
% Outputs: corrected [K x S], fitted [2 x S] (radians, radians/bin).
% A timing displacement d gives phase -2*pi*k*d/N. This removes modest
% sampling-clock drift within a packet; it cannot remove drift-induced ICI.
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
