function [week, stateOut] = solve_XProvince_block(data, hourIdx, stateIn, cfg, blockNumber)
%SOLVE_XINJIANG_BLOCK 构建并求解一个滚动时域的单区域 UCED MILP。

thermal = data.thermal;
hydro = data.hydro;
storage = data.storage;
G = height(thermal);
H = height(hydro);
S = height(storage);
T = numel(hourIdx);

loadMW = data.loadMW(hourIdx);
windAvail = data.windAvailMW(hourIdx);
solarAvail = data.solarAvailMW(hourIdx);
heating = data.heatingMask(hourIdx);

%% 参数
rawThermalCap = double(thermal.Existing_Cap_MW(:));
Pmax = rawThermalCap * (1 - cfg.thermalDerateFraction);
Pmin = Pmax .* double(thermal.Min_Power(:));
rampUp = Pmax .* double(thermal.Ramp_Up_Percentage(:));
rampDown = Pmax .* double(thermal.Ramp_Dn_Percentage(:));
minUp = max(0, round(double(thermal.Up_Time(:))));
minDown = max(0, round(double(thermal.Down_Time(:))));

fuelCost = cfg.coalFuelCostPerMMBtu * double(data.thermalIsCoal(:)) + ...
    cfg.gasFuelCostPerMMBtu * double(data.thermalIsGas(:));
marginalCost = double(thermal.Var_OM_Cost_per_MWh(:)) + ...
    double(thermal.Heat_Rate_MMBTU_per_MWh(:)) .* fuelCost;
startupCost = rawThermalCap .* (double(thermal.Start_Cost_per_MW(:)) + ...
    double(thermal.Start_Fuel_MMBTU_per_MW(:)) .* fuelCost);

hydroCap = double(hydro.Existing_Cap_MW(:));
hydroRampUp = hydroCap .* double(hydro.Ramp_Up_Percentage(:));
hydroRampDown = hydroCap .* double(hydro.Ramp_Dn_Percentage(:));

storageCap = double(storage.Existing_Cap_MW(:));
storageEnergy = double(storage.Existing_Cap_MWh(:));
storageEffCh = double(storage.Eff_Up(:));
storageEffDis = double(storage.Eff_Down(:));

if cfg.includeLargestUnitContingency && G > 0
    contingencyMW = max(rawThermalCap);
else
    contingencyMW = 0;
end

%% 变量索引（机组维在前、时间维在后，便于 reshape）
k = 0;
idx.pTh = alloc(G, T);       idx.u = alloc(G, T);
idx.su = alloc(G, T);        idx.sd = alloc(G, T);
idx.rUpTh = alloc(G, T);     idx.rDnTh = alloc(G, T);

idx.pHydro = alloc(H, T);    idx.rUpHydro = alloc(H, T);
idx.rDnHydro = alloc(H, T);

idx.pWind = alloc(1, T);     idx.curWind = alloc(1, T);
idx.pSolar = alloc(1, T);    idx.curSolar = alloc(1, T);

idx.charge = alloc(S, T);    idx.discharge = alloc(S, T);
idx.soc = alloc(S, T);       idx.storageMode = alloc(S, T);
idx.rUpStorage = alloc(S, T); idx.rDnStorage = alloc(S, T);

idx.nse = alloc(1, T);
nvar = k;

lb = zeros(nvar, 1);
ub = inf(nvar, 1);
obj = zeros(nvar, 1);
vtype = repmat('C', nvar, 1);

%% 变量上下界与类型
binaryIdx = [idx.u(:); idx.su(:); idx.sd(:); idx.storageMode(:)];
vtype(binaryIdx) = 'B';
ub(binaryIdx) = 1;

ub(idx.pWind(:)) = windAvail;
ub(idx.curWind(:)) = windAvail;
ub(idx.pSolar(:)) = solarAvail;
ub(idx.curSolar(:)) = solarAvail;
ub(idx.nse(:)) = loadMW;

if S > 0
    capVecS = repmat(storageCap, T, 1);
    energyVecS = repmat(storageEnergy, T, 1);
    ub(idx.charge(:)) = capVecS;
    ub(idx.discharge(:)) = capVecS;
    ub(idx.rUpStorage(:)) = capVecS;
    ub(idx.rDnStorage(:)) = capVecS;
    lb(idx.soc(:)) = repmat(cfg.storageMinSOCFraction * storageEnergy, T, 1);
    ub(idx.soc(:)) = energyVecS;
end

% 跨块剩余最小开停机时间。
for g = 1:G
    if stateIn.u0(g) >= 0.5
        remain = max(0, minUp(g) - stateIn.onDuration(g));
        if remain > 0
            lb(idx.u(g, 1:min(T, remain))) = 1;
        end
    else
        remain = max(0, minDown(g) - stateIn.offDuration(g));
        if remain > 0
            ub(idx.u(g, 1:min(T, remain))) = 0;
        end
    end
end

% 参考论文：供暖时段 CHP 必须开机。
if cfg.enableCHPHeating && any(heating)
    chp = find(data.thermalIsCHP(:));
    heatHours = find(heating(:));
    forced = idx.u(chp, heatHours);
    lb(forced(:)) = 1;
    ub(forced(:)) = 1;
end

%% 目标函数
obj(idx.pTh(:)) = repmat(marginalCost, T, 1);
obj(idx.su(:)) = repmat(startupCost, T, 1);
obj(idx.pHydro(:)) = cfg.hydroVariableCostPerMWh;
obj(idx.charge(:)) = cfg.storageCycleCostPerMWh;
obj(idx.discharge(:)) = cfg.storageCycleCostPerMWh;
obj(idx.curWind(:)) = cfg.vreCurtailPenaltyPerMWh;
obj(idx.curSolar(:)) = cfg.vreCurtailPenaltyPerMWh;
obj(idx.nse(:)) = cfg.nsePenaltyPerMWh;

%% 约束块容器
Ablocks = {};
rhsBlocks = {};
senseBlocks = {};

%% 功率平衡：不考虑外送负荷和跨区潮流
for t = 1:T
    cols = [idx.pTh(:, t); idx.pHydro(:, t); idx.pWind(t); idx.pSolar(t); ...
        idx.discharge(:, t); idx.charge(:, t); idx.nse(t)];
    vals = [ones(G + H + 2, 1); ones(S, 1); -ones(S, 1); 1];
    addBlock(sparse(1, cols, vals, 1, nvar), '=', loadMW(t));
end

%% 风光可用出力恒等式
addBlock(sparse([(1:T)'; (1:T)'], [idx.pWind(:); idx.curWind(:)], 1, T, nvar), '=', windAvail);
addBlock(sparse([(1:T)'; (1:T)'], [idx.pSolar(:); idx.curSolar(:)], 1, T, nvar), '=', solarAvail);

%% 煤电和气电机组：出力、启停、爬坡、最小开停机时间
if G > 0
    nGT = G * T;
    rows = (1:nGT)';
    capVec = repmat(Pmax, T, 1);
    pminVec = repmat(Pmin, T, 1);
    rupVec = repmat(rampUp, T, 1);
    rdnVec = repmat(rampDown, T, 1);

    % Pmin*u <= p <= Pmax*u
    addBlock(sparse([rows; rows], [idx.pTh(:); idx.u(:)], [ones(nGT,1); -capVec], nGT, nvar), '<', zeros(nGT,1));
    addBlock(sparse([rows; rows], [idx.pTh(:); idx.u(:)], [-ones(nGT,1); pminVec], nGT, nvar), '<', zeros(nGT,1));

    % u_t-u_(t-1)=su_t-sd_t
    A0 = sparse(repmat((1:G)', 3, 1), ...
        [idx.u(:,1); idx.su(:,1); idx.sd(:,1)], ...
        [ones(G,1); -ones(G,1); ones(G,1)], G, nvar);
    addBlock(A0, '=', stateIn.u0);
    if T > 1
        nr = G * (T-1);
        rr = (1:nr)';
        Atrans = sparse([rr;rr;rr;rr], ...
            [reshape(idx.u(:,2:end),[],1); reshape(idx.u(:,1:end-1),[],1); ...
             reshape(idx.su(:,2:end),[],1); reshape(idx.sd(:,2:end),[],1)], ...
            [ones(nr,1); -ones(nr,1); -ones(nr,1); ones(nr,1)], nr, nvar);
        addBlock(Atrans, '=', zeros(nr,1));
    end
    addBlock(sparse([rows;rows], [idx.su(:);idx.sd(:)], 1, nGT, nvar), '<', ones(nGT,1));

    % 爬坡，启动/停机时允许跨越到额定容量。
    Aru0 = sparse(repmat((1:G)', 2, 1), [idx.pTh(:,1); idx.su(:,1)], ...
        [ones(G,1); -Pmax], G, nvar);
    addBlock(Aru0, '<', stateIn.p0 + rampUp .* stateIn.u0);
    Ard0 = sparse(repmat((1:G)', 3, 1), [idx.pTh(:,1); idx.u(:,1); idx.sd(:,1)], ...
        [-ones(G,1); -rampDown; -Pmax], G, nvar);
    addBlock(Ard0, '<', -stateIn.p0);
    if T > 1
        nr = G * (T-1);
        rr = (1:nr)';
        Aup = sparse([rr;rr;rr;rr], ...
            [reshape(idx.pTh(:,2:end),[],1); reshape(idx.pTh(:,1:end-1),[],1); ...
             reshape(idx.u(:,1:end-1),[],1); reshape(idx.su(:,2:end),[],1)], ...
            [ones(nr,1); -ones(nr,1); -repmat(rampUp,T-1,1); -repmat(Pmax,T-1,1)], nr, nvar);
        addBlock(Aup, '<', zeros(nr,1));
        Adn = sparse([rr;rr;rr;rr], ...
            [reshape(idx.pTh(:,1:end-1),[],1); reshape(idx.pTh(:,2:end),[],1); ...
             reshape(idx.u(:,2:end),[],1); reshape(idx.sd(:,2:end),[],1)], ...
            [ones(nr,1); -ones(nr,1); -repmat(rampDown,T-1,1); -repmat(Pmax,T-1,1)], nr, nvar);
        addBlock(Adn, '<', zeros(nr,1));
    end

    % 备用受容量余量和一小时爬坡能力约束。
    addBlock(sparse([rows;rows;rows], [idx.rUpTh(:);idx.pTh(:);idx.u(:)], ...
        [ones(nGT,1);ones(nGT,1);-capVec], nGT, nvar), '<', zeros(nGT,1));
    addBlock(sparse([rows;rows], [idx.rUpTh(:);idx.u(:)], ...
        [ones(nGT,1);-rupVec], nGT, nvar), '<', zeros(nGT,1));
    addBlock(sparse([rows;rows;rows], [idx.rDnTh(:);idx.pTh(:);idx.u(:)], ...
        [ones(nGT,1);-ones(nGT,1);pminVec], nGT, nvar), '<', zeros(nGT,1));
    addBlock(sparse([rows;rows], [idx.rDnTh(:);idx.u(:)], ...
        [ones(nGT,1);-rdnVec], nGT, nvar), '<', zeros(nGT,1));

    [AupTime, AdnTime] = minimumTimeMatrices(idx, G, T, minUp, minDown, nvar);
    addBlock(AupTime, '<', zeros(size(AupTime,1),1));
    addBlock(AdnTime, '<', ones(size(AdnTime,1),1));
end

%% 常规水电：容量、爬坡备用和每周可发电量预算
if H > 0
    nHT = H * T;
    rowsH = (1:nHT)';
    capHVec = repmat(hydroCap, T, 1);
    rupHVec = repmat(hydroRampUp, T, 1);
    rdnHVec = repmat(hydroRampDown, T, 1);
    ub(idx.pHydro(:)) = capHVec;

    addBlock(sparse([rowsH;rowsH], [idx.rUpHydro(:);idx.pHydro(:)], 1, nHT, nvar), '<', capHVec);
    addBlock(sparse(rowsH, idx.rUpHydro(:), 1, nHT, nvar), '<', rupHVec);
    addBlock(sparse([rowsH;rowsH], [idx.rDnHydro(:);idx.pHydro(:)], ...
        [ones(nHT,1);-ones(nHT,1)], nHT, nvar), '<', zeros(nHT,1));
    addBlock(sparse(rowsH, idx.rDnHydro(:), 1, nHT, nvar), '<', rdnHVec);

    for h = 1:H
        addBlock(sparse(1, idx.pHydro(h,:), 1, 1, nvar), '<', ...
            cfg.hydroWeeklyCapacityFactor * hydroCap(h) * T);
    end
end

%% 储能：充放电互斥、SOC、分类循环和备用
if S > 0
    for s = 1:S
        for t = 1:T
            addBlock(sparse(1, [idx.charge(s,t),idx.storageMode(s,t)], [1,-storageCap(s)], 1, nvar), '<', 0);
            addBlock(sparse(1, [idx.discharge(s,t),idx.storageMode(s,t)], [1,storageCap(s)], 1, nvar), '<', storageCap(s));
            addBlock(sparse(1, [idx.rUpStorage(s,t),idx.discharge(s,t)], 1, 1, nvar), '<', storageCap(s));
            addBlock(sparse(1, [idx.rUpStorage(s,t),idx.soc(s,t)], [1,-storageEffDis(s)], 1, nvar), '<', 0);
            addBlock(sparse(1, [idx.rDnStorage(s,t),idx.charge(s,t)], 1, 1, nvar), '<', storageCap(s));
            addBlock(sparse(1, [idx.rDnStorage(s,t),idx.soc(s,t)], [storageEffCh(s),1], 1, nvar), '<', storageEnergy(s));

            if t == 1
                cols = [idx.soc(s,t),idx.charge(s,t),idx.discharge(s,t)];
                vals = [1,-storageEffCh(s),1/storageEffDis(s)];
                addBlock(sparse(1, cols, vals, 1, nvar), '=', stateIn.soc0(s));
            else
                cols = [idx.soc(s,t),idx.soc(s,t-1),idx.charge(s,t),idx.discharge(s,t)];
                vals = [1,-1,-storageEffCh(s),1/storageEffDis(s)];
                addBlock(sparse(1, cols, vals, 1, nvar), '=', 0);
            end
        end
        cycleType = lower(string(storage.CycleType(s)));
        if cycleType == "weekly"
            cycleEnds = find(mod(hourIdx(:),168) == 0);
            % 8760小时包含52个完整周和年末24小时，年末也恢复初始SOC，
            % 避免最后一个短优化块无偿耗尽抽水蓄能。
            cycleEnds = unique([cycleEnds;find(hourIdx(:) == numel(data.time))]);
        elseif cycleType == "daily"
            cycleEnds = find(mod(hourIdx(:),24) == 0);
        elseif cycleType == "none"
            cycleEnds = [];
        else
            error('未知储能循环类型：%s',cycleType);
        end
        for tCycle = cycleEnds(:)'
            addBlock(sparse(1, idx.soc(s,tCycle), 1, 1, nvar), '=', ...
                data.storageInitialSOCMWh(s));
        end
    end
end

%% 系统上下备用
for t = 1:T
    reqBaseUp = cfg.loadReserveFraction * loadMW(t) + contingencyMW;
    reqBaseDown = cfg.loadReserveFraction * loadMW(t);

    colsUp = [idx.rUpTh(:,t);idx.rUpHydro(:,t);idx.rUpStorage(:,t); ...
        idx.curWind(t);idx.curSolar(t);idx.pWind(t);idx.pSolar(t)];
    valsUp = [-ones(G+H+S+2,1); cfg.renewableReserveFraction; cfg.renewableReserveFraction];
    addBlock(sparse(1,colsUp,valsUp,1,nvar), '<', -reqBaseUp);

    colsDn = [idx.rDnTh(:,t);idx.rDnHydro(:,t);idx.rDnStorage(:,t);idx.pWind(t);idx.pSolar(t)];
    valsDn = [-ones(G+H+S,1); cfg.renewableReserveFraction; cfg.renewableReserveFraction];
    addBlock(sparse(1,colsDn,valsDn,1,nvar), '<', -reqBaseDown);
end

%% 汇总并求解
A = vertcat(Ablocks{:});
rhs = vertcat(rhsBlocks{:});
sense = vertcat(senseBlocks{:});

milp.name = sprintf('Xinjiang_UCED_block_%03d', blockNumber);
milp.A = A;
milp.rhs = rhs;
milp.sense = sense;
milp.obj = obj;
milp.lb = lb;
milp.ub = ub;
milp.vtype = vtype;

if cfg.verbose
    fprintf('块 %d：%d 小时，%d 个变量（%d 个二元），%d 条约束，非零元 %d。\n', ...
        blockNumber, T, nvar, nnz(vtype=='B'), size(A,1), nnz(A));
end
solution = solve_milp_model(milp, cfg);
x = solution.x;

%% 解包
week.hourIdx = hourIdx(:);
week.time = data.time(hourIdx);
week.pThermal = reshape(x(idx.pTh(:)), G, T);
week.commitment = reshape(x(idx.u(:)), G, T);
week.startup = reshape(x(idx.su(:)), G, T);
week.shutdown = reshape(x(idx.sd(:)), G, T);
week.rUpThermal = reshape(x(idx.rUpTh(:)), G, T);
week.rDnThermal = reshape(x(idx.rDnTh(:)), G, T);
week.pHydro = reshape(x(idx.pHydro(:)), H, T);
week.rUpHydro = reshape(x(idx.rUpHydro(:)), H, T);
week.rDnHydro = reshape(x(idx.rDnHydro(:)), H, T);
week.pWind = x(idx.pWind(:));
week.curWind = x(idx.curWind(:));
week.pSolar = x(idx.pSolar(:));
week.curSolar = x(idx.curSolar(:));
week.charge = reshape(x(idx.charge(:)), S, T);
week.discharge = reshape(x(idx.discharge(:)), S, T);
week.soc = reshape(x(idx.soc(:)), S, T);
week.rUpStorage = reshape(x(idx.rUpStorage(:)), S, T);
week.rDnStorage = reshape(x(idx.rDnStorage(:)), S, T);
week.nse = x(idx.nse(:));

week.pCoal = sum(week.pThermal(data.thermalIsCoal,:), 1)';
week.pGas = sum(week.pThermal(data.thermalIsGas,:), 1)';
week.pHydroTotal = sum(week.pHydro, 1)';
week.chargeTotal = sum(week.charge, 1)';
week.dischargeTotal = sum(week.discharge, 1)';
week.socTotal = sum(week.soc, 1)';
week.reserveUpProvided = sum(week.rUpThermal,1)' + sum(week.rUpHydro,1)' + ...
    sum(week.rUpStorage,1)' + week.curWind + week.curSolar;
week.reserveDownProvided = sum(week.rDnThermal,1)' + sum(week.rDnHydro,1)' + ...
    sum(week.rDnStorage,1)' + week.pWind + week.pSolar;
week.reserveUpRequired = cfg.loadReserveFraction*loadMW + ...
    cfg.renewableReserveFraction*(week.pWind+week.pSolar) + contingencyMW;
week.reserveDownRequired = cfg.loadReserveFraction*loadMW + ...
    cfg.renewableReserveFraction*(week.pWind+week.pSolar);
week.hourlyCost = (marginalCost' * week.pThermal)' + (startupCost' * week.startup)' + ...
    cfg.hydroVariableCostPerMWh*week.pHydroTotal + ...
    cfg.storageCycleCostPerMWh*(week.chargeTotal+week.dischargeTotal) + ...
    cfg.vreCurtailPenaltyPerMWh*(week.curWind+week.curSolar) + ...
    cfg.nsePenaltyPerMWh*week.nse;
week.objective = solution.objval;
week.status = string(solution.status);
week.solver = string(solution.solver);
week.runtimeSec = solution.runtimeSec;
week.mipGap = solution.mipGap;
week.contingencyMW = contingencyMW;

%% 向下一滚动块传递边界状态
stateOut = stateIn;
if G > 0
    uRounded = round(week.commitment);
    stateOut.u0 = uRounded(:,end);
    stateOut.p0 = week.pThermal(:,end);
    [stateOut.onDuration, stateOut.offDuration] = updateDurations( ...
        uRounded, stateIn.onDuration, stateIn.offDuration);
end
if S > 0
    stateOut.soc0 = week.soc(:,end);
end

    function matrixIdx = alloc(nrow, ncol)
        matrixIdx = reshape(k + (1:nrow*ncol), nrow, ncol);
        k = k + nrow*ncol;
    end

    function addBlock(Apart, senseValue, rhsValue)
        nRows = size(Apart, 1);
        if isscalar(rhsValue)
            rhsValue = repmat(rhsValue, nRows, 1);
        else
            rhsValue = rhsValue(:);
        end
        if numel(rhsValue) ~= nRows
            error('内部错误：约束右端维度不一致。');
        end
        Ablocks{end+1,1} = Apart;
        rhsBlocks{end+1,1} = rhsValue;
        senseBlocks{end+1,1} = repmat(char(senseValue), nRows, 1);
    end

end

function [Aup, Adn] = minimumTimeMatrices(idx, G, T, minUp, minDown, nvar)
% 每个 (g,t) 一行：sum(startup)-u<=0；sum(shutdown)+u<=1。
nRows = G*T;
nnzUp = nRows + sum(arrayfun(@(g) sum(min((1:T)', minUp(g))), (1:G)'));
nnzDn = nRows + sum(arrayfun(@(g) sum(min((1:T)', minDown(g))), (1:G)'));

ru = zeros(nnzUp,1); cu = zeros(nnzUp,1); vu = zeros(nnzUp,1);
rd = zeros(nnzDn,1); cd = zeros(nnzDn,1); vd = zeros(nnzDn,1);
ku = 0; kd = 0;
for t = 1:T
    for g = 1:G
        row = (t-1)*G + g;
        ku = ku + 1; ru(ku)=row; cu(ku)=idx.u(g,t); vu(ku)=-1;
        fromUp = max(1, t-minUp(g)+1);
        for tau = fromUp:t
            ku=ku+1; ru(ku)=row; cu(ku)=idx.su(g,tau); vu(ku)=1;
        end

        kd = kd + 1; rd(kd)=row; cd(kd)=idx.u(g,t); vd(kd)=1;
        fromDn = max(1, t-minDown(g)+1);
        for tau = fromDn:t
            kd=kd+1; rd(kd)=row; cd(kd)=idx.sd(g,tau); vd(kd)=1;
        end
    end
end
Aup = sparse(ru(1:ku), cu(1:ku), vu(1:ku), nRows, nvar);
Adn = sparse(rd(1:kd), cd(1:kd), vd(1:kd), nRows, nvar);
end

function [onDuration, offDuration] = updateDurations(u, oldOn, oldOff)
[G,T] = size(u);
onDuration = zeros(G,1);
offDuration = zeros(G,1);
for g = 1:G
    endState = u(g,T);
    trailing = 0;
    for t = T:-1:1
        if u(g,t) == endState
            trailing = trailing + 1;
        else
            break;
        end
    end
    if endState == 1
        if trailing == T
            onDuration(g) = oldOn(g) + T;
        else
            onDuration(g) = trailing;
        end
    else
        if trailing == T
            offDuration(g) = oldOff(g) + T;
        else
            offDuration(g) = trailing;
        end
    end
end
end
