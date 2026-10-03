% EXAMPLEGEARRACK2 Inspect a rack, shifted generation and a shortened gear.
%
% Run runMeFirst in the package root, then add examples/rack to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures. Uses m=3, alpha=15.75 degrees and c=0.25.
% Writes a default Fig<number>.jpg for the rack-contact plot. Other
% text/JPG exports are commented out; u is set only on the gear.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

close all

% create gear rack
m = 3; % modulus
alpha = 15 + 45/60; % pressure angle [deg]
c = 0.25; % tip tooth clearance
a = gearRack(m,'-alpha',alpha,'-c',c);

%print rack data
print(a)
%print(a,'rack.txt') % optional numerical text output

%plot rack
plot(a)
%plot(a,'save','rack') % to save figure

% generate gear with 7 teeth and prifil shift 0.2
gearGenerating(a,7,'-x',0.2)
%gearGenerating(a,7,'-x',0.2,'save','generation7') % to save figure

% Shorten only the generated gear; the basic rack a is unchanged.
g = gear(a,7,'x',0,'u',0.7);
plot(g,'gen')

plotRackContactPts(g,'save')