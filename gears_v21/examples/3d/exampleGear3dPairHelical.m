% EXAMPLEGEAR3DPAIRHELICAL Display a 7/13 helical pair with independent widths.
%
% Run runMeFirst in the package root, then add examples/3d to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Both input beta values are 25 degrees. gear3d displays opposite hands
% without changing the source gears. Writes gear3d_pair713_helical.jpg and
% prints mesh diagnostics. P writes numbered snapshots. Clears the Command
% Window. The widths and bore radii are display quantities.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

clc
rack = gearRack(1,'alpha',20,'c',0.167);
G1 = gear(rack,7, 'beta',25,'x',0.60,'u',0.75);
G2 = gear(rack,13,'beta',25,'x',0.25,'u',0.80);
G1.Ri = 1;
G2.Ri = 2;
GM = gearsInMesh(G1,G2);
S = gear3d(GM,'width',[3 4],'np',60,'nLayers',41);
plot(S,'th1',10,'axes',false,'view',[135 25], ...
    'figureSize',540,'title',false, ...
    'color1',[0.40 0.65 0.90],'color2',[0.95 0.65 0.35], ...
    'export','gear3d_pair713_helical.jpg', ...
    'print','exampleGear3dPairHelical');
[~,~,info] = mesh(S,'th1',10);
fprintf('Source beta: %g / %g; assembled beta: %g / %g deg\n', ...
    info.sourceBeta(1),info.sourceBeta(2), ...
    info.effectiveBeta(1),info.effectiveBeta(2));
fprintf('Gear rotations: th1 = %g; th2 = %g deg\n',info.th1,info.th2);
% Both front faces have Z=0; width=[b1 b2] does not recenter the teeth.
% [fh,ax,h] = plot(S,'view',[120 30],'axes',true);  % returned patch handles
