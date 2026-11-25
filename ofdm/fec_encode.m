function codedBits = fec_encode(bits)
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
