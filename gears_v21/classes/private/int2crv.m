function [x,y,i1,i2,lambda1,lambda2] = int2crv(x1,y1,x2,y2,maxInts,tol)
%INT2CRV Intersections of two polylines, including segment parameters.
%   [X,Y] = int2crv(X1,Y1,X2,Y2) retains the original interface.
%   [X,Y,I1,I2,L1,L2] also returns segment indices and local parameters:
%     P = (1-L1)*P1(I1) + L1*P1(I1+1), and similarly for curve 2.
%   Optional MAXINTS: positive integer or Inf (default 10).
%   Optional TOL: dimensionless tolerance (default 1e-12).
%   The parallelism test uses normalised direction vectors, not an
%   absolute determinant. Bounding-box and point tolerances scale with
%   the extent of the coordinates. No isnum/isint helper is required.
%   Collinear overlap has infinitely many solutions: its endpoints are
%   returned as candidate seeds, not as a unique analytical intersection.
%   Distinct parameter pairs at the same position are retained. Duplicate
%   representations of a shared polyline vertex are removed.
%   Degenerate segments and empty/one-point inputs are handled explicitly.

    narginchk(4,6)
    if nargin < 5 || isempty(maxInts), maxInts = 10; end
    if nargin < 6 || isempty(tol), tol = 1e-12; end
    names = {'x1','y1','x2','y2'};
    values = {x1,y1,x2,y2};
    for k = 1:4
        v = values{k};
        if ~isnumeric(v) || ~isreal(v) || (~isempty(v) && ~isvector(v)) || ...
                any(~isfinite(v(:)))
            error('int2crv:InputType','%s must be a real finite numeric vector.',names{k});
        end
    end
    if numel(x1) ~= numel(y1) || numel(x2) ~= numel(y2)
        error('int2crv:LenMismatch','Coordinate lengths do not match.');
    end
    if ~isnumeric(maxInts) || ~isreal(maxInts) || ~isscalar(maxInts) || ...
            maxInts <= 0 || isnan(maxInts) || ...
            (isfinite(maxInts) && maxInts ~= fix(maxInts))
        error('int2crv:MaxInts','maxInts must be a positive integer or Inf.');
    end
    validateattributes(tol,{'numeric'},{'real','finite','scalar','nonnegative'});
    x=zeros(0,1); y=x; i1=x; i2=x; lambda1=x; lambda2=x;
    x1=double(x1(:)); y1=double(y1(:)); x2=double(x2(:)); y2=double(y2(:));
    if numel(x1)<2 || numel(x2)<2, return; end
    allX=[x1;x2]; allY=[y1;y2];
    extent=hypot(max(allX)-min(allX),max(allY)-min(allY));
    coordScale=max(abs([allX;allY]));
    posTol=max(tol*extent,32*eps(max(coordScale,realmin)));
    parTol=max(tol,32*eps);
    angTol=max(tol,32*eps);
    truncated=false;
    for i=1:numel(x1)-1
        A=[x1(i);y1(i)]; v=[x1(i+1);y1(i+1)]-A;
        nv=hypot(v(1),v(2));
        lo=min(A,A+v)-posTol; hi=max(A,A+v)+posTol;
        % Vectorised bounding-box reject, followed by exact segment tests.
        jj=find(min(x2(1:end-1),x2(2:end)) <= hi(1) & ...
                max(x2(1:end-1),x2(2:end)) >= lo(1) & ...
                min(y2(1:end-1),y2(2:end)) <= hi(2) & ...
                max(y2(1:end-1),y2(2:end)) >= lo(2));
        for j=jj(:).'
            B=[x2(j);y2(j)]; w=[x2(j+1);y2(j+1)]-B;
            nw=hypot(w(1),w(2)); d=B-A;
            if nv<=posTol && nw<=posTol
                if norm(A-B)<=posTol, store(i,j,0,0,A); end
            elseif nv<=posTol
                mu=dot(A-B,w)/(nw*nw);
                if mu>=-parTol && mu<=1+parTol && norm(A-B-mu*w)<=posTol
                    store(i,j,0,min(1,max(0,mu)),A);
                end
            elseif nw<=posTol
                la=dot(B-A,v)/(nv*nv);
                if la>=-parTol && la<=1+parTol && norm(B-A-la*v)<=posTol
                    store(i,j,min(1,max(0,la)),0,B);
                end
            else
                uv=v/nv; uw=w/nw;
                den=cross2(uv,uw);
                if abs(den)>angTol
                    la=cross2(d,uw)/(nv*den);
                    mu=cross2(d,uv)/(nw*den);
                    if la>=-parTol && la<=1+parTol && mu>=-parTol && mu<=1+parTol
                        la=min(1,max(0,la)); mu=min(1,max(0,mu));
                        P=A+la*v; Q=B+mu*w;
                        if norm(P-Q)<=4*posTol
                            store(i,j,la,mu,(P+Q)/2);
                        end
                    end
                elseif abs(cross2(d,uv))<=posTol
                    % Collinear endpoints only; subsequent refinement must
                    % distinguish coincident curves from isolated roots.
                    l0=dot(d,uv)/nv; l1=l0+dot(w,uv)/nv;
                    a=max(0,min(l0,l1)); b=min(1,max(l0,l1));
                    if a<=b+parTol
                        for la=[min(1,max(0,a)),min(1,max(0,b))]
                            P=A+la*v; mu=dot(P-B,uw)/nw;
                            if mu>=-parTol && mu<=1+parTol
                                store(i,j,la,min(1,max(0,mu)),P);
                            end
                        end
                    end
                end
            end
            if truncated
                warning('int2crv:MaxExceeded','Maximum number of intersections exceeded.');
                return;
            end
        end
    end

    function store(i,j,a,b,P)
        % Global polyline parameters identify a shared vertex uniquely,
        % while retaining multiple branches at a self-intersection.
        q1=(i-1)+a; q2=(j-1)+b;
        if any(abs((i1-1)+lambda1-q1)<=parTol & ...
               abs((i2-1)+lambda2-q2)<=parTol), return; end
        if numel(x)>=maxInts, truncated=true; return; end
        x(end+1,1)=P(1); y(end+1,1)=P(2);
        i1(end+1,1)=i; i2(end+1,1)=j;
        lambda1(end+1,1)=a; lambda2(end+1,1)=b;
    end
end

function c=cross2(a,b)
    c=a(1)*b(2)-a(2)*b(1);
end
