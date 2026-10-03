% EXAMPLEGEAROUTPUTOPTIONS Demonstrate plot controls, contacts and overlays.
%
% Run runMeFirst in the package root, then add examples/gear to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Writes figures/gear.jpg, envelope.jpg, contact.jpg, normal.jpg,
% tangent.jpg and force.jpg under the same figures subfolder.
% Demonstrates title, line properties, normals, tangents and unit-force arrows.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

classFolder = fileparts(which('gear'));
if isempty(classFolder)
    error('gears:Setup','Run runMeFirst from the intended package first.');
end
for helper = {'gearArcLengthSample','gearProfileIntersection'}
    found = isfile(fullfile(classFolder,'private',[helper{1} '.m'])) ...
        || isfile(fullfile(classFolder,[helper{1} '.m'])) ...
        || ~isempty(which(helper{1}));
    if ~found
        error('gears:MissingNumericalHelper', ...
            'Original numerical helper %s.m is required; it should be in classes/private in this package.',helper{1});
    end
end

% Optional relative output subfolder under MATLAB Current Folder.
figFolder = 'figures';
g = gear(gearRack(1),30,'sampling','heun');
plot(g,'nz',3,'title',false,'save',fullfile(figFolder,'gear'));
plot(g,'gen','title','off','save',fullfile(figFolder,'envelope'), ...
    'LineWidth',2);
plotRackContactPts(g,'title',0,'save',fullfile(figFolder,'contact'));

% An overlay does not clear the existing profile.
plot(g,'nz',3,'title',true);
plotNormal(g,0.5,-1,1,'title',false,'LineWidth',2, ...
    'save',fullfile(figFolder,'normal'));
plotTangent(g,0.5,-1,1,'title',false,'save',fullfile(figFolder,'tangent'));
plotForce(g,0.5,1,'title',false,'save',fullfile(figFolder,'force'));

% Legacy save syntax remains valid. The default name uses this figure number.
% plot(g,'title',false,'save',[]);
% plot(g,'notxt','save');
