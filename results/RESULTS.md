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
