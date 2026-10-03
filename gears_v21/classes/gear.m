classdef gear < handle
    % GEAR Construct, inspect and display an external involute gear.
    %   g = gear(rack,z)
    %   g = gear(rack,z,'x',0.3,'u',0.85,'beta',25,'np',100)
    %   g = gear(rack,z,'sampling','heun','q',0.2,'Ri',0)
    %
    % rack is a gearRack value object; z is an integer >1. Options/defaults:
    %   x=0          profile-shift coefficient
    %   u=1          gear tip-shortening coefficient, 0<u<=1
    %   beta=0       helix-angle magnitude in degrees, 0<=beta<90
    %   np=100       sampling control: constructor accepts integers 4..100
    %   sampling     'heun' (default) or 'euler'
    %   q=0.2        minimum tip/reference thickness ratio, 0<q<1
    %   Ri=0         bore radius, 0<=Ri<g.Rd; used by gear3d, not tooth generation
    % Names are case-insensitive and accept a leading '-'. Lengths use the rack
    % module unit. np sets spacing, not an exact total point count. Assignment
    % to g.np accepts 10..200, unlike the constructor/gearContour option.
    % gear is a handle class: assignment shares it. Construct separate gears
    % for independent x and u. Changing g.u leaves the basic rack unchanged.
    %
    % Geometric limits (queries do not modify g):
    %   g.xmin; g.umax; u = calcU(g); u = calcU(g,q);
    %   g.x = g.xmin;                    % apply the no-undercut shift
    %   g.u = g.umax;                    % apply the limit for the current g.q
    % calcU requires a tip at/above the reference circle and a feasible 0<u<=1;
    % otherwise it raises an error. It does not assess strength or interference.
    %
    % Display and export:
    %   print(g); print(g,fid)           % fid is an open text-file ID
    %   plot(g,'nz',4,'title',false,'lineColor','k','lineWidth',2)
    %   plot(g,'gen','save','figures/envelope')
    %   plotRackContactPts(g,'title',false,'save','figures/contact')
    %   [X,Y,info] = gearContour(g,'np',30,'sampling','heun')
    %   gearContour(g,'file','data/contour.txt')
    % 'save',[] or bare 'save' writes Fig<number>.jpg; a name writes a named JPG.
    % Missing folders are created for JPG/coordinate export; named files overwrite.
    % Coordinate files contain tab-delimited planar XYZ with four significant
    % digits, Z=0. Returned X/Y arrays are closed contours at numerical precision.
    % plot also accepts keep, nocir, nocen, notxt and fig. title defaults on.
    %
    % Retained involute queries:
    %   t = getPar(g,R); s = getData(g,t); % t=0 at tip, t=1 at retained root
    % s.X,s.Y: coordinates; s.R: radius; s.L: tangent roll length; s.s: transverse
    % arc thickness; s.phi,s.th,s.invth: degree-valued angles/involute function.
    % getPar returns NaN if the radius-to-parameter solve fails.
    %   [X,Y,Nx,Ny] = getNormal(g,t); [X,Y,Tx,Ty] = getTangent(g,t);
    %   [X,Y,Fx,Fy,M] = getForce(g,t,F);
    %   plotNormal(g,t,t1,t2,...); plotTangent(g,t,t1,t2,...); plotForce(g,t,F,...);
    % The normal/tangent are unit length; F is signed and has no imposed force
    % unit. plotForce uses F as arrow length. These are geometric overlays.
    % g.profileInfo stores intersection and segment diagnostics. Unresolved or
    % ambiguous intersections raise an error before sampling.
    % Ra is the nominal tip radius; a pointed profile ends at Rc instead.
    % ha and h use the retained tip: ha=Rtip-Rr, hd=Rr-Rd, h=ha+hd.
    % The retained tip radius is Rr+ha. Ru is the involute/fillet junction.
    %
    % Additional point-data interface: [node,edge,node1] = model(g,...).
    % See method help; this does not solve an FEM or load-analysis problem.
    % Run runMeFirst; see examples/gear/README.md and doc/gear_doc.mlx.
    % See also gearRack, gearsInMesh, gear3d.

    properties
        q = 0.2    % Minimum tip/reference-circle tooth thickness ratio
    end

    properties (Dependent)
        z          % number of teeth
        x          % profile shift coefficient
        beta       % helix angle in degrees
        u          % Tip shortening coefficient
        umax       % Maximum u satisfying sa/sr >= q
    end
    properties (Access = private)
        z_          % number of teeth
        x_          % profile shift coefficient
        beta_       % helix angle in degrees
        u_          % Tip shortening coefficient
    end
    
    % Bore radius used by gear3d; not part of tooth-profile construction.
    properties (Dependent)
        Ri          % bore radius for gear3d display
    end
    properties (Access = private)
        Ri_         % gear inner radius
    end
    
    properties (Dependent)
        np   % half-tooth sampling-density control
        sampling % point-generation method: heun (default) or euler
        profileInfo % read-only intersection and segment-bound diagnostics
    end
    properties (Access = private)
        np_
        sampling_ = 'heun'
        profileInfo_ = struct()
    end
    
    properties
        rack        % independent value copy of the unchanged basic gearRack
    end
    
    properties(Dependent)
        R0   % normal-system reference radius m*z/2
        Rc   % max. radius for pointed teeth        
        Ra   % nominal addendum (tip) circle radius
        Rr   % transverse reference pitch radius
        Ru   % retained involute/fillet transition radius
        Rb   % base circle radius
        Rd   % dedendum (root) circle radius
        e    % profile shift
        h    % retained total tooth height, ha+hd
        ha   % retained addendum tooth height
        hd   % dedendum tooth height, Rr-Rd
        sa   % tooth thickness at the addendum circle
        sr   % tooth thickness at the reference pitch circle
        su   % tooth thickness at undercuting circle
        sb   % tooth thickness at the base circle
        sd   % tooth thickness at root circle
        xmax % max. profile shift coefficient
        xmin % min. profile shift coefficient
        zmin % minimum number of teeth for zero-shift no-undercut condition
        L    % length of segments
        Lt   % total length of profile
    end
    
    properties (Dependent)
        tpar % end point values of parameter
        tc   % max. radius parameter
    end
    
    properties (Access = private)
        ts_   % start parameter value
        te_   % end parameter value
        Rc_   % intersection with y-axis (ultimate gear outer radius)
        xmax_ % max shift to achive pointed teeth
        tc_
    end
    
    methods
        function obj = gear(rack,z,varargin)
            
            narginchk(2,inf)
            
            % check input
            validateattributes(z,  {'numeric'}, {'>',1,'integer','scalar'});
            if ~isa(rack,'gearRack')
                error('expect gearRack data.')
            end
            
            % set default values
            beta = 0;
            x    = 0;
            u    = 1;
            q    = 0.2;
            np   = 100;
            sampling = 'heun';
            Ri   = 0;
            if mod(numel(varargin),2)~=0
                error('gear:NameValue','Constructor options must be name-value pairs.');
            end
            
            % scann optional input name-value pairs
            if ~isempty(varargin)
                for k = 1:2:length(varargin)
                    switch lower(varargin{k})
                        case {'beta','-beta'}
                            beta = varargin{k + 1};
                            validateattributes(beta,  {'numeric'}, {'>=',0,'<',90,'real','scalar'});
                        case {'x','-x'}
                            x = varargin{k + 1};
                            validateattributes(x,    {'numeric'}, {'real','scalar'});
                        case {'q','-q'}
                            q = varargin{k + 1};
                            validateattributes(q,{'numeric'}, ...
                                {'finite','real','scalar','>',0,'<',1},'gear','q');
                        case {'u','-u'}
                            u = varargin{k + 1};
                            validateattributes(u,{'numeric'}, ...
                                {'finite','real','scalar','>',0,'<=',1},'gear','u');
                        case {'ri','-ri'}
                            Ri = varargin{k + 1};
                            validateattributes(Ri,{'numeric'}, ...
                                {'finite','real','scalar','>=',0},'gear','Ri');
                        case {'sampling','-sampling'}
                            sampling = validatestring(varargin{k+1},{'heun','euler'},'gear','sampling');
                        case {'np','-np'}
                            np = varargin{k + 1};
                            validateattributes(np,     {'numeric'}, {'>',3,'<',101,'integer','scalar'});
                        otherwise
                    end
                end
            end
            
            % save data
            obj.rack = rack;
            obj.z_ = z;
            obj.x_ = x;
            obj.beta_ = beta;
            obj.np_ = np;
            obj.sampling_ = sampling;
            obj.u_ = u;
            obj.q = q;
            obj.Ri_ = 0;
            tinit(obj);
            obj.Ri = Ri;
        end
    end
    
    % Set methods
    methods
        function set.q(obj,value)
            validateattributes(value,{'numeric'}, ...
                {'finite','real','scalar','>',0,'<',1},'gear','q');
            obj.q = value;
        end

        function u = calcU(g,q)
            %CALCU Return the largest u <= 1 meeting the tip-thickness ratio.
            % u = calcU(g) uses g.q (default 0.2).
            % u = g.calcU(q) uses a temporary ratio without changing g.q.
            % No object properties are changed. Assign g.u = g.umax to apply.
            % Thicknesses are transverse circular-arc lengths.
            % The tip circle is constrained to lie at or above the reference
            % circle. This does not check undercutting or load capacity.
            narginchk(1,2)
            if nargin < 2, q = g.q; end
            validateattributes(q,{'numeric'}, ...
                {'finite','real','scalar','>',0,'<',1},'calcU','q');
            u = gearRequiredU(g,q);
        end

        function set.sampling(obj,value)
            obj.sampling_=validatestring(value,{'heun','euler'},'gear','sampling');
        end
        function set.beta(obj,beta)
            % set helix angle in degree
            validateattributes(beta,{'numeric'},{'>=',0,'<',90,'real','scalar'});
            old = obj.beta_;
            obj.beta_ = beta;
            try
                tinit(obj)
            catch ME
                obj.beta_ = old;
                rethrow(ME)
            end
        end
        function set.np(obj,np)
            % set number of points on the profile
            validateattributes(np,{'numeric'}, {'>',9,'<',201,'integer','scalar'});
            obj.np_ = np;
        end
        function set.Ri(obj,Ri)
            % set inner radius
            validateattributes(Ri,{'numeric'}, {'>=',0,'<',obj.Rd,'real','scalar'});
            obj.Ri_ = Ri;
        end
        function set.x(obj,x)
            % set profile shift coefficient
            validateattributes(x,{'numeric'}, {'real','scalar'});
            old = obj.x_;
            obj.x_ = x;
            try
                tinit(obj)
            catch ME
                obj.x_ = old;
                rethrow(ME)
            end
        end
        function set.z(obj,z)
            % set number of teeth
            validateattributes(z,  {'numeric'}, {'>',1,'integer','scalar'});
            old = obj.z_;
            obj.z_ = z;
            try
                tinit(obj)
            catch ME
                obj.z_ = old;
                rethrow(ME)
            end
        end
        function set.u(obj,u)
            % set tip shortening coefficient
            validateattributes(u,{'numeric'}, ...
                {'finite','real','scalar','>',0,'<=',1},'gear','u');
            old = obj.u_;
            obj.u_ = u;
            try
                tinit(obj)
            catch ME
                obj.u_ = old;
                rethrow(ME)
            end
        end
    end
    
    methods
        function tinit(obj)
            % Calculate and verify everything before committing stored bounds.
            if ~isfinite(obj.Rd) || obj.Rd<=0
                error('gear:InvalidRootRadius','The generated root radius must be positive.');
            end
            [rc,tc]=calcRc(obj);
            [ts,te,review]=calcParam(obj,tc);
            if any(~isfinite([ts te])) || ~isreal([ts te]) || any(te<ts)
                error('gear:InvalidProfileBounds','Invalid retained segment bounds.');
            end
            gaps=zeros(1,3);
            active=find(te>ts);
            for k=1:numel(active)-1
                n=active(k); j=active(k+1);
                [x1,y1]=profil(obj,n,te(n));
                [x2,y2]=profil(obj,j,ts(j));
                gaps(k)=hypot(x1-x2,y1-y2)/obj.rack.m;
            end
            if any(gaps>1e-9)
                error('gear:OpenProfile','Analytical segment endpoints do not coincide; no connector was inserted.');
            end
            xmax=calcXmax(obj);
            review.baseParameter=(obj.u+obj.x+obj.z/obj.zmin)/(1+obj.u);
            review.bounds=[ts(:) te(:)];
            review.junctionGaps=gaps;
            review.pointedTip=(te(1)==ts(1));
            obj.ts_=ts; obj.te_=te;
            obj.Rc_=rc; obj.tc_=tc; obj.xmax_=xmax;
            obj.profileInfo_=review;
        end
    end


    % Get methods for data
    methods
        function val = get.beta(obj)
            % helix angle
            val = obj.beta_;
        end
        function val = get.Ri(obj)
            % inner radius
            val = obj.Ri_;
        end
        function val = get.x(obj)
            % profile shift factor
            val = obj.x_;
        end
        function val = get.z(obj)
            % number of teeth
            val = obj.z_;
        end
        function val = get.u(obj)
            % tooth shortening coefficient
            val = obj.u_;
        end
        function val = get.sampling(obj)
            val=obj.sampling_;
        end
        function val = get.profileInfo(obj)
            val=obj.profileInfo_;
        end
        function val = get.np(obj)
            % number of points for contour
            val = obj.np_;
        end
    end
    
    % Get methods for dependent properties
    methods
        function val = get.e(obj)
            % profile shift
            val = obj.x*obj.rack.m;
        end
        function val = get.h(obj)
            % Total radial height of the retained profile, including pointed tips.
            val = obj.ha + obj.hd;
        end
        function val = get.ha(obj)
            % Retained addendum height; pointed teeth end at Rc instead of Ra.
            if obj.te_(1) == 0
                val = obj.Rc_ - obj.Rr;
                return
            end
            val = obj.Ra - obj.Rr;
        end
        function val = get.hd(obj)
            % Dedendum extends to the root circle, including the fillet.
            val = obj.Rr - obj.Rd;
        end
        function val = get.L(obj)
            % length of profile segments
            val = calcLength(obj);
        end
        function val = get.Lt(obj)
            % total length  of profile
            val = sum(obj.L);
        end
        function val = get.Rc(obj)
            % max. circle
            val = obj.Rc_;
        end
        function val = get.Ru(obj)
            % undercut circle
            %  [ts,~] = calcParam(obj);
            [X,Y] = profil(obj,3,obj.ts_(3));
            val = sqrt(X^2 + Y^2);
        end
        function val = get.R0(obj)
            % Normal-system reference radius m*z/2.
            val = obj.z*obj.rack.m/2;
        end
        function val = get.Rr(obj)
            %  pitch circle
            val = obj.R0/cosd(obj.beta);
        end
        function val = get.umax(obj)
            % Computed from current geometry and q, just like xmin.
            val = gearRequiredU(obj,obj.q);
        end

        function val = get.Ra(obj)
            % Nominal addendum circle, also used to construct the profile.
            val = obj.Rr + obj.rack.m*(obj.u + obj.x);
            if val > obj.Rc_
               % val = obj.Rc_;
            end
        end
        function val = get.Rb(obj)
            % base circle
            val = obj.R0*cosd(obj.rack.alpha)/sqrt(1 -(sind(obj.beta)*cosd(obj.rack.alpha))^2);
        end
        function val = get.Rd(obj)
            % dedendum (root) circle
            val = obj.R0/cosd(obj.beta) - obj.rack.m*(1 + obj.rack.c - obj.x);
        end
        function val = get.sa(obj)
            % Transverse tip-circle thickness; zero for a retained pointed tip.
            if obj.te_(1) == 0
                val = 0;
                return
            end
            val = toothThickness(obj,obj.Ra);
        end
        function val = get.sr(obj)
            % tooth thickness at pitch circle
            val = toothThickness(obj,obj.Rr);
        end
        function val = get.su(obj)
            % tooth thickness at involute start circle
            val = toothThickness(obj,obj.Ru);
        end
        function val = get.sb(obj)
            % tooth thickness at base circle
            val = toothThickness(obj,obj.Rb);
        end
        function val = get.sd(obj)
            % tooth thickness at root circle
            %val = toothThickness1(obj,obj.Rd);
            %return
            [~,~,rho,~,~] = calcKeyPoints(obj.rack);
            val = 2*obj.Rd/obj.R0*(obj.rack.m*(pi/4 + tand(obj.rack.alpha)) + rho*cosd(obj.rack.alpha));
        end
        function val = get.xmax(obj)
            % max. profile shif coefficient
            val = obj.xmax_;            
        end
        function val = get.xmin(obj)
            % min profile shift coefficient to avoud undercutting
            val = 1 - obj.z/obj.zmin;
        end
        function val = get.zmin(obj)
            % min. number of teeth to avoid undercuting
            sina = sind(obj.rack.alpha);
            cosb = cosd(obj.beta);
            cosa = sqrt(1 - sina^2);
            sinb = sqrt(1 - cosb^2);
            val = 2*cosb*(1 - (sinb*cosa)^2)/sina^2;
        end
        function out = get.tpar(obj)
            % parameters for key points
            out = [obj.ts_' obj.te_'];
        end
        function out = get.tc(obj)
            % parameters for key points
            out = obj.tc_;
        end        
    end
    
    % involute segment get function
    methods
        function t = getPar(obj,R)
            % calculate normalized parameter for given radius R (involute segment
            % only)
            validateattributes(R,{'numeric'},{'>=',obj.Ru,'<=',obj.Ra,'real','scalar'});           
            try
                %==============================
                t = mfzero(@fun,[obj.ts_(2),obj.te_(2)]);
                %===============================
                t = (t - obj.ts_(2))/(obj.te_(2) - obj.ts_(2));
            catch
                t = NaN;
            end            
            function val = fun(t)
                [X,Y] =  profil(obj,2,t);
                val = X^2 + Y^2 - R^2;
            end
        end        
        function s = getData(obj,t)
            % get various geometric data of involute at point given
            % by parameter t
            narginchk(2,2)
            % check input
            validateattributes(t,{'numeric'}, {'>=',0,'<=',1,'real','scalar'});
            t = obj.ts_(2) + t*(obj.te_(2) - obj.ts_(2));
            [X,Y] = profil(obj,2,t);
            s.t   = t;
            s.R   = sqrt(X^2 + Y^2);  % radius            
            s.X   = X;
            s.Y   = Y;
            s.phi = atand(X/Y);  % angle in degree
            s.s   = s.R*(2*s.phi)*pi/180; % thickness
            s.th  = acosd(obj.Rb/s.R);  % involute angle
            s.invth = tand(s.th)*180/pi - s.th;  % involute of th
            s.L   = sqrt(s.R^2 - obj.Rb^2);  % distanc between tangent point point on involute            
        end
        function [X,Y,Tx,Ty] = getTangent(obj,t)
            % get point and tangent to involute point given with parameter t
             narginchk(2,2)
             nargoutchk(4,4)            
            % check input
            validateattributes(t,{'numeric'}, {'>=',0,'<=',1,'real','scalar'});
            t = obj.ts_(2) + t*(obj.te_(2) - obj.ts_(2));
            [X,Y] = profil(obj,2,t);
            [Tx,Ty] = calcTangent(obj,2,t);
        end        
        function [X,Y,Nx,Ny] = getNormal(obj,t)
            % get point and normal to involute point given with parameter t
             narginchk(2,2)
             nargoutchk(4,4)            
            % check input
            validateattributes(t,{'numeric'}, {'>=',0,'<=',1,'real','scalar'});
            t = obj.ts_(2) + t*(obj.te_(2) - obj.ts_(2));
            [X,Y] = profil(obj,2,t);
            [dX,dY] = calcTangent(obj,2,t);
            Nx = -dY;
            Ny = dX;
        end
        function [X,Y,Fx,Fy,M] = getForce(obj,t,F)
            %GETFORCE Components of signed normal force F and moment about gear centre.
            % The normal is unit length: hypot(Fx,Fy)=abs(F). No force unit is
            % imposed; moment uses force unit times the module length unit.
            [X,Y,Nx,Ny] = getNormal(obj,t);
            Fx = F*Nx;
            Fy = F*Ny;
            M  = X*Fy - Y*Fx; 
        end
    end
    
    % Output methods
    methods
        
        function plot(obj,varargin)
            %PLOT Draw a gear or its generating envelope. GEAR-INLINE-SWITCH-1
            % plot(g,'nz',4,'title',false,'save','figures/gear7')
            % 'save',[] selects Fig<number>.jpg; bare 'save' is retained.
            % Names accept a leading '-'; title accepts on/off, 1/0, true/false.
            % LineWidth/lineColor (or Color) and a LineSpec are supported.
            narginchk(1,inf)
            nargoutchk(0,0)
            % BEGIN INLINE GRAPHICS OPTIONS -- GEAR-INLINE-SWITCH-1
            % Consume each control and its value here, before any drawing.
            fig = [];
            showTitle = true;
            saveFigure = false;
            fileName = [];
            lineSpec = '';
            lineProps = {};
            colorSpecified = false;
            widthSpecified = false;
            nz = obj.z;
            init = true;
            drawCircles = true;
            drawCenter = true;
            generate = false;
            % These names distinguish legacy bare 'save' from 'save',filename.
            knownOptions = {'fig','title','notxt','notext','save', ...
                'nz','gen','gentooth','generationoftooth','keep', ...
                'nocir','nocirc','nocen','nocent','nocenter', ...
                'color','linecolor','linewidth','linestyle','marker', ...
                'markersize','markerindices','markeredgecolor','markerfacecolor','displayname', ...
                'tag','visible','clipping','hittest','pickableparts', ...
                'handlevisibility','userdata','buttondownfcn','createfcn','deletefcn', ...
                'interruptible','busyaction','alignvertexcenters','selectionhighlight','selected'};
            k = 1;
            while k <= numel(varargin)
                name = varargin{k};
                if isa(name,'string') && isscalar(name) && ~ismissing(name)
                    name = char(name);
                end
                if ~ischar(name) || ~isrow(name) || isempty(name)
                    error('gear:GraphicsOptionName', ...
                        'Expected a nonempty option name or line specification.');
                end
                key = lower(name);
                if key(1) == '-'
                    key = key(2:end);
                end
                switch key
                    case 'fig'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after fig.');
                        end
                        fig = varargin{k+1};
                        if ~isempty(fig)
                            validateattributes(fig,{'numeric'}, ...
                                {'real','finite','scalar','integer','positive'});
                        end
                        k = k + 1;
                    case 'nz'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after nz.');
                        end
                        nz = varargin{k+1};
                        validateattributes(nz,{'numeric'}, ...
                            {'real','finite','scalar','integer','positive','<=',obj.z});
                        k = k + 1;
                    case {'gen','gentooth','generationoftooth'}
                        generate = true;
                    case 'keep'
                        init = false;
                    case {'nocir','nocirc'}
                        drawCircles = false;
                    case {'nocen','nocent','nocenter'}
                        drawCenter = false;
                    case 'title'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after title.');
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        if ischar(value) && isrow(value)
                            switch lower(strtrim(value))
                                case 'on'
                                    showTitle = true;
                                case 'off'
                                    showTitle = false;
                                otherwise
                                    error('gear:InvalidTitle', ...
                                        'title must be on/off, 1/0, or true/false.');
                            end
                        elseif (isnumeric(value) || islogical(value)) && ...
                                isscalar(value) && isreal(value) && isfinite(value) && ...
                                (value == 0 || value == 1)
                            showTitle = logical(value);
                        else
                            error('gear:InvalidTitle', ...
                                'title must be on/off, 1/0, or true/false.');
                        end
                        k = k + 1;
                    case {'notxt','notext'}
                        showTitle = false;
                    case 'save'
                        saveFigure = true;
                        fileName = [];
                        if k < numel(varargin)
                            candidate = varargin{k+1};
                            if isa(candidate,'string') && isscalar(candidate) && ~ismissing(candidate)
                                candidate = char(candidate);
                            end
                            if isnumeric(candidate) && isempty(candidate)
                                % Explicit default filename: 'save',[]
                                k = k + 1;
                            elseif ischar(candidate) && (isrow(candidate) || isempty(candidate))
                                nextKey = lower(candidate);
                                if ~isempty(nextKey) && nextKey(1) == '-'
                                    nextKey = nextKey(2:end);
                                end
                                if ~any(strcmp(nextKey,knownOptions))
                                    fileName = candidate;
                                    k = k + 1;
                                end
                                % Otherwise this is a legacy bare 'save';
                                % the following option is processed next.
                            else
                                error('gear:SaveFilename', ...
                                    'Use save,[] or save,filename; a Boolean is not a filename.');
                            end
                        end
                    case {'color','linecolor','linewidth','linestyle','marker', ...
                'markersize','markerindices','markeredgecolor','markerfacecolor','displayname', ...
                'tag','visible','clipping','hittest','pickableparts', ...
                'handlevisibility','userdata','buttondownfcn','createfcn','deletefcn', ...
                'interruptible','busyaction','alignvertexcenters','selectionhighlight','selected'}
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue', ...
                                'A value is required after %s.',name);
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        switch key
                            case {'color','linecolor'}
                                propertyName = 'Color';
                                colorSpecified = true;
                            case 'linewidth'
                                validateattributes(value,{'numeric'}, ...
                                    {'real','finite','scalar','positive'});
                                propertyName = 'LineWidth';
                                widthSpecified = true;
                            otherwise
                                propertyName = key;
                        end
                        % A property's value is never interpreted as an option:
                        % e.g. 'DisplayName','save' is one graphics property.
                        j = find(strcmpi(lineProps(1:2:end),propertyName),1);
                        if isempty(j)
                            lineProps(end+1:end+2) = {propertyName,value};
                        else
                            lineProps{2*j} = value;
                        end
                        k = k + 1;
                    otherwise
                        % LineSpec is kept separately, ahead of name-value pairs.
                        % All package options must have been consumed above.
                        if ~isempty(regexp(name,'^[rgbcmykw+o*.x_|sd^v><ph:\-]+$','once'))
                            if ~isempty(lineSpec)
                                error('gear:LineSpecification', ...
                                    'Supply at most one line specification.');
                            end
                            lineSpec = name;
                            if ~isempty(regexp(name,'[rgbcmykw]','once'))
                                colorSpecified = true;
                            end
                        else
                            error('gear:UnknownGraphicsOption', ...
                                'Unknown graphics option: %s.',name);
                        end
                end
                k = k + 1;
            end
            lineArgs = lineProps;
            if ~isempty(lineSpec)
                lineArgs = [{lineSpec},lineArgs];
            end
            % END INLINE GRAPHICS OPTIONS
            if init
                if isempty(fig)
                    [~,fh,ax] = drawInit;
                else
                    [~,fh,ax] = drawInit(fig);
                end
                axis(ax,'off');
            else
                if isempty(fig)
                    fh = gcf;
                else
                    fh = figure(fig);
                end
                ax = get(fh,'CurrentAxes');
                if isempty(ax), ax = axes('Parent',fh); end
                hold(ax,'on');
            end
            set(groot,'CurrentFigure',fh);
            set(fh,'CurrentAxes',ax);
            set(fh,'Tag','gear.Profile');
            if generate
                plotEnvelope(obj,showTitle,ax,lineSpec,lineProps, ...
                    colorSpecified,widthSpecified);
            else
                if drawCircles
                    drawCircle(0,0,obj.Rr,'r:')
                    drawCircle(0,0,obj.Rb,'g:')
                    drawCircle(0,0,obj.Rd,'b:')
                    drawCircle(0,0,obj.Ra,'m:')
                    drawCircle(0,0,obj.Ru,'k:')
                end
                if drawCenter
                    drawPoint(1,obj.rack.m/4,0,0)
                end
                if showTitle
                    txt = sprintf('m = %g  z = %g  %s = %g%s  d = %g  d%s = %g  x = %g  h = %g',...
                        obj.rack.m,obj.z,'\beta',obj.beta,'^0',2*obj.R0,'_b',2*obj.Rb,obj.x,obj.h);
                    title(ax,txt,'FontSize',12,'FontWeight','normal')
                end
                [X,Y] = calcPoints(obj,nz);
                % Only clean graphics arguments reach drawPolyline/plot.
                if isempty(lineArgs)
                    drawPolyline(X,Y,'k','LineWidth',2)
                else
                    drawPolyline(X,Y,lineArgs{:})
                end
                if obj.Ri > 0
                    if isempty(lineArgs)
                        drawCircle(0,0,obj.Ri,'k','LineWidth',2)
                    else
                        drawCircle(0,0,obj.Ri,lineArgs{:})
                    end
                end
                if init
                    drawLimits(min(X),max(X),min(Y),1.1*max(Y));
                end
            end
            if ~showTitle, title(ax,''); end
            if saveFigure
                fnam = drawSave(fileName,'fig',fh);
                fprintf('Drawing is saved to the file %s\n',fnam);
            end
        end
        
        function  print(obj,fid)
            if nargin < 2
                fid = 1;
            end
            [ad,am,as]=deg2dms(obj.rack.alpha);
            [bd,bm,bs]=deg2dms(obj.beta);
            fprintf(fid,'Data\n');
            fprintf(fid,'                               Number of teeth:%12d\n',obj.z);
            fprintf(fid,'                                        Module:%12.4f mm\n',obj.rack.m);
            fprintf(fid,'                       Standard pressure angle:%6d:%02d:%02d \n',ad,am,as);
            fprintf(fid,'                   Tip clearance coefficient c:%12.4f\n',obj.rack.c);
            fprintf(fid,'                The tip shortening coefficient:%12.4f \n',obj.u);
            fprintf(fid,'                                   Helix angle:%6d:%02d:%02d \n',bd,bm,bs);
            fprintf(fid,'                    Profile shift coefficients:%12.4f\n',obj.x);
            fprintf(fid,'Calculated parameters\n');
            fprintf(fid,'              Nominal addendum circle diameter:%12.4f mm\n',2*obj.Ra);
            if obj.te_(1) == 0
                fprintf(fid,'                         Retained tip diameter:%12.4f mm\n',2*(obj.Rr+obj.ha));
            end
            fprintf(fid,'               Reference pitch circle diameter:%12.4f mm\n',2*obj.Rr);
            fprintf(fid,'                      Undercut circle diameter:%12.4f mm\n',2*obj.Ru);
            fprintf(fid,'                          Base circle diameter:%12.4f mm\n',2*obj.Rb);
            fprintf(fid,'               Dedendum (root) circle diameter:%12.4f mm\n',2*obj.Rd);
            fprintf(fid,'                            Total tooth height:%12.4f mm\n',obj.h);
            fprintf(fid,'                         Addendum tooth height:%12.4f mm\n',obj.ha);
            fprintf(fid,'                         Dedendum tooth height:%12.4f mm\n',obj.hd);
            fprintf(fid,'        Tooth thickness at the addendum circle:%12.4f mm\n',obj.sa);
            fprintf(fid,'           Tooth thickness at the pitch circle:%12.4f mm\n',obj.sr);
            fprintf(fid,'        Tooth thickness at the undercut circle:%12.4f mm\n',obj.su);
            fprintf(fid,'            Tooth thickness at the base circle:%12.4f mm\n',obj.sb);
            fprintf(fid,'            Tooth thickness at the root circle:%12.4f mm\n',obj.sd);
            fprintf(fid,'Notes\n');
            printGearTipRatio(obj,fid,'gear');
            printGearToothWarnings(obj,fid,'gear');
        end
    end
    
    methods
        %=======================
        % Aux. plot functions
        %========================
        function plotNormal(obj,t,t1,t2,varargin)
            %PLOTNORMAL Overlay the normal; options are handled here.
            narginchk(4,inf)
            nargoutchk(0,0)
            % BEGIN INLINE GRAPHICS OPTIONS -- GEAR-INLINE-SWITCH-1
            % Consume each control and its value here, before any drawing.
            fig = [];
            showTitle = [];
            saveFigure = false;
            fileName = [];
            lineSpec = '';
            lineProps = {};
            colorSpecified = false;
            widthSpecified = false;
            % These names distinguish legacy bare 'save' from 'save',filename.
            knownOptions = {'fig','title','notxt','notext','save', ...
                'keep','color','linecolor','linewidth','linestyle', ...
                'marker','markersize','markerindices','markeredgecolor','markerfacecolor', ...
                'displayname','tag','visible','clipping','hittest', ...
                'pickableparts','handlevisibility','userdata','buttondownfcn','createfcn', ...
                'deletefcn','interruptible','busyaction','alignvertexcenters','selectionhighlight', ...
                'selected'};
            k = 1;
            while k <= numel(varargin)
                name = varargin{k};
                if isa(name,'string') && isscalar(name) && ~ismissing(name)
                    name = char(name);
                end
                if ~ischar(name) || ~isrow(name) || isempty(name)
                    error('gear:GraphicsOptionName', ...
                        'Expected a nonempty option name or line specification.');
                end
                key = lower(name);
                if key(1) == '-'
                    key = key(2:end);
                end
                switch key
                    case 'fig'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after fig.');
                        end
                        fig = varargin{k+1};
                        if ~isempty(fig)
                            validateattributes(fig,{'numeric'}, ...
                                {'real','finite','scalar','integer','positive'});
                        end
                        k = k + 1;
                    case 'keep'
                        % Overlay methods already preserve the current drawing.
                    case 'title'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after title.');
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        if ischar(value) && isrow(value)
                            switch lower(strtrim(value))
                                case 'on'
                                    showTitle = true;
                                case 'off'
                                    showTitle = false;
                                otherwise
                                    error('gear:InvalidTitle', ...
                                        'title must be on/off, 1/0, or true/false.');
                            end
                        elseif (isnumeric(value) || islogical(value)) && ...
                                isscalar(value) && isreal(value) && isfinite(value) && ...
                                (value == 0 || value == 1)
                            showTitle = logical(value);
                        else
                            error('gear:InvalidTitle', ...
                                'title must be on/off, 1/0, or true/false.');
                        end
                        k = k + 1;
                    case {'notxt','notext'}
                        showTitle = false;
                    case 'save'
                        saveFigure = true;
                        fileName = [];
                        if k < numel(varargin)
                            candidate = varargin{k+1};
                            if isa(candidate,'string') && isscalar(candidate) && ~ismissing(candidate)
                                candidate = char(candidate);
                            end
                            if isnumeric(candidate) && isempty(candidate)
                                % Explicit default filename: 'save',[]
                                k = k + 1;
                            elseif ischar(candidate) && (isrow(candidate) || isempty(candidate))
                                nextKey = lower(candidate);
                                if ~isempty(nextKey) && nextKey(1) == '-'
                                    nextKey = nextKey(2:end);
                                end
                                if ~any(strcmp(nextKey,knownOptions))
                                    fileName = candidate;
                                    k = k + 1;
                                end
                                % Otherwise this is a legacy bare 'save';
                                % the following option is processed next.
                            else
                                error('gear:SaveFilename', ...
                                    'Use save,[] or save,filename; a Boolean is not a filename.');
                            end
                        end
                    case {'color','linecolor','linewidth','linestyle','marker', ...
                'markersize','markerindices','markeredgecolor','markerfacecolor','displayname', ...
                'tag','visible','clipping','hittest','pickableparts', ...
                'handlevisibility','userdata','buttondownfcn','createfcn','deletefcn', ...
                'interruptible','busyaction','alignvertexcenters','selectionhighlight','selected'}
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue', ...
                                'A value is required after %s.',name);
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        switch key
                            case {'color','linecolor'}
                                propertyName = 'Color';
                                colorSpecified = true;
                            case 'linewidth'
                                validateattributes(value,{'numeric'}, ...
                                    {'real','finite','scalar','positive'});
                                propertyName = 'LineWidth';
                                widthSpecified = true;
                            otherwise
                                propertyName = key;
                        end
                        % A property's value is never interpreted as an option:
                        % e.g. 'DisplayName','save' is one graphics property.
                        j = find(strcmpi(lineProps(1:2:end),propertyName),1);
                        if isempty(j)
                            lineProps(end+1:end+2) = {propertyName,value};
                        else
                            lineProps{2*j} = value;
                        end
                        k = k + 1;
                    otherwise
                        % LineSpec is kept separately, ahead of name-value pairs.
                        % All package options must have been consumed above.
                        if ~isempty(regexp(name,'^[rgbcmykw+o*.x_|sd^v><ph:\-]+$','once'))
                            if ~isempty(lineSpec)
                                error('gear:LineSpecification', ...
                                    'Supply at most one line specification.');
                            end
                            lineSpec = name;
                            if ~isempty(regexp(name,'[rgbcmykw]','once'))
                                colorSpecified = true;
                            end
                        else
                            error('gear:UnknownGraphicsOption', ...
                                'Unknown graphics option: %s.',name);
                        end
                end
                k = k + 1;
            end
            lineArgs = lineProps;
            if ~isempty(lineSpec)
                lineArgs = [{lineSpec},lineArgs];
            end
            % END INLINE GRAPHICS OPTIONS
            [X,Y,Nx,Ny] = getNormal(obj,t);
            % Overlay graphics without clearing the selected drawing.
            if isempty(fig)
                fh = get(groot,'CurrentFigure');
            else
                fh = figure(fig);
            end
            if isempty(fh) || ~isgraphics(fh,'figure')
                [~,fh,ax] = drawInit;
            else
                ax = get(fh,'CurrentAxes');
                if isempty(ax) || ~isgraphics(ax,'axes')
                    ax = axes('Parent',fh);
                    axis(ax,'equal');
                end
            end
            set(groot,'CurrentFigure',fh);
            set(fh,'CurrentAxes',ax);
            previousNextPlot = get(ax,'NextPlot');
            restoreAxes = onCleanup(@() restoreGearAxes(ax,previousNextPlot)); %#ok<NASGU>
            hold(ax,'on');
            for k = 1:length(t)
                drawLine(X(k),Y(k),X(k) + Nx,Y(k) + Ny,t1,t2,lineArgs{:})
            end
            % Unspecified title means preserve it for an overlay.
            if ~isempty(showTitle)
                if showTitle
                    title(ax,'Normal to the tooth flank','FontSize',12,'FontWeight','normal');
                else
                    title(ax,'');
                end
            end
            if saveFigure
                fnam = drawSave(fileName,'fig',fh);
                fprintf('Drawing is saved to the file %s\n',fnam);
            end
        end
        function plotTangent(obj,t,t1,t2,varargin)
            %PLOTTANGENT Overlay the tangent; options are handled here.
            narginchk(4,inf)
            nargoutchk(0,0)
            % BEGIN INLINE GRAPHICS OPTIONS -- GEAR-INLINE-SWITCH-1
            % Consume each control and its value here, before any drawing.
            fig = [];
            showTitle = [];
            saveFigure = false;
            fileName = [];
            lineSpec = '';
            lineProps = {};
            colorSpecified = false;
            widthSpecified = false;
            % These names distinguish legacy bare 'save' from 'save',filename.
            knownOptions = {'fig','title','notxt','notext','save', ...
                'keep','color','linecolor','linewidth','linestyle', ...
                'marker','markersize','markerindices','markeredgecolor','markerfacecolor', ...
                'displayname','tag','visible','clipping','hittest', ...
                'pickableparts','handlevisibility','userdata','buttondownfcn','createfcn', ...
                'deletefcn','interruptible','busyaction','alignvertexcenters','selectionhighlight', ...
                'selected'};
            k = 1;
            while k <= numel(varargin)
                name = varargin{k};
                if isa(name,'string') && isscalar(name) && ~ismissing(name)
                    name = char(name);
                end
                if ~ischar(name) || ~isrow(name) || isempty(name)
                    error('gear:GraphicsOptionName', ...
                        'Expected a nonempty option name or line specification.');
                end
                key = lower(name);
                if key(1) == '-'
                    key = key(2:end);
                end
                switch key
                    case 'fig'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after fig.');
                        end
                        fig = varargin{k+1};
                        if ~isempty(fig)
                            validateattributes(fig,{'numeric'}, ...
                                {'real','finite','scalar','integer','positive'});
                        end
                        k = k + 1;
                    case 'keep'
                        % Overlay methods already preserve the current drawing.
                    case 'title'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after title.');
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        if ischar(value) && isrow(value)
                            switch lower(strtrim(value))
                                case 'on'
                                    showTitle = true;
                                case 'off'
                                    showTitle = false;
                                otherwise
                                    error('gear:InvalidTitle', ...
                                        'title must be on/off, 1/0, or true/false.');
                            end
                        elseif (isnumeric(value) || islogical(value)) && ...
                                isscalar(value) && isreal(value) && isfinite(value) && ...
                                (value == 0 || value == 1)
                            showTitle = logical(value);
                        else
                            error('gear:InvalidTitle', ...
                                'title must be on/off, 1/0, or true/false.');
                        end
                        k = k + 1;
                    case {'notxt','notext'}
                        showTitle = false;
                    case 'save'
                        saveFigure = true;
                        fileName = [];
                        if k < numel(varargin)
                            candidate = varargin{k+1};
                            if isa(candidate,'string') && isscalar(candidate) && ~ismissing(candidate)
                                candidate = char(candidate);
                            end
                            if isnumeric(candidate) && isempty(candidate)
                                % Explicit default filename: 'save',[]
                                k = k + 1;
                            elseif ischar(candidate) && (isrow(candidate) || isempty(candidate))
                                nextKey = lower(candidate);
                                if ~isempty(nextKey) && nextKey(1) == '-'
                                    nextKey = nextKey(2:end);
                                end
                                if ~any(strcmp(nextKey,knownOptions))
                                    fileName = candidate;
                                    k = k + 1;
                                end
                                % Otherwise this is a legacy bare 'save';
                                % the following option is processed next.
                            else
                                error('gear:SaveFilename', ...
                                    'Use save,[] or save,filename; a Boolean is not a filename.');
                            end
                        end
                    case {'color','linecolor','linewidth','linestyle','marker', ...
                'markersize','markerindices','markeredgecolor','markerfacecolor','displayname', ...
                'tag','visible','clipping','hittest','pickableparts', ...
                'handlevisibility','userdata','buttondownfcn','createfcn','deletefcn', ...
                'interruptible','busyaction','alignvertexcenters','selectionhighlight','selected'}
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue', ...
                                'A value is required after %s.',name);
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        switch key
                            case {'color','linecolor'}
                                propertyName = 'Color';
                                colorSpecified = true;
                            case 'linewidth'
                                validateattributes(value,{'numeric'}, ...
                                    {'real','finite','scalar','positive'});
                                propertyName = 'LineWidth';
                                widthSpecified = true;
                            otherwise
                                propertyName = key;
                        end
                        % A property's value is never interpreted as an option:
                        % e.g. 'DisplayName','save' is one graphics property.
                        j = find(strcmpi(lineProps(1:2:end),propertyName),1);
                        if isempty(j)
                            lineProps(end+1:end+2) = {propertyName,value};
                        else
                            lineProps{2*j} = value;
                        end
                        k = k + 1;
                    otherwise
                        % LineSpec is kept separately, ahead of name-value pairs.
                        % All package options must have been consumed above.
                        if ~isempty(regexp(name,'^[rgbcmykw+o*.x_|sd^v><ph:\-]+$','once'))
                            if ~isempty(lineSpec)
                                error('gear:LineSpecification', ...
                                    'Supply at most one line specification.');
                            end
                            lineSpec = name;
                            if ~isempty(regexp(name,'[rgbcmykw]','once'))
                                colorSpecified = true;
                            end
                        else
                            error('gear:UnknownGraphicsOption', ...
                                'Unknown graphics option: %s.',name);
                        end
                end
                k = k + 1;
            end
            lineArgs = lineProps;
            if ~isempty(lineSpec)
                lineArgs = [{lineSpec},lineArgs];
            end
            % END INLINE GRAPHICS OPTIONS
            [X,Y,Tx,Ty] = getTangent(obj,t);
            % Overlay graphics without clearing the selected drawing.
            if isempty(fig)
                fh = get(groot,'CurrentFigure');
            else
                fh = figure(fig);
            end
            if isempty(fh) || ~isgraphics(fh,'figure')
                [~,fh,ax] = drawInit;
            else
                ax = get(fh,'CurrentAxes');
                if isempty(ax) || ~isgraphics(ax,'axes')
                    ax = axes('Parent',fh);
                    axis(ax,'equal');
                end
            end
            set(groot,'CurrentFigure',fh);
            set(fh,'CurrentAxes',ax);
            previousNextPlot = get(ax,'NextPlot');
            restoreAxes = onCleanup(@() restoreGearAxes(ax,previousNextPlot)); %#ok<NASGU>
            hold(ax,'on');
            for k = 1:length(t)
                drawLine(X(k),Y(k),X(k) + Tx,Y(k) + Ty,t1,t2,lineArgs{:})
            end
            % Unspecified title means preserve it for an overlay.
            if ~isempty(showTitle)
                if showTitle
                    title(ax,'Tangent to the tooth flank','FontSize',12,'FontWeight','normal');
                else
                    title(ax,'');
                end
            end
            if saveFigure
                fnam = drawSave(fileName,'fig',fh);
                fprintf('Drawing is saved to the file %s\n',fnam);
            end
        end
        function plotForce(obj,t,F,varargin)
            %PLOTFORCE Overlay a normal arrow with signed drawing length F.
            % F sets arrow length in plot coordinates, not a prescribed load.
            narginchk(3,inf)
            nargoutchk(0,0)
            % BEGIN INLINE GRAPHICS OPTIONS -- GEAR-INLINE-SWITCH-1
            % Consume each control and its value here, before any drawing.
            fig = [];
            showTitle = [];
            saveFigure = false;
            fileName = [];
            lineSpec = '';
            lineProps = {};
            colorSpecified = false;
            widthSpecified = false;
            % These names distinguish legacy bare 'save' from 'save',filename.
            knownOptions = {'fig','title','notxt','notext','save', ...
                'keep','color','linecolor','linewidth','linestyle', ...
                'marker','markersize','markerindices','markeredgecolor','markerfacecolor', ...
                'displayname','tag','visible','clipping','hittest', ...
                'pickableparts','handlevisibility','userdata','buttondownfcn','createfcn', ...
                'deletefcn','interruptible','busyaction','alignvertexcenters','selectionhighlight', ...
                'selected'};
            k = 1;
            while k <= numel(varargin)
                name = varargin{k};
                if isa(name,'string') && isscalar(name) && ~ismissing(name)
                    name = char(name);
                end
                if ~ischar(name) || ~isrow(name) || isempty(name)
                    error('gear:GraphicsOptionName', ...
                        'Expected a nonempty option name or line specification.');
                end
                key = lower(name);
                if key(1) == '-'
                    key = key(2:end);
                end
                switch key
                    case 'fig'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after fig.');
                        end
                        fig = varargin{k+1};
                        if ~isempty(fig)
                            validateattributes(fig,{'numeric'}, ...
                                {'real','finite','scalar','integer','positive'});
                        end
                        k = k + 1;
                    case 'keep'
                        % Overlay methods already preserve the current drawing.
                    case 'title'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after title.');
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        if ischar(value) && isrow(value)
                            switch lower(strtrim(value))
                                case 'on'
                                    showTitle = true;
                                case 'off'
                                    showTitle = false;
                                otherwise
                                    error('gear:InvalidTitle', ...
                                        'title must be on/off, 1/0, or true/false.');
                            end
                        elseif (isnumeric(value) || islogical(value)) && ...
                                isscalar(value) && isreal(value) && isfinite(value) && ...
                                (value == 0 || value == 1)
                            showTitle = logical(value);
                        else
                            error('gear:InvalidTitle', ...
                                'title must be on/off, 1/0, or true/false.');
                        end
                        k = k + 1;
                    case {'notxt','notext'}
                        showTitle = false;
                    case 'save'
                        saveFigure = true;
                        fileName = [];
                        if k < numel(varargin)
                            candidate = varargin{k+1};
                            if isa(candidate,'string') && isscalar(candidate) && ~ismissing(candidate)
                                candidate = char(candidate);
                            end
                            if isnumeric(candidate) && isempty(candidate)
                                % Explicit default filename: 'save',[]
                                k = k + 1;
                            elseif ischar(candidate) && (isrow(candidate) || isempty(candidate))
                                nextKey = lower(candidate);
                                if ~isempty(nextKey) && nextKey(1) == '-'
                                    nextKey = nextKey(2:end);
                                end
                                if ~any(strcmp(nextKey,knownOptions))
                                    fileName = candidate;
                                    k = k + 1;
                                end
                                % Otherwise this is a legacy bare 'save';
                                % the following option is processed next.
                            else
                                error('gear:SaveFilename', ...
                                    'Use save,[] or save,filename; a Boolean is not a filename.');
                            end
                        end
                    case {'color','linecolor','linewidth','linestyle','marker', ...
                'markersize','markerindices','markeredgecolor','markerfacecolor','displayname', ...
                'tag','visible','clipping','hittest','pickableparts', ...
                'handlevisibility','userdata','buttondownfcn','createfcn','deletefcn', ...
                'interruptible','busyaction','alignvertexcenters','selectionhighlight','selected'}
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue', ...
                                'A value is required after %s.',name);
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        switch key
                            case {'color','linecolor'}
                                propertyName = 'Color';
                                colorSpecified = true;
                            case 'linewidth'
                                validateattributes(value,{'numeric'}, ...
                                    {'real','finite','scalar','positive'});
                                propertyName = 'LineWidth';
                                widthSpecified = true;
                            otherwise
                                propertyName = key;
                        end
                        % A property's value is never interpreted as an option:
                        % e.g. 'DisplayName','save' is one graphics property.
                        j = find(strcmpi(lineProps(1:2:end),propertyName),1);
                        if isempty(j)
                            lineProps(end+1:end+2) = {propertyName,value};
                        else
                            lineProps{2*j} = value;
                        end
                        k = k + 1;
                    otherwise
                        % LineSpec is kept separately, ahead of name-value pairs.
                        % All package options must have been consumed above.
                        if ~isempty(regexp(name,'^[rgbcmykw+o*.x_|sd^v><ph:\-]+$','once'))
                            if ~isempty(lineSpec)
                                error('gear:LineSpecification', ...
                                    'Supply at most one line specification.');
                            end
                            lineSpec = name;
                            if ~isempty(regexp(name,'[rgbcmykw]','once'))
                                colorSpecified = true;
                            end
                        else
                            error('gear:UnknownGraphicsOption', ...
                                'Unknown graphics option: %s.',name);
                        end
                end
                k = k + 1;
            end
            lineArgs = lineProps;
            if ~isempty(lineSpec)
                lineArgs = [{lineSpec},lineArgs];
            end
            % END INLINE GRAPHICS OPTIONS
            [X,Y,Nx,Ny] = getNormal(obj,t);
            ad1 = obj.h/6;
            ad2 = ad1/2;
            % Overlay graphics without clearing the selected drawing.
            if isempty(fig)
                fh = get(groot,'CurrentFigure');
            else
                fh = figure(fig);
            end
            if isempty(fh) || ~isgraphics(fh,'figure')
                [~,fh,ax] = drawInit;
            else
                ax = get(fh,'CurrentAxes');
                if isempty(ax) || ~isgraphics(ax,'axes')
                    ax = axes('Parent',fh);
                    axis(ax,'equal');
                end
            end
            set(groot,'CurrentFigure',fh);
            set(fh,'CurrentAxes',ax);
            previousNextPlot = get(ax,'NextPlot');
            restoreAxes = onCleanup(@() restoreGearAxes(ax,previousNextPlot)); %#ok<NASGU>
            hold(ax,'on');
            drawArrow(-3,ad1,ad2,X,Y,'-delta',-F*Nx,-F*Ny,lineArgs{:})
            % Unspecified title means preserve it for an overlay.
            if ~isempty(showTitle)
                if showTitle
                    title(ax,'Force on the tooth flank','FontSize',12,'FontWeight','normal');
                else
                    title(ax,'');
                end
            end
            if saveFigure
                fnam = drawSave(fileName,'fig',fh);
                fprintf('Drawing is saved to the file %s\n',fnam);
            end
        end
        function plotRackContactPts(obj,varargin)
            %PLOTRACKCONTACTPTS Plot rack contact/cutoff sections for this gear.
            % The thin reference profile is the unchanged standard rack.
            % The thick upper segment denotes this gear's addendum cutoff.
            % A positional figure number is accepted for older scripts.
            narginchk(1,inf)
            nargoutchk(0,0)
            % BEGIN INLINE GRAPHICS OPTIONS -- GEAR-INLINE-SWITCH-1
            % Consume each control and its value here, before any drawing.
            fig = [];
            showTitle = true;
            saveFigure = false;
            fileName = [];
            lineSpec = '';
            lineProps = {};
            colorSpecified = false;
            widthSpecified = false;
            % Retain the original optional positional figure number.
            if ~isempty(varargin) && isnumeric(varargin{1})
                fig = varargin{1};
                if ~isempty(fig)
                    validateattributes(fig,{'numeric'}, ...
                        {'real','finite','scalar','integer','positive'});
                end
                varargin(1) = [];
            end
            % These names distinguish legacy bare 'save' from 'save',filename.
            knownOptions = {'fig','title','notxt','notext','save', ...
                'color','linecolor','linewidth','linestyle','marker', ...
                'markersize','markerindices','markeredgecolor','markerfacecolor','displayname', ...
                'tag','visible','clipping','hittest','pickableparts', ...
                'handlevisibility','userdata','buttondownfcn','createfcn','deletefcn', ...
                'interruptible','busyaction','alignvertexcenters','selectionhighlight','selected'};
            k = 1;
            while k <= numel(varargin)
                name = varargin{k};
                if isa(name,'string') && isscalar(name) && ~ismissing(name)
                    name = char(name);
                end
                if ~ischar(name) || ~isrow(name) || isempty(name)
                    error('gear:GraphicsOptionName', ...
                        'Expected a nonempty option name or line specification.');
                end
                key = lower(name);
                if key(1) == '-'
                    key = key(2:end);
                end
                switch key
                    case 'fig'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after fig.');
                        end
                        fig = varargin{k+1};
                        if ~isempty(fig)
                            validateattributes(fig,{'numeric'}, ...
                                {'real','finite','scalar','integer','positive'});
                        end
                        k = k + 1;
                    case 'title'
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue','A value is required after title.');
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        if ischar(value) && isrow(value)
                            switch lower(strtrim(value))
                                case 'on'
                                    showTitle = true;
                                case 'off'
                                    showTitle = false;
                                otherwise
                                    error('gear:InvalidTitle', ...
                                        'title must be on/off, 1/0, or true/false.');
                            end
                        elseif (isnumeric(value) || islogical(value)) && ...
                                isscalar(value) && isreal(value) && isfinite(value) && ...
                                (value == 0 || value == 1)
                            showTitle = logical(value);
                        else
                            error('gear:InvalidTitle', ...
                                'title must be on/off, 1/0, or true/false.');
                        end
                        k = k + 1;
                    case {'notxt','notext'}
                        showTitle = false;
                    case 'save'
                        saveFigure = true;
                        fileName = [];
                        if k < numel(varargin)
                            candidate = varargin{k+1};
                            if isa(candidate,'string') && isscalar(candidate) && ~ismissing(candidate)
                                candidate = char(candidate);
                            end
                            if isnumeric(candidate) && isempty(candidate)
                                % Explicit default filename: 'save',[]
                                k = k + 1;
                            elseif ischar(candidate) && (isrow(candidate) || isempty(candidate))
                                nextKey = lower(candidate);
                                if ~isempty(nextKey) && nextKey(1) == '-'
                                    nextKey = nextKey(2:end);
                                end
                                if ~any(strcmp(nextKey,knownOptions))
                                    fileName = candidate;
                                    k = k + 1;
                                end
                                % Otherwise this is a legacy bare 'save';
                                % the following option is processed next.
                            else
                                error('gear:SaveFilename', ...
                                    'Use save,[] or save,filename; a Boolean is not a filename.');
                            end
                        end
                    case {'color','linecolor','linewidth','linestyle','marker', ...
                'markersize','markerindices','markeredgecolor','markerfacecolor','displayname', ...
                'tag','visible','clipping','hittest','pickableparts', ...
                'handlevisibility','userdata','buttondownfcn','createfcn','deletefcn', ...
                'interruptible','busyaction','alignvertexcenters','selectionhighlight','selected'}
                        if k == numel(varargin)
                            error('gear:MissingGraphicsValue', ...
                                'A value is required after %s.',name);
                        end
                        value = varargin{k+1};
                        if isa(value,'string') && isscalar(value) && ~ismissing(value)
                            value = char(value);
                        end
                        switch key
                            case {'color','linecolor'}
                                propertyName = 'Color';
                                colorSpecified = true;
                            case 'linewidth'
                                validateattributes(value,{'numeric'}, ...
                                    {'real','finite','scalar','positive'});
                                propertyName = 'LineWidth';
                                widthSpecified = true;
                            otherwise
                                propertyName = key;
                        end
                        % A property's value is never interpreted as an option:
                        % e.g. 'DisplayName','save' is one graphics property.
                        j = find(strcmpi(lineProps(1:2:end),propertyName),1);
                        if isempty(j)
                            lineProps(end+1:end+2) = {propertyName,value};
                        else
                            lineProps{2*j} = value;
                        end
                        k = k + 1;
                    otherwise
                        % LineSpec is kept separately, ahead of name-value pairs.
                        % All package options must have been consumed above.
                        if ~isempty(regexp(name,'^[rgbcmykw+o*.x_|sd^v><ph:\-]+$','once'))
                            if ~isempty(lineSpec)
                                error('gear:LineSpecification', ...
                                    'Supply at most one line specification.');
                            end
                            lineSpec = name;
                            if ~isempty(regexp(name,'[rgbcmykw]','once'))
                                colorSpecified = true;
                            end
                        else
                            error('gear:UnknownGraphicsOption', ...
                                'Unknown graphics option: %s.',name);
                        end
                end
                k = k + 1;
            end
            lineArgs = lineProps;
            if ~isempty(lineSpec)
                lineArgs = [{lineSpec},lineArgs];
            end
            % END INLINE GRAPHICS OPTIONS
            if isempty(fig)
                [~,fh,ax] = drawInit;
            else
                [~,fh,ax] = drawInit(fig);
            end
            set(fh,'Tag','gear.RackContact');
            axis(ax,'off');
            if showTitle
                title(ax,'Contact sections','FontSize',12,'FontWeight','normal')
            else
                title(ax,'');
            end
            % Preserve the different default widths of rack and contact.
            rackArgs = {};
            contactArgs = {};
            if ~colorSpecified
                rackArgs = {'Color','k'};
                contactArgs = {'Color','k'};
            end
            if ~widthSpecified
                rackArgs = [rackArgs,{'LineWidth',1}];
                contactArgs = [contactArgs,{'LineWidth',4}];
            end
            rackArgs = [rackArgs,lineProps];
            contactArgs = [contactArgs,lineProps];
            if ~isempty(lineSpec)
                rackArgs = [{lineSpec},rackArgs];
                contactArgs = [{lineSpec},contactArgs];
            end
            % [X,Y] = calcPoints(obj.rack,1,0,0,obj.np);
            % drawPolyline(X,Y,rackArgs{:})
            % % for n = 1:4
            % %     if n ~= 3
            % %         [X,Y] = rackSection(obj,n,[obj.ts_(n),obj.te_(n)]);
            % %     else
            % %         [X,Y] = rackSection(obj,n,linspace(obj.ts_(n),obj.te_(n),obj.np));
            % %     end
            % %     drawPolyline( X,Y,contactArgs{:})
            % %     drawPolyline(-X,Y,contactArgs{:})
            % % end
            % for n = 1:4
            %     if n == 1
            %         [X,Y] = rackContactDisplaySection(obj,1,[obj.ts_(1),obj.te_(1)]);
            %     elseif n == 3
            %         [X,Y] = rackContactDisplaySection(obj,3,linspace(obj.ts_(3),obj.te_(3),obj.np));
            %     else
            %         [X,Y] = rackContactDisplaySection(obj,n,[obj.ts_(n),obj.te_(n)]);
            %     end
            %     drawPolyline(X,Y,contactArgs{:})
            %     drawPolyline(-X,Y,contactArgs{:})
            % end
            [X,Y] = calcPoints(obj.rack,1,0,0,obj.np);
            drawPolyline(X,Y,rackArgs{:})

            Xall = X(:);
            Yall = Y(:);

            for n = 1:4
                if n == 1
                    [X,Y] = rackContactDisplaySection( ...
                        obj,1,[obj.ts_(1),obj.te_(1)]);
                elseif n == 3
                    [X,Y] = rackContactDisplaySection( ...
                        obj,3,linspace(obj.ts_(3),obj.te_(3),obj.np));
                else
                    [X,Y] = rackContactDisplaySection( ...
                        obj,n,[obj.ts_(n),obj.te_(n)]);
                end

                drawPolyline( X,Y,contactArgs{:})
                drawPolyline(-X,Y,contactArgs{:})

                Xall = [Xall; X(:); -X(:)];
                Yall = [Yall; Y(:);  Y(:)];
            end

            % Set plotting limits
            xmin = min(Xall);
            xmax = max(Xall);
            ymin = min(Yall);
            ymax = max(Yall);

            dx = xmax - xmin;
            dy = ymax - ymin;

            mx    = max(0.08*dx,0.15*obj.rack.m);
            my    = max(0.08*dy,0.15*obj.rack.m);
            myTop = max(0.16*dy,0.30*obj.rack.m);

            drawLimits( ...
                xmin-mx, xmax+mx, ...
                ymin-my, ymax+myTop);

            if saveFigure
                fnam = drawSave(fileName,'fig',fh);
                fprintf('Drawing is saved to the file %s\n',fnam);
            end

            if saveFigure
                fnam = drawSave(fileName,'fig',fh);
                fprintf('Drawing is saved to the file %s\n',fnam);
            end
        end
    end
        
    methods
        function [X,Y,info] = gearContour(obj,varargin)
            %GEARCONTOUR Sample and optionally export the closed transverse contour.
            % [X,Y,info] = gearContour(g,'np',30,'sampling','heun').
            % np (alias nn): 4..100 intervals per half-tooth control, not the
            % total vertex count; default uses g.np. ds overrides target spacing
            % in length units, 0<ds<=g.Lt/4. Later np/ds options take precedence.
            % sampling: heun or euler, default g.sampling.
            % file/fnam/fname/filename: character filename for planar XYZ text,
            % tab-delimited, Z=0, four significant digits. Missing folders are
            % created; existing files overwrite. No filename means no file.
            % Options accept a leading '-'. X/Y remain at numerical precision.
            % set default values
            nz = obj.z;
            fnam = '';
            sampling=obj.sampling_;
            if mod(numel(varargin),2)~=0
                error('gear:NameValue','Contour options must be name-value pairs.');
            end
            ds = obj.Lt/obj.np_;  % size step
            %dsmin = min(obj.Lt);
            %if dsmin <= 0
            %    dsmin = min(obj.Lt(2:4));
            %end
            %ds = dsmin/2
            % scan options
            if ~isempty(varargin)
                for k = 1:2:length(varargin)
                    switch lower(varargin{k})
                        case {'sampling','-sampling'}
                            sampling=validatestring(varargin{k+1},{'heun','euler'},'gearContour','sampling');
                        case {'ds','-ds'}
                            ds = varargin{k + 1};
                            validateattributes(ds,{'numeric'}, {'>',0,'<=',obj.Lt/4,'real','scalar'});
                        case {'fnam','fname','file','filename','-fnam','-fname','-file','-filename'}
                            fnam = varargin{k + 1};
                            validateattributes(fnam,{'char'},{'nonempty'});
                        case {'np','nn','-np','-nn'}                            
                            nn = varargin{k + 1};
                            validateattributes(nn,{'numeric'}, {'>',3,'<=',100,'integer','scalar'});
                            ds = obj.Lt/nn;
                    end
                end
            end
            
            % Boundary points
            [X,Y,info] = calcPoints1(obj,ds,nz,sampling);
            if isrow(X)
                X = X';
            end
            if isrow(Y)
                Y = Y';
            end
            % close contour
            X(end+1) = X(1);
            Y(end+1) = Y(1);
            
            if isempty(fnam)
                return
            end
            
            % Relative output names are interpreted in MATLAB Current Folder.
            folder = fileparts(fnam);
            if ~isempty(folder) && ~isfolder(folder)
                [ok,msg] = mkdir(folder);
                if ~ok, error('gear:ExportFile','Cannot create output folder: %s',msg); end
            end
            [fid,msg] = fopen(fnam,'w');
            if fid<0, error('gear:ExportFile','Cannot open export file: %s',msg); end
            closeFile=onCleanup(@() fclose(fid));
            %  fprintf(fid,'%12s%12s%12s\n','x','y','z')
            for n = 1:length(X)
                %fprintf(fid,'%12.4f\t%12.4f\t%12.4f\n',node(n,1),node(n,2),0);
                fprintf(fid,'%.4g\t%.4g\t%.4g\r\n',X(n),Y(n),0);
            end
            clear closeFile;
        end
    end
    
    % FEM model
    methods
       function [node,edge,node1] = model(obj,varargin)
            %MODEL Return boundary points, boundary edges and interior point data.
            % [node,edge,node1] = model(g,'nz',n,'ds',spacing).
            % node/node1 have XY columns; edge has pairs of boundary-node indices.
            % nz: integer 1..g.z (default g.z). ds: 0<ds<=g.Lt/4,
            % default g.Lt/g.np. This produces points, not a solved FEM model.
            
            % set default values
            ds = obj.Lt/obj.np;
            nz = obj.z;
            
            % scan options
            if ~isempty(varargin)
                for k = 1:2:length(varargin)
                    switch lower(varargin{k})
                        case {'nz','-nz'}
                            nz = varargin{k + 1};
                            validateattributes(nz,{'numeric'},{'>',0,'<=',obj.z,'integer','scalar'});
                        case {'ds','-ds'}
                            ds = varargin{k + 1};
                            validateattributes(ds,{'numeric'}, {'>',0,'<=',obj.Lt/4,'real','scalar'});
                        otherwise
                    end
                end
            end
            
            % Boundary points
            [X,Y] = calcPoints1(obj,ds,nz);
            if isrow(X)
                X = X';
            end
            if isrow(Y)
                Y = Y';
            end
            node = [X Y];
            nnd = length(node);
            if nz < obj.z
                [X,Y] = evalLine(node(nnd,1),node(nnd,2),0,0,linspace(0,1,obj.Rd/ds)');
                X = [node(:,1);X];
                Y = [node(:,2);Y];
                [X,Y] = deleteDuplicate(X,Y);
                node = [X Y];
                [X,Y] = evalLine(0,0,node(1,1),node(1,2),linspace(0,1,obj.Rd/ds)');
                X = [node(:,1);X];
                Y = [node(:,2);Y];
                [X,Y] = deleteDuplicate(X,Y);
                node = [X Y];
            end
            nnd = length(node);
            edge = [(1:(nnd-1))' (2:nnd)'; nnd 1];
            
            % generate internal points
            if nz == obj.z
                k = 1;
                node1(1,1) = 0;  % center
                node1(1,2) = 0;
                nr = fix(obj.Rd/ds);
                dr = obj.Rd/nr;
                for r = dr:dr:obj.Rd - dr
                    s = 2*pi*r;
                    n = fix(s/ds);
                    if n < 4
                        continue
                    end
                    dth = 360/n;
                    for th = 0:dth:360-dth
                        k = k + 1;
                        node1(k,1) = r*cosd(th);
                        node1(k,2) = r*sind(th);
                    end
                end
                % tooth
                X = [];
                Y = [];
                j = 0;
                nr = fix((obj.Ra - obj.Rd)/ds);
                dr = (obj.Ra - obj.Rd)/nr;
                for r = obj.Rd :dr:obj.Ra - dr
                    s = toothThickness(obj,r)/2;
                    n = fix(s/ds);
                    if n < 1
                        continue
                    end
                    the = s/r*180/pi;
                    dth = the/n;
                    for th = -the+dth:dth:the-dth
                        j = j + 1;
                        X(j) = r*sind(th);
                        Y(j) = r*cosd(th);                        
                    end
                end
                X = X';
                Y = Y';
                XX = X;
                YY = Y;
                for n = 1:nz - 1
                    [X,Y] = trRot2d(X,Y,0,0,360/obj.z);
                    XX = [X;XX];
                    YY = [Y;YY];
                end
                X = XX;
                Y = YY;
                if isrow(X)
                    X = X';
                end
                if isrow(Y)
                    Y = Y';
                end
                [X,Y] = deleteDuplicate(X,Y);
                node2 = [X Y];
                node1 = [node1; node2];
            else
               % fprintf('Ups\n')
            end
            %{
             return   
             % generate internal points
             ths = atan2d(node(1,2),node(1,1));
             the = atan2d(node(nnd,2),node(nnd,1));
             if the < ths
                 the = the + 360;
             end
             dr = ds;
             X = [];
             Y = [];
             for r = dr:dr:obj.Rd-dr
                 s = r*(the - ths)*pi/180;
                 npt = fix(s/ds) + 1;
                 dth = (the - ths)/npt;
                 for j = 2:npt
                     k = k + 1;
                     X(k) = r*cosd(j*dth);
                     Y(k) = r*sind(j*dth);
                 end
             end
             if isrow(X)
                 X = X';
             end
             if isrow(Y)
                 Y = Y';
             end
             node1 = [X Y];
             % scatter(X,Y)
             
             else
                 node(nnd + 1,1:2) = [0 0];
        end
            % remove duplicate points
            %[~, I, ~] = unique(node,'first','rows');
            %I = sort(I);
            %node = node(I,:);
            nnd = length(node);
            edge = [(1:(nnd-1))' (2:nnd)'; nnd 1];
            %}
        end
    end
    
    methods (Access = private)
        function plotEnvelope(obj,showTitle,ax,lineSpec,lineProps,colorSpecified,widthSpecified)
            % Plot formation of the tooth (drawing only).
            if showTitle
                title(ax,'Generation of gear tooth','FontWeight','normal','FontSize',12)
            end
            
            % draw characteristic circles
            phi = -180/obj.z;
            drawCircle(0,0,obj.Rr,phi+90,360/obj.z,'r:')
            drawCircle(0,0,obj.Rb,phi + 90,-2*phi,'g:')
            drawCircle(0,0,obj.Rd,phi + 90,-2*phi,'b:')
            drawCircle(0,0,obj.Ra,phi + 90,-2*phi,'m:')
            drawCircle(0,0,obj.Ru,phi + 90,-2*phi,'k:')
            
            % draw profile and label points
            c = ['r','b','g','m'];
            for n = 1:4
                [X,Y] = profil(obj,n,linspace(0,1));
                scatter(X(1),Y(1),30,'k','filled')
                drawText(X(1),Y(1),num2str(n))
                % Use the caller's already separated LineSpec/properties.
                segmentArgs = {};
                if ~colorSpecified, segmentArgs = {'Color',c(n)}; end
                if ~widthSpecified, segmentArgs = [segmentArgs,{'LineWidth',2}]; end
                segmentArgs = [segmentArgs,lineProps];
                if ~isempty(lineSpec), segmentArgs = [{lineSpec},segmentArgs]; end
                drawPolyline( X,Y,segmentArgs{:})
                drawPolyline(-X,Y,segmentArgs{:})
            end
            scatter(X(end),Y(end),30,'k','filled')
            drawText(X(end),Y(end),num2str(n+1))
            
            % draw  path of point 2
            [X,Y] = point2(obj,linspace(0,1,obj.np));
            drawPolyline( X,Y,'k','LineWidth',1)
            drawPolyline(-X,Y,'k','LineWidth',1)
            scatter(X(1),Y(1),30,'k')
            drawText(X(1),Y(1),sprintf('2'''))
            
            % draw rack
            [X,Y] = calcPoints(obj.rack, 1, 0,0);
            X0 = (-obj.R0*sind(phi)+ obj.R0*phi*pi/180*cosd(phi))/cosd(obj.beta);
            Y0 =  (obj.R0*cosd(phi)+ obj.R0*phi*pi/180*sind(phi))/cosd(obj.beta);
            [X,Y] = trRot2d(X/cosd(obj.beta),Y+obj.e,X0,Y0,phi);
            drawPolyline(X,Y,'k:')
            drawCross(2*obj.rack.m,2*obj.rack.m,X0,Y0,phi,'m:')
            
        end
        
    end
    
    % calculation methods
    methods (Access = private)
        function [x,y,dydx,dx,dy,ddx,ddy] = rackSection(obj,n,t)
            % Gear-local parametrisation of the addendum cutoff and flank.
            % The public basic rack always has its full standard height.
            % Only numerical copies of its key-point arrays are changed;
            % no rack property is assigned and no temporary rack is created.
            % The fillet and root segments are inherited without alteration.
            validateattributes(n,{'numeric'},{'>=',1,'<=',4,'integer','scalar'});
            validateattributes(t,{'numeric'},{'real','vector'});
            if n <= 2
                [xx,yy] = calcKeyPoints(obj.rack);
                xx(2) = obj.rack.m*(pi/4 - obj.u*tand(obj.rack.alpha));
                yy(1:2) = obj.rack.m*obj.u;
                x = xx(n) + (xx(n+1)-xx(n))*t;
                y = yy(n) + (yy(n+1)-yy(n))*t;
                dydx = (yy(n+1)-yy(n))/(xx(n+1)-xx(n))*ones(size(t));
                if nargout > 3
                    dx = xx(n+1)-xx(n);
                    dy = yy(n+1)-yy(n);
                    ddx = zeros(size(t));
                    ddy = zeros(size(t));
                end
            elseif nargout > 3
                [x,y,dydx,dx,dy,ddx,ddy] = calcProfile(obj.rack,n,t);
            else
                [x,y,dydx] = calcProfile(obj.rack,n,t);
            end
        end
        function [X,Y] = profil(obj,n,t)
            % calculate points on given segment n
            [xi,eta,dydx] = rackSection(obj,n,t);
            cosb = cosd(obj.beta);
            phi = -(xi + (obj.e + eta)*cosb^2.*dydx)/obj.R0;
            sinp = sin(phi);
            cosp = cos(phi);
            X0 = (obj.R0*phi.*cos(phi) - obj.R0*sin(phi))/cosb;
            Y0 = (obj.R0*cosp + obj.R0*phi.*sinp)/cosb;
            X  = X0 + xi.*cosp/cosb - (eta + obj.e).*sinp;
            Y  = Y0 + xi.*sinp/cosb + (eta + obj.e).*cosp;
        end
        function [X,Y] = profilRelative(obj,n,t)
            % Stable analytical coordinates relative to the common rack
            % corner (flank t=1, fillet t=0), rotated by -phiReference.
            % Avoid subtracting two O(radius) coordinates near a cusp.
            m=obj.rack.m; a=obj.rack.alpha*pi/180; cb=cosd(obj.beta);
            xi0=m*(pi/4+tan(a)); eta0=-m; slope0=-1/tan(a);
            phi0=-(xi0+(obj.e+eta0)*cb^2*slope0)/obj.R0;
            if n==2
                dx=m*(1+obj.u)*tan(a)*(t-1);
                dy=-m*(1+obj.u)*(t-1);
                dslope=zeros(size(t));
            elseif n==3
                rho=m*obj.rack.c/(1-sin(a));
                dtheta=(pi/2-a)*t;
                dx=2*rho*sin(a+dtheta/2).*sin(dtheta/2);
                dy=-2*rho*cos(a+dtheta/2).*sin(dtheta/2);
                dslope=sin(dtheta)./(sin(a)*sin(a+dtheta));
            else
                error('gear:RelativeSegment','Relative coordinates are defined for segments 2 and 3.');
            end
            slope=slope0+dslope;
            dp=-(dx+cb^2*((obj.e+eta0)*dslope+dy.*slope))/obj.R0;
            A0=(obj.R0*phi0+xi0)/cb;
            B0=obj.Rr+eta0+obj.e;
            dA=(obj.R0*dp+dx)/cb;
            cm1=-2*sin(dp/2).^2;
            cp=cos(dp); sp=sin(dp);
            X=A0*cm1-B0*sp+dA.*cp-dy.*sp;
            Y=A0*sp+B0*cm1+dA.*sp+dy.*cp;
        end
        function [dX,dY] = profilRelativeDer(obj,n,t)
            [dx,dy]=profilDer(obj,n,t);
            a=obj.rack.alpha*pi/180; cb=cosd(obj.beta); m=obj.rack.m;
            xi0=m*(pi/4+tan(a));
            phi0=-(xi0+(obj.e-m)*cb^2*(-1/tan(a)))/obj.R0;
            dX=dx*cos(phi0)+dy*sin(phi0);
            dY=-dx*sin(phi0)+dy*cos(phi0);
        end
        function [X,Y] = profil0(obj,phi)
            % calculate point on involute part
            tana = tand(obj.rack.alpha);
            cosb = cosd(obj.beta);
            sinp = sin(phi);
            cosp = cos(phi);
            xi   = -tana^2*phi*obj.R0/(cosb^2+tana^2) + ...
                (pi*obj.rack.m+4*obj.e*tana)*cosb^2/(4*(cosb^2+tana^2));
            eta  = (pi*obj.rack.m/4 - xi)/tana;
            X0   = (obj.R0*phi.*cosp - obj.R0*sinp)/cosb;
            Y0   = (obj.R0*cosp + obj.R0*phi.*sinp)/cosb;
            X    = X0 + xi.*cosp/cosb - (eta + obj.e).*sinp;
            Y    = Y0 + xi.*sinp/cosb + (eta + obj.e).*cosp;
        end
        function [dX,dY] = profilDer(obj,n,t)
            % calculate derivatives of tooth profile
            narginchk(3,3)
            nargoutchk(2,2)
            %check input
            validateattributes(n, {'numeric'}, {'>',0,'<',5,'integer','scalar'});
            validateattributes(t, {'numeric'}, {'real','vector'});
            % calculate derivatives of rack profile
            [xi,eta,dydx,dx,dy,ddx,ddy] = rackSection(obj,n,t);
            cosb = cosd(obj.beta);
            phi  = - (xi + (eta + obj.e)*cosb^2.*dydx)/obj.R0;
            if n==3
                theta=(obj.rack.alpha+(90-obj.rack.alpha)*t)*pi/180;
                slopeDerivative=((90-obj.rack.alpha)*pi/180)./sin(theta).^2;
            else
                slopeDerivative=zeros(size(t));
            end
            % Differentiate phi directly, including the sharp-corner case c=0.
            dp=-(dx+cosb^2*(dy.*dydx+(eta+obj.e).*slopeDerivative))/obj.R0;
            cosp = cos(phi);
            sinp = sin(phi);
            dX   = -((obj.e*cosb + eta*cosb).*cosp + (obj.R0*phi + xi).*sinp).*dp/cosb + ...
                cosp.*dx/cosb - sinp.*dy;
            dY   = ((obj.R0*phi + xi).*cosp/cosb - (obj.e + eta).*sinp).*dp + ...
                sinp.*dx/cosb + cosp.*dy;
        end
        function [dX,dY] = calcTangent(obj,n,t)
            [dX,dY]=profilDer(obj,n,t);
            v=hypot(dX,dY);
            if any(v==0)
                error('gear:SingularTangent','The tangent is undefined at a stationary profile point.');
            end
            dX=-dX./v; dY=-dY./v;
        end
        function val = calcLength(obj)
            % Dimensionless quadrature gives module-independent tolerances.
            val=zeros(4,1);
            for n=1:4
                if obj.te_(n)==obj.ts_(n), continue; end
                val(n)=obj.rack.m*integral(@(t) profileSpeed(obj,n,t)/obj.rack.m, ...
                    obj.ts_(n),obj.te_(n),'AbsTol',1e-12,'RelTol',1e-10);
            end
            if any(~isfinite(val)) || ~isreal(val) || any(val<0)
                error('gear:InvalidArcLength','A retained segment has an invalid arc length.');
            end
        end
        function v=profileSpeed(obj,n,t)
            [dx,dy]=profilDer(obj,n,t);
            v=hypot(dx,dy);
        end
        function [ts,te,review] = calcParam(obj,tipLimit)
            % Tip/circle intersection is analytical. Only the physical
            % involute branch t<=tBase is eligible for the root intersection.
            tana=tand(obj.rack.alpha); cosb=cosd(obj.beta); m=obj.rack.m;
            if obj.Ra<obj.Rb
                error('gear:TipBelowBase','The prescribed tip radius is below the involute base circle.');
            end
            phib=-tana/cosb-(m*pi/4+obj.e*tana)/obj.R0;
            phi=phib+sqrt(max(0,(obj.Ra/obj.Rb)^2-1));
            xi=(-phi*obj.R0*tana^2+(m*pi/4+obj.e*tana)*cosb^2)/(tana^2+cosb^2);
            t20=(m*obj.u*tana-m*pi/4+xi)/(tana*m*(obj.u+1));
            [X,Y]=profil0(obj,phi);
            t11=-obj.R0*atan2(X,Y)/m/(obj.u*tana-pi/4);
            if tipLimit>t20 || t11<0
                t20=tipLimit;
                t11=0;
            end
            tBase=(obj.u+obj.x+obj.z/obj.zmin)/(1+obj.u);
            if abs(tBase-1)<=32*eps(max(1,abs(tBase))), tBase=1; end
            lastPhysical=min(1,tBase);
            if t20>=lastPhysical
                error('gear:NoPhysicalFlank', ...
                    'No surviving involute flank exists between the tip and the physical root limit.');
            end
            if tBase>=1
                % Ordinary smooth junction; never used as a solver fallback.
                t21=1; t30=0;
                [x2,y2]=profil(obj,2,t21); [x3,y3]=profil(obj,3,t30);
                gap=hypot(x2-x3,y2-y3)/m;
                if gap>1e-10 || ~isfinite(gap)
                    error('gear:OpenProfile','The ordinary involute/fillet junction is not continuous.');
                end
                review=struct('status','ordinary junction','gridPoints',0, ...
                    'fsolveCalls',0,'exitflag',NaN,'normalisedResidual',gap, ...
                    'scaledResidual',gap,'equationScale',1, ...
                    'jacobianRcond',NaN,'rangeA',[t20,1],'rangeB',[0,1]);
            else
                [dx0,dy0]=profilRelative(obj,2,lastPhysical);
                eqScale=max(1e-10,min(1,hypot(dx0,dy0)/m));
                [t21,t30,review]=gearProfileIntersection( ...
                    @(t) profilRelative(obj,2,t),@(t) profilRelativeDer(obj,2,t), ...
                    @(t) profilRelative(obj,3,t),@(t) profilRelativeDer(obj,3,t), ...
                    [t20,lastPhysical],[0,1],m,eqScale);
            end
            % Do not continue to t=1 after passing the involute cusp tBase.
            if t21>lastPhysical || t21<t20 || t30<0 || t30>1
                error('gear:WrongInvoluteBranch','The proposed root lies outside the physical profile intervals.');
            end
            ts=[0,t20,t30,0];
            te=[t11,t21,1,1];
        end
        function [X,Y] = calcPoints(obj,nz)
            if nargin<2, nz=obj.z; end
            [X,Y]=calcPoints1(obj,obj.Lt/obj.np,nz,obj.sampling_);
        end
        function [X,Y,info] = calcPoints1(obj,dsmin,nz,sampling)
            if nargin<3, nz=obj.z; end
            if nargin<4, sampling=obj.sampling_; end
            validateattributes(nz,{'numeric'},{'positive','<=',obj.z,'integer','scalar'});
            validateattributes(dsmin,{'numeric'},{'real','finite','scalar','positive'});
            sampling=validatestring(sampling,{'heun','euler'});
            lengths=obj.L; % evaluate numerical lengths only once
            X=[]; Y=[];
            info=struct('sampling',sampling,'targetStep',dsmin, ...
                'segmentParameters',{{}},'segmentCoordinates',{{}}, ...
                'segmentSampling',{{}},'profile',obj.profileInfo_);
            info.segmentParameters=cell(4,1);
            info.segmentCoordinates=cell(4,1);
            info.segmentSampling=cell(4,1);
            for n=1:4
                if lengths(n)==0, continue; end
                ni=max(1,ceil(lengths(n)/dsmin));
                if n==1 || n==4
                    t=linspace(obj.ts_(n),obj.te_(n),ni+1).';
                    si=struct('requestedMethod',sampling,'usedMethod','uniform circle parameter', ...
                        'fallback',false,'reason','','intervals',ni);
                else
                    [t,si]=gearArcLengthSample(@(t) profileSpeed(obj,n,t), ...
                        obj.ts_(n),obj.te_(n),ni,sampling,lengths(n));
                end
                [XX,YY]=profil(obj,n,t); XX=XX(:); YY=YY(:);
                info.segmentParameters{n}=t;
                info.segmentCoordinates{n}=[XX YY];
                info.segmentSampling{n}=si;
                if ~isempty(X)
                    gap=hypot(XX(1)-X(end),YY(1)-Y(end))/obj.rack.m;
                    if gap>1e-9
                        error('gear:OpenProfile','Sampled segments do not meet; no artificial bridge was inserted.');
                    end
                    % One shared vertex, not a short extra connector.
                    XX=XX(2:end); YY=YY(2:end);
                end
                X=[X;XX]; Y=[Y;YY];
            end
            if isempty(X) || any(~isfinite([X;Y])) || ~isreal([X;Y])
                error('gear:InvalidContour','The sampled contour is not finite and real.');
            end
            if obj.te_(1)==obj.ts_(1)
                if abs(X(1))/obj.rack.m>1e-9
                    error('gear:OpenTip','The pointed tip does not lie on the symmetry axis.');
                end
                X(1)=0; % weld the analytically shared symmetric tip to roundoff
            end
            xt=[-flipud(X);X]; yt=[flipud(Y);Y];
            X=[]; Y=[];
            for k=0:nz-1
                th=k*360/obj.z;
                xr=xt*cosd(th)-yt*sind(th); yr=xt*sind(th)+yt*cosd(th);
                X=[xr;X]; Y=[yr;Y];
            end
            [X,Y]=deleteDuplicate(X,Y,obj.rack.m);
            X=flipud(X); Y=flipud(Y);
            if nz<obj.z && nz>2
                th=-360/obj.z;
                xr=X*cosd(th)-Y*sind(th); Y=X*sind(th)+Y*cosd(th); X=xr;
            end
        end
        function R = calcRadius(obj)
            % calculate radius corespond to the key points
            %[ts,te] = calcParam(obj);
            for n = 1:4
                [X,Y] = profil(obj,n,[obj.ts_(n),obj.te_(n)]);
                R(2*n-1:2*n) = sqrt(X.^2 + Y.^2);
            end
        end

    end
    
    % calculation of tooth thickness
    methods (Access = private)
        function s = toothThickness(obj,R)
            % tooth thickness in involute segment
            tana  = tand(obj.rack.alpha);
            cosb  = cosd(obj.beta);
            phib  = -tana/cosb - 1/obj.R0*(obj.rack.m*pi/4 + obj.e*tana);
            phi   = phib+sqrt((R/obj.Rb)^2 - 1);
            [X,Y] = profil0(obj,phi);
            theta = atan(X/Y);
            s = 2*R*theta;
        end
        function s = toothThickness1(obj,R)
            % numerical calculation of tooth thickness
            validateattributes(R,{'numeric'},{'>=',obj.Rd,'<=',obj.Ra,'real','scalar'});
            s = NaN;
            if R == obj.Ra
                n = 2;
                t = obj.ts_(n);
            elseif R == obj.Rd
                n = 4;
                t = obj.ts_(n);
            elseif R == obj.Ru
                n = 2;
                t = obj.te_(2);
            else
                if R > obj.Ru
                    n = 2;
                    try
                        %==============================
                        t = mfzero(@fun,[obj.ts_(n),obj.te_(n)]);
                        %==============================
                    catch
                        return
                    end
                else
                    n = 3;
                    try
                        %==============================
                        t = mfzero(@fun,[obj.ts_(n),obj.te_(n)]);
                        %===============================
                    catch
                        return
                    end
                end
            end
            [X,Y] = profil(obj,n,t);
            theta = atan(X/Y);
            s = 2*R*theta;
            function val = fun(t)
                [X,Y] =  profil(obj,n,t);
                val = X^2 + Y^2 - R^2;
            end
        end
    end
    
    % var. methods
    methods (Access = private)
        function [x,y] = point2(obj,t)
            % calculate a path of rack point #2
            xx = obj.rack.m*(pi/4 - obj.u*tand(obj.rack.alpha));
            yy = obj.u*obj.rack.m;
            dydx = -t/tand(obj.rack.alpha);
            phi = -(xx + (obj.e + yy)*cosd(obj.beta)^2.*dydx)/obj.R0;
            x   = (-(obj.R0 + (obj.e + yy)*cosd(obj.beta)).*sin(phi) + ...
                (obj.R0*phi + xx).*cos(phi))/cosd(obj.beta);
            y   = ( (obj.R0 + (obj.e + yy)*cosd(obj.beta)).*cos(phi) + ...
                (obj.R0*phi + xx).*sin(phi))/cosd(obj.beta);
        end
        function [x,y] = rackContactDisplaySection(obj,n,t)
            % Odseki, prikazani NA osnovni nespremenjeni letvi.
            %
            % To ni isto kot gear-local rackSection, ki uporablja virtualno
            % skrajšano letev za geometrijo zobnika.

            validateattributes(n,{'numeric'},{'>=',1,'<=',4,'integer','scalar'});
            validateattributes(t,{'numeric'},{'real','vector'});

            switch n
                case 1
                    % Zgornji kontaktni/cutoff odsek naj ostane na vrhu osnovne letve.
                    m = obj.rack.m;
                    a = obj.rack.alpha;

                    x1 = 0;
                    x2u = m*(pi/4 - obj.u*tand(a));   % skrajšani desni konec
                    x = x1 + (x2u - x1).*t;
                    y = m*ones(size(t));              % pomembno: vrh osnovne letve

                case 2
                    % Flankni odsek lahko ostane iz rackSection, ker leži na isti premici.
                    [x,y] = rackSection(obj,2,t);

                case 3
                    % Fillet osnovne letve je nespremenjen.
                    [x,y] = calcProfile(obj.rack,3,t);

                case 4
                    % Root odsek osnovne letve je nespremenjen.
                    [x,y] = calcProfile(obj.rack,4,t);
            end
        end
    end
    
    methods 
        function [r,tc] = calcRc(obj)
            % Pointed limit from psi-atan(psi)=-phi0 on psi>=0.
            tana=tand(obj.rack.alpha); cosb=cosd(obj.beta); m=obj.rack.m;
            phib=-tana/cosb-(m*pi/4+obj.e*tana)/obj.R0;
            phi0=phib+atan(tana/cosb);
            target=-phi0;
            if ~isfinite(target) || target<=0
                error('gear:NoPositiveToothThickness','The base-circle tooth half-thickness is not positive.');
            end
            hi=max(1,target+pi/2);
            psi=fzero(@(q) q-atan(q)-target,[0,hi],optimset('Display','off','TolX',1e-12));
            r=obj.Rb*hypot(1,psi);
            phi=phib+psi;
            xi=(-phi*obj.R0*tana^2+(m*pi/4+obj.e*tana)*cosb^2)/(tana^2+cosb^2);
            tc=(m*obj.u*tana-m*pi/4+xi)/(tana*m*(obj.u+1));
        end
        function val = calcXmax(obj)
            % max. profile shif coefficient
            tana = tand(obj.rack.alpha);
            cosb = cosd(obj.beta);
            %find interval
            phi0=acot(tana/cosb);
            % solve equation
            try
                %===================================
                phi = mfzero(@fun,[0,0.99*phi0]);
                %==================================
                val = -1/tana*(obj.R0*(phi - sin(phi)*...
                    (cosb^2 + tana^2)/cosb/(cosb*cos(phi) - tana*sin(phi)))...
                    + pi*obj.rack.m/4);
            catch
                val = NaN;
            end
            function f = fun(phi)
                cosp = cos(phi);
                sinp = sin(phi);
                a1 = ((1 - cosp)*tana - cosb*sinp)./(cosb*cosp - tana*sinp);
                a2 = obj.rack.m/obj.R0*(pi/4 - obj.u*tana);
                f = phi + a1 + a2;
            end
        end
    end
    
end

function x = mfzero( fun, x0)
% Wrapper to fzero
    x = fzero(fun,x0);
end

function [dd,mm,ss] = deg2dms(deg)
%DMS2DEG  Convert decimal degrees to ddd:mm:ss
    dd = fix(deg);
    mm = fix((deg - dd)*60); 
    ss = round((deg - dd - mm/60)*3600,2);
    if ss > 59.9999
        mm = mm + 1;
        ss = 0;
    end
    if mm == 60
        dd = dd + 1;
        mm = mm - 60;
    end
end

function [x,y] = deleteDuplicate(X,Y,scale)
%DELETEDUPLICATE Delete duplicate entries in X,Y arrays which forms a
%contour
    narginchk(2,3)
    if nargin<3
        scale=max([hypot(max(X)-min(X),max(Y)-min(Y)),realmin]);
    end
    tol=max(1e-12*scale,64*eps(max([abs(X(:));abs(Y(:));realmin])));
    if isempty(X), x=X; y=Y; return; end
    nargoutchk(2,2)
    validateattributes(X, {'numeric'}, {'real','vector'});
    validateattributes(Y, {'numeric'}, {'real','vector'}); 
    if ~isequal(size(X),size(Y))
        error('Arrays must be of the same size.')
    end
    np = length(X);
    x  = nan(size(X));
    y  = nan(size(Y));
    k  = 1;
    x(1) = X(1);
    y(1) = Y(1);
    for n = 2:np 
        if (X(n) - x(k))^2 + (Y(n) - y(k))^2 < tol^2
            continue
        end
        k = k + 1;
        x(k) = X(n);
        y(k) = Y(n);        
    end
    if (x(1) - x(k))^2 + (y(1) - y(k))^2 < tol^2
        k = k - 1;
    end
    x = x(1:k);
    y = y(1:k);
end




function restoreGearAxes(ax,value)
% Restore overlay hold state; no option parsing is performed here.
if isgraphics(ax,'axes')
    set(ax,'NextPlot',value);
end
end
