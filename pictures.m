classdef pictures
    methods (Static)

        function image = load(name, settings)
            if nargin < 1 || isempty(name) || strcmpi(name, 'checkerboard')
                image = pictures.checkerboard(settings);
                return;
            end

            file = fullfile(settings.paths.images, [name, '.png']);
            if isfile(name)
                file = name;
            end
            assert(isfile(file), 'No picture called "%s".', name);

            pixels = double(imread(file));
            if size(pixels, 3) >= 3
                pixels = 0.299 * pixels(:, :, 1) + 0.587 * pixels(:, :, 2) + 0.114 * pixels(:, :, 3);
            end

            rows = round(linspace(1, size(pixels, 1), settings.imageSize(1)));
            cols = round(linspace(1, size(pixels, 2), settings.imageSize(2)));
            image = uint8(pixels(rows, cols));
        end

        function image = checkerboard(settings)
            [x, y] = meshgrid(linspace(0, 1, settings.imageSize(2)), linspace(0, 1, settings.imageSize(1)));
            pattern = 0.5 * x + 0.25 * y + 0.25 * (sin(6 * pi * x) .* cos(4 * pi * y) > 0);
            image = uint8(round(255 * pattern));
        end

        function makeLibrary()
            settings = config();
            n = settings.imageSize(1);
            [x, y] = meshgrid(linspace(-1, 1, n));

            % smiley
            face = 0.15 * ones(n);
            face(x.^2 + y.^2 < 0.85^2) = 0.85;
            face((x + 0.32).^2 + (y + 0.25).^2 < 0.11^2) = 0.1;
            face((x - 0.32).^2 + (y + 0.25).^2 < 0.11^2) = 0.1;
            face(abs(sqrt(x.^2 + (y + 0.05).^2) - 0.5) < 0.07 & y > 0.12) = 0.1;
            drawn.smiley = face;

            % heart
            hx = 1.35 * x;
            hy = -1.35 * y + 0.25;
            inside = (hx.^2 + hy.^2 - 1).^3 - hx.^2 .* hy.^3 <= 0;
            heart = 0.95 - 0.25 * (y + 1) / 2;
            heart(inside) = 0.25 + 0.35 * (x(inside) + 1) / 2;
            drawn.heart = heart;

            % text
            font.O = [0 1 1 1 0; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 0 1 1 1 0];
            font.F = [1 1 1 1 1; 1 0 0 0 0; 1 0 0 0 0; 1 1 1 1 0; 1 0 0 0 0; 1 0 0 0 0; 1 0 0 0 0];
            font.D = [1 1 1 1 0; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 1 1 1 0];
            font.M = [1 0 0 0 1; 1 1 0 1 1; 1 0 1 0 1; 1 0 1 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1];

            text = 0.92 * ones(n);
            top = round((n - 21) / 2) + 1;
            letters = 'OFDM';
            for k = 1:4
                left = 1 + (k - 1) * 16;
                block = text(top:top + 20, left:left + 14);
                block(kron(font.(letters(k)), ones(3)) == 1) = 0.08;
                text(top:top + 20, left:left + 14) = block;
            end
            text(top + 25:top + 26, 2:63) = 0.5;
            drawn.ofdm = text;

            % landscape
            land = 0.75 - 0.35 * (y + 1) / 2;
            land((x - 0.45).^2 + (y + 0.5).^2 < 0.18^2) = 1;
            land(y > 0.1 + 0.35 * abs(sin(2.2 * x + 0.6))) = 0.45;
            land(y > 0.35 + 0.2 * abs(sin(3.5 * x - 0.4))) = 0.28;
            land(y > 0.75) = 0.15;
            drawn.landscape = land;

            names = fieldnames(drawn);
            strip = kron(pictures.checkerboard(settings), ones(4, 'uint8'));
            gap = 255 * ones(4 * n, 16, 'uint8');

            for k = 1:numel(names)
                image = uint8(round(255 * min(max(drawn.(names{k}), 0), 1)));
                imwrite(image, fullfile(settings.paths.images, [names{k}, '.png']));
                strip = [strip, gap, kron(image, ones(4, 'uint8'))]; %#ok<AGROW>
            end

            imwrite(strip, fullfile(settings.paths.images, 'gallery.png'));
        end

    end
end
