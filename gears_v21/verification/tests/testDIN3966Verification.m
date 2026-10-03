function tests=testDIN3966Verification
%TESTDIN3966VERIFICATION Check reporting semantics; not DIN certification.
% From verification after runMeFirst: addpath(pwd), then
% results = runtests(fullfile('tests','testDIN3966Verification.m'));
% The path entry is needed because fixtures change to a temporary folder.
% Temporary work is under testsOutput; helper routines remain private.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
assert(~isempty(which('verifyDIN3966')),'Run runMeFirst after installing the addon.');
old=pwd;
tmp=gearTestTempname;
mkdir(tmp);
clean=onCleanup(@() restoreFolder(old,tmp));
cd(tmp);
state=warning('query','verification:DIN3966Review');
quiet=onCleanup(@() warning(state));
warning('off','verification:DIN3966Review');
[s,txt]=executeComparison();
s.noFiles=isempty(dir(fullfile(tmp,'DIN3966_*')));
s.noDirectoryChange=strcmp(pwd,tmp);
s.text=txt;
tc.TestData.data=s;
end

function [s,txt]=executeComparison
% Isolated workspace: variables made by the script cannot clobber fixtures.
txt=evalc('verifyDIN3966');
s.results=dinResults;
s.inputs=dinInputs;
s.scope=dinScope;
s.summary=dinSummary;
s.gears=dinGears;
end

function restoreFolder(old,tmp)
cd(old);
if isfolder(tmp), gearTestRemoveFolder(tmp); end
end

function testNoFilesOrFolderChange(tc)
verifyTrue(tc,tc.TestData.data.noFiles);
verifyTrue(tc,tc.TestData.data.noDirectoryChange);
end

function testEditionsRemainSeparate(tc)
T=tc.TestData.data.inputs;
a=T(strcmp(T.CaseID,'78-4.2'),:); b=T(strcmp(T.CaseID,'57-4'),:);
verifyEqual(tc,a.Beta_deg,17.4576,'AbsTol',1e-12);
verifyEqual(tc,b.Beta_deg,13);
verifyEqual(tc,a.Shift,0.205,'AbsTol',1e-12);
verifyEqual(tc,b.Shift,0);
a=T(strcmp(T.CaseID,'78-4.1'),:); b=T(strcmp(T.CaseID,'57-3'),:);
verifyEqual(tc,a.HeightInSource,7.88,'AbsTol',1e-12);
verifyEqual(tc,b.HeightInSource,7.4,'AbsTol',1e-12);
end

function testNormalThicknessProjection(tc)
T=tc.TestData.data.results;
r=T(strcmp(T.CaseID,'78-4.2') & strcmp(T.Quantity,'sn'),:);
g=tc.TestData.data.gears{2};
verifyEqual(tc,r.Computed,g.sr*cosd(g.beta),'AbsTol',1e-10);
verifyGreaterThan(tc,g.sr-r.Computed,0.2);
verifyEqual(tc,r.Status,{'PASS'});
end

function testPrintedTenToothSpan(tc)
T=tc.TestData.data.results;
r=T(strcmp(T.CaseID,'78-4.4'),:);
verifyEqual(tc,r.Reference,131.586,'AbsTol',1e-12);
verifyEqual(tc,r.Computed,131.58611305531528,'AbsTol',1e-8);
verifyFalse(tc,r.Conditional);
verifyEqual(tc,r.Status,{'PASS'});
end

function testInferredSpanCountsAreConditional(tc)
T=tc.TestData.data.results;
for id={'57-3','57-4'}
    r=T(strcmp(T.CaseID,id{1}),:);
    verifyTrue(tc,all(r.Conditional));
    verifyTrue(tc,all(strncmp(r.Status,'COND-',5)));
end
end

function testSourceDiscrepancyNotHidden(tc)
T=tc.TestData.data.results;
r=T(strcmp(T.CaseID,'78-4.1') & strcmp(T.Quantity,'db'),:);
verifyEqual(tc,r.Reference,55.9120,'AbsTol',1e-12);
verifyEqual(tc,r.RoundingAllowance,0.00005,'AbsTol',1e-15);
verifyGreaterThan(tc,r.AbsError,r.RoundingAllowance);
verifyEqual(tc,r.Status,{'REVIEW'});
end

function testAmbiguousSourceDigitIsNotGuessed(tc)
T=tc.TestData.data.results;
r=T(strcmp(T.CaseID,'78-4.2') & strcmp(T.Quantity,'db'),:);
verifyTrue(tc,isnan(r.Reference));
verifyTrue(tc,isfinite(r.Computed));
verifyEqual(tc,r.SourceText,{'82.27?0'});
verifyEqual(tc,r.Status,{'SOURCE?'});
end

function testChordIsNotArcThickness(tc)
T=tc.TestData.data.results;
r=T(strcmp(T.CaseID,'57-7') & strcmp(T.Quantity,'s0 chord'),:);
g=tc.TestData.data.gears{6};
verifyEqual(tc,r.Computed,13.523958633601529,'AbsTol',1e-8);
verifyGreaterThan(tc,g.sr-r.Computed,0.0001);
r=T(strcmp(T.CaseID,'57-7') & strcmp(T.Quantity,'h0 above chord'),:);
verifyEqual(tc,r.Computed,7.030483529017605,'AbsTol',1e-8);
verifyTrue(tc,r.Conditional);
end

function testNoUniversalSuccessVerdict(tc)
s=tc.TestData.data.summary;
verifyEqual(tc,s.WithinRounding,9);
verifyEqual(tc,s.Review,3);
verifyEqual(tc,s.UnresolvedSource,1);
verifyFalse(tc,s.HasModelErrors);
verifyTrue(tc,s.NoDinConformityClaim);
end
