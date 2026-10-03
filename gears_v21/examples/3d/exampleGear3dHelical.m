% EXAMPLEGEAR3DHELICAL Display a 13-tooth helical gear and inspect its mesh.
%
% Run runMeFirst in the package root, then add examples/3d to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Uses beta=25 degrees, width=4 and Ri=2 in module length units.
% Writes gear3d_helical13.jpg and prints surface-mesh data. P writes numbered
% exampleGear3dHelical snapshots. Clears the Command Window.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

clc
rack = gearRack(1,'alpha',20,'c',0.167);
g = gear(rack,13,'beta',25,'x',0.30,'u',0.85);
g.Ri = 2;
s = gear3d(g,'width',4,'np',60,'nLayers',41);

plot(s,'axes','off','view',[135 25],'figureSize',540, ...
    'export','gear3d_helical13.jpg', ...
    'print','exampleGear3dHelical');

% Keep transverse profile resolution and axial sweep resolution separate.
[V,F,info] = mesh(s);
fprintf('Width: %g; reference radius: %g; beta: %g deg\n', ...
    info.width,info.pitchRadius,info.beta);
fprintf('Total section rotation (Supplement sign): %.6f deg\n', ...
    info.sectionRotation*180/pi);
fprintf('Closed surface: %d; vertices: %d; triangles: %d\n', ...
    info.topology.closed,size(V,1),size(F,1));

% Optional coloured triangulation edges, using the same geometry:
% plot(s,'axes',true,'edgeColor',[0.25 0.25 0.25],'view',[135 25]);
