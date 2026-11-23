function results = run_all_simulations()
%RUN_ALL_SIMULATIONS Reproduce tests, E1-E5 software studies and synthetic audio.
% Input: none. Output: results structure plus MAT, CSV, PNG, FIG and WAV files.
% Never accesses microphone/speaker. Each experiment uses its own fixed seed.
settings = startup_project();
startTime = tic;
diaryPath = fullfile(settings.paths.results, 'simulation_log.txt');
if isfile(diaryPath)
    delete(diaryPath);
end
diary(diaryPath);
diaryCleanup = onCleanup(@() diary('off'));
runtime.matlabVersion = version;
runtime.computer = computer;
runtime.products = ver;
runtime.runTimestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
runtime.hardwareAudioExercised = false;
save(fullfile(settings.paths.results, 'reproducibility.mat'), 'settings', 'runtime');
fprintf('MATLAB %s; reproducible seed %d; no physical audio I/O.\n', runtime.matlabVersion, settings.seed);
results.tests = run_tests();
results.trace = trace_one_packet();
results.model = experiment_model_diagnostics(settings);
results.awgn = experiment_awgn(settings);
results.estimation = experiment_estimation(settings);
results.fading = experiment_fading(settings);
results.effectiveSnr = experiment_effective_snr(settings);
results.adaptive = experiment_adaptive(settings);
results.audio = run_fixed_qpsk_demo('simulation');
results.elapsedSeconds = toc(startTime);
save(fullfile(settings.paths.results, 'all_simulations.mat'), 'results', 'settings', 'runtime', '-v7.3');
write_results_summary(results, settings, runtime);
fprintf('Completed all software experiments in %.1f seconds.\n', results.elapsedSeconds);
clear diaryCleanup;
end
