% =====================================================================
% Predictive Modeling of CO2 Emissions by linear regresion 
% Based on World Bank socio-economic indicators
% =====================================================================

clear; clc;


% -------------------1. Load preprocessed dataset---------------------

data = readtable(fullfile("wb_outputs/","wb_preprocessed.csv"));% we read the data from q1

% Target: CO2 emissions per capita
if ~ismember("CO_2EmissionsPerCapita", data.Properties.VariableNames)%if the name we are searching doesnt exist the program stops
    error("Dataset does not contain CO_2EmissionsPerCapita (target variable).");
end

% Predictors: all other numeric columns except year and country and CO_2
% emissions as this is what we want to predict with other data.
predictors = setdiff(data.Properties.VariableNames, {'country','year','CO_2EmissionsPerCapita'});%setdiff(A,B) gives all elemnts in A not in B. So we get what was said up
X = data{:, predictors};   % predictor matrix i.e is a numeric matrix where rows = samples and columns = predictors. as data{:, predictors} selects all rows (:) and only the columns listed in predictors.
y = data.CO_2EmissionsPerCapita;       % target vector
%note X and Y are a matrix and a vector that will form the desired set of
%equations to solve the linear regression. 

% Remove rows with missing values (predictors or target)
validRows = all(~isnan(X),2) & ~isnan(y); %is used to only keep rows with valid predictors and target ie when we have a valid number (not NAN). 
X = X(validRows,:);%we define our matrices with the valid rows.
y = y(validRows,:);



% -----------------2. Split into train/test sets-----------------

fprintf("Dataset size before split: %d rows\n", size(X,1)); % size(X,1) gives the number of rows in X

if size(X,1) > 1
    cv = cvpartition(size(X,1),'HoldOut',0.2); %cvpartition helps splitin data like: % 80% train, 20% test (HoldOut does this). 
    % So cv remembers what is for training and what is for test.
    %training(cv) logical array (true/false) marking which rows go to the training set. analogue for test(cv)
    Xtrain = X(training(cv),:); %selects all predictor columns : ,but only the training rows.
    ytrain = y(training(cv),:);%selects the matching target values for training. 
    Xtest  = X(test(cv),:);
    ytest  = y(test(cv),:);
else%if we have 1 row
    error("Not enough data rows after preprocessing.");
end

%Xtrain, ytrain are used to teach the model.
%Xtest, ytest are used to check if the model learned well on unseen data.


% ----------------3. Training ridge regression model---------------

%the function fitlinear= fit regression linear model. It trains a model to predict a numeric value.
% Regularization parameter (Lambda) can be tuned; start with 1
mdl = fitrlinear(Xtrain, ytrain, ...
    'Learner','leastsquares', ...%Use ordinary least squares regression: find coefficients (a, b, c, …) that minimize squared error between predicted and actual CO₂.formula \min\sum(y-X\beta)^2.
    'Regularization','ridge', ...%Adds ridge penalty (also called L2 regularization). prevents overfitting when predictors are correlated or dataset is small. \min\sum(y-X\beta)^2+<\lambda\sum\beta^2.
    'Lambda',1, ...%λ=1. This is the regularization strength.
    'Solver','lbfgs');% solver computes the best coefficients. lbfgs = Limited-memory BFGS



% ---------------4. Evaluate performance------------------------------
yhat_train = predict(mdl, Xtrain);%predict(mdl, Xtrain) → uses the trained model (mdl) to estimate CO₂ for the training data, 
% so yhat_train = predicted CO₂ values for the training set.
yhat_test  = predict(mdl, Xtest);%analogous

%So at this point we have:
% 1. ytrain = the true CO₂ values (hard data).
% 2. yhat_train = the model's prediction with the train data.
% 3. ytest = true values (test set).
% 4. yhat_test = model's prediction on test set.


%Root Mean Squared Error (RMSE): tells us how far off our predictions are, on average.
rmse_train = sqrt(mean((ytrain - yhat_train).^2));
rmse_test  = sqrt(mean((ytest  - yhat_test ).^2));

%Coefficient of Determination (R²): measures how much of the variation in the data is explained by the  model,
%  formula is R^2= unexplained variation (errors)/ total variationin the data. 
% R^2=1 perfect prediction, R^2=0 model is no better than just guessing the mean, R^2<0 model is worse than guessing the mean.
R2_train   = 1 - sum((ytrain - yhat_train).^2)/sum((ytrain - mean(ytrain)).^2);
R2_test    = 1 - sum((ytest  - yhat_test ).^2)/sum((ytest  - mean(ytest)).^2);

fprintf("Model performance:\n");
fprintf(" - Train RMSE: %.3f, R2: %.3f\n", rmse_train, R2_train);
fprintf(" - Test  RMSE: %.3f, R2: %.3f\n", rmse_test, R2_test);



% -----------------5. Save coefficients----------------------------

if ~exist("wb_outputsQ2","dir")
    mkdir("wb_outputsQ2");
end

coefTbl = table(predictors', mdl.Beta, ...
    'VariableNames', {'Predictor','Coefficient'});
writetable(coefTbl, fullfile("wb_outputsQ2","regression_coefficients.csv"));



% -------------------6. Scenario analysis (GDP +10%)------------

if ismember("GDPperCapitaUS", predictors)
    Xscenario = Xtest;% we do a copy of Xtest so we can leave it unchanged, and work with copy.
    idxGDP = strcmp(predictors,"GDPperCapitaUS");%Logical vector with true value on position of GDP
    Xscenario(:,idxGDP) = 1.1 * Xscenario(:,idxGDP); % +10% GDP
    
    yhat_base = predict(mdl, Xtest);%predicted co2 with og values
    yhat_scen = predict(mdl, Xscenario);%prediced co2 with 10%
    
    % % change in CO2
    pctChange = 100 * (yhat_scen - yhat_base) ./ yhat_base;
    
    % Save results
    scenTbl = table(yhat_base, yhat_scen, pctChange, ...
        'VariableNames', {'PredictedCO2_Base','PredictedCO2_GDP10pct','PctChange'});
    writetable(scenTbl, fullfile("wb_outputsQ2","scenario_results.csv"));
    
    fprintf("Scenario analysis saved to scenario_results.csv\n");
else
    warning("GDP per capita not found in predictors. Scenario skipped.");
end


% --------------------7. Markdown summary----------------

fid = fopen(fullfile("wb_outputsQ2","predictive_summary.md"),'w');
fprintf(fid,"# Predictive Modeling of CO2 Emissions\n\n");
fprintf(fid,"**Model:** Ridge Regression (linear)\n\n");
fprintf(fid,"**Performance:**\n");
fprintf(fid,"- Train RMSE = %.3f, R² = %.3f\n", rmse_train, R2_train);
fprintf(fid,"- Test  RMSE = %.3f, R² = %.3f\n\n", rmse_test, R2_test);
fprintf(fid,"**Scenario:** If GDP per capita increases by 10%%, keeping other factors constant,\n");
fprintf(fid,"the model predicts corresponding %% changes in CO₂ emissions per country (see scenario_results.csv).\n");
fclose(fid);

fprintf("Markdown summary written.\n");
