classdef fec
    methods (Static)

        function coded = encode(bits)
            [nextState, outputs] = fec.trellis();
            bits = [logical(bits(:)); false(6, 1)];
            coded = false(2, numel(bits));

            state = 0;
            for k = 1:numel(bits)
                input = double(bits(k));
                coded(:, k) = outputs(state + 1, input + 1, :);
                state = nextState(state + 1, input + 1);
            end
            coded = coded(:);
        end

        function bits = decode(llr, numberOfBits)
            [~, outputs] = fec.trellis();
            steps = numberOfBits + 6;
            llr = reshape(llr(1:2 * steps), 2, steps);

            next = (0:63).';
            input = floor(next / 32);
            previous = [mod(2 * next, 64), mod(2 * next + 1, 64)];

            signs = zeros(64, 2, 2);
            for branch = 1:2
                for g = 1:2
                    bit = outputs(sub2ind([64, 2, 2], previous(:, branch) + 1, input + 1, g * ones(64, 1)));
                    signs(:, branch, g) = 1 - 2 * bit;
                end
            end

            metric = -inf(64, 1);
            metric(1) = 0;
            decisions = false(64, steps);

            for step = 1:steps
                branchMetric = signs(:, :, 1) * llr(1, step) + signs(:, :, 2) * llr(2, step);
                [metric, choice] = max(metric(previous + 1) + branchMetric, [], 2);
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

        function order = interleaver(numberOfBits, columns)
            order = reshape(reshape(1:numberOfBits, columns, []).', [], 1);
        end

        function [nextState, outputs] = trellis()
            generators = [bin2dec('1011011'), bin2dec('1111001')];
            nextState = zeros(64, 2);
            outputs = false(64, 2, 2);

            for state = 0:63
                for input = 0:1
                    register = input * 64 + state;
                    nextState(state + 1, input + 1) = floor(register / 2);

                    for g = 1:2
                        outputs(state + 1, input + 1, g) = mod(sum(dec2bin(bitand(register, generators(g))) == '1'), 2) == 1;
                    end
                end
            end
        end

    end
end
