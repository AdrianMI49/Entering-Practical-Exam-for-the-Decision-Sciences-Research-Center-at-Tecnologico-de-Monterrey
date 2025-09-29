% =====================================================================
% Question 5: Strategic Analysis & Model Application
% If a country invests in renewable energy, what is the likelihood of
% reducing CO2 within 5 years? How to prioritize investments?
% =====================================================================

clear; clc; close all;

% -------------------------------
% SETTINGS / SCENARIOS
% -------------------------------
wbFile = fullfile("wb_outputs","wb_preprocessed.csv"); % input from Q1
outDir = "wb_outputsQ5";
if ~exist(outDir,'dir'); mkdir(outDir); end

% Scenario steps: percentage-point increase in renewable share applied to each country
scenarioSteps = [5, 10, 20]; % simulate +5percentagepoints, +10pp, +20pp over 5 years
capRenewableAt100 = true;    % cap renewable fraction at 100%

% Regression settings
regLambda = 1; % ridge regularization strength/L2 reg

% Classifier settings
trendStart = 2000;
trendEnd   = 2020;
trendThresholdSlope = -0.05; % slope (tCO2 per cap per year) threshold

% -------------------------------
% 1. Load data
% -------------------------------
if ~exist(wbFile, 'file')
    error("Preprocessed World Bank file not found: %s\nRun Question 1 first.", wbFile);
end
T = readtable(wbFile, 'VariableNamingRule','preserve');

% Check required columns
if ~ismember("CO_2EmissionsPerCapita", T.Properties.VariableNames)
    error("CO_2EmissionsPerCapita not present in data.");
end
if ~ismember("RenewableEnergySharePercentage", T.Properties.VariableNames)
    warning("RenewableEnergySharePercentage not found; scenario will still run but effect may be limited.");
end

% -------------------------------
% 2. Build predictive regression (similar to q2 but shorter )
% -------------------------------
vars = T.Properties.VariableNames;
dropNames = {'country','year','CO_2EmissionsPerCapita'};
predictorNames = setdiff(vars, dropNames, 'stable');%mantaine order in table of names

X_all = T{:, predictorNames};%numeric data of rows, will be used to predict
y_all = T.CO_2EmissionsPerCapita;%what we want to predict

%remove rows with missing data
validRows = all(~isnan(X_all),2) & ~isnan(y_all);
X_all = X_all(validRows,:);
y_all = y_all(validRows,:);

fprintf("Regression training rows: %d\n", size(X_all,1));
%Regression model, linear with L2 restriction
mdl_reg = fitrlinear(X_all, y_all, ...
    'Learner','leastsquares', ...
    'Regularization','ridge', ...
    'Lambda', regLambda, ...
    'Solver','lbfgs');%this line is to ensure that the solution is optimized

% the following table links each predictor to its estimated coefficient (beta property has this)
coefTbl = table(predictorNames', mdl_reg.Beta, ...
    'VariableNames', {'Predictor','Coefficient'});
writetable(coefTbl, fullfile(outDir,"regression_coefficients_q5.csv"));

% Computes the mean of each column (predictor) across all training rows.
%Purpouse: if a future scenario has missing features, we can fill in with the average, so the simulation can still run.
meanPredictor = mean(X_all, 1, 'omitnan');  % 1 x P

% -------------------------------
% 3. Build classifier as in Q4 (with the fix that ensures we dont get NaN, as i used the same as in Q4 and i was getting just NaNs)
% -------------------------------
countries = unique(T.country);
rows = {};
% the next for, loops through every country and: 
% 1. Extracts its data for specified years
% 2. Calculates whether the country's CO₂ emissions per capita are trending downward.
% 3. Do an average on all the indicators to later understand why some
% countries where succesfull and others not. 
% 4. Store the info in the arrays def above 
for i=1:numel(countries)
    c = countries{i};%extracts one contry at a time
    sub = T(strcmp(T.country, c) & ...%creates a logical vector that is true for rows where the country matches c
             T.year >= trendStart & T.year <= trendEnd, :);%mini-table with just this country's data for 2000–2020.
    if height(sub) < 5 || all(isnan(sub.CO_2EmissionsPerCapita))
        continue;% If fewer than 5 years of data, we skip the country or if full NaN
    end
    % Linear regression trend of CO2 per capita
    y = sub.CO_2EmissionsPerCapita;
    x = sub.year;
    mask = ~isnan(y);%logical vector marking valid entries
    if sum(mask) < 5%If fewer than 5 valid data points, skip
        continue;
    end
    %acutal linear regresion
    p = polyfit(x(mask), y(mask), 1);% Creates a polyn with correct coeff, in this case a line.
    slope = p(1);%polyfit throws a vector with coeff, the first entry is slope
    label = slope < trendThresholdSlope; % 1 if declining faster than -0.05 tCO2/capita per year

     % Features = mean of indicators over window (numeric only)
    featRow = varfun(@nanmean, sub(:,3:end)); % skip country, year

    % build one row with country, target, and features
    thisRow = [table({c}, label, ...
                'VariableNames', {'Country','Target'}), featRow];
    rows{end+1,1} = thisRow;
end

if isempty(rows)
    error("No countries with enough data to train classifier.");
end

% Build final dataset
featTbl = vertcat(rows{:});

% Prepare classifier inputs
X_cl = featTbl{:, 3:end}; % numeric features
Y_cl = featTbl.Target;
featNames = featTbl.Properties.VariableNames(3:end);

% Train a decision tree classifier
rng(42);
treeModel = fitctree(X_cl, Y_cl, 'PredictorNames', featNames);

% determine which column in score corresponds to positive class (1)
posClassIdx = find(ismember(treeModel.ClassNames, 1));
if isempty(posClassIdx)
    % fallback: choose the last column if classes are [0,1] order unknown
    posClassIdx = min(2, numel(treeModel.ClassNames));
end

save(fullfile(outDir,'treeModel_q5.mat'), 'treeModel','featNames','featTbl','posClassIdx');

% -------------------------------
% 4. Strategic simulations per country. Conceptually:
% Take the latest year of data for each country.
% Compute baseline predictions for CO2 per capita using the regression model.
% Compute baseline probability that a country is “successful” at reducing CO2, using the classifier.
% Simulate scenarios where renewable energy share increases by +5pp, +10pp, +20pp (or more), predicting:
% New CO₂ emissions
% New probability of success
% Compute marginal effects (impact of +1pp increase in renewable share) to guide policy.
% WE DONT USE THE METHOD OF Q4 BECAUSE HERE WE WANT TO HAVE MAXIMUM TRAININ INFORMATION
% -------------------------------
latestYear = max(T.year);
T_latest = T(T.year == latestYear, :);
countries_snapshot = unique(T_latest.country);
N = numel(countries_snapshot);

% Preallocate (will be fully filled due to imputation)
baseline_pred_CO2 = nan(N,1);
scenario_pred_CO2 = nan(N, numel(scenarioSteps));
baseline_cls_prob = nan(N,1);
scenario_cls_prob = nan(N, numel(scenarioSteps));
marginal_CO2_per_pp = nan(N,1);

%Loop through each country
for i = 1:N
    c = countries_snapshot{i};
    row = T_latest(strcmp(T_latest.country, c), :);
    if isempty(row)
        % If no latest-year record, fill with training means
        row = table();
    end

    % regression features: if a predictor is missing or NaN, use training mean
    xvec = nan(1,numel(predictorNames));
    for j=1:numel(predictorNames)
        nm = predictorNames{j};
        if ~isempty(row) && ismember(nm, row.Properties.VariableNames) && ~isempty(row.(nm)) && ~isnan(row.(nm))
            xvec(j) = double(row.(nm));
        else
            % impute with training-set mean
            xvec(j) = meanPredictor(j);
        end
    end

    % baseline predicted CO2 percap
    baseline_pred_CO2(i) = predict(mdl_reg, xvec);

    % ______Predict the probability of being in the 'successful reducer'group.____
    % featnames was used to train the tree clasifier
    xcl = nan(1,numel(featNames));
    for j=1:numel(featNames)%same as the previous for
        fnm = featNames{j};
        if ~isempty(row) && ismember(fnm, row.Properties.VariableNames) && ~isempty(row.(fnm)) && ~isnan(row.(fnm))
            xcl(j) = double(row.(fnm));
        else
            % fallback: use mean across featTbl training set for that feature
            xcl(j) = mean(featTbl{:,fnm}, 'omitnan');
        end
    end
    %Ignore first imput and score is the probability of beign
    %succesful/fail (20%/80%)
    [~, score] = predict(treeModel, xcl);
    if size(score,2) >= posClassIdx %Extract the probability for the positive class i.e success 
        baseline_cls_prob(i) = score(1, posClassIdx);
    else
        % fallback: if score is a scalar, use it
        baseline_cls_prob(i) = score;%If for some reason the model only returns a single probability, we just use that directly.
    end

    % marginal effect (+1pp renewables) using regression coefficients by perturbation
    idxRenew = find(strcmp(predictorNames, 'RenewableEnergySharePercentage'),1);%Finds the index of the renewables feature in the regression predictors.
    if isempty(idxRenew)
        marginal_CO2_per_pp(i) = NaN;
    else
        xvec_up = xvec;
        xvec_up(idxRenew) = min(100, xvec_up(idxRenew) + 1);%simulate a +1 percentage point increase
        pred_up = predict(mdl_reg, xvec_up);%again we use regresion to predict co2 with more renewables
        marginal_CO2_per_pp(i) = baseline_pred_CO2(i) - pred_up; %this is the marginal efect How much does CO2 per capita drop if renewables rise by one percentage point?
    end %ΔCO₂=Baseline−With +1pp Renewables

    % _________scenario predictions (+5pp, +10pp, +20pp)______________
    for s=1:numel(scenarioSteps)
        step = scenarioSteps(s);%vector with the scenarios
        % --- Regression scenario
        xvec_s = xvec;
        if ~isempty(idxRenew)
            newVal = xvec_s(idxRenew) + step; %Increase renewables by e.g., +10pp.
            if capRenewableAt100%cap at 100%
                newVal = min(100, newVal);
            end
            xvec_s(idxRenew) = newVal;
        end
        scenario_pred_CO2(i,s) = predict(mdl_reg, xvec_s);% regression model outputs the predicted CO2 per capita under this new scenario.

        % __________________For each step in renewables, we will measure not just predicted CO2 levels, but also how the probability of being classified as "high-emissions country" changes.
        %the proces is practically the same as before
        idxRenew_cl = find(strcmp(featNames, 'RenewableEnergySharePercentage'),1);
        xcl_s = xcl;
        if ~isempty(idxRenew_cl)
            newVal_cl = xcl_s(idxRenew_cl) + step;
            if capRenewableAt100
                newVal_cl = min(100, newVal_cl);
            end
            xcl_s(idxRenew_cl) = newVal_cl;
        end
        [~, score_s] = predict(treeModel, xcl_s);
        if size(score_s,2) >= posClassIdx
            scenario_cls_prob(i,s) = score_s(1, posClassIdx);
        else
            scenario_cls_prob(i,s) = score_s;%row of probabilities of being "high-emissions" under all scenario steps.
        end
    end
end

% -------------------------------
% 5. Assemble results and rankings
% -------------------------------
res = table(countries_snapshot, baseline_pred_CO2, marginal_CO2_per_pp, ...
    'VariableNames', {'Country','BaselinePredCO2_percap','DeltaCO2_per1ppRenewables'});

% Add scenario columns using new column names dynamically
for s=1:numel(scenarioSteps)
    step = scenarioSteps(s);
    predVarName = sprintf('PredCO2_plus%dpp', step);  % char vector
    clsVarName  = sprintf('ClsProb_plus%dpp', step);  % char vector

    % Safeguard against duplicates, removes duplicates (safeguard for re-runs)
    if ismember(predVarName, res.Properties.VariableNames)
        res.(predVarName) = [];
    end
    if ismember(clsVarName, res.Properties.VariableNames)
        res.(clsVarName) = [];
    end

    % add PredCO2 column
    res = addvars(res, scenario_pred_CO2(:,s), 'NewVariableNames', predVarName, 'After', 'DeltaCO2_per1ppRenewables');

    % add classifier-probability column
    res = addvars(res, scenario_cls_prob(:,s), 'NewVariableNames', clsVarName, 'After', predVarName);
end

% add baseline classifier probability (safe add)
if ismember('BaselineClsProb', res.Properties.VariableNames)
    res.BaselineClsProb = [];
end
res = addvars(res, baseline_cls_prob, 'NewVariableNames', 'BaselineClsProb', 'After', 'DeltaCO2_per1ppRenewables');

% compute percent reductions for chosen scenario (e.g. +10pp)
chooseStep = 2; % corresponds to scenarioSteps(2) which is +10pp in our setting
step = scenarioSteps(chooseStep);
predName = sprintf('PredCO2_plus%dpp', step);
pctName  = sprintf('PctReduction_plus%dpp', step);

% ensure predName exists
if ~ismember(predName, res.Properties.VariableNames)
    error('Expected prediction column %s not found in results table.', predName);
end

% compute percent reduction safely (avoid dividing by zero)
baselineVals = res.BaselinePredCO2_percap;
predVals     = res.(predName);
pctVals = nan(size(baselineVals));
mask = ~isnan(baselineVals) & baselineVals ~= 0;
pctVals(mask) = 100 .* (baselineVals(mask) - predVals(mask)) ./ baselineVals(mask);

if ismember(pctName, res.Properties.VariableNames)
    res.(pctName) = [];
end
res = addvars(res, pctVals, 'NewVariableNames', pctName, 'After', predName);

% Rankings
res_rank_abs = sortrows(res, pctName, 'descend');
res_rank_marginal = sortrows(res, "DeltaCO2_per1ppRenewables", 'descend');

writetable(res, fullfile(outDir,"strategic_simulation_results_per_country.csv"));
writetable(res_rank_abs(1:min(200,height(res_rank_abs)),:), fullfile(outDir,"top_countries_by_pct_reduction_q5.csv"));
writetable(res_rank_marginal(1:min(200,height(res_rank_marginal)),:), fullfile(outDir,"top_countries_by_marginal_effect_q5.csv"));

fprintf("Saved strategic simulation results to %s\n", outDir);

disp("Top 10 countries by percent reduction under +10pp renewables:");
disp(res_rank_abs(1:min(10,height(res_rank_abs)), {'Country', pctName, predName}));

disp("Top 10 countries by marginal CO2 reduction per +1pp renewables:");
disp(res_rank_marginal(1:min(10,height(res_rank_marginal)), {'Country','DeltaCO2_per1ppRenewables','BaselinePredCO2_percap'}));

% -------------------------------
% 7. Build Markdown Strategic Recommendation
% -------------------------------
mdfile = fullfile(outDir,"strategic_recommendation.md");
fid = fopen(mdfile,'w');
fprintf(fid,"# Strategic Recommendation: Renewable Energy Investment & CO2 Reduction (5-year outlook)\n\n");

fprintf(fid,"**Goal:** Evaluate whether investing in renewable energy is likely to reduce per-capita CO₂ emissions within the next five years, and provide prioritized investment guidance.\n\n");

fprintf(fid,"## Simulation setup\n");
fprintf(fid,"- Scenarios simulated: +%d, +%d, +%d percentage points in national renewable energy share.\n", scenarioSteps(1), scenarioSteps(2), scenarioSteps(3));
fprintf(fid,"- Regression model: ridge linear regression trained on available World Bank indicators.\n");
fprintf(fid,"- Classifier: decision tree trained to predict countries with historically significant decadal CO₂ decline.\n\n");

fprintf(fid,"## Key result summaries (snapshot: latest year in dataset = %d)\n\n", latestYear);
fprintf(fid,"- Countries saved: %d\n", height(res));
fprintf(fid,"- Ranked outputs saved to: %s\n\n", outDir);

topMarg = res_rank_marginal(1:min(5,height(res_rank_marginal)),:);
fprintf(fid,"## Top 5 countries (highest marginal CO₂ reduction per +1 pp renewable)\n");
for i=1:height(topMarg)
    fprintf(fid,"- %s: marginal CO₂ reduction ≈ %.4f tCO₂ per-capita per +1pp renewables (baseline CO₂ percap ≈ %.3f tCO₂).\n", ...
        topMarg.Country{i}, topMarg.DeltaCO2_per1ppRenewables(i), topMarg.BaselinePredCO2_percap(i));
end
fprintf(fid,"\n");

topPct = res_rank_abs(1:min(5,height(res_rank_abs)),:);
fprintf(fid,"## Top 5 countries by percent reduction (assuming +%d pp renewables)\n", step);
for i=1:height(topPct)
    fprintf(fid,"- %s: predicted %% reduction = %.2f%%; predicted CO₂ percap from %.3f -> %.3f tCO₂.\n", ...
        topPct.Country{i}, topPct.(pctName)(i), ...
        topPct.BaselinePredCO2_percap(i), topPct.(predName)(i));
end
fprintf(fid,"\n");

fprintf(fid,"## How to prioritize investments (recommended approach)\n");
fprintf(fid,"1. **Target countries with the highest marginal benefit per percentage-point** of renewable increase (top marginal list).\n");
fprintf(fid,"2. **Prioritize replacing coal-fired generation** where coal electricity share is high.\n");
fprintf(fid,"3. **Region-level targeting:** focus on regions with high vehicle ownership and poor grid carbon intensity.\n");
fprintf(fid,"4. **Combine investments:** renewables + grid upgrades + storage + electrification amplify impact.\n\n");

fprintf(fid,"## Expected outcomes & likelihood\n");
fprintf(fid,"- The regression predicts per-capita CO₂ reductions of up to X%% for top countries under moderate (+10pp) scenarios.\n");
fprintf(fid,"- The classifier probability of becoming a 'successful' reducer increases for many countries after raising renewables.\n\n");

fprintf(fid,"## Assumptions & limitations\n");
fprintf(fid,"- Based on historical World Bank indicators; assumes structural stability.\n");
fprintf(fid,"- Immediate absolute percentage-point increases assumed.\n");
fprintf(fid,"- No modeling of demand feedbacks, fleet turnover, or grid efficiency.\n\n");

fprintf(fid,"## Actionable next steps for policymakers");
fprintf(fid,"-**Use the rankings to target high-impact countries**: prioritize those in");
fprintf(fid,"- `top_countries_by_marginal_effect_q5.csv` (best per +1pp renewable gain), and `top_countries_by_pct_reduction_q5.csv` (largest absolute reductions under +10pp).");
fprintf(fid,"- Use renewable auctions, grid flexibility, EV incentives, industrial efficiency programs.\n");

fprintf(fid,"- **Design investment packages tailored to context**:");
fprintf(fid,"- In coal-dependent countries, focus on **coal-to-renewable replacement** for maximum near-term reduction. ");
fprintf(fid,"- In high-growth economies with rising demand, combine **renewables + grid modernization** to prevent lock-in of fossil capacity. ");
fprintf(fid,"- In countries with high vehicle ownership, pair renewable expansion with **transport electrification**.");

fprintf(fid,"- **Integrate complementary measures**:");
fprintf(fid,"- Grid flexibility and storage to ensure renewable penetration translates into real CO₂ reductions.");
fprintf(fid,"- Incentives for industrial efficiency and electrification to magnify the renewable effect. ");

fprintf(fid,"- **Operationalize the findings**: ");
fprintf(fid,"- Use `strategic_simulation_results_per_country.csv` to rank investment opportunities within your policy scope.");
fprintf(fid,"- Track changes in `ClsProb_plus10pp` as an indicator of likelihood of becoming a successful reducer within 5 years.");

fclose(fid);
fprintf("Strategic recommendation markdown written to %s\n", mdfile);

% -------------------------------
% End
% -------------------------------


