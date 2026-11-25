function symbols = training_symbols(settings)
trainingStream = RandStream('mt19937ar', 'Seed', settings.seed + 99);
bits = rand(trainingStream, 2 * numel(settings.usedBins), 1) > 0.5;
symbols = sqrt(settings.pilotEnergy) * modulate_bits(bits, 2);
end
