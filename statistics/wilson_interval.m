function interval = wilson_interval(successes, trials, confidenceZ)
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
