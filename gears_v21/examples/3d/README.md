# 3-D examples

From the package root, run `runMeFirst`, then
`addpath(fullfile(pwd,'examples','3d'))`. Call one script by name
from the Command Window. `runMeFirst` does not add this folder.

- `exampleGear3dSpur` — Display a seven-tooth spur gear with a bore; writes `gear3d_spur7.jpg`.
- `exampleGear3dHelical` — Display a 13-tooth helical gear and print surface-mesh data; writes `gear3d_helical13.jpg`.
- `exampleGear3dPairHelical` — Display a 7/13 pair with opposite helix hands and independent widths; writes `gear3d_pair713_helical.jpg`.
- `exampleGear3dAnimation` — Animate a 7/36 helical pair; P saves snapshots, AVI export is optional.

Use a disposable workspace; scripts may clear variables or close figures.
Relative outputs use Current Folder. Named files can be overwritten; P-key
snapshots use the next free number. Run export/animation in the Command
Window because Live Editor export is not reliable. Remove the added path
with `rmpath` when finished.
