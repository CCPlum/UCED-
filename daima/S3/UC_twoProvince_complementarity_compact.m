% -------------------------------------------------------------------------
% 两区域互补协同 UC 模拟程序：区域1与区域3，典型周168h
% 研究对象：
%   区域1：送端区域，承担本地负荷 + 固定外送 1730 MW
%   区域3：送端区域，承担本地负荷 + 固定外送 2300 MW
%
% 场景设置：
%   S0：无互补协同情景
%       区域1、区域3分别作为单区域多能互补系统独立优化；
%       即各自满足“本地负荷 + 固定外送负荷”；
%       区域间联络线 Ptie = 0。
%
%   S1：两区域互补协同情景
%       区域1与区域3之间可通过联络线相互送电；
%       Ptie(t) > 0 表示区域1向区域3送电；
%       Ptie(t) < 0 表示区域3向区域1送电。
%
% 模型资源：
%   火电、风电、光伏、电化学储能、抽水蓄能、区域间联络线。
%
% 其中：
%   总负荷量 = 本地负荷电量 + 固定外送电量
%
% 运行环境：
%   MATLAB + YALMIP + Gurobi
% -------------------------------------------------------------------------

clc;
clear;
close all;
yalmip('clear');

%% ======================== 1. 构造两区域数据 =============================
data = buildData_twoRegion_R1_R3();

%% ======================== 2. S0：两个单区域独立多能互补 ==================
fprintf('\n============================================================\n');
fprintf('正在求解场景：S0 无互补协同：区域1、区域3分别单区域多能互补独立优化\n');
fprintf('============================================================\n');

resR1 = solveUC_oneRegion(data, 1);
resR3 = solveUC_oneRegion(data, 2);

Results{1} = combineIndependentResults(data, resR1, resR3);

if isAcceptableSol(Results{1})
    if Results{1}.sol.problem == 3
        fprintf('S0 达到时间限制，但已取得可行解，按近似最优解保留。\n');
    end
    printResult_twoRegion(Results{1});
else
    fprintf('S0 无互补协同情景存在求解失败：%s\n', yalmiperror(Results{1}.sol.problem));
end

%% ======================== 3. S1：两区域互补协同联合优化 ==================
fprintf('\n============================================================\n');
fprintf('正在求解场景：S1 两区域互补协同：区域1与区域3通过联络线相互支援\n');
fprintf('============================================================\n');

Results{2} = solveUC_jointTwoRegion(data);

if isAcceptableSol(Results{2})
    if Results{2}.sol.problem == 3
        fprintf('S1 达到时间限制，但已取得可行解，按近似最优解保留。\n');
    end
    printResult_twoRegion(Results{2});
else
    fprintf('S1 互补协同情景求解失败：%s\n', yalmiperror(Results{2}.sol.problem));
end

%% ======================== 4. 汇总输出 ==================================
summaryTable = makeSummary_twoRegion(Results);

fprintf('\n======================= 区域1-区域3独立/互补协同对比指标汇总 =======================\n');
disp(summaryTable);

writetable(summaryTable, 'UC_twoRegion_R1_R3_interconnection_v5_REPenetration_summary.xlsx');

%% ======================== 5. 绘图 ======================================
plotInput_twoRegion(data);

for k = 1:2
    if isAcceptableSol(Results{k})
        plotScenario_twoRegion(data, Results{k});
        plotThermal_twoRegion(data, Results{k});
    else
        fprintf('场景 %s 未取得可用解，跳过结果绘图。\n', Results{k}.name);
    end
end

fprintf('\n程序运行结束。结果表已输出：UC_twoRegion_R1_R3_interconnection_v5_REPenetration_summary.xlsx\n');


%% ========================================================================
%% 函数0：判断求解结果是否可用
%% ========================================================================
function flag = isAcceptableSol(result)

    flag = false;

    if ~isfield(result,'sol') || ~isfield(result.sol,'problem')
        return;
    end

    if ~(result.sol.problem == 0 || result.sol.problem == 3)
        return;
    end

    if ~isfield(result,'P')
        return;
    end

    if iscell(result.P)
        ok = true;
        for ii = 1:numel(result.P)
            if isempty(result.P{ii}) || all(isnan(result.P{ii}(:)))
                ok = false;
            end
        end
        flag = ok;
    else
        flag = ~isempty(result.P) && ~all(isnan(result.P(:)));
    end
end


%% ========================================================================
%% 函数1：构造区域1与区域3典型周数据
%% ========================================================================
function data = buildData_twoRegion_R1_R3()

    data.T  = 168;
    data.D  = 7;
    data.H  = 24;
    data.N  = 2;
    data.G  = 8;
    data.dt = 1;

    data.regionName = {'区域1：送端区域', '区域3：送端区域'};

    %% ===================== 1) 本地负荷与固定外送 =========================
    loadR1_24 = [ ...
        4370 4270 4170 4120 4170 4370 ...
        4770 5170 5370 5570 5720 5870 ...
        5970 5920 5820 5720 5670 5770 ...
        5920 5870 5620 5270 4870 4570 ];

    loadR3_24 = [ ...
        4500 4300 4150 4000 3950 4100 ...
        4700 5300 5750 6100 6300 6000 ...
        5800 5500 5350 5900 6350 6500 ...
        6900 7700 7400 6100 5500 4700 ];

    poutR1_24 = 1730 * ones(1,24);
    poutR3_24 = 2300 * ones(1,24);

    loadFactorR1 = [0.96 1.20 1.14 0.97 1.10 0.90 0.85];
    loadFactorR3 = [1.04 0.98 0.95 1.16 1.15 0.92 0.82];

    data.LoadBase = zeros(data.N,data.T);
    data.PoutFix  = zeros(data.N,data.T);
    data.Load     = zeros(data.N,data.T);

    for d = 1:data.D
        idx = (d-1)*24 + (1:24);

        data.LoadBase(1,idx) = loadR1_24 * loadFactorR1(d);
        data.LoadBase(2,idx) = loadR3_24 * loadFactorR3(d);

        data.PoutFix(1,idx) = poutR1_24;
        data.PoutFix(2,idx) = poutR3_24;

        data.Load(1,idx) = data.LoadBase(1,idx) + data.PoutFix(1,idx);
        data.Load(2,idx) = data.LoadBase(2,idx) + data.PoutFix(2,idx);
    end

    %% ===================== 2) 风光可用出力 ===============================
    data.WindCap = [10500; 10000];
    data.PvCap   = [10500; 10000];

    pvR1_24 = [ ...
        0.000 0.000 0.000 0.000 0.000 0.000 ...
        0.002 0.053 0.197 0.397 0.606 0.755 ...
        0.840 0.867 0.843 0.790 0.737 0.613 ...
        0.465 0.296 0.131 0.023 0.001 0.000 ];

    windR1_24 = [ ...
        0.46 0.49 0.51 0.50 0.45 0.39 ...
        0.33 0.28 0.24 0.21 0.18 0.16 ...
        0.15 0.16 0.18 0.20 0.23 0.26 ...
        0.30 0.34 0.38 0.41 0.43 0.45 ];

    pvR3_24 = [ ...
        0.000 0.000 0.000 0.000 0.000 0.000 ...
        0.010 0.095 0.233 0.378 0.507 0.591 ...
        0.634 0.640 0.640 0.570 0.481 0.398 ...
        0.248 0.140 0.035 0.000 0.000 0.000 ];

    windR3_24 = [ ...
        0.24 0.25 0.26 0.26 0.25 0.24 ...
        0.26 0.30 0.34 0.38 0.40 0.42 ...
        0.40 0.37 0.34 0.32 0.34 0.38 ...
        0.42 0.44 0.40 0.34 0.29 0.26 ];

    pvFactorR1   = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];
    windFactorR1 = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];

    pvFactorR3   = [1.21 0.94 1.05 0.82 1.12 0.96 0.92];
    windFactorR3 = [1.21 0.94 1.05 0.82 1.12 0.96 0.92];

    data.WindAva = zeros(data.N,data.T);
    data.PvAva   = zeros(data.N,data.T);

    for d = 1:data.D
        idx = (d-1)*24 + (1:24);

        data.WindAva(1,idx) = data.WindCap(1) * min(max(windR1_24 * windFactorR1(d), 0), 1);
        data.PvAva(1,idx)   = data.PvCap(1)   * min(max(pvR1_24   * pvFactorR1(d),   0), 1);

        data.WindAva(2,idx) = data.WindCap(2) * min(max(windR3_24 * windFactorR3(d), 0), 1);
        data.PvAva(2,idx)   = data.PvCap(2)   * min(max(pvR3_24   * pvFactorR3(d),   0), 1);
    end

    %% ===================== 3) 火电机组参数 ===============================
    G = data.G;

    data.Pmax = zeros(data.N,G);
    data.Pmin = zeros(data.N,G);
    data.RU   = zeros(data.N,G);
    data.RD   = zeros(data.N,G);
    data.SU   = zeros(data.N,G);
    data.SD   = zeros(data.N,G);

    data.MinUp   = zeros(data.N,G);
    data.MinDown = zeros(data.N,G);

    data.Cvar   = zeros(data.N,G);
    data.Cfix   = zeros(data.N,G);
    data.Cstart = zeros(data.N,G);
    data.Cshut  = zeros(data.N,G);

    data.Pmax(1,:) = [1200 1200 1000 1000 800 800 660 500];
    data.Pmin(1,:) = [480  480  400  400  320 320 264 200];

    data.Pmax(2,:) = [800 800 660 660 500 330 300 150];
    data.Pmin(2,:) = [320 320 264 264 200 132 120 60];

    data.RU(1,:) = [260 260 230 230 190 190 150 120];
    data.RU(2,:) = [190 190 150 150 120 90 80 50];

    data.RD = data.RU;
    data.SU = data.Pmax;
    data.SD = data.Pmax;

    data.MinUp(1,:)   = [4 4 3 3 3 3 2 2];
    data.MinDown(1,:) = [4 4 3 3 3 3 2 2];

    data.MinUp(2,:)   = [4 4 3 3 3 2 2 1];
    data.MinDown(2,:) = [4 4 3 3 3 2 2 1];

    data.MinOnline = [3; 2];

    data.Cvar(1,:) = [210 215 230 235 250 255 280 300];
    data.Cvar(2,:) = [210 215 230 235 250 270 285 320];

    data.Cfix(1,:) = [12000 12000 9500 9500 7000 7000 3500 3000];
    data.Cfix(2,:) = [8000 8000 6000 6000 4200 3000 2500 1200];

    data.Cstart(1,:) = [90000 90000 65000 65000 42000 42000 18000 15000];
    data.Cstart(2,:) = [65000 65000 42000 42000 25000 15000 12000 6000];

    data.Cshut(1,:) = [30000 30000 22000 22000 15000 15000 7000 6000];
    data.Cshut(2,:) = [22000 22000 15000 15000 9000 6000 5000 3000];

    data.u0 = zeros(data.N,G);
    data.u0(1,:) = [1 1 1 1 1 0 0 0];
    data.u0(2,:) = [1 1 1 1 0 0 0 0];

    data.P0 = data.u0 .* data.Pmin;

    %% ===================== 4) 电化学储能参数 =============================
    data.ES_Pmax = [2100; 2000];
    data.ES_Emax = [4200; 4000];
    data.ES_Emin = 0.10 * data.ES_Emax;
    data.ES_E0   = 0.50 * data.ES_Emax;

    data.ES_eta_ch  = [0.95; 0.95];
    data.ES_eta_dis = [0.95; 0.95];
    data.ES_cost    = [20; 20];

    data.ES_DailyCycle = 1;

    %% ===================== 5) 抽水蓄能参数 ===============================
    data.PS_Pgen_max  = [1000; 1000];
    data.PS_Ppump_max = [1000; 1000];
    data.PS_Emax      = [4000; 4000];
    data.PS_Emin      = 0.10 * data.PS_Emax;
    data.PS_E0        = 0.50 * data.PS_Emax;

    data.PS_eta_pump = [0.90; 0.90];
    data.PS_eta_gen  = [0.90; 0.90];
    data.PS_cost     = [15; 15];
    data.PS_Ramp     = [1000; 1000];

    data.PS_DailyCycle = 0;

    %% ===================== 6) 区域间互补联络线 ===========================
    data.TieMax  = 1800;
    data.TieRamp = 600;
    data.TieCost = 3;

    %% ===================== 7) 惩罚系数与备用需求 =========================
    data.VOLL               = 30000;
    data.ReservePenalty     = 12000;
    data.DownReservePenalty = 8000;

    data.CurtWind = 500;
    data.CurtPv   = 500;

    data.ReserveReq = max(0.10 * data.Load, ...
                          0.15 * (data.WindAva + data.PvAva));

    data.DownReserveReq = max(0.05 * data.Load, ...
                              0.10 * (data.WindAva + data.PvAva));
end


%% ========================================================================
%% 函数2：单区域独立优化
%% ========================================================================
function result = solveUC_oneRegion(data, n)

    T  = data.T;
    G  = data.G;
    dt = data.dt;

    u = binvar(G,T,'full');
    y = binvar(G,T,'full');
    z = binvar(G,T,'full');
    P = sdpvar(G,T,'full');

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

    %% ---------------------- 火电约束 ------------------------------------
    for t = 1:T
        C = [C, data.Pmin(n,:)' .* u(:,t) <= P(:,t) <= data.Pmax(n,:)' .* u(:,t)];
        C = [C, sum(u(:,t)) >= data.MinOnline(n)];
    end

    C = [C, y(:,1) - z(:,1) == u(:,1) - data.u0(n,:)'];
    C = [C, y(:,1) + z(:,1) <= 1];

    for t = 2:T
        C = [C, y(:,t) - z(:,t) == u(:,t) - u(:,t-1)];
        C = [C, y(:,t) + z(:,t) <= 1];
    end

    C = [C, P(:,1) - data.P0(n,:)' <= ...
        data.RU(n,:)' .* data.u0(n,:)' + data.SU(n,:)' .* y(:,1)];

    C = [C, data.P0(n,:)' - P(:,1) <= ...
        data.RD(n,:)' .* u(:,1) + data.SD(n,:)' .* z(:,1)];

    for t = 2:T
        C = [C, P(:,t) - P(:,t-1) <= ...
            data.RU(n,:)' .* u(:,t-1) + data.SU(n,:)' .* y(:,t)];

        C = [C, P(:,t-1) - P(:,t) <= ...
            data.RD(n,:)' .* u(:,t) + data.SD(n,:)' .* z(:,t)];
    end

    for g = 1:G
        Ton = data.MinUp(n,g);
        for t = 1:T
            tEnd = min(T, t + Ton - 1);
            C = [C, sum(u(g,t:tEnd)) >= (tEnd - t + 1) * y(g,t)];
        end
    end

    for g = 1:G
        Toff = data.MinDown(n,g);
        for t = 1:T
            tEnd = min(T, t + Toff - 1);
            C = [C, sum(1 - u(g,t:tEnd)) >= (tEnd - t + 1) * z(g,t)];
        end
    end

    %% ---------------------- 风光约束 ------------------------------------
    C = [C, 0 <= Pwind <= data.WindAva(n,:)];
    C = [C, 0 <= Ppv   <= data.PvAva(n,:)];

    %% ---------------------- 电化学储能 ----------------------------------
    C = [C, 0 <= Pch  <= data.ES_Pmax(n) .* uch];
    C = [C, 0 <= Pdis <= data.ES_Pmax(n) .* udis];
    C = [C, uch + udis <= 1];
    C = [C, data.ES_Emin(n) <= Ees <= data.ES_Emax(n)];

    if data.ES_DailyCycle == 1
        for d = 1:data.D
            tStart = (d-1)*24 + 1;
            tEnd   = d*24 + 1;
            C = [C, Ees(tStart) == data.ES_E0(n)];
            C = [C, Ees(tEnd)   == data.ES_E0(n)];
        end
    else
        C = [C, Ees(1) == data.ES_E0(n)];
        C = [C, Ees(T+1) == data.ES_E0(n)];
    end

    for t = 1:T
        C = [C, Ees(t+1) == Ees(t) ...
            + data.ES_eta_ch(n)  * Pch(t)  * dt ...
            - Pdis(t) / data.ES_eta_dis(n) * dt];
    end

    %% ---------------------- 抽水蓄能 ------------------------------------
    C = [C, 0 <= Pps_pump <= data.PS_Ppump_max(n) .* ups_pump];
    C = [C, 0 <= Pps_gen  <= data.PS_Pgen_max(n)  .* ups_gen];
    C = [C, ups_pump + ups_gen <= 1];
    C = [C, data.PS_Emin(n) <= Eps <= data.PS_Emax(n)];

    if data.PS_DailyCycle == 1
        for d = 1:data.D
            tStart = (d-1)*24 + 1;
            tEnd   = d*24 + 1;
            C = [C, Eps(tStart) == data.PS_E0(n)];
            C = [C, Eps(tEnd)   == data.PS_E0(n)];
        end
    else
        C = [C, Eps(1) == data.PS_E0(n)];
        C = [C, Eps(T+1) == data.PS_E0(n)];
    end

    for t = 1:T
        C = [C, Eps(t+1) == Eps(t) ...
            + data.PS_eta_pump(n) * Pps_pump(t) * dt ...
            - Pps_gen(t) / data.PS_eta_gen(n) * dt];
    end

    for t = 2:T
        C = [C, -data.PS_Ramp(n) <= Pps_pump(t)-Pps_pump(t-1) <= data.PS_Ramp(n)];
        C = [C, -data.PS_Ramp(n) <= Pps_gen(t)-Pps_gen(t-1) <= data.PS_Ramp(n)];
    end

    %% ---------------------- 松弛变量 ------------------------------------
    C = [C, 0 <= Pshed <= data.Load(n,:)];
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
            == data.Load(n,t)];
    end

    %% ---------------------- 正备用与负备用 ------------------------------
    for t = 1:T

        Rup_th = sum(data.Pmax(n,:)' .* u(:,t) - P(:,t));
        Rup_es = Pch(t) + (data.ES_Pmax(n) - Pdis(t));
        Rup_ps = Pps_pump(t) + (data.PS_Pgen_max(n) - Pps_gen(t));

        C = [C, Rup_th + Rup_es + Rup_ps + Rshort(t) >= data.ReserveReq(n,t)];

        Rdn_th = sum(P(:,t) - data.Pmin(n,:)' .* u(:,t));
        Rdn_es = Pdis(t) + (data.ES_Pmax(n) - Pch(t));
        Rdn_ps = Pps_gen(t) + (data.PS_Ppump_max(n) - Pps_pump(t));

        C = [C, Rdn_th + Rdn_es + Rdn_ps + RdownShort(t) >= data.DownReserveReq(n,t)];
    end

    %% ---------------------- 目标函数 ------------------------------------
    C_thermal = sum(sum( ...
        repmat(data.Cvar(n,:)',1,T)   .* P + ...
        repmat(data.Cfix(n,:)',1,T)   .* u + ...
        repmat(data.Cstart(n,:)',1,T) .* y + ...
        repmat(data.Cshut(n,:)',1,T)  .* z ));

    C_curt = data.CurtWind * sum(data.WindAva(n,:) - Pwind) * dt ...
           + data.CurtPv   * sum(data.PvAva(n,:)   - Ppv)   * dt;

    C_shed = data.VOLL * sum(Pshed) * dt;

    C_reserve = data.ReservePenalty     * sum(Rshort) * dt ...
              + data.DownReservePenalty * sum(RdownShort) * dt;

    C_es = data.ES_cost(n) * sum(Pch + Pdis) * dt;
    C_ps = data.PS_cost(n) * sum(Pps_pump + Pps_gen) * dt;

    objective = C_thermal + C_curt + C_shed + C_reserve + C_es + C_ps;

    ops = sdpsettings('solver','gurobi','verbose',1);
    ops.gurobi.MIPGap     = 1e-2;
    ops.gurobi.TimeLimit  = 900;
    ops.gurobi.MIPFocus   = 1;
    ops.gurobi.Heuristics = 0.20;

    sol = optimize(C, objective, ops);

    result.name = data.regionName{n};
    result.regionIndex = n;
    result.sol = sol;

    if ~(sol.problem == 0 || sol.problem == 3)
        result = fillFailedOneRegion(result, T, G);
        return;
    end

    result.obj = value(objective);

    result.P = value(P);
    result.u = value(u);
    result.y = value(y);
    result.z = value(z);

    result.Pwind = value(Pwind);
    result.Ppv   = value(Ppv);

    result.Pch  = value(Pch);
    result.Pdis = value(Pdis);
    result.Ees  = value(Ees);

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
    result.C_es      = value(C_es);
    result.C_ps      = value(C_ps);
    result.C_tie     = 0;

    result = calcOneRegionIndicators(data, n, result);
end


%% ========================================================================
%% 函数3：两区域互补协同联合优化
%% ========================================================================
function result = solveUC_jointTwoRegion(data)

    N  = data.N;
    G  = data.G;
    T  = data.T;
    dt = data.dt;

    u = cell(N,1);
    y = cell(N,1);
    z = cell(N,1);
    P = cell(N,1);

    for n = 1:N
        u{n} = binvar(G,T,'full');
        y{n} = binvar(G,T,'full');
        z{n} = binvar(G,T,'full');
        P{n} = sdpvar(G,T,'full');
    end

    Pwind = sdpvar(N,T,'full');
    Ppv   = sdpvar(N,T,'full');

    Pch  = sdpvar(N,T,'full');
    Pdis = sdpvar(N,T,'full');
    Ees  = sdpvar(N,T+1,'full');
    uch  = binvar(N,T,'full');
    udis = binvar(N,T,'full');

    Pps_pump = sdpvar(N,T,'full');
    Pps_gen  = sdpvar(N,T,'full');
    Eps      = sdpvar(N,T+1,'full');
    ups_pump = binvar(N,T,'full');
    ups_gen  = binvar(N,T,'full');

    Pshed      = sdpvar(N,T,'full');
    Rshort     = sdpvar(N,T,'full');
    RdownShort = sdpvar(N,T,'full');

    Ptie    = sdpvar(1,T,'full');
    PtieAbs = sdpvar(1,T,'full');

    C = [];

    %% ---------------------- 火电约束 ------------------------------------
    for n = 1:N

        for t = 1:T
            C = [C, data.Pmin(n,:)' .* u{n}(:,t) <= P{n}(:,t) <= data.Pmax(n,:)' .* u{n}(:,t)];
            C = [C, sum(u{n}(:,t)) >= data.MinOnline(n)];
        end

        C = [C, y{n}(:,1) - z{n}(:,1) == u{n}(:,1) - data.u0(n,:)'];
        C = [C, y{n}(:,1) + z{n}(:,1) <= 1];

        for t = 2:T
            C = [C, y{n}(:,t) - z{n}(:,t) == u{n}(:,t) - u{n}(:,t-1)];
            C = [C, y{n}(:,t) + z{n}(:,t) <= 1];
        end

        C = [C, P{n}(:,1) - data.P0(n,:)' <= ...
            data.RU(n,:)' .* data.u0(n,:)' + data.SU(n,:)' .* y{n}(:,1)];

        C = [C, data.P0(n,:)' - P{n}(:,1) <= ...
            data.RD(n,:)' .* u{n}(:,1) + data.SD(n,:)' .* z{n}(:,1)];

        for t = 2:T
            C = [C, P{n}(:,t) - P{n}(:,t-1) <= ...
                data.RU(n,:)' .* u{n}(:,t-1) + data.SU(n,:)' .* y{n}(:,t)];

            C = [C, P{n}(:,t-1) - P{n}(:,t) <= ...
                data.RD(n,:)' .* u{n}(:,t) + data.SD(n,:)' .* z{n}(:,t)];
        end

        for g = 1:G
            Ton = data.MinUp(n,g);
            for t = 1:T
                tEnd = min(T, t + Ton - 1);
                C = [C, sum(u{n}(g,t:tEnd)) >= (tEnd - t + 1) * y{n}(g,t)];
            end
        end

        for g = 1:G
            Toff = data.MinDown(n,g);
            for t = 1:T
                tEnd = min(T, t + Toff - 1);
                C = [C, sum(1 - u{n}(g,t:tEnd)) >= (tEnd - t + 1) * z{n}(g,t)];
            end
        end
    end

    %% ---------------------- 风光约束 ------------------------------------
    C = [C, 0 <= Pwind <= data.WindAva];
    C = [C, 0 <= Ppv   <= data.PvAva];

    %% ---------------------- 储能与抽蓄约束 -------------------------------
    for n = 1:N

        C = [C, 0 <= Pch(n,:)  <= data.ES_Pmax(n) .* uch(n,:)];
        C = [C, 0 <= Pdis(n,:) <= data.ES_Pmax(n) .* udis(n,:)];
        C = [C, uch(n,:) + udis(n,:) <= 1];
        C = [C, data.ES_Emin(n) <= Ees(n,:) <= data.ES_Emax(n)];

        if data.ES_DailyCycle == 1
            for d = 1:data.D
                tStart = (d-1)*24 + 1;
                tEnd   = d*24 + 1;
                C = [C, Ees(n,tStart) == data.ES_E0(n)];
                C = [C, Ees(n,tEnd)   == data.ES_E0(n)];
            end
        else
            C = [C, Ees(n,1) == data.ES_E0(n)];
            C = [C, Ees(n,T+1) == data.ES_E0(n)];
        end

        for t = 1:T
            C = [C, Ees(n,t+1) == Ees(n,t) ...
                + data.ES_eta_ch(n)  * Pch(n,t)  * dt ...
                - Pdis(n,t) / data.ES_eta_dis(n) * dt];
        end

        C = [C, 0 <= Pps_pump(n,:) <= data.PS_Ppump_max(n) .* ups_pump(n,:)];
        C = [C, 0 <= Pps_gen(n,:)  <= data.PS_Pgen_max(n)  .* ups_gen(n,:)];
        C = [C, ups_pump(n,:) + ups_gen(n,:) <= 1];
        C = [C, data.PS_Emin(n) <= Eps(n,:) <= data.PS_Emax(n)];

        if data.PS_DailyCycle == 1
            for d = 1:data.D
                tStart = (d-1)*24 + 1;
                tEnd   = d*24 + 1;
                C = [C, Eps(n,tStart) == data.PS_E0(n)];
                C = [C, Eps(n,tEnd)   == data.PS_E0(n)];
            end
        else
            C = [C, Eps(n,1) == data.PS_E0(n)];
            C = [C, Eps(n,T+1) == data.PS_E0(n)];
        end

        for t = 1:T
            C = [C, Eps(n,t+1) == Eps(n,t) ...
                + data.PS_eta_pump(n) * Pps_pump(n,t) * dt ...
                - Pps_gen(n,t) / data.PS_eta_gen(n) * dt];
        end

        for t = 2:T
            C = [C, -data.PS_Ramp(n) <= Pps_pump(n,t)-Pps_pump(n,t-1) <= data.PS_Ramp(n)];
            C = [C, -data.PS_Ramp(n) <= Pps_gen(n,t)-Pps_gen(n,t-1) <= data.PS_Ramp(n)];
        end
    end

    %% ---------------------- 联络线约束 ----------------------------------
    C = [C, -data.TieMax <= Ptie <= data.TieMax];

    for t = 2:T
        C = [C, -data.TieRamp <= Ptie(t)-Ptie(t-1) <= data.TieRamp];
    end

    C = [C, PtieAbs >= Ptie];
    C = [C, PtieAbs >= -Ptie];
    C = [C, PtieAbs >= 0];

    %% ---------------------- 松弛变量 ------------------------------------
    C = [C, 0 <= Pshed <= data.Load];
    C = [C, Rshort >= 0];
    C = [C, RdownShort >= 0];

    %% ---------------------- 功率平衡 ------------------------------------
    for t = 1:T

        C = [C, ...
            sum(P{1}(:,t)) ...
            + Pwind(1,t) + Ppv(1,t) ...
            + Pdis(1,t) - Pch(1,t) ...
            + Pps_gen(1,t) - Pps_pump(1,t) ...
            - Ptie(t) ...
            + Pshed(1,t) ...
            == data.Load(1,t)];

        C = [C, ...
            sum(P{2}(:,t)) ...
            + Pwind(2,t) + Ppv(2,t) ...
            + Pdis(2,t) - Pch(2,t) ...
            + Pps_gen(2,t) - Pps_pump(2,t) ...
            + Ptie(t) ...
            + Pshed(2,t) ...
            == data.Load(2,t)];
    end

    %% ---------------------- 正备用与负备用 ------------------------------
    for n = 1:N
        for t = 1:T

            Rup_th = sum(data.Pmax(n,:)' .* u{n}(:,t) - P{n}(:,t));
            Rup_es = Pch(n,t) + (data.ES_Pmax(n) - Pdis(n,t));
            Rup_ps = Pps_pump(n,t) + (data.PS_Pgen_max(n) - Pps_gen(n,t));

            C = [C, Rup_th + Rup_es + Rup_ps + Rshort(n,t) >= data.ReserveReq(n,t)];

            Rdn_th = sum(P{n}(:,t) - data.Pmin(n,:)' .* u{n}(:,t));
            Rdn_es = Pdis(n,t) + (data.ES_Pmax(n) - Pch(n,t));
            Rdn_ps = Pps_gen(n,t) + (data.PS_Ppump_max(n) - Pps_pump(n,t));

            C = [C, Rdn_th + Rdn_es + Rdn_ps + RdownShort(n,t) >= data.DownReserveReq(n,t)];
        end
    end

    %% ---------------------- 目标函数 ------------------------------------
    C_thermal_region = cell(N,1);
    C_curt_region    = cell(N,1);
    C_shed_region    = cell(N,1);
    C_reserve_region = cell(N,1);
    C_es_region      = cell(N,1);
    C_ps_region      = cell(N,1);

    objective = 0;

    for n = 1:N

        C_thermal_region{n} = sum(sum( ...
            repmat(data.Cvar(n,:)',1,T)   .* P{n} + ...
            repmat(data.Cfix(n,:)',1,T)   .* u{n} + ...
            repmat(data.Cstart(n,:)',1,T) .* y{n} + ...
            repmat(data.Cshut(n,:)',1,T)  .* z{n} ));

        C_curt_region{n} = ...
            data.CurtWind * sum(data.WindAva(n,:) - Pwind(n,:)) * dt + ...
            data.CurtPv   * sum(data.PvAva(n,:)   - Ppv(n,:))   * dt;

        C_shed_region{n} = data.VOLL * sum(Pshed(n,:)) * dt;

        C_reserve_region{n} = ...
            data.ReservePenalty     * sum(Rshort(n,:))     * dt + ...
            data.DownReservePenalty * sum(RdownShort(n,:)) * dt;

        C_es_region{n} = data.ES_cost(n) * sum(Pch(n,:) + Pdis(n,:)) * dt;
        C_ps_region{n} = data.PS_cost(n) * sum(Pps_pump(n,:) + Pps_gen(n,:)) * dt;

        objective = objective + C_thermal_region{n} + C_curt_region{n} + ...
                    C_shed_region{n} + C_reserve_region{n} + ...
                    C_es_region{n} + C_ps_region{n};
    end

    C_tie = data.TieCost * sum(PtieAbs) * dt;

    objective = objective + C_tie;

    ops = sdpsettings('solver','gurobi','verbose',1);
    ops.gurobi.MIPGap     = 1e-2;
    ops.gurobi.TimeLimit  = 900;
    ops.gurobi.MIPFocus   = 1;
    ops.gurobi.Heuristics = 0.20;

    sol = optimize(C, objective, ops);

    result.name = 'S1 两区域互补协同：区域1与区域3联络互济';
    result.sol  = sol;

    if ~(sol.problem == 0 || sol.problem == 3)
        result = fillFailedTwoRegion(result, T, G);
        return;
    end

    result.obj = value(objective);

    result.P = cell(N,1);
    result.u = cell(N,1);
    result.y = cell(N,1);
    result.z = cell(N,1);

    for n = 1:N
        result.P{n} = value(P{n});
        result.u{n} = value(u{n});
        result.y{n} = value(y{n});
        result.z{n} = value(z{n});
    end

    result.Pwind = value(Pwind);
    result.Ppv   = value(Ppv);

    result.Pch  = value(Pch);
    result.Pdis = value(Pdis);
    result.Ees  = value(Ees);

    result.Pps_pump = value(Pps_pump);
    result.Pps_gen  = value(Pps_gen);
    result.Eps      = value(Eps);

    result.Pshed      = value(Pshed);
    result.Rshort     = value(Rshort);
    result.RdownShort = value(RdownShort);

    result.Ptie    = value(Ptie);
    result.PtieAbs = value(PtieAbs);

    result.C_thermal_region = zeros(N,1);
    result.C_curt_region    = zeros(N,1);
    result.C_shed_region    = zeros(N,1);
    result.C_reserve_region = zeros(N,1);
    result.C_es_region      = zeros(N,1);
    result.C_ps_region      = zeros(N,1);

    for n = 1:N
        result.C_thermal_region(n) = value(C_thermal_region{n});
        result.C_curt_region(n)    = value(C_curt_region{n});
        result.C_shed_region(n)    = value(C_shed_region{n});
        result.C_reserve_region(n) = value(C_reserve_region{n});
        result.C_es_region(n)      = value(C_es_region{n});
        result.C_ps_region(n)      = value(C_ps_region{n});
    end

    result.C_tie = value(C_tie);

    result.C_thermal = sum(result.C_thermal_region);
    result.C_curt    = sum(result.C_curt_region);
    result.C_shed    = sum(result.C_shed_region);
    result.C_reserve = sum(result.C_reserve_region);
    result.C_es      = sum(result.C_es_region);
    result.C_ps      = sum(result.C_ps_region);

    result = calcTwoRegionIndicators(data, result);
end


%% ========================================================================
%% 函数4：合并独立优化结果
%% ========================================================================
function result = combineIndependentResults(data, res1, res3)

    T = data.T;
    N = data.N;

    result.name = 'S0 无互补协同：区域1、区域3分别单区域多能互补';
    result.sol.problem = max(res1.sol.problem, res3.sol.problem);

    if ~(isAcceptableSol(res1) && isAcceptableSol(res3))
        result = fillFailedTwoRegion(result, data.T, data.G);
        return;
    end

    result.P = cell(N,1);
    result.u = cell(N,1);
    result.y = cell(N,1);
    result.z = cell(N,1);

    result.P{1} = res1.P;
    result.P{2} = res3.P;

    result.u{1} = res1.u;
    result.u{2} = res3.u;

    result.y{1} = res1.y;
    result.y{2} = res3.y;

    result.z{1} = res1.z;
    result.z{2} = res3.z;

    result.Pwind = [res1.Pwind; res3.Pwind];
    result.Ppv   = [res1.Ppv;   res3.Ppv];

    result.Pch  = [res1.Pch;  res3.Pch];
    result.Pdis = [res1.Pdis; res3.Pdis];
    result.Ees  = [res1.Ees;  res3.Ees];

    result.Pps_pump = [res1.Pps_pump; res3.Pps_pump];
    result.Pps_gen  = [res1.Pps_gen;  res3.Pps_gen];
    result.Eps      = [res1.Eps;      res3.Eps];

    result.Pshed      = [res1.Pshed;      res3.Pshed];
    result.Rshort     = [res1.Rshort;     res3.Rshort];
    result.RdownShort = [res1.RdownShort; res3.RdownShort];

    result.Ptie    = zeros(1,T);
    result.PtieAbs = zeros(1,T);

    result.C_thermal_region = [res1.C_thermal; res3.C_thermal];
    result.C_curt_region    = [res1.C_curt;    res3.C_curt];
    result.C_shed_region    = [res1.C_shed;    res3.C_shed];
    result.C_reserve_region = [res1.C_reserve; res3.C_reserve];
    result.C_es_region      = [res1.C_es;      res3.C_es];
    result.C_ps_region      = [res1.C_ps;      res3.C_ps];

    result.C_tie = 0;

    result.C_thermal = sum(result.C_thermal_region);
    result.C_curt    = sum(result.C_curt_region);
    result.C_shed    = sum(result.C_shed_region);
    result.C_reserve = sum(result.C_reserve_region);
    result.C_es      = sum(result.C_es_region);
    result.C_ps      = sum(result.C_ps_region);

    result.obj = result.C_thermal + result.C_curt + result.C_shed + ...
                 result.C_reserve + result.C_es + result.C_ps;

    result = calcTwoRegionIndicators(data, result);
end


%% ========================================================================
%% 函数5：单区域指标
%% ========================================================================
function result = calcOneRegionIndicators(data, n, result)

    dt = data.dt;

    windCurt = data.WindAva(n,:) - result.Pwind;
    pvCurt   = data.PvAva(n,:)   - result.Ppv;

    windCurt(abs(windCurt) < 1e-6) = 0;
    pvCurt(abs(pvCurt) < 1e-6) = 0;

    result.EENS_MWh = sum(result.Pshed) * dt;
    result.LoadEnergy_MWh = sum(data.Load(n,:)) * dt;
    result.LoadSheddingRate_percent = 100 * result.EENS_MWh / max(1e-6, result.LoadEnergy_MWh);

    result.LOLH_h = sum(result.Pshed > 1e-4);
    result.MaxShed_MW = max(result.Pshed);

    result.ReserveShort_MWh = sum(result.Rshort) * dt;
    result.ReserveShortHours_h = sum(result.Rshort > 1e-4);

    result.DownReserveShort_MWh = sum(result.RdownShort) * dt;
    result.DownReserveShortHours_h = sum(result.RdownShort > 1e-4);

    result.WindCurtail_MWh = sum(windCurt) * dt;
    result.PvCurtail_MWh   = sum(pvCurt)   * dt;
    result.TotalCurtail_MWh = result.WindCurtail_MWh + result.PvCurtail_MWh;

    result.WindCurtailRate_percent = ...
        100 * result.WindCurtail_MWh / max(1e-6, sum(data.WindAva(n,:)) * dt);

    result.PvCurtailRate_percent = ...
        100 * result.PvCurtail_MWh / max(1e-6, sum(data.PvAva(n,:)) * dt);

    result.CurtailRate_percent = ...
        100 * result.TotalCurtail_MWh / ...
        max(1e-6, sum(data.WindAva(n,:) + data.PvAva(n,:)) * dt);

    result.RE_Utilization_percent = ...
        100 * sum(result.Pwind + result.Ppv) * dt / ...
        max(1e-6, sum(data.WindAva(n,:) + data.PvAva(n,:)) * dt);

    %% ---------------------- 新能源渗透率指标 ----------------------------
    result.RE_Consumed_MWh = sum(result.Pwind + result.Ppv) * dt;
    result.ThermalGen_MWh = sum(sum(result.P)) * dt;
    result.TotalLoad_MWh = sum(data.Load(n,:)) * dt;
    result.BaseLoad_MWh = sum(data.LoadBase(n,:)) * dt;
    result.ExportLoad_MWh = sum(data.PoutFix(n,:)) * dt;

    result.ThermalShare_percent = ...
        100 * result.ThermalGen_MWh / max(1e-6, result.TotalLoad_MWh);

    result.RE_Penetration_percent = ...
        100 * (1 - result.ThermalGen_MWh / max(1e-6, result.TotalLoad_MWh));

    result.ESCharge_MWh = sum(result.Pch) * dt;
    result.ESDischarge_MWh = sum(result.Pdis) * dt;
    result.PSHPump_MWh = sum(result.Pps_pump) * dt;
    result.PSHGen_MWh  = sum(result.Pps_gen)  * dt;
    result.StartupTimes = sum(sum(result.y));
end


%% ========================================================================
%% 函数6：两区域指标
%% ========================================================================
function result = calcTwoRegionIndicators(data, result)

    dt = data.dt;

    windCurt = data.WindAva - result.Pwind;
    pvCurt   = data.PvAva   - result.Ppv;

    windCurt(abs(windCurt) < 1e-6) = 0;
    pvCurt(abs(pvCurt) < 1e-6) = 0;

    result.EENS_region_MWh = sum(result.Pshed,2) * dt;
    result.LoadEnergy_region_MWh = sum(data.Load,2) * dt;

    result.LoadSheddingRate_region_percent = ...
        100 * result.EENS_region_MWh ./ max(1e-6, result.LoadEnergy_region_MWh);

    result.LOLH_region_h = sum(result.Pshed > 1e-4, 2);
    result.MaxShed_region_MW = max(result.Pshed, [], 2);

    result.ReserveShort_region_MWh = sum(result.Rshort,2) * dt;
    result.ReserveShortHours_region_h = sum(result.Rshort > 1e-4, 2);

    result.DownReserveShort_region_MWh = sum(result.RdownShort,2) * dt;
    result.DownReserveShortHours_region_h = sum(result.RdownShort > 1e-4, 2);

    result.WindCurtail_region_MWh = sum(windCurt,2) * dt;
    result.PvCurtail_region_MWh   = sum(pvCurt,2)   * dt;
    result.TotalCurtail_region_MWh = result.WindCurtail_region_MWh + result.PvCurtail_region_MWh;

    result.WindCurtailRate_region_percent = ...
        100 * result.WindCurtail_region_MWh ./ max(1e-6, sum(data.WindAva,2) * dt);

    result.PvCurtailRate_region_percent = ...
        100 * result.PvCurtail_region_MWh ./ max(1e-6, sum(data.PvAva,2) * dt);

    result.CurtailRate_region_percent = ...
        100 * result.TotalCurtail_region_MWh ./ ...
        max(1e-6, sum(data.WindAva + data.PvAva,2) * dt);

    result.RE_Utilization_region_percent = ...
        100 * sum(result.Pwind + result.Ppv,2) * dt ./ ...
        max(1e-6, sum(data.WindAva + data.PvAva,2) * dt);

    result.EENS_total_MWh = sum(result.EENS_region_MWh);
    result.LoadEnergy_total_MWh = sum(result.LoadEnergy_region_MWh);

    result.LoadSheddingRate_percent = ...
        100 * result.EENS_total_MWh / max(1e-6, result.LoadEnergy_total_MWh);

    result.LOLH_total_h = sum(sum(result.Pshed,1) > 1e-4);
    result.MaxShed_total_MW = max(sum(result.Pshed,1));

    result.ReserveShort_total_MWh = sum(result.ReserveShort_region_MWh);
    result.ReserveShortHours_total_h = sum(sum(result.Rshort,1) > 1e-4);

    result.DownReserveShort_total_MWh = sum(result.DownReserveShort_region_MWh);
    result.DownReserveShortHours_total_h = sum(sum(result.RdownShort,1) > 1e-4);

    result.TotalCurtail_MWh = sum(result.TotalCurtail_region_MWh);
    result.WindCurtail_MWh  = sum(result.WindCurtail_region_MWh);
    result.PvCurtail_MWh    = sum(result.PvCurtail_region_MWh);

    result.CurtailRate_percent = ...
        100 * result.TotalCurtail_MWh / ...
        max(1e-6, sum(sum(data.WindAva + data.PvAva)) * dt);

    result.WindCurtailRate_percent = ...
        100 * result.WindCurtail_MWh / max(1e-6, sum(sum(data.WindAva)) * dt);

    result.PvCurtailRate_percent = ...
        100 * result.PvCurtail_MWh / max(1e-6, sum(sum(data.PvAva)) * dt);

    result.RE_Utilization_percent = ...
        100 * sum(sum(result.Pwind + result.Ppv)) * dt / ...
        max(1e-6, sum(sum(data.WindAva + data.PvAva)) * dt);

    %% ---------------------- 新能源渗透率指标 ----------------------------
    result.RE_Consumed_region_MWh = sum(result.Pwind + result.Ppv, 2) * dt;

    result.ThermalGen_region_MWh = zeros(2,1);
    for n = 1:2
        result.ThermalGen_region_MWh(n) = sum(sum(result.P{n})) * dt;
    end

    result.TotalLoad_region_MWh = sum(data.Load, 2) * dt;
    result.BaseLoad_region_MWh = sum(data.LoadBase, 2) * dt;
    result.ExportLoad_region_MWh = sum(data.PoutFix, 2) * dt;

    result.ThermalShare_region_percent = ...
        100 * result.ThermalGen_region_MWh ./ ...
        max(1e-6, result.TotalLoad_region_MWh);

    result.RE_Penetration_region_percent = ...
        100 * (1 - result.ThermalGen_region_MWh ./ ...
        max(1e-6, result.TotalLoad_region_MWh));

    result.RE_Consumed_total_MWh = sum(result.RE_Consumed_region_MWh);
    result.ThermalGen_total_MWh = sum(result.ThermalGen_region_MWh);
    result.TotalLoad_total_MWh = sum(result.TotalLoad_region_MWh);
    result.BaseLoad_total_MWh = sum(result.BaseLoad_region_MWh);
    result.ExportLoad_total_MWh = sum(result.ExportLoad_region_MWh);

    result.ThermalShare_percent = ...
        100 * result.ThermalGen_total_MWh / ...
        max(1e-6, result.TotalLoad_total_MWh);

    result.RE_Penetration_percent = ...
        100 * (1 - result.ThermalGen_total_MWh / ...
        max(1e-6, result.TotalLoad_total_MWh));

    %% ---------------------- 区域互济与资源调用指标 ----------------------
    result.TieAbsEnergy_MWh = sum(abs(result.Ptie)) * dt;
    result.TieMaxUse_MW = max(abs(result.Ptie));
    result.TieUtilization_percent = ...
        100 * result.TieAbsEnergy_MWh / max(1e-6, data.TieMax * data.T * dt);

    result.ESCharge_region_MWh = sum(result.Pch,2) * dt;
    result.ESDischarge_region_MWh = sum(result.Pdis,2) * dt;

    result.PSHPump_region_MWh = sum(result.Pps_pump,2) * dt;
    result.PSHGen_region_MWh  = sum(result.Pps_gen,2)  * dt;

    result.ESCharge_MWh = sum(result.ESCharge_region_MWh);
    result.ESDischarge_MWh = sum(result.ESDischarge_region_MWh);

    result.PSHPump_MWh = sum(result.PSHPump_region_MWh);
    result.PSHGen_MWh  = sum(result.PSHGen_region_MWh);

    result.StartupTimes_region = zeros(2,1);
    for n = 1:2
        result.StartupTimes_region(n) = sum(sum(result.y{n}));
    end
    result.StartupTimes = sum(result.StartupTimes_region);
end


%% ========================================================================
%% 函数7：打印场景结果
%% ========================================================================
function printResult_twoRegion(result)

    fprintf('\n-------------------- 场景结果：%s --------------------\n', result.name);

    fprintf('\n成本指标：\n');
    fprintf('总运行成本：%.2f 万元\n', result.obj/1e4);

    for n = 1:2
        localCost = result.C_thermal_region(n) + result.C_curt_region(n) + ...
                    result.C_shed_region(n) + result.C_reserve_region(n) + ...
                    result.C_es_region(n) + result.C_ps_region(n);

        fprintf('%s 运行成本：%.2f 万元\n', resultRegionName(n), localCost/1e4);
    end

    fprintf('区域互补联络线成本：%.2f 万元\n', result.C_tie/1e4);

    fprintf('\n可靠性指标：\n');
    fprintf('两区域总 EENS：%.2f MWh\n', result.EENS_total_MWh);
    fprintf('两区域总切负荷率：%.4f %%\n', result.LoadSheddingRate_percent);

    for n = 1:2
        fprintf('%s EENS：%.2f MWh，切负荷率：%.4f %%，LOLH：%.0f h，最大失负荷：%.2f MW\n', ...
            resultRegionName(n), ...
            result.EENS_region_MWh(n), ...
            result.LoadSheddingRate_region_percent(n), ...
            result.LOLH_region_h(n), ...
            result.MaxShed_region_MW(n));
    end

    fprintf('两区域总正备用不足：%.2f MWh\n', result.ReserveShort_total_MWh);
    fprintf('两区域总负备用不足：%.2f MWh\n', result.DownReserveShort_total_MWh);

    for n = 1:2
        fprintf('%s 正备用不足：%.2f MWh，负备用不足：%.2f MWh\n', ...
            resultRegionName(n), ...
            result.ReserveShort_region_MWh(n), ...
            result.DownReserveShort_region_MWh(n));
    end

    fprintf('\n新能源消纳指标：\n');
    fprintf('两区域总弃风弃光电量：%.2f MWh\n', result.TotalCurtail_MWh);
    fprintf('两区域总弃风弃光率：%.2f %%\n', result.CurtailRate_percent);
    fprintf('两区域总弃风电量：%.2f MWh，弃风率：%.2f %%\n', ...
        result.WindCurtail_MWh, result.WindCurtailRate_percent);
    fprintf('两区域总弃光电量：%.2f MWh，弃光率：%.2f %%\n', ...
        result.PvCurtail_MWh, result.PvCurtailRate_percent);
    fprintf('两区域新能源消纳率：%.2f %%\n', result.RE_Utilization_percent);

    fprintf('\n新能源渗透率指标：\n');
    fprintf('两区域新能源消纳电量：%.2f MWh\n', result.RE_Consumed_total_MWh);
    fprintf('两区域火电发电量：%.2f MWh\n', result.ThermalGen_total_MWh);
    fprintf('两区域总负荷量：%.2f MWh\n', result.TotalLoad_total_MWh);
    fprintf('其中：本地负荷电量 %.2f MWh，固定外送电量 %.2f MWh\n', ...
        result.BaseLoad_total_MWh, result.ExportLoad_total_MWh);
    fprintf('两区域火电供电占比：%.2f %%\n', result.ThermalShare_percent);
    fprintf('两区域新能源渗透率，按1-火电/总负荷计算：%.2f %%\n', ...
        result.RE_Penetration_percent);

    for n = 1:2
        fprintf('%s 新能源消纳电量：%.2f MWh，火电发电量：%.2f MWh，总负荷量：%.2f MWh\n', ...
            resultRegionName(n), ...
            result.RE_Consumed_region_MWh(n), ...
            result.ThermalGen_region_MWh(n), ...
            result.TotalLoad_region_MWh(n));

        fprintf('%s 火电供电占比：%.2f %%，新能源渗透率：%.2f %%\n', ...
            resultRegionName(n), ...
            result.ThermalShare_region_percent(n), ...
            result.RE_Penetration_region_percent(n));
    end

    fprintf('\n分区域新能源消纳指标：\n');
    for n = 1:2
        fprintf('%s 弃风弃光电量：%.2f MWh，弃风弃光率：%.2f %%\n', ...
            resultRegionName(n), ...
            result.TotalCurtail_region_MWh(n), ...
            result.CurtailRate_region_percent(n));

        fprintf('  其中：弃风 %.2f MWh，弃风率 %.2f %%；弃光 %.2f MWh，弃光率 %.2f %%；新能源消纳率 %.2f %%\n', ...
            result.WindCurtail_region_MWh(n), ...
            result.WindCurtailRate_region_percent(n), ...
            result.PvCurtail_region_MWh(n), ...
            result.PvCurtailRate_region_percent(n), ...
            result.RE_Utilization_region_percent(n));
    end

    fprintf('\n区域互济指标：\n');
    fprintf('联络线绝对交换电量：%.2f MWh\n', result.TieAbsEnergy_MWh);
    fprintf('联络线最大使用功率：%.2f MW\n', result.TieMaxUse_MW);
    fprintf('联络线利用率：%.2f %%\n', result.TieUtilization_percent);
end


%% ========================================================================
%% 函数8：场景汇总表
%% ========================================================================
function summaryTable = makeSummary_twoRegion(Results)

    nCase = length(Results);

    Scenario = strings(nCase,1);

    TotalCost_yuan = nan(nCase,1);
    Cost_R1_yuan = nan(nCase,1);
    Cost_R3_yuan = nan(nCase,1);
    TieCost_yuan = nan(nCase,1);

    EENS_total_MWh = nan(nCase,1);
    EENS_R1_MWh = nan(nCase,1);
    EENS_R3_MWh = nan(nCase,1);

    LoadSheddingRate_total_percent = nan(nCase,1);
    LoadSheddingRate_R1_percent = nan(nCase,1);
    LoadSheddingRate_R3_percent = nan(nCase,1);

    ReserveShort_total_MWh = nan(nCase,1);
    ReserveShort_R1_MWh = nan(nCase,1);
    ReserveShort_R3_MWh = nan(nCase,1);

    DownReserveShort_total_MWh = nan(nCase,1);
    DownReserveShort_R1_MWh = nan(nCase,1);
    DownReserveShort_R3_MWh = nan(nCase,1);

    CurtailRate_total_percent = nan(nCase,1);
    CurtailRate_R1_percent = nan(nCase,1);
    CurtailRate_R3_percent = nan(nCase,1);

    WindCurtail_total_MWh = nan(nCase,1);
    WindCurtail_R1_MWh = nan(nCase,1);
    WindCurtail_R3_MWh = nan(nCase,1);

    PvCurtail_total_MWh = nan(nCase,1);
    PvCurtail_R1_MWh = nan(nCase,1);
    PvCurtail_R3_MWh = nan(nCase,1);

    WindCurtailRate_total_percent = nan(nCase,1);
    WindCurtailRate_R1_percent = nan(nCase,1);
    WindCurtailRate_R3_percent = nan(nCase,1);

    PvCurtailRate_total_percent = nan(nCase,1);
    PvCurtailRate_R1_percent = nan(nCase,1);
    PvCurtailRate_R3_percent = nan(nCase,1);

    RE_Utilization_total_percent = nan(nCase,1);
    RE_Utilization_R1_percent = nan(nCase,1);
    RE_Utilization_R3_percent = nan(nCase,1);

    RE_Consumed_total_MWh = nan(nCase,1);
    RE_Consumed_R1_MWh = nan(nCase,1);
    RE_Consumed_R3_MWh = nan(nCase,1);

    ThermalGen_total_MWh = nan(nCase,1);
    ThermalGen_R1_MWh = nan(nCase,1);
    ThermalGen_R3_MWh = nan(nCase,1);

    TotalLoad_total_MWh = nan(nCase,1);
    TotalLoad_R1_MWh = nan(nCase,1);
    TotalLoad_R3_MWh = nan(nCase,1);

    ThermalShare_total_percent = nan(nCase,1);
    ThermalShare_R1_percent = nan(nCase,1);
    ThermalShare_R3_percent = nan(nCase,1);

    RE_Penetration_total_percent = nan(nCase,1);
    RE_Penetration_R1_percent = nan(nCase,1);
    RE_Penetration_R3_percent = nan(nCase,1);

    TieAbsEnergy_MWh = nan(nCase,1);
    TieMaxUse_MW = nan(nCase,1);
    TieUtilization_percent = nan(nCase,1);

    Startup_R1_times = nan(nCase,1);
    Startup_R3_times = nan(nCase,1);

    ESDischarge_R1_MWh = nan(nCase,1);
    ESDischarge_R3_MWh = nan(nCase,1);

    PSHGen_R1_MWh = nan(nCase,1);
    PSHGen_R3_MWh = nan(nCase,1);

    for k = 1:nCase
        r = Results{k};

        Scenario(k) = string(r.name);

        TotalCost_yuan(k) = r.obj;

        Cost_R1_yuan(k) = r.C_thermal_region(1) + r.C_curt_region(1) + ...
                          r.C_shed_region(1) + r.C_reserve_region(1) + ...
                          r.C_es_region(1) + r.C_ps_region(1);

        Cost_R3_yuan(k) = r.C_thermal_region(2) + r.C_curt_region(2) + ...
                          r.C_shed_region(2) + r.C_reserve_region(2) + ...
                          r.C_es_region(2) + r.C_ps_region(2);

        TieCost_yuan(k) = r.C_tie;

        EENS_total_MWh(k) = r.EENS_total_MWh;
        EENS_R1_MWh(k) = r.EENS_region_MWh(1);
        EENS_R3_MWh(k) = r.EENS_region_MWh(2);

        LoadSheddingRate_total_percent(k) = r.LoadSheddingRate_percent;
        LoadSheddingRate_R1_percent(k) = r.LoadSheddingRate_region_percent(1);
        LoadSheddingRate_R3_percent(k) = r.LoadSheddingRate_region_percent(2);

        ReserveShort_total_MWh(k) = r.ReserveShort_total_MWh;
        ReserveShort_R1_MWh(k) = r.ReserveShort_region_MWh(1);
        ReserveShort_R3_MWh(k) = r.ReserveShort_region_MWh(2);

        DownReserveShort_total_MWh(k) = r.DownReserveShort_total_MWh;
        DownReserveShort_R1_MWh(k) = r.DownReserveShort_region_MWh(1);
        DownReserveShort_R3_MWh(k) = r.DownReserveShort_region_MWh(2);

        CurtailRate_total_percent(k) = r.CurtailRate_percent;
        CurtailRate_R1_percent(k) = r.CurtailRate_region_percent(1);
        CurtailRate_R3_percent(k) = r.CurtailRate_region_percent(2);

        WindCurtail_total_MWh(k) = r.WindCurtail_MWh;
        WindCurtail_R1_MWh(k) = r.WindCurtail_region_MWh(1);
        WindCurtail_R3_MWh(k) = r.WindCurtail_region_MWh(2);

        PvCurtail_total_MWh(k) = r.PvCurtail_MWh;
        PvCurtail_R1_MWh(k) = r.PvCurtail_region_MWh(1);
        PvCurtail_R3_MWh(k) = r.PvCurtail_region_MWh(2);

        WindCurtailRate_total_percent(k) = r.WindCurtailRate_percent;
        WindCurtailRate_R1_percent(k) = r.WindCurtailRate_region_percent(1);
        WindCurtailRate_R3_percent(k) = r.WindCurtailRate_region_percent(2);

        PvCurtailRate_total_percent(k) = r.PvCurtailRate_percent;
        PvCurtailRate_R1_percent(k) = r.PvCurtailRate_region_percent(1);
        PvCurtailRate_R3_percent(k) = r.PvCurtailRate_region_percent(2);

        RE_Utilization_total_percent(k) = r.RE_Utilization_percent;
        RE_Utilization_R1_percent(k) = r.RE_Utilization_region_percent(1);
        RE_Utilization_R3_percent(k) = r.RE_Utilization_region_percent(2);

        RE_Consumed_total_MWh(k) = r.RE_Consumed_total_MWh;
        RE_Consumed_R1_MWh(k) = r.RE_Consumed_region_MWh(1);
        RE_Consumed_R3_MWh(k) = r.RE_Consumed_region_MWh(2);

        ThermalGen_total_MWh(k) = r.ThermalGen_total_MWh;
        ThermalGen_R1_MWh(k) = r.ThermalGen_region_MWh(1);
        ThermalGen_R3_MWh(k) = r.ThermalGen_region_MWh(2);

        TotalLoad_total_MWh(k) = r.TotalLoad_total_MWh;
        TotalLoad_R1_MWh(k) = r.TotalLoad_region_MWh(1);
        TotalLoad_R3_MWh(k) = r.TotalLoad_region_MWh(2);

        ThermalShare_total_percent(k) = r.ThermalShare_percent;
        ThermalShare_R1_percent(k) = r.ThermalShare_region_percent(1);
        ThermalShare_R3_percent(k) = r.ThermalShare_region_percent(2);

        RE_Penetration_total_percent(k) = r.RE_Penetration_percent;
        RE_Penetration_R1_percent(k) = r.RE_Penetration_region_percent(1);
        RE_Penetration_R3_percent(k) = r.RE_Penetration_region_percent(2);

        TieAbsEnergy_MWh(k) = r.TieAbsEnergy_MWh;
        TieMaxUse_MW(k) = r.TieMaxUse_MW;
        TieUtilization_percent(k) = r.TieUtilization_percent;

        Startup_R1_times(k) = r.StartupTimes_region(1);
        Startup_R3_times(k) = r.StartupTimes_region(2);

        ESDischarge_R1_MWh(k) = r.ESDischarge_region_MWh(1);
        ESDischarge_R3_MWh(k) = r.ESDischarge_region_MWh(2);

        PSHGen_R1_MWh(k) = r.PSHGen_region_MWh(1);
        PSHGen_R3_MWh(k) = r.PSHGen_region_MWh(2);
    end

    summaryTable = table( ...
        Scenario, ...
        TotalCost_yuan, Cost_R1_yuan, Cost_R3_yuan, TieCost_yuan, ...
        EENS_total_MWh, EENS_R1_MWh, EENS_R3_MWh, ...
        LoadSheddingRate_total_percent, LoadSheddingRate_R1_percent, LoadSheddingRate_R3_percent, ...
        ReserveShort_total_MWh, ReserveShort_R1_MWh, ReserveShort_R3_MWh, ...
        DownReserveShort_total_MWh, DownReserveShort_R1_MWh, DownReserveShort_R3_MWh, ...
        CurtailRate_total_percent, CurtailRate_R1_percent, CurtailRate_R3_percent, ...
        WindCurtail_total_MWh, WindCurtail_R1_MWh, WindCurtail_R3_MWh, ...
        PvCurtail_total_MWh, PvCurtail_R1_MWh, PvCurtail_R3_MWh, ...
        WindCurtailRate_total_percent, WindCurtailRate_R1_percent, WindCurtailRate_R3_percent, ...
        PvCurtailRate_total_percent, PvCurtailRate_R1_percent, PvCurtailRate_R3_percent, ...
        RE_Utilization_total_percent, RE_Utilization_R1_percent, RE_Utilization_R3_percent, ...
        RE_Consumed_total_MWh, RE_Consumed_R1_MWh, RE_Consumed_R3_MWh, ...
        ThermalGen_total_MWh, ThermalGen_R1_MWh, ThermalGen_R3_MWh, ...
        TotalLoad_total_MWh, TotalLoad_R1_MWh, TotalLoad_R3_MWh, ...
        ThermalShare_total_percent, ThermalShare_R1_percent, ThermalShare_R3_percent, ...
        RE_Penetration_total_percent, RE_Penetration_R1_percent, RE_Penetration_R3_percent, ...
        TieAbsEnergy_MWh, TieMaxUse_MW, TieUtilization_percent, ...
        Startup_R1_times, Startup_R3_times, ...
        ESDischarge_R1_MWh, ESDischarge_R3_MWh, ...
        PSHGen_R1_MWh, PSHGen_R3_MWh);
end


%% ========================================================================
%% 函数9：输入数据图
%% ========================================================================
function plotInput_twoRegion(data)

    t = 1:data.T;

    figure('Name','区域1-区域3典型周输入数据');

    subplot(4,1,1);
    plot(t, data.LoadBase(1,:), 'LineWidth', 1.4);
    hold on;
    plot(t, data.PoutFix(1,:), '--', 'LineWidth', 1.2);
    plot(t, data.Load(1,:), 'k-', 'LineWidth', 1.6);
    ylabel('功率/MW');
    title('区域1本地负荷、固定外送与总需求');
    legend('区域1本地负荷','区域1固定外送','区域1总需求','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,2);
    plot(t, data.LoadBase(2,:), 'LineWidth', 1.4);
    hold on;
    plot(t, data.PoutFix(2,:), '--', 'LineWidth', 1.2);
    plot(t, data.Load(2,:), 'k-', 'LineWidth', 1.6);
    ylabel('功率/MW');
    title('区域3本地负荷、固定外送与总需求');
    legend('区域3本地负荷','区域3固定外送','区域3总需求','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,3);
    plot(t, data.WindAva(1,:), 'LineWidth', 1.4);
    hold on;
    plot(t, data.WindAva(2,:), 'LineWidth', 1.4);
    ylabel('风电/MW');
    title('两区域风电可用出力');
    legend('区域1风电','区域3风电','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,4);
    plot(t, data.PvAva(1,:), 'LineWidth', 1.4);
    hold on;
    plot(t, data.PvAva(2,:), 'LineWidth', 1.4);
    xlabel('时段/h');
    ylabel('光伏/MW');
    title('两区域光伏可用出力');
    legend('区域1光伏','区域3光伏','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数10：场景结果图
%% ========================================================================
function plotScenario_twoRegion(data, result)

    T = data.T;
    t = 1:T;

    Pth1 = sum(result.P{1},1);
    Pth3 = sum(result.P{2},1);

    %% 图1：联络线功率
    figure('Name',['区域1-区域3联络线功率 - ', result.name]);

    plot(t, result.Ptie, 'LineWidth', 1.8);
    hold on;
    yline(0, 'k-', 'HandleVisibility','off');
    yline(data.TieMax, 'k--', 'HandleVisibility','off');
    yline(-data.TieMax, 'k--', 'HandleVisibility','off');

    xlabel('时段/h');
    ylabel('联络线功率/MW');
    title(['区域1-区域3联络线功率：', result.name]);
    legend('P_{tie}，正值表示区域1向区域3送电','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% 图2：可靠性不足
    figure('Name',['两区域可靠性不足 - ', result.name]);

    subplot(3,1,1);
    bar(t, [result.Pshed(1,:)', result.Pshed(2,:)'], 'stacked');
    ylabel('失负荷/MW');
    title(['两区域失负荷 - ', result.name]);
    legend('区域1失负荷','区域3失负荷','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    subplot(3,1,2);
    bar(t, [result.Rshort(1,:)', result.Rshort(2,:)'], 'stacked');
    ylabel('正备用不足/MW');
    title(['两区域正备用不足 - ', result.name]);
    legend('区域1正备用不足','区域3正备用不足','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    subplot(3,1,3);
    bar(t, [result.RdownShort(1,:)', result.RdownShort(2,:)'], 'stacked');
    xlabel('时段/h');
    ylabel('负备用不足/MW');
    title(['两区域负备用不足 - ', result.name]);
    legend('区域1负备用不足','区域3负备用不足','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% 图3：风光消纳与弃电
    figure('Name',['两区域新能源消纳与弃电 - ', result.name]);

    windCurt1 = data.WindAva(1,:) - result.Pwind(1,:);
    windCurt3 = data.WindAva(2,:) - result.Pwind(2,:);
    pvCurt1   = data.PvAva(1,:)   - result.Ppv(1,:);
    pvCurt3   = data.PvAva(2,:)   - result.Ppv(2,:);

    subplot(2,1,1);
    plot(t, data.WindAva(1,:) + data.PvAva(1,:), '--', 'LineWidth', 1.2);
    hold on;
    plot(t, result.Pwind(1,:) + result.Ppv(1,:), '-', 'LineWidth', 1.6);
    plot(t, data.WindAva(2,:) + data.PvAva(2,:), '--', 'LineWidth', 1.2);
    plot(t, result.Pwind(2,:) + result.Ppv(2,:), '-', 'LineWidth', 1.6);
    ylabel('风光功率/MW');
    title(['两区域风光可用与消纳 - ', result.name]);
    legend('区域1风光可用','区域1风光消纳','区域3风光可用','区域3风光消纳','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    subplot(2,1,2);
    bar(t, [windCurt1(:), pvCurt1(:), windCurt3(:), pvCurt3(:)], 'stacked');
    xlabel('时段/h');
    ylabel('弃电/MW');
    title(['两区域弃风弃光 - ', result.name]);
    legend('区域1弃风','区域1弃光','区域3弃风','区域3弃光','Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% 图4：区域1电力平衡
    figure('Name',['区域1电力平衡 - ', result.name]);

    stack1 = [ ...
        Pth1(:), ...
        result.Pwind(1,:)', ...
        result.Ppv(1,:)', ...
        result.Pdis(1,:)', ...
        result.Pps_gen(1,:)', ...
        result.Pshed(1,:)', ...
        -result.Pch(1,:)', ...
        -result.Pps_pump(1,:)', ...
        -result.Ptie(:) ];

    b1 = bar(t, stack1, 'stacked');
    if numel(b1) >= 1
        b1(1).FaceColor = [0.55 0.55 0.55];
    end
    hold on;
    plot(t, data.Load(1,:), 'k-', 'LineWidth', 1.8);
    plot(t, data.LoadBase(1,:), 'k--', 'LineWidth', 1.1);
    yline(0, 'k-', 'HandleVisibility','off');

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['区域1电力平衡 - ', result.name]);
    legend('火电','风电','光伏','储能放电','抽蓄发电','失负荷', ...
           '储能充电','抽蓄抽水','区域1向区域3送电/受电','总需求','本地负荷', ...
           'Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);

    %% 图5：区域3电力平衡
    figure('Name',['区域3电力平衡 - ', result.name]);

    stack3 = [ ...
        Pth3(:), ...
        result.Pwind(2,:)', ...
        result.Ppv(2,:)', ...
        result.Pdis(2,:)', ...
        result.Pps_gen(2,:)', ...
        result.Pshed(2,:)', ...
        -result.Pch(2,:)', ...
        -result.Pps_pump(2,:)', ...
        result.Ptie(:) ];

    b3 = bar(t, stack3, 'stacked');
    if numel(b3) >= 1
        b3(1).FaceColor = [0.55 0.55 0.55];
    end
    hold on;
    plot(t, data.Load(2,:), 'k-', 'LineWidth', 1.8);
    plot(t, data.LoadBase(2,:), 'k--', 'LineWidth', 1.1);
    yline(0, 'k-', 'HandleVisibility','off');

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['区域3电力平衡 - ', result.name]);
    legend('火电','风电','光伏','储能放电','抽蓄发电','失负荷', ...
           '储能充电','抽蓄抽水','区域3受电/外送','总需求','本地负荷', ...
           'Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数11：火电机组图
%% ========================================================================
function plotThermal_twoRegion(data, result)

    T = data.T;
    t = 1:T;
    G = data.G;

    for n = 1:data.N

        unitNames = cell(G,1);
        for g = 1:G
            unitNames{g} = ['G', num2str(g)];
        end

        figure('Name',[data.regionName{n}, ' 火电机组堆叠出力 - ', result.name]);

        b = bar(t, result.P{n}', 'stacked');
        grayVals = linspace(0.30, 0.80, G);
        for gg = 1:min(numel(b),G)
            b(gg).FaceColor = [grayVals(gg) grayVals(gg) grayVals(gg)];
        end

        xlabel('时段/h');
        ylabel('火电出力/MW');
        title([data.regionName{n}, ' 火电机组堆叠出力 - ', result.name]);
        legend(unitNames, 'Location','eastoutside');
        grid on;
        xlim([1 T]);
        addDayLines(data);

        figure('Name',[data.regionName{n}, ' 火电启停状态 - ', result.name]);

        imagesc(t, 1:G, result.u{n});
        xlabel('时段/h');
        ylabel('机组编号');
        title([data.regionName{n}, ' 火电启停状态 - ', result.name]);
        yticks(1:G);
        yticklabels(unitNames);
        colorbar;
        grid on;
        xlim([1 T]);
    end
end


%% ========================================================================
%% 函数12：失败填充
%% ========================================================================
function result = fillFailedOneRegion(result, T, G)

    result.obj = NaN;
    result.P = nan(G,T);
    result.u = nan(G,T);
    result.y = nan(G,T);
    result.z = nan(G,T);

    result.Pwind = nan(1,T);
    result.Ppv = nan(1,T);

    result.Pch = nan(1,T);
    result.Pdis = nan(1,T);
    result.Ees = nan(1,T+1);

    result.Pps_pump = nan(1,T);
    result.Pps_gen = nan(1,T);
    result.Eps = nan(1,T+1);

    result.Pshed = nan(1,T);
    result.Rshort = nan(1,T);
    result.RdownShort = nan(1,T);

    result.EENS_MWh = NaN;
    result.LoadEnergy_MWh = NaN;
    result.LoadSheddingRate_percent = NaN;

    result.LOLH_h = NaN;
    result.MaxShed_MW = NaN;

    result.ReserveShort_MWh = NaN;
    result.ReserveShortHours_h = NaN;
    result.DownReserveShort_MWh = NaN;
    result.DownReserveShortHours_h = NaN;

    result.WindCurtail_MWh = NaN;
    result.PvCurtail_MWh = NaN;
    result.TotalCurtail_MWh = NaN;
    result.WindCurtailRate_percent = NaN;
    result.PvCurtailRate_percent = NaN;
    result.CurtailRate_percent = NaN;
    result.RE_Utilization_percent = NaN;

    result.RE_Consumed_MWh = NaN;
    result.ThermalGen_MWh = NaN;
    result.TotalLoad_MWh = NaN;
    result.BaseLoad_MWh = NaN;
    result.ExportLoad_MWh = NaN;
    result.ThermalShare_percent = NaN;
    result.RE_Penetration_percent = NaN;

    result.ESCharge_MWh = NaN;
    result.ESDischarge_MWh = NaN;
    result.PSHPump_MWh = NaN;
    result.PSHGen_MWh = NaN;
    result.StartupTimes = NaN;

    fields = {'C_thermal','C_curt','C_shed','C_reserve','C_es','C_ps','C_tie'};
    for i = 1:length(fields)
        result.(fields{i}) = NaN;
    end
end


function result = fillFailedTwoRegion(result, T, G)

    result.P = cell(2,1);
    result.u = cell(2,1);
    result.y = cell(2,1);
    result.z = cell(2,1);

    for n = 1:2
        result.P{n} = nan(G,T);
        result.u{n} = nan(G,T);
        result.y{n} = nan(G,T);
        result.z{n} = nan(G,T);
    end

    result.Pwind = nan(2,T);
    result.Ppv = nan(2,T);

    result.Pch = nan(2,T);
    result.Pdis = nan(2,T);
    result.Ees = nan(2,T+1);

    result.Pps_pump = nan(2,T);
    result.Pps_gen = nan(2,T);
    result.Eps = nan(2,T+1);

    result.Pshed = nan(2,T);
    result.Rshort = nan(2,T);
    result.RdownShort = nan(2,T);

    result.Ptie = nan(1,T);
    result.PtieAbs = nan(1,T);

    fields = { ...
        'obj','C_thermal','C_curt','C_shed','C_reserve','C_es','C_ps','C_tie', ...
        'EENS_total_MWh','LoadEnergy_total_MWh','LoadSheddingRate_percent', ...
        'LOLH_total_h','MaxShed_total_MW', ...
        'ReserveShort_total_MWh','ReserveShortHours_total_h', ...
        'DownReserveShort_total_MWh','DownReserveShortHours_total_h', ...
        'CurtailRate_percent','WindCurtailRate_percent','PvCurtailRate_percent', ...
        'RE_Utilization_percent', ...
        'RE_Consumed_total_MWh','ThermalGen_total_MWh','TotalLoad_total_MWh', ...
        'BaseLoad_total_MWh','ExportLoad_total_MWh', ...
        'ThermalShare_percent','RE_Penetration_percent', ...
        'TieAbsEnergy_MWh','TieMaxUse_MW','TieUtilization_percent', ...
        'ESCharge_MWh','ESDischarge_MWh','PSHPump_MWh','PSHGen_MWh','StartupTimes', ...
        'WindCurtail_MWh','PvCurtail_MWh','TotalCurtail_MWh'};

    for i = 1:length(fields)
        result.(fields{i}) = NaN;
    end

    result.C_thermal_region = nan(2,1);
    result.C_curt_region = nan(2,1);
    result.C_shed_region = nan(2,1);
    result.C_reserve_region = nan(2,1);
    result.C_es_region = nan(2,1);
    result.C_ps_region = nan(2,1);

    result.EENS_region_MWh = nan(2,1);
    result.LoadEnergy_region_MWh = nan(2,1);
    result.LoadSheddingRate_region_percent = nan(2,1);

    result.LOLH_region_h = nan(2,1);
    result.MaxShed_region_MW = nan(2,1);

    result.ReserveShort_region_MWh = nan(2,1);
    result.ReserveShortHours_region_h = nan(2,1);
    result.DownReserveShort_region_MWh = nan(2,1);
    result.DownReserveShortHours_region_h = nan(2,1);

    result.WindCurtail_region_MWh = nan(2,1);
    result.PvCurtail_region_MWh = nan(2,1);
    result.TotalCurtail_region_MWh = nan(2,1);

    result.WindCurtailRate_region_percent = nan(2,1);
    result.PvCurtailRate_region_percent = nan(2,1);
    result.CurtailRate_region_percent = nan(2,1);

    result.RE_Utilization_region_percent = nan(2,1);

    result.RE_Consumed_region_MWh = nan(2,1);
    result.ThermalGen_region_MWh = nan(2,1);
    result.TotalLoad_region_MWh = nan(2,1);
    result.BaseLoad_region_MWh = nan(2,1);
    result.ExportLoad_region_MWh = nan(2,1);
    result.ThermalShare_region_percent = nan(2,1);
    result.RE_Penetration_region_percent = nan(2,1);

    result.ESCharge_region_MWh = nan(2,1);
    result.ESDischarge_region_MWh = nan(2,1);
    result.PSHPump_region_MWh = nan(2,1);
    result.PSHGen_region_MWh = nan(2,1);
    result.StartupTimes_region = nan(2,1);
end


%% ========================================================================
%% 函数13：区域名称辅助
%% ========================================================================
function name = resultRegionName(n)
    if n == 1
        name = '区域1';
    else
        name = '区域3';
    end
end


%% ========================================================================
%% 函数14：日分隔线
%% ========================================================================
function addDayLines(data)
    for d = 1:data.D
        xline((d-1)*24 + 1, ':', 'HandleVisibility','off');
    end
end