% 负荷处理：
%   区域总负荷 = 区域1本地负荷 × 负荷日因子 + 固定外送负荷
%   固定外送负荷 = 1730 MW
% 场景：
%   S0：火电 + 风光
%   S1：火电 + 风光 + 电化学储能
%   S2：火电 + 风光 + 抽水蓄能
%   S3：火电 + 风光 + 电化学储能 + 抽水蓄能
% 储能设置：
%   电化学储能：日循环
%   抽水蓄能：周循环
% 求解环境：
%   MATLAB + YALMIP + Gurobi
% -------------------------------------------------------------------------

clc;
clear;
close all;
yalmip('clear');

%% ======================== 1. 构造数据 ==================================
data = buildData();

%% ======================== 2. 场景设置 ==================================
caseList(1).name = 'S0 基准：火电+风光';
caseList(1).useES = 0;
caseList(1).usePSH = 0;

caseList(2).name = 'S1 协同：加入电化学储能';
caseList(2).useES = 1;
caseList(2).usePSH = 0;

caseList(3).name = 'S2 协同：加入抽水蓄能';
caseList(3).useES = 0;
caseList(3).usePSH = 1;

caseList(4).name = 'S3 协同：储能+抽水蓄能';
caseList(4).useES = 1;
caseList(4).usePSH = 1;

nCase = length(caseList);
Results = cell(nCase,1);

%% ======================== 3. 求解各场景 ================================
for k = 1:nCase

    fprintf('\n============================================================\n');
    fprintf('正在求解场景：%s\n', caseList(k).name);
    fprintf('============================================================\n');

    Results{k} = solveUC(data, caseList(k));

    if Results{k}.sol.problem == 0
        printResult(Results{k});
    else
        fprintf('场景 %s 求解失败：%s\n', ...
            caseList(k).name, yalmiperror(Results{k}.sol.problem));
    end
end

%% ======================== 4. 汇总输出 ==================================
summaryTable = makeSummary(Results);

fprintf('\n======================= 区域1单区域典型周结果汇总 =======================\n');
disp(summaryTable);

writetable(summaryTable, 'UC_singleProvince_region1_withFixedExport_summary_REPenetration_ThermalShare.xlsx');

%% ======================== 5. 绘图 ======================================
plotInput(data);

for k = 1:nCase
    if Results{k}.sol.problem == 0
        plotScenario(data, Results{k});
        plotThermalUnits(data, Results{k});
    end
end

fprintf('\n程序运行结束。结果表已输出：UC_singleProvince_region1_withFixedExport_summary_REPenetration_ThermalShare.xlsx\n');


%% ========================================================================
%% 函数1：构造典型周数据
%% ========================================================================
function data = buildData()

    data.T  = 168;
    data.D  = 7;
    data.H  = 24;
    data.dt = 1;

    %% ---------------------- 1) 负荷数据 ---------------------------------
    % 区域1（送端）本地负荷，单位：MW
    localLoad24 = [ ...
        4370 4270 4170 4120 4170 4370 ...
        4770 5170 5370 5570 5720 5870 ...
        5970 5920 5820 5720 5670 5770 ...
        5920 5870 5620 5270 4870 4570 ];

    % 区域1固定外送负荷，单位：MW
    exportLoad24 = 1730 * ones(1,24);

    % 区域1负荷日因子，第1天—第7天
    loadDayFactor = [0.96 1.20 1.14 0.97 1.10 0.90 0.85];

    data.LocalLoad  = zeros(1,data.T);
    data.ExportLoad = zeros(1,data.T);
    data.Load       = zeros(1,data.T);

    for d = 1:data.D
        idx = (d-1)*24 + (1:24);

        data.LocalLoad(idx)  = localLoad24 * loadDayFactor(d);
        data.ExportLoad(idx) = exportLoad24;

        % 区域聚合负荷 = 本地负荷 + 固定外送负荷
        data.Load(idx) = data.LocalLoad(idx) + data.ExportLoad(idx);
    end

    %% ---------------------- 2) 风光可用出力 -----------------------------
    data.WindCap = 10500;
    data.PvCap   = 10500;

    % 区域1光伏单位出力
    pvPU24 = [ ...
        0.000 0.000 0.000 0.000 0.000 0.000 ...
        0.002 0.053 0.197 0.397 0.606 0.755 ...
        0.840 0.867 0.843 0.790 0.737 0.613 ...
        0.465 0.296 0.131 0.023 0.001 0.000 ];

    % 区域1风电单位出力
    windPU24 = [ ...
        0.46 0.49 0.51 0.50 0.45 0.39 ...
        0.33 0.28 0.24 0.21 0.18 0.16 ...
        0.15 0.16 0.18 0.20 0.23 0.26 ...
        0.30 0.34 0.38 0.41 0.43 0.45 ];

    % 光伏和风电天气响应因子，第1天—第7天
    pvDayFactor   = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];
    windDayFactor = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];

    data.WindAva = zeros(1,data.T);
    data.PvAva   = zeros(1,data.T);

    for d = 1:data.D
        idx = (d-1)*24 + (1:24);

        data.WindAva(idx) = data.WindCap * min(max(windPU24 * windDayFactor(d), 0), 1);
        data.PvAva(idx)   = data.PvCap   * min(max(pvPU24   * pvDayFactor(d),   0), 1);
    end

    %% ---------------------- 3) 火电机组数据 -----------------------------
    data.G = 8;

    data.Pmax = [1200; 1200; 1000; 1000; 800; 800; 660; 500];
    data.Pmin = [480;  480;  400;  400;  320; 320; 264; 200];

    data.RU = [260; 260; 230; 230; 190; 190; 150; 120];
    data.RD = data.RU;

    data.SU = data.Pmax;
    data.SD = data.Pmax;

    data.MinUp   = [4; 4; 3; 3; 3; 3; 2; 2];
    data.MinDown = [4; 4; 3; 3; 3; 3; 2; 2];

    data.MinOnline = 3;

    data.Cvar = [210; 215; 230; 235; 250; 255; 280; 300];
    data.Cfix = [12000; 12000; 9500; 9500; 7000; 7000; 3500; 3000];

    data.Cstart = [90000; 90000; 65000; 65000; 42000; 42000; 18000; 15000];
    data.Cshut  = [30000; 30000; 22000; 22000; 15000; 15000; 7000; 6000];

    data.u0 = [1;1;1;1;1;0;0;0];
    data.P0 = data.u0 .* data.Pmin;

    %% ---------------------- 4) 电化学储能 -------------------------------
    data.ES_Pmax    = 2100;
    data.ES_Emax    = 4200;
    data.ES_Emin    = 0.10 * data.ES_Emax;
    data.ES_E0      = 0.50 * data.ES_Emax;
    data.ES_eta_ch  = 0.95;
    data.ES_eta_dis = 0.95;
    data.ES_cost    = 20;
    data.ES_DailyCycle = 1;

    %% ---------------------- 5) 抽水蓄能 ---------------------------------
    data.PS_Pgen_max  = 1000;
    data.PS_Ppump_max = 1000;
    data.PS_Emax      = 4000;
    data.PS_Emin      = 0.10 * data.PS_Emax;
    data.PS_E0        = 0.50 * data.PS_Emax;
    data.PS_eta_pump  = 0.90;
    data.PS_eta_gen   = 0.90;
    data.PS_cost      = 15;
    data.PS_Ramp      = 1000;
    data.PS_DailyCycle = 0;

    %% ---------------------- 6) 惩罚系数与备用需求 -----------------------
    data.VOLL                = 30000;
    data.ReservePenalty      = 12000;
    data.DownReservePenalty  = 8000;

    % 弃风、弃光惩罚成本：500 元/MWh
    data.CurtWind = 500;
    data.CurtPv   = 500;

    % 正备用需求：应对负荷上升、新能源少发等缺电方向扰动
    data.ReserveReq = max(0.10 * data.Load, ...
                          0.15 * (data.WindAva + data.PvAva));

    % 负备用需求：应对负荷下降、新能源大发等富余方向扰动
    data.DownReserveReq = max(0.05 * data.Load, ...
                              0.10 * (data.WindAva + data.PvAva));
end


%% ========================================================================
%% 函数2：求解 UC
%% ========================================================================
function result = solveUC(data, cfg)

    T  = data.T;
    G  = data.G;
    dt = data.dt;

    %% ---------------------- 决策变量 ------------------------------------
    u  = binvar(G,T,'full');
    y  = binvar(G,T,'full');
    z  = binvar(G,T,'full');
    P  = sdpvar(G,T,'full');

    Pwind = sdpvar(1,T,'full');
    Ppv   = sdpvar(1,T,'full');

    Pch  = sdpvar(1,T,'full');
    Pdis = sdpvar(1,T,'full');
    Ees  = sdpvar(1,T+1,'full');
    uch  = binvar(1,T,'full');
    udis = binvar(1,T,'full');

    Pps_pump = sdpvar(1,T,'full');
    Pps_gen  = sdpvar(1,T,'full');
    Eps      = sdpvar(1,T+1,'full');
    ups_pump = binvar(1,T,'full');
    ups_gen  = binvar(1,T,'full');

    Pshed      = sdpvar(1,T,'full');
    Rshort     = sdpvar(1,T,'full');
    RdownShort = sdpvar(1,T,'full');

    C = [];

    %% ---------------------- 火电出力上下限 ------------------------------
    for t = 1:T
        C = [C, data.Pmin .* u(:,t) <= P(:,t) <= data.Pmax .* u(:,t)];
    end

    %% ---------------------- 最小在线台数 --------------------------------
    for t = 1:T
        C = [C, sum(u(:,t)) >= data.MinOnline];
    end

    %% ---------------------- 启停逻辑 ------------------------------------
    C = [C, y(:,1) - z(:,1) == u(:,1) - data.u0];
    C = [C, y(:,1) + z(:,1) <= 1];

    for t = 2:T
        C = [C, y(:,t) - z(:,t) == u(:,t) - u(:,t-1)];
        C = [C, y(:,t) + z(:,t) <= 1];
    end

    %% ---------------------- 火电爬坡 ------------------------------------
    C = [C, P(:,1) - data.P0 <= data.RU .* data.u0 + data.SU .* y(:,1)];
    C = [C, data.P0 - P(:,1) <= data.RD .* u(:,1) + data.SD .* z(:,1)];

    for t = 2:T
        C = [C, P(:,t) - P(:,t-1) <= data.RU .* u(:,t-1) + data.SU .* y(:,t)];
        C = [C, P(:,t-1) - P(:,t) <= data.RD .* u(:,t) + data.SD .* z(:,t)];
    end

    %% ---------------------- 最小开机时间 --------------------------------
    for g = 1:G
        Ton = data.MinUp(g);
        for t = 1:T
            tEnd = min(T, t + Ton - 1);
            C = [C, sum(u(g,t:tEnd)) >= (tEnd - t + 1) * y(g,t)];
        end
    end

    %% ---------------------- 最小停机时间 --------------------------------
    for g = 1:G
        Toff = data.MinDown(g);
        for t = 1:T
            tEnd = min(T, t + Toff - 1);
            C = [C, sum(1 - u(g,t:tEnd)) >= (tEnd - t + 1) * z(g,t)];
        end
    end

    %% ---------------------- 风光出力约束 --------------------------------
    C = [C, 0 <= Pwind <= data.WindAva];
    C = [C, 0 <= Ppv   <= data.PvAva];

    %% ---------------------- 电化学储能约束 ------------------------------
    if cfg.useES == 1

        C = [C, 0 <= Pch  <= data.ES_Pmax .* uch];
        C = [C, 0 <= Pdis <= data.ES_Pmax .* udis];
        C = [C, uch + udis <= 1];
        C = [C, data.ES_Emin <= Ees <= data.ES_Emax];

        if data.ES_DailyCycle == 1
            for d = 1:data.D
                tStart = (d-1)*24 + 1;
                tEnd   = d*24 + 1;
                C = [C, Ees(tStart) == data.ES_E0];
                C = [C, Ees(tEnd)   == data.ES_E0];
            end
        else
            C = [C, Ees(1) == data.ES_E0];
            C = [C, Ees(T+1) == data.ES_E0];
        end

        for t = 1:T
            C = [C, Ees(t+1) == Ees(t) ...
                + data.ES_eta_ch  * Pch(t)  * dt ...
                - Pdis(t) / data.ES_eta_dis * dt];
        end

    else

        C = [C, Pch == 0, Pdis == 0];
        C = [C, uch == 0, udis == 0];
        C = [C, Ees == data.ES_E0];

    end

    %% ---------------------- 抽水蓄能约束 --------------------------------
    if cfg.usePSH == 1

        C = [C, 0 <= Pps_pump <= data.PS_Ppump_max .* ups_pump];
        C = [C, 0 <= Pps_gen  <= data.PS_Pgen_max  .* ups_gen];
        C = [C, ups_pump + ups_gen <= 1];
        C = [C, data.PS_Emin <= Eps <= data.PS_Emax];

        if data.PS_DailyCycle == 1
            for d = 1:data.D
                tStart = (d-1)*24 + 1;
                tEnd   = d*24 + 1;
                C = [C, Eps(tStart) == data.PS_E0];
                C = [C, Eps(tEnd)   == data.PS_E0];
            end
        else
            C = [C, Eps(1) == data.PS_E0];
            C = [C, Eps(T+1) == data.PS_E0];
        end

        for t = 1:T
            C = [C, Eps(t+1) == Eps(t) ...
                + data.PS_eta_pump * Pps_pump(t) * dt ...
                - Pps_gen(t) / data.PS_eta_gen * dt];
        end

        for t = 2:T
            C = [C, -data.PS_Ramp <= Pps_pump(t) - Pps_pump(t-1) <= data.PS_Ramp];
            C = [C, -data.PS_Ramp <= Pps_gen(t)  - Pps_gen(t-1)  <= data.PS_Ramp];
        end

    else

        C = [C, Pps_pump == 0, Pps_gen == 0];
        C = [C, ups_pump == 0, ups_gen == 0];
        C = [C, Eps == data.PS_E0];

    end

    %% ---------------------- 失负荷、正备用不足、负备用不足 ---------------
    C = [C, 0 <= Pshed <= data.Load];
    C = [C, Rshort >= 0];
    C = [C, RdownShort >= 0];

    %% ---------------------- 功率平衡 ------------------------------------
    for t = 1:T
        C = [C, ...
            sum(P(:,t)) ...
            + Pwind(t) + Ppv(t) ...
            + Pdis(t) - Pch(t) ...
            + Pps_gen(t) - Pps_pump(t) ...
            + Pshed(t) ...
            == data.Load(t)];
    end

    %% ---------------------- 正备用与负备用约束 --------------------------
    for t = 1:T

        %% 正备用：向上调节能力
        Rup_th = sum(data.Pmax .* u(:,t) - P(:,t));

        if cfg.useES == 1
            Rup_es = Pch(t) + (data.ES_Pmax - Pdis(t));
        else
            Rup_es = 0;
        end

        if cfg.usePSH == 1
            Rup_ps = Pps_pump(t) + (data.PS_Pgen_max - Pps_gen(t));
        else
            Rup_ps = 0;
        end

        C = [C, Rup_th + Rup_es + Rup_ps + Rshort(t) >= data.ReserveReq(t)];

        %% 负备用：向下调节能力
        Rdn_th = sum(P(:,t) - data.Pmin .* u(:,t));

        if cfg.useES == 1
            Rdn_es = Pdis(t) + (data.ES_Pmax - Pch(t));
        else
            Rdn_es = 0;
        end

        if cfg.usePSH == 1
            Rdn_ps = Pps_gen(t) + (data.PS_Ppump_max - Pps_pump(t));
        else
            Rdn_ps = 0;
        end

        C = [C, Rdn_th + Rdn_es + Rdn_ps + RdownShort(t) >= data.DownReserveReq(t)];
    end

    %% ---------------------- 目标函数 ------------------------------------
    C_thermal = sum(sum( ...
        repmat(data.Cvar,1,T)   .* P + ...
        repmat(data.Cfix,1,T)   .* u + ...
        repmat(data.Cstart,1,T) .* y + ...
        repmat(data.Cshut,1,T)  .* z ));

    C_curt = data.CurtWind * sum(data.WindAva - Pwind) * dt ...
           + data.CurtPv   * sum(data.PvAva   - Ppv)   * dt;

    C_shed = data.VOLL * sum(Pshed) * dt;

    C_reserve = data.ReservePenalty     * sum(Rshort) * dt ...
              + data.DownReservePenalty * sum(RdownShort) * dt;

    C_storage = data.ES_cost * sum(Pch + Pdis) * dt;
    C_psh     = data.PS_cost * sum(Pps_pump + Pps_gen) * dt;

    objective = C_thermal + C_curt + C_shed + C_reserve + C_storage + C_psh;

    ops = sdpsettings('solver','gurobi','verbose',1);
    ops.gurobi.MIPGap    = 1e-2;
    ops.gurobi.TimeLimit = 600;

    sol = optimize(C, objective, ops);

    %% ---------------------- 保存结果 ------------------------------------
    result.name = cfg.name;
    result.sol  = sol;

    if sol.problem ~= 0
        result = fillFailed(result);
        return;
    end

    result.obj    = value(objective);
    result.P      = value(P);
    result.u      = value(u);
    result.y      = value(y);
    result.z      = value(z);

    result.Pwind  = value(Pwind);
    result.Ppv    = value(Ppv);

    result.Pch    = value(Pch);
    result.Pdis   = value(Pdis);
    result.Ees    = value(Ees);

    result.Pps_pump = value(Pps_pump);
    result.Pps_gen  = value(Pps_gen);
    result.Eps      = value(Eps);

    result.Pshed      = value(Pshed);
    result.Rshort     = value(Rshort);
    result.RdownShort = value(RdownShort);

    result.C_thermal = value(C_thermal);
    result.C_curt    = value(C_curt);
    result.C_shed    = value(C_shed);
    result.C_reserve = value(C_reserve);
    result.C_storage = value(C_storage);
    result.C_psh     = value(C_psh);

    result = calcIndicators(data, result);
end


%% ========================================================================
%% 函数3：指标计算
%% ========================================================================
function result = calcIndicators(data, result)

    dt = data.dt;

    windCurt = data.WindAva - result.Pwind;
    pvCurt   = data.PvAva   - result.Ppv;

    windCurt(abs(windCurt) < 1e-6) = 0;
    pvCurt(abs(pvCurt) < 1e-6) = 0;

    %% ---------------------- 弃风弃光与新能源消纳 ------------------------
    result.WindCurtail_MWh  = sum(windCurt) * dt;
    result.PvCurtail_MWh    = sum(pvCurt)   * dt;
    result.TotalCurtail_MWh = result.WindCurtail_MWh + result.PvCurtail_MWh;

    result.WindCurtailRate_percent = ...
        100 * result.WindCurtail_MWh / max(1e-6, sum(data.WindAva)*dt);

    result.PvCurtailRate_percent = ...
        100 * result.PvCurtail_MWh / max(1e-6, sum(data.PvAva)*dt);

    result.CurtailRate_percent = ...
        100 * result.TotalCurtail_MWh / ...
        max(1e-6, (sum(data.WindAva)+sum(data.PvAva))*dt);

    % 新能源消纳率：新能源消纳电量 / 新能源可用发电量
    result.RE_Utilization_percent = ...
        100 * (sum(result.Pwind) + sum(result.Ppv))*dt / ...
        max(1e-6, (sum(data.WindAva)+sum(data.PvAva))*dt);

    %% ---------------------- 新能源渗透率指标 -----------------------------
    % 新能源消纳电量：实际消纳的风电 + 光伏电量
    result.RE_Consumed_MWh = ...
        (sum(result.Pwind) + sum(result.Ppv)) * dt;

    % 总用电量：聚合负荷电量 = 本地负荷 + 固定外送负荷
    result.TotalLoad_MWh = sum(data.Load) * dt;

    % 本地用电量：仅本地负荷电量，作为辅助对比口径
    result.LocalLoad_MWh = sum(data.LocalLoad) * dt;

    % 固定外送电量
    result.ExportLoad_MWh = sum(data.ExportLoad) * dt;

    % 火电发电量
    result.ThermalGen_MWh = sum(sum(result.P)) * dt;

    % 火电供电占比：火电发电量 / 总负荷量
    result.ThermalShare_percent = ...
        100 * result.ThermalGen_MWh / max(1e-6, result.TotalLoad_MWh);

    % 新能源渗透率：
    % 按 1 - 火电发电量 / 总负荷量 计算
    result.RE_Penetration_percent = ...
        100 * (1 - result.ThermalGen_MWh / max(1e-6, result.TotalLoad_MWh));

    % 本地负荷口径火电供电占比
    result.ThermalShare_LocalLoad_percent = ...
        100 * result.ThermalGen_MWh / max(1e-6, result.LocalLoad_MWh);

    % 本地负荷口径新能源渗透率
    result.RE_Penetration_LocalLoad_percent = ...
        100 * (1 - result.ThermalGen_MWh / max(1e-6, result.LocalLoad_MWh));

    %% ---------------------- 可靠性与灵活性资源调用 -----------------------
    result.EENS_MWh = sum(result.Pshed) * dt;
    result.LOLH_h   = sum(result.Pshed > 1e-4);
    result.MaxShed_MW = max(result.Pshed);

    result.ReserveShort_MWh = sum(result.Rshort) * dt;
    result.ReserveShortHours_h = sum(result.Rshort > 1e-4);

    result.DownReserveShort_MWh = sum(result.RdownShort) * dt;
    result.DownReserveShortHours_h = sum(result.RdownShort > 1e-4);

    result.StartupTimes = sum(sum(result.y));
    result.StorageCharge_MWh = sum(result.Pch) * dt;
    result.StorageDischarge_MWh = sum(result.Pdis) * dt;
    result.PSHPump_MWh = sum(result.Pps_pump) * dt;
    result.PSHGen_MWh  = sum(result.Pps_gen)  * dt;
end


%% ========================================================================
%% 函数4：失败结果填充
%% ========================================================================
function result = fillFailed(result)

    result.obj = NaN;
    result.C_thermal = NaN;
    result.C_curt = NaN;
    result.C_shed = NaN;
    result.C_reserve = NaN;
    result.C_storage = NaN;
    result.C_psh = NaN;

    result.EENS_MWh = NaN;
    result.LOLH_h = NaN;
    result.MaxShed_MW = NaN;

    result.ReserveShort_MWh = NaN;
    result.ReserveShortHours_h = NaN;
    result.DownReserveShort_MWh = NaN;
    result.DownReserveShortHours_h = NaN;

    result.CurtailRate_percent = NaN;
    result.WindCurtailRate_percent = NaN;
    result.PvCurtailRate_percent = NaN;
    result.RE_Utilization_percent = NaN;

    result.RE_Consumed_MWh = NaN;
    result.TotalLoad_MWh = NaN;
    result.LocalLoad_MWh = NaN;
    result.ExportLoad_MWh = NaN;

    result.ThermalGen_MWh = NaN;
    result.ThermalShare_percent = NaN;
    result.RE_Penetration_percent = NaN;

    result.ThermalShare_LocalLoad_percent = NaN;
    result.RE_Penetration_LocalLoad_percent = NaN;

    result.StartupTimes = NaN;
    result.StorageCharge_MWh = NaN;
    result.StorageDischarge_MWh = NaN;
    result.PSHPump_MWh = NaN;
    result.PSHGen_MWh = NaN;
end


%% ========================================================================
%% 函数5：汇总表
%% ========================================================================
function summaryTable = makeSummary(Results)

    nCase = length(Results);

    Scenario = strings(nCase,1);
    TotalCost_yuan = nan(nCase,1);
    ThermalCost_yuan = nan(nCase,1);
    CurtCost_yuan = nan(nCase,1);
    ShedCost_yuan = nan(nCase,1);
    ReserveCost_yuan = nan(nCase,1);
    StorageCost_yuan = nan(nCase,1);
    PSHCost_yuan = nan(nCase,1);

    EENS_MWh = nan(nCase,1);
    LOLH_h = nan(nCase,1);
    MaxShed_MW = nan(nCase,1);

    ReserveShort_MWh = nan(nCase,1);
    ReserveShortHours_h = nan(nCase,1);
    DownReserveShort_MWh = nan(nCase,1);
    DownReserveShortHours_h = nan(nCase,1);

    CurtailRate_percent = nan(nCase,1);
    WindCurtailRate_percent = nan(nCase,1);
    PvCurtailRate_percent = nan(nCase,1);
    RE_Utilization_percent = nan(nCase,1);

    RE_Consumed_MWh = nan(nCase,1);
    TotalLoad_MWh = nan(nCase,1);
    LocalLoad_MWh = nan(nCase,1);
    ExportLoad_MWh = nan(nCase,1);

    ThermalGen_MWh = nan(nCase,1);
    ThermalShare_percent = nan(nCase,1);
    RE_Penetration_percent = nan(nCase,1);

    ThermalShare_LocalLoad_percent = nan(nCase,1);
    RE_Penetration_LocalLoad_percent = nan(nCase,1);

    StartupTimes = nan(nCase,1);
    StorageCharge_MWh = nan(nCase,1);
    StorageDischarge_MWh = nan(nCase,1);
    PSHPump_MWh = nan(nCase,1);
    PSHGen_MWh = nan(nCase,1);

    for k = 1:nCase
        r = Results{k};

        Scenario(k) = string(r.name);

        TotalCost_yuan(k) = r.obj;
        ThermalCost_yuan(k) = r.C_thermal;
        CurtCost_yuan(k) = r.C_curt;
        ShedCost_yuan(k) = r.C_shed;
        ReserveCost_yuan(k) = r.C_reserve;
        StorageCost_yuan(k) = r.C_storage;
        PSHCost_yuan(k) = r.C_psh;

        EENS_MWh(k) = r.EENS_MWh;
        LOLH_h(k) = r.LOLH_h;
        MaxShed_MW(k) = r.MaxShed_MW;

        ReserveShort_MWh(k) = r.ReserveShort_MWh;
        ReserveShortHours_h(k) = r.ReserveShortHours_h;
        DownReserveShort_MWh(k) = r.DownReserveShort_MWh;
        DownReserveShortHours_h(k) = r.DownReserveShortHours_h;

        CurtailRate_percent(k) = r.CurtailRate_percent;
        WindCurtailRate_percent(k) = r.WindCurtailRate_percent;
        PvCurtailRate_percent(k) = r.PvCurtailRate_percent;
        RE_Utilization_percent(k) = r.RE_Utilization_percent;

        RE_Consumed_MWh(k) = r.RE_Consumed_MWh;
        TotalLoad_MWh(k) = r.TotalLoad_MWh;
        LocalLoad_MWh(k) = r.LocalLoad_MWh;
        ExportLoad_MWh(k) = r.ExportLoad_MWh;

        ThermalGen_MWh(k) = r.ThermalGen_MWh;
        ThermalShare_percent(k) = r.ThermalShare_percent;
        RE_Penetration_percent(k) = r.RE_Penetration_percent;

        ThermalShare_LocalLoad_percent(k) = r.ThermalShare_LocalLoad_percent;
        RE_Penetration_LocalLoad_percent(k) = r.RE_Penetration_LocalLoad_percent;

        StartupTimes(k) = r.StartupTimes;
        StorageCharge_MWh(k) = r.StorageCharge_MWh;
        StorageDischarge_MWh(k) = r.StorageDischarge_MWh;
        PSHPump_MWh(k) = r.PSHPump_MWh;
        PSHGen_MWh(k) = r.PSHGen_MWh;
    end

    summaryTable = table( ...
        Scenario, ...
        TotalCost_yuan, ...
        ThermalCost_yuan, ...
        CurtCost_yuan, ...
        ShedCost_yuan, ...
        ReserveCost_yuan, ...
        StorageCost_yuan, ...
        PSHCost_yuan, ...
        EENS_MWh, ...
        LOLH_h, ...
        MaxShed_MW, ...
        ReserveShort_MWh, ...
        ReserveShortHours_h, ...
        DownReserveShort_MWh, ...
        DownReserveShortHours_h, ...
        CurtailRate_percent, ...
        WindCurtailRate_percent, ...
        PvCurtailRate_percent, ...
        RE_Utilization_percent, ...
        RE_Consumed_MWh, ...
        TotalLoad_MWh, ...
        LocalLoad_MWh, ...
        ExportLoad_MWh, ...
        ThermalGen_MWh, ...
        ThermalShare_percent, ...
        RE_Penetration_percent, ...
        ThermalShare_LocalLoad_percent, ...
        RE_Penetration_LocalLoad_percent, ...
        StartupTimes, ...
        StorageCharge_MWh, ...
        StorageDischarge_MWh, ...
        PSHPump_MWh, ...
        PSHGen_MWh);
end


%% ========================================================================
%% 函数6：打印结果
%% ========================================================================
function printResult(result)

    fprintf('\n-------------------- 场景结果：%s --------------------\n', result.name);

    fprintf('总运行成本：%.2f 万元\n', result.obj/1e4);
    fprintf('火电成本：%.2f 万元\n', result.C_thermal/1e4);
    fprintf('弃风弃光成本：%.2f 万元\n', result.C_curt/1e4);
    fprintf('失负荷惩罚成本：%.2f 万元\n', result.C_shed/1e4);
    fprintf('备用不足惩罚成本：%.2f 万元\n', result.C_reserve/1e4);
    fprintf('储能运行成本：%.2f 万元\n', result.C_storage/1e4);
    fprintf('抽蓄运行成本：%.2f 万元\n', result.C_psh/1e4);

    fprintf('\n可靠性指标：\n');
    fprintf('EENS 失负荷电量：%.2f MWh\n', result.EENS_MWh);
    fprintf('LOLH 失负荷小时数：%.0f h\n', result.LOLH_h);
    fprintf('最大失负荷功率：%.2f MW\n', result.MaxShed_MW);

    fprintf('正备用不足总量：%.2f MWh\n', result.ReserveShort_MWh);
    fprintf('正备用不足小时数：%.0f h\n', result.ReserveShortHours_h);
    fprintf('负备用不足总量：%.2f MWh\n', result.DownReserveShort_MWh);
    fprintf('负备用不足小时数：%.0f h\n', result.DownReserveShortHours_h);

    fprintf('\n新能源消纳与渗透指标：\n');
    fprintf('总弃风弃光率：%.2f %%\n', result.CurtailRate_percent);
    fprintf('弃风率：%.2f %%\n', result.WindCurtailRate_percent);
    fprintf('弃光率：%.2f %%\n', result.PvCurtailRate_percent);
    fprintf('新能源消纳率：%.2f %%\n', result.RE_Utilization_percent);

    fprintf('新能源消纳电量：%.2f MWh\n', result.RE_Consumed_MWh);
    fprintf('总用电量：%.2f MWh\n', result.TotalLoad_MWh);
    fprintf('本地用电量：%.2f MWh\n', result.LocalLoad_MWh);
    fprintf('固定外送电量：%.2f MWh\n', result.ExportLoad_MWh);

    fprintf('火电发电量：%.2f MWh\n', result.ThermalGen_MWh);
    fprintf('火电供电占比：%.2f %%\n', result.ThermalShare_percent);
    fprintf('新能源渗透率，按1-火电/总负荷计算：%.2f %%\n', result.RE_Penetration_percent);

    fprintf('本地负荷口径火电占比：%.2f %%\n', result.ThermalShare_LocalLoad_percent);
    fprintf('本地负荷口径新能源渗透率：%.2f %%\n', result.RE_Penetration_LocalLoad_percent);

    fprintf('\n协同资源调用情况：\n');
    fprintf('火电启动次数：%.0f 次\n', result.StartupTimes);
    fprintf('储能充电电量：%.2f MWh\n', result.StorageCharge_MWh);
    fprintf('储能放电电量：%.2f MWh\n', result.StorageDischarge_MWh);
    fprintf('抽蓄抽水电量：%.2f MWh\n', result.PSHPump_MWh);
    fprintf('抽蓄发电电量：%.2f MWh\n', result.PSHGen_MWh);
end


%% ========================================================================
%% 函数7：输入数据图
%% ========================================================================
function plotInput(data)

    t = 1:data.T;

    figure('Name','区域1典型周输入数据');

    subplot(4,1,1);
    plot(t, data.LocalLoad, 'LineWidth', 1.4);
    hold on;
    plot(t, data.ExportLoad, 'LineWidth', 1.4);
    plot(t, data.Load, 'k-', 'LineWidth', 1.8);
    xlabel('时段/h');
    ylabel('功率/MW');
    title('区域1本地负荷、固定外送负荷与聚合负荷');
    legend('本地负荷','固定外送负荷','聚合负荷=本地+外送','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,2);
    plot(t, data.WindAva, 'LineWidth', 1.5);
    xlabel('时段/h');
    ylabel('风电/MW');
    title('区域1风电可用出力');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,3);
    plot(t, data.PvAva, 'LineWidth', 1.5);
    xlabel('时段/h');
    ylabel('光伏/MW');
    title('区域1光伏可用出力');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,4);
    plot(t, data.WindAva + data.PvAva, 'LineWidth', 1.5);
    hold on;
    plot(t, data.Load, 'k-', 'LineWidth', 1.5);
    xlabel('时段/h');
    ylabel('功率/MW');
    title('区域1风光可用出力与聚合负荷对比');
    legend('风光可用出力','聚合负荷','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数8：场景总体结果图
%% ========================================================================
function plotScenario(data, result)

    T = data.T;
    t = 1:T;

    Pth_sum = sum(result.P,1);
    windCurt = data.WindAva - result.Pwind;
    pvCurt   = data.PvAva   - result.Ppv;

    %% ---------------------- 电力平衡图 ----------------------------------
    figure('Name',['区域1典型周电力平衡 - ', result.name]);

    supplyStack = [ ...
        Pth_sum(:), ...
        result.Pwind(:), ...
        result.Ppv(:), ...
        result.Pdis(:), ...
        result.Pps_gen(:), ...
        result.Pshed(:), ...
        -result.Pch(:), ...
        -result.Pps_pump(:) ];

    bBal = bar(t, supplyStack, 'stacked');

    if numel(bBal) >= 1
        bBal(1).FaceColor = [0.55 0.55 0.55];
    end

    hold on;
    plot(t, data.Load, 'k-', 'LineWidth', 1.8);
    plot(t, data.LocalLoad, 'k--', 'LineWidth', 1.1);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['区域1典型周电力平衡结果 - ', result.name]);
    legend('火电','风电消纳','光伏消纳','储能放电','抽蓄发电','失负荷', ...
        '储能充电','抽蓄抽水','聚合负荷','本地负荷','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% ---------------------- 风光消纳图 ----------------------------------
    figure('Name',['区域1典型周风光消纳 - ', result.name]);

    plot(t, data.WindAva, '--', 'LineWidth', 1.2);
    hold on;
    plot(t, result.Pwind, '-', 'LineWidth', 1.6);
    plot(t, data.PvAva, '--', 'LineWidth', 1.2);
    plot(t, result.Ppv, '-', 'LineWidth', 1.6);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['区域1典型周风光可用出力与消纳出力 - ', result.name]);
    legend('风电可用','风电消纳','光伏可用','光伏消纳','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% ---------------------- 弃风弃光图 ----------------------------------
    figure('Name',['区域1典型周弃风弃光 - ', result.name]);

    bar(t, [windCurt(:), pvCurt(:)], 'stacked');
    xlabel('时段/h');
    ylabel('弃电功率/MW');
    title(['区域1典型周弃风弃光结果 - ', result.name]);
    legend('弃风','弃光','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% ---------------------- 电化学储能图 --------------------------------
    figure('Name',['区域1典型周电化学储能运行 - ', result.name]);

    yyaxis left;
    bar(t, [result.Pdis(:), -result.Pch(:)], 'stacked');
    ylabel('充放电功率/MW');

    yyaxis right;
    plot(0:T, result.Ees, '-', 'LineWidth', 1.8);
    ylabel('储能电量/MWh');

    xlabel('时段/h');
    title(['区域1典型周电化学储能运行结果 - ', result.name]);
    legend('放电','充电','SOC','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% ---------------------- 抽水蓄能图 ----------------------------------
    figure('Name',['区域1典型周抽水蓄能运行 - ', result.name]);

    yyaxis left;
    bar(t, [result.Pps_gen(:), -result.Pps_pump(:)], 'stacked');
    ylabel('抽蓄功率/MW');

    yyaxis right;
    plot(0:T, result.Eps, '-', 'LineWidth', 1.8);
    ylabel('上水库等效能量/MWh');

    xlabel('时段/h');
    title(['区域1典型周抽水蓄能运行结果 - ', result.name]);
    legend('抽蓄发电','抽蓄抽水','上水库能量','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% ---------------------- 可靠性不足图 --------------------------------
    figure('Name',['区域1典型周可靠性不足 - ', result.name]);

    bar(t, [result.Pshed(:), result.Rshort(:), result.RdownShort(:)]);
    xlabel('时段/h');
    ylabel('功率/MW');
    title(['区域1典型周失负荷与备用不足 - ', result.name]);
    legend('失负荷','正备用不足','负备用不足','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数9：火电机组出力图
%% ========================================================================
function plotThermalUnits(data, result)

    T = data.T;
    G = data.G;
    t = 1:T;

    P = result.P;
    u = result.u;

    unitNames = cell(G,1);
    for g = 1:G
        unitNames{g} = ['G', num2str(g)];
    end

    %% ---------------------- 逐台火电机组出力 ----------------------------
    figure('Name',['区域1逐台火电机组出力 - ', result.name]);

    hUnit = plot(t, P', 'LineWidth', 1.1);

    grayValsLine = linspace(0.25, 0.75, G);
    for gg = 1:min(numel(hUnit), G)
        hUnit(gg).Color = [grayValsLine(gg) grayValsLine(gg) grayValsLine(gg)];
    end

    xlabel('时段/h');
    ylabel('机组出力/MW');
    title(['区域1典型周逐台火电机组出力曲线 - ', result.name]);
    legend(unitNames, 'Location', 'eastoutside');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% ---------------------- 火电机组堆叠出力 ----------------------------
    figure('Name',['区域1火电机组堆叠出力 - ', result.name]);

    bThermal = bar(t, P', 'stacked');

    grayVals = linspace(0.30, 0.80, G);
    for gg = 1:min(numel(bThermal), G)
        bThermal(gg).FaceColor = [grayVals(gg) grayVals(gg) grayVals(gg)];
    end

    xlabel('时段/h');
    ylabel('火电出力/MW');
    title(['区域1典型周火电机组堆叠出力结果 - ', result.name]);
    legend(unitNames, 'Location', 'eastoutside');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% ---------------------- 火电启停状态 --------------------------------
    figure('Name',['区域1火电机组启停状态 - ', result.name]);

    imagesc(t, 1:G, u);
    xlabel('时段/h');
    ylabel('机组编号');
    title(['区域1典型周火电机组启停状态 - ', result.name]);
    yticks(1:G);
    yticklabels(unitNames);
    colorbar;
    grid on;
    xlim([1 T]);

    %% ---------------------- 火电总出力与净负荷 --------------------------
    figure('Name',['区域1火电总出力与净负荷 - ', result.name]);

    Pth_sum = sum(P,1);

    Pnet = data.Load ...
           - result.Pwind - result.Ppv ...
           - result.Pdis + result.Pch ...
           - result.Pps_gen + result.Pps_pump;

    plot(t, Pth_sum, '-', 'LineWidth', 1.8);
    hold on;
    plot(t, data.Load, '--', 'LineWidth', 1.5);
    plot(t, data.LocalLoad, ':', 'LineWidth', 1.5);
    plot(t, result.Pwind + result.Ppv, '-.', 'LineWidth', 1.5);
    plot(t, data.Load - result.Pwind - result.Ppv, ':', 'LineWidth', 1.8);
    plot(t, Pnet, '-', 'LineWidth', 1.4);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['区域1典型周火电总出力与净负荷对比 - ', result.name]);
    legend('火电总出力','聚合负荷','本地负荷','风光消纳出力', ...
        '风光后净负荷','考虑储能/抽蓄后的火电需承担净负荷', ...
        'Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数10：日分隔线
%% ========================================================================
function addDayLines(data)
    for d = 1:data.D
        xline((d-1)*24 + 1, ':', 'HandleVisibility','off');
    end
end