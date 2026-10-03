% EXAMPLEGEAR3DANIMATION Animate a 7/36 helical pair in 3-D.
%
% Run runMeFirst in the package root, then add examples/3d to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Set mode to automatic or interactive; L/D step, Space pauses automatic
% playback, Esc ends the call. Mouse drag orbits the camera. P writes numbered
% pair3d snapshots. No AVI is written unless the commented save option is used.
% Closes existing figures. Width and bore radius are display quantities.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

close all
rack=gearRack(1);
G1=gear(rack,7,'beta',25);
G2=gear(rack,36,'beta',25);
GM=gearsInMesh(G1,G2);
S=gear3d(GM,'width',10,'np',30,'nLayers',21,...
    'figureSize',540,'title',true,...
    'color1',[0.40 0.65 0.90],'color2',[0.95 0.65 0.35]);
mode = 'automatic'; % set to 'interactive' for L/D stepping and P snapshots
animate(S,'mode',mode,'nr',0.3,'dth1',2,'fps',30,...
    'print','pair3d','view',[135 25]);
% Space pauses/resumes; mouse drag orbits the camera; P saves a JPG; Esc stops.
% To create a video, include 'save','pair3d.avi' in the animate call.
% 'save',[] chooses gear3d.avi. Camera changes during recording appear in AVI.
