# Examples

Run `runMeFirst` from the package root. It adds classes, **not these example
folders**. Add the chosen folder and call the script by name, for example:

```matlab
addpath(fullfile(pwd,'examples','meshing'))
exampleGearsInMesh
```

These paths are relative to the package root:

| Folder | Scripts |
|---|---|
| `examples/rack` | `exampleGearRack1`, `exampleGearRack2`, `verifyValueRack` |
| `examples/gear` | `exampleGear1`, `exampleGear2`, `exampleGearOutputOptions` |
| `examples/meshing` | `exampleGearsInMesh`, `exampleAnimationAutomatic713`, `exampleAnimationInteractive713`, `examplePlotTitleSave` |
| `examples/meshing/article` | `exampleGearsInMeshArticle` |
| `examples/3d` | `exampleGear3dSpur`, `exampleGear3dHelical`, `exampleGear3dPairHelical`, `exampleGear3dAnimation` |

Each folder's README and each script's header describe outputs. Run scripts
individually in a disposable workspace: some clear variables or close figures.
Relative output paths use Current Folder; named files may be overwritten.
Use the Command Window for export and animation because Live Editor export
can block. P-key snapshots require the figure to have keyboard focus.

The article example is self-contained MATLAB code; it does not need a
manuscript or supplementary PDF. The 3-D animation script selects automatic
or interactive mode through its `mode` variable. Use Esc to end animation.
Remove any paths you added with `rmpath`; `runMeLast` does not remove them.
