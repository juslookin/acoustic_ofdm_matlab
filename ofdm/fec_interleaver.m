function permutation = fec_interleaver(numberOfBits, columns)
%FEC_INTERLEAVER Block interleaver: write row by row, read column by column.
% Adjacent coded bits end up numberOfBits/columns positions apart, i.e. on
% widely separated subcarriers, so one faded frequency causes scattered
% errors the Viterbi decoder can correct. transmitted = coded(permutation);
% deinterleave with received(permutation) = received.
assert(mod(numberOfBits, columns) == 0, 'Interleaver length must be a multiple of the column count.');
permutation = reshape(reshape(1:numberOfBits, columns, []).', [], 1);
end
