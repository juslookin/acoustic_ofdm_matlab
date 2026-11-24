function bits = fec_decode(llr, numberOfBits)
%FEC_DECODE Soft-decision Viterbi decoder for fec_encode.
% Input: llr [2*(numberOfBits+6) x 1] log-likelihood ratios in the order
% fec_encode produces, positive meaning bit 0 is more likely; larger
% magnitude means more reliable. Output: logical [numberOfBits x 1].
[nextState, outputs] = fec_trellis();
steps = numberOfBits + 6;
llr = reshape(llr(1:2 * steps), 2, steps);
% Predecessors of each next state: register = 2*next + oldestBit.
next = (0:63).';
input = floor(next / 32);                 % newest bit of the next state
previous = [mod(2 * next, 64), mod(2 * next + 1, 64)];
% Antipodal output signs (+1 for bit 0) on the two incoming branches.
signs = zeros(64, 2, 2);
for branch = 1:2
    for generatorIndex = 1:2
        bitValues = outputs(sub2ind([64, 2, 2], previous(:, branch) + 1, input + 1, ...
            generatorIndex * ones(64, 1)));
        signs(:, branch, generatorIndex) = 1 - 2 * bitValues;
    end
end
assert(isequal(nextState(sub2ind([64, 2], previous(:, 1) + 1, input + 1)), next), 'Trellis mismatch.');
metric = -inf(64, 1);
metric(1) = 0;                             % encoder starts in state 0
decisions = false(64, steps);
for step = 1:steps
    branchMetric = signs(:, :, 1) * llr(1, step) + signs(:, :, 2) * llr(2, step);
    candidates = metric(previous + 1) + branchMetric;
    [metric, choice] = max(candidates, [], 2);
    decisions(:, step) = choice == 2;
end
% Tail bits force the final state to 0; trace back from there.
state = 0;
decoded = false(steps, 1);
for step = steps:-1:1
    decoded(step) = state >= 32;
    state = mod(2 * state + decisions(state + 1, step), 64);
end
bits = decoded(1:numberOfBits);
end
