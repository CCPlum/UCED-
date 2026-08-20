# 新疆 2025 单区域 UCED（MATLAB）

本程序参考论文的 UCED 数学结构和原 Julia/JuMP 实现，使用 MATLAB 构建混合整数线性规划（MILP）。初步把新疆视为一个节点，只满足新疆本地负荷，不考虑疆电外送、跨省中长期合同和新疆内部输电阻塞。

## 程序文件及调用关系


| 文件 | 作用 |
|---|---|
| `run_xinjiang_uced.m` | 唯一运行入口，组织数据读取、逐周求解、校验、导出和绘图 |
| `xinjiang_uced_config.m` | 集中设置容量、效率、备用、供暖期、循环方式和求解器参数 |
| `load_xinjiang_inputs.m` | 读取两份 Excel，筛选新疆机组，并加入20,000 MW/80,000 MWh新型储能 |
| `solve_xinjiang_block.m` | 建立一个168小时UCED混合整数模型及全部运行约束 |
| `solve_milp_model.m` | 将模型交给 Gurobi；没有 Gurobi 时可转用 `intlinprog` |
| `validate_xinjiang_results.m` | 检查功率平衡、备用、整数变量及储能日/周循环 |
| `export_xinjiang_results.m` | 导出小时级、机组级和储能级 CSV、假设说明等结果 |
| `plot_xinjiang_results.m` | 生成最终单图：出力与弃电向上、充电按负值向下 |

主调用顺序为：`run_xinjiang_uced` → 配置与数据读取 → 分块建模与求解 → 校验 → 导出与绘图。

## 1. 输入文件

程序直接读取同一文件夹内的：

- `风光出力及负荷曲线.xlsx`：8760 小时的 `solar_xinjiang`、`wind_xinjiang` 和 `load_xinjiang`；
- `西北地区_Generators_data_运行机组.xlsx`：从 `Generators_data` 工作表筛选 `region="XJ"`。

当前筛选结果：

- 煤电 228 条记录，其中热电联产 CHP 164 条；
- 气电 0 条记录（程序已预留气电分类和成本参数）；
- 常规水电 47 条；
- 抽水蓄能 1 条（1200 MW、9600 MWh）；
- 新增全疆聚合新型储能1条（20,000 MW、80,000 MWh）；
- 光伏项目 655 条、合计 91,668 MW；
- 风电项目 428 条、合计 67,722.8 MW。

煤电、气电、水电和储能保留机组级变量；风电与光伏使用工作簿给出的全疆聚合可用出力曲线，避免把同一条全疆曲线重复赋给每个新能源项目。热电联产只在模型内部用于供暖期开机约束，结果表和图中统一并入煤电，不再单列 CHP。

## 2. 模型包含的决策和约束

### 目标函数

最小化：

1. 煤电、气电燃料和可变运维成本；
2. 煤电、气电启动成本和启动燃料成本；
3. 水电及抽蓄循环成本；
4. 弃风、弃光惩罚；
5. 未满足负荷（NSE）高额惩罚。

### 主要约束

- 新疆单节点逐小时功率平衡；
- 煤电和气电最大/最小出力；
- 启动、停机与运行状态转换；
- 爬坡约束；
- 最小开机时间和最小停机时间；
- 供暖时段 CHP 强制开机；
- 风电、光伏出力不超过逐小时可用功率；
- 常规水电容量及周发电量上限；
- 储能充放电互斥、充放电效率和 SOC；
- 抽水蓄能每168小时回到周初SOC；
- 电化学储能每24小时回到日初SOC；
- 上、下备用约束；
- 最大单台常规机组事故备用；
- 允许 NSE 保证极端情况下模型仍可行。

程序按照论文的做法，以 168 小时为一个优化块滚动求解。2025 年共 8760 小时，即 52 个完整周加最后 24 小时。

## 3. 运行方式

在 MATLAB 中进入本文件夹：

```matlab
cd('E:\研究生\博一\资源充裕度\JEPO_ResourceAdequacy_2026-main\新疆模型程序')
```

先运行一个 24 小时快速测试：

```matlab
results = run_xinjiang_uced(struct( ...
    'hoursPerBlock', 24, ...
    'maxBlocks', 1, ...
    'timeLimitSec', 120));
```

确认运行正常后，运行全年：

```matlab
results = run_xinjiang_uced();
```

也可以只运行一个完整周：

```matlab
results = run_xinjiang_uced(struct('maxBlocks',1));
```

## 4. 求解器

`cfg.solver="auto"` 时：

1. 如果 MATLAB 路径中存在 Gurobi 接口，优先使用 Gurobi；
2. 否则使用 Optimization Toolbox 的 `intlinprog`。

手动指定：

```matlab
results = run_xinjiang_uced(struct('solver','gurobi'));
```

或：

```matlab
results = run_xinjiang_uced(struct('solver','intlinprog'));
```

## 5. 输出文件

每次运行在 `results/run_时间戳/` 下生成：

- `Xinjiang_UCED_2025_full_year.xlsx`：单一全年结果工作簿，包含：
  - `Summary`、`Assumptions`：全年指标与建模假设；
  - `Weekly_Summary`：52个完整周和最后24小时块的分块电量汇总；
  - `Hourly_All`：8760小时负荷、电源出力、储能、弃电、NSE、备用和成本；
  - `Block_Status`、`Validation`：53个优化块的求解状态和全年数值校验；
  - `Thermal_Units`、`Hydro_Units`、`Storage_Units`：实际进入模型的机组参数；
  - `Storage_Charge`、`Storage_Discharge`、`Storage_SOC`：两类储能的8760小时时序；
- `xinjiang_uced_results.mat`：完整MATLAB结果，包括每台火电的8760小时出力、启停、启动和水电机组级时序；
- `dispatch_block_001.png`：单坐标轴综合图；有效出力和弃风弃光向上堆叠，储能充电按负值画在零轴以下；
- `run_assumptions.txt`：本次运行采用的关键假设。

## 6. 当前必须注意的假设

这些不是原始数据给出的事实，而是为了让模型可运行设置的默认值，集中在 `xinjiang_uced_config.m` 中：

| 参数 | 默认值 | 说明 |
|---|---:|---|
| 煤电计划检修折减 | 15% | 参考论文基准处理 |
| 煤价 | 4.5 成本单位/MMBtu | 缺少新疆 2025 煤价，正式研究必须替换 |
| 气价 | 10.0 成本单位/MMBtu | 当前数据没有气电，仅供未来增加气电机组时使用 |
| 负荷备用 | 5% | 参考原程序 |
| 新能源备用 | 10% | 参考原程序 |
| 常规水电周容量因子 | 40% | 缺少逐小时水文入流的代理 |
| 抽蓄初始 SOC | 10% | 参考原程序，且周末回到周初 |
| 新型储能规模 | 20,000 MW / 80,000 MWh | 用户给定的全疆聚合等值装机 |
| 新型储能效率 | 充电95%、放电95% | 缺少实测参数的可修改假设，往返效率约90.25% |
| 储能循环 | 抽蓄每周、新型储能每日 | 与参考论文的统一周循环处理不同 |
| 代表性供暖期 | 1月1日-4月10日、10月10日-12月31日 | 全疆并不统一；单节点模型采用乌鲁木齐法定日期作为代理 |
