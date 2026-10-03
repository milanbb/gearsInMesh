function [sol, itHist, ierr, resnorm, output] = nsolve(f, x0, varargin)
% NSOLVE  Unified nonlinear solver (Newton–Krylov & Shamanskii/Chord).
%
%   [sol, itHist, ierr] = nsolve(f, x0, 'Name',Value, ...)
%   [sol, itHist, ierr, resnorm, output] = nsolve(...)
%
% Description:
%   NSOLVE combines two iterative algorithms for solving nonlinear systems:
%   • Newton–Krylov methods (matrix-free, inexact Newton with Krylov subsolvers)
%   • Shamanskii / Newton / Chord methods (explicit Jacobian, factored and reused)
%
% Source:
%   Adapted from C. T. Kelley's NSOL and NSOLA and their helper routines,
%   distributed in John Burkardt's KELLEY collection:
%   https://people.sc.fsu.edu/~jburkardt/m_src/kelley/kelley.html
%   The upstream names are nsol.m and nsola.m; nsolve.m is the combined,
%   extended interface supplied here. See doc/THIRD_PARTY_NOTICES.txt.
%
% Inputs:
%   f        - Function handle, returns residual vector same length as x0
%   x0       - Initial guess (vector)
%
% Name–Value options (case-insensitive):
%   Common:
%     'Jacobian'       [false]  true: F returns [residual,J]; use damped
%                              analytical Newton (overrides Algorithm).
%                              Optional finite-difference polishing is skipped.
%     'AbsTol'         [1e-8]    absolute RMS residual tolerance
%     'RelTol'         [1e-8]    relative RMS residual tolerance
%     'MaxIter'        [40]      max outer iterations
%     'Display'        ['off']   {'off','final','iter'}
%     'Algorithm'      ['newtonKrylov'] {'newtonKrylov','shamanskii','newton','chord'}
%
%   Newton–Krylov (Algorithm='newtonKrylov'):
%     'KrylovIter'     [40]      Arnoldi/inner iterations (or GMRES(m) subspace)
%     'Method'         ['gmres'] {'gmres','gmresm','bicgstab','tfqmr'}
%     'Reorth'         [1]       GMRES reorth: 1=BH, 2=never, 3=always
%     'RestartLimit'   [20]      GMRES(m) max restarts
%     'EtaMax'         [0.9]     Eisenstat–Walker cap for inner tolerance
%     'ArmijoAlpha'    [1e-4]    Armijo decrease parameter
%     'LineSearchMax'  [50]      max backtracking steps
%     'Sigma0'         [0.1]     parab3p lower clamp factor
%     'Sigma1'         [0.5]     parab3p upper clamp factor
%
%   Shamanskii / Newton / Chord (Algorithm='shamanskii'|'newton'|'chord'):
%     'ISham'          [1000]    recompute J every ISham accepted steps (Shamanskii)
%     'RSham'          [0.5]     recompute J if residual ratio > RSham
%
%   Post-processing (enabled by default; skipped with Jacobian=true):
%     'PolishRoots'    [true]    polish a converged scalar or vector root
%     'PolishIters'    [5]       max iterations for the polish step (0–5 sensible)
%
% Backward-compatibility (auto-detected):
%   Legacy nsola: nsolve(f,x0,tolVec,parmsVec), where
%     tolVec=[AbsTol RelTol]; parmsVec=[MaxIter KrylovIter EtaMax methodCode RestartLimit].
%                  methodCode: 1 GMRES, 2 GMRES(m), 3 BiCGSTAB, 4 TFQMR
%   Legacy nsol: nsolve(x,f,tolVec,parmsVec), where
%     tolVec=[atol rtol]; parmsVec=[MaxIter ISham RSham].
%
% Outputs:
%   sol      - Final iterate (column vector)
%   itHist   - (k+1)×3 array: [RMS_residual, cumFunEvals, aux]
%                • For Newton–Krylov: aux = Armijo backtrack count
%                • For Shamanskii:   aux = cumulative Jacobian refresh count
%   ierr     - Exit flag:
%                +1  converged to tolerance
%                 0  max iterations reached (not converged)
%                -2  line search failure (Newton–Krylov)
%                -1  evaluation failure / nonfinite residual
%   resnorm  - Final RMS residual; may improve beyond itHist after polishing
%   output   - Struct with fields:
%                .iterations  - Number of outer iterations performed
%                .funcCount   - Total function evaluations (includes polish evals if used)
%                .algorithm   - Algorithm type string
%                .method      - Inner method (Newton–Krylov) or 'diffjac' (Shamanskii)
%                .message     - Convergence/failure message ('... (polished)' if polish improved residual)
%
% Notes on usage of outputs:
%   • sol is an n×1 column vector containing the approximate solution to f(x) = 0,
%     where n = numel(x0). For example, if x0 has length 2, sol will be 2×1 and
%     sol(1) is the first variable, sol(2) the second.
%   • itHist is useful for plotting convergence history:
%       plot(itHist(:,1))              % RMS residual vs. iteration
%       plot(itHist(:,2), itHist(:,1)) % RMS residual vs. function eval count
%   • ierr lets you programmatically check solver status.
%   • resnorm is convenient when you only care about the final residual magnitude.
%   • output provides a machine-readable summary for logging or debugging.
%
% Called functions:
%   MATLAB standard:
%     inputParser, addParameter, parse, validateattributes, isa, isscalar, isvector, ...
%     isnumeric, isfinite, norm, size, zeros, ones, warning, error, strcmpi, lower, ...
%     string, max, min, eps, sqrt, feval
%   MATLAB toolbox:
%     (none)
%   User dependencies: none; diffjac is local, vectorizeFcn is not called.
%   Local (this file):
%     doNewtonKrylov, doShamanskii, makeOutput, ...
%     fdkrylov, fdgmres, fdcgstab, fdtfqmr, ...
%     dirder, parab3p, givapp, ...
%     polishScalarRoot, polishVectorRoot, doAnalyticalNewton, valid, pick
%     % polishing uses the 'PolishRoots' option
%
% Examples:
%   % Two-variable nonlinear system
%   f = @(x) [x(1)^2 + x(2) - 1;
%             x(1) + x(2)^2 - 1];
%   x0 = [0.5; 0.5];                    % initial guess (2×1)
%   [sol, itHist] = nsolve(f, x0);
%
%   % sol is a 2×1 column vector, same length as x0
%   sol(1)   % first variable
%   sol(2)   % second variable
%
%   % Plot RMS residual vs. iteration
%   plot(itHist(:,1), 'o-');
%   xlabel('Iteration'); ylabel('RMS residual');
%
% Licence:
%   The upstream Kelley source files explicitly state the MIT licence.
%   Author attribution and source links: doc/THIRD_PARTY_NOTICES.txt.

    % --- Detect & normalize legacy signatures -----------------------------
    % Handle possible old order: nsol(x, f, ...) vs nsola(f, x0, ...)
    if isnumeric(f) && isa(x0,'function_handle')
        warning('nsolve:ArgOrder', ...
            'Detected legacy order nsol(x,f,...). Swapping to nsolve(f,x,...).');
        [f, x0] = deal(x0, f);
        legacyKind = "nsol";   % shamanskii style
    else
        legacyKind = "";
    end

    % --- Defaults ---------------------------------------------------------
    def.AbsTol        = 1e-8;
    def.RelTol        = 1e-8;
    def.MaxIter       = 40;
    def.Display       = 'off';
    def.Algorithm     = 'newtonKrylov';

    % NK only:
    def.KrylovIter    = 40;
    def.Method        = 'gmres';
    def.Reorth        = 1;
    def.RestartLimit  = 20;
    def.EtaMax        = 0.9;
    def.ArmijoAlpha   = 1e-4;
    def.LineSearchMax = 50;
    def.Sigma0        = 0.1;
    def.Sigma1        = 0.5;

    % Shamanskii:
    def.ISham         = 1000;
    def.RSham         = 0.5;

    % --- Pre-scan for numeric legacy vectors ------------------------------
    v = varargin;
    legacyTol   = [];
    legacyParms = [];
    if ~isempty(v) && isnumeric(v{1}) && isvector(v{1})
        legacyTol = v{1}(:).'; v(1) = [];
    end
    if ~isempty(v) && isnumeric(v{1}) && isvector(v{1})
        legacyParms = v{1}(:).'; v(1) = [];
    end

    % --- Parse Name–Value options ----------------------------------------
    p = inputParser; p.CaseSensitive = false; p.KeepUnmatched = false;
    addParameter(p,'AbsTol',         def.AbsTol);
    addParameter(p,'RelTol',         def.RelTol);
    addParameter(p,'MaxIter',        def.MaxIter);
    addParameter(p,'Display',        def.Display);
    addParameter(p,'Algorithm',      def.Algorithm);
    addParameter(p,'Jacobian',false,@(v) islogical(v) && isscalar(v));

    % NK:
    addParameter(p,'KrylovIter',     def.KrylovIter);
    addParameter(p,'Method',         def.Method);
    addParameter(p,'Reorth',         def.Reorth);
    addParameter(p,'RestartLimit',   def.RestartLimit);
    addParameter(p,'EtaMax',         def.EtaMax);
    addParameter(p,'ArmijoAlpha',    def.ArmijoAlpha);
    addParameter(p,'LineSearchMax',  def.LineSearchMax);
    addParameter(p,'Sigma0',         def.Sigma0);
    addParameter(p,'Sigma1',         def.Sigma1);

    % Shamanskii:
    addParameter(p,'ISham',          def.ISham);
    addParameter(p,'RSham',          def.RSham);

    % Post-processing (scalar problems)
    addParameter(p,'PolishRoots',  true);    % on by default
    addParameter(p,'PolishIters', 5);       % 0..5 is sensible
    
    parse(p, v{:});
    o = p.Results;

    % --- Apply legacy vectors, if any ------------------------------------
    if ~isempty(legacyTol)
        % Both styles use [AbsTol, RelTol] ordering
        if numel(legacyTol) >= 1, o.AbsTol = legacyTol(1); end
        if numel(legacyTol) >= 2, o.RelTol = legacyTol(2); end
    end
    if ~isempty(legacyParms)
        if isempty(legacyKind)
            % Likely nsola legacy vector
            o.MaxIter = pick(legacyParms,1, o.MaxIter);
            o.KrylovIter = pick(legacyParms,2, o.KrylovIter);
            o.EtaMax = pick(legacyParms,3, o.EtaMax);
            if numel(legacyParms) >= 4
                switch legacyParms(4)
                    case 1, o.Method = 'gmres';
                    case 2, o.Method = 'gmresm';
                    case 3, o.Method = 'bicgstab';
                    case 4, o.Method = 'tfqmr';
                end
            end
            o.RestartLimit = pick(legacyParms,5, o.RestartLimit);
        else
            % nsol legacy: parms=[MaxIter ISham RSham]
            o.Algorithm = 'shamanskii';
            o.MaxIter   = pick(legacyParms,1, o.MaxIter);
            o.ISham     = pick(legacyParms,2, o.ISham);
            o.RSham     = pick(legacyParms,3, o.RSham);
        end
    end

    % If user asked explicitly for Newton or Chord, map to Shamanskii:
    alg = lower(string(o.Algorithm));
    switch alg
        case "newton"
            o.Algorithm = 'shamanskii'; o.ISham = 1;  o.RSham = 0;
        case "chord"
            o.Algorithm = 'shamanskii'; o.ISham = -1; o.RSham = 1;
    end

    polishRoots  = o.PolishRoots;
    polishIters = o.PolishIters;

    % --- Validate essentials ---------------------------------------------
    if ~(isa(f,'function_handle'))
        error('nsolve:BadInput','f must be a function handle.') 
    end
    if ~isnumeric(x0) || ~isvector(x0)
        error('nsolve:BadInput','x0 must be a numeric vector.')
    end
    x0 = x0(:);

    % vectorise if neccesarry
    %fx = fevalSafeHandle(f, x0);
    fx = f; %vectorizeFcn(f);

    % --- Dispatch by algorithm -------------------------------------------
    if o.Jacobian
        [sol,itHist,ierr,resnorm,output] = doAnalyticalNewton(fx,x0,o);
    elseif strcmpi(o.Algorithm,'shamanskii')
        [sol, itHist, ierr, resnorm, output] = doShamanskii(fx, x0, o);
    else
        [sol, itHist, ierr, resnorm, output] = doNewtonKrylov(fx, x0, o);
    end

    % --- Optional root polish (scalar: even/tangency; vector: 0.5||f||^2) ---
    if polishRoots && ierr == +1 && ~o.Jacobian
        if numel(sol) == 1
            % scalar polish: parabolic |f|-min near z
            [zPol, addEvals] = polishScalarRoot(fx, sol, max(o.AbsTol, o.RelTol), polishIters);
            if isfinite(zPol)
                fPol = feval(fx, zPol);
                if isfinite(fPol) && abs(fPol) < resnorm
                    sol     = zPol(:);
                    resnorm = abs(fPol);  % scalar RMS == |f|
                    if isfield(output,'funcCount'), output.funcCount = output.funcCount + addEvals; end
                    output.message = [output.message ' (polished)'];
                end
            end

        else
            % vector polish: short LM/GN step(s) minimizing 0.5||f||^2
            n = numel(sol);                         % residual length equals numel(x0)
            oldPhi = 0.5 * (resnorm^2) * n;        % phi_old = 0.5*||f||^2

            [xPol, phiPol, addEvals] = polishVectorRoot(f, sol, max(o.AbsTol, o.RelTol), polishIters);
            if isfinite(phiPol) && phiPol < oldPhi
                sol     = xPol(:);
                resnorm = sqrt(2*phiPol) / sqrt(n);  % RMS from phi
                if isfield(output,'funcCount'), output.funcCount = output.funcCount + addEvals; end
                output.message = [output.message ' (polished)'];
            end
        end
    end


end

% ========================================================================== %
% Helpers
% ========================================================================== %

function v = pick(a,i,default)
    if numel(a) >= i, v = a(i); else, v = default; end
end

function out = makeOutput(iterations, funcCount, method, message, algo)
    if nargin < 5, algo = 'Newton–Krylov (NSOLVE)'; end
    out = struct( ...
        'iterations', iterations, ...
        'funcCount',  funcCount, ...
        'algorithm',  char(algo), ...
        'method',     char(method), ...
        'message',    char(message) );
end

% ---------------------------- Newton–Krylov ------------------------------- %
function [sol, itHist, ierr, resnorm, output] = doNewtonKrylov(f, x0, o)
    % Method code
    switch lower(string(o.Method))
        case "gmres",    lmeth = 1;
        case "gmresm",   lmeth = 2;
        case "bicgstab", lmeth = 3;
        case "tfqmr",    lmeth = 4;
        otherwise, error('nsolve:BadMethod','Unknown Method "%s".', o.Method);
    end

    n = numel(x0);
    ierr = -1; funcCount = 0;
    itHist = zeros(o.MaxIter+1, 3); % [RMSres, cumFun, backtracks]

    try
        f0 = feval(f, x0); 
        funcCount = funcCount + 1;
    catch ME
        resnorm = NaN; output = makeOutput(0, funcCount, o.Method, "Evaluation failed: " + string(ME.message), 'Newton–Krylov');
        sol = x0; itHist = itHist(1,:); return
    end
    if ~isnumeric(f0) || ~isvector(f0) || numel(f0) ~= n || any(~isfinite(f0))
        resnorm = NaN; output = makeOutput(0, funcCount, o.Method, 'Nonfinite or wrong-size residual at x0.', 'Newton–Krylov');
        sol = x0; itHist = itHist(1,:); return
    end
    f0 = f0(:);

    fnrm  = norm(f0)/sqrt(n);
    fnrmo = max(fnrm, eps);
    itc   = 0;
    itHist(1,:) = [fnrm, funcCount, 0];
    stopTol = o.AbsTol + o.RelTol*fnrm;

    % Inner control for fdkrylov
    gmparms = [abs(o.EtaMax), o.KrylovIter];
    if lmeth == 2
        gmparms = [gmparms, o.RestartLimit, o.Reorth];
    elseif lmeth == 1
        gmparms = [gmparms, 0, o.Reorth];
    end

    x = x0;

    while (stopTol < fnrm) && (itc < o.MaxIter)
        ratio = fnrm / fnrmo; fnrmo = fnrm; itc = itc + 1;

        [step, ~, innerIters, innerEvals] = fdkrylov(f0, f, x, gmparms, lmeth);
        funcCount = funcCount + innerEvals;

        % Armijo backtracking (with parab3p)
        xOld = x;
        lambda = 1.0; lamPrev = 1.0; lamCur = lambda; iarm = 0;

        xTry  = x + lambda*step;
        fTry  = feval(f, xTry); 
        funcCount = funcCount + 1;
        nfTry = norm(fTry); nf0 = norm(f0);
        ff0   = nf0*nf0; ffCur = nfTry*nfTry; ffPrev = nfTry*nfTry;
        if ~isfinite(nfTry), nfTry = inf; end

        while ((1.0 - o.ArmijoAlpha)*nf0 <= nfTry)
            if iarm == 0
                lambda = o.Sigma1 * lambda;
            else
                lambda = parab3p(lamCur, lamPrev, ff0, ffCur, ffPrev);
            end
            xTry = x + lambda * step;
            lamPrev = lamCur; lamCur = lambda;

            fTry  = feval(f, xTry); 
            funcCount = funcCount + 1;
            nfTry = norm(fTry);
            if ~isfinite(nfTry), nfTry = inf; end
            ffPrev = ffCur; ffCur = nfTry*nfTry;

            iarm = iarm + 1;
            if (iarm > o.LineSearchMax) || (abs(lambda) < 1e-16)
                sol = xOld;
                itHist = itHist(1:itc, :);
                resnorm = itHist(end,1);
                ierr = -2;
                output = makeOutput(itc, funcCount, o.Method, 'Line search failed: too many backtracks.', 'Newton–Krylov');
                return
            end
        end

        % accept step
        x  = xTry; f0 = fTry;
        fnrm = norm(f0)/sqrt(n);

        itHist(itc+1,1) = fnrm;
        itHist(itc+1,2) = funcCount;
        itHist(itc+1,3) = iarm;

        % Eisenstat–Walker
        if o.EtaMax > 0
            etanew = 0.9 * (ratio*ratio);
            etanew = max(etanew, 0.9 * gmparms(1) * gmparms(1));
            gmparms(1) = min(etanew, o.EtaMax);
            gmparms(1) = max(gmparms(1), 0.5 * (o.AbsTol + o.RelTol*fnrm) / max(fnrm, eps));
        end

        if strcmpi(o.Display,'iter')
            fprintf('it=%3d  RMSres=%.3e  LS=%2d  InnerIters=%d\n', itc, fnrm, iarm, innerIters);
        end

        stopTol = o.AbsTol + o.RelTol*fnrm;
    end

    sol     = x;
    itHist  = itHist(1:itc+1,:);
    resnorm = itHist(end,1);

    if stopTol >= fnrm
        ierr = +1; msg = 'Converged to requested residual tolerance.';
    else
        ierr = 0;  msg = 'Maximum iterations reached before meeting tolerance.';
    end
    output = makeOutput(itc, funcCount, o.Method, msg, 'Newton–Krylov');

    if ~strcmpi(o.Display,'off')
        fprintf('[nsolve:Newton–Krylov] %s  it=%d  RMSres=%.3e  funcCount=%d\n', msg, itc, resnorm, funcCount);
    end
end

% --------------------------- Shamanskii / Chord --------------------------- %
function [sol, itHist, ierr, resnorm, output] = doShamanskii(f, x0, o)
    % Interpret ISham/RSham to emulate Newton/Shamanskii/Chord
    isham = o.ISham; rsham = o.RSham;
    maxIter = o.MaxIter;

    x = x0(:); 
    n = numel(x);
    ierr = 0; 
    funcCount = 0;
    itc = 0; 
    jacRefreshes = 0;

    % First residual
    f0 = feval(f, x); 
    funcCount = funcCount + 1;
    if ~isnumeric(f0) || ~isvector(f0) || numel(f0) ~= n || any(~isfinite(f0))
        sol = x; itHist = [NaN 1 0]; resnorm = NaN;
        output = makeOutput(0, funcCount, 'diffjac', 'Nonfinite or wrong-size residual at x0.', 'Shamanskii/Chord');
        ierr = -1; 
        return
    end
    fnrmInf = norm(f0, inf);
    fnrmo   = max(fnrmInf, eps);
    stopTol = o.AbsTol + o.RelTol * (norm(f0)/sqrt(n));

    itHist = zeros(maxIter+1, 3);
    itHist(1,:) = [norm(f0)/sqrt(n), funcCount, 0];

    itSham = isham;  % countdown to recompute Jacobian

    while (stopTol < norm(f0)/sqrt(n)) && (itc < maxIter)
        ratio = fnrmInf / fnrmo;
        fnrmo = fnrmInf;
        itc = itc + 1;

        % Refresh Jacobian?
        needJ = (itc == 1) || (rsham < ratio) || (itSham == 0);
        if needJ
            itSham = isham;
            % Build J and get LU with permutation: P*J = L*U
            [L, U, P] = diffjac(x, f, f0);   % <-- CHANGED: now returns P too
            jacRefreshes = jacRefreshes + 1;
        end
        itSham = itSham - 1;

        % Solve J * step = -f0 using permutation (more robust than 2-output LU)
        rhs  = -f0;                           % <-- CHANGED: explicit RHS
        y    = L \ (P * rhs);                 % <-- CHANGED: apply permutation to RHS
        step = U \ y;                         % <-- CHANGED: backsolve

        xOld = x;
        x    = x + step;

        f0   = feval(f, x); 
        funcCount = funcCount + 1;
        fnrmInf = norm(f0, inf);

        % Failure to decrease the residual is not convergence.
        if ~isfinite(fnrmInf) || (fnrmInf / fnrmo) >= 1.0
            ierr = -2;
            sol = xOld;
            itHist = itHist(1:itc, :);
            resnorm = itHist(end,1);
            output = makeOutput(itc, funcCount, 'diffjac', 'Residual did not decrease; terminated without convergence (Shamanskii safeguard).', 'Shamanskii/Chord');
            return
        end

        itHist(itc+1,1) = norm(f0)/sqrt(n);
        itHist(itc+1,2) = funcCount;
        itHist(itc+1,3) = jacRefreshes;

        if strcmpi(o.Display,'iter')
            fprintf('it=%3d  RMSres=%.3e  Jrefresh=%d\n', itc, itHist(itc+1,1), jacRefreshes);
        end
    end

    sol     = x;
    itHist  = itHist(1:itc+1,:);
    resnorm = itHist(end,1);

    if stopTol >= itHist(end,1)
        ierr = +1; msg = 'Converged to requested residual tolerance.';
    else
        ierr = 0;  msg = 'Maximum iterations reached before meeting tolerance.';
    end
    output = makeOutput(itc, funcCount, 'diffjac', msg, 'Shamanskii/Chord');

    if ~strcmpi(o.Display,'off')
        fprintf('[nsolve:Shamanskii] %s  it=%d  RMSres=%.3e  funcCount=%d\n', msg, itc, resnorm, funcCount);
    end
end

% ========================================================================== %
% Newton–Krylov internals (from your NSOLA path, lightly polished to camel) %
% ========================================================================== %

function [step, errStep, totalIters, fEvals] = fdkrylov(f0, f, x, params, lmeth)
    lmaxit = params(2);
    if lmeth == 1
        restartLimit = 0;
    elseif numel(params) >= 3
        restartLimit = params(3);
    else
        restartLimit = 20;
    end
    if numel(params) == 3
        gmparms = [params(1), params(2), 1];
    elseif numel(params) == 4
        gmparms = [params(1), params(2), params(4)];
    else
        gmparms = [params(1), params(2)];
    end

    switch lmeth
        case {1,2}
            [step, errStep, totalIters] = fdgmres(f0, f, x, gmparms);
            kRest = 0;
            while (totalIters == lmaxit) && (gmparms(1) * norm(f0) < errStep(end)) && (kRest < restartLimit)
                kRest = kRest + 1;
                [step, errStep, totalIters] = fdgmres(f0, f, x, gmparms, step);
            end
            totalIters = totalIters + kRest * lmaxit;
            fEvals     = totalIters + kRest;
        case 3
            [step, errStep, totalIters] = fdcgstab(f0, f, x, gmparms);
            fEvals = 2 * totalIters;
        case 4
            [step, errStep, totalIters] = fdtfqmr(f0, f, x, gmparms);
            fEvals = 2 * totalIters;
    end
end

function [x, resHist, totalIters] = fdgmres(f0, f, xc, params, xinit)
    f0 = f0(:);  xc = xc(:);
    n  = numel(xc);
    relRed = params(1); kmax = params(2); reorth = 1;
    if numel(params) >= 3, reorth = params(3); end

    b = -f0; errTol = relRed * norm(b);

    if nargin >= 5 && ~isempty(xinit)
        x0 = xinit(:);
        r  = -dirder(xc, x0, f, f0) - f0;
    else
        x0 = zeros(n,1);
        r  = b;
    end

    rho = norm(r);
    resHist = zeros(1, kmax+1); resHist(1) = rho;
    totalIters = 0;
    if rho <= errTol, x = x0; return; end

    V = zeros(n, kmax+1);
    H = zeros(kmax+1, kmax);
    c = zeros(kmax, 1);
    s = zeros(kmax, 1);
    g = zeros(kmax+1, 1); g(1) = rho;
    V(:,1) = r / rho;

    for k = 1:kmax
        totalIters = k;
        w = dirder(xc, V(:,k), f, f0);
        normAw = norm(w);

        for j = 1:k
            H(j,k) = V(:,j)' * w;
            w = w - H(j,k) * V(:,j);
        end
        H(k+1,k) = norm(w);

        if (reorth == 1 && normAw + 1e-3*H(k+1,k) == normAw) || reorth == 3
            for j = 1:k
                hr = V(:,j)' * w;
                H(j,k) = H(j,k) + hr;
                w = w - hr * V(:,j);
            end
            H(k+1,k) = norm(w);
        end

        if H(k+1,k) ~= 0, V(:,k+1) = w / H(k+1,k); else, V(:,k+1) = zeros(n,1); end

        if k > 1, H(1:k,k) = givapp(c(1:k-1), s(1:k-1), H(1:k,k), k-1); end
        nu = norm(H(k:k+1,k));
        if nu ~= 0
            c(k) = conj(H(k,k)/nu);
            s(k) = -H(k+1,k)/nu;
            H(k,k)   = c(k)*H(k,k) - s(k)*H(k+1,k);
            H(k+1,k) = 0;
            g(k:k+1) = givapp(c(k), s(k), g(k:k+1), 1);
        end

        rho = abs(g(k+1)); resHist(k+1) = rho;
        if rho <= errTol, break; end
    end
    resHist = resHist(1:totalIters+1);

    k = totalIters;
    if k == 0, x = x0; return; end
    y = H(1:k,1:k) \ g(1:k);
    x = x0 + V(:,1:k) * y;
end

function [x, resHist, totalIters] = fdcgstab(f0, f, xc, params, xinit)
    f0 = f0(:); xc = xc(:); n = numel(xc);
    relRed = params(1); kmax = params(2);
    b = -f0; errTol = relRed * norm(b);

    if nargin >= 5 && ~isempty(xinit), x = xinit(:); r = -dirder(xc, x, f, f0) - f0;
    else, x = zeros(n,1); r = b; end

    rhat = r; zeta = norm(r); resHist = zeros(1, kmax+1); resHist(1) = zeta;
    alpha = 1.0; omega = 1.0; v = zeros(n,1); p = zeros(n,1);
    rhoPrev = 1.0; rhoCurr = rhat' * r; k = 0;

    while (zeta > errTol) && (k < kmax)
        k = k + 1;
        if omega == 0, resHist(k+1) = zeta; break; end
        beta = (rhoCurr / rhoPrev) * (alpha / omega);
        p = r + beta * (p - omega * v);
        v = dirder(xc, p, f, f0);
        tau = rhat' * v; if tau == 0, resHist(k+1) = zeta; break; end
        alpha = rhoCurr / tau;
        s = r - alpha * v;
        t = dirder(xc, s, f, f0); tt = (t' * t); if tt == 0, resHist(k+1) = zeta; break; end
        omega = (t' * s) / tt;
        x = x + alpha * p + omega * s;
        r = s - omega * t;
        zeta = norm(r); resHist(k+1) = zeta;
        rhoNext = -omega * (rhat' * t); rhoPrev = rhoCurr; rhoCurr = rhoNext;
    end
    resHist = resHist(1:k+1); totalIters = k;
end

function [x, resHist, totalIters] = fdtfqmr(f0, f, xc, params, xinit)
    f0 = f0(:); xc = xc(:); n = numel(xc);
    relRed = params(1); kmax = params(2);
    b = -f0; errTol = relRed * norm(b);

    if nargin >= 5 && ~isempty(xinit), x = xinit(:); r = -dirder(xc, x, f, f0) - f0;
    else, x = zeros(n,1); r = b; end

    u = zeros(n,2); y = zeros(n,2); w = r; y(:,1) = r; d = zeros(n,1);
    v = dirder(xc, y(:,1), f, f0); u(:,1) = v;
    theta = 0; eta = 0; tau = norm(r);
    resHist = zeros(1, 2*kmax + 1); ri = 1; resHist(ri) = tau;
    rho = tau*tau; totalIters = 0;

    while totalIters < kmax
        totalIters = totalIters + 1;
        sigma = r' * v; if sigma == 0, ri = ri+1; resHist(ri)=tau; break; end
        alpha = rho / sigma;

        % j=1
        w = w - alpha * u(:,1);
        d = y(:,1) + (theta*theta*eta/alpha) * d;
        theta = norm(w) / tau; c = 1 / sqrt(1 + theta*theta); tau = tau * theta * c;
        eta = c*c * alpha; x = x + eta * d;
        m = 2*totalIters - 1; if tau * sqrt(m + 1) <= errTol, ri=ri+1; resHist(ri)=tau; break; end

        % j=2
        y(:,2) = y(:,1) - alpha * v;
        u(:,2) = dirder(xc, y(:,2), f, f0);
        w = w - alpha * u(:,2);
        d = y(:,2) + (theta*theta*eta/alpha) * d;
        theta = norm(w) / tau; c = 1 / sqrt(1 + theta*theta); tau = tau * theta * c;
        eta = c*c * alpha; x = x + eta * d;
        m = 2*totalIters; if tau * sqrt(m + 1) <= errTol, ri=ri+1; resHist(ri)=tau; break; end

        % recurrence
        rhon = r' * w; if rho == 0, ri=ri+1; resHist(ri)=tau; break; end
        beta = rhon / rho; rho = rhon;
        y(:,1) = w + beta * y(:,2);
        u(:,1) = dirder(xc, y(:,1), f, f0);
        v      = u(:,1) + beta * (u(:,2) + beta * v);

        ri = ri + 1; resHist(ri) = tau;
    end
    resHist = resHist(1:ri);
end

function z = dirder(x, w, f, f0)
    x = x(:); w = w(:); f0 = f0(:);
    nw = norm(w); if nw == 0, z = zeros(size(f0)); return; end
    epsfd = sqrt(eps); nx = norm(x);
    h = epsfd * (1 + nx) / nw; h = max(1e-16, min(1e-2, h));
    maxShrink = 8;

    for k = 1:maxShrink
        f1 = feval(f, x + h*w);
        if isnumeric(f1), f1 = f1(:); end
        if numel(f1) == numel(f0) && all(isfinite(f1))
            z = (f1 - f0) / h;
            if all(isfinite(z)), return; end
        end
        h = h * 0.1; if h < 1e-16, break; end
    end

    h = max(h, 1e-16);
    for k = 1:maxShrink
        fp = feval(f, x + h*w);
        fm = feval(f, x - h*w);
        if isnumeric(fp), fp = fp(:); end
        if isnumeric(fm), fm = fm(:); end
        if numel(fp)==numel(f0) && numel(fm)==numel(f0) && all(isfinite(fp)) && all(isfinite(fm))
            z = (fp - fm) / (2*h);
            if all(isfinite(z)), return; end
        end
        h = h * 0.1; if h < 1e-16, break; end
    end
    z = zeros(size(f0));
end

function lambdaP = parab3p(lambdaC, lambdaM, ff0, ffC, ffM)
    sigma0 = 0.1; sigma1 = 0.5;
    c2 = lambdaM * (ffC - ff0) - lambdaC * (ffM - ff0);
    if ~isfinite(c2) || c2 >= 0, lambdaP = sigma1 * lambdaC; return; end
    c1 = (lambdaC^2)*(ffM - ff0) - (lambdaM^2)*(ffC - ff0);
    lambdaP = -0.5 * c1 / c2;
    lo = sigma0 * lambdaC; hi = sigma1 * lambdaC; if lo > hi, t=lo; lo=hi; hi=t; end
    if ~isfinite(lambdaP), lambdaP = sigma1 * lambdaC; else, lambdaP = min(max(lambdaP, lo), hi); end
end

function v = givapp(c, s, v, k)
    for i = 1:k
        vi = v(i); vip1 = v(i+1);
        w1 = c(i)*vi -        s(i)*vip1;
        w2 = s(i)*vi + conj(  c(i))*vip1;
        v(i)   = w1;
        v(i+1) = w2;
    end
end

function [L, U, P] = diffjac(x, f, f0)
%DIFFJAC  Finite-difference Jacobian and LU factors.
%   [L,U,P] = diffjac(x, f, f0) builds J ≈ df/dx at x and returns LU with
%   partial pivoting so that P*J = L*U. f0 = f(x) is passed in to avoid
%   recomputation.
%
% Called by: Shamanskii/Newton/Chord path in nsolve

    x = x(:);
    n = numel(x);

    % Build Jacobian by directional derivatives of basis vectors
    J = zeros(n, n);
    for j = 1:n
        ej = zeros(n,1); ej(j) = 1;
        J(:,j) = dirder(x, ej, f, f0);
    end

    % LU with explicit permutation (more predictable than 2-output lu)
    [L, U, P] = lu(J);
end

function [z, nfe] = polishScalarRoot(f, z0, tol, iters)
%POLISHSCALARROOT  Parabolic |f|-minimization near z0 (derivative-free).
%   Nudges a scalar root (even/tangential) by a few vertex steps on |f|
%   using samples at (z-h, z, z+h). Accepts only improving moves.

    if nargin < 4 || isempty(iters), iters = 5; end
    z   = z0;
    nfe = 0;

    for it = 1:iters
        % small, scale-aware step
        h = max(10*tol, sqrt(eps)*(1 + abs(z)));

        % sample |f| symmetrically
        fL = abs(feval(f, z - h)); nfe = nfe + 1;
        fC = abs(feval(f, z    )); nfe = nfe + 1;
        fR = abs(feval(f, z + h)); nfe = nfe + 1;

        denom = (fL - 2*fC + fR);
        if ~isfinite(denom) || denom == 0
            break
        end

        % equally spaced parabola: vertex shift
        dz   = 0.5 * (fL - fR) / denom * h;
        zNew = z + dz;

        % stop if step is tiny or not improving
        if ~isfinite(zNew) || abs(zNew - z) <= 5*tol
            break
        end

        fNew = abs(feval(f, zNew)); nfe = nfe + 1;
        if ~isfinite(fNew) || fNew >= fC
            break
        end

        z = zNew;
    end
end

function [x, phi, addEvals] = polishVectorRoot(f, x0, tol, iters, lambda0)
%POLISHVECTORROOT  Short Gauss–Newton/LM polish for vector problems.
% Minimizes phi(x)=0.5*||f(x)||^2 using a few damped steps:
%   (J'J + lambda*I) s = -J' f   with Armijo backtracking on phi.
% J is built by directional derivatives via DIRDER (finite differences).
%
% Inputs
%   f        function handle returning residual vector
%   x0       current solution (column vector)
%   tol      scale for step size / acceptance (use max(AbsTol,RelTol))
%   iters    small integer (e.g., 1–3)
%   lambda0  initial LM damping (default 1e-6)
%
% Outputs
%   x        improved solution (or x0 if no improvement)
%   phi      final 0.5*||f(x)||^2
%   addEvals approx # extra f-evaluations (directional diffs + backtracks)

    if nargin < 5 || isempty(lambda0), lambda0 = 1e-6; end
    x = x0(:);
    addEvals = 0;

    % current residual / objective
    fx = feval(f, x); addEvals = addEvals + 1;
    if ~isvector(fx), fx = fx(:); end
    phi = 0.5 * (fx.'*fx);
    phi0 = phi;

    n = numel(x);
    if n == 0 || iters <= 0, return; end

    lambda = lambda0;
    for it = 1:iters
        % --- build J via directional derivatives (dirder) ---
        J = zeros(numel(fx), n);
        for j = 1:n
            ej = zeros(n,1); ej(j) = 1;
            J(:,j) = dirder(x, ej, f, fx);  % uses f(x+h*ej) internally
            % dirder calls f internally; we don't know exact count—skip addEvals here
        end

        g = J.' * fx;                 % grad phi
        H = J.' * J + lambda * eye(n);% LM normal matrix

        % Solve for step
        s = -H \ g;

        % Armijo backtracking on phi(x)
        c = 1e-4;  alpha = 1.0;  maxBT = 10;
        accepted = false;
        phi_curr = phi;
        for bt = 1:maxBT
            xTry = x + alpha*s;
            fTry = feval(f, xTry); addEvals = addEvals + 1;
            if ~isvector(fTry), fTry = fTry(:); end
            phiTry = 0.5 * (fTry.'*fTry);

            if phiTry <= (1 - c*alpha) * phi_curr    % sufficient decrease
                x   = xTry;
                fx  = fTry;
                phi = phiTry;
                accepted = true;
                break
            end
            alpha = 0.5 * alpha;   % backtrack
        end

        if ~accepted
            % increase damping and stop (too flat / inaccurate J)
            lambda = 10*lambda;
            break
        end

        % mild decrease in damping if we're improving well
        lambda = max(lambda/3, 1e-12);

        % stop if step is tiny or objective barely changes
        if norm(s) <= 5*tol*(1+norm(x)) || abs(phi_curr - phi) <= 1e-12*(1+phi_curr)
            break
        end
    end

    % only keep improvement if phi decreased
    if phi >= phi0
        x   = x0(:);
        phi = phi0;
    end
end

function [x,hist,flag,resnorm,out] = doAnalyticalNewton(f,x0,o)
% Analytical Newton with residual-decreasing backtracking; no toolbox calls.
x=x0(:); n=numel(x); count=0; iter=0; flag=0;
hist=zeros(o.MaxIter+1,3);
try
    [v,J]=f(x); count=count+1;
catch ME
    flag=-1; resnorm=NaN; hist=[NaN count 0];
    out=makeOutput(0,count,'analytical Jacobian',ME.message,'Damped Newton');
    return
end
if ~valid(v,J,n)
    flag=-1; resnorm=NaN; hist=[NaN count 0];
    out=makeOutput(0,count,'analytical Jacobian','Invalid residual/Jacobian.','Damped Newton');
    return
end
v=v(:); initial=norm(v)/sqrt(n); tol=o.AbsTol+o.RelTol*initial;
hist(1,:)=[initial count 0]; msg='Maximum iterations reached.';
while true
    resnorm=norm(v)/sqrt(n);
    if resnorm<=tol, flag=1; msg='Converged to requested residual tolerance.'; break; end
    if iter>=o.MaxIter, break; end
    if rcond(J)<eps
        flag=-2; msg='Singular or ill-conditioned analytical Jacobian.'; break
    end
    step=-(J\v);
    if ~isreal(step) || any(~isfinite(step))
        flag=-1; msg='Invalid Newton step.'; break
    end
    alpha=1; accepted=false;
    for back=0:o.LineSearchMax
        trial=x+alpha*step;
        try
            [vt,Jt]=f(trial); count=count+1;
            if valid(vt,Jt,n)
                vt=vt(:);
                if norm(vt)<= (1-o.ArmijoAlpha*alpha)*norm(v) || norm(vt)/sqrt(n)<=tol
                    accepted=true; break
                end
            end
        catch
            count=count+1;
        end
        alpha=alpha/2;
    end
    if ~accepted
        flag=-2; msg='No residual-decreasing Newton step found.'; break
    end
    x=trial; v=vt; J=Jt; iter=iter+1;
    hist(iter+1,:)=[norm(v)/sqrt(n) count back];
end
hist=hist(1:iter+1,:); resnorm=norm(v)/sqrt(n);
out=makeOutput(iter,count,'analytical Jacobian',msg,'Damped Newton');
if ~strcmpi(o.Display,'off')
    fprintf('[nsolve:analytical Newton] %s RMSres=%.3e\n',msg,resnorm);
end
end
function ok=valid(v,J,n)
ok=isnumeric(v) && isreal(v) && numel(v)==n && all(isfinite(v(:))) ...
    && isnumeric(J) && isreal(J) && isequal(size(J),[n n]) && all(isfinite(J(:)));
end
