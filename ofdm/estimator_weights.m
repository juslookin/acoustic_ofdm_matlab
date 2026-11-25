function [lsWeights, lmmseWeights, estimationErrorCovariance] = estimator_weights(channelCovariance, pilotPositions, pilotNoiseCovariance, pilotSymbols)
numberOfCarriers = size(channelCovariance, 1);
numberOfPilots = numel(pilotPositions);

lsWeights = interp1(pilotPositions, eye(numberOfPilots), (1:numberOfCarriers).', 'linear', 'extrap');
inversePilots = diag(1 ./ pilotSymbols(:));
lsNoiseCovariance = inversePilots * pilotNoiseCovariance * inversePilots';
observationCovariance = channelCovariance(pilotPositions, pilotPositions) + lsNoiseCovariance;
lmmseWeights = (observationCovariance \ channelCovariance(pilotPositions, :))';
estimationErrorCovariance = channelCovariance - lmmseWeights * channelCovariance(pilotPositions, :);
estimationErrorCovariance = (estimationErrorCovariance + estimationErrorCovariance') / 2;
end
