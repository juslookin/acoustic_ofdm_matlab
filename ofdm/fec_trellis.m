function [nextState, outputs] = fec_trellis()
generators = [bin2dec('1011011'), bin2dec('1111001')];
nextState = zeros(64, 2);
outputs = false(64, 2, 2);

for state = 0:63
    for input = 0:1
        register = input * 64 + state;
        nextState(state + 1, input + 1) = floor(register / 2);

        for generatorIndex = 1:2
            outputs(state + 1, input + 1, generatorIndex) = ...
                mod(sum(dec2bin(bitand(register, generators(generatorIndex))) == '1'), 2) == 1;
        end
    end
end
end
