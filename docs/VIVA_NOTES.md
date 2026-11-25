# Acoustic OFDM viva notebook

Notes for explaining the project out loud: conventions, derivations and a
worked example for each part. Synthetic channel parameters are assumptions,
not fitted to measured rooms; no room impulse-response measurements have been
made yet. Live speaker-to-microphone results are in the main README.

## Conventions and the packet path

Bits, bytes, taps and carrier indices are columns. A frequency-domain frame is
`used carriers x OFDM symbols`; each column is one time slot. Bin numbers are
zero-based in `settings.usedBins`, so MATLAB accesses bin k at index k+1.
The forward path is payload bytes -> CRC -> bits -> Gray symbols -> carrier
grid -> unitary IFFT -> cyclic prefix -> channel. The reverse path removes the
prefix, FFTs, estimates the channel, equalizes, makes hard decisions and checks
the CRC. Adaptive loading is known to the simulated receiver through ideal
feedback; an acoustic fixed-QPSK packet requires no loading feedback.

## Initial design decisions

- Base MATLAB only; modulation, CRC, PSD and confidence intervals are explicit.
- Complex fading and real acoustics use separate physically valid models.
- The Monte Carlo receiver observes comb pilots once per quasi-static frame.
  Data-symbol pilots consume the same resources but do not update the estimate.
  The audio receiver instead uses two full-band training symbols and tracks
  common phase plus phase slope from data-symbol pilots.
- Every method has the same per-carrier Es=1 and pilot Ep=1 power constraint.
  Off carriers stay silent; power is never redistributed. Total used energy is
  reported, so outage cannot masquerade as equal transmitted energy.
- Coloured synthetic noise has a specified diagonal FFT-domain covariance.
  General pilot-noise covariance is supported by the estimator. Recorded
  acoustic noise can have cross-bin correlation; its diagonal PSD approximation
  is labelled explicitly and is not used as an exact L-MMSE prior.
- Effective SNR and adaptive superiority are hypotheses, not acceptance criteria.
  Packet delivery is measured with the actual CRC, separately from BER.

## Modulation and CRC: first worked example

`modulate_bits([0;1],2)=(1-j)/sqrt(2)` and unit average energy follows because
each axis has magnitude 1/sqrt(2). In 16-QAM each real axis has mean square 5;
dividing the complex symbol by sqrt(10) therefore gives Es=1. Gray axis labels
are 00:+3, 01:+1, 11:-1, 10:-3. Demapping uses signs and the threshold 2/sqrt(10).
For gamma=Es/E|N|², BPSK BER=Q(sqrt(2 gamma)), QPSK BER=Q(sqrt(gamma)).
The exact Gray 16-QAM BER is 3/4 Q(a)+1/2 Q(3a)-1/4 Q(5a), a=sqrt(gamma/5).
Using only the first term is an approximation, and a poor one at very low SNR.
CRC-32/ISO-HDLC of ASCII `123456789` is hexadecimal CBF43926. A 64-byte
payload becomes 68 bytes, or 544 bits. CRC is error detection, not correction.

## OFDM normalization and real acoustics: first worked example

We use x=sqrt(N)*ifft(X) and X=fft(x)/sqrt(N), hence Parseval gives
sum|x|²=sum|X|². A complex simulation with K unit-energy used bins has expected
useful-symbol energy K. Real acoustics mirrors the K positive bins and has
energy 2K. Both use the same positive-bin Es convention; the mirror conveys no
new bits. If N=1024, CP=256, the prefix occupies 20% of the transmitted symbol.
With 32 pilots, 96 QPSK data carriers carry 192 bits every 1280/48000 seconds:
7200 raw data bits/s before training, chirps, packet CRC and gaps.
For a real FIR h, the transfer is H=fft(h,N), with NO unitary scale on h.
Complex Gaussian fading taps must never be convolved with a real speaker signal.

## Estimation and loading: first worked example

Pilot observations are z=Yp./Xp=Hp+v, with Cv=diag(1./Xp) Cn diag(1./Xp)'.
For H=Fh and tap covariance diag(p), R=F diag(p) F'. L-MMSE is
W=R(:,p)/(R(p,p)+Cv), Hhat=Wz, Ce=R-W R(p,:). The code solves a linear system.
LS uses z directly on pilots and linear interpolation/extrapolation elsewhere.
If |Hhat|²=0.2, noise variance=0.01 and error variance=0.04, naive gamma=20,
aware gamma=4. QPSK predicted BER changes from about 3.9e-6 to 0.0228.
The aware rule therefore turns this carrier off at target 1e-3 if even BPSK
fails. It uses the weakest carrier in each 8-data-carrier chunk.
E*X is not generally Gaussian for QAM; correlated errors also couple carriers.
Independent-frame Monte Carlo must test this approximation.

## Channel and noise module: worked example

`channel_statistics` constructs F(k,l)=exp(-j 2 pi k d_l/N). If two taps have
powers [0.8,0.2], then R(k,k)=0.8+0.2=1 and R(k,m) contains a sum of two
complex exponentials. This frequency correlation lets pilots inform nearby
data carriers. `draw_channels` uses sqrt(p_l/2)*(u+jv), with independent
unit-variance real Gaussians u,v. Thus E|h_l|²=p_l. Each column of H is a new
independent realization; OFDM symbols inside its frame share that column.
The central synthetic PDP is assumed, not fitted to any measured room.

Synthetic coloured noise has variance v_k=Es*c_k/rho, mean(c_k)=1. For example,
rho=100 (20 dB), c=[0.5,1.5] gives variances [0.005,0.015] at Es=1. Replacing
both by 0.01 would overstate one carrier's reliability and understate the
other's. Frequency-domain noise is independent across bins/time slots by
construction; its time-domain equivalent is circularly stationary noise.
An arbitrary finite segment of an AR process or recorded noise need not have
diagonal FFT covariance. The real-waveform demo deliberately uses actual
linear FIR convolution and real AR noise, not the complex-tap model.

Es/N0 means Es/E|N|² per complex symbol in the AWGN formulas. Es=1 and
E|N|²=0.01 gives 20 dB; each real noise component has variance 0.005. For QPSK,
Eb=Es/2 before overhead, so Eb/N0 is 3.0103 dB below Es/N0. Mirror energy,
CP, pilots, chirps and CRC all add costs when quoting energy per payload bit.

## Deriving L-MMSE and its limitations

Choose W to minimize E||H-Wz||². Orthogonality requires E[(H-Wz)z']=0, giving
W E[zz']=E[Hz']. Since z=Hp+v, E[Hz']=R(:,p) and
E[zz']=R(p,p)+Cv. This yields the weights in `estimator_weights`. The posterior
error covariance is Ce=R-R(:,p)/(R(p,p)+Cv)*R(p,:). `diag(Ce)` is a per-carrier
channel-error variance, not a received noise variance. No explicit inverse is
formed. Dividing observations by a pilot with energy Ep divides its noise
variance by Ep; complex pilot phases also rotate off-diagonal covariance.

As a scalar example, prior variance R=1 and pilot-noise variance 0.25 give
W=1/1.25=0.8 and Ce=1-0.8=0.2. LS reports z, while L-MMSE shrinks it to 0.8z.
L-MMSE error is uncorrelated with Hhat; joint proper Gaussian assumptions make
them independent. With non-Gaussian channels, uncorrelated does not imply
independent. A wrong PDP or noise covariance can undermine this advantage.
This project validates the matched-prior case, not robustness to all mismatch.

The audio receiver uses averaged full-band training LS estimates rather than
claiming the synthetic complex-Rayleigh prior fits a real room. For two
identical training symbols, Y1-Y2=N1-N2, so E|Y1-Y2|²=2v_k only when the
channel is constant and the two noise realizations are independent. It
smooths per-bin estimates over nine adjacent bins to reduce variance, at the
cost of bias when the noise spectrum changes sharply. Channel drift can
inflate this noise estimate. This is a practical estimate, not a calibrated
full covariance estimate from two samples.

## Loading, mapping and CRC throughput: worked example

The receiver equalizes Y=(Hhat+E)X+N by Hhat. The residual is (EX+N)/Hhat.
Replacing EX by independent Gaussian noise of variance Ce*Es gives
gammaEff=|Hhat|²*Es/(Ce*Es+v). Constant-modulus BPSK/QPSK have exact scalar
conditional Gaussian residuals under the assumed Gaussian E. For 16-QAM,
the variance Ce*|X|² depends on the transmitted point, so averaging energy
before computing BER is an approximation. `experiment_effective_snr` fixes
a representative estimate and independently samples errors/noise to test it.
Even a correct scalar expression does not remove cross-carrier/packet error
dependence. There is no theorem here guaranteeing the adaptive target.

For every chunk we test BPSK, QPSK, then 16-QAM at its weakest predicted SNR.
If none meets target, all chunk data carriers are off. Pilots remain. The
naive rule and aware rule both use L-MMSE Hhat; they differ only in the Ce*Es
denominator term. This isolates loading-rule behavior from estimator choice.
L-MMSE estimates are often shrunk; naive does not necessarily overestimate
every channel. Weakest-carrier chunk loading can already be conservative.

`map_loaded_frame` takes a loading such as [1;0;2]. A slot contains 3 bits:
first bit -> BPSK carrier 1, carrier 2 -> zero, next two bits -> QPSK carrier 3.
The next slot begins at bit 4. Carrier offsets [0;1;1] plus slot offsets
[0,3,...] implement this same order in a few readable matrix operations.
Demapping uses exactly the same indices. Modulation order is known to the
simulated receiver through ideal feedback. Feedback errors/latency are absent.

Simulation uses 12 data slots plus one comb probe per frame. With 96 QPSK data
carriers, capacity=12*96*2=2304 bits. Four 544-bit packets fit, leaving 128
random padding bits. If 3 packets pass CRC, delivered payload is 3*512=1536
bits, or 1536/13=118.15 payload bits per transmitted OFDM slot. CRC bytes,
padding and pilot/probe resources are excluded from delivered payload.

At independent BER p=0.001, an illustrative 544-bit packet success probability
is (1-p)^544, about 0.580. Thus BER target 1e-3 does not mean 99.9% CRC success.
Our faded packets do not have independent bit errors; actual CRC is evaluated
instead of using that expression to predict throughput. CRC collisions remain
possible; CRC32 detects corruption with very high probability but is not an
error-correcting code or an absolute guarantee. A one-bit error in a 544-bit
packet gives BER 1/544 but zero delivered payload for that packet.

## Synchronization, tracking and audio framing: worked example

The chirp's instantaneous frequency is f(t)=f0+(f1-f0)t/T; integrating gives
phase 2pi*(f0*t+(f1-f0)*t²/(2T)). A Hann taper reduces abrupt edges. Sliding
normalized matched correlation locates the earliest strong preamble, then
known training refines the OFDM start within one CP. A 137-sample latency
moves a zero-delay preamble start from MATLAB index 1 to index 138. Absolute
latency need not be known before transmission. Strongest-path locking and
late reverberation can still limit timing in difficult rooms.

For a sample displacement d, a carrier k acquires approximately
phi(k)=-2pi*k*d/N. Clock mismatch lets d grow over time. Pilot phase residuals
are unwrapped and fitted to a+b*(k-mean(k)) with channel-magnitude weights.
For a=0.3 rad and b=0.002 rad/bin, the unit test applies this phase to a known
grid and removes it to numerical precision. Another test resamples a full
waveform at 30 ppm clock mismatch and checks CRC. This supports modest drift
in a short synthetic packet; it does not prove physical drift/ICI robustness.
Chirp timing is analogous to estimating delay from a matched known waveform;
FMCW radar often estimates beat frequency instead, so it is an analogy rather
than an identical receiver implementation.

An image packet carries [ID_hi,ID_lo,length_hi,length_lo,64 image bytes], then
CRC32. Packet 1 with 64 valid bytes begins [0,1,0,64]. Its 68 payload/header
bytes plus 4 CRC bytes yield 576 bits: exactly three default data slots. The
training estimate includes the frame's global transmit gain, so equalization
automatically removes that gain. We never normalize each received symbol by
its own peak. Real waveform CP/mirrors preserve the positive-bin channel law.
Frames have their own chirps/training; the receiver still assumes known
image size and fixed packet format. Severe packet loss/false synchronization
needs a stronger general framing protocol. Failed image bytes are gray.

## Measurements and decisions: worked examples

`welch_psd` removes each segment's mean, multiplies by a Hann window, FFTs,
divides by fs*sum(window²), doubles positive bins except DC/Nyquist, then
averages overlapping periodograms. Units are full-scale²/Hz, not dB SPL.
Integrating the one-sided PSD approximates time variance. White noise with
variance 0.04 at fs=48000 has one-sided positive PSD 2*0.04/48000, so the
unitary positive-bin variance fs*PSD/2 returns 0.04. Overlapping Welch segments
are not independent repetitions for a confidence claim.

For a sweep recording Y=HX+N, regularized least squares uses
Hhat=Y*conj(X)/(|X|²+lambda), lambda=1e-6*max|X|². Zero-padding avoids circular
wrap through the recorded support. Frequencies with little sweep energy are
not reliably identified. The strongest inverse-FFT arrival establishes the
delay origin; its original index is saved as latency. This is regularized
linear deconvolution, not harmonic-separating Farina processing. A real room's
time variation, nonlinear speaker distortion and residual noise can bias h.

Delay statistics use p_l=|h_l|²/sum|h|², mean delay=sum(t_l*p_l), and
tauRms=sqrt(sum((t_l-meanDelay)²*p_l)). If two equal-power taps arrive at 0 and
1 ms, mean delay=0.5 ms, tauRms=0.5 ms and approximate coherence bandwidth
1/(5*tauRms)=400 Hz. A 99%-energy delay of 1 ms suggests at least 48 CP samples
at 48 kHz. A pilot spacing of 8 bins is 375 Hz at N=1024; that is only a rough
coherence-bandwidth check, not a sampling theorem for every multipath channel.
Late energy outside the CP causes ISI/ICI and cannot be removed by a one-tap
equalizer. Delay spread does not determine time coherence or a reprobe period.

Variation acquisition must fit inside its interval: 0.05+0.12+0.20+0.05=0.42 s
before overhead, below the requested 0.75 s. Actual timestamps are saved. If
device overhead exceeds the target interval, subsequent probes start late;
they never overlap. Shape correlation uses |H_i'*H_j|/(||H_i||*||H_j||), so
identical shapes with a global phase rotation still have correlation 1. This
method cannot identify all physical channel variations. A NaN coherence time
means no crossing was observed, not infinite coherence.

The tone check reports FFT peak errors, approximate periodic-probe latency and
spectral tone-to-residual ratio. This ratio is not a calibrated communication
SNR. Audio enhancements can alter amplitude, suppress pilots, impose time
variation or remove the played signal through echo cancellation. That breaks
the linear time-invariant assumptions even if ordinary speech sounds fine.

## Experiments and uncertainty: worked example

Experiment calls follow the modem dependencies: test primitives -> model PSD/
PDP diagnostics -> AWGN -> estimation MSE -> fixed faded BER -> conditional
effective SNR -> adaptive packets -> real-waveform image replay. Synthetic E1,
E2 and E6 titles explicitly say synthetic; measured figures are produced only
when measurement entry points are run. All raw settings are saved with data.

For 100 errors among 100000 independent BPSK trials, a Wilson interval is
appropriate. For 100000 bits sharing 10 fades, the independent units are the
10 fades: a bitwise Wilson interval would be much too narrow. Our bootstrap
resamples complete independent frames and recomputes total errors/total bits;
it resamples the same frame indices across the three methods for paired
goodput differences. 600 bootstrap repetitions give approximate percentile
intervals; rare-event tails warrant larger studies. QAM bits in one symbol
are also dependent, so independent-symbol CLT intervals are used there.

For independent errors near p=1e-3, relative standard error is approximately
1/sqrt(N*p). A 95% relative half-width near 10% needs about 384000 bits under
the independent-bit approximation. More than one million bits is a useful
starting point, not a substitute for independent channel draws. The adaptive
experiments use 2400 channel draws per point; low-SNR outage can leave too few
active packets for a strong target claim. Both trial counts are in the tables.
Zero errors give no bootstrap upper-tail information; NaN upper endpoints
mark that limitation explicitly. Pointwise intervals do not jointly guarantee
all plotted values. The theory should usually, not invariably, lie within 95%.

## Scope and questions to answer candidly

Things to be upfront about: measured-PDP fitting and adaptive loading over
real sound are not done, and the matched synthetic prior is not a fitted room
model. The audio link has optional convolutional coding (the simulation study
does not use it), and there is no channel prediction. Distance tests are still
to do. Whether adaptive loading actually helps was treated as a question; the
generated results below record what happened.

To explain the code orally, start with `trace_one_packet`, then
`make_audio_frame`/`decode_audio_frame`. For the contribution, follow
`channel_statistics` -> `estimator_weights` -> `select_loading` ->
`evaluate_adaptive_frame` -> `experiment_adaptive`. Explain what each array's
rows and columns represent before describing its matrix equation. Review
`results/adaptive_paired_differences.csv` before claiming improved throughput.



<!-- GENERATED RESULTS BELOW -->

# Recorded software results

Run: 2026-11-23 13:55:23. MATLAB 26.1.0.3203278 (R2026a). Seed 3362026. Elapsed 284.0 s.

All 16 software tests passed. No speaker/microphone experiment was performed.

## AWGN validation

15/15 exact-theory values fall inside available pointwise 95% intervals (Wilson for BPSK/QPSK, independent-symbol CLT for QAM). Multiple comparisons can produce misses even for correct code.

## Channel estimation

4000 independent channels per point. Empirical/theoretical L-MMSE MSE ratio ranges 0.9903 to 1.0008.

Perfect-CSI Rayleigh theory lies within 21/21 pointwise channel-bootstrap BER intervals. Estimated-channel BER is reported separately; it is not expected to equal perfect-CSI theory.

## Adaptive packet results

Each point uses 2400 independent quasi-static channels, 12 data slots plus one comb probe, 64-byte payloads plus CRC32.

| Spacing | SNR dB | Method | BER [95% channel bootstrap] | Compared bits | CRC success | Payload bits/slot [95%] | Off fraction | Energy/budget |
|---|---|---|---|---|---|---|---|---|
| 4 | 0 | fixed | 0.208 [0.2055, 0.2106] | 5222400 | 0.0000 | 0.000 [0.000, NaN] | 0.000 | 1.000 |
| 4 | 0 | naive | 0.0003547 [0.0001557, 0.000613] | 31008 | 0.8421 | 0.788 [0.558, 1.017] | 0.940 | 0.309 |
| 4 | 0 | aware | 5.57e-05 [0, 0.000178] | 17952 | 0.9697 | 0.525 [0.345, 0.706] | 0.957 | 0.297 |
| 4 | 5 | fixed | 0.1119 [0.1098, 0.114] | 5222400 | 0.0001 | 0.016 [0.000, 0.049] | 0.000 | 1.000 |
| 4 | 5 | naive | 0.0002162 [0.0001695, 0.0002643] | 541280 | 0.9005 | 14.704 [13.899, 15.672] | 0.753 | 0.447 |
| 4 | 5 | aware | 6.313e-05 [3.982e-05, 9.105e-05] | 396032 | 0.9670 | 11.553 [10.765, 12.423] | 0.789 | 0.421 |
| 4 | 10 | fixed | 0.04817 [0.04674, 0.04956] | 5222400 | 0.0204 | 3.216 [2.560, 3.807] | 0.000 | 1.000 |
| 4 | 10 | naive | 0.0001958 [0.0001741, 0.0002176] | 2226592 | 0.9062 | 60.866 [59.011, 62.507] | 0.466 | 0.658 |
| 4 | 10 | aware | 7.28e-05 [5.906e-05, 8.777e-05] | 1854496 | 0.9633 | 53.891 [52.168, 55.582] | 0.510 | 0.625 |
| 4 | 15 | fixed | 0.01755 [0.01679, 0.01829] | 5222400 | 0.1764 | 27.783 [25.845, 29.719] | 0.000 | 1.000 |
| 4 | 15 | naive | 0.0001319 [0.0001207, 0.0001427] | 4770336 | 0.9345 | 134.482 [132.217, 136.550] | 0.226 | 0.834 |
| 4 | 15 | aware | 4.769e-05 [4.074e-05, 5.49e-05] | 4340576 | 0.9756 | 127.737 [125.423, 129.756] | 0.255 | 0.812 |
| 4 | 20 | fixed | 0.005922 [0.005533, 0.006269] | 5222400 | 0.4512 | 71.089 [68.266, 73.666] | 0.000 | 1.000 |
| 4 | 20 | naive | 8.602e-05 [7.636e-05, 9.668e-05] | 7242816 | 0.9579 | 209.280 [206.933, 211.333] | 0.103 | 0.924 |
| 4 | 20 | aware | 2.83e-05 [2.441e-05, 3.259e-05] | 6854944 | 0.9847 | 203.618 [201.337, 205.638] | 0.118 | 0.913 |
| 4 | 25 | fixed | 0.001941 [0.001777, 0.002106] | 5222400 | 0.6868 | 108.193 [105.501, 110.835] | 0.000 | 1.000 |
| 4 | 25 | naive | 3.458e-05 [3.066e-05, 3.905e-05] | 8934656 | 0.9816 | 264.566 [262.843, 266.142] | 0.050 | 0.964 |
| 4 | 25 | aware | 1.357e-05 [1.087e-05, 1.674e-05] | 8698016 | 0.9929 | 260.513 [258.724, 262.155] | 0.057 | 0.959 |
| 4 | 30 | fixed | 0.000634 [0.0005601, 0.0007091] | 5222400 | 0.8547 | 134.646 [132.791, 136.485] | 0.000 | 1.000 |
| 4 | 30 | naive | 1.353e-05 [1.077e-05, 1.64e-05] | 9758272 | 0.9928 | 292.234 [291.084, 293.384] | 0.023 | 0.984 |
| 4 | 30 | aware | 4.771e-06 [3.312e-06, 6.234e-06] | 9641312 | 0.9975 | 290.117 [288.935, 291.267] | 0.026 | 0.981 |
| 8 | 0 | fixed | 0.2187 [0.216, 0.2216] | 5222400 | 0.0000 | 0.000 [0.000, NaN] | 0.000 | 1.000 |
| 8 | 0 | naive | 0.0005096 [0.0002902, 0.000771] | 54944 | 0.8020 | 1.329 [1.050, 1.608] | 0.939 | 0.187 |
| 8 | 0 | aware | 0.0001149 [0, 0.0002903] | 17408 | 0.9375 | 0.492 [0.328, 0.673] | 0.966 | 0.163 |
| 8 | 5 | fixed | 0.1202 [0.118, 0.1227] | 5222400 | 0.0003 | 0.049 [0.000, 0.131] | 0.000 | 1.000 |
| 8 | 5 | naive | 0.0005069 [0.0004344, 0.0005837] | 724064 | 0.8234 | 17.986 [16.968, 19.036] | 0.746 | 0.354 |
| 8 | 5 | aware | 7.191e-05 [4.418e-05, 0.0001032] | 444992 | 0.9670 | 12.981 [12.029, 13.851] | 0.808 | 0.300 |
| 8 | 10 | fixed | 0.05317 [0.05165, 0.05475] | 5222400 | 0.0197 | 3.102 [2.412, 3.774] | 0.000 | 1.000 |
| 8 | 10 | naive | 0.0004825 [0.0004395, 0.0005322] | 2799968 | 0.8146 | 68.808 [66.625, 70.975] | 0.452 | 0.609 |
| 8 | 10 | aware | 8.675e-05 [7.119e-05, 0.0001007] | 2063392 | 0.9586 | 59.668 [57.879, 61.376] | 0.532 | 0.539 |
| 8 | 15 | fixed | 0.01984 [0.01899, 0.02063] | 5222400 | 0.1617 | 25.469 [23.564, 27.455] | 0.000 | 1.000 |
| 8 | 15 | naive | 0.0003449 [0.0003196, 0.0003718] | 5845280 | 0.8565 | 151.024 [148.167, 153.682] | 0.214 | 0.815 |
| 8 | 15 | aware | 5.746e-05 [4.874e-05, 6.604e-05] | 4890016 | 0.9712 | 143.262 [140.732, 145.658] | 0.270 | 0.766 |
| 8 | 20 | fixed | 0.006856 [0.006425, 0.007255] | 5222400 | 0.4245 | 66.872 [64.279, 69.465] | 0.000 | 1.000 |
| 8 | 20 | naive | 0.0002023 [0.0001833, 0.0002215] | 8677344 | 0.9113 | 238.539 [235.700, 241.349] | 0.095 | 0.917 |
| 8 | 20 | aware | 3.073e-05 [2.604e-05, 3.565e-05] | 7906496 | 0.9840 | 234.699 [232.072, 237.179] | 0.123 | 0.893 |
| 8 | 25 | fixed | 0.002274 [0.002104, 0.00246] | 5222400 | 0.6670 | 105.075 [102.430, 107.735] | 0.000 | 1.000 |
| 8 | 25 | naive | 9.928e-05 [8.608e-05, 0.0001137] | 10515520 | 0.9560 | 303.245 [301.128, 305.281] | 0.045 | 0.961 |
| 8 | 25 | aware | 1.762e-05 [1.414e-05, 2.108e-05] | 10047680 | 0.9909 | 300.324 [298.404, 302.146] | 0.058 | 0.950 |
| 8 | 30 | fixed | 0.0007453 [0.0006704, 0.0008263] | 5222400 | 0.8374 | 131.922 [129.935, 133.909] | 0.000 | 1.000 |
| 8 | 30 | naive | 4.418e-05 [3.703e-05, 5.199e-05] | 11340768 | 0.9795 | 335.081 [333.604, 336.443] | 0.020 | 0.983 |
| 8 | 30 | aware | 7.188e-06 [5.142e-06, 9.532e-06] | 11129696 | 0.9964 | 334.539 [333.259, 335.787] | 0.027 | 0.977 |

Aware has point BER above target at 0/14 points with transmitted packets; naive at 0/14. These are observations, not proof of a universal guarantee.

Low-SNR adaptive points may have zero packets or fewer than one million compared bits; NaN in the estimate means no BER/CRC trials. NaN in an interval upper endpoint means zero observed events: bootstrap cannot provide an upper limit from this sample. Rare-event points are exploratory and do not establish BER-target compliance.

Paired aware-minus-naive goodput intervals are in `adaptive_paired_differences.csv`. `ObservedChunkViolationFraction` counts short empirical chunk samples above the target; it does not estimate how many latent chunk BERs truly exceed the target.

At spacing 8, 15 dB: naive BER 0.0003449, CRC success 0.856, goodput 151.02 bits/slot; aware BER 5.746e-05, CRC success 0.971, goodput 143.26 bits/slot. This is a measured reliability/rate trade-off. Weakest-carrier chunk loading already makes the naive policy conservative in this model.

## Effective-SNR hypothesis

For scalar conditional 16-QAM trials, 9/9 predictions lie outside the pointwise 95% intervals. See `effective_snr.csv`; this directly tests the Gaussian replacement of E*X.

## Real-waveform software demonstration

Synthetic real FIR, coloured AR noise, 137-sample latency: 64/64 CRC packets, BER 0, duration 16.023 s, 2045.02 payload bits/s. This is not over-the-air evidence.

## Scope and statistical limits

Synthetic PDP/noise are assumed, not measured. L-MMSE uses the correct Gaussian prior and known coloured covariance. Frequency-domain noise is exactly diagonal by construction; measured finite-window noise need not be. Methods share channel/noise/payload samples and equal Es/Ep carrier limits; off power is not reallocated.

Bootstrap units are independent channel frames. Wilson intervals are used for BPSK/QPSK independent AWGN/conditional bits; QAM uses independent-symbol CLT intervals. Trials sharing a fade are never treated as independent bits for BER uncertainty. Sparse/zero errors do not establish a strict 1e-3 BER guarantee.

Hardware I/O, measured room/noise, physical clock drift, distance trials and adaptive acoustic feedback remain untested or unimplemented. No live 90% CRC claim is made.
