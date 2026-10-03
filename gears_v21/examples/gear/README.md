# Single-gear examples

From the package root, run `runMeFirst`, then
`addpath(fullfile(pwd,'examples','gear'))`. Call one script by name
from the Command Window. `runMeFirst` does not add this folder.

- `exampleGear1` — Inspect generation, profile shift, shortening and force overlays; writes default JPGs and `force.jpg`.
- `exampleGear2` — Sample and overlay a retained contour with Heun; commented alternatives show Euler and XYZ export. No files by default.
- `exampleGearOutputOptions` — Demonstrate title/line controls, contact plots and overlays; writes six named JPGs under `figures/`.

Use a disposable workspace; scripts may clear variables or close figures.
Relative outputs use Current Folder. Named files can be overwritten; P-key
snapshots use the next free number. Run export/animation in the Command
Window because Live Editor export is not reliable. Remove the added path
with `rmpath` when finished.
