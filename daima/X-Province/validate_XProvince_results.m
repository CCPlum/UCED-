function validation = validate_XProvince_results(results)
%VALIDATE_XINJIANG_RESULTS 对功率平衡、备用、整数性和 SOC 做数值检查。

supply = results.pCoal + results.pGas + results.pHydro + ...
    results.pWind + results.pSolar + results.storageDischarge - ...
    results.storageCharge + results.nse;

validation.maxPowerBalanceErrorMW = max(abs(supply-results.loadMW));
validation.minUpReserveSlackMW = min(results.reserveUpProvided-results.reserveUpRequired);
validation.minDownReserveSlackMW = min(results.reserveDownProvided-results.reserveDownRequired);
if isempty(results.commitmentUnit)
    validation.maxCommitmentIntegralityError = 0;
else
validation.maxCommitmentIntegralityError = max(abs( ...
        results.commitmentUnit(:)-round(results.commitmentUnit(:))));
end
validation.minNSEMW = min(results.nse);
if isempty(results.storageSOC)
    validation.minStorageSOCMWh = NaN;
else
    validation.minStorageSOCMWh = min(results.storageSOC(:));
end

cycleType = lower(string(results.storage.CycleType));
initialSOC = results.cfg.storageInitialSOCFraction * ...
    double(results.storage.Existing_Cap_MWh(:));
dailyEnds = find(mod((1:numel(results.time))',24) == 0);
weeklyEnds = find(mod((1:numel(results.time))',168) == 0);
if numel(results.time) == 8760
    weeklyEnds = unique([weeklyEnds;numel(results.time)]);
end
validation.maxDailyStorageCycleErrorMWh = cycleError( ...
    results.storageSOCUnit,cycleType == "daily",dailyEnds,initialSOC);
validation.maxWeeklyStorageCycleErrorMWh = cycleError( ...
    results.storageSOCUnit,cycleType == "weekly",weeklyEnds,initialSOC);
validation.passed = validation.maxPowerBalanceErrorMW <= 1e-5 && ...
    validation.minUpReserveSlackMW >= -1e-5 && ...
    validation.minDownReserveSlackMW >= -1e-5 && ...
    validation.maxCommitmentIntegralityError <= 1e-5 && ...
    validation.minNSEMW >= -1e-7 && ...
    validation.maxDailyStorageCycleErrorMWh <= 1e-5 && ...
    validation.maxWeeklyStorageCycleErrorMWh <= 1e-5;

if ~validation.passed
    error('结果数值校验未通过，请检查 validation 结构。');
end
end

function value = cycleError(soc,unitMask,timeIdx,target)
if ~any(unitMask) || isempty(timeIdx)
    value = 0;
    return;
end
errorMatrix = soc(unitMask,timeIdx) - target(unitMask);
value = max(abs(errorMatrix(:)));
end
