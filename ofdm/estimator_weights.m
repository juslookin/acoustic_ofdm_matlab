function [lsWeights, lmmseWeights, estimationErrorCovariance] = estimator_weights(channelCovariance, pilotPositions, pilotNoiseCovariance, pilotSymbols)
%ESTIMATOR_WEIGHTS LS interpolation and linear minimum mean-square estimation.
% Inputs: channelCovariance [K x K], pilotPositions [P x 1], received pilot
% noise covariance [P x P], known pilotSymbols [P x 1]. Outputs: weights
% [K x P] acting on Y_p./X_p and L-MMSE error covariance [K x K].
numberOfCarriers = size(channelCovariance, 1);
numberOfPilots = numel(pilotPositions);
lsWeights = interp1(pilotPositions, eye(numberOfPilots), (1:numberOfCarriers).', 'linear', 'extrap');
inversePilots = diag(1 ./ pilotSymbols(:));
lsNoiseCovariance = inversePilots * pilotNoiseCovariance * inversePilots';
observationCovariance = channelCovariance(pilotPositions, pilotPositions) + lsNoiseCovariance;
% Solve a linear system instead of forming a matrix inverse.
lmmseWeights = (observationCovariance \ channelCovariance(pilotPositions, :))';
estimationErrorCovariance = channelCovariance - lmmseWeights * channelCovariance(pilotPositions, :);
estimationErrorCovariance = (estimationErrorCovariance + estimationErrorCovariance') / 2;
end
