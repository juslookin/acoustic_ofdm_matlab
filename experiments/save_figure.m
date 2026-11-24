function save_figure(figureHandle, fileStem, settings)
%SAVE_FIGURE Save an editable MATLAB figure and a shareable PNG.
% Inputs: graphics figure handle, text stem, settings. Output: files on disk.
% Set a per-figure theme so printed plots do not inherit desktop dark mode.
% R2024a has a Theme property but no theme() function (added in R2025a).
if isprop(figureHandle, 'Theme') && exist('theme', 'file')
    theme(figureHandle, 'light');
end
exportgraphics(figureHandle, fullfile(settings.paths.figures, [fileStem, '.png']), 'Resolution', 160);
savefig(figureHandle, fullfile(settings.paths.figures, [fileStem, '.fig']));
close(figureHandle);
end
