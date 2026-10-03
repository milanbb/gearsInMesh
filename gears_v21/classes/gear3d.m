classdef gear3d < handle
    %GEAR3D Closed 3-D display of an external gear or gearsInMesh pair.
    % Core draw*/gk* and int2crv helpers are bundled in classes/private.
    % Do not add private to the path.
    % Use runMeFirst; examples are in examples/3d.
    % Bare names save in Current Folder; relative subfolders are optional.
    %
    %   s = gear3d(g)                   % one scalar gear object
    %   s = gear3d(GM)                  % one scalar gearsInMesh object
    %   s = gear3d(GM,'width',[4 5])   % independent face widths
    %   plot(s,'th1',15,'axes',false) % gear 2 follows the pair ratio
    %   s = gear3d(g,'width',5)         % axial face width, same units as g
    %   plot(s,'axes','off','view',[135 25], ...
    %          'figureSize',[1000 700],'export','figures/gear3d')
    %   [fh,ax,h] = plot(s,...)         % optional figure/axes/patch handles
    %   [V,F,info] = mesh(s)            % vertices and oriented triangles
    %
    % With no output, gear3d(g,...) constructs AND plots the object.
    % Constructor options become defaults for plot. Plot overrides are local.
    % Name-value options accept a leading '-', with case-insensitive names.
    %   width/faceWidth : positive length; [b1 b2] also allowed for a pair;
    %                     default 5*normal module (display only)
    %   th1             : gear-1/single-gear rotation, degrees; default 0. Gear 2
    %                     follows -th1*G1.Rr/G2.Rr; not independently adjustable
    %   axes            : on/off, 1/0, true/false; default off
    %   view            : [azimuth elevation] in degrees or [vx vy vz];
    %                     also 2 (top) or 3 (standard 3-D); default [-37.5 30]
    %   figureSize      : s -> [s s], [W H], or [left bottom W H], pixels
    %                     default [540 540]; [] resets that default
    %   export          : [] or 'jpg' -> Fig<number>.jpg; text -> filename
    %                     false disables export; missing option means no file
    %   title           : on/off, 1/0, true/false; geometric header, default off
    %   interactive     : plot-only flag, default true; false disables view controls
    %   lineWidth       : width of visible edges in points, default 0.5
    %   color1/color2   : per-gear face colors; aliases faceColor1/faceColor2
    %   edgeColor1/2    : per-gear edge colors; [] uses the common setting
    %   print           : P-key JPG export: true/on (default), false/off,
    %                     [] (default filename), or a filename stem
    %   snapshot        : synonym for print; numbered JPGs do not overwrite
    %   instructions    : startup/export messages, on/off; default on (alias echo)
    %   np              : contour resolution passed to gearContour (4..100);
    %                     [] (default) keeps the source gear's sampling
    %   nLayers         : number of axial sections, 2..2001; [] -> automatic
    %   faceColor       : MATLAB color/RGB; for a pair also a 2-by-3 RGB matrix;
    %                     default light grey for both gears
    %   edgeColor       : MATLAB color/RGB/'none'; default 'none'
    %   fig             : figure number/handle; default a new figure
    % 'save' is an alias for 'export'. Export is JPG, 300 dpi, not CAD/STL.
    % Existing named export images are overwritten; missing folders are created.
    % P snapshots use stem_0001.jpg etc.; existing names are skipped.
    % Drag with the left mouse button to orbit the CAMERA, wheel to zoom.
    % P saves the current camera/geometry, H shows help; no rotate3d mode is used.
    %
    %   animate(s,'mode','automatic','nr',0.3,'dth1',1,'fps',30)
    %   animate(s,'mode','interactive') % L/D step GEARS, mouse orbits camera
    % During animation: Space pauses/resumes automatic mode; Esc stops.
    % 'save',[] / 'save','movies/pair.avi' writes AVI in animate only.
    % 'export' still exports the initial JPG; 'print' controls P snapshots.
    % The mesh is generated once; hgtransform rotates each complete gear.
    % Animation uses a frozen source snapshot, not a live simulation of edits.
    %
    % g.beta (degrees) and g.Rr define the helical sweep. In radians:
    %   gamma(zeta) = tand(g.beta)*zeta/g.Rr; r_p = g.Rr
    %   X' = X*cos(gamma)+Y*sin(gamma)
    %   Y' =-X*sin(gamma)+Y*cos(gamma); Z'=zeta, 0<=zeta<=width.
    % g already supplies a TRANSVERSE contour: do NOT scale it by sec(beta).
    % Ri>0 makes a circular, untwisted bore. Ri is read from the source gear.
    %
    % For pairs, axes are parallel to Z with centres (0,0) and (GM.a,0).
    % At Z=0 the rotations are -90+th1 and 90+180/G2.z+th2, exactly as
    % in gearsInMesh.plot. Both front faces are aligned at Z=0.
    % The current gear API stores beta as a nonnegative magnitude. A pair
    % uses equal magnitudes and OPPOSITE hands: +G1.beta and -G1.beta.
    % The second source gear.beta is not changed. Unequal magnitudes fail.
    %
    % G is a shared handle (gear or gearsInMesh), read only by this class. Each mesh/plot regenerates
    % the mesh from the current source. No source property or rack is changed.
    % This is a tessellated visualization, not a strength or contact analysis.

    properties (SetAccess = private)
        G                           % Input gear OR gearsInMesh handle (read only)
    end
    properties (Dependent)
        width                       % Scalar or pair [b1 b2]; [] uses 5*module
        th1                         % Rotation at the common reference plane Z=0
        isPair                      % Read-only: input is a gearsInMesh object
        np                          % [] uses existing source sampling settings
        nLayers                     % [] selects axial sections automatically
    end
    properties (Access = private)
        options_
    end

    methods
        function obj = gear3d(g,varargin)
            narginchk(1,inf)
            if ~(isa(g,'gear') || isa(g,'gearsInMesh')) || ~isscalar(g) || ~isvalid(g)
                error('gear3d:Input','Input must be one valid gear or gearsInMesh object.');
            end
            cfg = struct('width',[],'np',[],'nLayers',[],'th1',0, ...
                'axes',false,'title',false,'view',[-37.5 30], ...
                'figureSize',[540 540],'doExport',false,'exportValue',[], ...
                'fig',[],'faceColor',[0.78 0.80 0.84],'edgeColor','none', ...
                'faceColor1',[],'faceColor2',[],'edgeColor1',[],'edgeColor2',[], ...
                'lineWidth',0.5,'printEnabled',true, ...
                'snapshotValue',[],'instructions',true,'interactive',true);
            if mod(numel(varargin),2) ~= 0
                error('gear3d:NameValue','Options must be name-value pairs.');
            end
            for k = 1:2:numel(varargin)
                name = gear3d.optionName(varargin{k});
                value = varargin{k+1};
                switch name
                    case {'width','facewidth'}
                        cfg.width = value;
                    case 'th1'
                        cfg.th1 = value;
                    case {'np','nn'}
                        cfg.np = value;
                    case {'nlayers','layers'}
                        cfg.nLayers = value;
                    case 'axes'
                        cfg.axes = gear3d.flag(value,'axes');
                    case 'title'
                        cfg.title = gear3d.flag(value,'title');
                    case 'view'
                        cfg.view = value;
                    case 'figuresize'
                        cfg.figureSize = gear3d.normalizeFigureSize(value);
                    case {'export','save'}
                        cfg.exportValue = value;
                        cfg.doExport = ~(islogical(value) && isscalar(value) && ~value);
                    case 'fig'
                        cfg.fig = value;
                    case {'facecolor','color'}
                        cfg.faceColor = value;
                    case 'edgecolor'
                        cfg.edgeColor = value;
                    case {'facecolor1','color1'}
                        cfg.faceColor1 = value;
                    case {'facecolor2','color2'}
                        cfg.faceColor2 = value;
                    case 'edgecolor1'
                        cfg.edgeColor1 = value;
                    case 'edgecolor2'
                        cfg.edgeColor2 = value;
                    case 'linewidth'
                        cfg.lineWidth = value;
                    case {'print','snapshot'}
                        [cfg.printEnabled,cfg.snapshotValue] = gear3d.snapshotOption(value);
                    case {'instructions','echo'}
                        cfg.instructions = gear3d.flag(value,'instructions');
                    otherwise
                        error('gear3d:UnknownOption','Unknown option: %s.',name);
                end
            end
            gear3d.checkOptions(cfg);
            gear3d.checkSourceOptions(g,cfg);
            obj.G = g;
            obj.options_ = cfg;
            if nargout == 0
                plot(obj);
            end
        end

        function value = get.width(obj)
            value = obj.options_.width;
            if isempty(value)
                if obj.isPair
                    value = 5*obj.G.G1.rack.m;
                else
                    value = 5*obj.G.rack.m;
                end
            end
        end
        function set.width(obj,value)
            gear3d.checkWidth(value);
            cfg = obj.options_; cfg.width = value;
            gear3d.checkSourceOptions(obj.G,cfg);
            obj.options_ = cfg;
        end
        function value = get.isPair(obj)
            value = isa(obj.G,'gearsInMesh');
        end
        function value = get.th1(obj)
            value = obj.options_.th1;
        end
        function set.th1(obj,value)
            gear3d.checkAngle(value);
            cfg = obj.options_; cfg.th1 = value; obj.options_ = cfg;
        end
        function value = get.np(obj)
            value = obj.options_.np;
        end
        function set.np(obj,value)
            gear3d.checkResolution(value,'np',4,100);
            cfg = obj.options_; cfg.np = value; obj.options_ = cfg;
        end
        function value = get.nLayers(obj)
            value = obj.options_.nLayers;
        end
        function set.nLayers(obj,value)
            gear3d.checkResolution(value,'nLayers',2,2001);
            cfg = obj.options_; cfg.nLayers = value; obj.options_ = cfg;
        end

        function [V,F,info] = mesh(obj,varargin)
            %MESH Build a closed triangle surface without opening a figure.
            % Optional local overrides: width, np, nLayers, th1.
            % A pair returns one V/F array with TWO separate closed components.
            % info.faceGear, vertexRanges and faceRanges identify each gear.
            narginchk(1,inf)
            nargoutchk(0,3)
            cfg = obj.options_;
            if mod(numel(varargin),2) ~= 0
                error('gear3d:NameValue','Mesh options must be name-value pairs.');
            end
            for k = 1:2:numel(varargin)
                name = gear3d.optionName(varargin{k});
                value = varargin{k+1};
                switch name
                    case {'width','facewidth'}
                        cfg.width = value;
                    case 'th1'
                        cfg.th1 = value;
                    case {'np','nn'}
                        cfg.np = value;
                    case {'nlayers','layers'}
                        cfg.nLayers = value;
                    otherwise
                        error('gear3d:UnknownOption','Unknown mesh option: %s.',name);
                end
            end
            gear3d.checkGeometryOptions(cfg);
            [V,F,info] = buildMesh(obj,cfg);
        end

        function [fh,ax,h] = plot(obj,varargin)
            %PLOT Draw current source geometry using explicit figure handles.
            % interactive=false disables camera, keyboard and snapshot controls.
            % Use this setting for static plots in Live Editor.
            narginchk(1,inf)
            nargoutchk(0,3)
            cfg = obj.options_;
            if mod(numel(varargin),2) ~= 0
                error('gear3d:NameValue','Plot options must be name-value pairs.');
            end
            for k = 1:2:numel(varargin)
                name = gear3d.optionName(varargin{k});
                value = varargin{k+1};
                switch name
                    case {'width','facewidth'}
                        cfg.width = value;
                    case 'th1'
                        cfg.th1 = value;
                    case {'np','nn'}
                        cfg.np = value;
                    case {'nlayers','layers'}
                        cfg.nLayers = value;
                    case 'interactive'
                        cfg.interactive = gear3d.flag(value,'interactive');
                    case 'axes'
                        cfg.axes = gear3d.flag(value,'axes');
                    case 'title'
                        cfg.title = gear3d.flag(value,'title');
                    case 'view'
                        cfg.view = value;
                    case 'figuresize'
                        cfg.figureSize = gear3d.normalizeFigureSize(value);
                    case {'export','save'}
                        cfg.exportValue = value;
                        cfg.doExport = ~(islogical(value) && isscalar(value) && ~value);
                    case 'fig'
                        cfg.fig = value;
                    case {'facecolor','color'}
                        cfg.faceColor = value;
                    case 'edgecolor'
                        cfg.edgeColor = value;
                    case {'facecolor1','color1'}
                        cfg.faceColor1 = value;
                    case {'facecolor2','color2'}
                        cfg.faceColor2 = value;
                    case 'edgecolor1'
                        cfg.edgeColor1 = value;
                    case 'edgecolor2'
                        cfg.edgeColor2 = value;
                    case 'linewidth'
                        cfg.lineWidth = value;
                    case {'print','snapshot'}
                        [cfg.printEnabled,cfg.snapshotValue] = gear3d.snapshotOption(value);
                    case {'instructions','echo'}
                        cfg.instructions = gear3d.flag(value,'instructions');
                    otherwise
                        error('gear3d:UnknownOption','Unknown option: %s.',name);
                end
            end
            gear3d.checkOptions(cfg);
            gear3d.checkSourceOptions(obj.G,cfg);
            [fh,ax,h] = render(obj,cfg);
            if cfg.instructions && cfg.interactive, gear3d.showHelp(fh); end
        end

        function [fh,ax,h] = animate(obj,varargin)
            %ANIMATE Rigid 3-D gear motion; L/D step, mouse orbits CAMERA.
            % A single mesh is built. No source object is changed.
            % mode=automatic: nr turns of gear 1, signed step dth1, fps.
            % mode=interactive: L/D, Space forward, Esc ends the blocking call.
            % P saves current view; save,[]/name writes AVI, not JPG.
            narginchk(1,inf)
            nargoutchk(0,3)
            cfg = obj.options_;
            motion = struct('mode','automatic','nr',1,'dth1',1,'fps',30, ...
                'doVideo',false,'videoValue',[]);
            modeSeen = false; stepSeen = false; stepValue = false;
            if mod(numel(varargin),2) ~= 0
                error('gear3d:NameValue','Animation options must be name-value pairs.');
            end
            for k = 1:2:numel(varargin)
                name = gear3d.optionName(varargin{k});
                value = varargin{k+1};
                switch name
                    case {'width','facewidth'}
                        cfg.width = value;
                    case 'th1'
                        cfg.th1 = value;
                    case {'np','nn'}
                        cfg.np = value;
                    case {'nlayers','layers'}
                        cfg.nLayers = value;
                    case 'axes'
                        cfg.axes = gear3d.flag(value,'axes');
                    case 'title'
                        cfg.title = gear3d.flag(value,'title');
                    case 'view'
                        cfg.view = value;
                    case 'figuresize'
                        cfg.figureSize = gear3d.normalizeFigureSize(value);
                    case 'export'
                        cfg.exportValue = value;
                        cfg.doExport = ~(islogical(value) && isscalar(value) && ~value);
                    case 'fig'
                        cfg.fig = value;
                    case {'facecolor','color'}
                        cfg.faceColor = value;
                    case 'edgecolor'
                        cfg.edgeColor = value;
                    case {'facecolor1','color1'}
                        cfg.faceColor1 = value;
                    case {'facecolor2','color2'}
                        cfg.faceColor2 = value;
                    case 'edgecolor1'
                        cfg.edgeColor1 = value;
                    case 'edgecolor2'
                        cfg.edgeColor2 = value;
                    case 'linewidth'
                        cfg.lineWidth = value;
                    case {'print','snapshot'}
                        [cfg.printEnabled,cfg.snapshotValue] = gear3d.snapshotOption(value);
                    case {'instructions','echo'}
                        cfg.instructions = gear3d.flag(value,'instructions');
                    case {'save','video'}
                        motion.doVideo = ~(islogical(value) && isscalar(value) && ~value);
                        motion.videoValue = value;
                    case 'mode'
                        if isstring(value) && isscalar(value), value = char(value); end
                        if ~ischar(value) || ~isrow(value)
                            error('gear3d:Mode','mode must be automatic or interactive.');
                        end
                        switch lower(strtrim(value))
                            case {'automatic','auto'}, motion.mode = 'automatic';
                            case {'interactive','manual'}, motion.mode = 'interactive';
                            otherwise, error('gear3d:Mode','mode must be automatic or interactive.');
                        end
                        modeSeen = true;
                    case 'step'
                        stepValue = gear3d.flag(value,'step'); stepSeen = true;
                    case 'nr'
                        motion.nr = value;
                    case 'dth1'
                        motion.dth1 = value;
                    case {'fps','framerate'}
                        motion.fps = value;
                    otherwise
                        error('gear3d:UnknownOption','Unknown option: %s.',name);
                end
            end
            gear3d.checkOptions(cfg);
            gear3d.checkSourceOptions(obj.G,cfg);
            if stepSeen
                if stepValue, stepMode = 'interactive'; else, stepMode = 'automatic'; end
                if modeSeen && ~strcmp(motion.mode,stepMode)
                    error('gear3d:Mode','mode and step select different animation modes.');
                end
                motion.mode = stepMode;
            end
            gear3d.checkMotion(motion,cfg.th1);
            [fh,ax,h] = render(obj,cfg);
            gear3d.runAnimation(fh,motion);
        end
    end

    methods (Access = private)
        function [fh,ax,h] = render(obj,cfg)
            % Resolve data and topology BEFORE opening/clearing any figure.
            [V,F,info] = buildMesh(obj,cfg);
            if isempty(cfg.fig)
                fh = figure('WindowStyle','normal','Color','w');
            elseif isgraphics(cfg.fig,'figure')
                fh = cfg.fig;
                clf(fh);
            else
                fh = figure(cfg.fig);
                clf(fh);
            end
            set(fh,'WindowStyle','normal','Color','w','Units','pixels', ...
                'Tag','gear3d.View','Name','gear3d','PaperPositionMode','auto', ...
                'ToolBar','none');
            gear3d.removeViewState(fh);
            cfg.figureSize = gear3d.normalizeFigureSize(cfg.figureSize);
            pos = get(fh,'Position');
            if numel(cfg.figureSize) == 2
                pos(3:4) = cfg.figureSize(:).';
            else
                pos = cfg.figureSize(:).';
            end
            set(fh,'Position',pos);
            ax = axes('Parent',fh);
            hold(ax,'on');
            h = gobjects(0,1);
            groups = gobjects(1+double(info.isPair),1);
            tags = {'gear3d.Outer','gear3d.Bore','gear3d.Bottom','gear3d.Top'};
            for ig = 1:1+double(info.isPair)
                [color,edge] = gear3d.memberColors(cfg,ig);
                groups(ig) = hgtransform('Parent',ax, ...
                    'Tag',sprintf('gear3d.Gear%d.Transform',ig));
                if info.isPair
                    rows = info.faceGear == ig;
                else
                    rows = true(size(F,1),1);
                end
                for j = 1:4
                    selected = rows & info.facePart == j;
                    if ~any(selected), continue; end
                    if j <= 2
                        illumination = 'gouraud';
                    else
                        illumination = 'flat';
                    end
                    tag = tags{j};
                    if info.isPair
                        tag = sprintf('gear3d.Gear%d.%s',ig,tags{j}(8:end));
                    end
                    hp = patch('Parent',groups(ig),'Vertices',V,'Faces',F(selected,:), ...
                        'FaceColor',color,'EdgeColor',edge,'LineWidth',cfg.lineWidth, ...
                        'FaceLighting',illumination,'BackFaceLighting','reverselit', ...
                        'AmbientStrength',0.4,'DiffuseStrength',0.8, ...
                        'SpecularStrength',0.2,'SpecularExponent',20,'Tag',tag);
                    h(end+1,1) = hp; %#ok<AGROW>
                end
            end
            axis(ax,'equal');
            axis(ax,'tight');
            axis(ax,'vis3d');
            view(ax,cfg.view(:).');
            xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z');
            if cfg.axes
                axis(ax,'on'); grid(ax,'on'); box(ax,'on');
            else
                grid(ax,'off'); box(ax,'off'); axis(ax,'off');
            end
            titleData = gear3d.captureTitleData(obj.G,info);
            titleSize = max(8,min(11,10*cfg.figureSize(end-1)/700));
            if cfg.title
                title(ax,gear3d.headerText(titleData,info.th1), ...
                    'FontWeight','normal','FontSize',titleSize,'Interpreter','tex');
            else
                title(ax,'');
            end
            % Headlight without changing any global draw2d/MATLAB defaults.
            lamp = light('Parent',ax,'Style','infinite', ...
                'Position',get(ax,'CameraPosition')-get(ax,'CameraTarget'));
            hold(ax,'off');
            setappdata(fh,'gear3d_MeshInfo',info);
            if cfg.interactive
                gear3d.installControls(fh,ax,groups,lamp,cfg,info,titleData,titleSize);
            else
                % No custom callbacks or state; suppress MATLAB axes controls too.
                if exist('disableDefaultInteractivity','file')
                    disableDefaultInteractivity(ax);
                end
                if isprop(ax,'Toolbar')
                    bar = get(ax,'Toolbar');
                    if ~isempty(bar) && isvalid(bar), set(bar,'Visible','off'); end
                end
            end
            drawnow;
            if cfg.doExport
                filename = gear3d.jpgName(cfg.exportValue,fh);
                gear3d.exportJpg(fh,filename);
                setappdata(fh,'gear3d_ExportFile',filename);
                if cfg.instructions, fprintf('3-D gear saved in %s\n',filename); end
            end
        end

        function [V,F,info] = buildMesh(obj,cfg)
            if ~isvalid(obj.G)
                error('gear3d:DeletedSource','The source gear or pair has been deleted.');
            end
            gear3d.checkSourceOptions(obj.G,cfg);
            if obj.isPair
                [V,F,info] = buildPairMesh(obj,cfg);
            else
                [V,F,info] = buildSingleMesh(obj,obj.G,cfg,double(obj.G.beta));
                if cfg.th1 ~= 0
                    V = gear3d.placeVertices(V,cfg.th1,[0 0 0]);
                end
                info.isPair = false;
                info.th1 = double(cfg.th1);
                info.rotationDegrees = double(cfg.th1);
            end
        end

        function [V,F,info] = buildPairMesh(obj,cfg)
            GM = obj.G;
            g1 = GM.G1; g2 = GM.G2;
            sources = {g1,g2};
            for k = 1:2
                g = sources{k};
                if ~isa(g,'gear') || ~isscalar(g) || ~isvalid(g)
                    error('gear3d:PairGear','Both pair members must be valid scalar gear objects.');
                end
            end
            beta = double([g1.beta,g2.beta]);
            m = double([g1.rack.m,g2.rack.m]);
            alpha = double([g1.rack.alpha,g2.rack.alpha]);
            rp = double([g1.Rr,g2.Rr]);
            rb = double([g1.Rb,g2.Rb]);
            z = double([g1.z,g2.z]);
            if ~isreal([beta m alpha rp rb z]) || any(~isfinite([beta m alpha rp rb z])) ...
                    || any(m<=0) || any(rp<=0) || any(rb<=0) || any(abs(beta)>=90) ...
                    || any(z<2) || any(z~=fix(z))
                error('gear3d:PairGeometry','The pair has invalid geometric data.');
            end
            if abs(m(1)-m(2))>1e-10*max(m) || abs(alpha(1)-alpha(2))>1e-9
                error('gear3d:PairCompatibility','Both gears need matching module and rack pressure angle.');
            end
            if abs(abs(beta(1))-abs(beta(2)))>1e-9
                error('gear3d:PairHelix','Parallel-axis gears need equal helix-angle magnitudes.');
            end
            pb = 2*pi*rb./z;
            if abs(pb(1)-pb(2))>1e-9*max(pb)
                error('gear3d:PairBasePitch','Both gears need matching transverse base pitch.');
            end
            % The current gear class stores beta as a magnitude. Opposite
            % hands are an ASSEMBLY convention, never a mutation of either G.
            usedBeta = [beta(1),-beta(1)];
            aa = double(GM.a);
            if ~isreal(aa) || ~isscalar(aa) || ~isfinite(aa) || aa<=0 || GM.invalid ...
                    || aa<sum(rb)-1e-9*max(rp)
                error('gear3d:PairCenterDistance','The pair has no valid meshing center distance.');
            end
            widths = cfg.width;
            if isempty(widths), widths = 5*m(1); end
            if isscalar(widths), widths = [widths widths]; end
            widths = double(widths(:).');
            theta1 = double(cfg.th1);
            theta2 = -theta1*rp(1)/rp(2); % identical to gearsInMesh.plot
            if ~isfinite(theta2)
                error('gear3d:Angle','th1 is too large for the pair rotation ratio.');
            end
            rotation = [-90+theta1,90+180/z(2)+theta2];
            centres = [0 0 0;aa 0 0];
            meshes = cell(1,2); faces = cell(1,2); details = cell(1,2);
            vertexRanges = zeros(2,2); faceRanges = zeros(2,2);
            vertexCount = 0; faceCount = 0;
            for k = 1:2
                local = cfg; local.width = widths(k);
                [vk,fk,ik] = buildSingleMesh(obj,sources{k},local,usedBeta(k));
                vk = gear3d.placeVertices(vk,rotation(k),centres(k,:));
                meshes{k} = vk;
                faces{k} = fk+vertexCount;
                vertexRanges(k,:) = vertexCount+[1 size(vk,1)];
                faceRanges(k,:) = faceCount+[1 size(fk,1)];
                vertexCount = vertexCount+size(vk,1);
                faceCount = faceCount+size(fk,1);
                ik.sourceBeta = beta(k);
                ik.rotationDegrees = rotation(k);
                ik.center = centres(k,:);
                details{k} = ik;
            end
            V = vertcat(meshes{:}); F = vertcat(faces{:});
            facePart = [details{1}.facePart;details{2}.facePart];
            faceGear = [ones(size(faces{1},1),1,'uint8'); ...
                        repmat(uint8(2),size(faces{2},1),1)];
            % Each member has passed the original closed-surface check. Rigid
            % rotations/translations preserve that topology; do NOT weld the
            % two gears or claim that coincident/intersecting faces are tested.
            topology = struct('closed',true,'oriented',true,'components',2, ...
                'eulerCharacteristic',details{1}.topology.eulerCharacteristic+ ...
                                      details{2}.topology.eulerCharacteristic, ...
                'vertices',size(V,1),'triangles',size(F,1), ...
                'edges',details{1}.topology.edges+details{2}.topology.edges);
            info = struct('isPair',true,'sourceClass','gearsInMesh', ...
                'width',widths,'th1',theta1,'th2',theta2, ...
                'centerDistance',aa,'centers',centres,'rotationDegrees',rotation, ...
                'sourceBeta',beta,'effectiveBeta',usedBeta, ...
                'axialReference',0,'axialAlignment','common front face Z=0', ...
                'faceGear',faceGear,'facePart',facePart,'gears',{details}, ...
                'vertexRanges',vertexRanges,'faceRanges',faceRanges, ...
                'topology',topology,'interferenceChecked',false, ...
                'formulation','Supplement S1: eq:11, eq:12; gearsInMesh.plot phases');
        end

        function [V,F,info] = buildSingleMesh(~,g,cfg,beta)
            m = double(g.rack.m);
            rp = double(g.Rr);           % TRANSVERSE reference radius, S1 eq:8
            % beta is signed for the sweep; the transverse contour is unchanged.
            ri = double(g.Ri);
            width = cfg.width;
            if isempty(width), width = 5*m; end
            width = double(width);
            if ~isreal([m rp beta ri]) || any(~isfinite([m rp beta ri])) ...
                    || m<=0 || rp<=0 || ri<0 || abs(beta)>=90
                error('gear3d:SourceGeometry','Invalid module, pitch radius, helix angle or bore.');
            end
            if isempty(cfg.np)
                [x,y] = gearContour(g);
            else
                [x,y] = gearContour(g,'np',cfg.np);
            end
            [outer,cleaning] = gear3d.cleanContour(x,y,m);
            nOuter = size(outer,1);
            % Axis and bore must lie strictly inside the supplied contour.
            [inside,on] = inpolygon(0,0,outer(:,1),outer(:,2));
            if ~inside || on
                error('gear3d:AxisOutside','The external gear contour must enclose its axis.');
            end
            scale = max(hypot(outer(:,1),outer(:,2)));
            tol = max(1e-12*m,64*eps(scale));
            next = [2:nOuter 1];
            A = outer; D = outer(next,:)-A;
            t = max(0,min(1,-sum(A.*D,2)./sum(D.^2,2)));
            nearest = A+bsxfun(@times,t,D);
            minEdgeRadius = min(hypot(nearest(:,1),nearest(:,2)));
            if ri>0 && ri>=minEdgeRadius-tol
                error('gear3d:BoreOutside','Ri intersects the sampled outer contour. Reduce Ri.');
            end
            if ri == 0
                bore = zeros(0,2);
            else
                % Fixed angular stations make a cylinder, not a twisted bore.
                angle = -(0:127)'*(2*pi/128);  % clockwise hole boundary
                bore = ri*[cos(angle) sin(angle)];
            end
            nBore = size(bore,1);
            nRing = nOuter+nBore;
            twistRate = tand(beta)/rp;         % radians / length; S1 eq:12
            totalTwist = twistRate*width;
            if isempty(cfg.nLayers)
                if beta == 0
                    nLayers = 2;
                else
                    % At least 21 sections and at most 2 deg between sections.
                    nLayers = max(21,ceil(abs(totalTwist)/(pi/90))+1);
                end
            else
                nLayers = double(cfg.nLayers);
            end
            if nLayers>2001 || nLayers*nRing>1e6
                error('gear3d:MeshSize', ...
                    'Requested surface is too large. Reduce np, width or nLayers.');
            end
            axial = linspace(0,width,nLayers).';
            gamma = twistRate*axial;
            V = zeros(nRing*nLayers,3);
            for j = 1:nLayers
                c = cos(gamma(j)); s = sin(gamma(j));
                rows = (j-1)*nRing+(1:nOuter);
                V(rows,1) = outer(:,1)*c+outer(:,2)*s;
                V(rows,2) =-outer(:,1)*s+outer(:,2)*c;
                V(rows,3) = axial(j);
                if nBore>0
                    rows = (j-1)*nRing+nOuter+(1:nBore);
                    V(rows,:) = [bore,repmat(axial(j),nBore,1)];
                end
            end
            % Side faces: outer is CCW, bore is CW; both use the same rule.
            outerEdges = [(1:nOuter)' [2:nOuter 1]'];
            boreEdges = zeros(0,2);
            if nBore>0
                boreEdges = nOuter+[(1:nBore)' [2:nBore 1]'];
            end
            edges = [outerEdges;boreEdges];
            nEdges = size(edges,1);
            sideFaces = zeros(2*nEdges*(nLayers-1),3);
            sidePart = zeros(size(sideFaces,1),1,'uint8');
            edgePart = [ones(nOuter,1);2*ones(nBore,1)];
            for j = 1:nLayers-1
                a = edges(:,1)+(j-1)*nRing;
                b = edges(:,2)+(j-1)*nRing;
                rows = (j-1)*2*nEdges+(1:2*nEdges);
                sideFaces(rows,:) = [a b b+nRing; a b+nRing a+nRing];
                sidePart(rows) = uint8([edgePart;edgePart]);
            end
            % Each cap is triangulated inside its constrained loops. This
            % avoids a radial fan, which is invalid for some undercut profiles.
            lower = gear3d.capTriangles(V(1:nRing,1:2),edges,nBore>0,scale);
            offset = (nLayers-1)*nRing;
            upper = gear3d.capTriangles(V(offset+(1:nRing),1:2),edges,nBore>0,scale);
            F = [sideFaces;lower(:,[1 3 2]);upper+offset];
            part = [sidePart;repmat(uint8(3),size(lower,1),1); ...
                repmat(uint8(4),size(upper,1),1)];
            topology = gear3d.checkSurface(V,F,nBore>0);
            info = struct('width',width,'beta',beta,'pitchRadius',rp, ...
                'normalModule',m,'boreRadius',ri,'nOuter',nOuter, ...
                'nBore',nBore,'nLayers',nLayers,'nodesPerSection',nRing, ...
                'axialCoordinates',axial,'gamma',gamma,'twistRate',twistRate, ...
                'totalGamma',totalTwist,'sectionRotation',-totalTwist, ...
                'contour',outer,'facePart',part,'cleaning',cleaning, ...
                'topology',topology,'sourceClass',class(g), ...
                'formulation','Supplement S1: eq:11 and eq:12');
        end
    end

    methods (Static, Access = private)
        function value = normalizeFigureSize(value)
            if isnumeric(value) && isequal(size(value),[0 0])
                value = [540 540];
            end
            if ~isnumeric(value) || ~isreal(value) || ~isvector(value) ...
                    || any(~isfinite(value(:))) || ~ismember(numel(value),[1 2 4])
                error('gear3d:FigureSize', ...
                    'figureSize must be a positive scalar, [W H], or [left bottom W H].');
            end
            value = double(value(:).');
            if isscalar(value), value = [value value]; end
            if any(value(end-1:end)<=0)
                error('gear3d:FigureSize','Figure width and height must be positive.');
            end
        end

        function [enabled,value] = snapshotOption(value)
            % print is an on-demand P-key setting, NOT an immediate export.
            if isstring(value) && isscalar(value), value = char(value); end
            if (isnumeric(value) || islogical(value)) && isscalar(value)
                enabled = gear3d.flag(value,'print'); value = [];
            elseif ischar(value) && isrow(value) && any(strcmpi(strtrim(value),{'on','off'}))
                enabled = gear3d.flag(value,'print'); value = [];
            else
                gear3d.checkExport(value); enabled = true;
            end
        end

        function [face,edge] = memberColors(cfg,ig)
            face = cfg.faceColor; edge = cfg.edgeColor;
            if isnumeric(face) && isequal(size(face),[2 3]), face=face(ig,:); end
            if isnumeric(edge) && isequal(size(edge),[2 3]), edge=edge(ig,:); end
            own = cfg.(sprintf('faceColor%d',ig));
            if ~isempty(own), face=own; end
            own = cfg.(sprintf('edgeColor%d',ig));
            if ~isempty(own), edge=own; end
            face=gear3d.normalizeColor(face); edge=gear3d.normalizeColor(edge);
        end

        function data = captureTitleData(source,info)
            % Values are captured with the mesh, not read during later animation.
            data=struct('isPair',info.isPair,'m',[],'alpha',[], ...
                'z',[],'x',[],'u',[],'h',[],'d',[],'db',[], ...
                'b',info.width,'beta',[],'a',[],'ratio',0);
            if info.isPair
                gs={source.G1,source.G2}; data.a=info.centerDistance;
                data.beta=info.effectiveBeta;
                data.ratio=info.gears{1}.pitchRadius/info.gears{2}.pitchRadius;
            else
                gs={source}; data.beta=info.beta;
            end
            for k=1:numel(gs)
                g=gs{k}; data.m(k)=g.rack.m; data.alpha(k)=g.rack.alpha;
                data.z(k)=g.z; data.x(k)=g.x; data.u(k)=g.u; data.h(k)=g.h;
                data.d(k)=2*g.Rr; data.db(k)=2*g.Rb;
            end
        end

        function txt = headerText(d,th1)
            % h is tooth height; b is axial face width. Never interchange them.
            if d.isPair
                txt={sprintf('m = %g   \\alpha_n = %g^{\\circ}   a = %.5g', ...
                        d.m(1),d.alpha(1),d.a); ...
                     sprintf('z_1 = %d   x_1 = %.4g   u_1 = %.4g   b_1 = %g   \\beta_1 = %g^{\\circ}', ...
                        d.z(1),d.x(1),d.u(1),d.b(1),d.beta(1)); ...
                     sprintf('z_2 = %d   x_2 = %.4g   u_2 = %.4g   b_2 = %g   \\beta_2 = %g^{\\circ}', ...
                        d.z(2),d.x(2),d.u(2),d.b(2),d.beta(2)); ...
                     sprintf('\\theta_1 = %.5g^{\\circ}   \\theta_2 = %.5g^{\\circ}', ...
                        th1,-th1*d.ratio)};
            else
                txt={sprintf('m = %g   z = %d   \\alpha_n = %g^{\\circ}   \\beta = %g^{\\circ}', ...
                        d.m,d.z,d.alpha,d.beta); ...
                     sprintf('d = %.5g   d_b = %.5g   x = %.4g   u = %.4g', ...
                        d.d,d.db,d.x,d.u); ...
                     sprintf('h = %.5g   b = %g   \\theta = %.5g^{\\circ}', ...
                        d.h,d.b,th1)};
            end
        end

        function removeViewState(fh)
            % Reusing a figure must not keep closures/state from its old plot.
            if ~isgraphics(fh,'figure'), return; end
            rotate3d(fh,'off'); zoom(fh,'off'); pan(fh,'off');
            set(fh,'WindowKeyPressFcn',[],'WindowButtonDownFcn',[], ...
                'WindowButtonUpFcn',[],'WindowButtonMotionFcn',[], ...
                'WindowScrollWheelFcn',[],'CloseRequestFcn','closereq');
            keys={'gear3d_ViewState','gear3d_ExportFile','gear3d_LastSnapshot', ...
                'gear3d_Animation','gear3d_FramesWritten','gear3d_SnapshotHistory'};
            for k=1:numel(keys)
                if isappdata(fh,keys{k}), rmappdata(fh,keys{k}); end
            end
        end

        function installControls(fh,ax,groups,lamp,cfg,info,titleData,titleSize)
            % Own camera callbacks avoid rotate3d's legacy keyboard ownership.
            if exist('disableDefaultInteractivity','file'), disableDefaultInteractivity(ax); end
            if isprop(ax,'Toolbar')
                bar=get(ax,'Toolbar');
                if ~isempty(bar) && isvalid(bar), set(bar,'Visible','off'); end
            end
            stem=gear3d.jpgName(cfg.snapshotValue,fh);
            % Keep relative snapshot names relative until P is pressed.
            [folder,name,ext]=fileparts(stem);
            st=struct('axes',ax,'groups',groups,'lamp',lamp,'options',cfg, ...
                'baseInfo',info,'titleData',titleData,'titleSize',titleSize, ...
                'initialTh1',info.th1,'currentTh1',info.th1, ...
                'running',false,'mode','view','paused',false, ...
                'stopRequested',false,'actions',zeros(1,0), ...
                'dragging',false,'lastPoint',[0 0],'snapshotBusy',false, ...
                'snapshotFolder',folder,'snapshotStem',name,'snapshotExtension',ext, ...
                'snapshotCount',0,'frameNumber',1);
            setappdata(fh,'gear3d_ViewState',st);
            set(fh,'WindowKeyPressFcn',@gear3d.keyPressed, ...
                'WindowButtonDownFcn',@gear3d.mouseDown, ...
                'WindowButtonMotionFcn',@gear3d.mouseMoved, ...
                'WindowButtonUpFcn',@gear3d.mouseUp, ...
                'WindowScrollWheelFcn',@gear3d.mouseWheel);
        end

        function ok = hasScene(fh)
            ok=isgraphics(fh,'figure') && isappdata(fh,'gear3d_ViewState');
            if ok
                st=getappdata(fh,'gear3d_ViewState');
                ok=isgraphics(st.axes,'axes') && all(isgraphics(st.groups));
            end
        end

        function keyPressed(fh,event)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState');
            key=lower(char(event.Key));
            switch key
                case 'p'
                    if ~st.options.printEnabled || st.snapshotBusy, return; end
                    if st.running
                        st.actions(end+1)=0; % Preserve L/P/D/P event order.
                    else
                        gear3d.saveSnapshot(fh); return
                    end
                case {'l','rightarrow'}
                    if st.running && strcmp(st.mode,'interactive'), st.actions(end+1)=1; end
                case {'d','leftarrow'}
                    if st.running && strcmp(st.mode,'interactive'), st.actions(end+1)=-1; end
                case {'space','return'}
                    if st.running
                        if strcmp(st.mode,'automatic')
                            st.paused=~st.paused;
                        else
                            st.actions(end+1)=1;
                        end
                    end
                case 'escape'
                    st.dragging=false;
                    if st.running, st.stopRequested=true; end
                case 'h'
                    gear3d.showHelp(fh); return
            end
            setappdata(fh,'gear3d_ViewState',st);
        end

        function mouseDown(fh,~)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState');
            if st.snapshotBusy || ~strcmp(get(fh,'SelectionType'),'normal'), return; end
            point=get(fh,'CurrentPoint'); box=getpixelposition(st.axes,true);
            if point(1)<box(1) || point(1)>box(1)+box(3) ...
                    || point(2)<box(2) || point(2)>box(2)+box(4), return; end
            st.dragging=true; st.lastPoint=point(1:2);
            setappdata(fh,'gear3d_ViewState',st);
        end
        function mouseMoved(fh,~)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState');
            if ~st.dragging || st.snapshotBusy, return; end
            point=get(fh,'CurrentPoint'); delta=point(1:2)-st.lastPoint;
            st.lastPoint=point(1:2); setappdata(fh,'gear3d_ViewState',st);
            camorbit(st.axes,-0.35*delta(1),-0.35*delta(2),'camera');
            gear3d.updateLight(fh);
        end
        function mouseUp(fh,~)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState'); st.dragging=false;
            setappdata(fh,'gear3d_ViewState',st);
        end
        function mouseWheel(fh,event)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState');
            if st.snapshotBusy, return; end
            n=max(-50,min(50,double(event.VerticalScrollCount)));
            camzoom(st.axes,1.1^(-n)); gear3d.updateLight(fh);
        end
        function updateLight(fh)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState');
            if isgraphics(st.lamp,'light')
                set(st.lamp,'Position',get(st.axes,'CameraPosition')-get(st.axes,'CameraTarget'));
            end
        end

        function showHelp(fh)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState');
            fprintf('\ngear3d: %s\n',upper(st.mode));
            fprintf('  Drag left mouse: orbit CAMERA; mouse wheel: zoom.\n');
            if st.options.printEnabled
                fprintf('  P: save current view as numbered JPG (300 dpi).\n');
                fprintf('     %s_<number>%s\n',fullfile(st.snapshotFolder,st.snapshotStem),st.snapshotExtension);
            else
                fprintf('  P: disabled (print=off).\n');
            end
            if st.running
                if strcmp(st.mode,'interactive')
                    fprintf('  L / right arrow: gear step forward; D / left arrow: backward.\n');
                    fprintf('  Space / Enter: forward. Camera dragging does not step gears.\n');
                else
                    fprintf('  Space / Enter: pause or resume gear motion.\n');
                end
                fprintf('  Esc: stop animation, retain current view; close window: exit.\n');
            end
            fprintf('  H: show help. Keys act in the active figure, not Command Window.\n\n');
        end

        function ok = absolutePath(name)
            ok=~isempty(regexp(name,'^([A-Za-z]:[\\/]|[\\/])','once'));
        end
        function ensureFolder(folder)
            if ~isempty(folder) && ~isfolder(folder)
                [ok,msg]=mkdir(folder);
                if ~ok, error('gear3d:ExportDirectory','Cannot create output folder: %s',msg); end
            end
        end
        function exportJpg(fh,filename)
            gear3d.ensureFolder(fileparts(filename));
            % Use existing graphics and current CAMERA, never plot(obj) again.
            % Tighten the axes inside the existing figure before printing so
            % static JPG exports do not contain excessive white margins.
            ax = findobj(fh,'Type','axes');
            if ~isempty(ax)
                ax = ax(1);
                oldUnits = get(ax,'Units');
                oldPos = get(ax,'Position');
                oldOuter = get(ax,'OuterPosition');
                oldLoose = get(ax,'LooseInset');
                cleanup = onCleanup(@() gear3d.restoreExportAxes( ...
                    ax,oldUnits,oldPos,oldOuter,oldLoose)); %#ok<NASGU>
                set(ax,'Units','normalized');
                ti = get(ax,'TightInset');
                margin = 0.015;
                left = max(margin,ti(1)+margin);
                bottom = max(margin,ti(2)+margin);
                right = max(margin,ti(3)+margin);
                top = max(margin,ti(4)+margin);
                set(ax,'Position',[left bottom ...
                    max(0.1,1-left-right) max(0.1,1-bottom-top)], ...
                    'LooseInset',max(ti,margin));
                drawnow;
            end
            print(fh,filename,'-djpeg','-r300');
        end

        function restoreExportAxes(ax,units,pos,outer,loose)
            if isgraphics(ax,'axes')
                set(ax,'Units',units,'Position',pos,'OuterPosition',outer, ...
                    'LooseInset',loose);
            end
        end
        function saveSnapshot(fh)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState');
            if ~st.options.printEnabled || st.snapshotBusy, return; end
            st.snapshotBusy=true; setappdata(fh,'gear3d_ViewState',st);
            unlock=onCleanup(@() gear3d.unlockSnapshot(fh));
            try
                folder=st.snapshotFolder;
                if ~gear3d.absolutePath(folder), folder=fullfile(pwd,folder); end
                gear3d.ensureFolder(folder);
                k=st.snapshotCount+1;
                file=fullfile(folder,sprintf('%s_%04d%s', ...
                    st.snapshotStem,k,st.snapshotExtension));
                while isfile(file)
                    k=k+1;
                    file=fullfile(folder,sprintf('%s_%04d%s', ...
                        st.snapshotStem,k,st.snapshotExtension));
                end
                gear3d.exportJpg(fh,file);
                if gear3d.hasScene(fh)
                    % Read the latest state: printing may have processed Esc.
                    fresh=getappdata(fh,'gear3d_ViewState'); fresh.snapshotCount=k;
                    setappdata(fh,'gear3d_ViewState',fresh);
                    setappdata(fh,'gear3d_LastSnapshot',file);
                    entry=struct('filename',file,'th1',st.currentTh1, ...
                        'cameraPosition',get(st.axes,'CameraPosition'), ...
                        'cameraTarget',get(st.axes,'CameraTarget'), ...
                        'cameraUpVector',get(st.axes,'CameraUpVector'));
                    if isappdata(fh,'gear3d_SnapshotHistory')
                        history=getappdata(fh,'gear3d_SnapshotHistory');
                        history(end+1)=entry;
                    else
                        history=entry;
                    end
                    setappdata(fh,'gear3d_SnapshotHistory',history);
                end
                if st.options.instructions, fprintf('3-D snapshot saved in %s\n',file); end
            catch ME
                warning('gear3d:SnapshotFailed','Current view was not saved: %s',ME.message);
            end
            clear unlock
        end
        function unlockSnapshot(fh)
            if ~gear3d.hasScene(fh), return; end
            st=getappdata(fh,'gear3d_ViewState'); st.snapshotBusy=false;
            setappdata(fh,'gear3d_ViewState',st);
        end

        function checkMotion(motion,th1)
            names={'nr','dth1','fps'};
            for k=1:numel(names)
                value=motion.(names{k});
                if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value)
                    error('gear3d:AnimationOption','%s must be a finite real scalar.',names{k});
                end
            end
            if motion.nr<=0 || motion.fps<=0 || motion.dth1==0
                error('gear3d:AnimationOption','Require nr>0, fps>0 and dth1~=0.');
            end
            if strcmp(motion.mode,'automatic')
                span=360*double(motion.nr); steps=ceil(span/abs(double(motion.dth1)));
                ending=double(th1)+sign(motion.dth1)*span;
                if ~isfinite(ending) || ending==th1 || ~isfinite(steps) || steps>1e6
                    error('gear3d:AnimationRange','Unresolved angular range or more than 1e6 steps.');
                end
            end
            if motion.doVideo, gear3d.videoName(motion.videoValue); end
        end
        function filename = videoName(value)
            if isstring(value) && isscalar(value), value=char(value); end
            if (isnumeric(value) && isequal(size(value),[0 0])) ...
                    || (islogical(value) && isscalar(value))
                filename='gear3d.avi';
            elseif ischar(value) && isrow(value) && ~isempty(strtrim(value))
                if any(value==char(0)) || value(end)=='/' || value(end)==char(92)
                    error('gear3d:VideoFile','save requires an AVI filename, not just a directory.');
                end
                [folder,name,ext]=fileparts(value);
                if isempty(ext), ext='.avi'; end
                if isempty(name) || ~strcmpi(ext,'.avi')
                    error('gear3d:VideoFile','Only AVI video export is supported.');
                end
                filename=fullfile(folder,[name ext]);
            else
                error('gear3d:VideoFile','save must be [], true/false or an AVI filename.');
            end
            if ~gear3d.absolutePath(filename), filename=fullfile(pwd,filename); end
        end

        function setMotionLimits(fh)
            st=getappdata(fh,'gear3d_ViewState'); info=st.baseInfo;
            if info.isPair
                centers=info.centers;
                r=[max(hypot(info.gears{1}.contour(:,1),info.gears{1}.contour(:,2))), ...
                   max(hypot(info.gears{2}.contour(:,1),info.gears{2}.contour(:,2)))];
            else
                centers=[0 0 0]; r=max(hypot(info.contour(:,1),info.contour(:,2)));
            end
            pad=0.04*max(r);
            xlim(st.axes,[min(centers(:,1).'-r)-pad,max(centers(:,1).'+r)+pad]);
            ylim(st.axes,[-max(r)-pad,max(r)+pad]);
            zlim(st.axes,[-pad,max(info.width)+pad]);
            % Freeze framing, not the user's camera controls.
            set(st.axes,'XLimMode','manual','YLimMode','manual','ZLimMode','manual');
        end
        function moveToAngle(fh,theta,index)
            st=getappdata(fh,'gear3d_ViewState');
            if ~isfinite(theta)
                error('gear3d:AnimationAngle','The requested angle is not finite.');
            end
            delta=theta-st.initialTh1;
            angles=delta;
            centers=[0 0 0];
            info=st.baseInfo;
            if info.isPair
                angles=[delta,-delta*st.titleData.ratio]; centers=info.centers;
                info.th2=-theta*st.titleData.ratio;
            end
            if any(~isfinite(angles))
                error('gear3d:AnimationAngle','The corresponding pair angle is not finite.');
            end
            for k=1:numel(st.groups)
                a=rem(angles(k),360); c=cosd(a); s=sind(a);
                cx=centers(k,1); cy=centers(k,2);
                M=[c -s 0 cx*(1-c)+cy*s; ...
                   s  c 0 cy*(1-c)-cx*s; 0 0 1 0; 0 0 0 1];
                set(st.groups(k),'Matrix',M);
            end
            info.th1=theta; info.rotationDegrees=st.baseInfo.rotationDegrees+angles;
            if info.isPair
                for k=1:2, info.gears{k}.rotationDegrees=info.rotationDegrees(k); end
            end
            st.currentTh1=theta; st.frameNumber=index;
            setappdata(fh,'gear3d_ViewState',st);
            setappdata(fh,'gear3d_MeshInfo',info);
            if st.options.title
                title(st.axes,gear3d.headerText(st.titleData,theta), ...
                    'FontWeight','normal','FontSize',st.titleSize,'Interpreter','tex');
            end
            gear3d.updateLight(fh);
        end

        function runAnimation(fh,motion)
            % No source calls here: transform the one mesh made by render.
            st=getappdata(fh,'gear3d_ViewState');
            st.running=true; st.mode=motion.mode; st.stopRequested=false;
            st.paused=false; st.actions=zeros(1,0);
            setappdata(fh,'gear3d_ViewState',st);
            gear3d.setMotionLimits(fh);
            initial=st.currentTh1; oldResize=get(fh,'Resize');
            writer=[]; frames=0; displayFrames=1; dimensions=[];
            reason='aborted by error or interruption'; originalGroups=st.groups;
            videoFile='';
            if motion.doVideo
                videoFile=gear3d.videoName(motion.videoValue);
                set(fh,'Resize','off'); % getframe dimensions must stay constant
            end
            setappdata(fh,'gear3d_FramesWritten',0);
            guard=onCleanup(@finish);
            if st.options.instructions, gear3d.showHelp(fh); end
            drawnow;
            if shouldStop(), clear guard; return; end
            writeFrame();
            index=0; clock=tic;
            if strcmp(motion.mode,'automatic')
                span=360*double(motion.nr);
                steps=ceil(span/abs(double(motion.dth1)));
                while index<steps
                    drawnow;
                    if shouldStop(), break; end
                    processSnapshots();
                    if shouldStop(), break; end
                    fresh=getappdata(fh,'gear3d_ViewState');
                    if fresh.paused
                        pause(0.01); clock=tic; continue
                    end
                    if ~motion.doVideo
                        wait=max(0,1/double(motion.fps)-toc(clock));
                        if wait>0, pause(wait); end
                    end
                    if shouldStop(), break; end
                    processSnapshots();
                    if shouldStop(), break; end
                    fresh=getappdata(fh,'gear3d_ViewState');
                    if fresh.paused, continue; end
                    index=index+1; displayFrames=index+1;
                    theta=initial+sign(motion.dth1)*min(index*abs(double(motion.dth1)),span);
                    gear3d.moveToAngle(fh,theta,index+1);
                    drawnow;
                    if shouldStop(), break; end
                    writeFrame(); clock=tic;
                end
            else
                while true
                    drawnow;
                    if shouldStop(), break; end
                    fresh=getappdata(fh,'gear3d_ViewState');
                    if isempty(fresh.actions), pause(0.01); continue; end
                    command=fresh.actions(1); fresh.actions(1)=[];
                    setappdata(fh,'gear3d_ViewState',fresh);
                    if command==0
                        gear3d.saveSnapshot(fh); continue
                    end
                    index=index+command; displayFrames=displayFrames+1;
                    gear3d.moveToAngle(fh,initial+index*double(motion.dth1),displayFrames);
                    drawnow;
                    if shouldStop(), break; end
                    writeFrame();
                end
            end
            % Do not lose a P queued during the last successfully drawn frame.
            if ~shouldStop()
                processSnapshots();
                if ~shouldStop(), reason='completed'; end
            end
            clear guard

            function stop = shouldStop()
                stop=~gear3d.hasScene(fh) || ~all(isgraphics(originalGroups));
                if stop, reason='window closed or scene replaced'; return; end
                current=getappdata(fh,'gear3d_ViewState');
                stop=current.stopRequested;
                if stop, reason='stopped by user'; end
            end
            function processSnapshots()
                while ~shouldStop()
                    current=getappdata(fh,'gear3d_ViewState');
                    if isempty(current.actions), return; end
                    command=current.actions(1); current.actions(1)=[];
                    setappdata(fh,'gear3d_ViewState',current);
                    if command==0, gear3d.saveSnapshot(fh); end
                end
            end
            function writeFrame()
                if ~motion.doVideo || shouldStop(), return; end
                frame=getframe(fh);
                if shouldStop(), return; end
                shape=size(frame.cdata);
                if isempty(writer)
                    gear3d.ensureFolder(fileparts(videoFile));
                    writer=VideoWriter(videoFile,'Motion JPEG AVI');
                    writer.FrameRate=double(motion.fps);
                    open(writer); dimensions=shape;
                elseif ~isequal(shape,dimensions)
                    error('gear3d:VideoFrameSize','Capture size changed while writing the video.');
                end
                writeVideo(writer,frame); frames=frames+1;
                setappdata(fh,'gear3d_FramesWritten',frames);
            end
            function finish()
                if ~isempty(writer)
                    try
                        close(writer);
                    catch ME
                        warning('gear3d:VideoClose','Video could not be finalized: %s',ME.message);
                    end
                end
                if gear3d.hasScene(fh) && all(isgraphics(originalGroups))
                    current=getappdata(fh,'gear3d_ViewState');
                    current.running=false; current.mode='view'; current.actions=[];
                    current.paused=false; current.stopRequested=false;
                    setappdata(fh,'gear3d_ViewState',current);
                    set(fh,'Resize',oldResize);
                    result=struct('mode',motion.mode,'reason',reason, ...
                        'initialTh1',initial,'finalTh1',current.currentTh1, ...
                        'framesWritten',frames,'framesDisplayed',displayFrames,'videoFile',videoFile);
                    setappdata(fh,'gear3d_Animation',result);
                end
                if st.options.instructions
                    fprintf('3-D animation %s.\n',reason);
                    if frames>0, fprintf('Video saved in %s (%d frames).\n',videoFile,frames); end
                end
            end
        end

        function name = optionName(value)
            if isstring(value) && isscalar(value), value = char(value); end
            if ~ischar(value) || ~isrow(value) || isempty(value)
                error('gear3d:OptionName','Option names must be nonempty scalar text.');
            end
            name = lower(strtrim(value));
            if ~isempty(name) && name(1)=='-', name = name(2:end); end
        end
        function value = flag(value,name)
            if isstring(value) && isscalar(value), value = char(value); end
            if ischar(value) && isrow(value)
                switch lower(strtrim(value))
                    case 'on', value = true;
                    case 'off', value = false;
                    otherwise
                        error('gear3d:Flag','%s must be on/off, 1/0 or true/false.',name);
                end
            elseif (isnumeric(value) || islogical(value)) && isreal(value) ...
                    && isscalar(value) && isfinite(value) && (value==0 || value==1)
                value = logical(value);
            else
                error('gear3d:Flag','%s must be on/off, 1/0 or true/false.',name);
            end
        end
        function checkPositiveOrEmpty(value,name)
            if isempty(value)
                if ~isnumeric(value) || ~isequal(size(value),[0 0])
                    error('gear3d:GeometryOption','Empty %s must be [].',name);
                end
            elseif ~isnumeric(value) || ~isreal(value) || ~isscalar(value) ...
                    || ~isfinite(value) || value<=0
                error('gear3d:GeometryOption','%s must be positive finite scalar or [].',name);
            end
        end
        function checkResolution(value,name,lo,hi)
            if isempty(value)
                gear3d.checkPositiveOrEmpty(value,name);
            elseif ~isnumeric(value) || ~isreal(value) || ~isscalar(value) ...
                    || ~isfinite(value) || value~=fix(value) || value<lo || value>hi
                error('gear3d:Resolution','%s must be [] or an integer in [%d,%d].',name,lo,hi);
            end
        end
        function V = placeVertices(V,angle,center)
            % Row-vector version of a proper rotation about Z, then translation.
            a = rem(double(angle),360);
            c = cosd(a); s = sind(a);
            x = V(:,1); y = V(:,2);
            V(:,1) = c*x-s*y+center(1);
            V(:,2) = s*x+c*y+center(2);
            V(:,3) = V(:,3)+center(3);
        end
        function checkAngle(value)
            if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value)
                error('gear3d:Angle','th1 must be a finite real scalar in degrees.');
            end
        end
        function checkWidth(value)
            if isempty(value)
                gear3d.checkPositiveOrEmpty(value,'width');
            elseif ~isnumeric(value) || ~isreal(value) || ~isvector(value) ...
                    || ~ismember(numel(value),[1 2]) || any(~isfinite(value(:))) ...
                    || any(value(:)<=0)
                error('gear3d:GeometryOption','width must be a positive scalar, [b1 b2], or [].');
            end
        end
        function checkSourceOptions(g,cfg)
            if ~isa(g,'gearsInMesh')
                if numel(cfg.width)>1
                    error('gear3d:SingleWidth','Two widths require a gearsInMesh input.');
                end
                if (isnumeric(cfg.faceColor) && isequal(size(cfg.faceColor),[2 3])) ...
                        || (isnumeric(cfg.edgeColor) && isequal(size(cfg.edgeColor),[2 3])) ...
                        || ~isempty(cfg.faceColor2) || ~isempty(cfg.edgeColor2)
                    error('gear3d:SingleColor','Second-gear colors require a gearsInMesh input.');
                end
            end
        end
        function checkFaceColors(value,allowNone)
            if nargin<2, allowNone=false; end
            if isnumeric(value) && isequal(size(value),[2 3])
                gear3d.checkColor(value(1,:),'color(1,:)',allowNone);
                gear3d.checkColor(value(2,:),'color(2,:)',allowNone);
            else
                gear3d.checkColor(value,'color',allowNone);
            end
        end
        function checkGeometryOptions(cfg)
            gear3d.checkWidth(cfg.width);
            gear3d.checkAngle(cfg.th1);
            gear3d.checkResolution(cfg.np,'np',4,100);
            gear3d.checkResolution(cfg.nLayers,'nLayers',2,2001);
        end
        function checkOptions(cfg)
            gear3d.checkGeometryOptions(cfg);
            v = cfg.view;
            ok = isnumeric(v) && isreal(v) && isvector(v) && all(isfinite(v(:)));
            if ok
                ok = (isscalar(v) && (v==2 || v==3)) || numel(v)==2 ...
                    || (numel(v)==3 && any(v~=0));
            end
            if ~ok
                error('gear3d:View','view must be [az el], a nonzero 3-vector, 2 or 3.');
            end
            gear3d.normalizeFigureSize(cfg.figureSize);
            if ~isempty(cfg.fig)
                v = cfg.fig;
                ok = isscalar(v) && isgraphics(v,'figure');
                if ~ok
                    ok = isnumeric(v) && isreal(v) && isscalar(v) ...
                        && isfinite(v) && v>0 && v==fix(v);
                end
                if ~ok, error('gear3d:Figure','fig must be a figure handle or positive integer.'); end
            end
            gear3d.checkFaceColors(cfg.faceColor);
            gear3d.checkFaceColors(cfg.edgeColor,true);
            names = {'faceColor1','faceColor2','edgeColor1','edgeColor2'};
            for k=1:numel(names)
                v = cfg.(names{k});
                if ~isempty(v), gear3d.checkColor(v,names{k},k>2); end
            end
            if ~isnumeric(cfg.lineWidth) || ~isreal(cfg.lineWidth) || ~isscalar(cfg.lineWidth) ...
                    || ~isfinite(cfg.lineWidth) || cfg.lineWidth<=0
                error('gear3d:LineWidth','lineWidth must be a positive finite scalar.');
            end
            if cfg.printEnabled, gear3d.checkExport(cfg.snapshotValue); end
            if cfg.doExport
                gear3d.checkExport(cfg.exportValue);
            end
        end
        function checkColor(value,name,allowNone)
            if isstring(value) && isscalar(value), value = char(value); end
            if isnumeric(value) && isreal(value) && numel(value)==3 ...
                    && isvector(value) && all(isfinite(value(:))) ...
                    && all(value(:)>=0) && all(value(:)<=1)
                return
            end
            if ischar(value) && isrow(value)
                names = {'r','g','b','c','m','y','k','w','red','green','blue', ...
                    'cyan','magenta','yellow','black','white'};
                if allowNone, names{end+1}='none'; end
                if any(strcmpi(value,names)), return; end
                if ~isempty(regexp(value,'^#[0-9a-fA-F]{6}$','once')), return; end
            end
            error('gear3d:Color','Invalid %s; use a color name or RGB triplet.',name);
        end
        function value = normalizeColor(value)
            if isnumeric(value)
                if isequal(size(value),[2 3])
                    value = double(value);
                else
                    value = double(value(:).');
                end
            else
                value = lower(char(value));
            end
        end
        function checkExport(value)
            if isempty(value) && isnumeric(value) && isequal(size(value),[0 0]), return; end
            if islogical(value) && isscalar(value), return; end
            if isstring(value) && isscalar(value), value = char(value); end
            if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
                error('gear3d:Export','export must be [], jpg, a filename or a logical scalar.');
            end
            if any(value==char(0)) || value(end)=='/' || value(end)==char(92)
                error('gear3d:Export','export requires a filename, not only a directory.');
            end
            if strcmpi(value,'jpg') || strcmpi(value,'jpeg'), return; end
            [~,base,ext] = fileparts(value);
            if isempty(base) || (~isempty(ext) && ~any(strcmpi(ext,{'.jpg','.jpeg'})))
                error('gear3d:ExportFormat','Only JPG/JPEG export is supported.');
            end
        end
        function filename = jpgName(value,fh)
            if isstring(value), value = char(value); end
            if isempty(value) || islogical(value) || strcmpi(value,'jpg') || strcmpi(value,'jpeg')
                filename = sprintf('Fig%d.jpg',get(fh,'Number'));
            else
                [folder,base,ext] = fileparts(value);
                if isempty(ext), ext = '.jpg'; end
                filename = fullfile(folder,[base ext]);
            end
        end
        function [P,info] = cleanContour(x,y,m)
            if ~isnumeric(x) || ~isnumeric(y) || ~isvector(x) || ~isvector(y) ...
                    || numel(x)~=numel(y) || numel(x)<4
                error('gear3d:Contour','gearContour must return two coordinate vectors.');
            end
            P = double([x(:) y(:)]);
            if ~isreal(P) || any(~isfinite(P(:)))
                error('gear3d:Contour','The gear contour must be finite, real and single-loop.');
            end
            original = size(P,1);
            scale = max(hypot(P(:,1),P(:,2)));
            tol = max(1e-12*abs(m),64*eps(scale));
            keep = true(size(P,1),1); last = 1;
            for k = 2:size(P,1)
                if hypot(P(k,1)-P(last,1),P(k,2)-P(last,2))<=tol
                    keep(k) = false;
                else
                    last = k;
                end
            end
            P = P(keep,:);
            while size(P,1)>1 && hypot(P(end,1)-P(1,1),P(end,2)-P(1,2))<=tol
                P(end,:) = [];
            end
            if size(P,1)<3 || size(unique(P,'rows'),1)~=size(P,1)
                error('gear3d:Contour','Degenerate contour or nonconsecutive repeated vertices.');
            end
            next = [2:size(P,1) 1];
            area2 = sum(P(:,1).*P(next,2)-P(next,1).*P(:,2));
            if ~isfinite(area2) || abs(area2)<=tol*scale
                error('gear3d:Contour','The contour has zero or numerically unresolved area.');
            end
            reversed = area2<0;
            if reversed, P=flipud(P); end
            info = struct('inputVertices',original,'usedVertices',size(P,1), ...
                'removedDuplicateVertices',original-size(P,1), ...
                'reversedToCounterclockwise',reversed,'tolerance',tol);
        end
        function F = capTriangles(P,C,hasBore,scale)
            % Normalization prevents the unit of the module affecting meshing.
            Q = P/scale;
            try
                DT = delaunayTriangulation(Q,C);
            catch ME
                err = MException('gear3d:CapTriangulation', ...
                    'Cannot triangulate the supplied contour without changing it.');
                err = addCause(err,ME); throw(err);
            end
            [found,map] = ismember(DT.Points,Q,'rows');
            if size(DT.Points,1)~=size(Q,1) || ~all(found) || numel(unique(map))~=size(Q,1)
                error('gear3d:ContourIntersection', ...
                    'Triangulation introduced/merged vertices. Check for crossing or overlapping edges.');
            end
            F = DT.ConnectivityList(isInterior(DT),:);
            F = reshape(map(F),size(F));
            if isempty(F)
                error('gear3d:CapTriangulation','No interior cap triangles were obtained.');
            end
            a = Q(F(:,2),:)-Q(F(:,1),:); b = Q(F(:,3),:)-Q(F(:,1),:);
            twiceArea = a(:,1).*b(:,2)-a(:,2).*b(:,1);
            if any(twiceArea==0) || any(~isfinite(twiceArea))
                error('gear3d:CapTriangulation','A cap contains degenerate triangles.');
            end
            reverse = twiceArea<0;
            F(reverse,:) = F(reverse,[1 3 2]);
            % Check exact polygon boundary and expected Euler topology; do
            % not silently fill tooth spaces, repair intersections or a bore.
            boundary = freeBoundary(triangulation(F,Q));
            if ~isequal(sortrows(sort(boundary,2)),sortrows(sort(C,2))) ...
                    || size(F,1)~=size(P,1)-2+2*double(hasBore)
                error('gear3d:CapBoundary','Cap topology does not preserve the contour and hole.');
            end
            polygonArea = 0.5*sum(Q(C(:,1),1).*Q(C(:,2),2)-Q(C(:,2),1).*Q(C(:,1),2));
            if polygonArea<=0 || abs(sum(abs(twiceArea))/2-polygonArea)>1e-9*max(1,polygonArea)
                error('gear3d:CapArea','Cap triangles do not match the polygon area.');
            end
        end
        function out = checkSurface(V,F,hasBore)
            E = [F(:,[1 2]);F(:,[2 3]);F(:,[3 1])];
            [edges,~,id] = unique(sort(E,2),'rows');
            counts = accumarray(id,1);
            balance = accumarray(id,2*double(E(:,1)<E(:,2))-1);
            euler = size(V,1)-size(edges,1)+size(F,1);
            if any(counts~=2) || any(balance~=0) || euler~=2-2*double(hasBore)
                error('gear3d:SurfaceTopology','The surface is not closed and consistently oriented.');
            end
            A=V(F(:,1),:); B=V(F(:,2),:); C=V(F(:,3),:);
            normal=cross(B-A,C-A,2);
            if any(all(normal==0,2)) || any(~isfinite(normal(:)))
                error('gear3d:SurfaceTriangle','The surface contains degenerate triangles.');
            end
            % Topological verification does not certify non-self-intersection
            % of a coarse helical sweep or finite-element mesh quality.
            out=struct('closed',true,'oriented',true,'eulerCharacteristic',euler, ...
                'vertices',size(V,1),'triangles',size(F,1),'edges',size(edges,1));
        end
    end
end
