function sampleData(grid, writeto, fmtname)
% sampleData(grid, writeto, fmtname)

% Sampling params
if nargin < 1 || isempty(grid),    grid    = (9.5/24:5/(60*24):16/24)'; end
if nargin < 2 || isempty(writeto), writeto = '.\data\TAQ\sampled\5min'; end
if nargin < 3 || isempty(fmtname), fmtname = 'S5m_%04d.mat'; end

% Write path handling
[isok, msg, msgid] = mkdir(writeto);
direxists          = strcmpi('MATLAB:MKDIR:DirectoryExists',msgid);
if ~isok
    error(msgid,msg)
elseif direxists 
    if numel(dir(writeto)) > 2
        msg = 'the path ''%s'' already exists and is not empty.\n\t\t Data might get overwritten.';
        warning('sampleData:nonEmptyWriteDir',msg,writeto)
    end
else
    fprintf('%s: created new dir ''%s''.\n', mfilename, writeto)
end
%% Selection/filtering
fprintf('%s: selection and filtering.\n', mfilename)
mst = selectAndFilterTrades();

%% Sample at x min
fprintf('%s: sampling.\n', mfilename)
mst = mst(:, {'File','Id','Permno','Date','MedPrice','Isbadday','Isfewobs'});
opt = struct('grid',grid, 'writeto', writeto, 'fmtname', fmtname);
clearvars -except mst opt
Analyze('sample',[], mst,[],[],opt);

% Sort mst by from
fprintf('%s: sorting all mst by ''From''.\n', mfilename)
sortmst(opt.writeto)

% Make master file
fprintf('%s: making master records file.\n', mfilename)
makeMasterFile(opt.writeto)
end