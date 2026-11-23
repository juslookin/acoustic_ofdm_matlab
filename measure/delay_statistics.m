function statistics = delay_statistics(impulseResponse, sampleRate)
%DELAY_STATISTICS Energy-weighted delays relative to the supplied first tap.
% Inputs: real/complex FIR [L x 1], fs Hz. Output: seconds, Hz and normalized PDP.
power = abs(impulseResponse(:)).^2;
assert(sum(power) > 0, 'Zero impulse response.');
power = power / sum(power);
delays = (0:numel(power)-1).' / sampleRate;
meanDelay = sum(delays .* power);
statistics.rmsDelaySeconds = sqrt(sum((delays - meanDelay).^2 .* power));
statistics.energy95Seconds = delays(find(cumsum(power) >= 0.95, 1));
statistics.energy99Seconds = delays(find(cumsum(power) >= 0.99, 1));
statistics.coherenceBandwidthHz = 1 / max(5 * statistics.rmsDelaySeconds, eps);
statistics.powerDelayProfile = power;
end
