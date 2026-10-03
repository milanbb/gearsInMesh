% EXAMPLEGEARSINMESH Construct and inspect a 7/13 spur-gear pair.
%
% Run runMeFirst in the package root, then add examples/meshing to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures, prints pair data and plots the geometry. No files are written.
% Demonstrates independent x/u values, th1, title and line properties.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

close all
rack = gearRack(1,'alpha',20,'c',0.167);
G1 = gear(rack,7,'x',0.60,'u',0.80);
G2 = gear(rack,13,'x',0.25,'u',0.85);
GM = gearsInMesh(G1,G2);
print(GM)
plot(GM,'th1',30,'title',false,'lineWidth',1.5)
% Optional close-up of the same pair:
% plot(GM,'th1',30,'zoom',3,'title',true);
% Change gear 1 only; gear 2 retains its u:
% G1.u = 0.75; GM = gearsInMesh(G1,G2); plot(GM);
