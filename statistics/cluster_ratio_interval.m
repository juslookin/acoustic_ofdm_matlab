function [estimate, interval] = cluster_ratio_interval(numerator, denominator, bootstrapIndices)
%CLUSTER_RATIO_INTERVAL Resample independent channel frames, keeping bits together.
% Inputs: numerator/denominator [frames x 1], indices [frames x replicates].
% Outputs: pooled ratio scalar and percentile 95% bootstrap interval [1 x 2].
if sum(denominator) == 0
    estimate = NaN;
    interval = [NaN, NaN];
    return;
end
estimate = sum(numerator) / sum(denominator);
if all(numerator == 0)
    % Resampling cannot invent an unobserved error/delivery. A [0,0] interval
    % would be misleading. NaN explicitly marks the unavailable upper limit.
    interval = [0, NaN];
    return;
end
bootstrapDenominator = sum(denominator(bootstrapIndices), 1);
bootstrapRatio = sum(numerator(bootstrapIndices), 1) ./ bootstrapDenominator;
bootstrapRatio = sort(bootstrapRatio(isfinite(bootstrapRatio)));
if isempty(bootstrapRatio)
    interval = [NaN, NaN];
else
    positions = 1 + ([0.025, 0.975] * (numel(bootstrapRatio) - 1));
    interval = interp1(1:numel(bootstrapRatio), bootstrapRatio, positions);
end
end
