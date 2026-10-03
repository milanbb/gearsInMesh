function [x,y,model] = gearPairContactPoints(source,angle1,aa,side)
%GEARPAIRCONTACTPOINTS Geometric contacts on one transverse involute flank.
% [x,y,model] = gearPairContactPoints(GM,angle1,aa,side) caches scalar data.
% [x,y]       = gearPairContactPoints(model,angle1) evaluates another frame.
% angle1 is in degrees in the same convention as gearsInMesh.plot/animate.
% side=+1/-1 selects mirrored flanks; it is fixed during interactive replay.
% The common normal is clipped by the ACTUAL retained involute endpoints
% returned by getData(G,0) and getData(G,1), not merely by nominal tip circles.
% These are geometric transverse contacts, not contact forces or an
% interference check. Fillet/root contacts and face-width overlap are excluded.
narginchk(2,4)
validateattributes(angle1,{'numeric'},{'real','finite','scalar'});
if isa(source,'gearsInMesh')
    if nargin<3 || isempty(aa), aa=source.a; end
    if nargin<4, side=1; end
    validateattributes(aa,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(side,{'numeric'},{'real','finite','scalar'});
    if ~ismember(side,[-1 1])
        error('gearsInMesh:ContactSide','Contact side must be +1 or -1.');
    end
    g1=source.G1; g2=source.G2;
    rb1=g1.Rb; rb2=g2.Rb; m=g1.rack.m;
    pb1=2*pi*rb1/g1.z; pb2=2*pi*rb2/g2.z;
    scale=max([abs(aa),abs(rb1),abs(rb2),abs(m),realmin]);
    tol=max(1e-9*abs(m),128*eps(scale));
    if ~isreal([rb1 rb2 pb1 pb2]) || any(~isfinite([rb1 rb2 pb1 pb2])) ...
            || any([rb1 rb2 pb1 pb2]<=0)
        error('gearsInMesh:ContactGeometry','Positive finite base radii and pitches are required.');
    end
    if abs(pb1-pb2)>tol
        error('gearsInMesh:ContactGeometry', ...
            'Contact markers require matching transverse base pitches. Check helix angles.');
    end
    sumRb=rb1+rb2;
    if aa<sumRb-tol
        error('gearsInMesh:ContactGeometry','No real common normal exists at this center distance.');
    end
    aw=acos(min(1,sumRb/aa));
    S=aa*sin(aw); % Distance between tangency points on the common normal.
    [lo1,hi1,phi01]=flankData(g1,rb1,tol);
    [lo2,hi2,phi02]=flankData(g2,rb2,tol);
    % Current plot phases: gear 1 -pi/2; gear 2 +pi/2+pi/z2.
    % A nonstandard center distance does NOT silently rephase either gear.
    phaseResidual=rb1*(aw-phi01)+rb2*(aw-phi02-pi/g2.z)-S;
    phaseResidual=mod(phaseResidual+pb1/2,pb1)-pb1/2;
    if abs(phaseResidual)>8*tol
        error('gearsInMesh:ContactPhase', ...
            ['The chosen center distance is incompatible with the displayed tooth phases. ' ...
             'Contact markers are not drawn; no gear is repositioned silently.']);
    end
    model=struct('kind','gearsInMesh.TransverseContacts','rb1',rb1, ...
        'pb',pb1,'z1',g1.z,'aw',aw,'phi01',phi01,'side',side, ...
        'lower',max(lo1,S-hi2),'upper',min(hi1,S-lo2), ...
        'tol',tol,'centerDistance',aa,'phaseResidual',phaseResidual, ...
        'gear1RollBounds',[lo1 hi1],'gear2RollBounds',[lo2 hi2], ...
        'totalRollLength',S);
elseif isstruct(source) && isscalar(source) && isfield(source,'kind') ...
        && strcmp(source.kind,'gearsInMesh.TransverseContacts')
    model=source;
else
    error('gearsInMesh:ContactInput','Expected a gearsInMesh object or its cached contact model.');
end
x=zeros(0,1); y=zeros(0,1);
if model.lower>model.upper+model.tol, return; end
% Positions repeat every base pitch. Reducing the angle first also avoids
% subtracting huge nearly equal roll lengths after many interactive turns.
th=rem(angle1,360/model.z1)*pi/180;
s0=model.rb1*(model.aw-model.phi01-model.side*th);
klo=ceil((s0-model.upper-model.tol)/model.pb);
khi=floor((s0-model.lower+model.tol)/model.pb);
if klo>khi, return; end
s=s0-(klo:khi)'*model.pb;
keep=s>=model.lower-model.tol & s<=model.upper+model.tol;
s=s(keep);
x=model.rb1*cos(model.aw)+s*sin(model.aw);
y=model.side*(model.rb1*sin(model.aw)-s*cos(model.aw));
end

function [lo,hi,phi0] = flankData(g,rb,tol)
% Read both retained endpoints; do not infer the form radius from no-undercut
% formulas, which are not valid for every generated profile.
a=getData(g,0); b=getData(g,1); mid=getData(g,0.5);
r=hypot([a.X b.X mid.X],[a.Y b.Y mid.Y]);
if ~isreal(r) || any(~isfinite(r)) || any(r<rb-tol)
    error('gearsInMesh:ContactGeometry','The retained involute endpoints are invalid.');
end
roll=sqrt(max(0,(r-rb).*(r+rb)));
lo=min(roll(1:2)); hi=max(roll(1:2));
psi=roll(3)/rb;
phi0=-atan2(mid.X,mid.Y)-(psi-atan(psi));
end
