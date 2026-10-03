function [opt,lineArgs] = parseGearPlotOptions(mode,args)
%PARSEGEARPLOTOPTIONS Internal graphics-only options, never geometry inputs.
% Names are case-insensitive and accept an optional leading '-'.
% 'save',[] uses the default filename; legacy bare 'save' is retained.
% Gear, contact and overlay modes forward remaining line properties.
% Overlay drawings preserve the existing title unless explicitly requested.
narginchk(2,2)
opt = struct('title',true,'save',false,'fileName',[]);
lineArgs = {};
values = {};
flags = {};
allowLineArgs = false;
switch mode
    case 'gear'
        opt.fig = []; opt.nz = []; opt.init = true;
        opt.circles = true; opt.center = true; opt.gen = false;
        values = {'fig','fig'; 'nz','nz'};
        flags = {'gen','gen',true; 'gentooth','gen',true; ...
            'generationoftooth','gen',true; 'keep','init',false; ...
            'nocir','circles',false; 'nocirc','circles',false; ...
            'nocent','center',false; 'nocenter','center',false; ...
            'nocen','center',false; 'notxt','title',false; ...
            'notext','title',false};
        allowLineArgs = true;
    case 'rack'
        opt.fig = []; opt.beta = 0;
        values = {'fig','fig'; 'beta','beta'};
    case 'generating'
        opt.beta = 0; opt.x = 0;
        values = {'beta','beta'; 'x','x'};
    case 'contact'
        opt.fig = [];
        values = {'fig','fig'};
        flags = {'notxt','title',false; 'notext','title',false};
        allowLineArgs = true;
    case 'overlay'
        opt.fig = []; opt.title = []; opt.init = false;
        values = {'fig','fig'};
        flags = {'keep','init',false; 'notxt','title',false; ...
            'notext','title',false};
        allowLineArgs = true;
    case 'pair'
        allowLineArgs = true;
        opt.a = []; opt.zoom = 0; opt.th1 = 0; opt.np = 20;
        values = {'a','a'; 'zoom','zoom'; 'fc','zoom'; ...
            'th1','th1'; 'np','np'; 'nn','np'};
    case 'animate'
        opt.a = []; opt.zoom = 0; opt.dth1 = 1; opt.nr = 1;
        opt.np = 20; opt.step = false; opt.fps = 30;
        values = {'a','a'; 'zoom','zoom'; 'fc','zoom'; ...
            'dth1','dth1'; 'nr','nr'; 'np','np'; 'nn','np'; ...
            'step','step'; 'fps','fps'; 'framerate','fps'};
    otherwise
        error('gears:GraphicsMode','Unknown internal graphics mode.');
end
known = {'save';'title'};
if ~isempty(values), known = [known; values(:,1)]; end
if ~isempty(flags), known = [known; flags(:,1)]; end
% With a bare 'save', these names still start graphics property pairs.
lineProperties = {'color','linecolor','linewidth','linestyle','marker','markersize', ...
    'markeredgecolor','markerfacecolor','displayname','tag','visible', ...
    'hittest','pickableparts','handlevisibility','clipping','userdata'};
k = 1;
while k <= numel(args)
    name = asText(args{k});
    if isempty(name)
        error('gears:GraphicsOptionName','Expected a nonempty graphics option name.');
    end
    key = lower(name);
    if key(1) == '-', key = key(2:end); end
    if strcmp(key,'save')
        opt.save = true;
        opt.fileName = [];
        if k < numel(args)
            candidate = args{k+1};
            if isnumeric(candidate) && isempty(candidate)
                k = k+1;
            elseif isText(candidate)
                candidate = asText(candidate);
                nextKey = lower(candidate);
                if ~isempty(nextKey) && nextKey(1) == '-'
                    nextKey = nextKey(2:end);
                end
                isOption = any(strcmp(nextKey,known));
                if allowLineArgs
                    isOption = isOption || any(strcmp(nextKey,lineProperties));
                end
                if ~isOption
                    opt.fileName = candidate;
                    k = k+1;
                end
            else
                error('gears:SaveFilename', ...
                    'Use ''save'',[] or ''save'',filename (text), not a boolean.');
            end
        end
    elseif strcmp(key,'title')
        requireValue(args,k,name);
        opt.title = onOff(args{k+1},name);
        k = k+1;
    else
        j = [];
        if ~isempty(values), j = find(strcmp(key,values(:,1)),1); end
        f = [];
        if ~isempty(flags), f = find(strcmp(key,flags(:,1)),1); end
        if ~isempty(j)
            requireValue(args,k,name);
            field = values{j,2};
            value = args{k+1};
            if strcmp(field,'step')
                value = onOff(value,name);
            else
                validateOption(field,value);
            end
            opt.(field) = value;
            k = k+1;
        elseif ~isempty(f)
            opt.(flags{f,2}) = flags{f,3};
        elseif allowLineArgs
            if ~isempty(regexp(name,'^[rgbcmykw+o*.x_|sd^v><ph:\-]+$','once'))
                lineArgs{end+1} = name; %#ok<AGROW>
            else
                % A graphics property and its value are consumed together,
                % so e.g. 'DisplayName','title' is never a title option.
                if strcmpi(mode,'pair') && ~any(strcmp(key,lineProperties))
                    error('gears:UnknownGraphicsOption', ...
                        'Unknown graphics option: %s.',name);
                end
                requireValue(args,k,name);
                value = args{k+1};
                if isa(value,'string') && isscalar(value) && ~ismissing(value)
                    value = char(value);
                end
                if strcmp(key,'linecolor')
                    name = 'Color';
                elseif name(1) == '-' && any(strcmp(key,lineProperties))
                    name = name(2:end);
                end
                lineArgs(end+1:end+2) = {name,value};
                k = k+1;
            end
        else
            error('gears:UnknownGraphicsOption','Unknown graphics option: %s.',name);
        end
    end
    k = k+1;
end
end

function requireValue(args,k,name)
if k == numel(args)
    error('gears:MissingGraphicsValue','A value is required after ''%s''.',name);
end
end

function value = onOff(value,name)
if isText(value)
    text = lower(strtrim(asText(value)));
    if strcmp(text,'on'), value = true; return; end
    if strcmp(text,'off'), value = false; return; end
elseif (isnumeric(value) || islogical(value)) && isscalar(value) ...
        && isreal(value) && isfinite(value) && (value == 0 || value == 1)
    value = logical(value);
    return
end
error('gears:InvalidOnOff', ...
    '''%s'' must be ''on''/''off'', numeric 1/0, or logical true/false.',name);
end

function tf = isText(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) ...
    || (isa(value,'string') && isscalar(value) && ~ismissing(value));
end

function text = asText(value)
if ~isText(value)
    error('gears:GraphicsText','Expected a character vector or a scalar string.');
end
text = char(value);
end

function validateOption(name,value)
base = {'real','finite','scalar'};
switch name
    case {'fig','nz'}
        rules = [base {'positive','integer'}];
    case 'np'
        rules = [base {'integer','>=',4,'<=',100}];
    case 'zoom'
        validateattributes(value,{'numeric'},[base {'nonnegative'}]);
        if value ~= 0 && value < 2
            error('gears:InvalidZoom','Zoom must be 0 (full view) or at least 2.');
        end
        return
    case 'beta'
        rules = [base {'>=',0,'<',90}];
    case {'a','nr','fps'}
        rules = [base {'positive'}];
    case 'dth1'
        rules = [base {'nonzero'}];
    otherwise
        rules = base;
end
validateattributes(value,{'numeric'},rules,mfilename,name);
end
