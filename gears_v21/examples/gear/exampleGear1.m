% EXAMPLEGEAR1 Inspect generation, profile shift, shortening and force overlays.
%
% Run runMeFirst in the package root, then add examples/gear to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures. Writes default rack/envelope JPGs and force.jpg.
% Updates x and u on a single gear, then queries the retained involute.
% Force overlays use a signed unit arrow length; no load analysis is performed.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.
% Use the Command Window for export; Live Editor export is not reliable.

 close all
 
a = gear(gearRack(1),8,'-x',0,'-beta',0);
% plot rack
plot(a.rack,'save')
% plot gear formation
gearGenerating(a.rack,8)
% print data
print(a)
%plot gear generation
plot(a,'gen','save')
% plot gaer using 4 teeth
plot(a,'-nz',4)
% add force to top,midle and bottom of the involute
plotForce(a, 0,1,'r','save','force')
plotForce(a,0.5,1,'r')
plotForce(a, 1,1,'b')

% set profile shift to aviod undercutting
a.x = a.xmin;
print(a)
plot(a,'gen')
plot(a,'-nz',4)
plotForce(a,0.5,1,'r')

% set tip shortening coefficient to avoid pointed teeth
a.u = 0.7;
print(a)
plot(a,'gen')
plot(a,'-nz',4)

% get some data about tooth at radius in middle of top and base
getData(a,getPar(a,0.5*(a.Ra+a.Rb)))

