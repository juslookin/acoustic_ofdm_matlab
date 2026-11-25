function bits = fec_decode(llr, numberOfBits)
[nextState, outputs] = fec_trellis();
steps = numberOfBits + 6;
llr = reshape(llr(1:2 * steps), 2, steps);

next = (0:63).';
input = floor(next / 32);
previous = [mod(2 * next, 64), mod(2 * next + 1, 64)];

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
metric(1) = 0;

decisions = false(64, steps);
for step = 1:steps
    branchMetric = signs(:, :, 1) * llr(1, step) + signs(:, :, 2) * llr(2, step);
    candidates = metric(previous + 1) + branchMetric;
    [metric, choice] = max(candidates, [], 2);
    decisions(:, step) = choice == 2;
end

state = 0;
decoded = false(steps, 1);

for step = steps:-1:1
    decoded(step) = state >= 32;
    state = mod(2 * state + decisions(state + 1, step), 64);
end

bits = decoded(1:numberOfBits);
end
