# Question 3: Fermi Problem and Sensitivity Analysis

## Task  
Estimate the impact on global CO₂ emissions if **50% of the world’s population adopted electric vehicles (EVs)**. Use the model to perform sensitivity analysis and answer:  
*“Which countries would see the most significant reduction in emissions, and by how much?”*

---

## Methodology  

1. **Data preparation**  
   - Dataset: `wb_preprocessed.csv` (World Bank indicators, cleaned).  
   - Excluded aggregate/region rows (e.g., “World,” “OECD,” “High income”).  
   - Missing values for *vehicles per 1000 people* and *renewable energy share* were imputed with the **median across non-aggregate countries**.  

2. **Model assumptions**  
   - **Baseline EV share** = 20% (couldn't find a good indicator or dataset that had the adoption rates for all contries, so for simplicity of this exam I took the 20% that is the world avrege according to the IEA, for a more
   - thorough analysis this data set must be generated. Maybe by comparing the stocks of evs compared to the shares of the ev in every contry).  
   - **Target EV share** = 50%.  
   - **Delta** = +30% of vehicles shift from ICE -> EV.  

3. **Emission factors**  
   - ICE vehicle annual emissions: **4.6 tonnes CO₂**.  
   - EV annual electricity demand: **3000 kWh**.  
   - Grid carbon intensity: **0.45 kg CO₂/kWh**, adjusted per country using renewable share.  

4. **Computation**  
   - Vehicle stock = (vehicles per 1000 people × population).  
   - New EVs = 30% of total vehicle stock.  
   - Avoided emissions per EV =  
     
     $$\text{CO}_{2_{ICE}}-\text{CO}_{2_{EV}}$$
    
     (values < 0 set to 0).  
   - Total reduction = New EVs × avoided emissions per EV.  
   - Percent reduction =  
     
     $$100 \times \frac{\text{Reduction}}{\text{Baseline CO₂ emissions}}$$ 

---

## Outputs  

- **Results tables** (saved in `wb_outputsQ3/`):  
  - `ev_country_reduction_results.csv` -> all countries (excl. aggregates).  
  - `top_countries_by_abs_reduction.csv` -> top 200 by absolute reduction.  
  - `top_countries_by_pct_reduction.csv` -> top 200 by percent reduction.  

- **Console output**:  
  - Top 10 countries by absolute annual CO₂ reduction (tonnes/yr).  
  - Top 10 countries by percent reduction of baseline CO₂ (%).  

---

## Discussion  

- **Key drivers of emission reduction**:  
  1. Vehicle density (vehicles per capita).  
  2. Population size.  
  3. Electricity grid mix.  

- **Limitations**:  
  - Fixed baseline EV share (20%).  
  - Grid carbon intensity averaged where no data is available.  
  - Assumes constant vehicle use and emissions across all countries.  
  - Snapshot model (does not capture dynamic trends).  

---

## Conclusion  

- Large, high-vehicle countries (e.g., US, China, India) dominate the **absolute reduction rankings**.  
- Smaller nations with cleaner grids can achieve larger **percentage reductions**.  
- While simplified, this Fermi-style sensitivity model highlights the global CO₂ mitigation potential of widespread EV adoption and identifies where impacts are most significant.

## Note: 
- Important definition: A Fermi problem is an estimation problem where you don’t have complete data but you still want to arrive at a reasonable order-of-magnitude answer.
- Why this is a Fermi problem?
- Ans: We don’t have exact, complete data for every country (e.g., EV adoption, vehicle stock, driving behavior, energy mix).
  Instead, we make simplifying assumptions:
  1. Average emissions of an ICE car.
  2. Average electricity demand of an EV.
  3. Global average carbon intensity of electricity (adjusted with renewable share).
  4. Assumed baseline adoption (20%) vs. scenario adoption (50%).
Then we scale up by country population and vehicles per capita to estimate total reductions.
This lets us approximate global impact without needing perfect, detailed data for every input.
