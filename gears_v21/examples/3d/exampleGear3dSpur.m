% EXAMPLEGEAR3DSPUR Display a seven-tooth spur gear with a bore.
%
% Run runMeFirst in the package root, then add examples/3d to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Writes gear3d_spur7.jpg; P writes numbered exampleGear3dSpur snapshots.
% Mouse drag orbits the camera. Clears the Command Window.
% Width=3 and Ri=1 are display quantities in module length units.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

clc
rack = gearRack(1,'alpha',20,'c',0.167);
g = gear(rack,7,'x',0.60,'u',0.75);
g.Ri = 1;                         % Coaxial hole; no change to the tooth profile
s = gear3d(g,'width',3,'np',60);

plot(s,'axes','off','title',false,'view',[135 25], ...
    'figureSize',540, ...
    'export','gear3d_spur7.jpg', ...
    'print','exampleGear3dSpur');

% Optional: inspect the same source from above, without exporting.
% plot(s,'axes','on','view',[0 90],'figureSize',540);
% [vertices,triangles,info] = mesh(s);  % No graphical output
