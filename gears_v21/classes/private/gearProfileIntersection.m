function [ta,tb,info] = gearProfileIntersection(curveA,derA,curveB,derB,rangeA,rangeB,scale,equationScale)
%GEARPROFILEINTERSECTION Polyline seeds, then analytical fsolve/nsolve refinement.
% RANGEA must already be restricted to the physical involute branch.
% No root is accepted outside the supplied ranges, and failure never
% substitutes the ordinary junction (1,0). Multiple distinct verified
% roots are reported as ambiguous rather than selected by array order.
% Curve and derivative callbacks return two coordinate arrays [X,Y].
    if nargin<8, equationScale=1; end
    validateattributes(equationScale,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(scale,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(rangeA,{'numeric'},{'real','finite','vector','numel',2});
    validateattributes(rangeB,{'numeric'},{'real','finite','vector','numel',2});
    if rangeA(2)<=rangeA(1) || rangeB(2)<=rangeB(1)
        error('gear:NoPhysicalFlank','No nonzero physical flank interval is available.');
    end
    useFsolve=(exist('fsolve','file')==2 || exist('fsolve','builtin')==5) ...
        && license('test','Optimization_Toolbox');
    solverName='nsolve';
    if useFsolve, solverName='fsolve'; end
    origin=[rangeA(1);rangeB(1)]; width=[diff(rangeA);diff(rangeB)];
    rootTol=1e-10; parTol=64*eps; distinctTol=1e-8;
    opts=optimset('Display','off','Jacobian','on','TolFun',1e-24, ...
        'TolX',1e-12,'MaxIter',200,'MaxFunEvals',1200,'FunValCheck','on');
    previous=[]; accepted=[]; flags=[]; residuals=[]; calls=0; fsolveCalls=0; nsolveCalls=0;
    lastMin=Inf;
    for N=[65 129 257 513]
        q=(1-cos(linspace(0,pi,N)))/2; % resolve near-junction roots
        sa=origin(1)+width(1)*q; sb=origin(2)+width(2)*q;
        [xa,ya]=curveA(sa); [xb,yb]=curveB(sb);
        xa=xa(:)/scale; ya=ya(:)/scale;
        xb=xb(:)/scale; yb=yb(:)/scale;
        if any(~isfinite([xa;ya;xb;yb])) || ~isreal([xa;ya;xb;yb])
            error('gear:InvalidProfile','Non-finite analytical profile in the search interval.');
        end
        [~,~,ii,jj,la,lb]=int2crv(xa,ya,xb,yb,Inf,1e-12);
        % Enforce Nx2 orientation also for one seed / no seeds.
        if isempty(ii)
            seeds=zeros(0,2);
        else
            qa=q(:);
            seeds=[qa(ii)+la.*(qa(ii+1)-qa(ii)), ...
                   qa(jj)+lb.*(qa(jj+1)-qa(jj))];
        end
        accepted=zeros(0,2); flags=zeros(0,1); residuals=zeros(0,1);
        refineSeeds(seeds);
        if isempty(accepted)
            % A sampled tangent contact need not cross a polyline.
            % Closest sampled pairs are extra seeds, not accepted roots.
            D=(xa-xb.').^2+(ya-yb.').^2;
            lastMin=sqrt(min(D(:)));
            seeds=zeros(0,2);
            for k=1:12
                [d,ix]=min(D(:));
                if ~isfinite(d), break; end
                [ia,ib]=ind2sub(size(D),ix);
                seeds(end+1,:)=[q(ia),q(ib)];
                D(max(1,ia-2):min(N,ia+2),max(1,ib-2):min(N,ib+2))=Inf;
            end
            % Do not start only at the singular base endpoint: add
            % geometrically clustered starts just inside the physical branch.
            seeds=[seeds; [1-10.^(-(1:12)).',zeros(12,1)]];
            refineSeeds(seeds);
        end
        if size(accepted,1)>1
            error('gear:AmbiguousIntersection', ...
                ['Several distinct intersections survived the physical-branch checks. ', ...
                 'No arbitrary trimming branch has been selected.']);
        end
        if size(accepted,1)==1 && ~isempty(previous) && ...
                max(abs(accepted-previous))<distinctTol
            p=origin+width.*accepted(1,:).';
            ta=p(1); tb=p(2);
            [f,J]=equations(accepted(1,:).');
            info=struct('status','verified intersection','gridPoints',N, ...
                'fsolveCalls',fsolveCalls,'nsolveCalls',nsolveCalls, ...
                'solver',solverName,'solverCalls',calls,'exitflag',flags(1), ...
                'normalisedResidual',norm(f,Inf)*equationScale, ...
                'scaledResidual',norm(f,Inf),'equationScale',equationScale, ...
                'jacobianRcond',rcond(J),'rangeA',rangeA,'rangeB',rangeB);
            return;
        end
        previous=accepted;
    end
    error('gear:UnresolvedIntersection', ...
        ['No stable verified involute/fillet intersection was found on the ', ...
         'physical branch (closest sampled distance / module: %.3g). ', ...
         'The involute is NOT continued through its base-circle singularity ', ...
         'and no artificial connecting edge is inserted.'],lastMin);

    function refineSeeds(seeds)
        for iseed=1:size(seeds,1)
            calls=calls+1;
            try
                if useFsolve
                    fsolveCalls=fsolveCalls+1;
                    [r,~,flag]=fsolve(@equations,seeds(iseed,:).',opts);
                else
                    nsolveCalls=nsolveCalls+1;
                    [r,~,flag]=nsolve(@equations,seeds(iseed,:).', ...
                        'Jacobian',true,'AbsTol',1e-12,'RelTol',0, ...
                        'MaxIter',200,'Display','off','PolishRoots',false);
                end
            catch ME
                id=lower(ME.identifier);
                unavailable=contains(id,'license') || contains(id,'undefinedfunction');
                if useFsolve && unavailable
                    useFsolve=false; solverName='nsolve';
                    nsolveCalls=nsolveCalls+1;
                    [r,~,flag]=nsolve(@equations,seeds(iseed,:).', ...
                        'Jacobian',true,'AbsTol',1e-12,'RelTol',0, ...
                        'MaxIter',200,'Display','off','PolishRoots',false);
                else
                    continue;
                end
            end
            if flag<=0 || ~isreal(r) || any(~isfinite(r)) || ...
                    any(r < -parTol) || any(r > 1+parTol)
                continue;
            end
            % Snap roundoff only, then re-evaluate the analytical residual.
            r=min(1,max(0,r));
            f=equations(r);
            if ~isreal(f) || any(~isfinite(f)) || norm(f,Inf)>rootTol
                continue;
            end
            if ~isempty(accepted) && any(max(abs(accepted-r.'),[],2)<distinctTol)
                continue;
            end
            accepted(end+1,:)=r.';
            flags(end+1,1)=flag;
            residuals(end+1,1)=norm(f,Inf);
        end
    end
    function [f,J]=equations(qv)
        p=origin+width.*qv(:);
        [xA,yA]=curveA(p(1)); [xB,yB]=curveB(p(2));
        f=[xA-xB;yA-yB]/(scale*equationScale);
        if nargout>1
            [dxA,dyA]=derA(p(1)); [dxB,dyB]=derB(p(2));
            J=[dxA*width(1),-dxB*width(2); ...
               dyA*width(1),-dyB*width(2)]/(scale*equationScale);
        end
    end
end
