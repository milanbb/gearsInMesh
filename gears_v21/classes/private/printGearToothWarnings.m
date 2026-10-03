function printGearToothWarnings(g,fid,name)
%PRINTGEARTOOTHWARNINGS Distinguish undercut, pointed and merely thin tips.
status = gearToothStatus(g);
if status.undercut
    fprintf(fid,'\tWarning: %s is undercut.\n',name);
    fprintf(fid,'\tRequired profile shift to avoid undercut: >= %g\n',g.xmin);
    fprintf(fid,'\tGeometric undercut: part of the involute flank is removed.\n');
    fprintf(fid,'\tThis is not a tooth-root strength assessment.\n');
end
if ~status.validTip
    fprintf(fid,'\tWarning: %s has invalid or nonfinite tip geometry.\n',name);
elseif status.pointed
    fprintf(fid,'\tWarning: %s has pointed teeth or exceeds the pointed-tip radius.\n',name);
elseif status.thin
    fprintf(fid,'\tWarning: %s has a thin tooth tip, not a pointed tooth.\n',name);
    fprintf(fid,'\tTip thickness < 25%% of the reference-circle tooth thickness.\n');
    fprintf(fid,'\tThis is an advisory ratio, not the optimizer''s smin limit.\n');
end
end
