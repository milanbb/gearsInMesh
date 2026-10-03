% RUNMELAST Remove the gears v21 root and classes from the session path.
% Does not change Current Folder, delete objects/files or call savepath.
% Example/verification paths added manually remain; remove them with rmpath.

gearsRoot = fileparts(mfilename('fullpath'));
gearsFolders = {gearsRoot,fullfile(gearsRoot,'classes')}; %, ...
    % fullfile(gearsRoot,'examples'),fullfile(gearsRoot,'examples','rack'), ...
    % fullfile(gearsRoot,'examples','gear'),fullfile(gearsRoot,'examples','meshing'), ...
    % fullfile(gearsRoot,'examples','3d'),fullfile(gearsRoot,'verification')};
for gearsIndex = 1:numel(gearsFolders)
    if any(strcmp(strsplit(path,pathsep),gearsFolders{gearsIndex}))
        rmpath(gearsFolders{gearsIndex});
    end
end
clear gearsRoot gearsFolders gearsIndex
