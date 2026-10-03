function [x,y] = swap(x,y)
% SWAP Exchange two input values.
% [x,y] = swap(x,y). Internal helper.

    t = x;
    x = y;
    y = t;
end

