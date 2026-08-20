function cfg = xinjiang_uced_config()
%
% 所有缺少实测输入的建模假设都放在本文件，便于复核和替换。

rootDir = fileparts(mfilename('fullpath'));

%% 输入与输出
cfg.year = 2025;
cfg.regionCode = "XJ";
cfg.curveFile = fullfile(rootDir, "风光出力及负荷曲线.xlsx");
cfg.generatorFile = fullfile(rootDir, "西北地区_Generators_data_运行机组.xlsx");
cfg.outputRoot = fullfile(rootDir, "results");

%% 求解范围：论文采用每周 168 小时，本程序沿用并滚动全年
cfg.hoursPerBlock = 168;
cfg.maxBlocks = inf;              % inf=全年；调试时可设为 1
cfg.solver = "auto";             % auto / gurobi / intlinprog
cfg.timeLimitSec = 600;           % 每个优化块的时间上限
cfg.mipGap = 0.01;               % 0.5% MIP gap
cfg.threads = 0;                  % 0=由 Gurobi 自动决定
cfg.verbose = true;
cfg.solverLog = false;            % 全年运行只显示周进度，不打印求解器详细日志

%% 成本（沿用原机组表的成本单位体系）
% 。本值仅是可运行的基准假设，必须在正式研究中替换。
cfg.coalFuelCostPerMMBtu = 4.5;
cfg.gasFuelCostPerMMBtu = 10.0;
cfg.nsePenaltyPerMWh = 10000;
cfg.vreCurtailPenaltyPerMWh = 1;
cfg.hydroVariableCostPerMWh = 0.1;
cfg.storageCycleCostPerMWh = 0.1;

%% 机组可用率与备用
% 参考论文基准情景：计划检修使煤电可用容量降低 15%。
cfg.thermalDerateFraction = 0.15;
cfg.loadReserveFraction = 0.05;
cfg.renewableReserveFraction = 0.10;
cfg.includeLargestUnitContingency = true;

%% 常规水电
cfg.hydroWeeklyCapacityFactor = 0.40;

%% 抽水蓄能
cfg.storageInitialSOCFraction = 0.10;
cfg.storageMinSOCFraction = 0.00;
cfg.pumpedStorageCycle = "weekly"; % 抽水蓄能每 168 小时回到周初 SOC

%% 新型储能（聚合等值机组）
cfg.addNewStorage = true;
cfg.newStorageName = "Xj new-type storage aggregate";
cfg.newStoragePowerMW = 20000;
cfg.newStorageEnergyMWh = 80000;
cfg.newStorageChargeEfficiency = 0.95;
cfg.newStorageDischargeEfficiency = 0.95;
cfg.newStorageCycle = "daily";    % 电化学储能每 24 小时回到日初 SOC

%% 热电联产供暖约束
% 各地供暖期并不统一。单节点模型采用省会法定供暖期作为代表性假设。
% 热电联产只在模型内部用于施加供暖期开机约束，汇总结果统一计入煤电。
cfg.enableCHPHeating = true;
cfg.heatingSeasonStart = [10, 10]; % 月、日
cfg.heatingSeasonEnd = [4, 10];

%% 风光曲线处理
cfg.capVREAtInstalledCapacity = true;
cfg.clipNegativeVRE = true;

%% 输出
cfg.writeCSVFiles = false;         % 最终结果集中写入一个 Excel 工作簿
cfg.writeUnitCSV = false;
cfg.writeExcelWorkbook = true;
cfg.writeUnitTimeSeriesToExcel = false; % 全机组8760小时矩阵保留在MAT，避免Excel过大
cfg.makePlots = true;
cfg.plotBlock = 1;
cfg.saveCheckpointEveryBlock = false; % 保持结果目录简洁；全年长算例需要断点时可改为 true

end
