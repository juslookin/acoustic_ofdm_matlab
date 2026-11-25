function [pilotPositions, dataPositions] = carrier_layout(numberOfCarriers, pilotSpacing)
pilotPositions = (1:pilotSpacing:numberOfCarriers).';
dataPositions = setdiff((1:numberOfCarriers).', pilotPositions);
end
