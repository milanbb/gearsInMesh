function printGearTipRatio(g,fid,label)
%PRINTGEARTIPRATIO Report tip-thickness ratio without modifying geometry.
sr = g.sr; sa = g.sa;
if ~isreal([sr sa]) || any(~isfinite([sr sa])) || sr <= 0
    fprintf(fid,'\t%s: sa/sr unavailable; q = %.6g.\n',label,g.q);
    return
end
ratio = sa/sr;
% Allow roundoff when calcU has just solved the boundary condition.
tolerance = 64*eps(max([1 abs(ratio) abs(g.q)]));
if ratio >= g.q-tolerance
    fprintf(fid,'\t%s: sa/sr = %.6g >= q = %.6g [PASS].\n',label,ratio,g.q);
else
    fprintf(fid,'\t%s: sa/sr = %.6g < q = %.6g [FAIL].\n',label,ratio,g.q);
    try
        u = g.umax;
        fprintf(fid,'\tRequired tip shortening coefficient: u = %.10g (maximum).\n',u);
        fprintf(fid,'\tApply with g.u = g.umax; current u = %.10g is unchanged.\n',g.u);
    catch exception
        fprintf(fid,'\tRequired u unavailable: %s\n',exception.message);
    end
end
end
