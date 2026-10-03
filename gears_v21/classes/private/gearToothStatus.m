function status = gearToothStatus(g)
%GEARTOOTHSTATUS Reporting-only classification; no gear data are changed.
% The undercut check uses the implemented profile-shift limit.
% It detects geometric undercut, NOT root strength or loss of load capacity. A thin tip
% (advisory threshold 0.25*sr) is not a pointed tooth. This reporting
% threshold is distinct from the gear's q criterion used to calculate umax.
m = g.rack.m;
sa = g.sa;
sr = g.sr;
ra = g.Ra;
rc = g.Rc;
xmin = g.xmin;
status.undercut = g.x < xmin-1e-8*max(1,abs(xmin));
status.validTip = isreal([sa sr ra rc]) && all(isfinite([sa sr ra rc]));
status.pointed = status.validTip && (sa/m <= 1e-10 || ra >= rc-1e-10*m);
status.thin = status.validTip && ~status.pointed && sa < 0.25*sr;
end
