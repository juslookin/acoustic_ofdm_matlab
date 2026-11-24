function imageBytes = load_picture(name, settings)
%LOAD_PICTURE Picture to send, as uint8 grayscale of size settings.imageSize.
% name: 'checkerboard' (the original built-in pattern) or the name of a PNG
% in images/ (e.g. 'smiley'), or a path to any image file. Colour images
% are converted to gray and resized by nearest neighbour (base MATLAB only).
if nargin < 1 || isempty(name) || strcmpi(name, 'checkerboard')
    imageBytes = make_demo_image(settings);
    return;
end
if isfile(name)
    filePath = name;
else
    filePath = fullfile(settings.paths.images, [name, '.png']);
end
assert(isfile(filePath), 'No picture called "%s". Available: %s', name, strjoin(list_pictures(settings), ', '));
pixels = double(imread(filePath));
if size(pixels, 3) >= 3
    pixels = 0.299 * pixels(:, :, 1) + 0.587 * pixels(:, :, 2) + 0.114 * pixels(:, :, 3);
end
rowIndex = round(linspace(1, size(pixels, 1), settings.imageSize(1)));
columnIndex = round(linspace(1, size(pixels, 2), settings.imageSize(2)));
imageBytes = uint8(pixels(rowIndex, columnIndex));
end

function names = list_pictures(settings)
files = dir(fullfile(settings.paths.images, '*.png'));
names = [{'checkerboard'}, erase({files.name}, '.png')];
names = names(~strcmp(names, 'gallery'));
end
