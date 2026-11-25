function save_figure(figureHandle, fileStem, settings)
if isprop(figureHandle, 'Theme') && exist('theme', 'file')
    theme(figureHandle, 'light');
end

exportgraphics(figureHandle, fullfile(settings.paths.figures, [fileStem, '.png']), 'Resolution', 160);
savefig(figureHandle, fullfile(settings.paths.figures, [fileStem, '.fig']));
close(figureHandle);
end
