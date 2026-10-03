% EXAMPLEANIMATIONAUTOMATIC713 Animate a 7/13 spur pair with contact markers.
%
% Run runMeFirst in the package root, then add examples/meshing to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures, clears variables and the Command Window.
% Automatic playback covers 0.3 turns; Space pauses and Esc ends the call.
% P writes numbered exampleAnimationAutomatic713 snapshots.
% No AVI is written unless the commented video-export call is enabled.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

close all
clearvars
clc
rack = gearRack(1,'alpha',20,'c',0.167);
G1 = gear(rack,7, 'x',0.60,'u',0.80);
G2 = gear(rack,13,'x',0.25,'u',0.85);
GM = gearsInMesh(G1,G2);

% Preview: starts immediately; final gear-1 angle is exactly 108 degrees.
animate(GM,'mode','automatic','nr',0.3,'dth1',1,'fps',30, ...
    'figureSize',[1000 700],'contactPoints',true, ...
    'title',false,'instructions',true, ...
    'snapshot','exampleAnimationAutomatic713');

% Video export (uncomment to run):
% animate(GM,'mode','automatic','nr',0.3,'dth1',1,'fps',30, ...
%     'figureSize',[1000 700],'contactPoints',true,'title',false, ...
%     'save','pair713');
% Use 'save',[] for the default filename gearsInMesh.avi.
