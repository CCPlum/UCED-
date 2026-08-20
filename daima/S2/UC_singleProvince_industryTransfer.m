% 研究对象：区域1送端在“固定外送 + 新增产业负荷转移”下的多能互补运行
%
% 核心逻辑：
%   S0：无产业转移情景
%       即前面“区域1单区域多能互补固定外送情景”
%       总需求 = 区域1本地负荷 + 固定外送 1730 MW
%       资源 = 火电 + 风电 + 光伏 + 电化学储能 + 抽水蓄能
%
%   S1-S6：考虑产业转移情景
%       固定外送功率由 1730 MW 降低为 1211 MW
%       外送减少电量转化为新增产业负荷电量：
%       (1730 - 1211) * 168 = 87192 MWh
%
% 情景：
%   S0：无产业转移，外送 1730 MW，多能互补基准情景
%   S1：算力/数据中心负荷转移，外送 1211 MW
%   S2：绿色氢氨负荷转移，外送 1211 MW
%   S3：新能源装备制造负荷转移，外送 1211 MW
%   S4：电动重卡/充换电负荷转移，外送 1211 MW
%   S5：绿色工业负荷转移，外送 1211 MW
%   S6：综合新增产业负荷转移，外送 1211 MW
%
%   总负荷量 = 本地基础负荷 + 固定外送 + 固定产业负荷 + 优化后的柔性产业负荷
%
% 依赖：
%   MATLAB + YALMIP + Gurobi
% -------------------------------------------------------------------------

clc;
clear;
close all;
yalmip('clear');

%% ===================== 1. 产业转移情景设置 =============================
industryCases = buildIndustryCases();

nCase  = length(industryCases);
Results = cell(nCase,1);

%% ===================== 2. 逐情景求解 ===================================
for k = 1:nCase

    fprintf('\n============================================================\n');
    fprintf('正在求解产业情景：%s\n', industryCases(k).name);
    fprintf('============================================================\n');

    data = buildData(industryCases(k));

    cfg.name   = industryCases(k).name;

    % 所有情景均采用“风光火储抽蓄”多能互补配置；
    % 因此 S0 无产业转移情景就是前面单区域多能互补固定外送情景。
    cfg.useES  = 1;
    cfg.usePSH = 1;

    Results{k} = solveUC(data, cfg);

    if Results{k}.sol.problem == 0
        printResult(Results{k});

        plotInput(data, cfg.name);
        plotScenario(data, Results{k});
        plotThermalUnits(data, Results{k});
    else
        fprintf('场景 %s 求解失败：%s\n', ...
            cfg.name, yalmiperror(Results{k}.sol.problem));
    end
end

%% ===================== 3. 汇总结果 ======================================
summaryTable = makeSummary(Results);

fprintf('\n======================= 产业转移情景 UC 结果汇总 =======================\n');
disp(summaryTable);

writetable(summaryTable, 'UC_产业转移_区域1多能互补结果_v6_新能源渗透率.xlsx');

fprintf('\n程序运行结束。结果表已输出：UC_产业转移_区域1多能互补结果_v6_新能源渗透率.xlsx\n');


%% ========================================================================
%% 函数1：构造产业转移情景
%% ========================================================================
function industryCases = buildIndustryCases()

    %% ===================== 新增产业负荷 24h 曲线 =========================
    % 单位：MW
    % S1-S6 每条曲线周电量约为：
    % (1730 - 1211) * 168 = 87192 MWh

    %% 1）算力/数据中心
    dataCenter24 = [ ...
        492.1993714 486.6062 486.6062 481.0130 481.0130 486.6062 ...
        497.7925 514.5721 531.3516 542.5379 553.7243 559.3175 ...
        559.3175 553.7243 548.1311 542.5379 536.9448 531.3516 ...
        525.7584 520.1652 514.5721 508.9789 503.3857 497.7925 ];

    %% 2）绿色氢氨
    greenH2NH3_24 = [ ...
        374.5039086 374.5039 374.5039 374.5039 411.9543 449.4047 ...
        524.3055 614.1864 689.0872 749.0078 749.0078 749.0078 ...
        734.0277 711.5574 674.1070 614.1864 539.2856 464.3848 ...
        411.9543 374.5039 374.5039 374.5039 374.5039 374.5039 ];

    %% 3）新能源装备制造
    equipMfg24 = [ ...
        225.3261510 198.2865 180.2605 180.2605 198.2865 270.3907 ...
        495.7164 675.9768 811.1720 856.2373 883.2764 901.3025 ...
        829.1983 856.2373 883.2764 865.2504 811.1720 630.9117 ...
        405.5861 315.4590 270.3907 252.3647 234.3386 225.3260 ];

    %% 4）电动重卡/充换电
    eTruck24 = [ ...
        918.5011287 937.2460 918.5011 890.3837 843.5214 702.9340 ...
        421.7607 234.3115 187.4492 187.4492 234.3115 328.0361 ...
        421.7607 468.6230 421.7607 328.0361 234.3115 187.4492 ...
        234.3115 328.0361 515.4853 749.7968 862.2664 899.7562 ];

    %% 5）绿色工业
    greenIndustry24 = [ ...
        442.1501014 429.5720 416.8440 410.5680 416.8440 442.1501 ...
        492.6815 555.4580 600.0609 619.0101 631.6430 631.6430 ...
        606.3773 619.0101 631.6430 619.0101 581.1160 536.8966 ...
        492.6815 473.7323 461.0887 454.7830 448.4665 442.1501 ];

    %% 6）综合新增产业负荷
    newIndustryTotal24 = [ ...
        480.9210311 475.1093 466.3917 459.1270 463.4858 467.8446 ...
        489.6386 525.9620 569.5500 595.7028 613.1380 632.0261 ...
        626.2144 634.9320 626.2144 592.7969 544.8501 482.3740 ...
        431.5213 418.4449 435.8801 466.3917 478.0152 479.4681 ];

    emptyCase = struct( ...
        'name', '', ...
        'PindNom24', zeros(1,24), ...
        'alphaFlex', 0, ...
        'flexUpRatio', 1.0, ...
        'flexRampRatio', 1.0, ...
        'useIndustry', 0);

    industryCases = repmat(emptyCase, 7, 1);

    %% S0：无产业转移
    industryCases(1).name          = 'S0 基准：无产业转移，外送1730MW，多能互补';
    industryCases(1).PindNom24     = zeros(1,24);
    industryCases(1).alphaFlex     = 0.00;
    industryCases(1).flexUpRatio   = 1.00;
    industryCases(1).flexRampRatio = 1.00;
    industryCases(1).useIndustry   = 0;

    %% S1：算力/数据中心
    industryCases(2).name          = 'S1 算力/数据中心负荷转移';
    industryCases(2).PindNom24     = dataCenter24;
    industryCases(2).alphaFlex     = 0.15;
    industryCases(2).flexUpRatio   = 1.30;
    industryCases(2).flexRampRatio = 0.18;
    industryCases(2).useIndustry   = 1;

    %% S2：绿色氢氨
    industryCases(3).name          = 'S2 绿色氢氨负荷转移';
    industryCases(3).PindNom24     = greenH2NH3_24;
    industryCases(3).alphaFlex     = 0.75;
    industryCases(3).flexUpRatio   = 2.20;
    industryCases(3).flexRampRatio = 0.65;
    industryCases(3).useIndustry   = 1;

    %% S3：新能源装备制造
    industryCases(4).name          = 'S3 新能源装备制造负荷转移';
    industryCases(4).PindNom24     = equipMfg24;
    industryCases(4).alphaFlex     = 0.45;
    industryCases(4).flexUpRatio   = 1.80;
    industryCases(4).flexRampRatio = 0.45;
    industryCases(4).useIndustry   = 1;

    %% S4：电动重卡/充换电
    industryCases(5).name          = 'S4 电动重卡/充换电负荷转移';
    industryCases(5).PindNom24     = eTruck24;
    industryCases(5).alphaFlex     = 0.65;
    industryCases(5).flexUpRatio   = 2.00;
    industryCases(5).flexRampRatio = 0.60;
    industryCases(5).useIndustry   = 1;

    %% S5：绿色工业
    industryCases(6).name          = 'S5 绿色工业负荷转移';
    industryCases(6).PindNom24     = greenIndustry24;
    industryCases(6).alphaFlex     = 0.40;
    industryCases(6).flexUpRatio   = 1.60;
    industryCases(6).flexRampRatio = 0.35;
    industryCases(6).useIndustry   = 1;

    %% S6：综合产业负荷
    industryCases(7).name          = 'S6 综合新增产业负荷转移';
    industryCases(7).PindNom24     = newIndustryTotal24;
    industryCases(7).alphaFlex     = 0.55;
    industryCases(7).flexUpRatio   = 1.90;
    industryCases(7).flexRampRatio = 0.50;
    industryCases(7).useIndustry   = 1;
end


%% ========================================================================
%% 函数2：构造典型周数据
%% ========================================================================
function data = buildData(indCase)

    data.T  = 168;
    data.D  = 7;
    data.H  = 24;
    data.dt = 1;

    data.industryName = indCase.name;

    %% ===================== 1) 区域1基础本地负荷 ==========================
    baseLoad24 = [ ...
        4370 4270 4170 4120 4170 4370 ...
        4770 5170 5370 5570 5720 5870 ...
        5970 5920 5820 5720 5670 5770 ...
        5920 5870 5620 5270 4870 4570 ];

    % 最新表格中的区域1负荷影响因素
    loadDayFactor = [0.96 1.20 1.14 0.97 1.10 0.90 0.85];

    data.LoadBase = zeros(1,data.T);
    for d = 1:data.D
        idx = (d-1)*24 + (1:24);
        data.LoadBase(idx) = baseLoad24 * loadDayFactor(d);
    end

    %% ===================== 2) 固定跨区外送功率 ==========================
    data.PoutBefore = 1730;
    data.PoutAfter  = 1211;

    if indCase.useIndustry == 0
        % S0 无产业转移情景：保持固定外送 1730 MW
        data.PoutFix = data.PoutBefore * ones(1,data.T);
    else
        % S1-S6 产业转移情景：外送降低为 1211 MW
        data.PoutFix = data.PoutAfter * ones(1,data.T);
    end

    data.EtransferWeek = (data.PoutBefore - data.PoutAfter) * data.T * data.dt;

    % 固定外送是否允许缺额
    % 0：必须完成固定外送；
    % 1：允许缺额，并计入高惩罚。
    data.AllowOutShort = 0;

    %% ===================== 3) 风光可用出力 ==============================
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

    % 最新表格中的光伏和风电影响因素
    pvDayFactor   = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];
    windDayFactor = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];

    data.WindAva = zeros(1,data.T);
    data.PvAva   = zeros(1,data.T);

    for d = 1:data.D
        idx = (d-1)*24 + (1:24);

        data.WindAva(idx) = data.WindCap * min(max(windPU24 * windDayFactor(d), 0), 1);
        data.PvAva(idx)   = data.PvCap   * min(max(pvPU24   * pvDayFactor(d),   0), 1);
    end

    %% ===================== 4) 新增产业负荷 ==============================
    industryDayFactor = ones(1,data.D);

    industryShape = zeros(1,data.T);
    for d = 1:data.D
        idx = (d-1)*24 + (1:24);
        industryShape(idx) = indCase.PindNom24 * industryDayFactor(d);
    end

    if indCase.useIndustry == 1 && sum(industryShape) > 1e-6

        Eind_raw = sum(industryShape) * data.dt;

        if abs(Eind_raw - data.EtransferWeek) / data.EtransferWeek <= 0.01
            data.PindNom = data.EtransferWeek * industryShape / Eind_raw;
        else
            warning('产业负荷周电量 %.2f MWh 与外送减少电量 %.2f MWh 差异较大，请检查输入数据。', ...
                Eind_raw, data.EtransferWeek);
            data.PindNom = industryShape;
        end

    else
        data.PindNom = zeros(1,data.T);
    end

    data.alphaFlex = indCase.alphaFlex;

    data.PindFix      = (1 - data.alphaFlex) * data.PindNom;
    data.PindFlexBase = data.alphaFlex * data.PindNom;
    data.PindFlexMax  = indCase.flexUpRatio * data.PindFlexBase;

    data.PindFlexEnergyReq = sum(data.PindFlexBase) * data.dt;

    if max(data.PindNom) <= 1e-6
        data.PindFlexRamp = 0;
    else
        data.PindFlexRamp = indCase.flexRampRatio * max(data.PindNom);
    end

    data.IndShortPenalty = 6000;
    data.OutShortPenalty = 15000;

    % 用于绘图的名义总需求
    data.LoadForPlot = data.LoadBase ...
                     + data.PoutFix ...
                     + data.PindFix ...
                     + data.PindFlexBase;

    %% ===================== 5) 火电机组 ================================
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

    %% ===================== 6) 电化学储能 ==============================
    data.ES_Pmax    = 2100;
    data.ES_Emax    = 4200;
    data.ES_Emin    = 0.10 * data.ES_Emax;
    data.ES_E0      = 0.50 * data.ES_Emax;
    data.ES_eta_ch  = 0.95;
    data.ES_eta_dis = 0.95;
    data.ES_cost    = 20;
    data.ES_DailyCycle = 1;

    %% ===================== 7) 抽水蓄能 ================================
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

    %% ===================== 8) 惩罚系数与备用需求 =======================
    data.VOLL                = 30000;
    data.ReservePenalty      = 12000;
    data.DownReservePenalty  = 8000;

    % 弃风、弃光惩罚成本：500 元/MWh
    data.CurtWind = 500;
    data.CurtPv   = 500;
end


%% ========================================================================
%% 函数3：求解 UC
%% ========================================================================
function result = solveUC(data, cfg)

    T  = data.T;
    G  = data.G;
    dt = data.dt;

    %% ===================== 决策变量 =====================================
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

    PindFlex  = sdpvar(1,T,'full');
    EindShort = sdpvar(1,1,'full');

    PoutShort = sdpvar(1,T,'full');

    C = [];

    %% ===================== 火电约束 =====================================
    for t = 1:T
        C = [C, data.Pmin .* u(:,t) <= P(:,t) <= data.Pmax .* u(:,t)];
        C = [C, sum(u(:,t)) >= data.MinOnline];
    end

    C = [C, y(:,1) - z(:,1) == u(:,1) - data.u0];
    C = [C, y(:,1) + z(:,1) <= 1];

    for t = 2:T
        C = [C, y(:,t) - z(:,t) == u(:,t) - u(:,t-1)];
        C = [C, y(:,t) + z(:,t) <= 1];
    end

    C = [C, P(:,1) - data.P0 <= data.RU .* data.u0 + data.SU .* y(:,1)];
    C = [C, data.P0 - P(:,1) <= data.RD .* u(:,1) + data.SD .* z(:,1)];

    for t = 2:T
        C = [C, P(:,t) - P(:,t-1) <= data.RU .* u(:,t-1) + data.SU .* y(:,t)];
        C = [C, P(:,t-1) - P(:,t) <= data.RD .* u(:,t) + data.SD .* z(:,t)];
    end

    for g = 1:G
        Ton = data.MinUp(g);
        for t = 1:T
            tEnd = min(T, t + Ton - 1);
            C = [C, sum(u(g,t:tEnd)) >= (tEnd - t + 1) * y(g,t)];
        end
    end

    for g = 1:G
        Toff = data.MinDown(g);
        for t = 1:T
            tEnd = min(T, t + Toff - 1);
            C = [C, sum(1 - u(g,t:tEnd)) >= (tEnd - t + 1) * z(g,t)];
        end
    end

    %% ===================== 风光约束 =====================================
    C = [C, 0 <= Pwind <= data.WindAva];
    C = [C, 0 <= Ppv   <= data.PvAva];

    %% ===================== 产业柔性负荷约束 =============================
    C = [C, 0 <= PindFlex <= data.PindFlexMax];
    C = [C, EindShort >= 0];

    C = [C, sum(PindFlex) * dt + EindShort == data.PindFlexEnergyReq];

    if data.PindFlexRamp > 1e-6
        for t = 2:T
            C = [C, -data.PindFlexRamp <= PindFlex(t) - PindFlex(t-1) <= data.PindFlexRamp];
        end
    else
        C = [C, PindFlex == 0];
    end

    %% ===================== 固定外送缺额约束 =============================
    if data.AllowOutShort == 1
        C = [C, 0 <= PoutShort <= data.PoutFix];
    else
        C = [C, PoutShort == 0];
    end

    %% ===================== 电化学储能约束 ===============================
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

    %% ===================== 抽水蓄能约束 ===============================
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

    %% ===================== 失负荷与备用不足 =============================
    C = [C, 0 <= Pshed <= data.LoadBase + data.PoutFix + data.PindFix + data.PindFlexMax];
    C = [C, Rshort >= 0];
    C = [C, RdownShort >= 0];

    %% ===================== 功率平衡 =====================================
    for t = 1:T

        Demand_t = data.LoadBase(t) ...
                 + data.PindFix(t) ...
                 + PindFlex(t) ...
                 + data.PoutFix(t);

        C = [C, ...
            sum(P(:,t)) ...
            + Pwind(t) + Ppv(t) ...
            + Pdis(t) - Pch(t) ...
            + Pps_gen(t) - Pps_pump(t) ...
            + Pshed(t) ...
            + PoutShort(t) ...
            == Demand_t];
    end

    %% ===================== 正备用与负备用约束 ===========================
    for t = 1:T

        Demand_t = data.LoadBase(t) ...
                 + data.PindFix(t) ...
                 + PindFlex(t) ...
                 + data.PoutFix(t);

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

        C = [C, Rup_th + Rup_es + Rup_ps + Rshort(t) >= 0.10 * Demand_t];

        C = [C, Rup_th + Rup_es + Rup_ps + Rshort(t) >= ...
                0.15 * (data.WindAva(t) + data.PvAva(t))];

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

        C = [C, Rdn_th + Rdn_es + Rdn_ps + RdownShort(t) >= 0.05 * Demand_t];

        C = [C, Rdn_th + Rdn_es + Rdn_ps + RdownShort(t) >= ...
                0.10 * (data.WindAva(t) + data.PvAva(t))];
    end

    %% ===================== 目标函数 =====================================
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

    C_indShort = data.IndShortPenalty * EindShort;
    C_outShort = data.OutShortPenalty * sum(PoutShort) * dt;

    objective = C_thermal ...
              + C_curt ...
              + C_shed ...
              + C_reserve ...
              + C_storage ...
              + C_psh ...
              + C_indShort ...
              + C_outShort;

    ops = sdpsettings('solver','gurobi','verbose',1);
    ops.gurobi.MIPGap    = 1e-2;
    ops.gurobi.TimeLimit = 600;

    sol = optimize(C, objective, ops);

    %% ===================== 保存结果 =====================================
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

    result.PindFlex  = value(PindFlex);
    result.EindShort = value(EindShort);
    result.PoutShort = value(PoutShort);

    result.PindNom = data.PindNom;
    result.PindFix = data.PindFix;
    result.PoutFix = data.PoutFix;
    result.LoadBase = data.LoadBase;

    result.EtransferWeek = data.EtransferWeek;
    result.OutFixReq_MWh = sum(data.PoutFix) * dt;
    result.OutShort_MWh  = sum(result.PoutShort) * dt;

    result.OutCompletion_percent = ...
        100 * (result.OutFixReq_MWh - result.OutShort_MWh) / max(1e-6, result.OutFixReq_MWh);

    result.IndustryFlex_MWh  = sum(result.PindFlex) * dt;
    result.IndustryFix_MWh   = sum(data.PindFix) * dt;
    result.IndustryTotal_MWh = result.IndustryFlex_MWh + result.IndustryFix_MWh;
    result.IndustryNom_MWh   = sum(data.PindNom) * dt;
    result.IndustryFlexReq_MWh = data.PindFlexEnergyReq;

    if data.PindFlexEnergyReq > 1e-6
        result.IndustryFlexCompletion_percent = ...
            100 * result.IndustryFlex_MWh / data.PindFlexEnergyReq;
    else
        result.IndustryFlexCompletion_percent = 100;
    end

    result.DesiredDemand = data.LoadBase ...
                         + data.PindFix ...
                         + result.PindFlex ...
                         + data.PoutFix;

    result.ServedDemand = result.DesiredDemand ...
                        - result.Pshed ...
                        - result.PoutShort;

    result.LoadForPlot = data.LoadForPlot;

    result.C_thermal  = value(C_thermal);
    result.C_curt     = value(C_curt);
    result.C_shed     = value(C_shed);
    result.C_reserve  = value(C_reserve);
    result.C_storage  = value(C_storage);
    result.C_psh      = value(C_psh);
    result.C_indShort = value(C_indShort);
    result.C_outShort = value(C_outShort);

    result = calcIndicators(data, result);
end


%% ========================================================================
%% 函数4：指标计算
%% ========================================================================
function result = calcIndicators(data, result)

    dt = data.dt;

    windCurt = data.WindAva - result.Pwind;
    pvCurt   = data.PvAva   - result.Ppv;

    windCurt(abs(windCurt) < 1e-6) = 0;
    pvCurt(abs(pvCurt) < 1e-6) = 0;

    %% ===================== 弃风弃光与新能源消纳 =========================
    result.WindCurtail_MWh  = sum(windCurt) * dt;
    result.PvCurtail_MWh    = sum(pvCurt)   * dt;
    result.TotalCurtail_MWh = result.WindCurtail_MWh + result.PvCurtail_MWh;

    result.WindCurtailRate_percent = ...
        100 * result.WindCurtail_MWh / max(1e-6, sum(data.WindAva) * dt);

    result.PvCurtailRate_percent = ...
        100 * result.PvCurtail_MWh / max(1e-6, sum(data.PvAva) * dt);

    result.CurtailRate_percent = ...
        100 * result.TotalCurtail_MWh / ...
        max(1e-6, (sum(data.WindAva) + sum(data.PvAva)) * dt);

    % 新能源消纳率：新能源消纳电量 / 新能源可用发电量
    result.RE_Utilization_percent = ...
        100 * (sum(result.Pwind) + sum(result.Ppv)) * dt / ...
        max(1e-6, (sum(data.WindAva) + sum(data.PvAva)) * dt);

    %% ===================== 新能源渗透率指标 =============================
    % 新能源消纳电量：实际消纳的风电 + 光伏电量
    result.RE_Consumed_MWh = ...
        (sum(result.Pwind) + sum(result.Ppv)) * dt;

    % 火电发电量
    result.ThermalGen_MWh = sum(sum(result.P)) * dt;

    % 总负荷量：
    % 采用优化后的总需求口径：
    % 本地基础负荷 + 固定外送 + 固定产业负荷 + 优化后的柔性产业负荷
    result.TotalLoad_MWh = sum(result.DesiredDemand) * dt;

    % 其中：本地基础负荷电量
    result.BaseLoad_MWh = sum(data.LoadBase) * dt;

    % 固定外送电量
    result.ExportLoad_MWh = sum(data.PoutFix) * dt;

    % 新增产业负荷电量
    result.IndustryLoad_MWh = result.IndustryTotal_MWh;

    % 火电供电占比
    result.ThermalShare_percent = ...
        100 * result.ThermalGen_MWh / max(1e-6, result.TotalLoad_MWh);

    % 新能源渗透率：
    % 按 1 - 火电发电量 / 总负荷量 计算
    result.RE_Penetration_percent = ...
        100 * (1 - result.ThermalGen_MWh / max(1e-6, result.TotalLoad_MWh));

    %% ===================== 可靠性与资源调用指标 ==========================
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
%% 函数5：失败结果填充
%% ========================================================================
function result = fillFailed(result)

    result.obj = NaN;
    result.C_thermal = NaN;
    result.C_curt = NaN;
    result.C_shed = NaN;
    result.C_reserve = NaN;
    result.C_storage = NaN;
    result.C_psh = NaN;
    result.C_indShort = NaN;
    result.C_outShort = NaN;

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
    result.ThermalGen_MWh = NaN;
    result.TotalLoad_MWh = NaN;
    result.BaseLoad_MWh = NaN;
    result.ExportLoad_MWh = NaN;
    result.IndustryLoad_MWh = NaN;
    result.ThermalShare_percent = NaN;
    result.RE_Penetration_percent = NaN;

    result.StartupTimes = NaN;
    result.StorageCharge_MWh = NaN;
    result.StorageDischarge_MWh = NaN;
    result.PSHPump_MWh = NaN;
    result.PSHGen_MWh = NaN;

    result.IndustryNom_MWh = NaN;
    result.IndustryTotal_MWh = NaN;
    result.IndustryFlex_MWh = NaN;
    result.IndustryFlexCompletion_percent = NaN;
    result.EindShort = NaN;
    result.EtransferWeek = NaN;

    result.OutFixReq_MWh = NaN;
    result.OutShort_MWh = NaN;
    result.OutCompletion_percent = NaN;
end


%% ========================================================================
%% 函数6：汇总表
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
    IndustryShortCost_yuan = nan(nCase,1);
    OutShortCost_yuan = nan(nCase,1);

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
    ThermalGen_MWh = nan(nCase,1);
    TotalLoad_MWh = nan(nCase,1);
    BaseLoad_MWh = nan(nCase,1);
    ExportLoad_MWh = nan(nCase,1);
    IndustryLoad_MWh = nan(nCase,1);
    ThermalShare_percent = nan(nCase,1);
    RE_Penetration_percent = nan(nCase,1);

    EtransferWeek_MWh = nan(nCase,1);
    IndustryNom_MWh = nan(nCase,1);
    IndustryTotal_MWh = nan(nCase,1);
    IndustryFlex_MWh = nan(nCase,1);
    IndustryFlexCompletion_percent = nan(nCase,1);
    IndustryShort_MWh = nan(nCase,1);

    OutFixReq_MWh = nan(nCase,1);
    OutShort_MWh = nan(nCase,1);
    OutCompletion_percent = nan(nCase,1);

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
        IndustryShortCost_yuan(k) = r.C_indShort;
        OutShortCost_yuan(k) = r.C_outShort;

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
        ThermalGen_MWh(k) = r.ThermalGen_MWh;
        TotalLoad_MWh(k) = r.TotalLoad_MWh;
        BaseLoad_MWh(k) = r.BaseLoad_MWh;
        ExportLoad_MWh(k) = r.ExportLoad_MWh;
        IndustryLoad_MWh(k) = r.IndustryLoad_MWh;
        ThermalShare_percent(k) = r.ThermalShare_percent;
        RE_Penetration_percent(k) = r.RE_Penetration_percent;

        EtransferWeek_MWh(k) = r.EtransferWeek;
        IndustryNom_MWh(k) = r.IndustryNom_MWh;
        IndustryTotal_MWh(k) = r.IndustryTotal_MWh;
        IndustryFlex_MWh(k) = r.IndustryFlex_MWh;
        IndustryFlexCompletion_percent(k) = r.IndustryFlexCompletion_percent;
        IndustryShort_MWh(k) = r.EindShort;

        OutFixReq_MWh(k) = r.OutFixReq_MWh;
        OutShort_MWh(k) = r.OutShort_MWh;
        OutCompletion_percent(k) = r.OutCompletion_percent;

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
        IndustryShortCost_yuan, ...
        OutShortCost_yuan, ...
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
        ThermalGen_MWh, ...
        TotalLoad_MWh, ...
        BaseLoad_MWh, ...
        ExportLoad_MWh, ...
        IndustryLoad_MWh, ...
        ThermalShare_percent, ...
        RE_Penetration_percent, ...
        EtransferWeek_MWh, ...
        IndustryNom_MWh, ...
        IndustryTotal_MWh, ...
        IndustryFlex_MWh, ...
        IndustryFlexCompletion_percent, ...
        IndustryShort_MWh, ...
        OutFixReq_MWh, ...
        OutShort_MWh, ...
        OutCompletion_percent, ...
        StartupTimes, ...
        StorageCharge_MWh, ...
        StorageDischarge_MWh, ...
        PSHPump_MWh, ...
        PSHGen_MWh);
end


%% ========================================================================
%% 函数7：打印结果
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
    fprintf('产业柔性负荷未完成惩罚：%.2f 万元\n', result.C_indShort/1e4);
    fprintf('固定外送缺额惩罚：%.2f 万元\n', result.C_outShort/1e4);

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
    fprintf('火电发电量：%.2f MWh\n', result.ThermalGen_MWh);
    fprintf('总负荷量：%.2f MWh\n', result.TotalLoad_MWh);
    fprintf('其中：本地基础负荷电量 %.2f MWh，固定外送电量 %.2f MWh，新增产业负荷电量 %.2f MWh\n', ...
        result.BaseLoad_MWh, result.ExportLoad_MWh, result.IndustryLoad_MWh);
    fprintf('火电供电占比：%.2f %%\n', result.ThermalShare_percent);
    fprintf('新能源渗透率，按1-火电/总负荷计算：%.2f %%\n', result.RE_Penetration_percent);

    fprintf('\n产业负荷与固定外送情况：\n');
    fprintf('产业转移目标电量：%.2f MWh\n', result.EtransferWeek);
    fprintf('新增产业名义电量：%.2f MWh\n', result.IndustryNom_MWh);
    fprintf('新增产业总用电量：%.2f MWh\n', result.IndustryTotal_MWh);
    fprintf('新增产业柔性用电量：%.2f MWh\n', result.IndustryFlex_MWh);
    fprintf('产业柔性负荷完成率：%.2f %%\n', result.IndustryFlexCompletion_percent);
    fprintf('产业柔性负荷未完成电量：%.2f MWh\n', result.EindShort);
    fprintf('固定外送计划电量：%.2f MWh\n', result.OutFixReq_MWh);
    fprintf('固定外送缺额电量：%.2f MWh\n', result.OutShort_MWh);
    fprintf('固定外送完成率：%.2f %%\n', result.OutCompletion_percent);

    fprintf('\n协同资源调用情况：\n');
    fprintf('火电启动次数：%.0f 次\n', result.StartupTimes);
    fprintf('储能充电电量：%.2f MWh\n', result.StorageCharge_MWh);
    fprintf('储能放电电量：%.2f MWh\n', result.StorageDischarge_MWh);
    fprintf('抽蓄抽水电量：%.2f MWh\n', result.PSHPump_MWh);
    fprintf('抽蓄发电电量：%.2f MWh\n', result.PSHGen_MWh);
end


%% ========================================================================
%% 函数8：输入数据图
%% ========================================================================
function plotInput(data, caseName)

    t = 1:data.T;

    figure('Name',['输入数据：', caseName]);

    plot(t, data.LoadBase, 'k-', 'LineWidth', 1.6);
    hold on;
    plot(t, data.PoutFix, '-', 'LineWidth', 1.3);
    plot(t, data.PindNom, '-', 'LineWidth', 1.3);
    plot(t, data.LoadForPlot, '--', 'LineWidth', 1.6);
    plot(t, data.WindAva, ':', 'LineWidth', 1.4);
    plot(t, data.PvAva, '-.', 'LineWidth', 1.4);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['典型周输入数据 - ', caseName]);

    legend('本地基础负荷','固定外送功率','新增产业名义负荷', ...
           '等效总需求','风电可用','光伏可用', ...
           'Location','best');

    grid on;
    xlim([1 data.T]);

    for d = 1:data.D
        xline((d-1)*24 + 1, ':', 'HandleVisibility','off');
    end
end


%% ========================================================================
%% 函数9：场景总体结果图
%% ========================================================================
function plotScenario(data, result)

    T = data.T;
    t = 1:T;

    Pth_sum = sum(result.P,1);
    windCurt = data.WindAva - result.Pwind;
    pvCurt   = data.PvAva   - result.Ppv;

    %% ---------------------- 电力平衡 ------------------------------------
    figure('Name',['典型周电力平衡 - ', result.name]);

    supplyStack = [ ...
        Pth_sum(:), ...
        result.Pwind(:), ...
        result.Ppv(:), ...
        result.Pdis(:), ...
        result.Pps_gen(:), ...
        result.Pshed(:), ...
        result.PoutShort(:), ...
       -result.Pch(:), ...
       -result.Pps_pump(:) ];

    bBal = bar(t, supplyStack, 'stacked');

    if numel(bBal) >= 1
        bBal(1).FaceColor = [0.55 0.55 0.55];
    end

    hold on;

    plot(t, result.DesiredDemand, 'k-', 'LineWidth', 1.8);
    plot(t, data.LoadBase + data.PoutFix, '--', 'LineWidth', 1.4);
    plot(t, data.PindFix + result.PindFlex, '-.', 'LineWidth', 1.4);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['典型周电力平衡结果 - ', result.name]);

    legend('火电','风电消纳','光伏消纳','储能放电','抽蓄发电', ...
           '失负荷','外送缺额','储能充电','抽蓄抽水', ...
           '总需求','基础负荷+固定外送','优化后新增产业负荷', ...
           'Location','best');

    grid on;
    xlim([1 T]);

    for d = 1:data.D
        xline((d-1)*24 + 1, ':', 'HandleVisibility','off');
    end

    %% ---------------------- 风光消纳 ------------------------------------
    figure('Name',['典型周风光消纳 - ', result.name]);

    plot(t, data.WindAva, '--', 'LineWidth', 1.2);
    hold on;
    plot(t, result.Pwind, '-', 'LineWidth', 1.6);
    plot(t, data.PvAva, '--', 'LineWidth', 1.2);
    plot(t, result.Ppv, '-', 'LineWidth', 1.6);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['典型周风光可用出力与消纳出力 - ', result.name]);
    legend('风电可用','风电消纳','光伏可用','光伏消纳','Location','best');
    grid on;
    xlim([1 T]);

    %% ---------------------- 弃风弃光 ------------------------------------
    figure('Name',['典型周弃风弃光 - ', result.name]);

    bar(t, [windCurt(:), pvCurt(:)], 'stacked');
    xlabel('时段/h');
    ylabel('弃电功率/MW');
    title(['典型周弃风弃光结果 - ', result.name]);
    legend('弃风','弃光','Location','best');
    grid on;
    xlim([1 T]);

    %% ---------------------- 新增产业负荷优化前后 -------------------------
    figure('Name',['新增产业负荷优化结果 - ', result.name]);

    plot(t, result.PindNom, '--', 'LineWidth', 1.4);
    hold on;
    plot(t, result.PindFix + result.PindFlex, '-', 'LineWidth', 1.8);
    plot(t, result.PindFlex, '-.', 'LineWidth', 1.5);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['新增产业负荷优化前后对比 - ', result.name]);
    legend('新增产业名义负荷','优化后新增产业总负荷','可转移柔性负荷调用', ...
        'Location','best');
    grid on;
    xlim([1 T]);

    %% ---------------------- 储能运行 ------------------------------------
    figure('Name',['电化学储能运行 - ', result.name]);

    yyaxis left;
    bar(t, [result.Pdis(:), -result.Pch(:)], 'stacked');
    ylabel('充放电功率/MW');

    yyaxis right;
    plot(0:T, result.Ees, '-', 'LineWidth', 1.8);
    ylabel('储能电量/MWh');

    xlabel('时段/h');
    title(['电化学储能运行 - ', result.name]);
    legend('放电','充电','SOC','Location','best');
    grid on;
    xlim([1 T]);

    %% ---------------------- 抽蓄运行 ------------------------------------
    figure('Name',['抽水蓄能运行 - ', result.name]);

    yyaxis left;
    bar(t, [result.Pps_gen(:), -result.Pps_pump(:)], 'stacked');
    ylabel('抽蓄功率/MW');

    yyaxis right;
    plot(0:T, result.Eps, '-', 'LineWidth', 1.8);
    ylabel('上水库等效能量/MWh');

    xlabel('时段/h');
    title(['抽水蓄能运行 - ', result.name]);
    legend('抽蓄发电','抽蓄抽水','上水库能量','Location','best');
    grid on;
    xlim([1 T]);

    %% ---------------------- 可靠性不足 ----------------------------------
    figure('Name',['失负荷与备用不足 - ', result.name]);

    bar(t, [result.Pshed(:), result.Rshort(:), result.RdownShort(:)]);
    xlabel('时段/h');
    ylabel('功率/MW');
    title(['典型周失负荷与备用不足 - ', result.name]);
    legend('失负荷','正备用不足','负备用不足','Location','best');
    grid on;
    xlim([1 T]);
end


%% ========================================================================
%% 函数10：火电机组出力图
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

    %% ---------------------- 逐台火电机组出力 -----------------------------
    figure('Name',['典型周逐台火电机组出力 - ', result.name]);

    hUnit = plot(t, P', 'LineWidth', 1.1);

    grayValsLine = linspace(0.25, 0.75, G);
    for gg = 1:min(numel(hUnit),G)
        hUnit(gg).Color = [grayValsLine(gg) grayValsLine(gg) grayValsLine(gg)];
    end

    xlabel('时段/h');
    ylabel('机组出力/MW');
    title(['典型周逐台火电机组出力曲线 - ', result.name]);
    legend(unitNames, 'Location', 'eastoutside');
    grid on;
    xlim([1 T]);

    %% ---------------------- 火电机组堆叠出力 -----------------------------
    figure('Name',['典型周火电机组堆叠出力 - ', result.name]);

    bThermal = bar(t, P', 'stacked');

    grayVals = linspace(0.30, 0.80, G);
    for gg = 1:min(numel(bThermal),G)
        bThermal(gg).FaceColor = [grayVals(gg) grayVals(gg) grayVals(gg)];
    end

    xlabel('时段/h');
    ylabel('火电出力/MW');
    title(['典型周火电机组堆叠出力结果 - ', result.name]);
    legend(unitNames, 'Location', 'eastoutside');
    grid on;
    xlim([1 T]);

    %% ---------------------- 火电启停状态 --------------------------------
    figure('Name',['典型周火电机组启停状态 - ', result.name]);

    imagesc(t, 1:G, u);
    xlabel('时段/h');
    ylabel('机组编号');
    title(['典型周火电机组启停状态 - ', result.name]);
    yticks(1:G);
    yticklabels(unitNames);
    colorbar;
    grid on;
    xlim([1 T]);

    %% ---------------------- 火电总出力与净负荷 ---------------------------
    figure('Name',['典型周火电总出力与净负荷 - ', result.name]);

    Pth_sum = sum(P,1);

    Pnet_afterRE = result.DesiredDemand - result.Pwind - result.Ppv;

    Pnet_afterStorage = result.DesiredDemand ...
                      - result.Pwind - result.Ppv ...
                      - result.Pdis + result.Pch ...
                      - result.Pps_gen + result.Pps_pump;

    plot(t, Pth_sum, '-', 'LineWidth', 1.8);
    hold on;
    plot(t, result.DesiredDemand, '--', 'LineWidth', 1.5);
    plot(t, result.Pwind + result.Ppv, '-.', 'LineWidth', 1.5);
    plot(t, Pnet_afterRE, ':', 'LineWidth', 1.8);
    plot(t, Pnet_afterStorage, '-', 'LineWidth', 1.4);

    xlabel('时段/h');
    ylabel('功率/MW');
    title(['典型周火电总出力与净负荷对比 - ', result.name]);

    legend('火电总出力','总需求','风光消纳出力', ...
           '风光后净负荷','考虑储能/抽蓄后的火电需承担净负荷', ...
           'Location','best');

    grid on;
    xlim([1 T]);
end