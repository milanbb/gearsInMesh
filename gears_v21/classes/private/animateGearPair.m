function animateGearPair(obj,opt)
%ANIMATEGEARPAIR Render cached contours; never alter the gear/rack objects.
% All name-value parsing occurs in gearsInMesh.animate (inline switch/case).
% Interactive mode replays a signed step index until Esc/window close.
% Automatic mode includes the initial/final states and clips its last step.
% Interactive P is a queued export action, not a motion/video-frame step.
% Snapshot export runs in the waiting loop, never recursively in a callback.
if ~opt.step
    travel=360*opt.nr;
    q=travel/abs(opt.dth1);
    if ~isfinite(travel) || ~isfinite(q) || q>=flintmax-1
        error('gearsInMesh:AnimationLength', ...
            'Too many animation steps; reduce nr or increase abs(dth1).');
    end
    nSteps=max(1,ceil(q-8*eps(max(1,q))));
else
    travel=NaN; nSteps=NaN; % nr is not an interactive click budget.
end
if opt.save, fname=videoFilename(opt.fileName); else, fname=''; end
m=obj.G1.rack.m; aa=opt.a; ratio=obj.G1.Rr/obj.G2.Rr;
[X1,Y1]=gearContour(obj.G1,'np',opt.np);
[X2,Y2]=gearContour(obj.G2,'np',opt.np);
[X1,Y1]=trRot2d(X1,Y1,0,0,-90);
[X2,Y2]=trRot2d(X2,Y2,0,0,90+180/obj.G2.z);
contactModel=[]; contactNote='off';
if opt.contactPoints
    try
        [~,~,contactModel]=gearPairContactPoints(obj,opt.th1,aa,sign(opt.dth1));
        contactNote='retained transverse involutes (one fixed flank)';
    catch ME
        if ~strncmp(ME.identifier,'gearsInMesh:Contact',19), rethrow(ME); end
        contactNote=['unavailable: ' ME.message];
        warning('gearsInMesh:ContactDisplayUnavailable','%s',contactNote);
    end
end
if isempty(opt.fig)
    [~,fh,ax]=drawInit;
else
    [~,fh,ax]=drawInit(opt.fig);
end
try
% A separate undocked window is needed for predictable keyboard focus/size.
set(fh,'WindowStyle','normal');
if isprop(fh,'WindowState'), set(fh,'WindowState','normal'); end
position=opt.figureSize;
if numel(position)==2, position=[100 100 position]; end
set(fh,'Units','pixels','Position',position,'Resize','off', ...
    'NumberTitle','off','Tag','gearsInMesh.Animation', ...
    'WindowKeyPressFcn',@keyPressed,'WindowButtonDownFcn',@mousePressed);
if opt.step
    set(fh,'Name','Gears in mesh: L forward, D backward, P save JPG, Esc stop');
else
    set(fh,'Name','Gears in mesh: automatic; Space pause, Esc stop');
end
setappdata(fh,'gearsAnimationStop',false);
setappdata(fh,'gearsAnimationPaused',false);
setappdata(fh,'gearsAnimationStep',0); % retained diagnostic field
setappdata(fh,'gearsAnimationQueue',[]); % +1/-1: motion; 0: export current figure.
setappdata(fh,'gearsAnimationSnapshotBase',snapshotBase(opt.snapshot,fh,''));
setappdata(fh,'gearsAnimationSnapshotNumber',0);
setappdata(fh,'gearsAnimationSnapshotsWritten',0);
setappdata(fh,'gearsAnimationSnapshotBusy',false);
setappdata(fh,'gearsAnimationSnapshotRecords', ...
    struct('file',{},'angle1',{},'index',{}));
setappdata(fh,'gearsAnimationFramesWritten',0);
setappdata(fh,'gearsAnimationRunning',true);
setappdata(fh,'gearsAnimationReady',false);
setappdata(fh,'gearsAnimationOptions',opt);
setappdata(fh,'gearsAnimationContactNote',contactNote);
setappdata(fh,'gearsAnimationContactsAvailable',~isempty(contactModel));
figureGuard=onCleanup(@() finishFigure(fh)); %#ok<NASGU>
drawSet('LineWidth',2,'LineColor','k');
width=gkGet('LineWidth'); color=gkGet('LineColor');
if ~isempty(opt.lineWidth), width=opt.lineWidth; end
if ~isempty(opt.lineColor), color=opt.lineColor; end
style={'LineWidth',width,'Color',color,'LineStyle',gkGet('LineStyle')};
h2=plot(ax,X2+aa,Y2,style{:},'Tag','gearsInMesh.Gear2');
h1=plot(ax,X1,Y1,style{:},'Tag','gearsInMesh.Gear1');
% Preserve the existing center symbols; no callback is processed here.
set(groot,'CurrentFigure',fh); set(fh,'CurrentAxes',ax);
drawPoint(1,m/4,0,0);
drawPoint(1,m/4,aa,0);
hContacts=[];
if ~isempty(contactModel)
    palette=get(ax,'ColorOrder');
    hContacts=plot(ax,NaN,NaN,'o','LineStyle','none','MarkerSize',7, ...
        'Color',palette(1,:),'MarkerFaceColor',palette(1,:), ...
        'Tag','gearsInMesh.ContactPoints');
end
if opt.zoom>0
    xlim(ax,[-opt.zoom*m opt.zoom*m]+obj.G1.Rr);
    ylim(ax,[-opt.zoom*m opt.zoom*m]);
else
    r1=max(hypot(X1,Y1)); r2=max(hypot(X2,Y2));
    xmin=min(-r1,aa-r2); xmax=max(r1,aa+r2); yr=max(r1,r2);
    pad=0.04*max([xmax-xmin,2*yr,m]);
    xlim(ax,[xmin-pad xmax+pad]); ylim(ax,[-yr-pad yr+pad]);
end
axis(ax,'equal'); axis(ax,'manual'); axis(ax,'off');
hTitle=get(ax,'Title');
set(hTitle,'String','','FontSize',12,'FontWeight','normal');
% Cache text data too: no recomputation of gear properties in the frame loop.
heading=sprintf('m = %g, z_1 = %g, z_2 = %g, x_1 + x_2 = %g, a = %g', ...
    m,obj.G1.z,obj.G2.z,obj.G1.x+obj.G2.x,aa);
% Process initial native layout once, then reapply the requested client size.
drawnow
if ~isgraphics(fh,'figure') || ~isgraphics(ax,'axes'), return; end
set(fh,'Units','pixels','Position',position);
catch ME
    if ~isgraphics(fh,'figure') || ~isgraphics(ax,'axes'), return; end
    rethrow(ME)
end
if opt.instructions, showInstructions(opt,contactNote); end
writer=[]; written=0; frameSize=[]; index=0; angle1=opt.th1;
lastAngle=angle1; completed=false;
while ~stopped(fh)
    if ~isgraphics(ax) || ~isgraphics(h1) || ~isgraphics(h2), break; end
    tick=tic;
    [x1,y1]=trRot2d(X1,Y1,0,0,angle1);
    [x2,y2]=trRot2d(X2,Y2,0,0,-angle1*ratio);
    set(h1,'XData',x1,'YData',y1);
    set(h2,'XData',x2+aa,'YData',y2);
    if ~isempty(hContacts) && isgraphics(hContacts)
        [xc,yc]=gearPairContactPoints(contactModel,angle1);
        set(hContacts,'XData',xc,'YData',yc);
        setappdata(fh,'gearsAnimationContactPoints',[xc(:) yc(:)]);
    else
        setappdata(fh,'gearsAnimationContactPoints',zeros(0,2));
    end
    lastAngle=angle1;
    setappdata(fh,'gearsAnimationAngle1',angle1);
    setappdata(fh,'gearsAnimationIndex',index);
    if opt.title
        if opt.step
            text=sprintf('%s\nInteractive: step %+d, angle_1 = %.6g deg',heading,index,angle1);
        else
            text=sprintf('%s\nFrame %d/%d, angle_1 = %.6g deg',heading,index+1,nSteps+1,angle1);
        end
        set(hTitle,'String',text);
    end
    setappdata(fh,'gearsAnimationReady',true);
    drawnow
    if stopped(fh), break; end
    if opt.save
        try
            frame=getframe(fh);
        catch ME
            if ~isgraphics(fh,'figure'), break; end
            rethrow(ME)
        end
        if stopped(fh), break; end
        if isempty(writer)
            % Lazy open: stopping before the first frame does not create an
            % empty AVI. Cleanup captures writer itself, not a nested scope.
            writer=VideoWriter(fname,'Motion JPEG AVI');
            writer.FrameRate=opt.fps;
            open(writer);
            videoGuard=onCleanup(@() closeVideoQuietly(writer)); %#ok<NASGU>
            frameSize=size(frame.cdata);
        elseif ~isequal(size(frame.cdata),frameSize)
            error('gearsInMesh:VideoFrameSize', ...
                'Captured frame size changed. Do not resize/dock or move the recording across displays with different scaling.');
        end
        writeVideo(writer,frame);
        written=written+1;
        if isgraphics(fh,'figure'), setappdata(fh,'gearsAnimationFramesWritten',written); end
    end
    if opt.step
        % Unlimited signed navigation. Integer indices make L then D return
        % to exactly the same sample; there is no accumulated rotation.
        direction=nextInteractiveStep(fh);
        if stopped(fh), break; end
        index=index+direction;
        if abs(index)>=flintmax || ~isfinite(opt.th1+index*opt.dth1)
            error('gearsInMesh:AnimationLength','Interactive angle exceeds the representable range.');
        end
        angle1=opt.th1+index*opt.dth1;
    else
        if index==nSteps, completed=true; break; end
        % A saved AVI is rendered as fast as possible. fps controls playback;
        % an unsaved preview is additionally paced near this rate.
        waitAutomatic(fh,opt,tick);
        if stopped(fh), break; end
        index=index+1;
        angle1=opt.th1+sign(opt.dth1)*min(index*abs(opt.dth1),travel);
    end
end
if ~isempty(writer)
    close(writer); % Do not hide errors on the normal close path.
    clear videoGuard
end
if opt.instructions
    if completed
        fprintf('Animation completed. Gear 1 angle: %.6g deg.\n',lastAngle);
    else
        fprintf('Animation stopped. Last displayed gear 1 angle: %.6g deg.\n',lastAngle);
    end
    if written>0
        fprintf('Video saved in %s (%d frames, %g fps).\n',fname,written,opt.fps);
    elseif opt.save
        fprintf('No video frame was written.\n');
    end
end
end

function direction=nextInteractiveStep(fh)
direction=0;
while ~stopped(fh)
    queue=getappdata(fh,'gearsAnimationQueue');
    if ~isempty(queue)
        action=queue(1);
        setappdata(fh,'gearsAnimationQueue',queue(2:end));
        setappdata(fh,'gearsAnimationStep',0);
        if action==0
            % No angle change and no additional AVI frame. L/P/D actions
            % remain in event order even when several keys were queued.
            saveCurrentSnapshot(fh);
            continue
        end
        direction=action;
        return
    end
    pause(0.02);
    drawnow
end
end

function waitAutomatic(fh,opt,tick)
while ~stopped(fh)
    paused=getappdata(fh,'gearsAnimationPaused');
    if ~paused && (opt.save || toc(tick)>=1/opt.fps), return; end
    pause(0.01);
    drawnow
end
end

function keyPressed(src,event)
if ~isgraphics(src,'figure'), return; end
opt=getappdata(src,'gearsAnimationOptions');
switch lower(event.Key)
    case 'escape'
        setappdata(src,'gearsAnimationStop',true);
    case 'p'
        if opt.step, enqueueStep(src,0); end % snapshot, no motion
    case 'h'
        showInstructions(opt,getappdata(src,'gearsAnimationContactNote'));
    case 'space'
        if opt.step
            enqueueStep(src,1);
        else
            setappdata(src,'gearsAnimationPaused',~getappdata(src,'gearsAnimationPaused'));
        end
    case {'l','rightarrow','uparrow','return'}
        if opt.step, enqueueStep(src,1); end
    case {'d','leftarrow','downarrow'}
        if opt.step, enqueueStep(src,-1); end
end
end

function mousePressed(src,~)
if ~isgraphics(src,'figure'), return; end
opt=getappdata(src,'gearsAnimationOptions');
switch get(src,'SelectionType')
    case {'normal','open'}
        if opt.step, enqueueStep(src,1); end
    case 'alt'
        if opt.step, enqueueStep(src,-1); end
    case 'extend'
        setappdata(src,'gearsAnimationStop',true);
end
end

function enqueueStep(fh,direction)
queue=getappdata(fh,'gearsAnimationQueue');
setappdata(fh,'gearsAnimationQueue',[queue direction]);
setappdata(fh,'gearsAnimationStep',direction);
end

function base=snapshotBase(value,fh,callFolder)
% Empty base keeps the stored name relative; pwd resolves it at P export.
% Match drawSave: an input extension is replaced by .jpg, not a format flag.
if isempty(value)
    folder=callFolder;
    name=sprintf('Fig%g',get(fh,'Number'));
else
    [folder,name,~]=fileparts(value);
    % Absolute POSIX paths and Windows drive/UNC/root-relative paths.
    absolute=~isempty(folder) && (folder(1)=='/' || ...
        (ispc && (folder(1)=='\' || ...
        (numel(folder)>=3 && isletter(folder(1)) && folder(2)==':' && ...
        (folder(3)=='/' || folder(3)=='\')))));
    if ~absolute, folder=fullfile(callFolder,folder); end
end
base=fullfile(folder,name);
end

function saveCurrentSnapshot(fh)
% Only called by the interactive waiting loop: callbacks merely enqueue.
% Export exactly this figure, with its current title, limits and markers.
if stopped(fh) || ~isequal(getappdata(fh,'gearsAnimationReady'),true), return; end
if isequal(getappdata(fh,'gearsAnimationSnapshotBusy'),true), return; end
setappdata(fh,'gearsAnimationSnapshotBusy',true);
busyGuard=onCleanup(@() finishSnapshot(fh)); %#ok<NASGU>
opt=getappdata(fh,'gearsAnimationOptions');
base=snapshotBase(opt.snapshot,fh,pwd);
setappdata(fh,'gearsAnimationSnapshotBase',base);
number=getappdata(fh,'gearsAnimationSnapshotNumber')+1;
angle=getappdata(fh,'gearsAnimationAngle1');
index=getappdata(fh,'gearsAnimationIndex');
try
    fname=sprintf('%s_%04d.jpg',base,number);
    while isfile(fname) || isfolder(fname)
        number=number+1;
        fname=sprintf('%s_%04d.jpg',base,number);
    end
    % drawSave creates missing folders; explicit fh avoids gcf ambiguity.
    fname=drawSave(fname,'fig',fh,'r',300);
catch ME
    % Closing the window during export is an ordinary animation stop.
    if ~isgraphics(fh,'figure'), return; end
    warning('gearsInMesh:SnapshotSaveFailed', ...
        'Snapshot was not saved: %s. Animation can continue.',ME.message);
    return
end
if ~isgraphics(fh,'figure'), return; end
setappdata(fh,'gearsAnimationSnapshotNumber',number);
count=getappdata(fh,'gearsAnimationSnapshotsWritten')+1;
setappdata(fh,'gearsAnimationSnapshotsWritten',count);
records=getappdata(fh,'gearsAnimationSnapshotRecords');
records(end+1)=struct('file',fname,'angle1',angle,'index',index);
setappdata(fh,'gearsAnimationSnapshotRecords',records);
opt=getappdata(fh,'gearsAnimationOptions');
if opt.instructions
    fprintf('Snapshot saved in %s (gear 1 angle %.6g deg).\n',fname,angle);
end
end

function finishSnapshot(fh)
if isgraphics(fh,'figure'), setappdata(fh,'gearsAnimationSnapshotBusy',false); end
end

function showInstructions(opt,contactNote)
fprintf('\nGears in mesh animation: %s\n',upper(opt.mode));
fprintf('  Focus the animation window before pressing keys.\n');
if opt.step
    fprintf('  L / Right arrow / left mouse button : forward by dth1 (%g deg).\n',opt.dth1);
    fprintf('  D / Left arrow / right mouse button : backward by dth1.\n');
    fprintf('  P : save the displayed figure as a 300-dpi JPG; no movement.\n');
    if isempty(opt.snapshot)
        fprintf('      Default name: Fig<number>_0001.jpg, _0002.jpg, ...\n');
    else
        fprintf('      Snapshot stem: %s (next free numbered JPG).\n',opt.snapshot);
    end
    fprintf('      Snapshot export is separate from the save option for AVI.\n');
    fprintf('  Space / Enter : forward. nr does not limit interactive steps.\n');
    fprintf('  The initial frame is shown; motion waits for your input.\n');
else
    fprintf('  Automatic travel: %g turns, signed step %g deg; fps = %g.\n',opt.nr,opt.dth1,opt.fps);
    fprintf('  Space : pause/resume. L and D do not change automatic playback.\n');
end
fprintf('  Esc / close window / middle mouse button : stop. H : show these instructions.\n');
fprintf('  Contact points: %s.\n',contactNote);
if opt.contactPoints
    fprintf('  Geometric contacts only: no fillet collision, load or tooth-root strength analysis.\n');
end
if opt.save && opt.step
    fprintf('  AVI: one frame per displayed step; waiting times are not recorded.\n');
elseif opt.save
    fprintf('  AVI export runs without real-time waiting; fps sets video playback speed.\n');
end
end

function tf=stopped(fh)
tf=~isgraphics(fh,'figure');
if ~tf, tf=getappdata(fh,'gearsAnimationStop'); end
end

function finishFigure(fh)
if isgraphics(fh,'figure')
    setappdata(fh,'gearsAnimationRunning',false);
    setappdata(fh,'gearsAnimationReady',false);
    set(fh,'WindowKeyPressFcn',[],'WindowButtonDownFcn',[],'Resize','on', ...
        'Name','Gears in mesh');
    % Changing Resize can change native window decorations on Windows.
    % Reapply client Position after that final layout change, not before it.
    opt=getappdata(fh,'gearsAnimationOptions');
    target=opt.figureSize;
    if numel(target)==2, target=[100 100 target]; end
    for attempt=1:3
        drawnow
        if ~isgraphics(fh,'figure'), return; end
        set(fh,'Units','pixels','Position',target);
    end
end
end

function closeVideoQuietly(writer)
try
    close(writer);
catch
    % Never replace an original capture/write/interrupt error during cleanup.
end
end

function fname=videoFilename(value)
if isempty(value), fname='gearsInMesh.avi'; return; end
[folder,base,ext]=fileparts(value);
if isempty(base) || any(strcmp(base,{'.','..'}))
    error('gearsInMesh:VideoFilename','A video filename is required.');
end
if ~isempty(ext) && ~strcmpi(ext,'.avi')
    error('gearsInMesh:VideoFormat','Animation export uses AVI; use .avi or omit the extension.');
end
if ~isempty(folder) && ~isfolder(folder)
    [ok,msg]=mkdir(folder);
    if ~ok, error('gearsInMesh:VideoFolder','Cannot create output folder: %s',msg); end
end
fname=fullfile(folder,[base '.avi']);
end
