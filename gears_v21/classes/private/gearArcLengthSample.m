function [t,info] = gearArcLengthSample(speed,a,b,nIntervals,method,L)
%GEARARCLENGTHSAMPLE Euler/Heun integration of dt/ds = 1/speed(t).
% The end parameters are always retained exactly. Regular interior steps
% use Euler or explicit trapezoidal Heun (not midpoint RK2). If a stage
% approaches a zero speed, leaves the analytical segment, or ceases to
% advance, the segment is resampled by monotone arc-length inversion.
% This safeguard is reported in INFO, not silently labelled a Heun step.
% All numerical quadrature is dimensionless with respect to L.
    validateattributes(a,{'numeric'},{'real','finite','scalar'});
    validateattributes(b,{'numeric'},{'real','finite','scalar','>=',a});
    validateattributes(nIntervals,{'numeric'},{'scalar','integer','positive'});
    validateattributes(L,{'numeric'},{'real','finite','scalar','nonnegative'});
    method=validatestring(method,{'heun','euler'},mfilename,'method');
    info=struct('requestedMethod',method,'usedMethod',method, ...
        'fallback',false,'reason','','intervals',nIntervals);
    if b==a || L==0
        t=a;
        return;
    end
    t=zeros(nIntervals+1,1); t(1)=a; t(end)=b;
    h=L/nIntervals;
    vref=L/(b-a);
    reason='';
    for k=2:nIntervals
        tk=t(k-1);
        v0=speed(tk);
        if ~isreal(v0) || ~isfinite(v0) || v0<=1e-12*vref
            reason='zero or ill-conditioned initial speed'; break;
        end
        pred=tk+h/v0;
        if ~isfinite(pred) || pred<=tk || pred>=b
            reason='Euler predictor leaves the retained interval'; break;
        end
        if strcmp(method,'heun')
            vp=speed(pred);
            if ~isreal(vp) || ~isfinite(vp) || vp<=1e-12*vref
                reason='zero or ill-conditioned predictor speed'; break;
            end
            tn=tk+(h/2)*(1/v0+1/vp);
        else
            tn=pred;
        end
        if ~isfinite(tn) || tn<=tk || tn>=b
            reason='corrector leaves the retained interval'; break;
        end
        t(k)=tn;
    end
    if ~isempty(reason)
        % A cusp can make dt/ds singular although the arc length is finite.
        % Invert the original integral instead of extrapolating past it.
        t(1)=a; t(end)=b;
        options=optimset('Display','off','TolX',32*eps(max(1,max(abs([a b])))));
        for k=2:nIntervals
            target=(k-1)/nIntervals;
            t(k)=fzero(@(q) arc(q)-target,[a b],options);
        end
        if any(diff(t)<=0)
            error('gear:SamplingFailure','Arc-length inversion did not give increasing parameters.');
        end
        info.usedMethod='arc-length inversion';
        info.fallback=true;
        info.reason=reason;
    end
    function s=arc(q)
        if q==a, s=0; return; end
        if q==b, s=1; return; end
        s=integral(@(v) speed(v)/L,a,q,'AbsTol',1e-12,'RelTol',1e-10);
    end
end
