function solution = solve_milp_model(model, cfg)
%SOLVE_MILP_MODEL 使用 Gurobi 或 MATLAB intlinprog 求解统一的 MILP 结构。

requested = lower(string(cfg.solver));
if requested == "auto"
    % Gurobi 的主入口通常是 MEX 文件，exist(...,'file') 会返回 3。
    if exist('gurobi', 'file') > 0
        solverName = "gurobi";
    elseif exist('intlinprog', 'file') == 2
        solverName = "intlinprog";
    else
        error('未找到 Gurobi MATLAB 接口或 Optimization Toolbox/intlinprog。');
    end
else
    solverName = requested;
end

switch solverName
    case "gurobi"
        solution = solveWithGurobi(model, cfg);
    case "intlinprog"
        solution = solveWithIntlinprog(model, cfg);
    otherwise
        error('未知求解器：%s。可选 auto/gurobi/intlinprog。', solverName);
end

solution.solver = char(solverName);
end

function solution = solveWithGurobi(model, cfg)
if exist('gurobi', 'file') == 0
    error('cfg.solver="gurobi"，但 MATLAB 路径中没有 Gurobi 接口。');
end

gmodel.A = model.A;
gmodel.obj = model.obj;
gmodel.rhs = model.rhs;
gmodel.sense = model.sense;
gmodel.lb = model.lb;
gmodel.ub = model.ub;
gmodel.vtype = model.vtype;
gmodel.modelsense = 'min';
gmodel.modelname = model.name;

params.OutputFlag = double(cfg.solverLog);
params.TimeLimit = cfg.timeLimitSec;
params.MIPGap = cfg.mipGap;
if cfg.threads > 0
    params.Threads = cfg.threads;
end

tStart = tic;
raw = gurobi(gmodel, params);
elapsed = toc(tStart);

hasX = isfield(raw, 'x') && ~isempty(raw.x);
accepted = any(strcmpi(raw.status, {'OPTIMAL', 'TIME_LIMIT', 'SUBOPTIMAL', 'INTERRUPTED'}));
if ~(hasX && accepted)
    error('Gurobi 未返回可用解，状态：%s。', raw.status);
end

solution.x = raw.x;
solution.objval = raw.objval;
solution.status = raw.status;
solution.runtimeSec = elapsed;
solution.mipGap = NaN;
if isfield(raw, 'mipgap')
    solution.mipGap = raw.mipgap;
end
solution.raw = raw;
end

function solution = solveWithIntlinprog(model, cfg)
if exist('intlinprog', 'file') ~= 2
    error('cfg.solver="intlinprog"，但未安装 MATLAB Optimization Toolbox。');
end

isEq = model.sense == '=';
isLe = model.sense == '<';
isGe = model.sense == '>';

Aeq = model.A(isEq, :);
beq = model.rhs(isEq);
Aineq = [model.A(isLe, :); -model.A(isGe, :)];
bineq = [model.rhs(isLe); -model.rhs(isGe)];
intcon = find(model.vtype == 'B' | model.vtype == 'I');

displayMode = 'off';
if cfg.solverLog
    displayMode = 'iter';
end
options = optimoptions('intlinprog', ...
    'Display', displayMode, ...
    'MaxTime', cfg.timeLimitSec, ...
    'RelativeGapTolerance', cfg.mipGap);

tStart = tic;
[x, fval, exitflag, output] = intlinprog(model.obj, intcon, ...
    Aineq, bineq, Aeq, beq, model.lb, model.ub, options);
elapsed = toc(tStart);

if isempty(x) || exitflag <= 0
    error('intlinprog 未返回可用解，exitflag=%d，信息：%s', exitflag, output.message);
end

solution.x = x;
solution.objval = fval;
solution.status = sprintf('INTLINPROG_EXITFLAG_%d', exitflag);
solution.runtimeSec = elapsed;
solution.mipGap = NaN;
if isfield(output, 'relativegap')
    solution.mipGap = output.relativegap;
end
solution.raw = output;
end
