% VERIFYDIN3966 Compare gear objects with historical DIN 3966 examples.
% Part of the integrated literature-verification suite.
% Run runMeFirst in the root; change to verification, then call this script
% or runVerification by name. No files are written with the default switches.
%
% EXTERNAL PRIMARY SOURCES (printed page numbering; scans are not bundled):
% A: DIN 3966 Teil 1, August 1978, sections 4.1, 4.2, 4.4, pages 5--7.
% B: DIN 3966, March 1957, examples 3, 4, 7, pages 2--4.
% The two editions are separate datasets, NOT interchangeable corrections.
%
% INTERPRETATION / MODEL COMPLETION:
% - alpha_n=20 deg is explicitly adopted for entries labelled DIN 867.
%   The source pages refer to DIN 867 but do not reproduce that profile.
% - c=0.25 is a declared rack-model choice, not a value read from these tables.
% - u is a GEAR option. When a smaller tooth height is given, u=h/m-1-c.
%   A height used to determine u is INPUT, not an independent successful check.
% - The 1978 spur height 7.88 is retained as printed; u=1 gives 7.875 with
%   the chosen c. This is a rounding-compatible MODEL assumption, not a fit.
% - k=3 (17 teeth) and k=4 (1957, 28 teeth) are explicit working inferences:
%   these scans do not state the number of spanned teeth. Only k=10 in
%   1978 section 4.4 is printed. Conditional results are marked COND-*.
% - sn is NORMAL CIRCULAR thickness, NOT a chord or gear.sr at beta~=0.
% - Normal base-tangent span: Wkn=(g.sb+(k-1)*2*pi*g.Rb/g.z)*cos(beta_b),
%   tan(beta_b)=(g.Rb/g.Rr)*tan(beta). This is a derived measurement, not
%   a native Wk property. For normal-thickness allowance As, deltaW=As*cos(alpha_n).
% - The 1978 helical base diameter has an ambiguous handwritten digit in the
%   available scan. It is kept as '82.27?0', with Reference=NaN, NOT guessed.
% - Manufacturing allowances are source data, NOT numerical error tolerances.
%   Numerical comparison allowance: half the last printed decimal unit.
%   A discrepancy is REVIEW, not silently removed by widening that allowance.
%
% This is a nominal-geometry comparison, NOT DIN conformity, manufacturing
% accuracy, load capacity, or independent verification of a root fillet.
% No pair is fabricated from an unknown mating profile shift.
%
% WORKSPACE OUTPUTS: dinResults, dinInputs, dinScope, dinSummary, dinGears.
% Objects in dinGears are newly constructed; existing user objects are untouched.
% Required public API: gearRack; gear(...,'u',...); Rr, Rb, Ra, Rd, sr, sb, h.
% All comparison data are embedded below; no external file is read at runtime.

%% User switches
exportResults = false;  % CSV files go to Current Folder; no file by default.
showFigures = false;   % Display just the 1978 17- and 28-tooth model sections.
strictChecks = false;  % true: error AFTER the report for numerical REVIEW rows.

assert(~isempty(which('gearRack')) && ~isempty(which('gear')), ...
    'verification:DIN3966Setup','Run runMeFirst before verifyDIN3966.');

% Six separate examples, even where nominal data coincide between editions.
% Columns: ID, m_n, z, x, beta[deg], h_in_scan, k, u_mode, description.
% u_mode 0: default u=1; u_mode 1: derive u from the supplied h and chosen c.
cases = {
    '78-4.1',3.5,17, 0.518, 0,       7.88, 3,0,'1978 p.5, section 4.1: external spur';
    '78-4.2',3.0,28, 0.205,17.4576,  6.50,NaN,1,'1978 p.6, section 4.2: external helical';
    '78-4.4',4.5,81, 0,   11,        NaN,10,0,'1978 p.7, section 4.4: external helical';
    '57-3',  3.5,17, 0.518, 0,       7.40, 3,1,'1957 p.2, example 3: external spur';
    '57-4',  3.0,28, 0,   13,        6.50, 4,1,'1957 p.3, example 4: external helical';
    '57-7', 10.0,150,-0.3, 0,      22.50,NaN,0,'1957 p.4, example 7: external spur'
};
alphaNormal = 20;
clearanceModel = 0.25;
dinGears = cell(size(cases,1),1);
rows = cell(0,12);
inputRows = cell(0,12);
modelErrors = cell(0,2);

for ic = 1:size(cases,1)
    id=cases{ic,1}; mn=cases{ic,2}; z=cases{ic,3}; x=cases{ic,4};
    beta=cases{ic,5}; heightSource=cases{ic,6}; kSpan=cases{ic,7};
    description=cases{ic,9};
    u=1;
    completion='u=1; c=0.25 is a declared model choice';
    if cases{ic,8}==1
        u=heightSource/mn-1-clearanceModel;
        completion='u derived from h in source and chosen c; h is NOT verified';
    elseif strcmp(id,'78-4.1')
        completion='u=1; h_model=7.875 rounds to source 7.88; NOT independent';
    end
    q=struct('d',NaN,'db',NaN,'sn',NaN,'W',NaN,'chord',NaN, ...
        'chordHeight',NaN,'height',NaN);
    try
        r=gearRack(mn,'alpha',alphaNormal,'c',clearanceModel);
        g=gear(r,z,'x',x,'beta',beta,'u',u);
        q=dinObjectMeasurements(g,kSpan);
        dinGears{ic}=g;
    catch ME
        modelErrors(end+1,:)={id,sprintf('%s: %s',ME.identifier,ME.message)}; %#ok<SAGROW>
    end
    inputRows(end+1,:)={id,mn,z,x,beta,alphaNormal,clearanceModel,u, ...
        heightSource,q.height,kSpan,completion}; %#ok<SAGROW>

    % Only the following numbers are used as tabulated reference values.
    % Widths, heights, mates, and tolerance classes are not invented.
    switch id
        case '78-4.1'
            rows(end+1,:)=dinRow(id,'d','59.5',59.5,q.d,0.1,false,description, ...
                'Printed reference diameter; not the addendum diameter.');
            rows(end+1,:)=dinRow(id,'db','55.9120',55.9120,q.db,0.0001,false,description, ...
                'Printed value retained even if it differs from d*cos(20 deg).');
            rows(end+1,:)=dinRow(id,'sn','6.818',6.818,q.sn,0.001,false,description, ...
                'Nominal normal arc thickness; excludes -0.040/-0.100 allowances.');
            rows(end+1,:)=dinRow(id,'W3 maximum','27.868',27.868, ...
                q.W-0.040*cosd(alphaNormal),0.001,true,description, ...
                'k=3 inferred, not printed; As_upper=-0.040; deltaW=As*cos(alpha_n).');
            rows(end+1,:)=dinRow(id,'W3 minimum','27.811',27.811, ...
                q.W-0.100*cosd(alphaNormal),0.001,true,description, ...
                'k=3 inferred, not printed; As_lower=-0.100; deltaW=As*cos(alpha_n).');
        case '78-4.2'
            rows(end+1,:)=dinRow(id,'d','88.056',88.056,q.d,0.001,false,description, ...
                'Decimal beta=17.4576 deg used; rounded DMS is not substituted.');
            rows(end+1,:)=dinRow(id,'db','82.27?0',NaN,q.db,0.0001,false,description, ...
                'Handwritten digit not securely resolved; excluded from numeric pass/fail.');
            rows(end+1,:)=dinRow(id,'sn','5.160',5.160,q.sn,0.001,false,description, ...
                'g.sr*cos(beta), not g.sr; source -0.040/-0.100 are separate allowances.');
        case '78-4.4'
            rows(end+1,:)=dinRow(id,'W10 nominal','131.586',131.586,q.W,0.001,false,description, ...
                'k=10 is printed; -0.100/-0.160 are span allowances, not nominal W.');
        case '57-3'
            rows(end+1,:)=dinRow(id,'W3 nominal','27.904',27.904,q.W,0.001,true,description, ...
                'k=3 inferred, not printed; keep 27.904, do not replace with 1978 limit.');
        case '57-4'
            rows(end+1,:)=dinRow(id,'W4 nominal','32.264',32.264,q.W,0.001,true,description, ...
                'k=4 inferred, not printed; beta=13 deg and x=0 belong to 1957.');
        case '57-7'
            rows(end+1,:)=dinRow(id,'s0 chord','13.52',13.52,q.chord,0.01,false,description, ...
                'Chord at reference circle: 2*Rr*sin(sr/(2*Rr)); NOT arc sr.');
            rows(end+1,:)=dinRow(id,'h0 above chord','7.03',7.03,q.chordHeight,0.01,true,description, ...
                'Requires the declared full-height model u=1,c=0.25; source h=22.5.');
    end
end

dinResults=cell2table(rows,'VariableNames', ...
    {'CaseID','Quantity','SourceText','Reference','Computed','Difference', ...
     'AbsError','RoundingAllowance','Conditional','Status','Source','Note'});
dinInputs=cell2table(inputRows,'VariableNames', ...
    {'CaseID','Module','Teeth','Shift','Beta_deg','Alpha_n_deg', ...
     'c_Model','u_Model','HeightInSource','HeightModel','SpanCount','Completion'});

dinScope=cell2table({
    'Both editions','Tooth-height rows used to select u','INPUT', ...
        'With chosen c, height sets u; reproducing that same height is not an independent test.';
    '1978 4.1 / 1957 ex.3','a=90.060 / 90.06, mate z=33','NOT VERIFIED', ...
        'Mating profile shift and allowances are incomplete; a zero-backlash pair cannot be independently reconstructed.';
    '1978 4.2','a''''=101.185 / 101.105','NOT VERIFIED', ...
        'Double-flank rolling-test distances for a master gear, NOT a working housing center distance.';
    '1978 4.2','d_Nf=84.53','NOT VERIFIED', ...
        'Root usable diameter is not automatically the generated form diameter 2*Ru.';
    '1978 4.2','g_alpha=14.32','NOT VERIFIED', ...
        'The corresponding mate and complete assembly inputs are not given in this table.';
    '1978 4.3 / 1957 ex.6','Internal gear, z=143','UNSUPPORTED', ...
        'Current gear class is external-only. Positive z=143 would not model the internal tooth geometry.';
    '1978 4.5','z=28/53; a=100','INCOMPLETE', ...
        'Setting sheet Z789/3 is referenced, not supplied. Profile shifts and setting data are missing.';
    '1957 ex.5','Protuberance-cutter example','NOT VERIFIED', ...
        'No independent fillet reference or complete cutter/blank data are supplied.';
    'Both editions','DIN quality / tolerance classes','NOT ASSESSED', ...
        'No pitch-error, profile-error, runout, rolling-test or tolerance-grade compliance is assessed.';
    'Both editions','Fillet and root strength','NOT ASSESSED', ...
        'No independent root-fillet coordinates or strength/load data occur in the selected tables.';
    'Both editions','Left-hand designation','NOT ASSESSED', ...
        'The scalar comparisons use beta magnitude; they do not verify helix handedness or a 3D surface.';
    'Spans','Actual measuring-jaw placement','NOT ASSESSED', ...
        'Theoretical normal base-tangent spans only; no face-width/jaw-clearance check.'
    },'VariableNames',{'Source','Quantity','Status','Reason'});

%% Print report -- numerical tolerance is NOT a DIN manufacturing tolerance.
fprintf('\nDIN 3966: HISTORICAL DRAWING-TABLE COMPARISON\n');
fprintf('1978 Teil 1 and 1957 are kept separate. All lengths below are mm.\n');
fprintf('Assumed alpha_n=20 deg; chosen rack c=0.25; see dinInputs for u.\n');
fprintf('Class: %s\n',which('gear'));
fprintf('PASS = within half of the last printed decimal unit.\n');
fprintf('COND-* = depends on an explicit extra inference/assumption.\n');
fprintf('REVIEW = outside that allowance; NOT a claim of a defective gear or source.\n');
fprintf('SOURCE? = unresolved source digit; excluded from numerical pass/fail.\n');
for ic=1:size(cases,1)
    selected=strcmp(dinResults.CaseID,cases{ic,1});
    fprintf('\n%s\n',cases{ic,9});
    fprintf('m_n=%g, z=%d, x=%g, beta=%g deg; u_model=%.9g\n', ...
        cases{ic,2},cases{ic,3},cases{ic,4},cases{ic,5},dinInputs.u_Model(ic));
    fprintf('%-19s %11s %14s %13s %10s  %s\n', ...
        'Quantity','DIN value','Computed','Calc - DIN','Round tol','Status');
    fprintf('%s\n',repmat('-',1,96));
    for ir=find(selected).'
        fprintf('%-19s %11s %14.9f %+13.7f %10.5g  %s\n', ...
            dinResults.Quantity{ir},dinResults.SourceText{ir}, ...
            dinResults.Computed(ir),dinResults.Difference(ir), ...
            dinResults.RoundingAllowance(ir),dinResults.Status{ir});
    end
end
fprintf('\nASSUMPTIONS / SOURCE POINTS TO REVIEW\n');
for ir=1:height(dinResults)
    if dinResults.Conditional(ir) || ~strcmp(dinResults.Status{ir},'PASS')
        fprintf('%s / %s: %s\n',dinResults.CaseID{ir}, ...
            dinResults.Quantity{ir},dinResults.Note{ir});
    end
end
fprintf('\nMODEL COMPLETION (a fitted/input height is not a verification result)\n');
disp(dinInputs);
fprintf('\nNOT VERIFIED / NOT SUPPORTED\n');
for ir=1:height(dinScope)
    fprintf('%s, %s [%s]\n  %s\n',dinScope.Source{ir}, ...
        dinScope.Quantity{ir},dinScope.Status{ir},dinScope.Reason{ir});
end

passMask=ismember(dinResults.Status,{'PASS','COND-PASS'});
reviewMask=ismember(dinResults.Status,{'REVIEW','COND-REVIEW'});
unknownMask=strcmp(dinResults.Status,'SOURCE?');
errorMask=strcmp(dinResults.Status,'MODEL ERROR');
dinSummary=struct('WithinRounding',sum(passMask),'Review',sum(reviewMask), ...
    'UnresolvedSource',sum(unknownMask),'ModelErrorRows',sum(errorMask), ...
    'HasModelErrors',~isempty(modelErrors),'NoDinConformityClaim',true);
fprintf('\nSUMMARY: %d within rounding (including conditional rows), ',sum(passMask));
fprintf('%d REVIEW, %d SOURCE?, %d MODEL ERROR rows.\n', ...
    sum(reviewMask),sum(unknownMask),sum(errorMask));
fprintf('No global DIN conformity / manufacturing / fillet / strength verdict is made.\n');
for ie=1:size(modelErrors,1)
    fprintf(2,'%s: %s\n',modelErrors{ie,1},modelErrors{ie,2});
end

if exportResults
    writetable(dinResults,'DIN3966_results.csv');
    writetable(dinInputs,'DIN3966_inputs.csv');
    writetable(dinScope,'DIN3966_scope.csv');
    fprintf('CSV files saved in Current Folder: %s\n',pwd);
end
if showFigures
    for ic=1:2
        if ~isempty(dinGears{ic})
            plot(dinGears{ic},'nz',4,'title',true);
        end
    end
end
if ~isempty(modelErrors) || any(errorMask)
    error('verification:DIN3966ModelError', ...
        'One or more object calculations failed. Review the complete DIN report above.');
end
if strictChecks && any(reviewMask)
    error('verification:DIN3966Difference', ...
        'Some differences exceed the explicitly stated rounding allowance. Source data were not adjusted.');
end
if any(reviewMask) || any(unknownMask)
    warning('verification:DIN3966Review', ...
        ['Report contains rounding discrepancies or an unresolved source reading. ' ...
         'Review dinInputs and dinResults.Note; this is not a DIN conformity test.']);
end

function q=dinObjectMeasurements(g,k)
% Derive inspection quantities from the ACTUAL public properties of gear.
% No reference table value is used here to calculate a nominal result.
r=g.Rr; rb=g.Rb; st=g.sr; sb=g.sb;
b=g.beta*pi/180;
bb=atan((rb/r)*tan(b));
q.d=2*r;
q.db=2*rb;
q.sn=st*cos(b);
q.W=NaN;
if isfinite(k)
    pb=2*pi*rb/g.z;
    q.W=(sb+(k-1)*pb)*cos(bb);
end
q.chord=2*r*sin(st/(2*r));
% Stable sagitta: r*(1-cos(st/(2*r))) = 2*r*sin(st/(4*r))^2.
q.chordHeight=(g.Ra-r)+2*r*sin(st/(4*r))^2;
q.height=g.h;
v=[q.d q.db q.sn q.chord q.chordHeight q.height];
assert(isreal(v) && all(isfinite(v)), ...
    'verification:DIN3966Nonfinite','Computed dimensions must be finite and real.');
if isfinite(k)
    assert(isreal(q.W) && isfinite(q.W), ...
        'verification:DIN3966Nonfinite','Computed span must be finite and real.');
end
end

function row=dinRow(id,quantity,sourceText,reference,computed,lastUnit,conditional,source,note)
% Half-last-unit is a transparent reporting threshold, not a statement that
% the old DIN example was necessarily calculated with modern full precision.
tol=lastUnit/2;
err=computed-reference;
if ~isreal(computed) || ~isfinite(computed)
    status='MODEL ERROR';
elseif isnan(reference)
    status='SOURCE?';
else
    slack=128*eps(max([1,abs(reference),abs(computed)]));
    if abs(err)<=tol+slack
        status='PASS';
    else
        status='REVIEW';
    end
    if conditional, status=['COND-' status]; end
end
row={id,quantity,sourceText,reference,computed,err,abs(err),tol, ...
    logical(conditional),status,source,note};
end
