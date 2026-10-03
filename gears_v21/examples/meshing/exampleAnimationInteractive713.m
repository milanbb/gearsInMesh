% EXAMPLEANIMATIONINTERACTIVE713 Inspect a 7/13 spur pair interactively.
%
% Run runMeFirst in the package root, then add examples/meshing to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures, clears variables and the Command Window.
% L/D step the gears; P writes numbered exampleAnimationInteractive713 JPGs;
% Esc ends the blocking call. Contact markers describe transverse geometry.
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

animate(GM,'mode','interactive', ...
    'figureSize',[1000 700], ...
    'dth1',1,'contactPoints',true, ...
    'title',false,'instructions',true, ...
    'snapshot','exampleAnimationInteractive713');

% In the animation window:
% L / right arrow / left mouse button: forward.
% D / left arrow / right mouse button: backward.
% Esc / middle mouse button / close window: finish this call.
% H: print the instructions again.
% 'nr' is ignored in interactive mode; you can return through old positions.
