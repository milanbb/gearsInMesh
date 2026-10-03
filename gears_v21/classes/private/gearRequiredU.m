function u = gearRequiredU(g,q)
%GEARREQUIREDU Maximum shortening coefficient meeting sa/sr >= q.
% Pure calculation: does not modify the gear.
            r = g.Rr; rb = g.Rb; m = g.rack.m; sr = g.sr;
            if ~isreal(sr) || ~isfinite(sr) || sr <= 0
                error('gear:TipThicknessRatio', ...
                    'Reference-circle tooth thickness must be positive and finite.');
            end
            involute = @(a) tan(a)-a; % Angles in radians.
            alpha = acos(rb/r);
            thickness = @(R) R.*(sr/r + ...
                2*(involute(alpha)-involute(acos(rb./R))));
            residual = @(v) thickness(r+m*(g.x+v))-q*sr;
            umin = max(0,-g.x);
            if umin > 1
                error('gear:TipThicknessInterval', ...
                    'No admissible u places the tip at or above the reference circle.');
            elseif residual(1) >= 0
                u = 1;
            else
                u = fzero(residual,[umin 1]);
            end
            if ~isfinite(u) || u <= 0 || u > 1
                error('gear:TipThicknessInterval', ...
                    'The calculated shortening coefficient must satisfy 0 < u <= 1.');
            end
end
