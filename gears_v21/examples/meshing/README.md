# Gear-pair examples

From the package root, run `runMeFirst`, then
`addpath(fullfile(pwd,'examples','meshing'))`. Call one script by name
from the Command Window. `runMeFirst` does not add this folder.

- `exampleGearsInMesh` — Print and plot a 7/13 spur pair with independent shifts and shortening; no files.
- `exampleAnimationAutomatic713` — Animate a 7/13 pair automatically; P saves snapshots, AVI export is commented out.
- `exampleAnimationInteractive713` — Inspect a 7/13 pair with L/D stepping; P saves snapshots, Esc ends the call.
- `examplePlotTitleSave` — Write default/named JPGs and `pair1830.avi`; named files can be overwritten.
- `article/exampleGearsInMeshArticle` — Modify an 8/39 helical pair and plot a 3-D view; writes `example1.jpg` through `example4.jpg`. Add this separate subfolder to run by name.

Use a disposable workspace; scripts may clear variables or close figures.
Relative outputs use Current Folder. Named files can be overwritten; P-key
snapshots use the next free number. Run export/animation in the Command
Window because Live Editor export is not reliable. Remove the added path
with `rmpath` when finished.
