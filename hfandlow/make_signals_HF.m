function signals = make_signals_HF(permno,date,master,reton,factors,skew,beta)

[unDt,~,midx] = unique(date/100);
nmonths       = numel(unDt);
nseries       = numel(permno);
signals       = NaN(nmonths, nseries,3);

% Alpha
signals(:,:,1) = estimateAlpha(permno,date,factors,master,reton);

% Skewness
for ii = 1:nmonths
    imonth          = midx == ii;
    signals(ii,:,2) = nanmean(skew(imonth,:));
end

% % Betas
% for ii = 12:nmonths
%     iyear = ismember(midx, ii-12+1:ii);
%     nobs  = nnz(iyear);
%
%     signals(ii,nonans,4) = coeff(2,:);
% end
end

function signals = estimateAlpha(permno,date,factors,master,reton)

unDt    = unique(date/100);
nmonths = numel(unDt);
nseries = numel(permno);
signals = NaN(nmonths, nseries);

for ii = 1:nmonths
    % Get data
    [ret, permnoFound, dt] = getHighFreqRet(unDt(ii),reton, master);

    % make sure dates are same
    idx = ismember(dt,date);
    ret = ret(idx,:);
    dt  = dt(idx);

    % Get mkt
    imkt        = permnoFound == 84398;
    mkt         = ret(:, imkt);
    ret         = ret(:,~imkt);
    permnoFound = permnoFound(~imkt);

    % Expand rf
    [~,~,subs] = unique(dt);
    idx        = ismember(factors.Date, unique(dt));
    rf         = RunLength(factors.RF(idx)/100, accumarray(subs,1));

    % Alpha
    Y = bsxfun(@minus,ret,rf);
    X = [ones(numel(dt),1), mkt-rf];

    % At least some obs
    igood = sum(~bsxfun(@or, isnan(mkt), isnan(Y))) > 10;

    coeff = NaN(2,numel(permnoFound));
    for jj = 1:numel(permnoFound)
        if igood(jj)
            coeff(:,jj) = regress(Y(:,jj),X);
            % Set to NaN rank deficient estimates
            if strncmpi(lastwarn(),'X is rank',9)
                igood(jj) = false;
                lastwarn('');
            end
        end
    end
    coeff(:,~igood) = NaN;
    [~,pos]         = ismember(permnoFound, permno);
    signals(ii,pos) = coeff(1,:);

    %     % Skewness
    %     signals(ii,nonans,2) = skewness(r);
    %     signals(ii,nonans,3) = sqrt(nobs) * sum(r.^3) ./ sum(r.*r).^1.5;
end
end

function [data, permnoFound, dates] = getHighFreqRet(month, reton, master)
% Get prices
from = month*100+1;
to   = month*100+31;
data = getTaqData('permno',[],from,to,[],'..\data\TAQ\sampled\5min\nobad_vw',master,false);

% Add returns
data = price2ret(data);
data = addOvernightRet(data,reton(in(reton.Date,[from,to]),:));

% Unstack
data.Date   = serial2yyyymmdd(data.Datetime);
data.Time   = serial2hhmmss(data.Datetime);
data        = sortrows(unstack(data(:,{'Date','Time','Permno','Ret'}),'Ret','Permno'),{'Date','Time'});
permnoFound = xstr2num(data.Properties.VariableNames(3:end));
dates       = data.Date;
data        = data{:,3:end};
end

function data = price2ret(data)
data.Ret        = [NaN; diff(log(data.Price))];
ion             = [true; diff(fix(data.Datetime)) ~= 0] |...
                  [true; diff(data.Permno) ~= 0];
data.Ret(ion,1) = NaN;
end
