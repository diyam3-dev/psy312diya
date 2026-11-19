%% FIGURE B: reproduction audit - exclusion sensitivity (replication sample)
% Compares the learning curve WITH the paper's exclusion rule (N=138)
% vs WITHOUT it (N=195). Copy-paste and run.
clear; clc; close all;

root = fullfile(getenv('USERPROFILE'), 'Downloads', 'slow_prior-main', ...
                'slow_prior-main', 'data_participants');
nTr  = 60;                       % learning trials per block (replication)
thr  = 71/120;                   % paper's exclusion threshold (~59.2 %)

pick  = @(lvn, c) find(ismember(lvn, c), 1);
toNum = @(x) str2double(replace(replace(lower(string(x)), "true", "1"), "false", "0"));

%% ---- load replication learning data ----
f = dir(fullfile(root, 'replication', '*train*.csv'));
if isempty(f), error('No train csv found in replication folder'); end
T  = readtable(fullfile(f(1).folder, f(1).name), ...
               'TreatAsMissing', {'NA','N/A','NaN','nan',''});
vn = T.Properties.VariableNames;  lvn = lower(vn);

iS = pick(lvn, {'subject','subj','id','participant','participant_id','subject_id','sub','pid','prolific_id','participantid','subjectid'});
iT = pick(lvn, {'trial','trial_n','trial_nr','trialnr','trial_num','trial_number','trial_in_block','trialnum'});
iC = pick(lvn, {'correct','accuracy','acc','is_correct','iscorrect','corr'});
if isempty(iS) || isempty(iT)
    error('Could not find subject/trial columns. Send me the Columns list: %s', strjoin(vn, ', '));
end

subj  = T.(vn{iS});
trial = toNum(T.(vn{iT}));
if ~isempty(iC)
    correct = toNum(T.(vn{iC}));
else
    iCh = pick(lvn, {'choice','accept','response','resp','accepted','decision'});
    iV  = pick(lvn, {'reward','stim_reward','value','true_reward','stimulus_reward','stim_value','reward_value','true_value'});
    if isempty(iCh) || isempty(iV)
        error('No accuracy column and cannot compute it. Columns: %s', strjoin(vn, ', '));
    end
    ch = toNum(T.(vn{iCh}));  v = toNum(T.(vn{iV}));
    correct = double((ch == 1 & v > 50) | (ch == 0 & v < 50));
    correct(isnan(ch) | isnan(v)) = NaN;
end

if min(trial) == 0, trial = trial + 1; end
if max(trial) > nTr, trial = mod(trial - 1, nTr) + 1; end
ok = ~isnan(correct) & ~isnan(trial) & trial >= 1 & trial <= nTr;
subj = subj(ok); trial = trial(ok); correct = correct(ok);
[ids, ~, si] = unique(subj);  nSub = numel(ids);

%% ---- per-participant end-of-learning accuracy (last 15 trials, all blocks) ----
m15 = trial > nTr - 15;
acc15 = accumarray(si(m15), correct(m15), [nSub 1], @mean);
good  = acc15 > thr;                       % TRUE = kept by the paper's rule

%% ---- curves (participants x trials) ----
M = accumarray([si trial], correct, [nSub nTr], @mean, NaN);
x = 1:nTr;
stats = @(Mx) deal(mean(Mx,1,'omitnan'), std(Mx,0,1,'omitnan')./sqrt(sum(~isnan(Mx),1)));
[muAll, semAll] = stats(M);
[muEx,  semEx ] = stats(M(good,:));

res = zeros(2,4);   % N, start(1-10), end(last 10), mean last-15 acc
res(1,:) = [nSub,        mean(muAll(1:10)), mean(muAll(end-9:end)), mean(acc15)];
res(2,:) = [sum(good),   mean(muEx(1:10)),  mean(muEx(end-9:end)),  mean(acc15(good))];

fprintf('\nWITHOUT exclusion: N=%d | start=%.3f | end=%.3f\n', res(1,1), res(1,2), res(1,3));
fprintf('WITH exclusion:    N=%d | start=%.3f | end=%.3f   (paper: N=138, 0.51 -> 0.75)\n', res(2,1), res(2,2), res(2,3));
fprintf('Excluded: %d of %d participants\n', nSub - sum(good), nSub);

%% ---- Figure B ----
figure('Position', [100 100 1250 420]);

% Panel 1: curves with vs without exclusion
subplot(1,3,1); hold on;
cAll = [0.85 0.33 0.10];
fill([x fliplr(x)], [muAll-semAll fliplr(muAll+semAll)], cAll, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
fill([x fliplr(x)], [muEx-semEx   fliplr(muEx+semEx)],   [0 0 0], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
h1 = plot(x, muAll, 'Color', cAll, 'LineWidth', 1.8);
h2 = plot(x, muEx,  'k', 'LineWidth', 1.8);
plot([1 60], [0.5 0.5], '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.5);
xlim([1 60]); ylim([0.4 1]);
set(gca, 'XTick', [1 15 30 45 60], 'Box', 'off', 'TickDir', 'out');
xlabel('trial'); ylabel('proportion correct');
title('Replication learning curve', 'FontWeight', 'normal');
legend([h1 h2], {sprintf('no exclusion (N=%d)', nSub), sprintf('paper''s exclusion (N=%d)', sum(good))}, ...
       'Location', 'southeast', 'Box', 'off');

% Panel 2: who was excluded
subplot(1,3,2); hold on;
histogram(acc15(~good), 0.30:0.025:1, 'FaceColor', cAll, 'EdgeColor', 'w');
histogram(acc15(good),  0.30:0.025:1, 'FaceColor', [0.3 0.3 0.3], 'EdgeColor', 'w');
yl = ylim; plot([thr thr], yl, 'k--', 'LineWidth', 1.5);
text(thr, yl(2), sprintf('  cutoff %.3f', thr), 'VerticalAlignment', 'top');
xlabel('accuracy, last 15 trials (all blocks)'); ylabel('participants');
set(gca, 'Box', 'off', 'TickDir', 'out');
title('Exclusion criterion', 'FontWeight', 'normal');
legend({'excluded','kept'}, 'Box', 'off', 'Location', 'northwest');

% Panel 3: numerical comparison to the paper
subplot(1,3,3); axis off;
txt = {
  'Replication sample',
  '',
  sprintf('%-22s %4s %7s %7s', '', 'N', 'start', 'end'),
  sprintf('%-22s %4d %7.3f %7.3f', 'Paper (reported)', 138, 0.51, 0.75),
  sprintf('%-22s %4d %7.3f %7.3f', 'Mine, excluded', res(2,1), res(2,2), res(2,3)),
  sprintf('%-22s %4d %7.3f %7.3f', 'Mine, no exclusion', res(1,1), res(1,2), res(1,3)),
  '',
  'start = mean of trials 1-10',
  'end   = mean of last 10 trials',
  sprintf('Excluded: %d of %d', nSub - sum(good), nSub)};
text(0, 0.95, txt, 'FontName', 'FixedWidth', 'FontSize', 10, 'VerticalAlignment', 'top');

print('-dpng', '-r300', 'Figure_B_exclusion_audit.png');
