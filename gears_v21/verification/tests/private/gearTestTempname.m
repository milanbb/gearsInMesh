function name=gearTestTempname
%GEARTESTTEMPNAME Allocate a unique test path beneath package testsOutput.
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
folder=fullfile(root,'testsOutput');
if ~isfolder(folder), mkdir(folder); end
name=tempname(folder);
end
