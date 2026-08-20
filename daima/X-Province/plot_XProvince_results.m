function plot_XProvince_results(results)
%PLOT_XINJIANG_RESULTS 按论文图例风格绘制一个 168 小时优化块。

cfg = results.cfg;
first = (cfg.plotBlock-1)*cfg.hoursPerBlock + 1;
if first > numel(results.time)
    warning('plotBlock=%d 超过已求解范围，不生成图。', cfg.plotBlock);
    return;
end
last = min(first+cfg.hoursPerBlock-1, numel(results.time));
k = first:last;
hour = (0:numel(k)-1)';

% 当前新疆机组表没有核电，仍保留 Nuclear=0，便于与论文图例一致。
% 弃风、弃光叠加在有效出力上方，仅用于同轴展示，不参与负荷平衡。
nuclear = zeros(numel(k),1);
stack = [nuclear,results.pCoal(k),results.pHydro(k),results.pGas(k), ...
    results.pWind(k),results.pSolar(k),results.storageDischarge(k),results.nse(k), ...
    results.windCurtailment(k),results.solarCurtailment(k)];
colors = [1.00 0.39 0.30; ... % Nuclear
          0.42 0.42 0.42; ... % Coal
          0.00 0.68 0.90; ... % Hydro
          0.86 0.36 0.86; ... % Gas
          0.18 0.80 0.18; ... % Wind
          1.00 0.62 0.00; ... % Solar
          1.00 0.90 0.00; ... % Stor
          0.85 0.02 0.15; ... % Nse
          0.60 0.92 0.60; ... % Wind curtailment
          1.00 0.82 0.45];    % Solar curtailment

fig = figure('Visible','off','Color','w','Position',[100 100 1200 720]);
axDispatch = axes(fig);
hArea = area(axDispatch,hour,stack,'LineStyle','none');
for i = 1:numel(hArea)
    hArea(i).FaceColor = colors(i,:);
end
hArea(9).FaceAlpha = 0.72;
hArea(10).FaceAlpha = 0.72;
hArea(9).EdgeColor = colors(5,:);
hArea(10).EdgeColor = colors(6,:);
hold(axDispatch,'on');
% 采用电力平衡常用符号：充电是系统用电，因此画在零轴以下。
chargeSigned = -results.storageCharge(k);
hChargeArea = area(axDispatch,hour,chargeSigned,'LineStyle','none','BaseValue',0);
hChargeArea.FaceColor = [0.50 0.10 0.72];
hChargeArea.FaceAlpha = 0.90;
hLoad = plot(axDispatch, hour, results.loadMW(k), 'k--', 'LineWidth', 1.7);
yline(axDispatch,0,'k-','LineWidth',0.8,'HandleVisibility','off');
hold(axDispatch,'off');
box(axDispatch,'on');
grid(axDispatch,'off');
ylabel(axDispatch,'Power (MW)');
xlabel(axDispatch,'Hour');
title(axDispatch,sprintf('Xinjiang UCED - Week %d: Dispatch, Curtailment and Charging', ...
    cfg.plotBlock));
xlim(axDispatch,[0,numel(k)]);
xticks(axDispatch,0:24:numel(k));
ytickformat(axDispatch,'%,.0f');
ylim(axDispatch,[1.08*min([chargeSigned;-1]),1.05*max(sum(stack,2))]);
lgd = legend([hLoad,hArea(8),hArea(7),hArea(6),hArea(5),hArea(4), ...
    hArea(3),hArea(2),hArea(1),hArea(9),hArea(10),hChargeArea], ...
    {'Demand','Nse','Stor','Solar','Wind','Gas','Hydro','Coal','Nuclear', ...
     'Wind curtailment','Solar curtailment','Charge (negative)'}, ...
    'Location','eastoutside');
lgd.Title.String = 'Tech';
set(axDispatch,'FontName','Arial','FontSize',11,'LineWidth',0.8);

exportgraphics(fig, fullfile(cfg.runDir, sprintf('dispatch_block_%03d.png',cfg.plotBlock)), ...
    'Resolution',180);
close(fig);
end
