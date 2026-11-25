function checksum = crc32_bytes(bytes)
persistent lookupTable
if isempty(lookupTable)
    lookupTable = zeros(256, 1, 'uint32');
    polynomial = uint32(hex2dec('EDB88320'));

    for tableIndex = 0:255
        remainder = uint32(tableIndex);
        for bitIndex = 1:8
            if bitand(remainder, uint32(1)) ~= 0
                remainder = bitxor(bitshift(remainder, -1), polynomial);
            else
                remainder = bitshift(remainder, -1);
            end
        end

        lookupTable(tableIndex + 1) = remainder;
    end
end

checksum = uint32(hex2dec('FFFFFFFF'));
for byteIndex = 1:numel(bytes)
    tableIndex = double(bitand(bitxor(checksum, uint32(bytes(byteIndex))), uint32(255))) + 1;
    checksum = bitxor(bitshift(checksum, -8), lookupTable(tableIndex));
end

checksum = bitcmp(checksum);
end
