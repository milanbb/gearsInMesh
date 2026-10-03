% GEARS v21 - External involute gear geometry, meshing and visualisation.
% Author: Milan Batista.
%
% Setup:
%   runMeFirst       Add only the package root and classes to the session path.
%   runMeLast        Remove those two entries; manually added paths remain.
%   README.md        Installation, quick start, requirements and outputs.
%
% Public classes:
%   gearRack         Normal rack; read-only m, alpha and c.
%   gear             Profile construction; independent x, u and tip ratio q.
%   gearsInMesh      Pair geometry, 2-D plotting and meshing animation.
%   gear3d           3-D views, surface mesh data and animation.
%
% Documentation and examples:
%   doc/             Three Live Scripts; see doc/README.md.
%   examples/rack/   Rack displays and rack-value-semantics check.
%   examples/gear/   Profiles, contour sampling/export and overlays.
%   examples/meshing/   Pair display, animation and graphics export.
%   examples/meshing/article/   exampleGearsInMeshArticle (8/39 helical pair).
%   examples/3d/     Spur/helical meshes, pair views and animation.
%   verification/   runVerification and five literature comparisons.
%   verification/tests/   testDIN3966Verification reporting checks.
%
% Add a chosen example folder before calling scripts by name. Run
% runVerification from verification after runMeFirst. Relative outputs use
% Current Folder; named files overwrite.
% Profile sampling: Heun by default, Euler optional. Intersections use licensed
% fsolve when available, otherwise bundled nsolve. See doc/THIRD_PARTY_NOTICES.txt.
% Internal helpers in private folders are not public commands or path entries.
