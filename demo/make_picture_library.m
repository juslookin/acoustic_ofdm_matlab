function names = make_picture_library()
%MAKE_PICTURE_LIBRARY Draw the 64x64 test pictures into images/.
% All pictures are generated here from simple geometry, so they are
% reproducible and free of copyright. Also writes images/gallery.png.
settings = startup_project();
n = settings.imageSize(1);
[x, y] = meshgrid(linspace(-1, 1, n));
pictures = struct();

% Smiley: light face on a dark background.
face = 0.15 * ones(n);
face(x.^2 + y.^2 < 0.85^2) = 0.85;
face((x + 0.32).^2 + (y + 0.25).^2 < 0.11^2) = 0.1;
face((x - 0.32).^2 + (y + 0.25).^2 < 0.11^2) = 0.1;
smile = abs(sqrt(x.^2 + (y + 0.05).^2) - 0.5) < 0.07 & y > 0.12;
face(smile) = 0.1;
pictures.smiley = face;

% Heart: implicit curve (x^2 + y^2 - 1)^3 - x^2 y^3 <= 0, with soft shading.
hx = 1.35 * x;
hy = -1.35 * y + 0.25;
inside = (hx.^2 + hy.^2 - 1).^3 - hx.^2 .* hy.^3 <= 0;
heart = 0.95 - 0.25 * (y + 1) / 2;
heart(inside) = 0.25 + 0.35 * (x(inside) + 1) / 2;
pictures.heart = heart;

% OFDM: block letters from a 5x7 font, scaled 3x.
font.O = [0 1 1 1 0; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 0 1 1 1 0];
font.F = [1 1 1 1 1; 1 0 0 0 0; 1 0 0 0 0; 1 1 1 1 0; 1 0 0 0 0; 1 0 0 0 0; 1 0 0 0 0];
font.D = [1 1 1 1 0; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 1 1 1 0];
font.M = [1 0 0 0 1; 1 1 0 1 1; 1 0 1 0 1; 1 0 1 0 1; 1 0 0 0 1; 1 0 0 0 1; 1 0 0 0 1];
text = 0.92 * ones(n);
letters = 'OFDM';
top = round((n - 21) / 2) + 1;
for k = 1:numel(letters)
    glyph = kron(font.(letters(k)), ones(3));
    left = 1 + (k - 1) * 16;
    block = text(top:top + 20, left:left + 14);
    block(glyph == 1) = 0.08;
    text(top:top + 20, left:left + 14) = block;
end
text(top + 25:top + 26, 2:63) = 0.5; % underline
pictures.ofdm = text;

% Landscape: sky gradient, sun, two mountain ranges, ground.
land = 0.75 - 0.35 * (y + 1) / 2;
land((x - 0.45).^2 + (y + 0.5).^2 < 0.18^2) = 1;
land(y > 0.1 + 0.35 * abs(sin(2.2 * x + 0.6))) = 0.45;
land(y > 0.35 + 0.2 * abs(sin(3.5 * x - 0.4))) = 0.28;
land(y > 0.75) = 0.15;
pictures.landscape = land;

names = fieldnames(pictures);
tiles = {make_demo_image(settings)};
for k = 1:numel(names)
    picture = uint8(round(255 * min(max(pictures.(names{k}), 0), 1)));
    imwrite(picture, fullfile(settings.paths.images, [names{k}, '.png']));
    tiles{end + 1} = picture; %#ok<AGROW>
end
% Gallery strip (checkerboard first), upscaled 4x with white gaps.
gap = 255 * ones(4 * n, 16, 'uint8');
strip = [];
for k = 1:numel(tiles)
    strip = [strip, kron(tiles{k}, ones(4, 'uint8'))]; %#ok<AGROW>
    if k < numel(tiles)
        strip = [strip, gap]; %#ok<AGROW>
    end
end
imwrite(strip, fullfile(settings.paths.images, 'gallery.png'));
names = [{'checkerboard'}; names];
fprintf('Wrote %d pictures and images/gallery.png\n', numel(names) - 1);
end
