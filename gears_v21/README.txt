gears v21 — External involute gear geometry and visualisation
Author: Milan Batista

1. Extract the archive and select gears_v21 as MATLAB Current Folder.
2. Run runMeFirst. This adds only the root and classes folders.
3. For a demonstration, add its folder explicitly, for example:
     addpath(fullfile(pwd,'examples','meshing'))
     exampleGearsInMesh
4. For literature comparisons, change from the root to verification:
     cd verification
     runVerification

runMeLast removes only the root and classes path entries. Remove manually
added example/verification folders with rmpath when they are no longer needed.
Do not add private folders to the path.

MATLAB is required; Optimization Toolbox is optional (bundled nsolve fallback).
Use the Command Window for graphics export and animation. Minimum supported
MATLAB release and platform compatibility remain to be established.

See README.md for the quick start, inputs, output formats and known limits;
examples/README.md for all demonstrations; doc/README.md for Live Scripts;
verification/README.md for comparisons and regression-test instructions;
doc/THIRD_PARTY_NOTICES.txt for the Kelley solver attribution and MIT source notice.
