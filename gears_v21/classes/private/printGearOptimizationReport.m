function printGearOptimizationReport(GM,fid)
%PRINTGEAROPTIMIZATIONREPORT Reporting only; never changes the design.
% Separate requested limits, best candidate, and actual returned object.
info = GM.optimizationInfo;
g1 = GM.G1; g2 = GM.G2;
signature = [g1.z,g2.z,g1.x,g2.x,g1.u,g2.u,g1.beta,g2.beta,...
    g1.rack.m,g2.rack.m,g1.rack.alpha,g2.rack.alpha,...
    g1.rack.c,g2.rack.c];
needed = {'version','verified','reason','smin','emin',...
    'candidateEvaluations','bestEpsalpha','signature'};
hasInfo = isstruct(info) && isscalar(info) && all(isfield(info,needed));
current = hasInfo && isequaln(signature,info.signature);
verified = current && isequal(info.verified,true);
if verified
    titleText = 'VERIFIED FEASIBLE PAIR';
elseif current
    titleText = 'OPTIMIZATION DID NOT SUCCEED';
elseif hasInfo
    titleText = 'CURRENT PAIR -- OPTIMIZATION REPORT OUTDATED';
else
    titleText = 'CURRENT PAIR -- NO OPTIMIZATION RECORD';
end
fprintf(fid,'\nOptimal gear design: %s\n',titleText);
fprintf(fid,'Number of teeth: %d / %d\n',g1.z,g2.z);
s = pairSnapshot(GM);
if hasInfo
    lim = readLimits(info);
    fprintf(fid,'\nREQUESTED LIMITS');
    if ~current
        fprintf(fid,' (from the previous search; current data have changed)');
    end
    fprintf(fid,'\n');
    fprintf(fid,'  Geometric undercut: not allowed for either gear.\n');
    fprintf(fid,'  Tip thickness / normal module: >= %.6g for each gear.\n',lim.smin);
    fprintf(fid,'  Transverse contact ratio: >= %.6g on usable involutes.\n',lim.emin);
    fprintf(fid,'  Radial clearance / module: >= %.6g in both directions.\n',lim.cmin);
    fprintf(fid,'  Tip-shortening coefficient: > 0 and <= 1 for each gear.\n');
    fprintf(fid,'  Profile shifts: at least the no-undercut limit and <= %.6g.\n',lim.xmax);
    if current && ~verified
        fprintf(fid,'\nOptimization did not succeed: no returned optimized pair meets all limits.\n');
        if ~isempty(info.reason)
            fprintf(fid,'Reason: %s\n',info.reason);
        end
        printBestCandidate(fid,info,lim);
        fprintf(fid,'\nRETURNED OBJECT: UNOPTIMIZED REFERENCE PAIR\n');
        fprintf(fid,'This is the actual output GM; it is NOT the best search candidate.\n');
    elseif verified
        fprintf(fid,'\nRETURNED OBJECT: VERIFIED FEASIBLE PAIR\n');
    else
        fprintf(fid,'\nCURRENT OBJECT (stored verification is no longer valid)\n');
    end
else
    lim = struct([]);
    fprintf(fid,'No optimizer limits/status are attached to this pair.\n');
end
printParameters(fid,s);
if hasInfo
    printChecks(fid,s,lim,verified);
else
    fprintf(fid,'Nominal transverse contact ratio: %.6f [NOT CERTIFIED].\n',s.epsalpha);
end
if current && ~verified
    fprintf(fid,'Returned reference-pair status: NOT CERTIFIED.\n');
    fprintf(fid,'Optimization did not succeed; reference values do not override the failure.\n');
elseif hasInfo && ~current
    fprintf(fid,'Gear or rack data changed after optimization. Stored limits are shown\n');
    fprintf(fid,'for reference only; run the optimizer again for a verified result.\n');
    fprintf(fid,'Current-pair optimization status: [NOT CERTIFIED].\n');
end
if any([g1.beta g2.beta] ~= 0)
    fprintf(fid,'Fixed beta; transverse tip thickness; face-width overlap is not included.\n');
end
if hasInfo
    fprintf(fid,'Candidate evaluations in recorded search: %d.\n',info.candidateEvaluations);
end
fprintf(fid,'\nSCOPE OF THE CHECKS\n');
fprintf(fid,'  Geometric undercut: loss of part of the generated involute flank.\n');
fprintf(fid,'  A shorter involute shortens contact only if the removed part is needed\n');
fprintf(fid,'  by the mating gear; the usable-involute contact check is separate.\n');
fprintf(fid,'  Tooth-root strength: NOT ASSESSED, whether undercut is present or absent.\n');
fprintf(fid,'  Absence of undercut does not certify root section, fillet stress or fatigue life.\n');
fprintf(fid,'  Geometrical checks only; load capacity has not been assessed.\n');
fprintf(fid,'  Search results do not prove global optimality or geometric infeasibility.\n');
end

function lim = readLimits(info)
lim = struct('smin',info.smin,'emin',info.emin,'cmin',NaN,'xmax',NaN);
if isfield(info,'cmin')
    lim.cmin = info.cmin;
elseif numel(info.signature) >= 14
    lim.cmin = info.signature(13); % old v13 record: shared generating clearance
end
if isfield(info,'options') && isstruct(info.options) && isfield(info.options,'xmax')
    lim.xmax = info.options.xmax;
end
end

function printBestCandidate(fid,info,lim)
fprintf(fid,'\nBEST CANDIDATE FOUND DURING SEARCH (NOT RETURNED)\n');
if ~isfield(info,'bestCandidate') || isempty(info.bestCandidate)
    if isfinite(info.bestEpsalpha)
        fprintf(fid,'The previous record saved only the search ratio, not a full candidate.\n');
        fprintf(fid,'Largest ratio recorded: %.6f; required >= %.6g [NOT VERIFIED].\n',...
            info.bestEpsalpha,lim.emin);
    else
        fprintf(fid,'No admissible candidate was recorded. Achieved candidate values: N/A.\n');
        fprintf(fid,'No substitute candidate values are taken from the reference pair.\n');
    end
    fprintf(fid,'Candidate geometry/constraint results: NOT AVAILABLE.\n');
    return
end
b = info.bestCandidate;
if b.objectChecked && ~isempty(b.actual)
    printParameters(fid,b.actual);
    printChecks(fid,b.actual,lim,b.geometryVerified);
    if b.geometryVerified
        fprintf(fid,'Other geometrical limits and agreement with the search model: verified.\n');
    else
        fprintf(fid,'Object/model verification failed; this candidate is NOT CERTIFIED.\n');
    end
    if b.allLimitsVerified
        fprintf(fid,'All requested limits were met by this reporting check. The search\n');
        fprintf(fid,'still returned the reference pair; the failed search status is unchanged.\n');
    else
        fprintf(fid,'Best-candidate result: requested design limits NOT all achieved.\n');
    end
else
    % Do not present search-model values as measurements of a checked object.
    d = b.model;
    fprintf(fid,'Object verification unavailable; SEARCH-MODEL VALUES ONLY.\n');
    fprintf(fid,'%-36s %14s %14s\n','Quantity','Gear 1','Gear 2');
    fprintf(fid,'%s\n',repmat('-',1,68));
    numericPair(fid,'Profile shift',d.x);
    numericPair(fid,'Tip-shortening coefficient',d.u);
    numericPair(fid,'Tip thickness / normal module',d.sa);
    fprintf(fid,'Required tip thickness / normal module: >= %.6g.\n',lim.smin);
    fprintf(fid,'Search-model contact ratio: %.6f; required >= %.6g [NOT VERIFIED].\n',...
        d.epsalpha,lim.emin);
    fprintf(fid,'Other achieved object constraints: N/A; candidate is NOT CERTIFIED.\n');
end
if ~isempty(b.message)
    fprintf(fid,'Candidate verification note: %s\n',b.message);
end
if isfinite(info.bestEpsalpha) && info.bestEpsalpha < lim.emin
    fprintf(fid,'Contact-ratio shortfall in search: %.6f.\n',lim.emin-info.bestEpsalpha);
end
end

function printParameters(fid,s)
fprintf(fid,'\n%-36s %14s %14s\n','Quantity','Gear 1','Gear 2');
fprintf(fid,'%s\n',repmat('-',1,68));
numericPair(fid,'Profile shift',s.x);
numericPair(fid,'Tip-shortening coefficient',s.u);
numericPair(fid,'Tip thickness / normal module',s.tip);
numericPair(fid,'No-undercut shift limit',s.xmin);
if any(s.beta ~= 0)
    numericPair(fid,'Helix angle magnitude [deg]',s.beta);
end
undercut = s.x < s.xmin-1e-8*max(1,abs(s.xmin));
fprintf(fid,'%-36s %14s %14s\n','Geometric undercut',yesNo(undercut(1)),yesNo(undercut(2)));
fprintf(fid,'%s\n',repmat('-',1,68));
end

function printChecks(fid,s,lim,basisVerified)
% Same geometric quantities/tolerance as verifyPair; no new design criterion.
tol = 1e-8*max(1,lim.smin);
values = [s.x s.u s.ra s.rb s.rf s.rd s.rc s.tip s.epsalpha s.alphaw s.a];
valid = isreal(values) && all(isfinite(values)) && ~s.invalid;
noUndercut = s.x >= s.xmin-tol;
clearance = s.a-s.ra-s.rd([2 1]);
onInvolute = false;
if valid
    ta = sqrt(max(0,(s.ra-s.rb).*(s.ra+s.rb)));
    tf = sqrt(max(0,(s.rf-s.rb).*(s.rf+s.rb)));
    T = s.a*sind(s.alphaw);
    onInvolute = all(s.ra >= max(s.rb,s.rf)-tol) ...
        && all(tf+ta([2 1]) <= T+tol);
end
contactBasis = basisVerified && valid && all(noUndercut) && onInvolute;
fprintf(fid,'\n%-39s %16s %16s %s\n','Requirement','Required','Achieved','Status');
fprintf(fid,'%s\n',repmat('-',1,91));
for i = 1:2
    valueRow(fid,sprintf('No undercut: shift, gear %d',i),...
        sprintf('>= %.6f',s.xmin(i)),s.x(i),noUndercut(i));
    valueRow(fid,sprintf('Upper shift bound, gear %d',i),...
        sprintf('<= %.6f',lim.xmax),s.x(i),s.x(i) <= lim.xmax+tol);
    valueRow(fid,sprintf('Tip coefficient, gear %d',i),...
        '0 < u <= 1',s.u(i),s.u(i) > 0 && s.u(i) <= 1+tol);
    valueRow(fid,sprintf('Tip thickness / module, gear %d',i),...
        sprintf('>= %.6f',lim.smin),s.tip(i),s.tip(i) >= lim.smin-tol);
    valueRow(fid,sprintf('Radial clearance / module, gear %d',i),...
        sprintf('>= %.6f',lim.cmin),clearance(i),clearance(i) >= lim.cmin-tol);
end
conditionRow(fid,'Finite/valid geometry and positive roots',valid && all(s.rd > 0));
conditionRow(fid,'Tips within limiting pointed-tip radii',valid && all(s.ra <= s.rc+tol));
conditionRow(fid,'Full contact on usable involutes',onInvolute);
if contactBasis
    valueRow(fid,'Transverse contact ratio',sprintf('>= %.6f',lim.emin),...
        s.epsalpha,s.epsalpha >= lim.emin-tol);
    valueRow(fid,'Contact length / module',sprintf('>= %.6f',lim.emin*s.pb),...
        s.Lc,s.Lc >= lim.emin*s.pb-tol*s.pb);
    fprintf(fid,'Transverse contact ratio: %.6f; required >= %.6g [%s].\n',...
        s.epsalpha,lim.emin,passFail(s.epsalpha >= lim.emin-tol));
else
    fprintf(fid,'%-39s %16s %16.6f %s\n','Nominal transverse contact ratio',...
        sprintf('>= %.6f',lim.emin),s.epsalpha,'NOMINAL ONLY');
    fprintf(fid,'%-39s %16s %16.6f %s\n','Nominal contact length / module',...
        sprintf('>= %.6f',lim.emin*s.pb),s.Lc,'NOMINAL ONLY');
    fprintf(fid,'%-39s %16s %16s %s\n','Verified usable-involute contact ratio',...
        sprintf('>= %.6f',lim.emin),'N/A','NOT CERTIFIED');
    fprintf(fid,'Required transverse contact ratio: >= %.6g [NOT CERTIFIED].\n',lim.emin);
    fprintf(fid,'Nominal values have not been shortened at form/undercut limits.\n');
    fprintf(fid,'A nominal value above the minimum is not a verified contact result.\n');
end
fprintf(fid,'%-39s %16s %16s %s\n','Tooth-root strength','not specified','not calculated','NOT ASSESSED');
end

function numericPair(fid,name,v)
fprintf(fid,'%-36s %14.6f %14.6f\n',name,v(1),v(2));
end

function valueRow(fid,name,required,achieved,ok)
if ~isreal(achieved) || ~isfinite(achieved)
    fprintf(fid,'%-39s %16s %16s %s\n',name,required,'N/A','NOT AVAILABLE');
else
    fprintf(fid,'%-39s %16s %16.6f %s\n',name,required,achieved,passFail(ok));
end
end

function conditionRow(fid,name,ok)
fprintf(fid,'%-39s %16s %16s %s\n',name,'yes',yesNo(ok),passFail(ok));
end

function text = passFail(tf)
if tf
    text = 'PASS';
else
    text = 'FAIL';
end
end

function text = yesNo(tf)
if tf
    text = 'yes';
else
    text = 'no';
end
end

function s = pairSnapshot(GM)
% Numerical value record; all lengths except m are in normal-module units.
g1 = GM.G1; g2 = GM.G2;
s.m = g1.rack.m;
s.z = [g1.z g2.z];
s.x = [g1.x g2.x]; s.u = [g1.u g2.u];
s.beta = [g1.beta g2.beta]; s.xmin = [g1.xmin g2.xmin];
s.ra = [g1.Ra g2.Ra]/s.m; s.rb = [g1.Rb g2.Rb]/s.m;
s.rf = [g1.Ru g2.Ru]/s.m; s.rd = [g1.Rd g2.Rd]/s.m;
s.rc = [g1.Rc g2.Rc]/s.m;
s.tip = [g1.sa g2.sa]/s.m;
s.epsalpha = GM.epsalpha; % refresh pair properties before reading a/alphaw
s.a = GM.a/s.m; s.alphaw = GM.alphaw;
s.Lc = GM.Lc/s.m; s.pb = 2*pi*s.rb(1)/s.z(1);
s.invalid = GM.invalid;
end
