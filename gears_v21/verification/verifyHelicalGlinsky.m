% VERIFYHELICALGLINSKY Selected published transverse dimensions of one gear.
% Run runMeFirst in the package root, then execute this script from
% verification. Results remain in the caller workspace; exportResults=false
% by default. Optional CSV output uses Current Folder.
% Chad Glinsky, Geometry / Helical Gears, Example | Helical Gear Geometry.
% https://drivetrainhub.com/notebooks/gears/geometry/Chapter%203%20-%20Helical%20Gears.html
% m_n=1 mm, alpha_n=20 deg, beta=15 deg, z=17, x=0.2, ha*=1, hf*=1.25.
% We compare only published transverse dimensions/thicknesses and base pitch.
% The source specifies an independent tool-radius coefficient 0.38. This
% package ties radius to clearance: c/(1-sin(alpha))=0.37995..., not exactly
% 0.38. Root-form geometry is therefore NOT part of this numerical benchmark.
% Rounded six-decimal values allow 5e-7 plus 1e-8 floating-point allowance.
exportResults = false;
assert(~isempty(which('gear')),'Run runMeFirst before this comparison.');
rack = gearRack(1,'alpha',20,'c',0.25);
g = gear(rack,17,'beta',15,'x',0.2,'u',1);
Quantity = {'Reference diameter [mm]';'Base diameter [mm]'; ...
    'Tip diameter [mm]';'Root diameter [mm]'; ...
    'Reference transverse tooth thickness [mm]'; ...
    'Transverse tip thickness [mm]';'Transverse base pitch [mm]'};
Reference = [17.599695;16.469288;19.999695;15.499695; ...
    1.776932;0.634641;3.043517];
Computed = [2*g.Rr;2*g.Rb;2*g.Ra;2*g.Rd;g.sr;g.sa;2*pi*g.Rb/g.z];
Tolerance = repmat(5.1e-7,numel(Reference),1);
AbsoluteError = abs(Computed-Reference);
Pass = isfinite(Computed) & AbsoluteError<=Tolerance;
verificationTable = table(Quantity,Reference,Computed,AbsoluteError,Tolerance,Pass);
fprintf('\nGlinsky: published 17-tooth helical gear (selected transverse data)\n');
disp(verificationTable);
if exportResults, writetable(verificationTable,'verification_glinsky_helical.csv'); end
assert(all(Pass),'verification:Mismatch','Helical dimension comparison did not pass.');
