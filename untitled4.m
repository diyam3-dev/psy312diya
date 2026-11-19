%% FIGURE C: own-data result, two-option probabilistic reward learning (Version 1)
% Reads every bandit_v1_*.csv made by bandit_task_v1.py and plots:
%   1) learning curves (accuracy by trial) for each reward-probability gap
%   2) choice accuracy and reward rate across blocks
%   3) accuracy in the last 10 trials of each gap condition (one dot per participant)
% It also prints a table of PRE-SPECIFIED failure checks (floor, ceiling, no learning...).
clear; clc; close all;

%% ---------------- CONFIG ----------------
dataDir        = fullfile(pwd, 'data');  % folder with the CSV files (change if needed)
applyExclusion = false;     % true = drop participants at/below the chance cutoff (decide BEFORE main study)
winSize        = 5;         % moving-average window (trials) for panel 1
nTr            = 40;        % trials per block (must match the task)
lastN          = 10;        % "end of learning" = last 10 trials of a block
%% ----------------------------------------

toNum = @(x) str2double(replace(replace(lower(string(x)), "true", "1"), "false", "0"));

files = dir(fullfile(dataDir, 'bandit_v1_*.csv'));
if isempty(files), error('No bandit_v1_*.csv files found in %s', dataDir); end

T = [];
for i = 1:numel(files)
    t = readtable(fullfile(files(i).folder, files(i).name), 'TreatAsMissing', {'NA',''}, ...
                  'TextType', 'string');
    n = height(t);
    r = table(string(t.participant), toNum(t.practice), toNum(t.block), toNum(t.p_best), ...
              toNum(t.trial), toNum(t.correct), toNum(t.reward), toNum(t.no_response), ...
              lower(string(t.key)), ...
              'VariableNames', {'pid','practice','block','p_best','trial','correct','reward','noresp','key'});
    if isempty(T), T = r; else, T = [T; r]; end
end
T = T(T.practice == 0, :);                       % drop practice trials

[pids, ~, pi_] = unique(T.pid);   nP = numel(pids);
gaps = sort(unique(T.p_best), 'descend')';       % e.g. [0.8 0.7 0.6]
nC   = numel(gaps);
[~, ci] = ismember(T.p_best, gaps);
nB   = max(T.block);
valid = ~isnan(T.correct);

%% ---------------- participant-level checks ----------------
accAll  = accumarray(pi_(valid), T.correct(valid), [nP 1], @mean);
nValid  = accumarray(pi_(valid), 1, [nP 1]);
nTotal  = accumarray(pi_, 1, [nP 1]);
pNoResp = 1 - nValid ./ nTotal;
isJ     = T.key == "j";
sideBias = accumarray(pi_(valid), double(isJ(valid)), [nP 1], @mean);
cutoff  = 0.5 + 1.96 * 0.5 ./ sqrt(nValid);      % ~97.5th percentile of chance accuracy
belowChance = accAll <= cutoff;

fprintf('\nPARTICIPANTS (%d)\n', nP);
fprintf('%-12s %8s %8s %8s %8s %8s\n', 'id', 'accuracy', 'cutoff', 'noResp%', 'jShare', 'chance?');
for p = 1:nP
    fprintf('%-12s %8.3f %8.3f %8.1f %8.2f %8s\n', pids(p), accAll(p), cutoff(p), ...
            100*pNoResp(p), sideBias(p), string(belowChance(p)));
end

keepP = true(nP, 1);
if applyExclusion, keepP = ~belowChance; fprintf('\nExclusion ON: kept %d of %d\n', sum(keepP), nP); end
keepRow = keepP(pi_) & valid;

%% ---------------- accuracy tensors ----------------
% participants x condition x trial (mean over the repeats of that condition)
A = accumarray([pi_(keepRow) ci(keepRow) T.trial(keepRow)], T.correct(keepRow), [nP nC nTr], @mean, NaN);
A(~keepP, :, :) = NaN;
Asm = movmean(A, winSize, 3, 'omitnan');

% participants x block
AccB = accumarray([pi_(keepRow) T.block(keepRow)], T.correct(keepRow), [nP nB], @mean, NaN);
RewB = accumarray([pi_(keepRow) T.block(keepRow)], T.reward(keepRow),  [nP nB], @mean, NaN);

% last-N accuracy per participant x condition
lastIdx = nTr - lastN + 1 : nTr;
firstIdx = 1 : lastN;
Last  = mean(A(:, :, lastIdx),  3, 'omitnan');
First = mean(A(:, :, firstIdx), 3, 'omitnan');

%% ---------------- Figure C ----------------
cols = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
sem  = @(X, d) std(X, 0, d, 'omitnan') ./ sqrt(sum(~isnan(X), d));
figure('Position', [100 100 1300 420]);

% Panel 1: learning curves by gap
subplot(1, 3, 1); hold on; h = gobjects(1, nC); lab = cell(1, nC);
x = 1:nTr;
for c = 1:nC
    mu = reshape(mean(Asm(:, c, :), 1, 'omitnan'), 1, nTr);
    se = reshape(sem(Asm(:, c, :), 1), 1, nTr);
    fill([x fliplr(x)], [mu-se fliplr(mu+se)], cols(c,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    h(c) = plot(x, mu, 'Color', cols(c,:), 'LineWidth', 1.8);
    lab{c} = sprintf('%.1f vs %.1f', gaps(c), 1 - gaps(c));
end
plot([1 nTr], [0.5 0.5], '--', 'Color', [0.4 0.4 0.4]);
xlim([1 nTr]); ylim([0.3 1]);
set(gca, 'Box', 'off', 'TickDir', 'out');
xlabel('trial within block'); ylabel('proportion choosing the better option');
title(sprintf('Learning curves (%d-trial moving mean)', winSize), 'FontWeight', 'normal');
legend(h, lab, 'Location', 'southeast', 'Box', 'off');

% Panel 2: accuracy and reward rate across blocks
subplot(1, 3, 2); hold on;
hP = [];
for p = 1:nP
    if keepP(p)
        hp = plot(1:nB, AccB(p, :), '-', 'Color', [0.8 0.8 0.8]);
        if isempty(hP), hP = hp; end
    end
end
muA = mean(AccB, 1, 'omitnan');  seA = sem(AccB, 1);
muR = mean(RewB, 1, 'omitnan');  seR = sem(RewB, 1);
hA = errorbar(1:nB, muA, seA, 'k-o', 'LineWidth', 1.8, 'MarkerFaceColor', 'k');
hR = errorbar(1:nB, muR, seR, '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.5, 'MarkerFaceColor', [0.85 0.33 0.10]);
plot([0.5 nB+0.5], [0.5 0.5], '--', 'Color', [0.4 0.4 0.4]);
xlim([0.5 nB+0.5]); ylim([0.3 1]); set(gca, 'XTick', 1:nB, 'Box', 'off', 'TickDir', 'out');
xlabel('block (order presented)'); ylabel('proportion');
title('Across blocks', 'FontWeight', 'normal');
legend([hP hA hR], {'participants (accuracy)', 'accuracy (mean \pm SEM)', 'reward rate (mean \pm SEM)'}, ...
       'Location', 'southeast', 'Box', 'off');

% Panel 3: last-N accuracy by gap
subplot(1, 3, 3); hold on;
for p = 1:nP
    if keepP(p), plot(1:nC, Last(p, :), '-', 'Color', [0.8 0.8 0.8]); end
end
for c = 1:nC
    plot(c * ones(nP, 1), Last(:, c), 'o', 'Color', cols(c,:), 'MarkerFaceColor', cols(c,:), 'MarkerSize', 5);
end
errorbar(1:nC, mean(Last, 1, 'omitnan'), sem(Last, 1), 'k', 'LineStyle', 'none', 'Marker', '_', 'MarkerSize', 22, 'LineWidth', 2);
plot([0.5 nC+0.5], [0.5 0.5], '--', 'Color', [0.4 0.4 0.4]);
xlim([0.5 nC+0.5]); ylim([0.3 1.02]);
set(gca, 'XTick', 1:nC, 'XTickLabel', lab, 'Box', 'off', 'TickDir', 'out');
xlabel('reward probabilities (better vs worse option)'); ylabel(sprintf('accuracy, last %d trials', lastN));
title('End-of-block accuracy by difficulty', 'FontWeight', 'normal');

print('-dpng', '-r300', 'Figure_C.png');

%% ---------------- summary + PRE-SPECIFIED failure checks ----------------
fprintf('\nCONDITION SUMMARY (N=%d kept)\n', sum(keepP));
fprintf('%-12s %10s %10s %10s\n', 'gap', 'first10', 'last10', 'gain');
for c = 1:nC
    fprintf('%-12s %10.3f %10.3f %10.3f\n', lab{c}, mean(First(:,c),'omitnan'), ...
            mean(Last(:,c),'omitnan'), mean(Last(:,c) - First(:,c), 'omitnan'));
end

easy = 1; hard = nC;
floorFail   = mean(Last(:, hard), 'omitnan') <= 0.55;
ceilFail    = mean(Last(keepP, easy) >= 0.95) >= 0.80;
nolearnFail = mean(Last(:, easy) - First(:, easy), 'omitnan') < 0.10;
nrFail      = any(pNoResp > 0.10);
biasFail    = any(abs(sideBias - 0.5) > 0.15);

fprintf('\nFAILURE CHECKS (thresholds are provisional; justify them in your report)\n');
fprintf('FLOOR   hardest gap mean last-%d accuracy <= 0.55 : %s\n', lastN, string(floorFail));
fprintf('CEILING >=80%% of participants >= 0.95 on easiest gap: %s\n', string(ceilFail));
fprintf('NO LEARNING easiest-gap gain (last - first) < 0.10 : %s\n', string(nolearnFail));
fprintf('MISSED RESPONSES any participant > 10%% no-response : %s\n', string(nrFail));
fprintf('SIDE BIAS any participant J-share outside 0.35-0.65 : %s\n', string(biasFail));
fprintf('\nSaved Figure_C.png in %s\n', pwd);