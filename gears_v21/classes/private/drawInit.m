function [p,fh,ax] = drawInit(figNum)
% DRAWINIT Initialise a figure and equal-scale axes for internal drawings.
% [p,fh,ax] = drawInit() creates a figure; drawInit(number) reuses that figure.
% Clears the selected figure, resets drawing defaults and enables hold on.
% p is the figure number, fh the figure handle and ax the axes handle.

narginchk(0,1)
nargoutchk(0,3)

if nargin > 0
    validateattributes(figNum,{'numeric'},{'positive','integer','scalar'});
    figure(figNum);              % legacy: make this the current figure
else
    figure;                      % legacy: create current figure
end

% Keep the package graphics defaults exactly in the normal drawing path.
gkInit

% Important for Live Scripts: use the legacy current-figure/current-axes
% sequence instead of creating an Axes object explicitly with Parent=fh.
clf
hold on
axis equal

fh = gcf;
ax = gca;

if nargout > 0
    try
        p = get(fh,'Number');
    catch
        p = fh;                  % compatibility with very old MATLAB
    end
end
end
