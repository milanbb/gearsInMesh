% EXAMPLEPLOTTITLESAVE Export pair figures and an automatic animation.
%
% Run runMeFirst in the package root, then add examples/meshing to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures. Writes rack.jpg, gear18.jpg, pair1830.jpg, generation.jpg,
% a default Fig<number>.jpg and pair1830.avi. P also saves numbered snapshots.
% Includes a preview animation followed by a separate recording call.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

close all
rack = gearRack(1);
G1 = gear(rack,18);
G2 = gear(rack,30);
GM = gearsInMesh(G1,G2);

% Default and explicitly named JPGs. Output directories are created if needed.
plot(rack,'title','off','save','rack.jpg')
plot(G1,'title',false,'save','gear18.jpg')
plot(GM,'title',0,'save','pair1830.jpg')
plot(GM,'save',[])  % default Fig<number>.jpg in Current Folder

% Also works for the generating-rack display and gear envelope.
gearGenerating(rack,18,'title',false,'save','generation')
plot(G1,'gen','title',false)

% Preview only (Esc or close the window to stop).
animate(GM,'nr',0.1,'dth1',1,'title',false, ...
    'snapshot','examplePlotTitleSave')

% Save AVI to a chosen path; fps controls the stored playback frame rate.
animate(GM,'nr',0.1,'dth1',1,'title',false,'fps',30, ...
    'save','pair1830.avi', ...
    'snapshot','examplePlotTitleSave')

% Default AVI filename:
% animate(GM,'nr',0.1,'title',false,'save',[])
% Manual stepping (right/up/left click forwards; left/down/right click back):
% animate(GM,'step',true,'title',false)
