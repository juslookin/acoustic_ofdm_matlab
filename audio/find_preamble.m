function [startSample, peakCorrelation] = find_preamble(recording, settings)
%FIND_PREAMBLE Earliest strong chirp followed by a local peak refinement.
% Input: recording [T x 1], settings. Outputs: 1-based start and score.
preamble = make_chirp(settings.preambleDuration, settings.preambleStartHz, settings.preambleEndHz, settings.sampleRate, false);
[~, normalizedCorrelation] = matched_filter(recording, preamble);
threshold = max(settings.syncThreshold, settings.syncRelativeThreshold * max(normalizedCorrelation));
firstCrossing = find(normalizedCorrelation >= threshold, 1, 'first');
assert(~isempty(firstCrossing), 'No reliable chirp detected.');
searchEnd = min(numel(normalizedCorrelation), firstCrossing + settings.syncSearchRadius);
[peakCorrelation, localIndex] = max(normalizedCorrelation(firstCrossing:searchEnd));
startSample = firstCrossing + localIndex - 1;
end
