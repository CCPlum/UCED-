function data = load_XProvince_inputs(cfg)
%LOAD_XINJIANG_INPUTS 读取全年曲线并从西北机组表筛选新疆机组。

mustExist(cfg.curveFile, "风光出力及负荷曲线文件");
mustExist(cfg.generatorFile, "西北地区机组文件");

%% 机组数据
genOpts = detectImportOptions(cfg.generatorFile, ...
    'Sheet', 'Generators_data', 'VariableNamingRule', 'preserve');
genAll = readtable(cfg.generatorFile, genOpts);

requiredGen = ["region", "Resource", "technology", "R_ID", "STOR", ...
    "SOLAR", "COAL", "GAS", "WIND", "HYDRO", "Existing_Cap_MW", ...
    "Existing_Cap_MWh", "Var_OM_Cost_per_MWh", "Start_Cost_per_MW", ...
    "Start_Fuel_MMBTU_per_MW", "Heat_Rate_MMBTU_per_MWh", "Min_Power", ...
    "Eff_Up", "Eff_Down", "Ramp_Up_Percentage", "Ramp_Dn_Percentage", ...
    "Up_Time", "Down_Time"];
assertColumns(genAll, requiredGen, "Generators_data");

region = upper(strtrim(string(genAll.region)));
gen = genAll(region == upper(string(cfg.regionCode)), :);
if isempty(gen)
    error('未在 Generators_data 中找到 region="%s" 的机组。', cfg.regionCode);
end

tech = string(gen.technology);
isCoal = logical(gen.COAL == 1);
isGas = logical(gen.GAS == 1);
isThermal = isCoal | isGas;
isCHP = isCoal & contains(lower(tech), "cogen");
isHydro = logical(gen.HYDRO == 1);
isStorage = logical(gen.STOR == 1);
isSolar = logical(gen.SOLAR == 1);
isWind = logical(gen.WIND == 1);

thermal = gen(isThermal, :);
hydro = gen(isHydro, :);
storage = gen(isStorage, :);
nativeStorageCount = height(storage);

% 在原始抽水蓄能记录之外，增加全疆聚合的新型储能等值机组。
if cfg.addNewStorage
    if isempty(storage)
        error('增加新型储能时需要至少一条原始储能记录作为机组表字段模板。');
    end
    newStorage = storage(1,:);
    newStorage.Resource = {char(cfg.newStorageName)};
    newStorage.technology = {'electrochemical_storage'};
    newStorage.region = {char(cfg.regionCode)};
    newStorage.R_ID = max(double(gen.R_ID)) + 1;
    newStorage.STOR = 1;
    newStorage.SOLAR = 0;
    newStorage.COAL = 0;
    newStorage.GAS = 0;
    newStorage.WIND = 0;
    newStorage.HYDRO = 0;
    newStorage.Existing_Cap_MW = cfg.newStoragePowerMW;
    newStorage.Existing_Cap_MWh = cfg.newStorageEnergyMWh;
    newStorage.Eff_Up = cfg.newStorageChargeEfficiency;
    newStorage.Eff_Down = cfg.newStorageDischargeEfficiency;
    storage = [storage; newStorage];
end

storage.CycleType = [repmat(string(cfg.pumpedStorageCycle),nativeStorageCount,1); ...
    repmat(string(cfg.newStorageCycle),height(storage)-nativeStorageCount,1)];

%% 风光和负荷曲线
curveOpts = detectImportOptions(cfg.curveFile, ...
    'Sheet', 'Sheet1', 'VariableNamingRule', 'preserve');
curve = readtable(cfg.curveFile, curveOpts);
assertColumns(curve, ["solar_xinjiang", "wind_xinjiang", "load_xinjiang"], "Sheet1");

solarRaw = double(curve.solar_xinjiang(:));
windRaw = double(curve.wind_xinjiang(:));
loadMW = double(curve.load_xinjiang(:));

nHoursExpected = 24 * (365 + double(eomday(cfg.year, 2) == 29));
if height(curve) ~= nHoursExpected
    error('曲线应有 %d 小时，但实际为 %d 行。', nHoursExpected, height(curve));
end
if any(~isfinite(loadMW) | loadMW < 0)
    error('负荷曲线包含缺失、无穷大或负值。');
end
if any(~isfinite(solarRaw)) || any(~isfinite(windRaw))
    error('风电或光伏曲线包含缺失/无穷值。');
end

negativeSolarHours = nnz(solarRaw < 0);
negativeWindHours = nnz(windRaw < 0);
if cfg.clipNegativeVRE
    solarAvail = max(solarRaw, 0);
    windAvail = max(windRaw, 0);
else
    solarAvail = solarRaw;
    windAvail = windRaw;
end

solarInstalledMW = sum(double(gen.Existing_Cap_MW(isSolar)));
windInstalledMW = sum(double(gen.Existing_Cap_MW(isWind)));
solarOverCapHours = nnz(solarAvail > solarInstalledMW + 1e-6);
windOverCapHours = nnz(windAvail > windInstalledMW + 1e-6);
if cfg.capVREAtInstalledCapacity
    solarAvail = min(solarAvail, solarInstalledMW);
    windAvail = min(windAvail, windInstalledMW);
end

time = datetime(cfg.year, 1, 1, 0, 0, 0) + hours((0:height(curve)-1)');
monthDay = month(time) * 100 + day(time);
heatStart = cfg.heatingSeasonStart(1) * 100 + cfg.heatingSeasonStart(2);
heatEnd = cfg.heatingSeasonEnd(1) * 100 + cfg.heatingSeasonEnd(2);
if heatStart > heatEnd
    heatingMask = monthDay >= heatStart | monthDay <= heatEnd;
else
    heatingMask = monthDay >= heatStart & monthDay <= heatEnd;
end
if ~cfg.enableCHPHeating
    heatingMask(:) = false;
end

%% 整理输出
data.time = time;
data.loadMW = loadMW;
data.solarAvailMW = solarAvail;
data.windAvailMW = windAvail;
data.heatingMask = heatingMask;
data.generators = gen;
data.thermal = thermal;
data.hydro = hydro;
data.storage = storage;
data.storageInitialSOCMWh = cfg.storageInitialSOCFraction * ...
    double(storage.Existing_Cap_MWh(:));
data.thermalIsCHP = isCHP(isThermal);
data.thermalIsCoal = isCoal(isThermal);
data.thermalIsGas = isGas(isThermal);

data.meta.totalXJRecords = height(gen);
data.meta.nThermal = height(thermal);
data.meta.nCoal = nnz(data.thermalIsCoal);
data.meta.nGas = nnz(data.thermalIsGas);
data.meta.nCHP = nnz(data.thermalIsCHP);
data.meta.nHydro = height(hydro);
data.meta.nStorage = height(storage);
data.meta.nPumpedStorage = nativeStorageCount;
data.meta.nNewStorage = height(storage)-nativeStorageCount;
data.meta.storagePowerMW = sum(double(storage.Existing_Cap_MW));
data.meta.storageEnergyMWh = sum(double(storage.Existing_Cap_MWh));
data.meta.nSolarProjects = nnz(isSolar);
data.meta.nWindProjects = nnz(isWind);
data.meta.solarInstalledMW = solarInstalledMW;
data.meta.windInstalledMW = windInstalledMW;
data.meta.negativeSolarHours = negativeSolarHours;
data.meta.negativeWindHours = negativeWindHours;
data.meta.solarOverCapHours = solarOverCapHours;
data.meta.windOverCapHours = windOverCapHours;

if cfg.verbose
    fprintf('XProvince 机组筛选：煤电 %d（其中 CHP %d），气电 %d，常规水电 %d，抽蓄 %d，新型储能 %d，光伏项目 %d，风电项目 %d。\n', ...
        data.meta.nCoal, data.meta.nCHP, data.meta.nGas, data.meta.nHydro, ...
        data.meta.nPumpedStorage, data.meta.nNewStorage, ...
        data.meta.nSolarProjects, data.meta.nWindProjects);
    fprintf('储能汇总：功率 %.1f MW，能量 %.1f MWh。\n', ...
        data.meta.storagePowerMW,data.meta.storageEnergyMWh);
    fprintf('风光装机：光伏 %.1f MW，风电 %.1f MW；负荷峰值 %.1f MW。\n', ...
        solarInstalledMW, windInstalledMW, max(loadMW));
    fprintf('曲线校验：负光伏 %d 小时，负风电 %d 小时；超过机组表装机的光伏/风电小时数为 %d/%d。\n', ...
        negativeSolarHours, negativeWindHours, solarOverCapHours, windOverCapHours);
end

end

function mustExist(pathValue, label)
if ~isfile(pathValue)
    error('%s不存在：%s', label, pathValue);
end
end

function assertColumns(tbl, required, sheetLabel)
present = string(tbl.Properties.VariableNames);
missing = required(~ismember(required, present));
if ~isempty(missing)
    error('%s 缺少字段：%s', sheetLabel, strjoin(missing, ', '));
end
end
