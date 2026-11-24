function settings = config()
%CONFIG Central, reproducible settings for simulation and acoustic experiments.
% Input: none. Output: scalar structure; vectors are columns, times in seconds.
% All tunable engineering and Monte Carlo settings belong in this file.

settings.projectRoot = fileparts(mfilename('fullpath'));
settings.seed = 3362026;
settings.sampleRate = 48000;
settings.fftSize = 1024;
settings.cyclicPrefixLength = 256;
settings.usedBins = (43:170).'; % Zero-based positive FFT bin numbers.
settings.pilotSpacing = 4;
settings.pilotEnergy = 1;
settings.symbolEnergy = 1;
settings.chunkSize = 8;
settings.targetBer = 1e-3;
settings.modulationBits = [0, 1, 2, 4]; % 0 = off; then BPSK, QPSK, 16-QAM.
settings.packetPayloadBytes = 64;
settings.crcBits = 32;
% Optional forward error correction for the audio link (run_speaker_demo
% 'fec' flag): rate-1/2 K=7 convolutional code, block interleaver, soft
% Viterbi. Off by default so the uncoded results stay reproducible.
settings.useFec = false;
settings.fecInterleaverColumns = 16;
settings.imageSize = [64, 64];
settings.dataSymbolsPerFrame = 12;
settings.trainingSymbols = 2;

% Synthetic proper-complex Gaussian taps, not a real loudspeaker FIR.
settings.channelDelays = [0; 2; 5; 9; 15; 24; 38; 56];
settings.channelDecaySamples = 18;
settings.channelTapPowers = exp(-settings.channelDelays / settings.channelDecaySamples);
settings.channelTapPowers = settings.channelTapPowers / sum(settings.channelTapPowers);
settings.noiseColourStrength = 2;
settings.noiseColourFloor = 0.25;
settings.snrDb = [0, 5, 10, 15, 20, 25, 30];
settings.pilotSpacings = [2, 4, 8];
settings.adaptivePilotSpacings = [4, 8];
settings.estimationRealizations = 4000;
settings.adaptiveRealizations = 2400;
settings.awgnBits = 1200000;
settings.awgnSnrDb = [0, 3, 6, 9, 12];
settings.effectiveSnrErrorVariances = [0.01, 0.05, 0.2];
settings.effectiveSnrNoiseDb = [10, 20, 30];
settings.effectiveSnrSymbols = 300000;
settings.bootstrapReplicates = 600;
settings.confidenceZ = 1.95996398454005;

% Audio uses one global gain per frame. Training estimates include this gain.
settings.audioPeak = 0.5;
settings.preambleDuration = 0.05;
settings.preambleStartHz = 1000;
settings.preambleEndHz = 9000;
settings.preambleGuardSeconds = 0.03;
settings.audioLeadingSilence = 0.15;
settings.audioTrailingSilence = 0.30;
settings.interPacketSilence = 0.03;
settings.recordLeadSeconds = 0.25;
settings.recordTailSeconds = 0.5;
settings.audioInputDevice = -1;
settings.audioOutputDevice = -1;
settings.audioBits = 16;
settings.syncThreshold = 0.12;
settings.syncRelativeThreshold = 0.65;
settings.syncSearchRadius = settings.cyclicPrefixLength;
settings.equalizerFloor = 1e-12;
settings.noiseSmoothingBins = 9;
settings.noiseVarianceFloor = 1e-10;
settings.phaseFitMinimumPilots = 4;
settings.phasePilotRelativeFloor = 0.1;
settings.demoSnrDb = 32;
settings.demoChannel = [1; zeros(23, 1); 0.25; zeros(35, 1); -0.12];
settings.demoDelaySamples = 137;
settings.demoNoiseCoefficient = 0.7;
% Start the FFT window this many samples inside the CP, before the strongest
% arrival. Weaker early paths and timing jitter then stay inside the CP; the
% resulting linear phase is part of the training channel estimate.
settings.timingBackoffSamples = 32;

% Over-the-air speaker demo (run_speaker_demo). Rooms are SYNTHETIC stress
% models (direct path + exponential diffuse tail), not measured rooms.
settings.speakerCheckPackets = 3;
settings.speakerQuietPeak = 0.05;
settings.speakerClipLevel = 0.99;
settings.speakerGoodSnrDb = 15;
settings.stressSnrDb = [10, 15, 20, 25, 30, 40];
settings.stressClockPpm = 20;
settings.stressRoomNames = {'Direct path only', 'Desk 0.3 m', 'Room 1 m', 'Room 2 m'};
settings.stressRoomRt60 = [0, 0.3, 0.4, 0.5];
settings.stressRoomDrrDb = [Inf, 12, 4, -2];

settings.noiseRecordingSeconds = 30;
settings.psdWindowLength = 4096;
settings.psdOverlapFraction = 0.5;
settings.sweepDuration = 2;
settings.sweepStartHz = 100;
settings.sweepEndHz = 18000;
settings.sweepTailSeconds = 0.4;
settings.sweepRegularization = 1e-6;
settings.impulseResponseSeconds = 0.08;
settings.variationProbeDuration = 0.12;
settings.variationRepetitions = 20;
settings.variationRequestedInterval = 0.75;
settings.variationTailSeconds = 0.20;
settings.variationRecordLeadSeconds = 0.05;
settings.variationRecordTailSeconds = 0.05;
settings.coherenceThreshold = 0.5;
settings.toneDuration = 0.5;
settings.toneFrequencies = [1000, 5000];
settings.paths.figures = fullfile(settings.projectRoot, 'figures');
settings.paths.results = fullfile(settings.projectRoot, 'results');
settings.paths.data = fullfile(settings.projectRoot, 'data');
end
