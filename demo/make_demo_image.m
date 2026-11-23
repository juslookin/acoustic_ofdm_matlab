function imageBytes = make_demo_image(settings)
%MAKE_DEMO_IMAGE Deterministic grayscale pattern; no Image Processing Toolbox.
% Input: settings.imageSize [rows,columns]. Output: uint8 [rows x columns].
[columns, rows] = meshgrid(linspace(0, 1, settings.imageSize(2)), linspace(0, 1, settings.imageSize(1)));
pattern = 0.5 * columns + 0.25 * rows + 0.25 * (sin(6 * pi * columns) .* cos(4 * pi * rows) > 0);
imageBytes = uint8(round(255 * pattern));
end
