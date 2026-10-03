# Literature verification

Run `runMeFirst` from the package root, then run the comparisons **from the
`verification` folder**:

```matlab
cd verification
runVerification
```

An individual comparison can be called by name from this same folder.
The runner adds no paths and does not change Current Folder. It prints a
Wright/Glinsky summary and the separate DIN report; no files are saved by
default. Scripts leave result variables in the caller's workspace.

| Script | Source and comparison |
|---|---|
| `verifySpanWright` | Douglas Wright, *DANotes: Gear tooth generation*: 13-tooth example, spans over two and three teeth. |
| `verifyFilletWright` | Wright, *DANotes: Spur gears*, Appendix B: independently formulated rolling-centre trajectory and normal offset; selected shortened/undercut profiles. |
| `verifyHelicalGlinsky` | Chad Glinsky, *Geometry / Helical Gears*: dimensions of the published 17-tooth example. |
| `verifyPairGlinsky` | Glinsky's 17/35 pair: published theoretical zero-backlash distance and independent pair quantities evaluated at that distance. |
| `verifyDIN3966` | DIN 3966 (March 1957) and DIN 3966 Teil 1 (August 1978): selected diameters, normal thicknesses, spans and chordal quantities. |

The scripts include the numerical inputs and source references. External
publications and DIN scans are not bundled and are not runtime inputs.
Wright and Glinsky URLs are in the corresponding script headers.

## Results and optional files

The Wright/Glinsky scripts use explicit tolerances. The runner records
exceptions in `verificationSummary` and issues a warning if a comparison
fails. DIN results retain `PASS`, `COND-PASS`, `REVIEW`, `COND-REVIEW` and
`SOURCE?`; they are not reduced to one binary verdict.

`verifyDIN3966` produces `dinResults`, `dinInputs`, `dinScope`, `dinSummary`
and `dinGears`. `COND-*` identifies additional assumptions, `REVIEW` denotes
a numerical discrepancy against the stated rounding allowance, and `SOURCE?`
marks an unresolved reference digit. See `dinInputs` and `dinResults.Note`.

Each comparison has an `exportResults=false` switch. If enabled, outputs in
Current Folder are `verification_wright_span.csv`,
`verification_wright_fillet.csv`, `verification_glinsky_helical.csv`,
`verification_glinsky_pair.csv`, or `DIN3966_results.csv`,
`DIN3966_inputs.csv` and `DIN3966_scope.csv`. Existing files may be overwritten.
`verifyFilletWright` also has `makePlot`; `verifyDIN3966` has `showFigures`
and `strictChecks`, all false by default.

## DIN reporting regression test

This test checks report semantics, not DIN conformity. From `verification`,
after the root setup:

```matlab
addpath(pwd) % keep verifyDIN3966 visible while the test changes folder
results = runtests(fullfile('tests','testDIN3966Verification.m'));
```

The test uses `tests/private` helpers automatically. Do not add that folder
to the path. Temporary work is created below the package's `testsOutput`
folder; cleanup attempts to remove the individual temporary subfolder.
The parent `testsOutput` folder can remain. `runMeLast` does not remove the
verification path added above; remove it separately when finished.

## Scope

Comparisons check selected geometric quantities, not tooth-root strength,
fatigue life, manufacturing tolerance compliance, global interference freedom
or general DIN conformity. The Wright fillet check uses the program's retained
interval and does not independently validate its trimming-root selection.
The Glinsky pair comparison uses the theoretical zero-backlash distance,
not the source's separate 27.5 mm assembly with backlash. The helical
single-gear comparison excludes the source's independently chosen tool radius.
