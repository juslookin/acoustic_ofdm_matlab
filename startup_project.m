function settings = startup_project()
projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
settings = config();

directoryNames = fieldnames(settings.paths);
for directoryIndex = 1:numel(directoryNames)
    directoryPath = settings.paths.(directoryNames{directoryIndex});
    if ~isfolder(directoryPath)
        mkdir(directoryPath);
    end
end
end
