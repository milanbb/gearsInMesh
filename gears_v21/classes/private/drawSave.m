function varargout = drawSave(fileName,varargin)
%DRAWSAVE Save a figure as a JPG without exporting a Live Editor figure directly.
%
% drawSave() or drawSave([])              -> Fig<number>.jpg
% drawSave('name')                        -> name.jpg
% drawSave('figures/name')                -> figures/name.jpg
% drawSave(name,'r',600)                  -> resolution in dpi
% drawSave(name,'fig',fh)                 -> source figure handle
%
% The source figure is NOT sent directly to print/exportgraphics.  This is
% important for figures displayed inline by the Live Editor, where direct
% export can block.  Instead, the visible graphics are copied to a temporary
% ordinary hidden figure, and that figure is printed using the painters
% renderer.

narginchk(0,inf)
nargoutchk(0,1)

if nargin == 0
    fileName = [];
end

res = 300;
fh = [];

if mod(numel(varargin),2) ~= 0
    error('drawSave:Options','Options must be name-value pairs.');
end

for k = 1:2:numel(varargin)
    key = lower(textValue(varargin{k}));
    if ~isempty(key) && key(1) == '-'
        key = key(2:end);
    end

    switch key
        case 'r'
            value = varargin{k+1};
            if ischar(value) || isa(value,'string')
                switch lower(textValue(value))
                    case {'low','l'}
                        res = 100;
                    case {'medium','m'}
                        res = 300;
                    case {'high','h'}
                        res = 600;
                    otherwise
                        error('drawSave:Resolution','Unknown resolution preset.');
                end
            else
                validateattributes(value,{'numeric'}, ...
                    {'finite','real','integer','scalar','>=',10,'<=',1200});
                res = value;
            end

        case 'f'
            fileName = varargin{k+1};

        case 'fig'
            fh = varargin{k+1};
            if ~isscalar(fh) || ~isgraphics(fh,'figure')
                error('drawSave:Figure','Expected a valid scalar figure handle.');
            end

        otherwise
            error('drawSave:Options','Unknown option: %s.',key);
    end
end

if isempty(fh)
    fh = gcf;
end

if isnumeric(fileName) && isempty(fileName)
    fileName = '';
else
    fileName = textValue(fileName);
end

if isempty(fileName)
    fname = sprintf('Fig%g.jpg',get(fh,'Number'));
else
    [folder,base,~] = fileparts(fileName);
    if isempty(base) || any(strcmp(base,{'.','..'}))
        error('drawSave:Filename','A filename, not only a folder, is required.');
    end
    if ~isempty(folder) && ~isfolder(folder)
        [ok,msg] = mkdir(folder);
        if ~ok
            error('drawSave:Folder','Cannot create output folder: %s',msg);
        end
    end
    fname = fullfile(folder,[base '.jpg']);
end

% -------------------------------------------------------------------------
% Do not export the Live Editor/inline figure itself.  Copy its direct
% graphics children to a temporary ordinary figure and export that copy.
% -------------------------------------------------------------------------
pos = get(fh,'Position');
if numel(pos) ~= 4 || any(~isfinite(pos))
    pos = [100 100 560 420];
end
pos(1:2) = [100 100];

bg = get(fh,'Color');

tmp = figure('Visible','off', ...
    'WindowStyle','normal', ...
    'Units','pixels', ...
    'Position',pos, ...
    'Color',bg, ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'NumberTitle','off', ...
    'Renderer','painters');

cleanupObj = onCleanup(@() closeTemporaryFigure(tmp));

kids = fh.Children;
if isempty(kids)
    error('drawSave:EmptyFigure','The source figure contains no graphics to save.');
end
copyobj(kids,tmp);

set(tmp,'PaperPositionMode','auto');

% Export only the ordinary temporary figure.  No drawnow/exportgraphics is
% used here because both have been observed to block for the inline source.
print(tmp,fname,'-djpeg',sprintf('-r%d',res),'-painters');

clear cleanupObj
closeTemporaryFigure(tmp);

if nargout > 0
    varargout{1} = fname;
end
end

function value = textValue(value)
if isa(value,'string') && isscalar(value) && ~ismissing(value)
    value = char(value);
end
if ~ischar(value) || (~isempty(value) && ~isrow(value))
    error('drawSave:Text','Expected a character vector or a scalar string.');
end
end

function closeTemporaryFigure(fh)
if isscalar(fh) && isgraphics(fh,'figure')
    delete(fh);
end
end
