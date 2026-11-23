function interval = wilson_interval(successes, trials, confidenceZ)
%WILSON_INTERVAL Binomial interval, appropriate only for independent trials.
% Inputs: counts scalar, normal quantile. Output: [lower, upper] probabilities.
if trials == 0
    interval = [NaN, NaN];
    return;
end
proportion = successes / trials;
denominator = 1 + confidenceZ^2 / trials;
centre = (proportion + confidenceZ^2 / (2 * trials)) / denominator;
halfWidth = confidenceZ * sqrt(proportion * (1 - proportion) / trials ...
    + confidenceZ^2 / (4 * trials^2)) / denominator;
interval = [max(0, centre - halfWidth), min(1, centre + halfWidth)];
end
