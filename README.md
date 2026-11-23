# Acoustic OFDM in base MATLAB

This project implements and tests an OFDM simulation, LS and L-MMSE channel
estimation, fixed QPSK versus naive/estimation-aware bit loading, and a real
fixed-QPSK image waveform. It includes acoustic measurement routines. **The
saved audio demonstration uses a synthetic room. No live room measurement or
over-the-air success is claimed.** Adaptive acoustic feedback is a remaining
stretch goal.

Validated installation: **MATLAB R2026a, 26.1.0.3203278**, Windows 11. Installed
products are MATLAB, Simulink and Control System Toolbox. The project uses
**base MATLAB only**, including `fft`, `erfc`, `audiorecorder`, `audioplayer`,
`audioread` and `audiowrite`. Communications, DSP, Signal Processing and Image
Processing Toolboxes are not required. Other MATLAB releases were not tested;
the plotting/export syntax requires R2020a or newer.

## Run the complete software project

Clone the repository, or unzip the delivered project:

```powershell
git clone https://github.com/juslookin/acoustic_ofdm_matlab.git
cd acoustic_ofdm_matlab
```

Open MATLAB, set its Current Folder to `acoustic_ofdm_matlab`, and run:

```matlab
settings = startup_project();
report = run_tests();
results = run_all_simulations();
```

`config.m` discovers the project root automatically, so moving or cloning the
folder requires no code edits. `run_all_simulations` already runs the tests;
calling `run_tests` separately is useful for a quick check. A full run takes a
few minutes on the validated machine and overwrites reproducible software
results. Each experiment resets its own documented RNG seed.

PowerShell batch alternative, starting inside the project folder:

```powershell
& 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe' -batch "run_all_simulations;"
```

The agent's sandbox needed `MATLAB_PREFDIR` redirected to a writable workspace
folder and MATLAB launched with access to its licensing service. This is an
execution-environment issue; normal desktop MATLAB does not require changes
to the modem. No preferences or licence files are bundled.

## Read and inspect the results

- `results/RESULTS.md`: actual recorded numbers and interpretation.
- `VIVA_NOTES.md`: equations, examples, assumptions, code flow and generated results.
- `results/reproducibility.mat`: complete settings, version and product inventory.
- `results/*.csv`: readable numerical tables with intervals and trial counts.
- `results/code_review.txt`: MATLAB static analyzer results.
- `results/entry_point_validation.txt`: offline entry-point checks on synthetic
  noise/sweep/tone fixtures and the saved waveform; no devices opened.
- `results/adaptive.mat`: per-channel raw counts, column names, bootstrap indices
  and paired aware-minus-naive goodput differences.
- `figures/*.png` and `*.fig`: shareable plots and editable MATLAB figures.
- `data/fixed_qpsk_transmit.wav`: real transmit waveform.
- `data/fixed_qpsk_recording_simulation.wav`: synthetic recording with latency,
  a real FIR and coloured noise.
- `data/transmitted_image.png` and `data/received_image_simulation.png`: image demo.

Trace one small packet without running the full experiments:

```matlab
trace = trace_one_packet();
trace.payloadBytes(1:8)
trace.packetBits(1:16)
trace.firstQpskSymbols
trace.receiver.channelEstimate(1:8)
trace.receiver.passed
```

## Fixed-QPSK audio entry point

```matlab
result = run_fixed_qpsk_demo('simulation'); % Real waveform, synthetic room
manifest = run_fixed_qpsk_demo('prepare'); % Save WAV and manifest only
result = run_fixed_qpsk_demo('hardware');   % Plays sound, records microphone
result = run_fixed_qpsk_demo('file', 'C:/path/to/recording.wav');
```

The default is the safe, reproducible simulation. The hardware mode requires a
48 kHz input/output device and a suitable speaker/microphone arrangement. Set
device IDs in `config.m` if defaults are unsuitable; inspect with
`audiodevinfo`. Disable AGC, noise suppression, echo cancellation and OS audio
enhancements. Keep playback volume moderate and avoid clipping. Capture mono
or stereo WAV at 48 kHz; file mode averages stereo channels. The file receiver
expects the deterministic demo image format and known image dimensions. It
does not implement a general-purpose file-transfer protocol.

Each audio packet contains 4 protected header bytes (16-bit packet ID and
16-bit valid-data length), 64 image bytes and CRC32: **576 bits**, exactly
three data OFDM symbols at the default pilot spacing. A frame also has a
50 ms chirp, 30 ms guard, two full-band training symbols and a 30 ms gap.
The 4096-byte image uses 64 frames. The receiver inserts gray pixels for
missing/CRC-failed image packets. Synthetic replay BER uses known transmit
bits; an actual receiver without the original can only report CRC results.

Base MATLAB starts recording and playback asynchronously. It does not provide
sample-synchronous duplex timing. Chirp/training synchronization handles start
latency; pilot phase/slope tracking handles modest within-packet clock error.
Large clock mismatch, intercarrier interference, clipping and nonlinear audio
processing require further work. A synthetic 30 ppm clock test is included.

## Measurements (physical interaction required)

```matlab
toneResult = run_audio_measurements('tones');
quietResult = run_audio_measurements('noise');
fanResult = run_audio_measurements('noise'); % Run again with fan on
channelResult = run_audio_measurements('channel');
variationResult = run_audio_measurements('variation');
```

Noise recordings last 30 s. The exponential sweep lasts 2 s, followed by a
0.4 s tail. Repeated variation probes last 0.12 s with a 0.2 s tail, 0.05 s
record lead and tail, and a requested 0.75 s interval: minimum acquisition is
0.42 s before overhead. Actual start times are saved; late probes are never
overlapped. Twenty probes take about 15 s plus device overhead. Shape
correlation is measured after strongest-arrival alignment; it is not a
calibrated absolute-phase/Doppler coherence measurement.

Each physical run saves a timestamped MAT containing the recording, probe,
settings and derived results. Plots show the most recent run; timestamped raw
data remain available. Noise/channel/tones can also analyze a WAV offline:

```matlab
noiseResult = run_audio_measurements('noise', 'C:/path/to/noise.wav');
channelResult = run_audio_measurements('channel', 'C:/path/to/sweep_recording.wav');
```

Offline channel analysis expects the exact sweep defined in `config.m` to
have been played. Deconvolution uses regularized FFT least squares, with
latency recorded separately and delays referenced to the strongest arrival.
This replaces the reference's Farina inverse filter. Band-limited resolution,
weaker precursor paths and a noise-biased late tail limit delay estimates.
`measurement_decisions` suggests CP length/pilot spacing; these are estimates,
not automatic configuration edits or a validated usable-band decision.

Replay a measured FIR with scaled recorded noise after making measurements:

```matlab
result = run_measured_channel_simulation( ...
    'C:/path/to/channel_TIMESTAMP.mat', ...
    'C:/path/to/noise_TIMESTAMP.mat');
```

This is a convolution/replay simulation. It does not replace an over-the-air
packet trial. The noise clip must cover the complete transmission; short
clips are rejected instead of periodically repeated. Repeat measurements at
0.5, 1 and 2 m to obtain distance evidence. No such data are included.

## Model, power and fairness

The FFT pair is unitary: `sqrt(N)*ifft(X)` and `fft(x)/sqrt(N)`. Each used
positive-bin data symbol has ensemble energy Es=1; each pilot has Ep=1.
The complex simulation uses proper-complex Gaussian taps with normalized PDP.
The real acoustic waveform uses Hermitian symmetry and a real FIR; the mirror
doubles energy without doubling information. An explicit test connects both
models through the same positive-bin channel equation.

Synthetic noise has known per-bin variance `Es*noiseShape/rho`, normalized so
`mean(noiseShape)=1`; the SNR axis is `rho=Es/mean(noiseVariance)`, not the mean
instantaneous faded SNR. The finite-FFT stationary noise model has exactly
diagonal covariance by construction. The L-MMSE function also accepts full
pilot-noise covariance. Measured real noise PSD maps approximately to positive
unitary-FFT variance as `fs*oneSidedPSD/2`; finite-window cross-bin covariance
can remain. No measured-noise diagonal model is claimed exact.

Fixed QPSK, naive and aware loading share the channel, pilot noise, data noise
and payload stream within each comparison. They have equal **per-carrier
ensemble-energy limits**, identical pilots and frame duration. There is no
power reallocation: off carriers save energy. Actual energy/budget is reported.
This is not a comparison at exactly equal expended energy per realization.
Random tail padding avoids biasing 16-QAM energy with all-zero symbols.

One comb probe is followed by 12 data slots in simulation. Each fade is fixed
throughout that frame; data pilots count against resources but do not update
the estimate. Adaptive feedback is ideal and costs no extra slots. The audio
receiver instead uses two full-band training symbols and per-symbol pilot
tracking. These distinct protocols are explicitly documented.

## Statistical interpretation and scope

The central configuration uses 4000 independent channel realizations per
estimation/fixed-fading point and 2400 per adaptive point. Channel bootstrap
intervals preserve dependence among carriers, symbols and packets sharing a
fade. Paired goodput differences resample the same frame triplets. Independent
BPSK/QPSK AWGN/conditional trials use Wilson intervals; QAM uses a CLT across
independent symbols. Pointwise 95% intervals are not simultaneous guarantees.

Low-SNR adaptive points can have very few active packets despite many channel
draws. Tables give actual compared bits and channels with packets. These are
exploratory when sparse; zero observed errors do not prove target compliance.
Bootstrap zero-event upper endpoints are `NaN`, explicitly unavailable. The
effective-SNR formula is tested in a separate conditional-error experiment.

Completed: tested simulation, both estimators, three loading policies, outage,
CRC/BER/goodput, uncertainty, real fixed-QPSK image waveform, offline receiver,
measurement/replay routines and saved experiments. Remaining: physical room
measurements, hardware duplex/clock testing, live distance/90% CRC validation,
measured-PDP statistical fitting, adaptive acoustic probe/feedback, robust
general file-transfer framing and coding. No hardware function was invoked
while validating this delivery. Synthetic signals are labelled throughout.

## Source layout and design changes

`config.m` is the central configuration. `ofdm/` follows mapping -> IFFT/CP ->
FFT -> estimation/equalization -> decisions -> CRC. `channel/` separates
proper-complex fading from real FIR convolution. `audio/` handles physical
waveforms and synchronization. `measure/` estimates PSD, FIR and variation.
`experiments/` saves figures/tables. `statistics/` contains interval routines.
`run_tests.m` contains focused deterministic and statistical checks.

Changes to the reference: MATLAB replaces Python; calendar/stop gates removed;
off mode added; coloured covariance and FFT/power conventions made explicit;
exact Gray 16-QAM theory used; CRC packet sizes fixed; feasible probe timing;
regularized deconvolution replaces Farina inversion; separate complex/real
channel models; statistical uncertainty uses independent channel frames;
effective-SNR/adaptive advantage treated as hypotheses. Hardware-dependent
results and adaptive acoustic transmission remain outside completed scope.

Official MATLAB references: [FFT](https://www.mathworks.com/help/matlab/ref/fft.html),
[IFFT](https://www.mathworks.com/help/matlab/ref/ifft.html),
[audio recording](https://www.mathworks.com/help/matlab/ref/audiorecorder.html),
[audio playback](https://www.mathworks.com/help/matlab/ref/audioplayer.html).
