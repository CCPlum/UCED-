% -------------------------------------------------------------------------
% 四区域两直流通道送受端灵活互济 + 两送端互补协同 UC 程序：典型周168h
%
% 拓扑结构：
%   区域1（送端） —— 直流通道1 ——> 区域2（受端）
%      │
%      │ 送端互补联络通道，可双向送电
%      │
%   区域3（送端） —— 直流通道2 ——> 区域4（受端）
%
% 场景：
%   S0：固定外送 + 送端不互补
%       P12 = 1730 MW，P34 = 2300 MW；
%       P13 = 0；
%       受端不参与需求响应；
%       等价于各区域在固定送受电边界下分别进行多能互补优化。
%
%   S1：固定外送 + 送端互补协同
%       P12 = 1730 MW，P34 = 2300 MW；
%       P13(t) 为优化变量；
%       区域1与区域3之间可双向互补送电；
%       受端不参与需求响应。
%
%   S2：送受端灵活互济 + 送端不互补
%       P12(t)、P34(t) 为优化变量；
%       P12、P34 分别保持周总外送电量与固定外送情景一致；
%       P12、P34 满足阶梯化调整和调整后保持5小时约束；
%       P13 = 0；
%       区域2、区域4受端需求响应参与协同优化；
%       该情景用于表征“柔性直流过渡情景”。
%
%   S3：送受端灵活互济 + 送端互补协同
%       P12(t)、P34(t) 为优化变量；
%       P12、P34 分别保持周总外送电量与固定外送情景一致；
%       P12、P34 满足阶梯化调整和调整后保持5小时约束；
%       P13(t) 为优化变量；
%       区域1与区域3之间可双向互补送电；
%       区域2、区域4受端需求响应参与协同优化；
%       区域2与区域4之间不互联。
%
% 系统口径：
%   系统总负荷量 = 四区域实际用电负荷之和；
%   P12、P34、P13 属于系统内部交换，不重复计入系统总负荷。
%
% 分区域口径：
%   按功率平衡中的“等效供电责任负荷”计算：
%   区域1 = 本地负荷 + P12外送 + P13送端互补净外送
%   区域2 = 响应后负荷 - P12受电
%   区域3 = 本地负荷 + P34外送 - P13受电
%   区域4 = 响应后负荷 - P34受电
%
% 弃电惩罚：
%   弃风、弃光惩罚成本 = 500 元/MWh。
%
% 运行环境：
%   MATLAB + YALMIP + Gurobi
% -------------------------------------------------------------------------

clc;
clear;
close all;
yalmip('clear');

%% ======================== 1. 构造数据 ==================================
data = buildData_fourRegion();

Results = cell(4,1);

%% ======================== 2. S0：固定外送 + 送端不互补 ===================
fprintf('\n============================================================\n');
fprintf('S0：固定外送，P12=%.0f MW，P34=%.0f MW，P13=0\n', ...
    data.P12FixedValue, data.P34FixedValue);
fprintf('说明：S0 等价于各区域单独多能互补，固定外送作为边界条件处理。\n');
fprintf('============================================================\n');

case0.name = 'S0 固定外送：送端不互补';
case0.mode = 'fixed_no_complement';

Results{1} = solveUC_fourRegion(data, case0);

if Results{1}.sol.problem == 0
    printResult_fourRegion(Results{1});
else
    fprintf('S0 求解失败：%s\n', yalmiperror(Results{1}.sol.problem));
end

%% ======================== 3. S1：固定外送 + 送端互补 =====================
fprintf('\n============================================================\n');
fprintf('S1：固定外送，P12=%.0f MW，P34=%.0f MW，区域1与区域3送端互补\n', ...
    data.P12FixedValue, data.P34FixedValue);
fprintf('说明：P12、P34固定不变，仅允许送端区域1和区域3通过P13互补。\n');
fprintf('============================================================\n');

case1.name = 'S1 固定外送：送端区域1和区域3互补';
case1.mode = 'fixed_sender_complement';

Results{2} = solveUC_fourRegion(data, case1);

if Results{2}.sol.problem == 0
    printResult_fourRegion(Results{2});
else
    fprintf('S1 求解失败：%s\n', yalmiperror(Results{2}.sol.problem));
end

%% ======================== 4. S2：柔性直流 + 送端不互补 ===================
fprintf('\n============================================================\n');
fprintf('S2：两直流柔性调节，周总送电量不变，区域1与区域3不互补\n');
fprintf('说明：仅考虑区域1-区域2、区域3-区域4送受端灵活互济，P13=0。\n');
fprintf('============================================================\n');

case2.name = 'S2 柔性直流：送受端灵活互济，送端不互补';
case2.mode = 'flexible_no_sender_complement';

Results{3} = solveUC_fourRegion(data, case2);

if Results{3}.sol.problem == 0
    printResult_fourRegion(Results{3});
else
    fprintf('S2 求解失败：%s\n', yalmiperror(Results{3}.sol.problem));
end

%% ======================== 5. S3：柔性直流 + 送端互补 =====================
fprintf('\n============================================================\n');
fprintf('S3：两直流灵活互济，周总送电量不变，区域1与区域3送端互补\n');
fprintf('============================================================\n');

case3.name = 'S3 灵活互济：两直流可调，送端区域1和区域3互补';
case3.mode = 'flexible_sender_complement';

Results{4} = solveUC_fourRegion(data, case3);

if Results{4}.sol.problem == 0
    printResult_fourRegion(Results{4});
else
    fprintf('S3 求解失败：%s\n', yalmiperror(Results{4}.sol.problem));
end

%% ======================== 6. 汇总输出 ==================================
summaryTable = makeSummary_fourRegion(Results);
fprintf('\n======================= 四区域两直流四情景结果汇总 =======================\n');
disp(summaryTable);

writetable(summaryTable, 'UC_fourRegion_twoHVDC_senderComplement_v6_REPenetration_summary.xlsx');

%% ======================== 7. 绘图 ======================================
plotInput_fourRegion(data);

for k = 1:length(Results)
    if Results{k}.sol.problem == 0
        plotTie_fourRegion(data, Results{k});
        plotCurtail_fourRegion(data, Results{k});
        plotPowerBalance_fourRegion(data, Results{k});
        plotThermal_fourRegion(data, Results{k});
    end
end

fprintf('\n程序运行结束。结果表已输出：UC_fourRegion_twoHVDC_senderComplement_v6_REPenetration_summary.xlsx\n');


%% ========================================================================
%% 函数1：构造四区域数据
%% ========================================================================
function data = buildData_fourRegion()

    data.T  = 168;
    data.D  = 7;
    data.H  = 24;
    data.N  = 4;
    data.G  = 8;
    data.dt = 1;

    data.nodeName = { ...
        '区域1：送端-直流1', ...
        '区域2：受端-直流1', ...
        '区域3：送端-直流2', ...
        '区域4：受端-直流2'};

    %% ---------------------- 1) 负荷数据 MW ------------------------------
    load1_24 = [ ...
        4370 4270 4170 4120 4170 4370 ...
        4770 5170 5370 5570 5720 5870 ...
        5970 5920 5820 5720 5670 5770 ...
        5920 5870 5620 5270 4870 4570 ];

    load2_24 = [ ...
        7700 7300 7000 6800 6900 7500 ...
        8800 10400 11600 12200 11800 11100 ...
        10400 10000 10300 11200 12800 14800 ...
        16600 17400 16600 14400 11400 9200 ];

    load3_24 = [ ...
        4500 4300 4150 4000 3950 4100 ...
        4700 5300 5750 6100 6300 6000 ...
        5800 5500 5350 5900 6350 6500 ...
        6900 7700 7400 6100 5500 4700 ];

    load4_24 = [ ...
        6600 6300 6050 5900 6000 6550 ...
        7900 9300 10300 10900 10600 10000 ...
        9600 9300 9600 10400 11800 13600 ...
        15000 15600 14800 12900 10200 8100 ];

    load24 = [load1_24; load2_24; load3_24; load4_24];

    loadFactor = zeros(data.N,data.D);
    loadFactor(1,:) = [0.96 1.20 1.14 0.97 1.10 0.90 0.85];
    loadFactor(2,:) = [0.95 0.96 0.90 0.94 0.98 0.90 0.85];
    loadFactor(3,:) = [1.04 0.98 0.95 1.16 1.15 0.92 0.82];
    loadFactor(4,:) = [0.88 1.00 0.98 1.02 1.20 0.98 0.80];

    data.Load = zeros(data.N,data.T);
    for n = 1:data.N
        for d = 1:data.D
            idx = (d-1)*24 + (1:24);
            data.Load(n,idx) = load24(n,:) * loadFactor(n,d);
        end
    end

    %% ---------------------- 2) 风光可用出力 MW --------------------------
    data.WindCap = [10500; 9000; 10000; 9000];
    data.PvCap   = [10500; 9000; 10000; 9000];

    pv1_24 = [ ...
        0.000 0.000 0.000 0.000 0.000 0.000 ...
        0.002 0.053 0.197 0.397 0.606 0.755 ...
        0.840 0.867 0.843 0.790 0.737 0.613 ...
        0.465 0.296 0.131 0.023 0.001 0.000 ];

    wind1_24 = [ ...
        0.46 0.49 0.51 0.50 0.45 0.39 ...
        0.33 0.28 0.24 0.21 0.18 0.16 ...
        0.15 0.16 0.18 0.20 0.23 0.26 ...
        0.30 0.34 0.38 0.41 0.43 0.45 ];

    pv2_24 = [ ...
        0.000 0.000 0.000 0.000 0.000 0.000 ...
        0.040 0.120 0.260 0.380 0.550 0.650 ...
        0.640 0.590 0.460 0.320 0.220 0.060 ...
        0.010 0.000 0.000 0.000 0.000 0.000 ];

    wind2_24 = [ ...
        0.22 0.24 0.25 0.25 0.24 0.23 ...
        0.24 0.28 0.32 0.36 0.39 0.41 ...
        0.40 0.37 0.34 0.32 0.33 0.37 ...
        0.40 0.42 0.39 0.33 0.28 0.24 ];

    pv3_24 = [ ...
        0.000 0.000 0.000 0.000 0.000 0.000 ...
        0.010 0.095 0.233 0.378 0.507 0.591 ...
        0.634 0.640 0.640 0.570 0.481 0.398 ...
        0.248 0.140 0.035 0.000 0.000 0.000 ];

    wind3_24 = [ ...
        0.24 0.25 0.26 0.26 0.25 0.24 ...
        0.26 0.30 0.34 0.38 0.40 0.42 ...
        0.40 0.37 0.34 0.32 0.34 0.38 ...
        0.42 0.44 0.40 0.34 0.29 0.26 ];

    pv4_24 = [ ...
        0.000 0.000 0.000 0.000 0.000 0.040 ...
        0.100 0.150 0.320 0.380 0.440 0.560 ...
        0.520 0.480 0.360 0.280 0.120 0.060 ...
        0.010 0.000 0.000 0.000 0.000 0.000 ];

    wind4_24 = [ ...
        0.18 0.20 0.22 0.23 0.23 0.22 ...
        0.24 0.27 0.30 0.33 0.37 0.40 ...
        0.42 0.40 0.37 0.34 0.32 0.35 ...
        0.38 0.40 0.37 0.30 0.24 0.20 ];

    pv24   = [pv1_24; pv2_24; pv3_24; pv4_24];
    wind24 = [wind1_24; wind2_24; wind3_24; wind4_24];

    pvFactor = zeros(data.N,data.D);
    windFactor = zeros(data.N,data.D);

    pvFactor(1,:)   = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];
    windFactor(1,:) = [1.05 1.02 0.96 0.95 0.88 1.10 1.08];

    pvFactor(2,:)   = [1.02 1.05 0.95 1.00 0.87 0.96 0.92];
    windFactor(2,:) = [1.02 1.05 0.95 1.00 0.87 0.96 0.92];

    pvFactor(3,:)   = [1.21 0.94 1.05 0.82 1.12 0.96 0.92];
    windFactor(3,:) = [1.21 0.94 1.05 0.82 1.12 0.96 0.92];

    pvFactor(4,:)   = [1.16 0.98 1.02 0.98 0.80 1.12 1.20];
    windFactor(4,:) = [1.16 0.98 1.02 0.98 0.80 1.12 1.20];

    data.WindAva = zeros(data.N,data.T);
    data.PvAva   = zeros(data.N,data.T);

    for n = 1:data.N
        for d = 1:data.D
            idx = (d-1)*24 + (1:24);

            data.WindAva(n,idx) = data.WindCap(n) * ...
                min(max(wind24(n,:) * windFactor(n,d),0),1);

            data.PvAva(n,idx) = data.PvCap(n) * ...
                min(max(pv24(n,:) * pvFactor(n,d),0),1);
        end
    end

    %% ---------------------- 3) 火电机组数据 -----------------------------
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

    data.Pmax(2,:) = [2000 1800 1600 1400 1200 1000 800 600];
    data.Pmin(2,:) = [800  720  640  560  480  400 320 240];

    data.Pmax(3,:) = [800 800 660 660 500 330 300 150];
    data.Pmin(3,:) = [320 320 264 264 200 132 120 60];

    data.Pmax(4,:) = [1800 1600 1400 1200 1000 800 600 300];
    data.Pmin(4,:) = [720  640  560  480  400 320 240 120];

    data.RU(1,:) = [260 260 230 230 190 190 150 120];
    data.RU(2,:) = [450 400 360 320 280 240 200 160];
    data.RU(3,:) = [190 190 150 150 120 90 80 50];
    data.RU(4,:) = [420 380 340 300 250 210 160 90];

    data.RD = data.RU;
    data.SU = data.Pmax;
    data.SD = data.Pmax;

    data.MinUp(1,:)   = [4 4 3 3 3 3 2 2];
    data.MinDown(1,:) = [4 4 3 3 3 3 2 2];

    data.MinUp(2,:)   = [4 4 3 3 3 2 2 2];
    data.MinDown(2,:) = [4 4 3 3 3 2 2 2];

    data.MinUp(3,:)   = [4 4 3 3 3 2 2 1];
    data.MinDown(3,:) = [4 4 3 3 3 2 2 1];

    data.MinUp(4,:)   = [4 4 3 3 3 2 2 2];
    data.MinDown(4,:) = [4 4 3 3 3 2 2 2];

    data.MinOnline = [3; 4; 2; 4];

    data.Cvar(1,:) = [210 215 230 235 250 255 280 300];
    data.Cvar(2,:) = [230 235 245 255 270 285 300 320];
    data.Cvar(3,:) = [210 215 230 235 250 270 285 320];
    data.Cvar(4,:) = [230 235 245 255 270 285 305 330];

    data.Cfix(1,:) = [12000 12000 9500 9500 7000 7000 3500 3000];
    data.Cfix(2,:) = [15000 14500 12000 11000 9000 8000 5000 4000];
    data.Cfix(3,:) = [8000 8000 6000 6000 4200 3000 2500 1200];
    data.Cfix(4,:) = [14500 13500 11000 9500 8000 6500 4500 2500];

    data.Cstart(1,:) = [90000 90000 65000 65000 42000 42000 18000 15000];
    data.Cstart(2,:) = [110000 100000 80000 75000 52000 45000 30000 20000];
    data.Cstart(3,:) = [65000 65000 42000 42000 25000 15000 12000 6000];
    data.Cstart(4,:) = [105000 95000 76000 65000 50000 38000 24000 12000];

    data.Cshut(1,:) = [30000 30000 22000 22000 15000 15000 7000 6000];
    data.Cshut(2,:) = [38000 35000 28000 25000 18000 16000 10000 8000];
    data.Cshut(3,:) = [22000 22000 15000 15000 9000 6000 5000 3000];
    data.Cshut(4,:) = [35000 32000 26000 22000 17000 13000 9000 5000];

    data.u0 = zeros(data.N,G);
    data.u0(1,:) = [1 1 1 1 1 0 0 0];
    data.u0(2,:) = [1 1 1 1 1 1 0 0];
    data.u0(3,:) = [1 1 1 1 0 0 0 0];
    data.u0(4,:) = [1 1 1 1 1 1 0 0];

    data.P0 = data.u0 .* data.Pmin;

    %% ---------------------- 4) 电化学储能 -------------------------------
    data.ES_Pmax = [2100; 1800; 2000; 1800];
    data.ES_Emax = [4200; 3600; 4000; 3600];
    data.ES_Emin = 0.10 * data.ES_Emax;
    data.ES_E0   = 0.50 * data.ES_Emax;

    data.ES_eta_ch  = [0.95; 0.95; 0.95; 0.95];
    data.ES_eta_dis = [0.95; 0.95; 0.95; 0.95];
    data.ES_cost    = [20; 20; 20; 20];

    data.ES_DailyCycle = 1;

    %% ---------------------- 5) 抽水蓄能 -------------------------------
    data.PS_Pgen_max  = [1000; 1000; 1000; 1000];
    data.PS_Ppump_max = [1000; 1000; 1000; 1000];
    data.PS_Emax      = [4000; 4000; 4000; 4000];
    data.PS_Emin      = 0.10 * data.PS_Emax;
    data.PS_E0        = 0.50 * data.PS_Emax;

    data.PS_eta_pump  = [0.90; 0.90; 0.90; 0.90];
    data.PS_eta_gen   = [0.90; 0.90; 0.90; 0.90];
    data.PS_cost      = [15; 15; 15; 15];
    data.PS_Ramp      = [1000; 1000; 1000; 1000];

    data.PS_DailyCycle = 0;

    %% ---------------------- 6) 两条直流通道与送端互补通道 ---------------
    data.P12FixedValue = 1730;
    data.P12Fixed = data.P12FixedValue * ones(1,data.T);
    data.E12WeekReq = sum(data.P12Fixed) * data.dt;

    data.P34FixedValue = 2300;
    data.P34Fixed = data.P34FixedValue * ones(1,data.T);
    data.E34WeekReq = sum(data.P34Fixed) * data.dt;

    data.Tie12Max = 3000;
    data.Tie34Max = 3600;

    data.Tie12Ramp = 700;
    data.Tie34Ramp = 800;

    data.Tie12StepMin = 100;
    data.Tie12StepMax = 700;
    data.Tie34StepMin = 100;
    data.Tie34StepMax = 800;

    data.UseTieStep = 1;
    data.UseTieHold = 1;
    data.TieHoldHours = 5;

    data.UseTieAdjustCount = 0;
    data.TieMaxAdjustDay  = 4;
    data.TieMaxAdjustWeek = 28;

    data.Tie12Cost = 5;
    data.Tie34Cost = 5;

    data.Tie13Max  = 1800;
    data.Tie13Ramp = 600;
    data.Tie13Cost = 3;

    data.CountTieCostInFixedNoComplement = 0;
    data.CountTieCostInFixedSenderComplement = 1;
    data.CountTieCostInFlexibleNoSenderComplement = 1;
    data.CountTieCostInFlexibleSenderComplement = 1;

    %% ---------------------- 7) 受端需求响应参数 -------------------------
    data.DR_ratio = 0.06;
    data.DR_cost  = 120;

    %% ---------------------- 8) 惩罚系数 --------------------------------
    data.VOLL                = 30000;
    data.ReservePenalty      = 12000;
    data.DownReservePenalty  = 8000;

    data.CurtWind            = 500;
    data.CurtPv              = 500;
end


%% ========================================================================
%% 函数2：求解四区域 UC
%% ========================================================================
function result = solveUC_fourRegion(data, caseInfo)

    N  = data.N;
    G  = data.G;
    T  = data.T;
    dt = data.dt;

    isFixedNoComplement = strcmp(caseInfo.mode, 'fixed_no_complement');
    isFixedSenderComplement = strcmp(caseInfo.mode, 'fixed_sender_complement');
    isFlexibleNoSenderComplement = strcmp(caseInfo.mode, 'flexible_no_sender_complement');
    isFlexibleSenderComplement = strcmp(caseInfo.mode, 'flexible_sender_complement');

    useFlexibleHVDC = isFlexibleNoSenderComplement || isFlexibleSenderComplement;
    useSenderComplement = isFixedSenderComplement || isFlexibleSenderComplement;
    useDR = isFlexibleNoSenderComplement || isFlexibleSenderComplement;

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

    if useFlexibleHVDC
        P12 = sdpvar(1,T,'full');
        P34 = sdpvar(1,T,'full');

        x12Up   = binvar(1,T-1,'full');
        x12Down = binvar(1,T-1,'full');
        x34Up   = binvar(1,T-1,'full');
        x34Down = binvar(1,T-1,'full');
    else
        P12 = data.P12Fixed;
        P34 = data.P34Fixed;

        x12Up = [];
        x12Down = [];
        x34Up = [];
        x34Down = [];
    end

    if useSenderComplement
        P13    = sdpvar(1,T,'full');
        P13Abs = sdpvar(1,T,'full');
    else
        P13    = zeros(1,T);
        P13Abs = zeros(1,T);
    end

    Pdr_up   = sdpvar(2,T,'full');
    Pdr_down = sdpvar(2,T,'full');

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

    %% ---------------------- 储能与抽蓄约束 ------------------------------
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

    %% ---------------------- 两条直流通道约束 -----------------------------
    if useFlexibleHVDC

        C = [C, 0 <= P12 <= data.Tie12Max];
        C = [C, 0 <= P34 <= data.Tie34Max];

        if data.UseTieStep == 1

            for t = 1:T-1
                dP12 = P12(t+1) - P12(t);
                C = [C, x12Up(t) + x12Down(t) <= 1];
                C = [C, dP12 <= data.Tie12StepMax * x12Up(t) ...
                               - data.Tie12StepMin * x12Down(t)];
                C = [C, dP12 >= data.Tie12StepMin * x12Up(t) ...
                               - data.Tie12StepMax * x12Down(t)];

                dP34 = P34(t+1) - P34(t);
                C = [C, x34Up(t) + x34Down(t) <= 1];
                C = [C, dP34 <= data.Tie34StepMax * x34Up(t) ...
                               - data.Tie34StepMin * x34Down(t)];
                C = [C, dP34 >= data.Tie34StepMin * x34Up(t) ...
                               - data.Tie34StepMax * x34Down(t)];
            end

            if data.UseTieHold == 1
                for t = 1:T-1
                    idxHold = t:min(t + data.TieHoldHours - 1, T-1);
                    C = [C, sum(x12Up(idxHold) + x12Down(idxHold)) <= 1];
                    C = [C, sum(x34Up(idxHold) + x34Down(idxHold)) <= 1];
                end
            end

            if data.UseTieAdjustCount == 1
                for d = 1:data.D
                    idxAdj = (d-1)*24 + (1:23);
                    C = [C, sum(x12Up(idxAdj) + x12Down(idxAdj)) <= data.TieMaxAdjustDay];
                    C = [C, sum(x34Up(idxAdj) + x34Down(idxAdj)) <= data.TieMaxAdjustDay];
                end
                C = [C, sum(x12Up + x12Down) <= data.TieMaxAdjustWeek];
                C = [C, sum(x34Up + x34Down) <= data.TieMaxAdjustWeek];
            end

        else
            for t = 2:T
                C = [C, -data.Tie12Ramp <= P12(t)-P12(t-1) <= data.Tie12Ramp];
                C = [C, -data.Tie34Ramp <= P34(t)-P34(t-1) <= data.Tie34Ramp];
            end
        end

        C = [C, sum(P12) * dt == data.E12WeekReq];
        C = [C, sum(P34) * dt == data.E34WeekReq];

    else
        % S0/S1 中，P12、P34 为固定曲线。
    end

    %% ---------------------- 送端互补通道 P13 约束 -----------------------
    if useSenderComplement
        C = [C, -data.Tie13Max <= P13 <= data.Tie13Max];
        C = [C, P13Abs >= P13, P13Abs >= -P13, P13Abs >= 0];

        for t = 2:T
            C = [C, -data.Tie13Ramp <= P13(t)-P13(t-1) <= data.Tie13Ramp];
        end
    else
        % S0/S2 中，P13 = 0。
    end

    %% ---------------------- 受端需求响应约束 ----------------------------
    if useDR
        loadR2 = data.Load(2,:);
        loadR4 = data.Load(4,:);

        C = [C, 0 <= Pdr_up(1,:)   <= data.DR_ratio * loadR2];
        C = [C, 0 <= Pdr_down(1,:) <= data.DR_ratio * loadR2];

        C = [C, 0 <= Pdr_up(2,:)   <= data.DR_ratio * loadR4];
        C = [C, 0 <= Pdr_down(2,:) <= data.DR_ratio * loadR4];

        for d = 1:data.D
            idx = (d-1)*24 + (1:24);
            C = [C, sum(Pdr_up(1,idx)) == sum(Pdr_down(1,idx))];
            C = [C, sum(Pdr_up(2,idx)) == sum(Pdr_down(2,idx))];
        end
    else
        C = [C, Pdr_up == 0, Pdr_down == 0];
    end

    %% ---------------------- 松弛变量 ------------------------------------
    C = [C, 0 <= Pshed(1,:) <= data.Load(1,:) + data.Tie12Max + data.Tie13Max];
    C = [C, 0 <= Pshed(2,:) <= data.Load(2,:) + Pdr_up(1,:)];
    C = [C, 0 <= Pshed(3,:) <= data.Load(3,:) + data.Tie34Max + data.Tie13Max];
    C = [C, 0 <= Pshed(4,:) <= data.Load(4,:) + Pdr_up(2,:)];

    C = [C, Rshort >= 0];
    C = [C, RdownShort >= 0];

    %% ---------------------- 功率平衡 ------------------------------------
    for t = 1:T

        C = [C, ...
            sum(P{1}(:,t)) ...
            + Pwind(1,t) + Ppv(1,t) ...
            + Pdis(1,t) - Pch(1,t) ...
            + Pps_gen(1,t) - Pps_pump(1,t) ...
            + Pshed(1,t) ...
            == data.Load(1,t) + P12(t) + P13(t)];

        C = [C, ...
            sum(P{2}(:,t)) ...
            + Pwind(2,t) + Ppv(2,t) ...
            + Pdis(2,t) - Pch(2,t) ...
            + Pps_gen(2,t) - Pps_pump(2,t) ...
            + P12(t) ...
            + Pshed(2,t) ...
            == data.Load(2,t) - Pdr_down(1,t) + Pdr_up(1,t)];

        C = [C, ...
            sum(P{3}(:,t)) ...
            + Pwind(3,t) + Ppv(3,t) ...
            + Pdis(3,t) - Pch(3,t) ...
            + Pps_gen(3,t) - Pps_pump(3,t) ...
            + P13(t) ...
            + Pshed(3,t) ...
            == data.Load(3,t) + P34(t)];

        C = [C, ...
            sum(P{4}(:,t)) ...
            + Pwind(4,t) + Ppv(4,t) ...
            + Pdis(4,t) - Pch(4,t) ...
            + Pps_gen(4,t) - Pps_pump(4,t) ...
            + P34(t) ...
            + Pshed(4,t) ...
            == data.Load(4,t) - Pdr_down(2,t) + Pdr_up(2,t)];
    end

    %% ---------------------- 正备用与负备用约束 --------------------------
    for t = 1:T

        reserveLoad = cell(N,1);
        reserveLoad{1} = data.Load(1,t) + P12(t) + P13(t);
        reserveLoad{2} = data.Load(2,t) - Pdr_down(1,t) + Pdr_up(1,t) - P12(t);
        reserveLoad{3} = data.Load(3,t) + P34(t) - P13(t);
        reserveLoad{4} = data.Load(4,t) - Pdr_down(2,t) + Pdr_up(2,t) - P34(t);

        for n = 1:N

            Rup_th = sum(data.Pmax(n,:)' .* u{n}(:,t) - P{n}(:,t));
            Rup_es = Pch(n,t) + (data.ES_Pmax(n) - Pdis(n,t));
            Rup_ps = Pps_pump(n,t) + (data.PS_Pgen_max(n) - Pps_gen(n,t));

            Rdn_th = sum(P{n}(:,t) - data.Pmin(n,:)' .* u{n}(:,t));
            Rdn_es = Pdis(n,t) + (data.ES_Pmax(n) - Pch(n,t));
            Rdn_ps = Pps_gen(n,t) + (data.PS_Ppump_max(n) - Pps_pump(n,t));

            C = [C, Rup_th + Rup_es + Rup_ps + Rshort(n,t) >= ...
                    0.10 * reserveLoad{n}];

            C = [C, Rup_th + Rup_es + Rup_ps + Rshort(n,t) >= ...
                    0.15 * (data.WindAva(n,t) + data.PvAva(n,t))];

            C = [C, Rdn_th + Rdn_es + Rdn_ps + RdownShort(n,t) >= ...
                    0.05 * reserveLoad{n}];

            C = [C, Rdn_th + Rdn_es + Rdn_ps + RdownShort(n,t) >= ...
                    0.10 * (data.WindAva(n,t) + data.PvAva(n,t))];
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
            data.CurtPv   * sum(data.PvAva(n,:)   - Ppv(n,:)) * dt;

        C_shed_region{n} = data.VOLL * sum(Pshed(n,:)) * dt;

        C_reserve_region{n} = ...
            data.ReservePenalty     * sum(Rshort(n,:)) * dt + ...
            data.DownReservePenalty * sum(RdownShort(n,:)) * dt;

        C_es_region{n} = data.ES_cost(n) * sum(Pch(n,:) + Pdis(n,:)) * dt;
        C_ps_region{n} = data.PS_cost(n) * sum(Pps_pump(n,:) + Pps_gen(n,:)) * dt;

        objective = objective + C_thermal_region{n} + C_curt_region{n} + ...
                    C_shed_region{n} + C_reserve_region{n} + ...
                    C_es_region{n} + C_ps_region{n};
    end

    C_dr2 = data.DR_cost * sum(Pdr_up(1,:) + Pdr_down(1,:)) * dt;
    C_dr4 = data.DR_cost * sum(Pdr_up(2,:) + Pdr_down(2,:)) * dt;
    C_dr  = C_dr2 + C_dr4;

    if isFixedNoComplement
        if data.CountTieCostInFixedNoComplement == 1
            C_tie12 = data.Tie12Cost * sum(P12) * dt;
            C_tie34 = data.Tie34Cost * sum(P34) * dt;
        else
            C_tie12 = 0;
            C_tie34 = 0;
        end
        C_tie13 = 0;

    elseif isFixedSenderComplement
        C_tie12 = 0;
        C_tie34 = 0;
        if data.CountTieCostInFixedSenderComplement == 1
            C_tie13 = data.Tie13Cost * sum(P13Abs) * dt;
        else
            C_tie13 = 0;
        end

    elseif isFlexibleNoSenderComplement
        if data.CountTieCostInFlexibleNoSenderComplement == 1
            C_tie12 = data.Tie12Cost * sum(P12) * dt;
            C_tie34 = data.Tie34Cost * sum(P34) * dt;
        else
            C_tie12 = 0;
            C_tie34 = 0;
        end
        C_tie13 = 0;

    elseif isFlexibleSenderComplement
        if data.CountTieCostInFlexibleSenderComplement == 1
            C_tie12 = data.Tie12Cost * sum(P12) * dt;
            C_tie34 = data.Tie34Cost * sum(P34) * dt;
            C_tie13 = data.Tie13Cost * sum(P13Abs) * dt;
        else
            C_tie12 = 0;
            C_tie34 = 0;
            C_tie13 = 0;
        end
    else
        C_tie12 = 0;
        C_tie34 = 0;
        C_tie13 = 0;
    end

    C_tie = C_tie12 + C_tie34 + C_tie13;

    objective = objective + C_dr + C_tie;

    ops = sdpsettings('solver','gurobi','verbose',1);
    ops.gurobi.MIPGap    = 1e-2;
    ops.gurobi.TimeLimit = 900;

    sol = optimize(C, objective, ops);

    %% ---------------------- 保存结果 ------------------------------------
    result.name = caseInfo.name;
    result.mode = caseInfo.mode;
    result.sol  = sol;

    if sol.problem ~= 0
        result = fillFailedFourRegion(result, T, G);
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

    result.Pshed = value(Pshed);
    result.Rshort = value(Rshort);
    result.RdownShort = value(RdownShort);

    if useFlexibleHVDC
        result.P12 = value(P12);
        result.P34 = value(P34);

        result.x12Up   = value(x12Up);
        result.x12Down = value(x12Down);
        result.x34Up   = value(x34Up);
        result.x34Down = value(x34Down);

        result.Tie12AdjustTimes = sum(result.x12Up + result.x12Down);
        result.Tie34AdjustTimes = sum(result.x34Up + result.x34Down);
    else
        result.P12 = data.P12Fixed;
        result.P34 = data.P34Fixed;

        result.x12Up = double(diff(result.P12) > 1e-4);
        result.x12Down = double(diff(result.P12) < -1e-4);
        result.x34Up = double(diff(result.P34) > 1e-4);
        result.x34Down = double(diff(result.P34) < -1e-4);

        result.Tie12AdjustTimes = 0;
        result.Tie34AdjustTimes = 0;
    end

    if useSenderComplement
        result.P13 = value(P13);
        result.P13Abs = value(P13Abs);
    else
        result.P13 = zeros(1,T);
        result.P13Abs = zeros(1,T);
    end

    result.Pdr_up   = value(Pdr_up);
    result.Pdr_down = value(Pdr_down);

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

    result.C_dr2 = value(C_dr2);
    result.C_dr4 = value(C_dr4);
    result.C_dr  = value(C_dr);

    if isa(C_tie12,'sdpvar')
        result.C_tie12 = value(C_tie12);
    else
        result.C_tie12 = C_tie12;
    end

    if isa(C_tie34,'sdpvar')
        result.C_tie34 = value(C_tie34);
    else
        result.C_tie34 = C_tie34;
    end

    if isa(C_tie13,'sdpvar')
        result.C_tie13 = value(C_tie13);
    else
        result.C_tie13 = C_tie13;
    end

    if isa(C_tie,'sdpvar')
        result.C_tie = value(C_tie);
    else
        result.C_tie = C_tie;
    end

    result.C_thermal = sum(result.C_thermal_region);
    result.C_curt    = sum(result.C_curt_region);
    result.C_shed    = sum(result.C_shed_region);
    result.C_reserve = sum(result.C_reserve_region);
    result.C_es      = sum(result.C_es_region);
    result.C_ps      = sum(result.C_ps_region);

    result = calcFourRegionIndicators(data, result);
end


%% ========================================================================
%% 函数3：指标计算
%% ========================================================================
function result = calcFourRegionIndicators(data, result)

    dt = data.dt;
    N = data.N;

    windCurt = data.WindAva - result.Pwind;
    pvCurt   = data.PvAva   - result.Ppv;

    windCurt(abs(windCurt) < 1e-6) = 0;
    pvCurt(abs(pvCurt) < 1e-6) = 0;

    result.WindCurtail_region_MWh = sum(windCurt,2) * dt;
    result.PvCurtail_region_MWh   = sum(pvCurt,2) * dt;
    result.TotalCurtail_region_MWh = ...
        result.WindCurtail_region_MWh + result.PvCurtail_region_MWh;

    result.WindCurtailRate_region_percent = ...
        100 * result.WindCurtail_region_MWh ./ ...
        max(1e-6, sum(data.WindAva,2) * dt);

    result.PvCurtailRate_region_percent = ...
        100 * result.PvCurtail_region_MWh ./ ...
        max(1e-6, sum(data.PvAva,2) * dt);

    result.CurtailRate_region_percent = ...
        100 * result.TotalCurtail_region_MWh ./ ...
        max(1e-6, sum(data.WindAva + data.PvAva,2) * dt);

    result.TotalCurtail_MWh = sum(result.TotalCurtail_region_MWh);
    result.WindCurtail_MWh  = sum(result.WindCurtail_region_MWh);
    result.PvCurtail_MWh    = sum(result.PvCurtail_region_MWh);

    result.CurtailRate_percent = ...
        100 * result.TotalCurtail_MWh / ...
        max(1e-6, sum(sum(data.WindAva + data.PvAva)) * dt);

    result.WindCurtailRate_percent = ...
        100 * result.WindCurtail_MWh / ...
        max(1e-6, sum(sum(data.WindAva)) * dt);

    result.PvCurtailRate_percent = ...
        100 * result.PvCurtail_MWh / ...
        max(1e-6, sum(sum(data.PvAva)) * dt);

    result.RE_Utilization_region_percent = ...
        100 * sum(result.Pwind + result.Ppv,2) * dt ./ ...
        max(1e-6, sum(data.WindAva + data.PvAva,2) * dt);

    result.RE_Utilization_percent = ...
        100 * sum(sum(result.Pwind + result.Ppv)) * dt / ...
        max(1e-6, sum(sum(data.WindAva + data.PvAva)) * dt);

    %% ---------------------- 新能源渗透率指标 ----------------------------
    % 系统口径：P12、P34、P13为系统内部交换，不重复计入系统总负荷。
    % 分区域口径：按功率平衡中的等效供电责任负荷计算。

    % 新能源消纳电量
    result.RE_Consumed_region_MWh = sum(result.Pwind + result.Ppv,2) * dt;
    result.RE_Consumed_system_MWh = sum(result.RE_Consumed_region_MWh);

    % 火电发电量
    result.ThermalGen_region_MWh = zeros(N,1);
    for n = 1:N
        result.ThermalGen_region_MWh(n) = sum(sum(result.P{n})) * dt;
    end
    result.ThermalGen_system_MWh = sum(result.ThermalGen_region_MWh);

    % 响应后负荷
    LoadAfterDR = data.Load;
    LoadAfterDR(2,:) = data.Load(2,:) - result.Pdr_down(1,:) + result.Pdr_up(1,:);
    LoadAfterDR(4,:) = data.Load(4,:) - result.Pdr_down(2,:) + result.Pdr_up(2,:);

    % 分区域等效供电责任负荷
    EquivalentLoad = zeros(N, data.T);
    EquivalentLoad(1,:) = data.Load(1,:) + result.P12 + result.P13;
    EquivalentLoad(2,:) = LoadAfterDR(2,:) - result.P12;
    EquivalentLoad(3,:) = data.Load(3,:) + result.P34 - result.P13;
    EquivalentLoad(4,:) = LoadAfterDR(4,:) - result.P34;

    result.EquivalentLoad_region_MWh = sum(EquivalentLoad,2) * dt;

    % 系统总负荷量
    result.TotalLoad_system_MWh = sum(sum(LoadAfterDR)) * dt;

    % 火电供电占比
    result.ThermalShare_region_percent = ...
        100 * result.ThermalGen_region_MWh ./ ...
        max(1e-6, result.EquivalentLoad_region_MWh);

    result.ThermalShare_system_percent = ...
        100 * result.ThermalGen_system_MWh / ...
        max(1e-6, result.TotalLoad_system_MWh);

    % 新能源渗透率 = 1 - 火电发电量 / 总负荷量
    result.RE_Penetration_region_percent = ...
        100 * (1 - result.ThermalGen_region_MWh ./ ...
        max(1e-6, result.EquivalentLoad_region_MWh));

    result.RE_Penetration_system_percent = ...
        100 * (1 - result.ThermalGen_system_MWh / ...
        max(1e-6, result.TotalLoad_system_MWh));

    %% ---------------------- 可靠性指标 ----------------------------------
    result.EENS_region_MWh = sum(result.Pshed,2) * dt;
    result.EENS_total_MWh = sum(result.EENS_region_MWh);

    result.LOLH_region_h = sum(result.Pshed > 1e-4, 2);
    result.LOLH_total_h = sum(sum(result.Pshed,1) > 1e-4);

    result.ReserveShort_region_MWh = sum(result.Rshort,2) * dt;
    result.DownReserveShort_region_MWh = sum(result.RdownShort,2) * dt;
    result.ReserveShort_total_MWh = sum(result.ReserveShort_region_MWh);
    result.DownReserveShort_total_MWh = sum(result.DownReserveShort_region_MWh);

    %% ---------------------- 成本指标 ------------------------------------
    result.C_local_region = ...
        result.C_thermal_region(:) + ...
        result.C_curt_region(:)    + ...
        result.C_shed_region(:)    + ...
        result.C_reserve_region(:) + ...
        result.C_es_region(:)      + ...
        result.C_ps_region(:);

    result.C_local_total = sum(result.C_local_region);

    result.C_dr_region = zeros(N,1);
    result.C_dr_region(2) = result.C_dr2;
    result.C_dr_region(4) = result.C_dr4;

    result.C_tie_region = zeros(N,1);

    result.C_tie_region(1) = result.C_tie_region(1) + 0.5 * result.C_tie12;
    result.C_tie_region(2) = result.C_tie_region(2) + 0.5 * result.C_tie12;

    result.C_tie_region(3) = result.C_tie_region(3) + 0.5 * result.C_tie34;
    result.C_tie_region(4) = result.C_tie_region(4) + 0.5 * result.C_tie34;

    result.C_tie_region(1) = result.C_tie_region(1) + 0.5 * result.C_tie13;
    result.C_tie_region(3) = result.C_tie_region(3) + 0.5 * result.C_tie13;

    result.C_total_region = ...
        result.C_local_region + result.C_dr_region + result.C_tie_region;

    %% ---------------------- 通道指标 ------------------------------------
    result.E12_MWh = sum(result.P12) * dt;
    result.E34_MWh = sum(result.P34) * dt;

    result.E13_pos_MWh = sum(max(result.P13,0)) * dt;
    result.E13_neg_MWh = sum(max(-result.P13,0)) * dt;
    result.E13_abs_MWh = sum(abs(result.P13)) * dt;

    result.P12Avg_MW = mean(result.P12);
    result.P34Avg_MW = mean(result.P34);

    result.P12Max_MW = max(result.P12);
    result.P34Max_MW = max(result.P34);

    result.P12Min_MW = min(result.P12);
    result.P34Min_MW = min(result.P34);

    result.P13Max_MW = max(result.P13);
    result.P13Min_MW = min(result.P13);

    result.P12RampStd_MW = std(diff(result.P12));
    result.P34RampStd_MW = std(diff(result.P34));
    result.P13RampStd_MW = std(diff(result.P13));

    result.DR2Up_MWh   = sum(result.Pdr_up(1,:)) * dt;
    result.DR2Down_MWh = sum(result.Pdr_down(1,:)) * dt;
    result.DR4Up_MWh   = sum(result.Pdr_up(2,:)) * dt;
    result.DR4Down_MWh = sum(result.Pdr_down(2,:)) * dt;

    result.StartupTimes_region = zeros(N,1);
    for n = 1:N
        result.StartupTimes_region(n) = sum(sum(result.y{n}));
    end
    result.StartupTimes = sum(result.StartupTimes_region);
end


%% ========================================================================
%% 函数4：汇总表
%% ========================================================================
function summaryTable = makeSummary_fourRegion(Results)

    nCase = length(Results);

    Scenario = strings(nCase,1);

    SystemTotalCost_yuan = nan(nCase,1);
    SystemLocalCost_yuan = nan(nCase,1);

    R1Cost_yuan = nan(nCase,1);
    R2Cost_yuan = nan(nCase,1);
    R3Cost_yuan = nan(nCase,1);
    R4Cost_yuan = nan(nCase,1);

    SystemTotalCurtail_MWh = nan(nCase,1);
    SystemWindCurtail_MWh = nan(nCase,1);
    SystemPvCurtail_MWh = nan(nCase,1);

    R1TotalCurtail_MWh = nan(nCase,1);
    R2TotalCurtail_MWh = nan(nCase,1);
    R3TotalCurtail_MWh = nan(nCase,1);
    R4TotalCurtail_MWh = nan(nCase,1);

    R1WindCurtail_MWh = nan(nCase,1);
    R2WindCurtail_MWh = nan(nCase,1);
    R3WindCurtail_MWh = nan(nCase,1);
    R4WindCurtail_MWh = nan(nCase,1);

    R1PvCurtail_MWh = nan(nCase,1);
    R2PvCurtail_MWh = nan(nCase,1);
    R3PvCurtail_MWh = nan(nCase,1);
    R4PvCurtail_MWh = nan(nCase,1);

    R1CurtailRate_percent = nan(nCase,1);
    R2CurtailRate_percent = nan(nCase,1);
    R3CurtailRate_percent = nan(nCase,1);
    R4CurtailRate_percent = nan(nCase,1);

    R1WindCurtailRate_percent = nan(nCase,1);
    R2WindCurtailRate_percent = nan(nCase,1);
    R3WindCurtailRate_percent = nan(nCase,1);
    R4WindCurtailRate_percent = nan(nCase,1);

    R1PvCurtailRate_percent = nan(nCase,1);
    R2PvCurtailRate_percent = nan(nCase,1);
    R3PvCurtailRate_percent = nan(nCase,1);
    R4PvCurtailRate_percent = nan(nCase,1);

    SystemCurtailRate_percent = nan(nCase,1);
    SystemWindCurtailRate_percent = nan(nCase,1);
    SystemPvCurtailRate_percent = nan(nCase,1);
    SystemREUtil_percent = nan(nCase,1);

    SystemREConsumed_MWh = nan(nCase,1);
    SystemThermalGen_MWh = nan(nCase,1);
    SystemTotalLoad_MWh = nan(nCase,1);
    SystemThermalShare_percent = nan(nCase,1);
    SystemREPenetration_percent = nan(nCase,1);

    R1REPenetration_percent = nan(nCase,1);
    R2REPenetration_percent = nan(nCase,1);
    R3REPenetration_percent = nan(nCase,1);
    R4REPenetration_percent = nan(nCase,1);

    R1ThermalShare_percent = nan(nCase,1);
    R2ThermalShare_percent = nan(nCase,1);
    R3ThermalShare_percent = nan(nCase,1);
    R4ThermalShare_percent = nan(nCase,1);

    R1EquivalentLoad_MWh = nan(nCase,1);
    R2EquivalentLoad_MWh = nan(nCase,1);
    R3EquivalentLoad_MWh = nan(nCase,1);
    R4EquivalentLoad_MWh = nan(nCase,1);

    R1ThermalGen_MWh = nan(nCase,1);
    R2ThermalGen_MWh = nan(nCase,1);
    R3ThermalGen_MWh = nan(nCase,1);
    R4ThermalGen_MWh = nan(nCase,1);

    EENS_total_MWh = nan(nCase,1);
    R1EENS_MWh = nan(nCase,1);
    R2EENS_MWh = nan(nCase,1);
    R3EENS_MWh = nan(nCase,1);
    R4EENS_MWh = nan(nCase,1);

    ReserveShort_total_MWh = nan(nCase,1);
    DownReserveShort_total_MWh = nan(nCase,1);

    E12_MWh = nan(nCase,1);
    E34_MWh = nan(nCase,1);
    E13_abs_MWh = nan(nCase,1);
    E13_R1toR3_MWh = nan(nCase,1);
    E13_R3toR1_MWh = nan(nCase,1);

    P12Max_MW = nan(nCase,1);
    P34Max_MW = nan(nCase,1);
    P13Max_MW = nan(nCase,1);
    P13Min_MW = nan(nCase,1);

    Tie12AdjustTimes = nan(nCase,1);
    Tie34AdjustTimes = nan(nCase,1);

    for k = 1:nCase

        r = Results{k};

        Scenario(k) = string(r.name);

        SystemTotalCost_yuan(k) = r.obj;
        SystemLocalCost_yuan(k) = r.C_local_total;

        R1Cost_yuan(k) = r.C_total_region(1);
        R2Cost_yuan(k) = r.C_total_region(2);
        R3Cost_yuan(k) = r.C_total_region(3);
        R4Cost_yuan(k) = r.C_total_region(4);

        SystemTotalCurtail_MWh(k) = r.TotalCurtail_MWh;
        SystemWindCurtail_MWh(k) = r.WindCurtail_MWh;
        SystemPvCurtail_MWh(k) = r.PvCurtail_MWh;

        R1TotalCurtail_MWh(k) = r.TotalCurtail_region_MWh(1);
        R2TotalCurtail_MWh(k) = r.TotalCurtail_region_MWh(2);
        R3TotalCurtail_MWh(k) = r.TotalCurtail_region_MWh(3);
        R4TotalCurtail_MWh(k) = r.TotalCurtail_region_MWh(4);

        R1WindCurtail_MWh(k) = r.WindCurtail_region_MWh(1);
        R2WindCurtail_MWh(k) = r.WindCurtail_region_MWh(2);
        R3WindCurtail_MWh(k) = r.WindCurtail_region_MWh(3);
        R4WindCurtail_MWh(k) = r.WindCurtail_region_MWh(4);

        R1PvCurtail_MWh(k) = r.PvCurtail_region_MWh(1);
        R2PvCurtail_MWh(k) = r.PvCurtail_region_MWh(2);
        R3PvCurtail_MWh(k) = r.PvCurtail_region_MWh(3);
        R4PvCurtail_MWh(k) = r.PvCurtail_region_MWh(4);

        R1CurtailRate_percent(k) = r.CurtailRate_region_percent(1);
        R2CurtailRate_percent(k) = r.CurtailRate_region_percent(2);
        R3CurtailRate_percent(k) = r.CurtailRate_region_percent(3);
        R4CurtailRate_percent(k) = r.CurtailRate_region_percent(4);

        R1WindCurtailRate_percent(k) = r.WindCurtailRate_region_percent(1);
        R2WindCurtailRate_percent(k) = r.WindCurtailRate_region_percent(2);
        R3WindCurtailRate_percent(k) = r.WindCurtailRate_region_percent(3);
        R4WindCurtailRate_percent(k) = r.WindCurtailRate_region_percent(4);

        R1PvCurtailRate_percent(k) = r.PvCurtailRate_region_percent(1);
        R2PvCurtailRate_percent(k) = r.PvCurtailRate_region_percent(2);
        R3PvCurtailRate_percent(k) = r.PvCurtailRate_region_percent(3);
        R4PvCurtailRate_percent(k) = r.PvCurtailRate_region_percent(4);

        SystemCurtailRate_percent(k) = r.CurtailRate_percent;
        SystemWindCurtailRate_percent(k) = r.WindCurtailRate_percent;
        SystemPvCurtailRate_percent(k) = r.PvCurtailRate_percent;
        SystemREUtil_percent(k) = r.RE_Utilization_percent;

        SystemREConsumed_MWh(k) = r.RE_Consumed_system_MWh;
        SystemThermalGen_MWh(k) = r.ThermalGen_system_MWh;
        SystemTotalLoad_MWh(k) = r.TotalLoad_system_MWh;
        SystemThermalShare_percent(k) = r.ThermalShare_system_percent;
        SystemREPenetration_percent(k) = r.RE_Penetration_system_percent;

        R1REPenetration_percent(k) = r.RE_Penetration_region_percent(1);
        R2REPenetration_percent(k) = r.RE_Penetration_region_percent(2);
        R3REPenetration_percent(k) = r.RE_Penetration_region_percent(3);
        R4REPenetration_percent(k) = r.RE_Penetration_region_percent(4);

        R1ThermalShare_percent(k) = r.ThermalShare_region_percent(1);
        R2ThermalShare_percent(k) = r.ThermalShare_region_percent(2);
        R3ThermalShare_percent(k) = r.ThermalShare_region_percent(3);
        R4ThermalShare_percent(k) = r.ThermalShare_region_percent(4);

        R1EquivalentLoad_MWh(k) = r.EquivalentLoad_region_MWh(1);
        R2EquivalentLoad_MWh(k) = r.EquivalentLoad_region_MWh(2);
        R3EquivalentLoad_MWh(k) = r.EquivalentLoad_region_MWh(3);
        R4EquivalentLoad_MWh(k) = r.EquivalentLoad_region_MWh(4);

        R1ThermalGen_MWh(k) = r.ThermalGen_region_MWh(1);
        R2ThermalGen_MWh(k) = r.ThermalGen_region_MWh(2);
        R3ThermalGen_MWh(k) = r.ThermalGen_region_MWh(3);
        R4ThermalGen_MWh(k) = r.ThermalGen_region_MWh(4);

        EENS_total_MWh(k) = r.EENS_total_MWh;
        R1EENS_MWh(k) = r.EENS_region_MWh(1);
        R2EENS_MWh(k) = r.EENS_region_MWh(2);
        R3EENS_MWh(k) = r.EENS_region_MWh(3);
        R4EENS_MWh(k) = r.EENS_region_MWh(4);

        ReserveShort_total_MWh(k) = r.ReserveShort_total_MWh;
        DownReserveShort_total_MWh(k) = r.DownReserveShort_total_MWh;

        E12_MWh(k) = r.E12_MWh;
        E34_MWh(k) = r.E34_MWh;
        E13_abs_MWh(k) = r.E13_abs_MWh;
        E13_R1toR3_MWh(k) = r.E13_pos_MWh;
        E13_R3toR1_MWh(k) = r.E13_neg_MWh;

        P12Max_MW(k) = r.P12Max_MW;
        P34Max_MW(k) = r.P34Max_MW;
        P13Max_MW(k) = r.P13Max_MW;
        P13Min_MW(k) = r.P13Min_MW;

        Tie12AdjustTimes(k) = r.Tie12AdjustTimes;
        Tie34AdjustTimes(k) = r.Tie34AdjustTimes;
    end

    summaryTable = table( ...
        Scenario, ...
        SystemTotalCost_yuan, SystemLocalCost_yuan, ...
        R1Cost_yuan, R2Cost_yuan, R3Cost_yuan, R4Cost_yuan, ...
        SystemTotalCurtail_MWh, SystemWindCurtail_MWh, SystemPvCurtail_MWh, ...
        SystemCurtailRate_percent, SystemWindCurtailRate_percent, SystemPvCurtailRate_percent, SystemREUtil_percent, ...
        SystemREConsumed_MWh, SystemThermalGen_MWh, SystemTotalLoad_MWh, ...
        SystemThermalShare_percent, SystemREPenetration_percent, ...
        R1REPenetration_percent, R2REPenetration_percent, R3REPenetration_percent, R4REPenetration_percent, ...
        R1ThermalShare_percent, R2ThermalShare_percent, R3ThermalShare_percent, R4ThermalShare_percent, ...
        R1EquivalentLoad_MWh, R2EquivalentLoad_MWh, R3EquivalentLoad_MWh, R4EquivalentLoad_MWh, ...
        R1ThermalGen_MWh, R2ThermalGen_MWh, R3ThermalGen_MWh, R4ThermalGen_MWh, ...
        R1TotalCurtail_MWh, R2TotalCurtail_MWh, R3TotalCurtail_MWh, R4TotalCurtail_MWh, ...
        R1WindCurtail_MWh, R2WindCurtail_MWh, R3WindCurtail_MWh, R4WindCurtail_MWh, ...
        R1PvCurtail_MWh, R2PvCurtail_MWh, R3PvCurtail_MWh, R4PvCurtail_MWh, ...
        R1CurtailRate_percent, R2CurtailRate_percent, R3CurtailRate_percent, R4CurtailRate_percent, ...
        R1WindCurtailRate_percent, R2WindCurtailRate_percent, R3WindCurtailRate_percent, R4WindCurtailRate_percent, ...
        R1PvCurtailRate_percent, R2PvCurtailRate_percent, R3PvCurtailRate_percent, R4PvCurtailRate_percent, ...
        EENS_total_MWh, R1EENS_MWh, R2EENS_MWh, R3EENS_MWh, R4EENS_MWh, ...
        ReserveShort_total_MWh, DownReserveShort_total_MWh, ...
        E12_MWh, E34_MWh, E13_abs_MWh, E13_R1toR3_MWh, E13_R3toR1_MWh, ...
        P12Max_MW, P34Max_MW, P13Max_MW, P13Min_MW, Tie12AdjustTimes, Tie34AdjustTimes);
end


%% ========================================================================
%% 函数5：打印结果
%% ========================================================================
function printResult_fourRegion(result)

    fprintf('\n-------------------- 场景结果：%s --------------------\n', result.name);

    fprintf('\n成本指标：\n');
    fprintf('系统总运行成本：%.2f 万元\n', result.obj/1e4);
    fprintf('系统本地运行成本合计（不含需求响应/通道成本）：%.2f 万元\n', result.C_local_total/1e4);
    for n = 1:4
        fprintf('区域%d总运行成本：%.2f 万元\n', n, result.C_total_region(n)/1e4);
    end

    fprintf('\n分区域成本构成：\n');
    for n = 1:4
        fprintf('区域%d火电成本：%.2f 万元，弃风弃光成本：%.2f 万元，失负荷成本：%.2f 万元，备用不足成本：%.2f 万元\n', ...
            n, result.C_thermal_region(n)/1e4, result.C_curt_region(n)/1e4, ...
            result.C_shed_region(n)/1e4, result.C_reserve_region(n)/1e4);
    end

    fprintf('\n可靠性指标：\n');
    fprintf('系统EENS：%.2f MWh\n', result.EENS_total_MWh);
    for n = 1:4
        fprintf('区域%d EENS：%.2f MWh，LOLH：%.0f h\n', ...
            n, result.EENS_region_MWh(n), result.LOLH_region_h(n));
    end
    fprintf('系统正备用不足：%.2f MWh\n', result.ReserveShort_total_MWh);
    fprintf('系统负备用不足：%.2f MWh\n', result.DownReserveShort_total_MWh);

    fprintf('\n新能源消纳指标（系统总区域合计）：\n');
    fprintf('系统弃风弃光总电量：%.2f MWh\n', result.TotalCurtail_MWh);
    fprintf('系统弃风电量：%.2f MWh\n', result.WindCurtail_MWh);
    fprintf('系统弃光电量：%.2f MWh\n', result.PvCurtail_MWh);
    fprintf('系统总弃风弃光率：%.2f %%\n', result.CurtailRate_percent);
    fprintf('系统弃风率：%.2f %%\n', result.WindCurtailRate_percent);
    fprintf('系统弃光率：%.2f %%\n', result.PvCurtailRate_percent);
    fprintf('系统新能源消纳率：%.2f %%\n', result.RE_Utilization_percent);

    fprintf('\n新能源渗透率指标（系统总口径）：\n');
    fprintf('系统新能源消纳电量：%.2f MWh\n', result.RE_Consumed_system_MWh);
    fprintf('系统火电发电量：%.2f MWh\n', result.ThermalGen_system_MWh);
    fprintf('系统总负荷量：%.2f MWh\n', result.TotalLoad_system_MWh);
    fprintf('系统火电供电占比：%.2f %%\n', result.ThermalShare_system_percent);
    fprintf('系统新能源渗透率，按1-火电/总负荷计算：%.2f %%\n', ...
        result.RE_Penetration_system_percent);

    fprintf('\n新能源消纳与渗透指标（分区域）：\n');
    for n = 1:4
        fprintf('区域%d弃风弃光电量：%.2f MWh，其中弃风 %.2f MWh，弃光 %.2f MWh\n', ...
            n, result.TotalCurtail_region_MWh(n), ...
            result.WindCurtail_region_MWh(n), ...
            result.PvCurtail_region_MWh(n));

        fprintf('区域%d总弃风弃光率：%.2f %%，弃风率：%.2f %%，弃光率：%.2f %%，新能源消纳率：%.2f %%\n', ...
            n, result.CurtailRate_region_percent(n), ...
            result.WindCurtailRate_region_percent(n), ...
            result.PvCurtailRate_region_percent(n), ...
            result.RE_Utilization_region_percent(n));

        fprintf('区域%d等效供电责任负荷：%.2f MWh，火电发电量：%.2f MWh，火电占比：%.2f %%，新能源渗透率：%.2f %%\n', ...
            n, ...
            result.EquivalentLoad_region_MWh(n), ...
            result.ThermalGen_region_MWh(n), ...
            result.ThermalShare_region_percent(n), ...
            result.RE_Penetration_region_percent(n));
    end

    fprintf('\n两直流与送端互补指标：\n');
    fprintf('直流1外送电量 E12：%.2f MWh，平均功率：%.2f MW，最大功率：%.2f MW，调整次数：%.0f 次\n', ...
        result.E12_MWh, result.P12Avg_MW, result.P12Max_MW, result.Tie12AdjustTimes);
    fprintf('直流2外送电量 E34：%.2f MWh，平均功率：%.2f MW，最大功率：%.2f MW，调整次数：%.0f 次\n', ...
        result.E34_MWh, result.P34Avg_MW, result.P34Max_MW, result.Tie34AdjustTimes);
    fprintf('送端互补通道绝对交换电量：%.2f MWh\n', result.E13_abs_MWh);
    fprintf('区域1送区域3电量：%.2f MWh\n', result.E13_pos_MWh);
    fprintf('区域3送区域1电量：%.2f MWh\n', result.E13_neg_MWh);
    fprintf('P13最大值：%.2f MW，P13最小值：%.2f MW\n', ...
        result.P13Max_MW, result.P13Min_MW);

    fprintf('\n受端需求响应指标：\n');
    fprintf('区域2负荷上调：%.2f MWh，下调：%.2f MWh\n', result.DR2Up_MWh, result.DR2Down_MWh);
    fprintf('区域4负荷上调：%.2f MWh，下调：%.2f MWh\n', result.DR4Up_MWh, result.DR4Down_MWh);
end


%% ========================================================================
%% 函数6：输入数据图
%% ========================================================================
function plotInput_fourRegion(data)

    t = 1:data.T;

    figure('Name','四区域输入数据');

    subplot(4,1,1);
    plot(t, data.Load', 'LineWidth', 1.3);
    ylabel('负荷/MW');
    title('四区域本地负荷');
    legend(data.nodeName,'Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,2);
    plot(t, data.WindAva', 'LineWidth', 1.3);
    ylabel('风电/MW');
    title('四区域风电可用出力');
    legend(data.nodeName,'Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,3);
    plot(t, data.PvAva', 'LineWidth', 1.3);
    ylabel('光伏/MW');
    title('四区域光伏可用出力');
    legend(data.nodeName,'Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(4,1,4);
    plot(t, data.P12Fixed, 'LineWidth', 1.5);
    hold on;
    plot(t, data.P34Fixed, 'LineWidth', 1.5);
    xlabel('时段/h');
    ylabel('固定外送/MW');
    title('固定外送曲线');
    legend('直流1：区域1→区域2','直流2：区域3→区域4','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数7：通道曲线图
%% ========================================================================
function plotTie_fourRegion(data, result)

    t = 1:data.T;

    figure('Name',['通道功率曲线 - ', result.name]);

    subplot(3,1,1);
    plot(t, data.P12Fixed, 'k--', 'LineWidth', 1.3);
    hold on;
    plot(t, result.P12, 'LineWidth', 1.8);
    yline(data.Tie12Max, ':', '直流1上限', 'HandleVisibility','off');
    ylabel('P12/MW');
    title(['直流通道1：区域1→区域2 - ', result.name]);
    legend('固定外送','实际/优化外送','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(3,1,2);
    plot(t, data.P34Fixed, 'k--', 'LineWidth', 1.3);
    hold on;
    plot(t, result.P34, 'LineWidth', 1.8);
    yline(data.Tie34Max, ':', '直流2上限', 'HandleVisibility','off');
    ylabel('P34/MW');
    title(['直流通道2：区域3→区域4 - ', result.name]);
    legend('固定外送','实际/优化外送','Location','best');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);

    subplot(3,1,3);
    plot(t, result.P13, 'Color', [1.00 0.40 0.70], 'LineWidth', 1.8);
    yline(0, 'k-', 'HandleVisibility','off');
    yline(data.Tie13Max, ':', '互补通道上限', 'HandleVisibility','off');
    yline(-data.Tie13Max, ':', '互补通道下限', 'HandleVisibility','off');
    xlabel('时段/h');
    ylabel('P13/MW');
    title('送端互补通道：P13>0为区域1送区域3，P13<0为区域3送区域1');
    grid on;
    xlim([1 data.T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数8：新能源消纳与弃电图
%% ========================================================================
function plotCurtail_fourRegion(data, result)

    T = data.T;
    t = 1:T;

    windCurt = data.WindAva - result.Pwind;
    pvCurt   = data.PvAva   - result.Ppv;

    figure('Name',['新能源消纳与弃电 - ', result.name]);

    subplot(2,1,1);
    plot(t, (data.WindAva + data.PvAva)', '--', 'LineWidth', 1.0);
    hold on;
    plot(t, (result.Pwind + result.Ppv)', '-', 'LineWidth', 1.4);
    ylabel('风光功率/MW');
    title(['四区域风光可用与消纳 - ', result.name]);
    grid on;
    xlim([1 T]);
    addDayLines(data);

    subplot(2,1,2);
    bar(t, [windCurt(1,:)', pvCurt(1,:)', ...
            windCurt(2,:)', pvCurt(2,:)', ...
            windCurt(3,:)', pvCurt(3,:)', ...
            windCurt(4,:)', pvCurt(4,:)'], 'stacked');
    xlabel('时段/h');
    ylabel('弃电功率/MW');
    title('四区域弃风弃光');
    legend('区1弃风','区1弃光','区2弃风','区2弃光', ...
           '区3弃风','区3弃光','区4弃风','区4弃光', ...
           'Location','best');
    grid on;
    xlim([1 T]);
    addDayLines(data);
end


%% ========================================================================
%% 函数9：四区域电力平衡图
%% ========================================================================
function plotPowerBalance_fourRegion(data, result)

    T = data.T;
    t = 1:T;

    for n = 1:data.N

        Pth = sum(result.P{n},1);

        if n == 1
            BalanceBar = [ ...
                Pth(:), result.Pwind(n,:)', result.Ppv(n,:)', ...
                result.Pdis(n,:)', result.Pps_gen(n,:)', result.Pshed(n,:)', ...
               -result.Pch(n,:)', -result.Pps_pump(n,:)', ...
               -result.P12(:), -result.P13(:)];

            loadLine = data.Load(n,:);

            legendText = {'火电','风电','光伏','储能放电','抽蓄发电','切负荷', ...
                          '储能充电','抽蓄抽水','直流1外送P12','送端互补P13','本地负荷'};

            colorType = 'sender';

            BalanceError = ...
                Pth + result.Pwind(n,:) + result.Ppv(n,:) ...
                + result.Pdis(n,:) + result.Pps_gen(n,:) + result.Pshed(n,:) ...
                - result.Pch(n,:) - result.Pps_pump(n,:) ...
                - result.P12 - result.P13 - data.Load(n,:);

        elseif n == 2
            LoadAfterDR = data.Load(n,:) - result.Pdr_down(1,:) + result.Pdr_up(1,:);

            BalanceBar = [ ...
                Pth(:), result.Pwind(n,:)', result.Ppv(n,:)', result.P12(:), ...
                result.Pdis(n,:)', result.Pps_gen(n,:)', result.Pshed(n,:)', ...
               -result.Pch(n,:)', -result.Pps_pump(n,:)'];

            loadLine = LoadAfterDR;

            legendText = {'火电','风电','光伏','直流1受电P12','储能放电','抽蓄发电','切负荷', ...
                          '储能充电','抽蓄抽水','响应后负荷'};

            colorType = 'receiver';

            BalanceError = ...
                Pth + result.Pwind(n,:) + result.Ppv(n,:) + result.P12 ...
                + result.Pdis(n,:) + result.Pps_gen(n,:) + result.Pshed(n,:) ...
                - result.Pch(n,:) - result.Pps_pump(n,:) - LoadAfterDR;

        elseif n == 3
            BalanceBar = [ ...
                Pth(:), result.Pwind(n,:)', result.Ppv(n,:)', ...
                result.Pdis(n,:)', result.Pps_gen(n,:)', result.Pshed(n,:)', ...
               -result.Pch(n,:)', -result.Pps_pump(n,:)', ...
               -result.P34(:), result.P13(:)];

            loadLine = data.Load(n,:);

            legendText = {'火电','风电','光伏','储能放电','抽蓄发电','切负荷', ...
                          '储能充电','抽蓄抽水','直流2外送P34','送端互补P13','本地负荷'};

            colorType = 'sender';

            BalanceError = ...
                Pth + result.Pwind(n,:) + result.Ppv(n,:) ...
                + result.Pdis(n,:) + result.Pps_gen(n,:) + result.Pshed(n,:) ...
                - result.Pch(n,:) - result.Pps_pump(n,:) ...
                - result.P34 + result.P13 - data.Load(n,:);

        else
            LoadAfterDR = data.Load(n,:) - result.Pdr_down(2,:) + result.Pdr_up(2,:);

            BalanceBar = [ ...
                Pth(:), result.Pwind(n,:)', result.Ppv(n,:)', result.P34(:), ...
                result.Pdis(n,:)', result.Pps_gen(n,:)', result.Pshed(n,:)', ...
               -result.Pch(n,:)', -result.Pps_pump(n,:)'];

            loadLine = LoadAfterDR;

            legendText = {'火电','风电','光伏','直流2受电P34','储能放电','抽蓄发电','切负荷', ...
                          '储能充电','抽蓄抽水','响应后负荷'};

            colorType = 'receiver';

            BalanceError = ...
                Pth + result.Pwind(n,:) + result.Ppv(n,:) + result.P34 ...
                + result.Pdis(n,:) + result.Pps_gen(n,:) + result.Pshed(n,:) ...
                - result.Pch(n,:) - result.Pps_pump(n,:) - LoadAfterDR;
        end

        figure('Name',[data.nodeName{n}, ' 电力平衡 - ', result.name]);

        b = bar(t, BalanceBar, 'stacked');
        hold on;

        setPowerBalanceBarColors(b, colorType);

        plot(t, loadLine, 'k-', 'LineWidth', 1.8);
        yline(0, 'k-', 'HandleVisibility','off');

        xlabel('时段/h');
        ylabel('功率/MW');
        title([data.nodeName{n}, ' 电力平衡 - ', result.name]);

        legend(legendText,'Location','best');

        grid on;
        xlim([1 T]);
        addDayLines(data);

        fprintf('%s：%s功率平衡最大误差 = %.6f MW\n', ...
            result.name, data.nodeName{n}, max(abs(BalanceError)));
    end
end


%% ========================================================================
%% 函数10：电力平衡图颜色设置
%% ========================================================================
function setPowerBalanceBarColors(b, colorType)

    if strcmp(colorType, 'sender')
        colors = [ ...
            0.60 0.60 0.60;   % 火电
            0.90 0.30 0.10;   % 风电
            0.96 0.72 0.10;   % 光伏
            0.50 0.20 0.70;   % 储能放电
            0.35 0.65 0.20;   % 抽蓄发电
            0.35 0.75 0.95;   % 切负荷
            0.70 0.05 0.20;   % 储能充电
            0.00 0.35 0.60;   % 抽蓄抽水
            0.95 0.40 0.05;   % 直流外送P12/P34
            1.00 0.40 0.70];  % 送端互补P13

    else
        colors = [ ...
            0.60 0.60 0.60;   % 火电
            0.90 0.30 0.10;   % 风电
            0.96 0.72 0.10;   % 光伏
            0.95 0.40 0.05;   % 直流受电P12/P34
            0.50 0.20 0.70;   % 储能放电
            0.35 0.65 0.20;   % 抽蓄发电
            0.35 0.75 0.95;   % 切负荷
            0.70 0.05 0.20;   % 储能充电
            0.00 0.35 0.60];  % 抽蓄抽水
    end

    for i = 1:min(length(b), size(colors,1))
        b(i).FaceColor = colors(i,:);
        b(i).EdgeColor = 'none';
    end
end


%% ========================================================================
%% 函数11：火电机组堆叠图
%% ========================================================================
function plotThermal_fourRegion(data, result)

    T = data.T;
    t = 1:T;
    G = data.G;

    for n = 1:data.N

        unitNames = cell(G,1);
        for g = 1:G
            unitNames{g} = ['G', num2str(g)];
        end

        figure('Name',[data.nodeName{n}, ' 火电机组堆叠出力 - ', result.name]);

        b = bar(t, result.P{n}', 'stacked');

        grayVals = linspace(0.35, 0.80, G);
        for gg = 1:min(numel(b),G)
            b(gg).FaceColor = [grayVals(gg) grayVals(gg) grayVals(gg)];
            b(gg).EdgeColor = 'none';
        end

        xlabel('时段/h');
        ylabel('火电出力/MW');
        title([data.nodeName{n}, ' 火电机组堆叠出力 - ', result.name]);
        legend(unitNames, 'Location','eastoutside');
        grid on;
        xlim([1 T]);
        addDayLines(data);
    end
end


%% ========================================================================
%% 函数12：失败填充
%% ========================================================================
function result = fillFailedFourRegion(result, T, G)

    N = 4;

    result.obj = NaN;

    result.P = cell(N,1);
    result.u = cell(N,1);
    result.y = cell(N,1);
    result.z = cell(N,1);

    for n = 1:N
        result.P{n} = nan(G,T);
        result.u{n} = nan(G,T);
        result.y{n} = nan(G,T);
        result.z{n} = nan(G,T);
    end

    result.Pwind = nan(N,T);
    result.Ppv = nan(N,T);
    result.Pch = nan(N,T);
    result.Pdis = nan(N,T);
    result.Ees = nan(N,T+1);
    result.Pps_pump = nan(N,T);
    result.Pps_gen = nan(N,T);
    result.Eps = nan(N,T+1);
    result.Pshed = nan(N,T);
    result.Rshort = nan(N,T);
    result.RdownShort = nan(N,T);

    result.P12 = nan(1,T);
    result.P34 = nan(1,T);
    result.P13 = nan(1,T);
    result.P13Abs = nan(1,T);

    result.Pdr_up = nan(2,T);
    result.Pdr_down = nan(2,T);

    fields = { ...
        'C_thermal','C_curt','C_shed','C_reserve','C_es','C_ps','C_dr','C_tie', ...
        'C_local_total', ...
        'EENS_total_MWh','ReserveShort_total_MWh','DownReserveShort_total_MWh', ...
        'CurtailRate_percent','WindCurtailRate_percent','PvCurtailRate_percent', ...
        'RE_Utilization_percent', ...
        'RE_Consumed_system_MWh','ThermalGen_system_MWh','TotalLoad_system_MWh', ...
        'ThermalShare_system_percent','RE_Penetration_system_percent', ...
        'E12_MWh','E34_MWh','E13_abs_MWh', ...
        'E13_pos_MWh','E13_neg_MWh','P12Max_MW','P34Max_MW','P13Max_MW','P13Min_MW', ...
        'Tie12AdjustTimes','Tie34AdjustTimes','StartupTimes', ...
        'WindCurtail_MWh','PvCurtail_MWh','TotalCurtail_MWh'};

    for i = 1:length(fields)
        result.(fields{i}) = NaN;
    end

    result.C_thermal_region = nan(N,1);
    result.C_curt_region = nan(N,1);
    result.C_shed_region = nan(N,1);
    result.C_reserve_region = nan(N,1);
    result.C_es_region = nan(N,1);
    result.C_ps_region = nan(N,1);

    result.C_local_region = nan(N,1);
    result.C_dr_region = nan(N,1);
    result.C_tie_region = nan(N,1);
    result.C_total_region = nan(N,1);

    result.EENS_region_MWh = nan(N,1);
    result.LOLH_region_h = nan(N,1);

    result.WindCurtail_region_MWh = nan(N,1);
    result.PvCurtail_region_MWh = nan(N,1);
    result.TotalCurtail_region_MWh = nan(N,1);

    result.WindCurtailRate_region_percent = nan(N,1);
    result.PvCurtailRate_region_percent = nan(N,1);
    result.CurtailRate_region_percent = nan(N,1);
    result.RE_Utilization_region_percent = nan(N,1);

    result.RE_Consumed_region_MWh = nan(N,1);
    result.ThermalGen_region_MWh = nan(N,1);
    result.EquivalentLoad_region_MWh = nan(N,1);
    result.ThermalShare_region_percent = nan(N,1);
    result.RE_Penetration_region_percent = nan(N,1);
end


%% ========================================================================
%% 函数13：日分隔线
%% ========================================================================
function addDayLines(data)
    for d = 1:data.D
        xline((d-1)*24 + 1, ':', 'HandleVisibility','off');
    end
end