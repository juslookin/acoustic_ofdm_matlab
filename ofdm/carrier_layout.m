function [pilotPositions, dataPositions] = carrier_layout(numberOfCarriers, pilotSpacing)
%CARRIER_LAYOUT Positions within the used-carrier vector, all column indices.
% Inputs: positive integer scalars. Outputs: pilot/data column index vectors.
pilotPositions = (1:pilotSpacing:numberOfCarriers).';
dataPositions = setdiff((1:numberOfCarriers).', pilotPositions);
end
