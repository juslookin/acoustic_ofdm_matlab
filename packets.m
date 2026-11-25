classdef packets
    methods (Static)

        function bits = make(payload)
            checksum = packets.crc32(payload);
            checksumBytes = zeros(4, 1, 'uint8');

            for k = 1:4
                checksumBytes(k) = uint8(bitand(bitshift(checksum, -8 * (4 - k)), uint32(255)));
            end

            bits = packets.toBits([uint8(payload(:)); checksumBytes]);
        end

        function [passed, payload] = check(bits)
            bytes = packets.toBytes(bits);
            payload = bytes(1:end-4);
            passed = isequal(logical(bits(:)), packets.make(payload));
        end

        function checksum = crc32(bytes)
            persistent table
            if isempty(table)
                table = zeros(256, 1, 'uint32');
                polynomial = uint32(hex2dec('EDB88320'));

                for index = 0:255
                    remainder = uint32(index);
                    for bit = 1:8
                        if bitand(remainder, uint32(1))
                            remainder = bitxor(bitshift(remainder, -1), polynomial);
                        else
                            remainder = bitshift(remainder, -1);
                        end
                    end
                    table(index + 1) = remainder;
                end
            end

            checksum = uint32(hex2dec('FFFFFFFF'));
            for k = 1:numel(bytes)
                index = double(bitand(bitxor(checksum, uint32(bytes(k))), uint32(255))) + 1;
                checksum = bitxor(bitshift(checksum, -8), table(index));
            end
            checksum = bitcmp(checksum);
        end

        function bits = toBits(bytes)
            bytes = uint8(bytes(:));
            bits = false(8, numel(bytes));

            for k = 1:8
                bits(k, :) = bitget(bytes, 9 - k) ~= 0;
            end
            bits = bits(:);
        end

        function bytes = toBytes(bits)
            groups = reshape(double(bits(:)), 8, []).';
            bytes = uint8(groups * (2.^(7:-1:0)).');
        end

    end
end
