% EXAMPLEGEAR2 Sample and overlay a retained analytical tooth contour.
%
% Run runMeFirst in the package root, then add examples/gear to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Uses Heun with np=30. Commented alternatives show Euler sampling and
% tab-delimited planar XYZ export. No files are written by default.
% np controls density, not the exact total vertex count.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.

g = gear(gearRack(1),13,'x',0.30,'u',0.85);
[X,Y,info] = gearContour(g,'np',30,'sampling','heun');
plot(g,'title',false)
hold on
scatter(X,Y,8,'filled')
% Optional alternative sampling and coordinate export:
% [X,Y,info] = gearContour(g,'np',30,'sampling','euler');
% gearContour(g,'np',30,'sampling','heun','file','contour13.txt');
