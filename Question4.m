%=====================================================================
%  Classification and Policy Implications
% Build a classifier to identify countries likely to reduce CO2 emissions
% significantly in the next decade.
%=====================================================================
clc; clear; close all;

% ---------------- Load data ----------------
fn = fullfile("wb_outputs/", "wb_preprocessed.csv"); % relative path for GitHub
df = readtable(fn);

disp("Available variables:");
%disp(df.Properties.VariableNames);

% ---------------- Define target variable ----------------
countries = unique(df.country);
target = [];              % binary labels for countries, will show if a contry is succesfull reducing emissions
allFeatures = [];         % stores numeric data for all contries
countryNames = {};        % keep country names separately

startYear = 2000; % look at last ~20 years
endYear   = 2020;
% the next for, loops through every country and: 
% 1. Extracts its data for specified years
% 2. Calculates whether the country's CO₂ emissions per capita are trending downward.
% 3. Do an average on all the indicators to later understand why some
% countries where succesfull and others not. 
% 4. Store the info in the arrays def above 
for i = 1:numel(countries)
    ctry = countries{i};%extracts one contry at a time
    sub = df(strcmp(df.country, ctry) & ...%creates a logical vector that is true for rows where the country matches ctry
             df.year >= startYear & df.year <= endYear, :);%mini-table with just this country's data for 2000–2020.

    if height(sub) < 5 || all(isnan(sub.CO_2EmissionsPerCapita))
        continue; % If fewer than 5 years of data, we skip the country or if full NaN
    end

    % Linear regression trend of CO2 per capita
    y = sub.CO_2EmissionsPerCapita;
    x = sub.year;
    mask = ~isnan(y);%logical vector marking valid entries
    if sum(mask) < 5 %If fewer than 5 valid data points, skip
        continue
    end
    %acutal linear regresion
    p = polyfit(x(mask), y(mask), 1); % Creates a polyn with correct coeff, in this case a line.
    slope = p(1);%polyfit throws a vector with coeff, the first entry is slope

    % Target: 1 if declining faster than -0.05 tCO2/capita per year
    label = slope < -0.05;
    target(end+1,1) = label;

    % Features = mean of indicators over window (numeric only)
    featRow = varfun(@nanmean, sub(:,3:end)); % skip country, year and gives a single row with the average of each indicator from 2000–2020.
    allFeatures = [allFeatures; featRow{1,:}];%append featrow
    countryNames{end+1,1} = ctry;
end

% Build final dataset
featTbl = array2table(allFeatures, 'VariableNames', featRow.Properties.VariableNames);
%is [GDP, EnergyUse, RenewablesShare, ..., Country, Target]
featTbl.Country = countryNames;
featTbl.Target = target;

%---------------- Prepare ML data ----------------
X = featTbl{:, 1:end-2};  % numeric matrix (skip Country + Target)
Y = featTbl.Target;

featNames = featTbl.Properties.VariableNames(1:end-2);%names of contries for later reference

% ---------------- Train classifier ----------------
rng(42); % sets the random number generator seed so results are reproducible.

%Instead of training once and testing once, we use 5-fold cross-validation:
% 1. Split the dataset into 5 parts ("folds"), Train on 4 folds, test on the 5th.
% Repeat 5 times so every country gets tested once. This is more relaiable.
cv = cvpartition(Y, 'KFold', 5);

%we use a clasification tree to predict and name as we have a nonlinear relationships: Trees can capture "if GDP is high AND renewables are high, THEN success"
% Also it makes it easier which indicators attribute to success or not
% succes.
model = fitctree(X, Y, 'PredictorNames', featNames);

% Cross-validated predictions
cvModel = crossval(model, 'CVPartition', cv);%wraps the trained model in a cross-validation framework
preds = kfoldPredict(cvModel); %runs the cross-validation. gives a vector of predicted labels (0 or 1) for every country, but generated in a cross-validated way

% ---------------- Evaluation ----------------
cm = confusionmat(Y, preds);%confusion matrix, which is the standard way to evaluate classification.
acc = mean(preds == Y);% gives accuracy of our model
precision = cm(2,2) / sum(cm(:,2)); %Of all countries the model predicted as successful, how many actually are?
recall = cm(2,2) / sum(cm(2,:));%Of all countries that truly are successful, how many did we catch?
f1 = 2 * (precision * recall) / (precision + recall);%harmonic mean, if high both precision and recall are good, if near 0 one or both are bad

fprintf("Accuracy: %.2f\n", acc);
fprintf("Precision: %.2f\n", precision);
fprintf("Recall: %.2f\n", recall);
fprintf("F1-score: %.2f\n", f1);

% ---------------- Feature importance ----------------
imp = predictorImportance(model); %based on the prediction tree gives which indicators are more important to the co2 emisions reduction of each contry
[sortedImp, idx] = sort(imp, 'descend');

figure;
bar(sortedImp(1:10));
xticklabels(featNames(idx(1:10)));
xtickangle(45);
ylabel("Importance");
title("Top 10 Most Important Features");

%---------------- Save results ----------------
if ~exist('wb_outputsQ4', 'dir')
    mkdir('wb_outputsQ4'); 
end
writetable(featTbl, fullfile("wb_outputsQ4/", "classification_dataset.csv"));
