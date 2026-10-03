% EXAMPLEGEARSINMESHARTICLE Modify and display an 8/39 helical pair.
%
% Run runMeFirst in the package root, then add examples/meshing/article to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures, clears the workspace and Command Window. Uses m=3 and
% beta=20 degrees. Sets G1.x=G1.xmin, G2.x=-G1.x and G1.u=G1.umax,
% then displays a 3-D pair. Writes example1.jpg through example4.jpg.
% Width and Ri are used for display only. No manuscript or PDF is required.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

close all
clear all
clc

% Define pair
m = 3; z1=8; z2=39; beta=20; 
width = 50; Ri = 45; % for plot only
rack = gearRack(m,'alpha',20,'c',0.167);
G1 = gear(rack,z1,'beta',beta);
G2 = gear(rack,z2,'beta',beta,'Ri',Ri);
GM = gearsInMesh(G1,G2);
print(GM)
plot(GM,'th1',30,'title',true,'lineWidth',1.5,'zoom',4,'save','example1')

% Remove undercut
G1.x = G1.xmin;
G2.x =-G1.x;
print(GM)
plot(GM,'th1',30,'title',true,'lineWidth',1.5,'zoom',4,'save','example2')

% Shorten gear1 head
G1.u=G1.umax;
print(GM)
plot(GM,'th1',30,'title',true,'lineWidth',1.5,'zoom',5,'save','example3')

% Create a three-dimensional visualization of the meshing gears.
plot(gear3d(GM,'width',width),'save','example4')
