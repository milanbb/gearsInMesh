% VERIFYVALUERACK Check rack value semantics and independent gear u.
%
% Run runMeFirst in the package root, then add examples/rack to the
% path or make it Current Folder. Call this script by name in the Command Window.
%
% Closes figures, clears variables and the Command Window.
% Assertions check independent gear u values and retained rack value copies.
% Prints a PASS message if all assertions succeed; writes no files.
%
% Lengths use the module unit; input angles are degrees.
% Relative outputs use Current Folder; named files may be overwritten.

close all
clear
clc

rack = gearRack(1,'alpha',20,'c',0.167);
G1 = gear(rack,18,'u',0.70);
G2 = gear(rack,30,'u',0.90);

assert(~isa(rack,'handle'),'gearRack must be a value class.');
assert(isa(G1,'handle') && isa(G2,'handle'),'gear must remain a handle class.');
assert(abs(G1.u-0.70)<eps && abs(G2.u-0.90)<eps,'Initial u values are not independent.');

G1.u = 0.80;
assert(abs(G1.u-0.80)<eps,'G1.u was not updated.');
assert(abs(G2.u-0.90)<eps,'Changing G1.u changed G2.u.');

% Rebinding the original rack variable must not affect either stored rack copy.
rack = gearRack(2,'alpha',25,'c',0.10);
assert(abs(G1.rack.m-1)<eps && abs(G2.rack.m-1)<eps, ...
    'A gear did not retain its rack value copy.');
assert(abs(G1.rack.alpha-20)<eps && abs(G2.rack.alpha-20)<eps, ...
    'A gear rack copy changed unexpectedly.');

fprintf('gearRack value-semantics check: PASS\n');
fprintf('G1.u = %.3f, G2.u = %.3f; stored rack module = %.3f\n',G1.u,G2.u,G1.rack.m);
