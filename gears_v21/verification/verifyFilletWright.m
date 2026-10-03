% VERIFYFILLETWRIGHT Independent offset-curve check of retained root fillets.
% Run runMeFirst in the package root, then execute this script from
% verification. Results remain in the caller workspace; exportResults=false
% by default. Optional CSV output uses Current Folder.
% Douglas Wright, DANotes, Spur gears, Appendix B, pp. 29-30,
% "The Trochoidal Fillet", Fig. B-6/B-7 and eq. (x).
% https://www-mdp.eng.cam.ac.uk/web/library/enginfo/textbooks_dvd_only/DAN/gears/appendices.pdf
% Principle: the fillet is the normal offset of the rolling trajectory of
% the rack-fillet centre by the rack-fillet radius, not a circular gear fillet.
% Below this principle is independently differentiated in Cartesian form.
% The INPUT CASES are chosen here; there are no published coordinate tables.
% The source PDF has missing Greek glyphs; this is not a verbatim transcription.
% Normalized source symbols: R=z/2, shift=x, depth=1+c, e=rho/m, h=pi/4.
% We use the program's retained parameters, so this checks the curve and the
% no-undercut limit, NOT an independent search for the trimming intersection.
exportResults = false;
makePlot = false;
assert(~isempty(which('gear')),'Run runMeFirst before this comparison.');
% Columns: z, x, u, module, clearance coefficient.
cases = [7 0 1 1 .167; 7 .65 .75 1 .167; 13 0 1 1 .167; ...
    24 0 1 1 .25; 40 -.1 .9 3 .1];
N = size(cases,1);
Z = cases(:,1); Shift = cases(:,2);
FilletErrorOverModule=zeros(N,1); InvoluteErrorOverModule=zeros(N,1);
UndercutLimitError=zeros(N,1); SampleCount=zeros(N,1);
for j=1:N
    z=cases(j,1); x=cases(j,2); u=cases(j,3); m=cases(j,4); c=cases(j,5);
    rack=gearRack(m,'alpha',20,'c',c);
    g=gear(rack,z,'x',x,'u',u);
    [~,~,sample]=gearContour(g,'np',80);
    t=sample.segmentParameters{3}(:);
    actual=sample.segmentCoordinates{3};
    assert(~isempty(t),'verification:MissingFillet','No retained fillet for case %d.',j);
    a=20*pi/180; R=m*z/2; rho=m*c/(1-sin(a)); depth=m*(1+c);
    vC=rho-depth; uC=m*pi/4+rho/cos(a)-vC*tan(a);
    B=m*x+vC;
    assert(B<0,'verification:ReferenceBranch','This offset branch requires x*m+vC<0.');
    theta=a+(pi/2-a)*t;
    phi=(B./tan(theta)-uC)/R;
    A=R*phi+uC;
    % Rolling centre trajectory C and its derivative with respect to phi.
    cx=A.*cos(phi)-(R+B).*sin(phi);
    cy=A.*sin(phi)+(R+B).*cos(phi);
    dx=-B.*cos(phi)-A.*sin(phi);
    dy=-B.*sin(phi)+A.*cos(phi);
    speed=hypot(dx,dy);
    reference=[cx+rho*dy./speed, cy-rho*dx./speed];
    FilletErrorOverModule(j)=max(hypot(actual(:,1)-reference(:,1),actual(:,2)-reference(:,2)))/m;
    SampleCount(j)=numel(t);
    % Appendix B involute in polar coordinates; compare public getData output.
    gamma=(m*pi/4+m*x*tan(a))/R+tan(a)-a; rb=R*cos(a);
    err=zeros(31,1);
    for k=1:31
        d=getData(g,(k-1)/30); psi=sqrt(max(0,(d.R/rb)^2-1));
        polarAngle=gamma-psi+atan(psi);
        err(k)=hypot(d.X-d.R*sin(polarAngle),d.Y-d.R*cos(polarAngle))/m;
    end
    InvoluteErrorOverModule(j)=max(err);
    shiftLimit=(depth-R*sin(a)^2-rho*(1-sin(a)))/m;
    UndercutLimitError(j)=abs(g.xmin-shiftLimit);
    if makePlot
        fh=figure; ax=axes('Parent',fh);
        plot(ax,actual(:,1),actual(:,2),'-',reference(:,1),reference(:,2),'o');
        axis(ax,'equal'); legend(ax,'gear retained fillet','Wright offset construction');
        title(ax,sprintf('z=%d, x=%g, u=%g',z,x,u));
        % Explicit relative subdirectory only when this optional plot is saved.
        if ~isfolder('figures'), mkdir('figures'); end
        print(fh,fullfile('figures',sprintf('verification_fillet_%d.jpg',j)),'-djpeg','-r300');
    end
end
Tolerance=repmat(2e-9,N,1);
Pass=isfinite(FilletErrorOverModule) & isfinite(InvoluteErrorOverModule) & ...
    FilletErrorOverModule<=Tolerance & InvoluteErrorOverModule<=Tolerance & ...
    UndercutLimitError<=Tolerance;
verificationTable=table(Z,Shift,SampleCount,FilletErrorOverModule, ...
    InvoluteErrorOverModule,UndercutLimitError,Tolerance,Pass);
fprintf('\nWright: reference-formula checks on chosen retained profiles\n');
disp(verificationTable);
if exportResults, writetable(verificationTable,'verification_wright_fillet.csv'); end
assert(all(Pass),'verification:Mismatch','Retained-profile formula comparison did not pass.');
