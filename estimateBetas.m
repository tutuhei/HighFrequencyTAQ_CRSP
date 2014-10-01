function betas = estimateBetas(lookback, freq, useon, useproxy)
if nargin < 1 || isempty(lookback), lookback = 1;     end
if nargin < 2 || isempty(freq),     freq     = 5;     end
if nargin < 3 || isempty(useon),    useon    = false; end
if nargin < 4 || isempty(useproxy), useproxy = false; end

writeto = '.\results\';

% Sample if data doesn't exist
path2data = sprintf('.\\data\\TAQ\\sampled\\%dmin', freq);
if exist(path2data,'dir') ~= 7 || numel(dir(path2data)) <= 2
    fprintf('%s: sampling data at %d min.\n', mfilename, freq)
    step    = freq/(60*24);
    grid    = (9.5/24:step:16/24)';
    fmtname = sprintf('S%dm_%%04d.mat',freq);
    sampleData(grid, path2data, fmtname);
end 

try
    fprintf('%s: loading betacomponents at %d min.\n', mfilename, freq)
    name  = sprintf('betacomponents%dm',freq);
    betas = loadresults(name);
catch
    % Use self-built sp500 proxy
    if useproxy
        name = sprintf('sp500proxy%dm',freq);
        try
            sp500 = loadresults(name);
        catch
            fprintf('%s: creating ssp500proxy at %d min.\n', mfilename, freq)
            sp500 = sp500intraday(path2data);
        end
        % Use spyders
    else
        name = sprintf('spysampled%dm',freq);
        try
            sp500 = loadresults(name);
        catch
            fprintf('%s: extracting spyders at %d min.\n', mfilename, freq)
            master = load(fullfile(path2data,'master'),'-mat');
            sp500  = getTaqData(master, 'SPY',[],[],'Price',path2data);
            fname  = fullfile(writeto, sprintf('%s_%s.mat',datestr(now,'yyyymmdd_HHMM'),name));
            save(fname, 'sp500')
        end
    end
    
    % SP500 ret 
    spret = [sp500.Datetime(2:end) sp500.Price(2:end)./sp500.Price(1:end-1)-1];
    ion   = diff(rem(sp500.Datetime,1)) >= 0;
    
    % Add overnight return or discard
    if useon
        ion               = find(~ion);
        reton             = loadresults('return_overnight');
        spreton           = reton(reton.UnID == 29904,:);
        [idx,pos]         = ismember(serial2yyyymmdd(spret(ion,1)),spreton.Date);
        spret(ion(idx),2) = spreton.Onret(pos(idx));
    else
        spret = spret(ion,:);
    end
        
    % Cache SP500 returns by days
    load(fullfile(path2data,'master'),'-mat','mst');
    nfiles = max(mst.File);
    cached = cell(nfiles,1);
    
    dates           = fix(spret(:,1));
    [spdays,~,subs] = unique(dates,'stable');
    spret           = mat2cell(spret(:,2), accumarray(subs,1),1);
    
    unMstDates = accumarray(mst.File, mst.Date,[],@(x){yyyymmdd2serial(unique(x))});
    for ii = 1:nfiles
        pos        = ismembc2(unMstDates{ii}, spdays);
        nnzero     = pos ~= 0;
        isp        = ismembc(spdays, unMstDates{ii});
        cached{ii} = {spret(isp) spdays(pos(nnzero))};
    end
    
    % Cache overnight returns
    if useon
        reton.File      = zeros(size(reton,1),1,'uint16');
        [idx,pos]       = ismemberb(reton(:,{'Date','UnID'}), mst(:,{'Date','UnID'}));
        reton.File(idx) = mst.File(pos(idx));
        reton           = reton(reton.File ~= 0,{'UnID','Date','Onret','File'});
        cached          = [cached,...
                           accumarray(reton.File,(1:size(reton))',[],@(x) {reton(x,{'UnID','Date','Onret'})})];
    end
    
    % Calculate beta components: sum(r*benchr) and sum(benchr^2)
    fprintf('%s: creating betacomponents at %d min.\n', mfilename, freq)
    fmtname          = sprintf('S%dm_*.mat',freq);
    [betas,filename] = Analyze('betacomponents', [], cached, fullfile(path2data,fmtname));
    
    % Rename to append the sampling frequency
    newfullname = fullfile(writeto,regexprep(filename,'\.mat',sprintf('%dm$0',freq)));
    movefile(fullfile(writeto,filename), newfullname);
end

% Sort and create subs
betas      = sortrows(betas,{'UnID','Date'});
[~,~,subs] = unique(betas.UnID);

% Beta
num        = accumarray(subs, betas.Num, [], @(x) runsum(lookback,x));
den        = accumarray(subs, betas.Den, [], @(x) runsum(lookback,x));
betas.Beta = cat(1,num{:})./cat(1,den{:});
end

function rs = runsum(lookback, data)
    rs        = NaN(size(data));
    nonan     = ~isnan(data);
    rs(nonan) = filter(ones(lookback,1), 1, data(nonan), NaN(lookback-1,1));
    rs        = {rs};
end