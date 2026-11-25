classdef ofdm
    methods (Static)

        function symbols = qpsk(bits)
            bits = double(reshape(bits, 2, []));
            symbols = ((1 - 2 * bits(1, :)) + 1i * (1 - 2 * bits(2, :))).' / sqrt(2);
        end

        function bits = qpskBits(symbols)
            bits = [real(symbols(:)).'; imag(symbols(:)).'] < 0;
            bits = bits(:);
        end

        function [pilots, data] = layout(settings)
            carriers = numel(settings.usedBins);
            pilots = (1:settings.pilotSpacing:carriers).';
            data = setdiff((1:carriers).', pilots);
        end

        function count = dataSymbols(packetBits, settings)
            [~, data] = ofdm.layout(settings);
            if settings.useFec
                packetBits = 2 * (packetBits + 6);
            end
            count = ceil(packetBits / (2 * numel(data)));
        end

        function waveform = modulate(grid, settings, realWaveform)
            spectrum = zeros(settings.fftSize, size(grid, 2));
            spectrum(settings.usedBins + 1, :) = grid;
            if realWaveform
                spectrum(settings.fftSize - settings.usedBins + 1, :) = conj(grid);
            end

            symbols = sqrt(settings.fftSize) * ifft(spectrum, [], 1);
            if realWaveform
                symbols = real(symbols);
            end

            withPrefix = [symbols(end-settings.cyclicPrefixLength+1:end, :); symbols];
            waveform = withPrefix(:);
        end

        function grid = demodulate(waveform, settings)
            blocks = reshape(waveform, settings.fftSize + settings.cyclicPrefixLength, []);
            spectrum = fft(blocks(settings.cyclicPrefixLength+1:end, :), [], 1) / sqrt(settings.fftSize);
            grid = spectrum(settings.usedBins + 1, :);
        end

        function symbols = training(settings)
            stream = RandStream('mt19937ar', 'Seed', settings.seed + 99);
            bits = rand(stream, 2 * numel(settings.usedBins), 1) > 0.5;
            symbols = sqrt(settings.pilotEnergy) * ofdm.qpsk(bits);
        end

        function sweep = chirp(settings)
            n = round(settings.preambleDuration * settings.sampleRate);
            t = (0:n-1).' / settings.sampleRate;
            f0 = settings.preambleStartHz;
            f1 = settings.preambleEndHz;

            phase = 2 * pi * (f0 * t + (f1 - f0) * t.^2 / (2 * settings.preambleDuration));
            window = 0.5 - 0.5 * cos(2 * pi * (0:n-1).' / (n - 1));
            sweep = sin(phase) .* window;
        end

        function [start, score] = findChirp(recording, settings)
            [~, match] = ofdm.matchedFilter(recording, ofdm.chirp(settings));
            threshold = max(settings.syncThreshold, settings.syncRelativeThreshold * max(match));
            first = find(match >= threshold, 1, 'first');
            assert(~isempty(first), 'No chirp found.');

            last = min(numel(match), first + settings.syncSearchRadius);
            [score, offset] = max(match(first:last));
            start = first + offset - 1;
        end

        function [correlation, match] = matchedFilter(recording, reference)
            recording = recording(:);
            reference = reference(:);
            n = 2^nextpow2(numel(recording) + numel(reference) - 1);

            full = ifft(fft(recording, n) .* fft(conj(flipud(reference)), n));
            correlation = full(numel(reference):numel(recording));

            energy = [0; cumsum(abs(recording).^2)];
            windowEnergy = energy(numel(reference)+1:end) - energy(1:end-numel(reference));
            match = abs(correlation) ./ sqrt(max(windowEnergy * sum(abs(reference).^2), eps));
        end

        function [corrected, fits] = fixPhase(received, channel, pilots, settings)
            strength = abs(channel(pilots));
            pilots = pilots(strength > settings.phasePilotRelativeFloor * max(strength));
            assert(numel(pilots) >= settings.phaseFitMinimumPilots, 'Too few pilots.');

            bins = settings.usedBins - mean(settings.usedBins);
            weights = abs(channel(pilots));
            design = [ones(numel(pilots), 1), bins(pilots)] .* weights;

            corrected = received;
            fits = zeros(2, size(received, 2));
            for k = 1:size(received, 2)
                drift = unwrap(angle(received(pilots, k) ./ (channel(pilots) * sqrt(settings.pilotEnergy))));
                fits(:, k) = design \ (drift .* weights);
                corrected(:, k) = received(:, k) .* exp(-1i * (fits(1, k) + fits(2, k) * bins));
            end
        end

    end
end
