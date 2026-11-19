%% FIGURE B (v2): exclusion-threshold sensitivity, all three samples
clear; clc; close all;

root = fullfile(getenv('USERPROFILE'), 'Downloads', 'slow_prior-main', ...
    'slow_prior-main', 'data_participants');
folders = {'experiment1','experiment2','replication'};
titles  = {'experiment 1','experiment 2','replication'};
nTr     = [45 60 60];
ths     = [0 71/120 0.65 0.70];                  % 0 = no exclusion
thName  = {'no exclusion','paper rule (\geq0.592)','\geq0.65','\geq0.70'};
cols    = [0.55 0.55 0.55; 0 0 0; 0.85 0.33 0.10; 0.00 0.45 0.74];

pick  = @(lvn, c) find(ismember(lvn, c), 1);
toNum = @(x) str2double(replace(replace(lower(string(x)), "true", "1"), "false", "0"));

figure('Position', [100 100 1250 420]);
for k = 1:3
    f = dir(fullfile(root, folders{k}, '*train*.csv'));
    T = readtable(fullfile(f(1).folder, f(1).name), 'TreatAsMissing', {'NA','N/A','NaN','nan',''});
    vn = T.Properties.VariableNames;  lvn = lower(vn);
    iS = pick(lvn, {'subject','subj','id','participant','participant_id','subject_id','sub','pid','prolific_id','participantid','subjectid'});
    iT = pick(lvn, {'trial','trial_n','trial_nr','trialnr','trial_num','trial_number','trial_in_block','trialnum'});
    iC = pick(lvn, {'correct','accuracy','acc','is_correct','iscorrect','corr'});
    subj = T.(vn{iS});  trial = toNum(T.(vn{iT}));
    if ~isempty(iC)
        correct = toNum(T.(vn{iC}));
    else
        iCh = pick(lvn, {'choice','accept','response','resp','accepted','decision'});
        iV  = pick(lvn, {'reward','stim_reward','value','true_reward','stimulus_reward','stim_value','reward_value','true_value'});
        ch = toNum(T.(vn{iCh}));  v = toNum(T.(vn{iV}));
        correct = double((ch == 1 & v > 50) | (ch == 0 & v < 50));
        correct(isnan(ch) | isnan(v)) = NaN;
    end
    if min(trial) == 0, trial = trial + 1; end
    if max(trial) > nTr(k), trial = mod(trial - 1, nTr(k)) + 1; end
    ok = ~isnan(correct) & ~isnan(trial) & trial >= 1 & trial <= nTr(k);
    subj = subj(ok); trial = trial(ok); correct = correct(ok);
    [~, ~, si] = unique(subj);  nSub = max(si);

    m15   = trial > nTr(k) - 15;
    acc15 = accumarray(si(m15), correct(m15), [nSub 1], @mean);
    M     = accumarray([si trial], correct, [nSub nTr(k)], @mean, NaN);
    x     = 1:nTr(k);

    subplot(1,3,k); hold on; h = []; lab = {};
    fprintf('\n%s\n', titles{k});
    for j = 1:numel(ths)
        keep = acc15 >= ths(j);
        mu  = mean(M(keep,:), 1, 'omitnan');
        sem = std(M(keep,:), 0, 1, 'omitnan') ./ sqrt(sum(~isnan(M(keep,:)),1));
        fill([x fliplr(x)], [mu-sem fliplr(mu+sem)], cols(j,:), 'FaceAlpha', 0.12, 'EdgeColor', 'none');
        h(j) = plot(x, mu, 'Color', cols(j,:), 'LineWidth', 1.6);
        lab{j} = sprintf('%s, N=%d', thName{j}, sum(keep));
        fprintf('  %-22s N=%3d | start=%.3f | end=%.3f\n', thName{j}, sum(keep), mean(mu(1:10)), mean(mu(end-9:end)));
    end
    plot([1 60], [0.5 0.5], '--', 'Color', [0.4 0.4 0.4]);
    xlim([1 60]); ylim([0.4 1]);
    set(gca, 'XTick', [1 15 30 45 60], 'Box', 'off', 'TickDir', 'out');
    xlabel('trial'); if k == 1, ylabel('proportion correct'); end
    title(titles{k}, 'FontWeight', 'normal');
    legend(h, lab, 'Location', 'southeast', 'Box', 'off', 'FontSize', 8);
end
print('-dpng', '-r300', 'Figure_B_threshold_sensitivity.png');