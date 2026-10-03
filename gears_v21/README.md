# gears v21 — External involute gear geometry

MATLAB classes for constructing external involute spur and helical gears as
rack envelopes, inspecting selected geometric limits, assembling gear pairs,
animating meshing and exporting contours. Includes 3-D surface meshes,
examples and literature comparisons. Author: Milan Batista.

## Installation and quick start

Extract the archive and select `gears_v21` as MATLAB's Current Folder:

```matlab
runMeFirst
rack = gearRack(1,'alpha',20,'c',0.167);
G1 = gear(rack,7,'x',0.60,'u',0.80);
G2 = gear(rack,13,'x',0.25,'u',0.85);
GM = gearsInMesh(G1,G2);
print(GM)
plot(GM,'title',false)
```

`runMeFirst` adds **only the package root and `classes`** to the session path.
It does not change Current Folder, add example/verification folders, save the
MATLAB path, run tests or create output folders. Keep only one package version
on the path. Do not add either `private` folder directly.

To run an example by name, add its folder first. From the package root:

```matlab
addpath(fullfile(pwd,'examples','meshing'))
exampleGearsInMesh
```

Use the corresponding folder for other examples; see [examples/README.md](examples/README.md).
Scripts share the caller's workspace. Several clear variables or close figures;
run them in a disposable workspace. Relative outputs use Current Folder.
Calling `run` with a file path can temporarily change that folder, so use the
Command Window and script name when the output location matters.

`runMeLast` removes only the root and `classes`. Remove any example or
verification folders you added with `rmpath`, or close the MATLAB session.

## Requirements

- MATLAB; use desktop graphics for interactive views, keyboard controls and
  video capture. Live Editor is needed for the three `.mlx` guides.
- Optimization Toolbox is **optional**: profile intersections use licensed
  `fsolve` when available and the bundled `nsolve` otherwise.
- Drawing and numerical helpers are included in `classes/private`.
- All 37 automated tests passed and all 15 example scripts completed without
  an uncaught error on MATLAB 26.1.0.3030274 (R2026a) Prerelease,
  Windows 64-bit (`PCWIN64`), on 2 October 2026. The additional test runner
  is maintained separately from this distribution. A minimum supported release
  has not been established; other releases, platforms and Octave are unverified.

## Classes and main interfaces

| Class | Main methods | Purpose |
|---|---|---|
| `gearRack` | `print`, `plot`, `gearGenerating`, `calcProfile`, `calcPoints`, `calcKeyPoints`, `calcLength` | Basic normal rack with read-only `m`, `alpha`, `c`. |
| `gear` | `print`, `plot`, `gearContour`, `getPar`, `getData`, `calcU` | Generated profile, independent `x` and `u`, geometry and contour export. |
| `gearsInMesh` | `print`, `plot`, `animate` | Pair geometry, nominal transverse contact ratio and 2-D animation. |
| `gear3d` | `plot`, `mesh`, `animate` | Shaded views, triangular surface data and 3-D animation. |

Use `help gear`, `help gearRack`, `help gearsInMesh` and `help gear3d` for
options. Method help includes, for example, `help gear.gearContour`.
`Contents.m` is the package index. Interactive guides are listed in [doc/README.md](doc/README.md).

Angles are in degrees. The normal module `m` sets the length unit; use
millimetres to match the printed `mm` labels. The rack coefficient `c` is
dimensionless and is printed without a unit; the corresponding rack clearance
length is `m*c`.

`Ra` is the nominal tip-circle radius. A pointed tooth ends at `Rc` when its
flanks meet before reaching that circle. The heights describe the retained
profile: `ha` runs from `Rr` to its tip, `hd=Rr-Rd` includes the root fillet,
and `h=ha+hd`. The retained tip radius is `Rr+ha`. `Ru` marks the
involute/fillet junction, not the root circle. For pointed teeth, printed
diameters distinguish the nominal tip circle from the retained tip.

`gearRack` is a value class; `gear`, `gearsInMesh` and `gear3d` are handle
classes. Assigning a gear to another variable shares the same object.
Construct separate gears for independent changes. A pair retains its source
gear handles and refreshes its dependent geometry after edits.

`u` is a **gear property**, set by `gear(rack,z,'u',value)` or `g.u=value`;
`0<u<=1`. It is not a `gearRack` option. `g.xmin` gives the implemented
no-undercut shift. `g.umax` and `calcU(g,q)` give a tip-shortening limit for
the transverse tip/reference thickness ratio `sa/sr >= q` (`g.q=0.2` by
default). These queries do not apply a change; use `g.x=g.xmin` or
`g.u=g.umax` when appropriate.

`beta` is a nonnegative helix-angle magnitude, below 90 degrees. Use equal
magnitudes for a parallel-axis pair; `gear3d` displays opposite hands.
The 3-D width and each gear's bore radius `Ri` are display parameters, not
tooth-profile inputs or strength-rated dimensions.

Profile sampling uses Heun by default, with `'sampling','euler'` available.
`np` controls spacing, not the exact total contour-point count. Constructor
and `gearContour` options accept 4–100; assignment to `g.np` accepts 10–200
in this implementation. Analytical segment limits are determined before
sampling. Unresolved or ambiguous intersections raise an error.

## Output and animation

```matlab
plot(GM,'lineWidth',1.5,'lineColor','r','save','figures/pair')
plot(GM,'save',[])                       % Fig<number>.jpg
animate(GM,'nr',0.1,'save','pair')        % pair.avi
animate(GM,'mode','interactive')         % Esc finishes the call
S = gear3d(GM,'width',[3 4]);
plot(S,'export','pair3d')                % pair3d.jpg
[V,F,info] = mesh(S);                    % vertices and surface triangles
[X,Y,info] = gearContour(G1,'file','data/contour.txt');
```

JPG/AVI, contour export and rack text export create missing destination
folders. Named files can be overwritten. `gearContour` writes tab-delimited
planar XYZ coordinates (Z=0), with four significant digits per value; returned
X/Y arrays retain MATLAB numerical precision. `mesh` returns data; it does
not write a CAD or STL file.

`print(rack,filename)` accepts a character filename. `print(g,fid)` and
`print(GM,fid)` instead require an already opened text-file identifier; the
caller closes it. With no second argument, these methods print to the
Command Window.

In animation, L/D step forward/backward, Space pauses automatic playback,
P saves a numbered JPG, H displays help, and Esc stops. Snapshot names are
separate from AVI recording and skip existing names. In 3-D, dragging orbits
the camera and the wheel zooms. `plot(S,'interactive',false)` disables view
controls. Run graphics export and animation from the Command Window:
Live Editor export is not reliable in this release.

## Verification

After `runMeFirst` in the package root, change to `verification` and run:

```matlab
cd verification
runVerification
```

For the separate regression test, still in `verification`:

```matlab
addpath(pwd) % the test temporarily changes Current Folder
results = runtests(fullfile('tests','testDIN3966Verification.m'));
```

Literature comparisons print results and save no files by default. The test
creates temporary work under `testsOutput`; it attempts to remove its temporary
subfolder. See [verification/README.md](verification/README.md) for source
references, optional exports and DIN status meanings.

## Scope and attribution

The package constructs geometry and checks selected geometric quantities.
It does not calculate strength, fatigue life or manufacturing compliance.
`Lc` and `epsalpha` use nominal tip circles; contact markers are restricted
to retained involutes. Neither establishes general interference freedom.

Additional `gear` methods provide normal/tangent overlays, signed normal-force
components and a point model. They do not perform a load or FEM analysis.
`printOptimization` and `optimizationInfo` are retained reporting interfaces;
this archive contains no gear-pair optimisation routine.

Literature references are in the verification scripts. The bundled `nsolve.m`
adapts C. T. Kelley's `nsol.m`, `nsola.m` and helper routines from John Burkardt's
KELLEY collection. The upstream files state the MIT licence. See
[doc/THIRD_PARTY_NOTICES.txt](doc/THIRD_PARTY_NOTICES.txt).
