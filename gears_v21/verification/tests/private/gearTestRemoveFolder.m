function gearTestRemoveFolder(folder)
%GEARTESTREMOVEFOLDER Best-effort cleanup of a test-owned temporary folder.
% Windows export services or sync clients may briefly retain file handles.
if ~isfolder(folder), return; end
message = '';
for attempt = 1:5
    try
        [removed,message] = rmdir(folder,'s');
        if removed || ~isfolder(folder), return; end
    catch exception
        message = exception.message;
    end
    if attempt < 5
        drawnow;
        pause(0.2*attempt);
    end
end
warning('gears:TestCleanupDeferred', ...
    'Temporary test folder retained: %s. Cleanup failed: %s',folder,message);
end
