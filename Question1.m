% =====================================================================
% Robust World Bank download + basic preprocessing
% =====================================================================


clc; clear; close all;

%%------------------------settings----------------------------


startYear = 1990;
endYear   = 2020;
%indicators that we will download, where the official WB code on the left
%is assigned to the one we will be using in this code. This is a cell array
%where each row is one indicator. 
indicators = { ...
    'EN.GHG.CO2.PC.CE.AR5', 'CO_2EmissionsPerCapita'; ...
    'NY.GDP.MKTP.CD', 'GDPcurrentInUS'; ...
    'NY.GDP.PCAP.CD', 'GDPperCapitaUS'; ...
    'SP.POP.TOTL', 'PopulationTotal'; ...
    'EG.USE.PCAP.KG.OE', 'EnergyUsePerCapitaKgOilEq'; ...
    'SP.URB.TOTL.IN.ZS', 'UrbanPopulationPercentage'; ...
    'SE.XPD.TOTL.GD.ZS', 'EducationExpenditurePercentageGDP'; ...
    'EG.FEC.RNEW.ZS', 'RenewableEnergySharePercentage'; ...
    "IS.VEH.NVEH.P3", 'MotorVehiclesPer1000People'; ...
    "EG.ELC.COAL.ZS", 'ElectricityFromCoalPerc'; ...
    "EG.ELC.NUCL.ZS", 'ElectricityFromNuclearPerc'; ...
    "EG.ELC.RNWX.ZS", 'ElectricityFromRenewablesPerc'; ...
    "EG.ELC.FOSL.ZS",  'ElectricityFromFossilFuelsPerc'; ...
    %"EN.ATM.CO2E.EG.ZS" 'CO_2IntensityOfEnergyKgPerKgOilEquivalent)'; ...
};

  
%now we create (mkdir) the output folder in the case it does not exist. 
outDirect = "wb_outputs"
if ~exist(outDirect, "dir");
    mkdir(outDirect);
end




% -------------------DOWNLOAD ALL INDICATORS (robust)-----------------------

fprintf("Downloading data from World Bank...\n");
tables = cell(size(indicators,1),1);%creates an array with all the tables of the indicators that are gonna be created by T

for k=1:size(indicators,1)%loop through all indicators, that links the code with the name we want and then defines the complete array
    code = indicators{k,1};
    name = indicators{k,2};
    fprintf(" - %s (%s)\n", name, code); 
    T = fetchWB(code, name, startYear, endYear);   % local function below that contacts WB APi, parses the JSON and gives a table with 3 coulums year, country and indicator, that goes int the kth row of table
    if istable(T) && height(T)>0 %returns true if T is a MATLAB table object, returns the number of rows of the table T.
        tables{k} = T; %writes the entire table T into the k-th cell of tables.
        %The if condition therefore checks: Is T actually a table, and does it contain at least one row? If both are true, we consider the download successful.
    else
        tables{k} = table(); % constructs an empty MATLAB table and is stored into tables{k} as a placeholder. 
        % That keeps the indexing consistent: the tables cell array has the same length and positions as the indicators list. Later code can detect and skip empty entries
        warning("Indicator %s returned empty table (skipped).", name);
    end
end



% -----------------MERGE TABLES (skip empties)-------------------------------
nonempty_idx = []; %creates an empty numeric array so that it stores the indices of those entries in tables that are not empty.
for k=1:numel(tables) %returns the number of elements in the array tables.
    if istable(tables{k}) && ~isempty(tables{k}) && height(tables{k})>0 %checks whether the current entry in tables is valid data.
        nonempty_idx(end+1) = k; %we add k (the index of the valid table) to the list nonempty_idx.
    end
end

if isempty(nonempty_idx)
    error("No indicator data was downloaded. Check internet / API.");
end

df = tables{nonempty_idx(1)}; % this is the merged dataset of all the non empty tables, starts with the first usable table.
for idx = nonempty_idx(2:end)
    df = outerjoin(df, tables{idx}, 'Keys',{'country','year'}, 'MergeKeys',true);% here we are doing the merge of the rows by specific keys
end

% writes a MATLAB table to a text file, and we save this raw data
writetable(df, fullfile(outDirect,"wb_raw_download.csv"));
fprintf("Raw data saved to %s\n", fullfile(outDirect,"wb_raw_download.csv"));


% -----------------------BASIC PREPROCESSING-------------------------------
% If there are no numeric columns beyond country/year, stop early
allVars = df.Properties.VariableNames;%gets a list of all column names in the table
if numel(allVars) <= 2
    error("No numeric indicators present after download/merge.");
end%if we have only 2 columns, then we have no actual indicators, so we stop with an error.
%Otherwise, we take all columns starting from the 3rd one. This ensures we
%are working with the indicators which are numerical.

numVarNames = allVars(3:end);

% Drop countries with >70% missing across indicators
countryList = unique(df.country);%list of unique contry names
dropCountries = strings(0);
for i=1:numel(countryList)
    sub = df(strcmp(df.country,countryList(i)), :);%we take only its rows of the contries, temporary table for each contry
    % selects only the numeric columns for that country,
    %then creates a matrix of true and false, we take the mean if > 70 then
    %we eliminate
    fracMissing = mean(mean(ismissing(sub{:,numVarNames})));
    if fracMissing > 0.7
        dropCountries(end+1) = countryList(i); %
    end
end
if ~isempty(dropCountries)% here we explicitly are eliminating the country form df
    fprintf("Dropping %d countries with >70%% missing.\n", numel(dropCountries));
    df = df(~ismember(df.country, dropCountries), :);
end

% Interpolate missing values per-country by year. If a country has only NaNs for a column it stays NaN.
dfInterp = table();
countries = unique(df.country);
for c = 1:numel(countries)%For each contry we make sure that the rows are in cronological order
    sub = df(strcmp(df.country,countries(c)), :);
    sub = sortrows(sub,'year');
    
    for vn = 1:numel(numVarNames)%For each numeric column (indicator), extract the column as a vector vec.
        col = numVarNames{vn};
        vec = sub.(col);
        if ~all(isnan(vec))%If not all values are missing, we use the following to fill missing values by linear interpolation. this avoids erros after
            vecFilled = fillmissing(vec,'linear','EndValues','nearest');
            sub.(col) = vecFilled;
        else
            % leave as NaN
            sub.(col) = vec;
        end
    end
    dfInterp = [dfInterp; sub]; %Notice that we worked with sub to do the interpolation here we gather all the subs and put them in a clean data set where each row is a sub.
end

% Save preprocessed
writetable(dfInterp, fullfile(outDirect,"wb_preprocessed.csv"));
fprintf("Preprocessed data saved to %s\n", fullfile(outDirect,"wb_preprocessed.csv"));

% ------------------- OUTLIER FLAGGING with respect the IQR in each indicator(Q_3-Q_1=IQR)------------
% First line creates empty vert table with an indicator in each row with a
% subsequent zero which will keep the count of outliers for each indicator with the for.

outlierCounts = table(numVarNames', zeros(numel(numVarNames),1), 'VariableNames', {'Indicator','OutlierCount'}); 
for i=1:numel(numVarNames)
    col = numVarNames{i};%gets name of indicator
    x = dfInterp.(col); % get column of our clean data set (i.e an indicator coloumn) 
    % this is a vector with all the values of that indicators for all contries all years. Can have missing data NAN we want to check this
    xnum = x(~isnan(x)); %~isnan is another vector same size as x with ture, and false for entries. false=nan, true=anyvalue.
    %so xnum is only taking the entries of x that are true
    if isempty(xnum) %if the xnum is filled with false then we set the outliers to zero as there is no valid info
        outlierCounts.OutlierCount(i) = 0;
        continue
    end
    %caluclation of IQR
    q1 = quantile(xnum,0.25);
    q3 = quantile(xnum,0.75);
    iqrVal = q3 - q1;
    low = q1 - 1.5*iqrVal;
    high = q3 + 1.5*iqrVal;
    flags = (x < low) | (x > high);
    outlierCounts.OutlierCount(i) = sum(flags,'omitnan');%Here we flag what went beyond our bounds and print them in the cvs
end
writetable(outlierCounts, fullfile(outDirect,"outlier_counts.csv"));
fprintf("Outlier counts written.\n");

% -------------------- SUMMARY STATISTICS + CORRELATION------------------

% Compute mean/std/min/max per indicator
statsTbl = table(numVarNames', 'VariableNames', {'Indicator'}); %creates a column with each indicator
statsTbl.Mean = zeros(height(statsTbl),1);%this an the rest add a zero column for each stat of the indicator.
statsTbl.Std  = zeros(height(statsTbl),1);
statsTbl.Min  = zeros(height(statsTbl),1);
statsTbl.Max  = zeros(height(statsTbl),1);

for i=1:numel(numVarNames)%Loop that calculates all the stats for the indicators while ignoring the NAN. 
    col = numVarNames{i};
    v = dfInterp.(col);
    statsTbl.Mean(i) = mean(v,'omitnan');
    statsTbl.Std(i)  = std(v,'omitnan');
    statsTbl.Min(i)  = min(v, [], 'omitnan');
    statsTbl.Max(i)  = max(v, [], 'omitnan');
end

writetable(statsTbl, fullfile(outDirect,"summary_stats.csv"));%print table with all stats
fprintf("Summary stats written.\n");


% Correlation matrix (pairwise)
numericData = dfInterp{:, numVarNames};%extracts all numeric columns as a numeric matrix
% If there's only one numeric column, corr will fail, so...
if size(numericData,2) > 1
    corrMat = corr(numericData, 'Rows', 'pairwise');%this is our correlation matrix, For each pair of variables, use only the rows where both variables have valid (non-missing) values.
    %avoid eliminating an entire row for unrelated missing values.

    writematrix(corrMat, fullfile(outDirect,"corr_pearson.csv"));%saves, and draws the matrix we calculated
    figure;
    heatmap(numVarNames, numVarNames, corrMat);
    title("Pearson correlation heatmap");
    saveas(gcf, fullfile(outDirect,"corr_heatmap.png"));
else
    warning("Not enough numeric columns for correlation matrix.");
end

% --------------------Simple example plot (first country available)-----------

if ~isempty(countries)%if the list of contries is not empty after preprocessing then we take the first country of the list and do the heat map as an example. 
    exampleC = countries(1);
    sub = dfInterp(strcmp(dfInterp.country,exampleC), :);
    fig = figure('Visible','off');
    hold on;
    plotted = false;
    if ismember('co2_percap', numVarNames)
        plot(sub.year, sub.co2_percap, '-o', 'DisplayName','CO2 percap');
        plotted = true;
    end
    if ismember('gdp_percap', numVarNames)
        plot(sub.year, sub.gdp_percap, '-x', 'DisplayName','GDP percap');
        plotted = true;
    end
    if plotted
        xlabel('Year'); ylabel('Value'); title("Time series: " + exampleC);
        legend('Location','best'); grid on;
        saveas(fig, fullfile(outDirect,"time_series_example.png"));
        close(fig);
        fprintf("Example time series saved.\n");
    end
end

% --------------Markdown summary-----------------

%This creates a human-readable text file (.md, Markdown format) with a summary of what was downloaded and processed.
fid = fopen(fullfile(outDirect,"summary.md"),'w');
fprintf(fid,"# World Bank CO2 & Socio-economic Data\n\n");
fprintf(fid,"Years: %d–%d\n\n", startYear, endYear);
fprintf(fid,"Indicators requested:\n");
for k=1:size(indicators,1)
    fprintf(fid, "- %s (%s)\n", indicators{k,2}, indicators{k,1});
end
fprintf(fid,"\nCountries dropped (>70%% missing):\n");
if exist('dropCountries','var') && ~isempty(dropCountries)
    fprintf(fid, "%s\n", strjoin(dropCountries, ", "));
else
    fprintf(fid, "None\n");
end
fprintf(fid,"\nOutlier counts are in outlier_counts.csv\n");
fclose(fid);
fprintf("Markdown summary written.\n");

% END OF MAIN SCRIPT

% -------------------------------
% -------------------------------
% FUNCTION fetchWB
% This function handles different shapes returned by webread (cell or struct).
% -------------------------------
% -------------------------------

function T = fetchWB(indicatorCode, indicatorName, startY, endY)
    base = "http://api.worldbank.org/v2/country/all/indicator/";% base url
    url = base + indicatorCode + "?date=" + startY + ":" + endY + "&per_page=20000&format=json";%we build the url where we will get the indicator data
    try%we try to download the info with webread
        raw = webread(url);
    catch ME %if the internet fails, we use this to avoid a crash, gives empty table
        warning("webread failed for %s: %s", indicatorCode, ME.message);
        T = table(strings(0,1), zeros(0,1), zeros(0,1), 'VariableNames', {'country','year',indicatorName});
        return;
    end

    % Determine where the entries (data) live:
%if it's a cell array (iscell(raw)), the actual data is usually in the second cell raw{2}.
%If it's already a struct array, then the data is directly inside.
%If neither, we just set entries = {} (empty).
    if iscell(raw)
        if numel(raw) >= 2
            entries = raw{2};
        else
            entries = {};
        end
    elseif isstruct(raw)
        % raw could already be the array of entries or a struct with fields.
        % If raw has numeric indices, treat as struct array
        entries = raw;
    else
        entries = {};
    end
%Prepare empty arrays for the data: 
    n = numel(entries);
    country = strings(n,1);
    year = nan(n,1);
    val = nan(n,1);
%Loops through each record, each e is one observation: one country, one year, one value.
    for i = 1:n
        % allow both cell and struct arrays
        if iscell(entries)
            e = entries{i};
        else
            e = entries(i);
        end

        % World Bank API sometimes encodes country as a struct with a value field. So we extract it
        if isfield(e,'country')
            c = e.country;
            if isstruct(c) && isfield(c,'value')
                country(i) = string(c.value);
            else
                country(i) = string(c);
            end
        else
            country(i) = "";
        end

        % same for year: e.date
        if isfield(e,'date')
            year(i) = str2double(string(e.date));
        else
            year(i) = NaN;
        end

        % same for value: e.value (may be empty)
        if isfield(e,'value')
            v = e.value;
            if isempty(v)
                val(i) = NaN;
            else
                % numeric or string convertible to number
                val(i) = double(v);
            end
        else
            val(i) = NaN;
        end
    end
%build the final table as the following:
    T = table(country, year, val, 'VariableNames', {'country','year',indicatorName});
end
