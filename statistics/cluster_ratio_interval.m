function [estimate, interval] = cluster_ratio_interval(numerator, denominator, bootstrapIndices)
if sum(denominator) == 0
    estimate = NaN;
    interval = [NaN, NaN];
    return;
end

estimate = sum(numerator) / sum(denominator);
if all(numerator == 0)
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
