function results = run_XProvince_uced(overrides)

if nargin < 1
    overrides = struct();
end
cfg = applyOverrides(XProvince_uced_config(), overrides);

if ~isfolder(cfg.outputRoot)
    mkdir(cfg.outputRoot);
end
runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
cfg.runDir = fullfile(cfg.outputRoot, "run_" + string(runStamp));
mkdir(cfg.runDir);

data = load_XProvince_inputs(cfg);
nHours = numel(data.time);
nBlocksAll = ceil(nHours / cfg.hoursPerBlock);
nBlocks = min(nBlocksAll, cfg.maxBlocks);
if isinf(nBlocks)
    nBlocks = nBlocksAll;
end
nBlocks = floor(nBlocks);
lastHour = min(nHours, nBlocks * cfg.hoursPerBlock);

G = height(data.thermal);
H = height(data.hydro);
S = height(data.storage);

%% 初始状态：年初在供暖期的 CHP 已运行，其他煤电/气电可自由启动
isCHP = data.thermalIsCHP(:);
firstHeating = data.heatingMask(1);
state.u0 = double(isCHP & firstHeating);
effectiveCap = double(data.thermal.Existing_Cap_MW(:)) * (1-cfg.thermalDerateFraction);
state.p0 = state.u0 .* effectiveCap .* double(data.thermal.Min_Power(:));
state.onDuration = state.u0 .* max(1, round(double(data.thermal.Up_Time(:))));
state.offDuration = (1-state.u0) .* max(1, round(double(data.thermal.Down_Time(:))));
state.soc0 = data.storageInitialSOCMWh;

%% 结果预分配
results.time = data.time(1:lastHour);
results.loadMW = data.loadMW(1:lastHour);
results.windAvailMW = data.windAvailMW(1:lastHour);
results.solarAvailMW = data.solarAvailMW(1:lastHour);
results.heatingMask = data.heatingMask(1:lastHour);

hourFields = ["pCoal","pGas","pHydro","pWind","pSolar", ...
    "windCurtailment","solarCurtailment","storageCharge","storageDischarge", ...
    "storageSOC","nse","reserveUpProvided","reserveUpRequired", ...
    "reserveDownProvided","reserveDownRequired","hourlyCost"];
for f = hourFields
    results.(f) = zeros(lastHour,1);
end

results.pThermalUnit = zeros(G,lastHour);
results.commitmentUnit = zeros(G,lastHour);
results.startupUnit = zeros(G,lastHour);
results.shutdownUnit = zeros(G,lastHour);
results.pHydroUnit = zeros(H,lastHour);
results.storageChargeUnit = zeros(S,lastHour);
results.storageDischargeUnit = zeros(S,lastHour);
results.storageSOCUnit = zeros(S,lastHour);

blockNumber = zeros(nBlocks,1);
blockStart = NaT(nBlocks,1);
blockEnd = NaT(nBlocks,1);
blockStatus = strings(nBlocks,1);
blockSolver = strings(nBlocks,1);
blockObjective = zeros(nBlocks,1);
blockRuntimeSec = zeros(nBlocks,1);
blockMipGap = nan(nBlocks,1);

%% 滚动求解
for b = 1:nBlocks
    first = (b-1)*cfg.hoursPerBlock + 1;
    last = min(b*cfg.hoursPerBlock, nHours);
    hourIdx = (first:last)';
    if cfg.verbose
        fprintf('\n========== XProvince UCED：块 %d/%d，%s 至 %s ==========\n', ...
            b, nBlocks, string(data.time(first)), string(data.time(last)));
    end

    [week, state] = solve_XProvince_block(data, hourIdx, state, cfg, b);
    if ~(strcmpi(week.status,"OPTIMAL") || strcmpi(week.status,"INTLINPROG_EXITFLAG_1"))
        warning('块 %d 返回限时/非最优可行解（状态 %s，MIP gap %.4g）。其中的 NSE 不能直接解释为物理缺电。', ...
            b, week.status, week.mipGap);
    end
    pos = first:last;

    results.pCoal(pos) = week.pCoal;
    results.pGas(pos) = week.pGas;
    results.pHydro(pos) = week.pHydroTotal;
    results.pWind(pos) = week.pWind;
    results.pSolar(pos) = week.pSolar;
    results.windCurtailment(pos) = week.curWind;
    results.solarCurtailment(pos) = week.curSolar;
    results.storageCharge(pos) = week.chargeTotal;
    results.storageDischarge(pos) = week.dischargeTotal;
    results.storageSOC(pos) = week.socTotal;
    results.nse(pos) = week.nse;
    results.reserveUpProvided(pos) = week.reserveUpProvided;
    results.reserveUpRequired(pos) = week.reserveUpRequired;
    results.reserveDownProvided(pos) = week.reserveDownProvided;
    results.reserveDownRequired(pos) = week.reserveDownRequired;
    results.hourlyCost(pos) = week.hourlyCost;

    results.pThermalUnit(:,pos) = week.pThermal;
    results.commitmentUnit(:,pos) = week.commitment;
    results.startupUnit(:,pos) = week.startup;
    results.shutdownUnit(:,pos) = week.shutdown;
    results.pHydroUnit(:,pos) = week.pHydro;
    results.storageChargeUnit(:,pos) = week.charge;
    results.storageDischargeUnit(:,pos) = week.discharge;
    results.storageSOCUnit(:,pos) = week.soc;

    blockNumber(b) = b;
    blockStart(b) = data.time(first);
    blockEnd(b) = data.time(last);
    blockStatus(b) = week.status;
    blockSolver(b) = week.solver;
    blockObjective(b) = week.objective;
    blockRuntimeSec(b) = week.runtimeSec;
    blockMipGap(b) = week.mipGap;

    results.blocks = table(blockNumber(1:b),blockStart(1:b),blockEnd(1:b), ...
        blockStatus(1:b),blockSolver(1:b),blockObjective(1:b), ...
        blockRuntimeSec(1:b),blockMipGap(1:b), ...
        'VariableNames',{'Block','StartTime','EndTime','Status','Solver', ...
        'Objective','RuntimeSec','MIPGap'});
    results.cfg = cfg;
    results.meta = data.meta;
    if cfg.saveCheckpointEveryBlock
        save(fullfile(cfg.runDir,'checkpoint_latest.mat'), 'results', 'state', '-v7.3');
    end
end

results.cfg = cfg;
results.meta = data.meta;
results.thermal = data.thermal;
results.hydro = data.hydro;
results.storage = data.storage;
results.totalObjective = sum(blockObjective);
results.totalNSE_MWh = sum(results.nse);
results.totalWindCurtailment_MWh = sum(results.windCurtailment);
results.totalSolarCurtailment_MWh = sum(results.solarCurtailment);
results.validation = validate_xinjiang_results(results);

export_XProvince_results(results);
if cfg.makePlots
    plot_XProvince_results(results);
end
save(fullfile(cfg.runDir,'XProvince_uced_results.mat'), 'results', '-v7.3');

if cfg.verbose
    fprintf('\n运行完成。结果目录：%s\n', cfg.runDir);
    fprintf('总 NSE：%.3f MWh；弃风：%.3f MWh；弃光：%.3f MWh。\n', ...
        results.totalNSE_MWh, results.totalWindCurtailment_MWh, ...
        results.totalSolarCurtailment_MWh);
end

end

function cfg = applyOverrides(cfg, overrides)
if ~isstruct(overrides)
    error('overrides 必须是 struct。');
end
names = fieldnames(overrides);
for i = 1:numel(names)
    name = names{i};
    if ~isfield(cfg, name)
        error('未知配置项：%s', name);
    end
    cfg.(name) = overrides.(name);
end
end
