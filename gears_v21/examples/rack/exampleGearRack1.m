% EXAMPLEGEARRACK1 Print and plot a normal rack and generating positions.
%
% Run runMeFirst in the package root, then add examples/rack to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures. Uses module 3 and the default pressure angle/clearance.
% Displays a static sequence of rack positions for seven teeth.
% No files are written; a text-export call is commented out.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

close all

% create gear rack
m = 3; % modulus
a = gearRack(m);

%print rack data
print(a)
%print(a,'rack.txt') % optional numerical text output

%plot rack
plot(a)

% generate gear with 7 teeth
gearGenerating(a,7)