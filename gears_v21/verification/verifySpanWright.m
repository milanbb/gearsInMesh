% VERIFYSPANWRIGHT Published tooth-span example (not a strength check).
% Run runMeFirst in the package root, then execute this script from
% verification. Results remain in the caller workspace; exportResults=false
% by default. Optional CSV output uses Current Folder.
% Douglas Wright, DANotes, Spur gears / Gear tooth generation, EXAMPLE.
% https://www-mdp.eng.cam.ac.uk/web/library/enginfo/textbooks_dvd_only/DAN/gears/generation/generation.html
% Published data: z=13, m=8 mm, alpha=20 deg, profile shift=0.30,
% span across 2 teeth=38.52 mm and across 3 teeth=62.14 mm.
% Source spans have two decimal places: 0.005 mm rounding tolerance.
% The rack fillet is irrelevant to these theoretical involute span values;
% this check does not assert that a measuring tool fits every tooth gap.
exportResults = false;
assert(~isempty(which('gear')),'Run runMeFirst before this comparison.');
rack = gearRack(8,'alpha',20,'c',0.25);
g = gear(rack,13,'x',0.30,'u',1);
pb = 2*pi*g.Rb/g.z;
Quantity = {'Pitch diameter [mm]'; 'Span over 2 teeth [mm]'; 'Span over 3 teeth [mm]'};
Reference = [104;38.52;62.14];
Computed = [2*g.Rr; g.sb+pb; g.sb+2*pb];
Tolerance = [1e-9;0.005;0.005];
AbsoluteError = abs(Computed-Reference);
Pass = isfinite(Computed) & AbsoluteError<=Tolerance;
verificationTable = table(Quantity,Reference,Computed,AbsoluteError,Tolerance,Pass);
fprintf('\nWright: published 13-tooth inspection example\n');
disp(verificationTable);
if exportResults, writetable(verificationTable,'verification_wright_span.csv'); end
assert(all(Pass),'verification:Mismatch','Wright span comparison did not pass.');
