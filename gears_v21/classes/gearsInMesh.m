classdef gearsInMesh < handle
    %GEARSINMESH Assemble and display two existing gear objects.
    %
    %   GM = gearsInMesh(G1,G2)
    % The source gears are shared handles, not copied or modified by construction.
    % Use equal normal rack modules/pressure angles and equal nonnegative
    % helix-angle magnitudes. This is a parallel-axis, zero-backlash geometry.
    % Each gear owns its independent u; the basic rack remains unchanged.
    % Public properties include G1, G2, a, alphaw, cw, Rw1, Rw2, Lc,
    % epsalpha, invalid and optimizationInfo. Dependent outputs are refreshed.
    % Lc and epsalpha are nominal tip-circle values; they are not an undercut,
    % interference or load-capacity certificate.
    %
    % Static display and numerical output:
    %   plot(GM,'th1',15,'np',40,'title',false,'save','figures/pair')
    %   plot(GM,'zoom',3,'title',true)  % local enlarged view
    %   print(GM); print(GM,fid)       % fid is an open text-file ID
    %   printOptimization(GM); printOptimization(GM,fid) % reporting only
    % No optimisation routine is included. With an empty optimizationInfo,
    % printOptimization reports the current pair without an optimisation record.
    % 'save',[]: Fig<number>.jpg; named save: JPG at 300 dpi.
    % 'title': on/off, 1/0 or true/false; default on. Bare save is retained.
    %
    % Animation (2-D transverse geometry):
    %   animate(GM,'mode','automatic','nr',0.3,'dth1',1,'fps',30)
    %   animate(GM,'mode','interactive','contactPoints',true, ...
    %       'figureSize',[1000 700],'title',false, ...
    %       'snapshot','figures/pair')
    %   animate(GM,'nr',0.3,'save','movies/pair.avi')
    % L/D: forward/backward gear steps; P: numbered JPG snapshot;
    % Esc: finish; H: help. Space pauses/resumes automatic mode.
    % Instructions default on; 'instructions',false or 'echo','off' hides them.
    % 'save',[] in animate selects gearsInMesh.avi, not a still image.
    % 'snapshot',[] selects Fig<number>_0001.jpg; no file until P is pressed.
    % figureSize here is [W H] or [left bottom W H], not a scalar.
    % 'step',true is the legacy alias for interactive mode. Prefix '-' is accepted.
    % Contact markers use the retained involutes, not polygon intersections;
    % root/fillet collisions, elasticity and face-width overlap are not checked.
    %
    % For a 3-D view, use S = gear3d(GM); plot(S) or animate(S,...).
    % All required draw*/gk* and numerical helpers are in classes/private.
    % Private helpers do not need a separate path entry.
    % Use runMeFirst once. Examples: examples/meshing; documentation: doc/.

    properties
        G1      % gear 1
        G2      % gear 2
        optimizationInfo = struct([]) % result record; treat as read-only
    end

    properties (Dependent)
        a      % center distance
        alphaw % working pressure angle in degrees
        cw     % working tip tooth clearance
        Rw1    % working pitch circle radius for gear 1
        Rw2    % working pitch circle radius for gear 2
        Lc     % NOMINAL transverse involute path of contact
        epsalpha % NOMINAL transverse contact ratio; not axial overlap
        invalid
    end
    properties (Access = private)
        a_
        alphaw_
        cw_
        invalid_ % set to true if fail to calculate a_
        Rw1_
        Rw2_
        Lc_
        epsalpha_
    end
    
        
    methods
        function obj = gearsInMesh(G1,G2)
            if ~(isa(G1,'gear') && isa(G2,'gear'))
                error('Input must be gear objects.')
            end
            if G1.rack.m ~= G2.rack.m || G1.rack.alpha ~= G2.rack.alpha
                error('Gears in mesh must have the same rack.')
            end
            obj.G1 = G1;
            obj.G2 = G2;
            ainit(obj)
        end
        
    end
    
    methods (Access = private)
        function ainit(obj)
            % Normal rack angle -> transverse working angle. Equal shifts
            % are NOT equivalent to a zero sum of shifts.
            obj.alphaw_ = workingPressureAngle(obj.G1.rack.alpha,...
                obj.G1.z,obj.G2.z,obj.G1.x,obj.G2.x,obj.G1.beta);
            obj.a_ = (obj.G1.Rb + obj.G2.Rb)/cosd(obj.alphaw_);
            obj.invalid_ = ~isreal(obj.a_) || ~isfinite(obj.a_) ...
                || obj.a_ <= 0 || obj.a_ > obj.G1.Ra + obj.G2.Ra;
            if obj.invalid_
                warning('gearsInMesh:InvalidCenterDistance',...
                    'Invalid center distance. Set to default. Correct profile shifts.');
                obj.a_ = obj.G1.Rr + obj.G2.Rr;
                obj.alphaw_ = atand(tand(obj.G1.rack.alpha)/cosd(obj.G1.beta));
            end
            % The smaller radial tip/root clearance governs the pair;
            % u1 and u2 need not be equal. All radii already carry units.
            obj.cw_ = min(obj.a_ - obj.G1.Rd - obj.G2.Ra,...
                          obj.a_ - obj.G2.Rd - obj.G1.Ra);
            obj.Rw1_ = obj.G1.Rb/cosd(obj.alphaw_);
            obj.Rw2_ = obj.G2.Rb/cosd(obj.alphaw_);
            % Nominal transverse involute contact length. This expression
            % assumes the full tip-to-tip contact lies on usable involutes.
            % These nominal values do not certify that assumption for an
            % undercut pair. No optimisation routine is included here.
            q1 = obj.G1.Ra^2 - obj.G1.Rb^2;
            q2 = obj.G2.Ra^2 - obj.G2.Rb^2;
            if isreal([q1 q2]) && all(isfinite([q1 q2])) && q1 >= 0 && q2 >= 0
                obj.Lc_ = sqrt(q1) + sqrt(q2) - obj.a_*sind(obj.alphaw_);
                pb = 2*pi*obj.G1.Rb/obj.G1.z;
                obj.epsalpha_ = obj.Lc_/pb;
            else
                obj.Lc_ = NaN;
                obj.epsalpha_ = NaN;
            end
        end
    end
    

    methods
        function out = get.a(obj)
            ainit(obj); % member gears can change independently
            out = obj.a_;
        end
        function out = get.alphaw(obj)
            ainit(obj); % member gears can change independently
            out = obj.alphaw_;
        end
        function out = get.cw(obj)
            ainit(obj); % member gears can change independently
            out = obj.cw_;
        end
        function out = get.Rw1(obj)
            ainit(obj); % member gears can change independently
            out = obj.Rw1_;
        end
        function out = get.Rw2(obj)
            ainit(obj); % member gears can change independently
            out = obj.Rw2_;
        end
        function out = get.Lc(obj)
            ainit(obj);
            out = obj.Lc_;
        end
        function out = get.epsalpha(obj)
            ainit(obj);
            out = obj.epsalpha_;
        end
        function out = get.invalid(obj)
            ainit(obj); % member gears can change independently
            out = obj.invalid_;
        end        
    end
    
    methods
        function plot(obj,varargin)
            %PLOT Draw the pair in a specified position.
            % 'lineWidth',positive width; 'lineColor',color; LineSpec accepted.
            % 'a',distance; 'zoom',factor (0 or >=2); 'th1',angle in degrees;
            % 'np',points (4..100). All names accept a leading '-'.
            % 'title',on/off/1/0/true/false controls the title (default on).
            % 'save',[] -> Fig<number>.jpg; 'save',filename -> named JPG.
            % Legacy bare 'save' is retained.
            narginchk(1,inf)
            nargoutchk(0,0)
            [opt,lineArgs] = parseGearPlotOptions('pair',varargin);
            ainit(obj);
            m = obj.G1.rack.m;
            sz = m/4;
            fc = opt.zoom;
            aa = opt.a;
            if isempty(aa), aa = obj.a_; end
            th1 = opt.th1;
            np = opt.np;
            save = opt.save;
            th2 = -th1*obj.G1.Rr/obj.G2.Rr;
            
            [X1,Y1] = gearContour(obj.G1,'-np',np);
            [X2,Y2] = gearContour(obj.G2,'-np',np);
            
            [X1,Y1] = trRot2d(X1,Y1,0,0, -90);
            [X2,Y2] = trRot2d(X2,Y2,0,0,  90);
            [X2,Y2] = trRot2d(X2,Y2,0,0,  180/obj.G2.z);
            
            [X1,Y1] = trRot2d(X1,Y1,0,0,  th1);
            [X2,Y2] = trRot2d(X2,Y2,0,0,  th2);
            
            [~,fh,ax] = drawInit;
            set(fh,'Position',[100 100 600 600],'Tag','gearsInMesh.Pair');
            set(groot,'CurrentFigure',fh);
            set(fh,'CurrentAxes',ax);
            drawSet('LineWidth',2,'LineColor','k');
            pairStyle = gearLineOptions('k',2,lineArgs);
            drawPolyline(X2+aa,Y2,pairStyle{:})
            drawPolyline(X1,Y1,pairStyle{:})
            drawPoint(1,sz,0,0)
            drawPoint(1,sz,aa,0)
            if opt.title
                title(ax,sprintf('m = %g, z_1 = %g, z_2 = %g, x_1 + x_2 = %g, a = %g',...
                    m,obj.G1.z,obj.G2.z,obj.G1.x+obj.G2.x,aa),...
                    'FontSize',12,'FontWeight','normal')
            else
                title(ax,'');
            end
            if fc > 0
                xmin = -fc*m+obj.G1.Rr;
                xmax = fc*m + obj.G1.Rr;
                ymin = -fc*m;
                ymax = fc*m;
                drawLimits(xmin,xmax,ymin,ymax)
            end
            axis(ax,'off');
            if save
                fn = drawSave(opt.fileName,'fig',fh);
                fprintf('Figure is saved in file %s\n',fn)
            end            
        end
    end

    methods
        function animate(obj,varargin)
            %ANIMATE Automatic playback or interactive inspection of a gear pair.
            % animate(GM,'mode','automatic',...)   % default: stop after nr turns
            % animate(GM,'mode','interactive',...) % L forward, D backward, Esc exit
            % 'figureSize',[width height] or [left bottom width height], pixels;
            % 'contactPoints',on/off/1/0/true/false (default false);
            % 'instructions',on/off/1/0/true/false (default true; alias 'echo');
            % 'title',on/off/1/0/true/false (default true);
            % 'save',[] -> gearsInMesh.avi; 'save',filename -> named AVI.
            % Interactive P exports the displayed figure as a 300-dpi JPG.
            % 'snapshot',[] -> Fig<number>_0001.jpg; 'snapshot',stem -> stem_0001.jpg.
            % Repeated P uses the next free suffix; existing files are not overwritten.
            % 'th1',initial angle [deg]; 'dth1',nonzero signed step [deg];
            % 'nr',positive number of automatic turns; 'fps',frame rate;
            % 'a',center distance; 'zoom',0 or >=2; 'np',points (4..100);
            % 'fig',figure number; 'lineWidth',width; 'lineColor',MATLAB color.
            % Names accept a leading '-'. Legacy 'step',true means interactive.
            % Interactive mode waits until Esc/close: nr is not a click budget.
            % L adds dth1 and D subtracts it. Left/right mouse buttons do the same.
            % Space pauses automatic playback. Keys require figure focus.
            % Contact markers are transverse geometric involute contacts only.
            narginchk(1,inf)
            nargoutchk(0,0)
            opt = struct('mode','automatic','step',false,'a',[],'zoom',0, ...
                'np',20,'dth1',1,'th1',0,'nr',1,'fps',30,'fig',[], ...
                'figureSize',[600 600],'contactPoints',false,'instructions',true, ...
                'title',true,'save',false,'fileName',[],'snapshot',[], ...
                'lineWidth',[],'lineColor',[]);
            explicitMode = ''; legacyStep = [];
            known = {'mode','step','a','zoom','fc','np','nn','dth1','th1','nr', ...
                'fps','framerate','fig','figuresize','contactpoints','contacts', ...
                'instructions','echo','title','save','snapshot','notxt','notext', ...
                'linewidth','linecolor','color'};
            k = 1;
            while k <= numel(varargin)
                name = varargin{k};
                if isa(name,'string') && isscalar(name) && ~ismissing(name)
                    name = char(name);
                end
                if ~ischar(name) || ~isrow(name) || isempty(name)
                    error('gears:GraphicsOptionName','Expected a nonempty option name.');
                end
                key = lower(name);
                if key(1)=='-', key=key(2:end); end
                if ~any(strcmp(key,known))
                    error('gears:UnknownGraphicsOption','Unknown animation option: %s.',name);
                end
                if ~any(strcmp(key,{'save','notxt','notext'}))
                    if k==numel(varargin)
                        error('gears:MissingGraphicsValue','A value is required after ''%s''.',name);
                    end
                    value = varargin{k+1};
                end
                switch key
                    case 'save'
                        opt.save = true; opt.fileName = [];
                        if k < numel(varargin)
                            candidate = varargin{k+1};
                            if isnumeric(candidate) && isempty(candidate)
                                k = k+1;
                            else
                                if isa(candidate,'string') && isscalar(candidate) && ~ismissing(candidate)
                                    candidate = char(candidate);
                                end
                                if ~ischar(candidate) || (~isrow(candidate) && ~isempty(candidate))
                                    error('gears:SaveFilename','Use ''save'',[] or ''save'',filename.');
                                end
                                nextKey=lower(candidate);
                                if ~isempty(nextKey) && nextKey(1)=='-', nextKey=nextKey(2:end); end
                                if ~any(strcmp(nextKey,known))
                                    opt.fileName=candidate;
                                    k=k+1;
                                end
                            end
                        end
                    case 'snapshot'
                        if isnumeric(value) && isempty(value)
                            opt.snapshot=[];
                        else
                            if isa(value,'string') && isscalar(value) && ~ismissing(value)
                                value=char(value);
                            end
                            if ~ischar(value) || (~isempty(value) && ~isrow(value))
                                error('gearsInMesh:SnapshotFilename', ...
                                    'Use ''snapshot'',[] or ''snapshot'',filenameStem.');
                            end
                            if ~isempty(value)
                                [~,base,~]=fileparts(value);
                                if isempty(base) || any(strcmp(base,{'.','..'}))
                                    error('gearsInMesh:SnapshotFilename', ...
                                        'A snapshot filename stem, not only a folder, is required.');
                                end
                            end
                            opt.snapshot=value;
                        end
                        k=k+1;
                    case {'notxt','notext'}
                        opt.title = false;
                    case 'mode'
                        if isa(value,'string') && isscalar(value) && ~ismissing(value), value=char(value); end
                        if ~ischar(value) || ~isrow(value)
                            error('gearsInMesh:AnimationMode','Mode must be automatic or interactive.');
                        end
                        switch lower(strtrim(value))
                            case {'automatic','auto'}, explicitMode='automatic';
                            case {'interactive','manual'}, explicitMode='interactive';
                            otherwise
                                error('gearsInMesh:AnimationMode','Mode must be automatic or interactive.');
                        end
                        opt.mode=explicitMode; k=k+1;
                    case {'step','title','contactpoints','contacts','instructions','echo'}
                        if isa(value,'string') && isscalar(value) && ~ismissing(value), value=char(value); end
                        if ischar(value) && isrow(value)
                            switch lower(strtrim(value))
                                case 'on', value=true;
                                case 'off', value=false;
                                otherwise, value=[];
                            end
                        end
                        if ~((isnumeric(value)||islogical(value)) && isscalar(value) ...
                                && isreal(value) && isfinite(value) && (value==0 || value==1))
                            error('gears:InvalidOnOff','''%s'' must be on/off, 1/0 or true/false.',name);
                        end
                        value=logical(value);
                        switch key
                            case 'step', legacyStep=value;
                            case 'title', opt.title=value;
                            case {'contactpoints','contacts'}, opt.contactPoints=value;
                            otherwise, opt.instructions=value;
                        end
                        k=k+1;
                    case 'figuresize'
                        validateattributes(value,{'numeric'},{'real','finite','vector'});
                        if ~ismember(numel(value),[2 4]) || any(value(end-1:end)<=0) ...
                                || any(value(end-1:end)~=fix(value(end-1:end)))
                            error('gearsInMesh:FigureSize', ...
                                'figureSize must be [width height] or [left bottom width height], with positive integer dimensions.');
                        end
                        opt.figureSize=double(value(:).'); k=k+1;
                    case {'a','nr','fps','framerate','linewidth'}
                        validateattributes(value,{'numeric'},{'real','finite','scalar','positive'});
                        switch key
                            case 'a', opt.a=double(value);
                            case 'nr', opt.nr=double(value);
                            case 'linewidth', opt.lineWidth=double(value);
                            otherwise, opt.fps=double(value);
                        end
                        k=k+1;
                    case {'zoom','fc'}
                        validateattributes(value,{'numeric'},{'real','finite','scalar','nonnegative'});
                        if value~=0 && value<2
                            error('gears:InvalidZoom','Zoom must be 0 or at least 2.');
                        end
                        opt.zoom=double(value); k=k+1;
                    case {'np','nn'}
                        validateattributes(value,{'numeric'},{'real','finite','scalar','integer','>=',4,'<=',100});
                        opt.np=double(value); k=k+1;
                    case 'fig'
                        validateattributes(value,{'numeric'},{'real','finite','scalar','positive','integer'});
                        opt.fig=double(value); k=k+1;
                    case 'th1'
                        validateattributes(value,{'numeric'},{'real','finite','scalar'});
                        opt.th1=double(value); k=k+1;
                    case 'dth1'
                        validateattributes(value,{'numeric'},{'real','finite','scalar','nonzero'});
                        opt.dth1=double(value); k=k+1;
                    case {'linecolor','color'}
                        if isa(value,'string') && isscalar(value) && ~ismissing(value), value=char(value); end
                        if isnumeric(value)
                            validateattributes(value,{'numeric'},{'real','finite','vector','numel',3,'>=',0,'<=',1});
                            value=double(value(:).');
                        elseif ~ischar(value) || ~isrow(value) || isempty(value)
                            error('gearsInMesh:LineColor','lineColor must be a MATLAB color name or RGB triplet.');
                        end
                        opt.lineColor=value; k=k+1;
                end
                k=k+1;
            end
            if ~isempty(legacyStep)
                stepMode='automatic';
                if legacyStep, stepMode='interactive'; end
                if ~isempty(explicitMode) && ~strcmp(explicitMode,stepMode)
                    error('gearsInMesh:ConflictingAnimationMode','Options mode and step disagree.');
                end
                opt.mode=stepMode;
            end
            opt.step=strcmp(opt.mode,'interactive');
            ainit(obj);
            if isempty(opt.a), opt.a=obj.a_; end
            animateGearPair(obj,opt);
        end
    end

    methods
        function  print(obj,fid)
            if nargin < 2
                fid = 1;
            end
            ainit(obj);
            fprintf(fid,'\nGears in mesh\n');
            %a  = centerDistance(obj.G1.rack.alpha,obj.G1.rack.m,...
            %    obj.G1.z,obj.G2.z,obj.G1.x,obj.G2.x,obj.G1.beta);
            %aw = workingPressureAngle(obj.G1.rack.alpha,...
            %    obj.G1.z,obj.G2.z,obj.G1.x,obj.G2.x);
            fprintf(fid,'                               Number of teeth:%12d%12d\n',obj.G1.z,obj.G2.z);
            fprintf(fid,'                                        Module:%18.4f       mm\n',obj.G1.rack.m);
            fprintf(fid,'                       Standard pressure angle:%18.4f       \n',obj.G1.rack.alpha);
            fprintf(fid,'                   Tip clearance coefficient c:%18.4f\n',obj.G1.rack.c);
            fprintf(fid,'                               Center distance:%18.4f       \n',obj.a);  
            fprintf(fid,'                    Tip shortening coefficient:%12.4f%12.4f\n',obj.G1.u,obj.G2.u);            
            fprintf(fid,'                        Working pressure angle:%18.4f       \n',obj.alphaw);
            fprintf(fid,'         Sum of the profile shift coefficients:%18.4f       \n',obj.G1.x+obj.G2.x);
            fprintf(fid,'                    Profile shift coefficients:%12.4f%12.4f\n',obj.G1.x,obj.G2.x);            
            fprintf(fid,'Calculated parameters\n');
            fprintf(fid,'               Reference pitch circle diameter:%12.4f%12.4f mm\n',2*obj.G1.Rr,2*obj.G2.Rr);
            fprintf(fid,'                 Working pitch circle diameter:%12.4f%12.4f mm\n',2*obj.Rw1,2*obj.Rw2);
            fprintf(fid,'              Nominal addendum circle diameter:%12.4f%12.4f mm\n',2*obj.G1.Ra,2*obj.G2.Ra);
            if obj.G1.profileInfo.pointedTip || obj.G2.profileInfo.pointedTip
                fprintf(fid,'                         Retained tip diameter:%12.4f%12.4f mm\n', ...
                    2*(obj.G1.Rr+obj.G1.ha),2*(obj.G2.Rr+obj.G2.ha));
            end
            fprintf(fid,'                      Dedendum circle diameter:%12.4f%12.4f mm\n',2*obj.G1.Rd,2*obj.G2.Rd);
            fprintf(fid,'                          Base circle diameter:%12.4f%12.4f mm\n',2*obj.G1.Rb,2*obj.G2.Rb);
            fprintf(fid,'                   Working tip tooth clearance:%18.4f       \n',obj.cw_);            
            fprintf(fid,' Tooth thickness at the reference pitch circle:%12.4f%12.4f mm\n',obj.G1.sr,obj.G2.sr);
            fprintf(fid,'            Tooth thickness at the base circle:%12.4f%12.4f mm\n',obj.G1.sb,obj.G2.sb);
            fprintf(fid,'                           Tip tooth thickness:%12.4f%12.4f mm\n',obj.G1.sa,obj.G2.sa);
            fprintf(fid,'                       Nominal path of contact:%18.4f       mm\n',obj.Lc);
            fprintf(fid,'%46s%18.4f       \n','Nominal transverse contact ratio:',obj.epsalpha);
            fprintf(fid,'Notes\n');
            fprintf(fid,'\tNominal values use tip circles; form/undercut limits are not applied.\n');
            if obj.invalid_
                fprintf(fid,'\tWarning: center distance and working pressure angle are invalid.\n');
                fprintf(fid,'\t Adjust profile shifts.\n');
            end
            flags1 = gearToothStatus(obj.G1);
            flags2 = gearToothStatus(obj.G2);
            if flags1.undercut || flags2.undercut
                fprintf(fid,'\tUndercutting can shorten actual contact; nominal ratio is not a design pass.\n');
            end
            if obj.G1.beta > 0 || obj.G2.beta > 0
                fprintf(fid,'\tTransverse ratio only; face-width overlap is not included.\n');
            end
            printGearTipRatio(obj.G1,fid,'gear 1');
            printGearTipRatio(obj.G2,fid,'gear 2');
            printGearToothWarnings(obj.G1,fid,'gear 1');
            printGearToothWarnings(obj.G2,fid,'gear 2');
            fprintf(fid,'\tTooth-root strength: NOT ASSESSED (also for non-undercut teeth).\n');
        end
    end
    
    methods
        function printOptimization(obj,fid)
            %PRINTOPTIMIZATION Report current pair and any stored result record.
            % printOptimization(GM) or printOptimization(GM,fid).
            % This method reports data; it does not perform optimisation.
            % With empty optimizationInfo it reports the current geometry only.
            % Geometry changes invalidate the stored verification status.
            narginchk(1,2)
            nargoutchk(0,0)
            if nargin < 2
                fid = 1;
            end
            validateattributes(fid,{'numeric'},...
                {'finite','real','scalar','integer','positive'});
            ainit(obj);
            printGearOptimizationReport(obj,fid);
        end
    end

end

function alphaw = workingPressureAngle(alpha,z1,z2,x1,x2,beta)
% alpha is the normal rack pressure angle; alphaw is transverse.
% Solve the inverse involute on its unique nonnegative branch.
t = tand(alpha)/cosd(beta);
alphaT = atand(t);
v = invTangent(t) + 2*tand(alpha)*(x1+x2)/(z1+z2);
if ~isfinite(v) || v < 0
    alphaw = NaN;
    return
end
if x1+x2 == 0
    alphaw = alphaT;
    return
end
if v == 0
    alphaw = 0;
    return
end
lo = 0;
hi = v+pi/2;
for k = 1:56
    p = (lo+hi)/2;
    if invTangent(p) < v
        lo = p;
    else
        hi = p;
    end
end
alphaw = atand((lo+hi)/2);
end

function v = invTangent(p)
% Stable evaluation close to the zero-angle endpoint.
if abs(p) < 1e-3
    q = p*p;
    v = p*q*(1/3-q*(1/5-q*(1/7-q/9)));
else
    v = p-atan(p);
end
end
