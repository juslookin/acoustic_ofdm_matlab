function bits = demap_symbols(symbols)
bits = [real(symbols(:)).'; imag(symbols(:)).'] < 0;
bits = bits(:);
end
