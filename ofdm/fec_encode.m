function codedBits = fec_encode(bits)
%FEC_ENCODE Rate-1/2, constraint-length-7 convolutional code (IEEE 802.11).
% Generators 133 and 171 (octal). Six zero tail bits return the encoder to
% state 0 so the Viterbi decoder can end in a known state.
% Input: bits logical [N x 1]. Output: logical [2*(N+6) x 1], ordered
% [A1; B1; A2; B2; ...] where A uses 133 and B uses 171.
[nextState, outputs] = fec_trellis();
bits = [logical(bits(:)); false(6, 1)];
codedBits = false(2, numel(bits));
state = 0;
for index = 1:numel(bits)
    input = double(bits(index));
    codedBits(:, index) = outputs(state + 1, input + 1, :);
    state = nextState(state + 1, input + 1);
end
codedBits = codedBits(:);
end
