# Predictive Modeling of CO₂ Emissions

This project builds a **predictive model** for per-capita CO₂ emissions using socio-economic indicators from the **World Bank dataset** (preprocessed in Question 1).  
The modeling approach uses **linear regression** with **ridge ridge/L2 pennalty** to handle multicollinearity among predictors and avoid overfitting.

---

## Workflow

### 1. Load Data
- Reads the **preprocessed dataset** (`wb_preprocessed.csv`) from Question 1.  
- Target variable: `CO_2EmissionsPerCapita`.  
- Predictors: all other numeric indicators (GDP, population, energy use, etc.).

### 2. Data Cleaning
- Removes rows with missing values in predictors or target.  
- Ensures only valid numeric rows are used.

### 3. Train/Test Split
- Splits data: **80% training**, **20% testing** (`cvpartition` with HoldOut).  
- This ensures robust evaluation on unseen data.

### 4. Ridge Regression Model
- Trains a **linear regression model** with **L2 regularization (ridge penalty)**:  


$\min_\beta \sum (y - X\beta)^2 + \lambda \sum \beta^2$


- Parameters:
  - Learner: `leastsquares`
  - Regularization: `ridge`
  - Lambda: `1`
  - Solver: `lbfgs`

### 5. Performance Evaluation
- Predictions are made on both training and test sets.  
- Metrics:
  - **RMSE (Root Mean Squared Error)** -> average prediction error.
  - **R² (Coefficient of Determination)** -> proportion of variance explained.  

Results are printed to console and summarized in Markdown.

### 6. Coefficients
- Saves regression coefficients (`regression_coefficients.csv`) for interpretability.  
- Each coefficient shows the marginal effect of one predictor on CO₂ emissions.

### 7. Scenario Analysis
- Tests a **“GDP per capita +10%” scenario**.  
- Predicts CO₂ emissions with increased GDP (holding other variables constant).  
- Saves results in `scenario_results.csv`, including percent change in emissions.

### 8. Markdown Report
- Generates a summary report (`predictive_summary.md`) with:
  - Model type
  - Performance metrics
  - Scenario description

---

##  Outputs
- `wb_outputsQ2/regression_coefficients.csv` -> predictor effects  
- `wb_outputsQ2/scenario_results.csv` -> GDP +10% scenario impact  
- `wb_outputsQ2/predictive_summary.md` -> Markdown summary  

---

## Requirements
- MATLAB (tested with R2023b)  
- Output from **Question 1** preprocessing (`wb_preprocessed.csv`)


