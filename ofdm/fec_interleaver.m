function permutation = fec_interleaver(numberOfBits, columns)
assert(mod(numberOfBits, columns) == 0, 'Interleaver length must be a multiple of the column count.');
permutation = reshape(reshape(1:numberOfBits, columns, []).', [], 1);
end
