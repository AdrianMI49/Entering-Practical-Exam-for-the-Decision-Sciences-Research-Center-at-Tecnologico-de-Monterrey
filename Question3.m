% =====================================================================
% Robust country ranking for CO2 reduction (20% -> 50% EV), reading
% wb_preprocessed.csv. Imputes missing MotorVehiclesPer1000 values using
% the median (computed excluding aggregates), and removes common region/aggregate rows.
% =====================================================================



clc; clear; close all;

% ---------- SETTINGS ----------
baselineEVshare = 0.20;  % We assume all contries have 20% of ev cars, as there are no indicators to include.
targetEVshare   = 0.50; 
deltaEVshare    = targetEVshare - baselineEVshare;

% Per-vehicle and electricity parameters (assumed values)
CO2perVehicle_ICE = 4600;  % average annual CO2 emissions from an internal combustion vehicle
kWhPerEV = 3000;           % average annual electricity consumption per EV.
CO2perKWh = 0.45;          % carbon intensity of the electricity grid (kg CO₂ per kWh).GLOBAL AVG

% ---------- READ DATA ----------
fn = fullfile("wb_outputs/","wb_preprocessed.csv");
% preserve exact column names so we can reference the names you have
T = readtable(fn, 'VariableNamingRule', 'preserve');

% pick the latest year snapshot
latestYear = max(T.year);
sub = T(T.year == latestYear, :);%only rows

% variables (exact names from CSV, shorter)
pop_col = 'PopulationTotal';
veh_col = 'MotorVehiclesPer1000People';
ren_col = 'RenewableEnergySharePercentage';

% Convert to convenient arrays
country_names = string(sub.country);
Population = double(sub.(pop_col));      % should exist for most rows (numeric array created by dbl)
VehPer1000_raw = double(sub.(veh_col));  % many NaNs here
RenShare_raw = double(sub.(ren_col));    % some NaNs possible

% ---------- IDENTIFY AGGREGATES / REGIONS ----------
% list of keywords that typically mark region / aggregate rows; Supposedly
% as the cvs file is already preprocessed this shouldnt be necesarry though
% is a safe guard. Any error that comes here can be added. 
agg_keywords = {'World','income','region','regions','total','aggregate','group','IBRD','IDA', ...
    'OECD','Euro','Arab','Eastern','Western','Northern','Southern','America','Africa','Asia', ...
    'Pacific','European','Caribbean','countries','Developing','High income','Low income', ...
    'Middle income','Upper middle','Lower middle','demographic','dividend','sub-saharan', ...
    'latin','area','pre-demographic','post-demographic','early-demographic','late-demographic', ...
    'Euro area','IDA only','IBRD only','Fragile','Small states'};

is_agg = false(height(sub),1);%colomn vector of same height as table with all false
low_names = lower(country_names); %everything to lowercase
for k = 1:numel(agg_keywords)%compares the list of exclusions with contries if smth mathces we flag it 
    key = lower(agg_keywords{k});
    is_agg = is_agg | contains(low_names, key);
end

% ---------- COMPUTE MEDIANS ----------
%because of the lack of data here we will fill the data set with a median
nonagg_idx = ~is_agg;%true for all contries
medianVeh = median(VehPer1000_raw(nonagg_idx),'omitnan');%medan of vehicles without nan and agg
if isnan(medianVeh)%if there is no info this sets the median at 200
    warning('No non-aggregate MotorVehicles values available; using fallback 200 veh per 1000.');
    medianVeh = 200;
end
%same for renewables
medianRen = median(RenShare_raw(nonagg_idx),'omitnan');
if isnan(medianRen)
    medianRen = 0; % if no info here we asume there is none. 
end

% ---------- IMPUTE MISSING ----------
VehPer1000 = VehPer1000_raw;%comes from the data set may have nan
VehPer1000(isnan(VehPer1000)) = medianVeh; %fills the missing info

RenShare = RenShare_raw;%same as above
RenShare(isnan(RenShare)) = medianRen;

% ---------- DROP ROWS WITH MISSING POPULATION (cannot compute) ----------
validPop = ~isnan(Population) & Population > 0;
valid_idx = validPop; % keep for now; aggregates already marked separately below

% ---------- COMPUTE TOTAL VEHICLES ----------
TotalVehicles = (VehPer1000 ./ 1000) .* Population; % vehicles in each contry

% set problematic totals to NaN so they are ignored
TotalVehicles(~valid_idx) = NaN;

% ---------- NEW EVs (additional 30%) ----------
NewEVs = deltaEVshare .* TotalVehicles;  % (could be NaN)

% ---------- PER-EV AVOIDED EMISSIONS ----------
effectiveGridCO2 = CO2perKWh .* (1 - (RenShare ./ 100)); % kgCO2/kWh

%CO2perVehicle_ICE: emissions from a typical ICE vehicle in one year.
%(effectiveGridCO2 * kWhPerEV): emissions from charging one EV in that country for a year.
%Subtracting gives net avoided emissions per EV:
avoidedPerEV_kg = CO2perVehicle_ICE - (effectiveGridCO2 .* kWhPerEV); % kg/yr

% avoid negative values (if EV operational > ICE baseline) => set to 0
avoidedPerEV_kg(avoidedPerEV_kg < 0) = 0;

% ---------- total annual avoided CO₂ emissions for each country becasue of 50 increase ----------
Reduction_kg = NewEVs .* avoidedPerEV_kg;
Reduction_tonnes = Reduction_kg ./ 1000;

% ---------- BASELINE CO2 (kg) ----------
EVstock_baseline = baselineEVshare .* TotalVehicles;% Total ev used 20
ICEstock_baseline = (1 - baselineEVshare) .* TotalVehicles;%not ev cars in use
CO2_EV_baseline_kg = EVstock_baseline .* (effectiveGridCO2 .* kWhPerEV);%ev contribution to co2
CO2_ICE_baseline_kg = ICEstock_baseline .* CO2perVehicle_ICE;%ice contribution to co2
BaselineCO2_kg = CO2_EV_baseline_kg + CO2_ICE_baseline_kg;%total
BaselineCO2_tonnes = BaselineCO2_kg ./ 1000;

% ---------- PERCENT REDUCTION ----------Put reductions in context — not just "how many tonnes" but also "what fraction of current emissions are cut".
PctReduction = 100 .* (Reduction_kg ./ BaselineCO2_kg);%
PctReduction(BaselineCO2_kg == 0) = 0;

% ---------- BUILD RESULTS TABLE (exclude aggregates) ----------
resTbl = table(country_names, TotalVehicles, NewEVs, avoidedPerEV_kg, Reduction_tonnes, BaselineCO2_tonnes, PctReduction, ...
    'VariableNames', {'Country','TotalVehicles','NewEVs','AvoidedPerEV_kgPerYear','Reduction_tonnesPerYear','BaselineCO2_tonnesPerYear','PctReduction'});

% remove aggregate rows for final ranking
res_countries = resTbl(~is_agg & ~isnan(resTbl.TotalVehicles), :);

% sort by absolute reduction and by percent reduction
res_sorted_abs = sortrows(res_countries, 'Reduction_tonnesPerYear', 'descend');
res_sorted_pct = sortrows(res_countries, 'PctReduction', 'descend');

% ---------- SAVE & PRINT ----------
if ~exist('wb_outputsQ3', 'dir')
    mkdir('wb_outputsQ3'); 
end
writetable(res_countries, fullfile('wb_outputsQ3','ev_country_reduction_results.csv'));
writetable(res_sorted_abs(1:min(200,height(res_sorted_abs)),:), fullfile('wb_outputsQ3','top_countries_by_abs_reduction.csv'));
writetable(res_sorted_pct(1:min(200,height(res_sorted_pct)),:), fullfile('wb_outputsQ3','top_countries_by_pct_reduction.csv'));

fprintf("Saved results to wb_outputsQ3/ (ev_country_reduction_results.csv and top lists).\n\n");

% Print top 10 absolute
disp("Top 10 countries by absolute annual CO2 reduction (tonnes/yr):");
disp(res_sorted_abs(1:10, {'Country','Reduction_tonnesPerYear','BaselineCO2_tonnesPerYear','PctReduction'}));

% Print top 10 percent
disp("Top 10 countries by percent reduction of baseline CO2 (%):");
disp(res_sorted_pct(1:10, {'Country','Reduction_tonnesPerYear','BaselineCO2_tonnesPerYear','PctReduction'}));
