# World Bank CO₂ & Socio-economic Data Processing

This MATLAB script downloads, merges, and preprocesses socio-economic indicators from the **World Bank API**, focusing on CO₂ emissions and related variables. 
It produces cleaned datasets, performs basic analysis, and generates summary outputs.

---

## Workflow

### 1. Settings
- Define the analysis time window (`startYear`, `endYear`).
- List of **World Bank indicators** to download (with their official codes and custom names).

### 2. Download Data
- Uses the World Bank API (`fetchWB` function).
- Each indicator is downloaded as a separate table.
- Handles errors, so that if the API fails it empties tables.

### 3. Merge Data
- Combines all non-empty tables into one dataset.
- Uses `outerjoin` on `country` and `year` keys.
- Saves raw merged data as `wb_raw_download.csv`.

### 4. Basic Preprocessing
- Removes countries with >70% missing values.
- Interpolates missing values **per country** by year, using linear interpolation.
- Saves cleaned dataset as `wb_preprocessed.csv`.

### 5. Outlier Flagging
- Uses the **Interquartile Range (IQR)** method.
- Counts outliers for each indicator.
- Saves counts to `outlier_counts.csv`.

### 6. Summary Statistics + Correlation
- Calculate mean, std, min, max for each indicator.
- Saves results to `summary_stats.csv`.
- Builds Pearson correlation matrix and a heatmap (`corr_heatmap.png`).

### 7. Example Plot for first country
- Creates a time-series plot of CO₂ and GDP for the first country in the dataset.
- Saves figure as `time_series_example.png`.

### 8. Markdown Summary
- Generates a readable report (`summary.md`) with:
  - Years analyzed
  - Indicators requested
  - Dropped countries
  - Outlier info

---

## Output Files

All outputs are saved in the `wb_outputs/` folder:

- `wb_raw_download.csv` -> Raw merged dataset  
- `wb_preprocessed.csv` -> Cleaned dataset (after interpolation)  
- `outlier_counts.csv` -> Outlier counts per indicator  
- `summary_stats.csv` -> Mean, Std, Min, Max per indicator  
- `corr_pearson.csv` -> Correlation matrix (numeric matrix)  
- `corr_heatmap.png` -> Heatmap  
- `time_series_example.png` -> Example time-series plot  
- `summary.md` -> Markdown summary  

---

## Key Function

### `fetchWB(indicatorCode, indicatorName, startY, endY)`
- Downloads indicator data from World Bank API.
- Handles both JSON structures (`cell` or `struct`).
- Extracts: **country, year, value**.
- Returns a MATLAB table.

---

## Indicators Included

The script downloads the following indicators (World Bank code -> custom name):

- `EN.GHG.CO2.PC.CE.AR5` -> CO₂ emissions per capita  
- `NY.GDP.MKTP.CD` -> GDP current US$  
- `NY.GDP.PCAP.CD` -> GDP per capita (US$)  
- `SP.POP.TOTL` -> Total population  
- `EG.USE.PCAP.KG.OE` -> Energy use per capita (kg oil eq.)  
- `SP.URB.TOTL.IN.ZS` -> Urban population (%)  
- `SE.XPD.TOTL.GD.ZS` -> Education expenditure (% GDP)  
- `EG.FEC.RNEW.ZS` -> Renewable energy share (%)  
- `IS.VEH.NVEH.P3` -> Motor vehicles per 1000 people  
- `EG.ELC.COAL.ZS` -> Electricity from coal (%)  
- `EG.ELC.NUCL.ZS` -> Electricity from nuclear (%)  
- `EG.ELC.RNWX.ZS` -> Electricity from renewables (%)  
- `EG.ELC.FOSL.ZS` -> Electricity from fossil fuels (%)  
