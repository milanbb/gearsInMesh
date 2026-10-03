% VERIFYPAIRGLINSKY Zero-backlash distance versus a published helical pair.
% Run runMeFirst in the package root, then execute this script from
% verification. Results remain in the caller workspace; exportResults=false
% by default. Optional CSV output uses Current Folder.
% Chad Glinsky, Geometry / Helical Gears, Example | Helical Gear Mesh.
% https://drivetrainhub.com/notebooks/gears/geometry/Chapter%203%20-%20Helical%20Gears.html
% Published inputs: m_n=1, alpha_n=20 deg, beta=15 deg, z=17/35, x=0.2/-0.1.
% Published a0=26.917181 and theoretical zero-backlash aj0=27.015921 mm.
% IMPORTANT: the source's ACTUAL assembly uses a=27.5 mm and backlash.
% gearsInMesh instead computes aj0. We compare GM.a ONLY with source aj0;
% its printed contact ratio at 27.5 is not a target for this object's GM.
% Remaining rows use independent evaluation of the cited zero-backlash and
% nominal contact formulas at aj0; they are NOT published table numbers.
exportResults = false;
assert(~isempty(which('gearsInMesh')),'Run runMeFirst before this comparison.');
m = 1; alpha = 20*pi/180; beta = 15*pi/180;
z = [17 35]; x = [0.2 -0.1];
rack = gearRack(m,'alpha',20,'c',0.25);
g1 = gear(rack,z(1),'beta',15,'x',x(1),'u',1);
g2 = gear(rack,z(2),'beta',15,'x',x(2),'u',1);
GM = gearsInMesh(g1,g2);
% Reference evaluation is not read from GM or its workingPressureAngle helper.
at = atan(tan(alpha)/cos(beta));
target = tan(at)-at+2*tan(alpha)*sum(x)/sum(z);
lo = 0; hi = pi/2-1e-8;
for k = 1:100
    mid = (lo+hi)/2;
    if tan(mid)-mid<target, lo=mid; else, hi=mid; end
end
aw = (lo+hi)/2;
rp = m*z/(2*cos(beta)); rb = rp*cos(at); ra=rp+m*(1+x);
aRef = sum(rb)/cos(aw);
LcRef = sum(sqrt(ra.^2-rb.^2))-aRef*sin(aw);
ratioRef = LcRef/(2*pi*rb(1)/z(1));
Quantity = {'Reference centre distance [mm]';'Zero-backlash centre distance [mm]'; ...
    'Working pressure angle [deg]';'Nominal contact length [mm]'; ...
    'Nominal transverse contact ratio'};
ReferenceKind = {'published';'published';'formula evaluation'; ...
    'formula evaluation';'formula evaluation'};
Reference = [26.917181;27.015921;aw*180/pi;LcRef;ratioRef];
Computed = [g1.Rr+g2.Rr;GM.a;GM.alphaw;GM.Lc;GM.epsalpha];
Tolerance = [5.1e-7;5.1e-7;1e-8;1e-8;1e-8];
AbsoluteError = abs(Computed-Reference);
Pass = isfinite(Computed) & AbsoluteError<=Tolerance;
verificationTable = table(Quantity,ReferenceKind,Reference,Computed,AbsoluteError,Tolerance,Pass);
fprintf('\nGlinsky 17/35: compare theoretical aj0, NOT the assembly at 27.5 mm\n');
disp(verificationTable);
if exportResults, writetable(verificationTable,'verification_glinsky_pair.csv'); end
assert(all(Pass),'verification:Mismatch','Pair comparison did not pass.');
