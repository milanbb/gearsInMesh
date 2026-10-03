function args = gearLineOptions(defaultColor,defaultWidth,lineArgs)
%GEARLINEOPTIONS Merge drawing defaults with explicit line overrides.
% Keep the envelope segment colours when only LineWidth is supplied.
% Place any LineSpec before property/value pairs, as required by plot.
narginchk(3,3)
specs = {};
propertyArgs = {};
hasColor = false;
hasWidth = false;
k = 1;
while k <= numel(lineArgs)
    name = lineArgs{k};
    if isa(name,'string'), name = char(name); end
    if ~isempty(regexp(name,'^[rgbcmykw+o*.x_|sd^v><ph:\-]+$','once'))
        specs{end+1} = name; %#ok<AGROW>
        hasColor = hasColor || ~isempty(regexp(name,'[rgbcmykw]','once'));
        k = k+1;
    else
        if k == numel(lineArgs)
            error('gears:MissingGraphicsValue','Missing line property value.');
        end
        hasColor = hasColor || strcmpi(name,'Color');
        hasWidth = hasWidth || strcmpi(name,'LineWidth');
        propertyArgs(end+1:end+2) = {name,lineArgs{k+1}}; %#ok<AGROW>
        k = k+2;
    end
end
args = specs;
if ~hasColor, args(end+1:end+2) = {'Color',defaultColor}; end
if ~hasWidth, args(end+1:end+2) = {'LineWidth',defaultWidth}; end
args = [args,propertyArgs];
end
