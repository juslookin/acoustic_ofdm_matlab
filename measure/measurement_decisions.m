function decisions = measurement_decisions(statistics, settings)
decisions.recommendedPrefixSamples = ceil(statistics.energy99Seconds * settings.sampleRate);
decisions.currentPrefixSamples = settings.cyclicPrefixLength;
decisions.maximumPilotSpacingApprox = max(1, floor(statistics.coherenceBandwidthHz / (settings.sampleRate / settings.fftSize)));
decisions.currentPilotSpacing = settings.pilotSpacing;
decisions.currentBandHz = settings.usedBins([1, end]) * settings.sampleRate / settings.fftSize;
decisions.bandStatus = 'Provisional: choose using measured channel gain AND measured noise PSD.';
decisions.reprobeStatus = 'Requires repeated channel measurements; not inferred from delay spread.';
decisions.prefixCovers99Percent = settings.cyclicPrefixLength >= decisions.recommendedPrefixSamples;
end
