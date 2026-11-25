function symbols = modulate_bits(bits)
bits = double(reshape(bits, 2, []));
symbols = ((1 - 2 * bits(1, :)) + 1i * (1 - 2 * bits(2, :))).' / sqrt(2);
end
