# Rack examples

From the package root, run `runMeFirst`, then
`addpath(fullfile(pwd,'examples','rack'))`. Call one script by name
from the Command Window. `runMeFirst` does not add this folder.

- `exampleGearRack1` — Print and plot a normal rack and successive generating positions; no files.
- `exampleGearRack2` — Inspect a shifted rack display and shortened gear; saves a default contact-plot JPG.
- `verifyValueRack` — Assert rack value semantics and independent gear `u`; prints results, no files.

Use a disposable workspace; scripts may clear variables or close figures.
Relative outputs use Current Folder. Named files can be overwritten; P-key
snapshots use the next free number. Run export/animation in the Command
Window because Live Editor export is not reliable. Remove the added path
with `rmpath` when finished.
