function [nextState, outputs] = fec_trellis()
%FEC_TRELLIS State table for the K=7, rate-1/2 code with generators 133/171.
% State s (0..63) holds the previous six inputs, most recent in bit 5.
% Outputs: nextState [64 x 2] (column = input 0/1), outputs [64 x 2 x 2]
% logical coded bits (third index: generator 133, then 171).
generators = [bin2dec('1011011'), bin2dec('1111001')]; % 133, 171 octal
nextState = zeros(64, 2);
outputs = false(64, 2, 2);
for state = 0:63
    for input = 0:1
        register = input * 64 + state; % bit 6 = current input
        nextState(state + 1, input + 1) = floor(register / 2);
        for generatorIndex = 1:2
            outputs(state + 1, input + 1, generatorIndex) = ...
                mod(sum(dec2bin(bitand(register, generators(generatorIndex))) == '1'), 2) == 1;
        end
    end
end
end
