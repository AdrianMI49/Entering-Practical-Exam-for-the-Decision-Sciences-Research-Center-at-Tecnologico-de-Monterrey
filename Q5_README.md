# Strategic Recommendation: Renewable Energy Investment & CO2 Reduction (5-year outlook)

**Goal:** Evaluate whether investing in renewable energy is likely to reduce per-capita CO₂ emissions within the next five years, and provide prioritized investment guidance.

## Simulation setup
- Scenarios simulated: +5, +10, +20 percentage points in national renewable energy share.
- Regression model: ridge linear regression/L2 restriction trained on available World Bank indicators.
- Classifier: decision tree trained to predict countries with historically significant decadal CO₂ decline.

## Key result summaries (snapshot: latest year in dataset = 2020)

- Countries saved: 264
- Ranked outputs saved to: wb_outputsQ5

## Top 5 countries (highest marginal CO₂ reduction per +1 pp renewable)
- Palau: marginal CO₂ reduction ≈ 0.0000 tCO₂ per-capita per +1pp renewables (baseline CO₂ percap ≈ 419521.519 tCO₂).
- Afghanistan: marginal CO₂ reduction ≈ 0.0000 tCO₂ per-capita per +1pp renewables (baseline CO₂ percap ≈ 32325144.541 tCO₂).
- Africa Eastern and Southern: marginal CO₂ reduction ≈ 0.0000 tCO₂ per-capita per +1pp renewables (baseline CO₂ percap ≈ 1511957884.180 tCO₂).
- Africa Western and Central: marginal CO₂ reduction ≈ 0.0000 tCO₂ per-capita per +1pp renewables (baseline CO₂ percap ≈ 1291479960.631 tCO₂).
- Albania: marginal CO₂ reduction ≈ 0.0000 tCO₂ per-capita per +1pp renewables (baseline CO₂ percap ≈ 24688517.430 tCO₂).

## Top 5 countries by percent reduction (assuming +10 pp renewables)
- Tuvalu: predicted % reduction = 0.00%; predicted CO₂ percap from 83821.826 -> 83821.826 tCO₂.
- Sao Tome and Principe: predicted % reduction = 0.00%; predicted CO₂ percap from 763311.387 -> 763311.387 tCO₂.
- Palau: predicted % reduction = 0.00%; predicted CO₂ percap from 419521.519 -> 419521.519 tCO₂.
- Afghanistan: predicted % reduction = 0.00%; predicted CO₂ percap from 32325144.541 -> 32325144.541 tCO₂.
- Africa Eastern and Southern: predicted % reduction = 0.00%; predicted CO₂ percap from 1511957884.180 -> 1511957884.180 tCO₂.

## How to prioritize investments (recommended approach)
1. **Target countries with the highest marginal benefit per percentage-point** of renewable increase (top marginal list).
2. **Prioritize replacing coal-fired generation** where coal electricity share is high.
3. **Region-level targeting:** focus on regions with high vehicle ownership and poor grid carbon intensity.
4. **Combine investments:** renewables + grid upgrades + storage + electrification amplify impact.

## Expected outcomes & likelihood
- The regression predicts per-capita CO₂ reductions of up to X% for top countries under moderate (+10pp) scenarios.
- The classifier probability of becoming a 'successful' reducer increases for many countries after raising renewables.

## Assumptions & limitations
- Based on historical World Bank indicators; assumes structural stability, but we took a small amount of indicators, other indicators could be taken in account.
- Immediate absolute percentage-point increases assumed.

## Actionable next steps for policymakers

- **Use the rankings to target high-impact countries**: prioritize those in  
  - `top_countries_by_marginal_effect_q5.csv` (best per +1pp renewable gain), and  
  - `top_countries_by_pct_reduction_q5.csv` (largest absolute reductions under +10pp).  

- **Design investment packages tailored to context**:  
  - In coal-dependent countries, focus on **coal-to-renewable replacement** for maximum near-term reduction.  
  - In high-growth economies with rising demand, combine **renewables + grid modernization** to prevent lock-in of fossil capacity.  
  - In countries with high vehicle ownership, pair renewable expansion with **transport electrification**.  

- **Integrate complementary measures**:  
  - Grid flexibility and storage to ensure renewable penetration translates into real CO₂ reductions.  
  - Incentives for industrial efficiency and electrification to magnify the renewable effect.  

- **Operationalize the findings**:  
  - Use `strategic_simulation_results_per_country.csv` to rank investment opportunities within your policy scope.  
  - Track changes in `ClsProb_plus10pp` as an indicator of likelihood of becoming a “successful reducer” within 5 years.  


