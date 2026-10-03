classdef gearRack
    % GEARRACK Define a basic normal rack (value class).
    %   rack = gearRack(m)
    %   rack = gearRack(m,'alpha',20,'c',0.167)
    %
    % m is a positive normal module and sets the length unit. alpha is the normal
    % pressure angle in degrees (default 20); c is a dimensionless clearance
    % coefficient (default 0.167). The constructor requires 0<alpha<90 and
    % 0<=c<(pi/4-tand(alpha))*(1-sind(alpha))/cosd(alpha).
    % The three properties are read-only. Each gear stores a value copy.
    % Set tip shortening on a gear with gear(rack,z,'u',value), not on the rack.
    %
    % Display and output:
    %   print(rack)                      % Command Window
    %   print(rack,'data/rack.txt')      % character filename, not a file ID
    %   plot(rack,'fig',2,'title',false,'save','figures/rack')
    %   gearGenerating(rack,7,'x',0.2,'beta',15,'title',false)
    % gearGenerating draws successive rack positions in one static figure;
    % it is not an animation. z is an integer >1; beta is in degrees, x is a
    % profile-shift coefficient. title accepts on/off, true/false or 1/0
    % (default on). Rack drawing styles are fixed by these methods.
    % 'save',[] or bare 'save' writes Fig<number>.jpg; a name writes that JPG.
    % Missing output folders are created. Names may have a leading '-'.
    % Printed length labels use mm. The clearance coefficient c has no unit;
    % the corresponding rack clearance length is m*c.
    %
    % Geometry:
    %   [x,y,dydx,dx,dy,ddx,ddy] = calcProfile(rack,n,t)
    %   [x,y] = calcPoints(rack,form,nl,nr,np)
    %   [xx,yy,rho,xx0,yy0] = calcKeyPoints(rack)
    %   L = calcLength(rack)
    % Segments n=1..4: top straight, inclined flank, circular corner, bottom
    % straight. The segment parameter t ranges from 0 to 1.
    %
    % Run runMeFirst from the root. See examples/rack/README.md and
    % doc/gearRack_doc.mlx. Internal helpers are bundled in classes/private.
    % See also gear, gearsInMesh, gear3d.

    properties (SetAccess = private)
        alpha        % normal pressure angle in degrees
        m            % normal module
        c            % dimensionless clearance coefficient
    end
           
    methods
        function obj = gearRack(m,varargin)
            
            narginchk(1,inf)
            validateattributes(m, {'numeric'}, {'positive','real','scalar'});
            
            % default values
            alpha = 20;
            c = 0.167;
            
            if mod(numel(varargin),2) ~= 0
                error('gearRack:NameValue','Constructor options must be name-value pairs.');
            end
            % scan options 
            if ~isempty(varargin)
                for k = 1:2:length(varargin)
                    switch lower(varargin{k})
                        case {'alpha','-alpha'}
                            alpha = varargin{k + 1};
                        case {'c','-c'}
                            c = varargin{k + 1};
                        case {'u','-u'}
                            error('gearRack:GearOnlyOption', ...
                                ['u belongs to a gear, not to the basic rack. ', ...
                                 'Use gear(rack,z,''u'',value) or g.u = value.']);
                        otherwise
                    end
                end
            end
            
            validateattributes(alpha, {'numeric'}, {'positive','<',90,'real','scalar'});
            cm = (pi/4 - tand(alpha))*(1 - sind(alpha))/cosd(alpha);
            validateattributes(c,     {'numeric'}, {'>=',0,'<',cm,'real','scalar'});
            
            obj.alpha = alpha;
            obj.m = m;
            obj.c = c;
        end
    end
    
    methods
        function gearGenerating(obj,z,varargin)
            %GEARGENERATING Draw successive generating-rack positions.
            % 'title',on/off/1/0/true/false (default on).
            % 'save',[] or 'save',filename saves a JPG; bare 'save' also works.
            narginchk(2,inf)
            nargoutchk(0,0)
            validateattributes(z,{'numeric'},{'>',1,'integer','scalar'});
            opt = parseGearPlotOptions('generating',varargin);
            beta = opt.beta;
            x = opt.x;
            save = opt.save;
            dth = 5;
            th = 150;
            if z < 5, th = 270; end
            % calculate points (4 tooth)
            [xx,yy] = calcPoints(obj,1,2,1);   
            R = obj.m*z/2;
            e = obj.m*x;  % profile shift
            [~,fh,ax] = drawInit;
            set(fh,'Tag','gearRack.Generation');
            axis(ax,'off');           
            for th = dth:dth:th
                x0 = (-R*sind(th)+ R*th*pi/180*cosd(th))/cosd(beta);
                y0 =  (R*cosd(th)+ R*th*pi/180*sind(th))/cosd(beta);
                [x,y] = trRot2d(xx/cosd(beta),yy+e,x0,y0,th);
                drawPolyline(x,y,'k')
            end
            x0 = 0;
            y0 = R/cosd(beta);
            [x,y] = trRot2d(xx/cosd(beta),yy+e,x0,y0,0);
            drawPolyline(x,y,'LineWidth',2,'Color','r')
            R1 = R + 2*obj.m;
            x1 = max([-R1,xx(end)]);
            x2 = min([R,xx(1)]);
            y2 = R1;
            y1 = R*cos(min([5,z])*pi/z)-obj.m;
            drawLimits(x1,x2,y1,y2)
            drawCircle(0,0,R,'r')
            drawPoint(1,obj.m/3,0,0)
            if opt.title
                title(ax,...
                sprintf('z = %d, x = %g, %s = %g^0',z,e/obj.m,'\beta',beta),...
                'FontSize',12,'FontWeight','normal')
            else
                title(ax,'');
            end
            if save                
                fn = drawSave(opt.fileName,'fig',fh);
                fprintf('Figure is saved in file %s\n',fn)
            end
        end
        
        function print(obj,fnam)
            narginchk(1,2)
            nargoutchk(0,0)
            if nargin < 2
                fid = 1;  % command window
            else
                validateattributes(fnam,{'char'},{'nonempty'});
                % Named text output follows the same current-folder rule as JPG.
                folder = fileparts(fnam);
                if ~isempty(folder) && ~isfolder(folder)
                    [ok,msg] = mkdir(folder);
                    if ~ok, error('gearRack:ExportFile','Cannot create output folder: %s',msg); end
                end
                [fid,errmsg] = fopen(fnam,'w');
                if fid < 0
                    warning(errmsg);
                    fid = 1;
                end
            end
            [xx,yy,rho,xx0,yy0] = calcKeyPoints(obj);
            [dd,mm,ss] = deg2dms(obj.alpha); 
            L = calcLength(obj);
            fprintf(fid,'Gear rack data\n');             
            fprintf(fid,'                                    Module:%18.4f       mm\n',obj.m);
            fprintf(fid,'                            Pressure angle:%14d:%02d:%02d\n',dd,mm,ss);
            fprintf(fid,'               Tip clearance coefficient c:%18.4f\n',obj.c);
            fprintf(fid,'Calculated parameters\n') ;           
            fprintf(fid,'                              Filet radius:%18.4f       mm\n',rho);
            fprintf(fid,'                                     Point:      xx          yy \n');
            for n = 1:4
            fprintf(fid,'                                        #%d:%12.4f%12.4f mm\n',n,xx(n),yy(n));
            end
            fprintf(fid,'                             Fillet center:%12.4f%12.4f mm\n',xx0,yy0); 
             fprintf(fid,'                                   Segment:            Length\n');
            for n = 1:4
            fprintf(fid,'                                        #%d:%18.4f       mm\n',n,L(n));
            end
            if fid > 1
                fclose(fid);
            end
        end

        function plot(obj,varargin)
            %PLOT Draw the normal rack profile and its dimensions.
            % 'title',on/off/1/0/true/false (default on).
            % 'save',[] or 'save',filename; legacy bare 'save' remains valid.
            % 'fig',number reuses a figure. The legacy 'beta' option is
            % accepted; as before, this method draws the normal rack section.
            narginchk(1,inf)
            nargoutchk(0,0)
            opt = parseGearPlotOptions('rack',varargin);
            newfig = isempty(opt.fig);
            fig = opt.fig;
            save = opt.save;
            % get key points
            [xx,yy,~,xx0,yy0] = calcKeyPoints(obj);
            % open figure window
            if newfig
                [~,fh,ax] = drawInit; % new
            else
                [~,fh,ax] = drawInit(fig); % old
            end
            set(fh,'Tag','gearRack.Profile');
            % form polygon
            form = 2;
            [x,y] = calcPoints(obj,form,1,0);
            n = length(x);
            x(n + 1) = x(n);
            y(n + 1) = yy(5) - obj.m/4;
            x(n + 2) = x(1);
            y(n + 2) = y(n+1);            
            % fill rack
            col = 0.85*[1,1,1]; % gry
            fillPolygon(col,x,y);                                   
            % draw profil
            %drawSet('LineWidth',2)
            drawPolyline(x(1:n),y(1:n),'k','LineWidth',2)                                  
            % pitch line
            drawLine(x(n),0,x(1),0,'k-.');
            % add dimensions
            drawSet('LineWidth',1)
            drawSet('FontSize',12,'textColor','k')
            ad1 = obj.m/10; % arrow width
            ad2 = ad1/2;    % arrow height
            aform = 2;      % arrow form 1,2,3,or 11
            xd = obj.m/2;   % basic step
            % tooth height
            drawVDim(aform,ad1,ad2, xx(2),yy(2),xx(3),yy(3), xx(5)+xd,0)
            drawVDim(aform,ad1,ad2, xx(2),yy(2),xx(5),yy(5), xx(5)+2*xd,0)
            % tooth addendum
            drawVDim(aform,ad1,ad2,-xx(2),yy(2),-obj.m*pi/2,0,    -3*xd, xd)
            drawVDim(aform,ad1,ad2,-xx(5),yy(5),-obj.m*pi/2,0,    -3*xd,-xd)
            drawVDim(aform,ad1,ad2,-xx(5),yy(5),-xx(3),yy(3), -xd,-xd)
            % tooth pitch
            drawHDim(aform,ad1,ad2,obj.m*pi/4,0,obj.m*pi/4-obj.m*pi, 0,0,yy(1)+2*xd)
            drawHDim(aform,ad1,ad2,obj.m*pi/4,0,-obj.m*pi/4, 0,0,yy(1)+xd)            
            % pressure angle
            drawAngDim3p(aform,ad1,ad2,pi*obj.m/4,0,pi*obj.m/4,obj.m/2,xx(2),yy(2),3*obj.m/4,-30)            
            % mark key points
            scatter(xx(1),yy(1),30,'k','filled')
            scatter(xx(2),yy(2),30,'k','filled')
            scatter(xx(3),yy(3),30,'k','filled')
            scatter(xx(4),yy(4),30,'k','filled')
            scatter(xx(5),yy(5),30,'k','filled')
            scatter(xx0,yy0,30,'k','filled')            
            % label points
            drawSet('textColor','r')
            drawText(xx(1),yy(1),'1')
            drawText(xx(2),yy(2),'2')
            drawText(xx(3),yy(3),'3')
            drawText(xx(4),yy(4),'4')
            drawText(xx(5),yy(5),'5')
            drawText(xx0,yy0,'0')            
            % draw axes
            drawAxes(3,ad1,1.25*obj.m,0,0)            
            % add title
            if opt.title
                title(ax,'Gear rack tooth profile','FontSize',12,'FontWeight','normal')
            else
                title(ax,'');
            end            
            % don't show axes
            axis(ax,'off');
            %%%%%%%%%%%
            if save
               fn = drawSave(opt.fileName,'fig',fh);
                fprintf('Figure is saved in file %s\n',fn)
            end
        end
    end
    
    methods 
        function [x,y,dydx,dx,dy,ddx,ddy] = calcProfile(obj,n,t)
            % Calculate points, derivatives and second derivatives on n-th
            % profile segment
            validateattributes(n,{'numeric'},{'>=',1,'<=',4,'integer','scalar'});
            validateattributes(t,{'numeric'},{'real','vector'});
            if n ~= 3
                [xx,yy] = calcKeyPoints(obj);
                x = xx(n) + (xx(n+1) - xx(n))*t;
                y = yy(n) + (yy(n+1) - yy(n))*t;
                dydx = (yy(n+1) - yy(n))/(xx(n+1) - xx(n))*ones(size(t));
                if nargout > 3
                    dx = (xx(n+1) - xx(n));
                    dy = (yy(n+1) - yy(n));
                    ddx = zeros(size(t));
                    ddy = zeros(size(t));
                end
            else
                [~,~,rho,xx0,yy0] = calcKeyPoints(obj);
                tt = obj.alpha + t*(90 - obj.alpha);
                x = xx0 - rho*cosd(tt);
                y = yy0 - rho*sind(tt);
                dydx =  - 1./tand(tt);
                if nargout > 3
                    dtt = (90 - obj.alpha)/180*pi;
                    dx  =  rho*sind(tt)*dtt;
                    dy  = -rho*cosd(tt)*dtt;
                    ddx =  rho*cosd(tt)*dtt^2;
                    ddy =  rho*sind(tt)*dtt^2;
                end
            end
        end
        function [x,y] = calcPoints(obj,form,nl,nr,np)
            % calculate points on the rack
            % Input:
            % obj  -- rack
            % form -- 1= sym, 2=asym
            % nl   -- number of periods on left
            % nr   -- number of periods on right
           
            narginchk(4,5)
            nargoutchk(2,2)
            
            % check input
            validateattributes(form,{'numeric'},{'>=',1,'<=',2,'integer','scalar'});
            validateattributes(nl,{'numeric'},{'>=',0,'integer','scalar'});
            validateattributes(nr,{'numeric'},{'>=',0,'integer','scalar'});

            % set optional argument
            if nargin < 5                
                np = 90 - obj.alpha; % # of points on fillet
            else
                validateattributes(np,{'numeric'},{'positive','<',290,'integer','scalar'});
            end
            
            p = obj.m*pi;  % period
            
            % calculate key points
            [XX,YY,rho,XX0,YY0] = calcKeyPoints(obj);
            
            % calculate half period
            x    = []; y = [];
            x(1) = XX(5); y(1) = YY(5);
            x(2) = XX(4); y(2) = YY(4);
            [xx,yy] = evalCircle(XX0,YY0,rho,linspace(-90,-180+obj.alpha,np));
            x = [x xx]; y = [y yy];
            n = length(x);
            x(n+1) = XX(2); y(n+1) = YY(2);
            x(n+2) = XX(1); y(n+2) = YY(1);
            
            % miror period    
            switch form
                case 1
                    xx = [x -fliplr(x)];
                    yy = [y  fliplr(y)];
                case 2
                    xx = [  -fliplr(x) + p x];
                    yy = [   fliplr(y) y];
            end
            
            % now we have data for -m*pi/2 to m*pi/2 or 0 to m*pi
            x = xx;
            y = yy;
                           
            % add periods on right
            for n = 1:nr
                x = [(xx + n*p) x];
                y = [ yy     y];
            end
            
            % add periods to left
            for n = 1:nl
                x = [x  (xx - p*n)];
                y = [y       yy];
            end
            
            % clean
            [x,y] = deleteDuplicate(x,y);
        end
    end
    
     methods 
         function [xx,yy,rho,xx0,yy0] = calcKeyPoints(obj)
            % Calculate key points of the half of the profile of standard
            % rack (standard, unshortened upper height = module)
            % Bottom fillet radius
            rho =  obj.m*obj.c/(1 - sind(obj.alpha));
            % characteristics points
            xx(1) = 0;
            yy(1) =  obj.m;
            xx(2) =  obj.m*(pi/4 - tand(obj.alpha));
            yy(2) =  obj.m;
            xx(3) =  obj.m*(pi/4 + tand(obj.alpha));
            yy(3) = -obj.m;
            xx(4) =  xx(3) + rho*cosd(obj.alpha);
            yy(4) = -obj.m*(1 + obj.c);
            xx(5) =  obj.m*pi/2;
            yy(5) =  yy(4);
            % center point of the filet
            xx0 = xx(4);
            yy0 = yy(4) + rho;
        end            
        function L = calcLength(obj)
            [xx,yy,rho,~,~] = calcKeyPoints(obj);
            L = zeros(4,1);
            for n = 1:4
                if n ~= 3
                    L(n) = sqrt((xx(n+1) - xx(n))^2 + (yy(n+1) - yy(n))^2);
                else
                    L(n) = rho*(90 - obj.alpha)*pi/180;
                end
            end
        end
    end
    
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

function [x,y] = deleteDuplicate(X,Y)
%DELETEDUPLICATE Delete duplicate entries in X,Y arrays which forms a
%contour
    tol = 1e-4;
    narginchk(2,2)
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
