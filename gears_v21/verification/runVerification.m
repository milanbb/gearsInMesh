% RUNVERIFICATION Run five literature comparisons from the verification folder.
% First run runMeFirst in the package root, then change to verification and
% call runVerification. No path/Current Folder change or file export occurs.
% Creates verificationSummary and the DIN result variables in the caller workspace.
%
% Wright/Glinsky checks have explicit numerical tolerances; failures are caught,
% recorded and reported with a warning. The separate DIN report retains PASS,
% COND-PASS, REVIEW, COND-REVIEW and SOURCE? statuses. See README.md here.
% These are geometric comparisons, not strength or conformity certification.

checks={'verifySpanWright';'verifyHelicalGlinsky';'verifyPairGlinsky';'verifyFilletWright'};
Passed=false(numel(checks),1); Message=repmat({''},numel(checks),1);
for j=1:numel(checks)
    try
        runOneLiteratureCheck(checks{j});
        Passed(j)=true; Message{j}='All stated comparison tolerances met.';
    catch ME
        Message{j}=ME.message;
        fprintf(2,'\n%s: %s\n',checks{j},ME.message);
    end
end
verificationSummary=table(checks,Passed,Message,'VariableNames',{'Check','Passed','Message'});
fprintf('\nWRIGHT / GLINSKY LITERATURE COMPARISON SUMMARY\n');
disp(verificationSummary);
if ~all(Passed)
    warning('verification:SomeChecksFailed', ...
        'One or more Wright/Glinsky comparisons did not pass. Review the tables/messages above.');
end

fprintf('\nDIN 3966 HISTORICAL EXAMPLE COMPARISONS\n');
% Keep the DIN report multi-status: REVIEW and SOURCE? are informative and
% are not silently converted into either success or failure.
verifyDIN3966

fprintf('\nOVERALL SCOPE\n');
fprintf('The suite verifies selected geometrical quantities only.\n');
fprintf('It is not a DIN conformity, interference, strength, or fatigue certificate.\n');

function runOneLiteratureCheck(name)
% Fixed internal names, not user-provided expressions; no directory change.
eval(name);
end
