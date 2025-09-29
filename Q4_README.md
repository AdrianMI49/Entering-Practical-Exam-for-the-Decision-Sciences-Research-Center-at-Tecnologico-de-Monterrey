# Question 4: Classification and Policy Implications

## Objective  
The goal of this task was to **build a classifier** that identifies countries likely to achieve significant reductions in CO₂ emissions in the next decade taking in account just the indicators form the WB.  
We also aimed to extract **policy-relevant insights**:  
- What are the **common characteristics** of countries that successfully reduce emissions?  
- How can policymakers in other nations apply these insights?  

---

## Methodology

### 1. Data Preparation
- We used the **World Bank preprocessed dataset (`wb_preprocessed.csv`)**.  
- Time window considered: **2000–2020**.  
- For each country:  
  1. Extracted CO₂ emissions per capita data.  
  2. Performed a **linear regression trend** (`polyfit`) to measure whether CO₂ emissions were decreasing.  
  3. Defined the **binary target variable**:
     - `1` = Successful country (slope < -0.05 tCO₂/capita/year).  
     - `0` = Not successful.  
  4. Computed the **mean values of all indicators** over the period 2000–2020 to serve as features.  

### 2. Classification Model
- **Algorithm:** Decision Tree Classifier (`fitctree`).  
- **Why trees?**  
  - Handle nonlinear interactions well.  
  - Provide interpretable feature importance.  
  - Useful for small-to-medium datasets.  
- **Validation:**  
  - Used **5-fold cross-validation** (`cvpartition`).  
  - Ensures reliable evaluation without overfitting to one split.  

### 3. Evaluation Metrics
We evaluated performance using standard classification metrics:  
- **Accuracy** = fraction of correct predictions.  
- **Precision** = of the countries predicted successful, how many truly are.  
- **Recall** = of the truly successful countries, how many did the model capture.  
- **F1-score** = harmonic mean of precision and recall (balances both).  

### 4. Feature Importance
- Computed using **predictor importance from the decision tree**.  
- Identified the **top 10 indicators** most predictive of emission reduction success.  

---

## Results

### Model Performance 28/09/2025
- **Accuracy:** ~0.86  
- **Precision:** ~0.67 
- **Recall:** ~0.57 
- **F1-score:** ~0.62 

*(Exact values depend on dataset content.)* The actual values can be read on the console. 

### Top Predictive Features
The most influential variables for predicting successful CO₂ reduction were:  
1. **Renewable Energy Share (%)**  
2. **GDP per capita**  
3. **Energy use per capita**  
4. **Motor vehicles per 1000 people**  
5. **Population growth rate**  
6. **Electricity access (%)**  
7. **Urbanization rate (%)**  
8. **Trade openness (% of GDP)**  
9. **Industry share of GDP (%)**  
10. **Electricity production from low-carbon sources (%)**  

*(Top 10 indicators saved in `wb_outputsQ4/Table_indicators.png`.)*

---

## Interpretation and Policy Insights

### Characteristics of Successful Countries
From the classification model, countries that **reduced CO₂ emissions significantly** in 2000–2020 tended to share these characteristics:  
- **High renewable energy penetration** → greater share of solar, wind, hydro, or nuclear.  
- **Stable or declining vehicle ownership rates** → especially fewer ICE cars per 1000 people.  
- **Energy efficiency improvements** → lower per-capita energy consumption relative to GDP.  
- **Economic structure shifts** → moving from heavy industry to services and knowledge-based sectors.  
- **High access to electricity** → but increasingly from clean sources.  

### Policy Implications
- **Accelerate renewable energy deployment:** Countries lagging in renewable share should prioritize policy and investment in green grids.  
- **Vehicle electrification and public transit:** Policies that encourage EV adoption and reduce dependence on ICE cars are critical.  
- **Energy efficiency standards:** Buildings, appliances, and industrial processes should adopt stricter efficiency norms.  
- **Structural economic transformation:** Encourage diversification away from heavy, carbon-intensive industries.  
- **Knowledge sharing and policy transfer:** Countries identified as “successful” can provide roadmaps for others through international cooperation (e.g., EU Green Deal practices applied elsewhere).  
 *(Disclaimer, for a better analysis of the policy making more indicators need to be added.)*
---

## Deliverables
- **Classification dataset** with country features and binary target:  
  `wb_outputsQ4/classification_dataset.csv`  
- **Top feature importance chart**:  
  `wb_outputsQ4/Table_indicators.png`  
---

## Conclusion
This classification analysis highlights that **policy success in reducing CO₂ emissions is strongly tied to renewable energy adoption, efficient use of energy, and structural changes in the economy**.  
Policymakers should **use these insights to shape targeted interventions**, adapting best practices from successful countries while accounting for local contexts.  

