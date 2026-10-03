% RUNMEFIRST Add the gears v21 root and classes to the session path.
% Run from the package root. Current Folder is not changed.
% Example, doc and verification folders are not added. Add a chosen example
% or verification folder explicitly before calling its scripts by name.
% Does not run examples/tests, create output folders, or call savepath.
% Do not add private folders. See README.md for setup and cleanup.

gearsRoot = fileparts(mfilename('fullpath'));
gearsFolders = {gearsRoot,fullfile(gearsRoot,'classes')}; %, ...
    % fullfile(gearsRoot,'examples'),fullfile(gearsRoot,'examples','rack'), ...
    % fullfile(gearsRoot,'examples','gear'),fullfile(gearsRoot,'examples','meshing'), ...
    % fullfile(gearsRoot,'examples','3d'),fullfile(gearsRoot,'verification')};
for gearsIndex = numel(gearsFolders):-1:1
    if ~any(strcmp(strsplit(path,pathsep),gearsFolders{gearsIndex}))
        addpath(gearsFolders{gearsIndex},'-begin');
    end
end
clear gearsRoot gearsFolders gearsIndex
