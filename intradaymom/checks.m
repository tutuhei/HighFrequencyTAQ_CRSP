%% Check Open/Close in TAQ vs CRSP
taq = loadresults('price_fl');

if OPT_NOMICRO
    idx = isMicrocap(taq,'LastPrice',OPT_LAGDAY);
    taq = taq(~idx,:);
end

crsp      = loadresults('dsfquery');
crsp.Prc  = abs(crsp.Prc);
[~,ia,ib] = intersectIdDate(crsp.Permno,crsp.Date, taq.Permno, taq.Date);
crsp      = crsp(ia,:);
taq       = taq(ib,:);

% Filter out outliers
taq.TAQret   = taq.LastPrice./taq.FirstPrice-1;
iout         = taq.TAQret          > OPT_OUTLIERS_THRESHOLD |...
    1./(taq.TAQret+1)-1 > OPT_OUTLIERS_THRESHOLD;
taq(iout,:)  = [];
crsp(iout,:) = [];

% Comparison table
cmp         = [crsp(:,{'Date','Permno','Openprc'}) taq(:,'FirstPrice'), ...
    crsp(:,{'Bid','Ask','Prc'}),taq(:,{'LastPrice','TAQret'})];
cmp.CRSPret = cmp.Prc./cmp.Openprc-1;

retdiff = abs(cmp.CRSPret - cmp.TAQret);
idx     = retdiff > eps*1e12;
boxplot(retdiff(idx))
%% Check new/old ff49
load('D:\TAQ\HF\intradaymom\results\bck\FF49.mat')

taq  = loadresults('price_fl');
ff49 = getFF49IndustryCodes(taq,1);
ff49 = struct('Permno', xstr2num(getVariableNames(ff49(:,2:end))), ...
    'Dates', ff49{:,1},...
    'Data', ff49{:,2:end});

% Intersect permno
[~,ia,ib] = intersect(industry.Permno, ff49.Permno);
industry.Data = industry.Data(:,ia);
industry.Permno = industry.Permno(ia);
ff49.Data = ff49.Data(:,ib);
ff49.Permno = ff49.Permno(ib);

% intersect date
[~,ia,ib] = intersect(industry.Date, ff49.Dates);
industry.Data = industry.Data(ia,:);
industry.Date = industry.Date(ia);
ff49.Data = ff49.Data(ib,:);
ff49.Dates = ff49.Dates(ib);

[r,c] = find(ff49.Data ~= industry.Data & ff49.Data ~= 0)


