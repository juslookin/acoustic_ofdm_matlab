function save_figure(figureHandle, fileStem, settings)
%SAVE_FIGURE Save an editable MATLAB figure and a shareable PNG.
% Inputs: graphics figure handle, text stem, settings. Output: files on disk.
% Set a per-figure theme so printed plots do not inherit desktop dark mode.
if isprop(figureHandle, 'Theme')
    theme(figureHandle, 'light');
end
exportgraphics(figureHandle, fullfile(settings.paths.figures, [fileStem, '.png']), 'Resolution', 160);
savefig(figureHandle, fullfile(settings.paths.figures, [fileStem, '.fig']));
close(figureHandle);
end
