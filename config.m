function settings = config()

% modem
settings.projectRoot = fileparts(mfilename('fullpath'));
settings.seed = 3362026;
settings.sampleRate = 48000;
settings.fftSize = 1024;
settings.cyclicPrefixLength = 256;
settings.usedBins = (43:170).'; % zero-based
settings.pilotSpacing = 4;
settings.pilotEnergy = 1;
settings.symbolEnergy = 1;
settings.trainingSymbols = 2;

% packets
settings.imageSize = [64, 64];
settings.packetPayloadBytes = 64;
settings.crcBits = 32;
settings.targetBer = 1e-3;

% error correction
settings.useFec = false;
settings.fecInterleaverColumns = 16;

% audio link
settings.audioPeak = 0.5;
settings.audioBits = 16;
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

% receiver
settings.syncThreshold = 0.12;
settings.syncRelativeThreshold = 0.65;
settings.syncSearchRadius = settings.cyclicPrefixLength;
settings.timingBackoffSamples = 32;
settings.equalizerFloor = 1e-12;
settings.noiseSmoothingBins = 9;
settings.noiseVarianceFloor = 1e-10;
settings.phaseFitMinimumPilots = 4;
settings.phasePilotRelativeFloor = 0.1;
settings.demoChannel = [1; zeros(23, 1); 0.25; zeros(35, 1); -0.12];

% speaker demo
settings.speakerCheckPackets = 3;
settings.listenMarginSeconds = 25;
settings.speakerQuietPeak = 0.05;
settings.speakerClipLevel = 0.99;
settings.speakerGoodSnrDb = 15;

% folders
settings.paths.figures = fullfile(settings.projectRoot, 'figures');
settings.paths.results = fullfile(settings.projectRoot, 'results');
settings.paths.data = fullfile(settings.projectRoot, 'data');
settings.paths.images = fullfile(settings.projectRoot, 'images');
settings.paths.transmit = fullfile(settings.projectRoot, 'transmit');

folders = struct2cell(settings.paths);
for k = 1:numel(folders)
    if ~isfolder(folders{k})
        mkdir(folders{k});
    end
end
end
