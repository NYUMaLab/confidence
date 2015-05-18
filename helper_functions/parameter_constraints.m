function models = parameter_constraints(models)
nModels = length(models);

for m_id = 1 : nModels
    c = models(m_id);
    
    options = {'multi_lapse','partial_lapse','repeat_lapse','choice_only','symmetric','d_noise','free_cats','non_overlap','ori_dep_noise','diff_mean_same_std','joint_task_fit','joint_d', 'attention1'};
    for o = 1:length(options)
        if ~isfield(c,options{o}) || isempty(c.(options{o}))
            c.(options{o}) = 0;
        end
    end
    
    
    if c.choice_only
        % the below options are only for confidence models. they don't make sense if choice_only has been specified
        c.partial_lapse = 0;
        c.multi_lapse = 0;
        c.symmetric = 0;
    end
    
    if ~strcmp(c.family, 'opt')
        % d noise is only for opt
        c.d_noise = 0;
    end
    
    if c.joint_d
        c.joint_task_fit = 1;
    end
    
    % important that this come before the symmetric piece right below it
    if c.joint_task_fit
        c.diff_mean_same_std = 0; % don't need both of these params. this is ugly. replace with switch that can take 3 values?
    end

    if ~c.diff_mean_same_std && ~strcmp(c.family, 'opt')
        c.symmetric = 0; % opt is the only model that can be symmetric in task B
    elseif c.diff_mean_same_std || c.joint_d
        c.symmetric = 1; % bounds are symmetric for all Task A models.
    end
    
    % give model its name based on the settings. in future, might be better to report the alternative rather than just leave it out when it's zero.
    fields = fieldnames(c);
    str='';
    for f = 1 : length(fields)
        if isa(c.(fields{f}), 'char')
            str = [str c.(fields{f})];
        elseif isa(c.(fields{f}), 'double') && all(size(c.(fields{f})) == [1 1]) && c.(fields{f})==1
            str = [str ' : ' fields{f}];
        end
    end
    c.name = str; % model name
    %%
    % change alpha, beta, logsigma_0 to logsigma_c_low, logsigma_c_hi, beta
    % beta: -25:10; -2:2
    
    c.parameter_names = {
        'logsigma_c_low'
        'logsigma_c_hi'
        'beta'
        'b_n3_d'
        'b_n2_dTerm'
        'b_n1_dTerm'
        'b_0_dTerm'
        'b_1_dTerm'
        'b_2_dTerm'
        'b_3_dTerm'
        'b_n3_x'
        'b_n2_xTerm'
        'b_n1_xTerm'
        'b_0_xTerm'
        'b_1_xTerm'
        'b_2_xTerm'
        'b_3_xTerm'
        'm_n3'
        'm_n2Term'
        'm_n1Term'
        'm_0Term'
        'm_1Term'
        'm_2Term'
        'm_3Term'
        'logsigma_d'
        'lambda'
        'lambda_1'
        'lambda_4'
        'lambda_g'
        'lambda_r'
        'logsig1'
        'logsig2Term'
        'sig_amplitude'
        'b_0_dChoice'
        'b_0_xChoice'
        'm_0Choice'
        'b_0_d_TaskA'
        'b_1_dTerm_TaskA'
        'b_2_dTerm_TaskA'
        'b_3_dTerm_TaskA'
        'b_0_x_TaskA'
        'b_1_xTerm_TaskA'
        'b_2_xTerm_TaskA'
        'b_3_xTerm_TaskA'
        'm_0_TaskA'
        'm_1Term_TaskA'
        'm_2Term_TaskA'
        'm_3Term_TaskA'
        'b_0_dChoice_TaskA'
        'b_0_xChoice_TaskA'
        'm_0Choice_TaskA'
        'logsigma_tc'
        'b_n3_neural1'
        'b_n2_neural1Term'
        'b_n1_neural1Term'
        'b_0_neural1Term'
        'b_1_neural1Term'
        'b_2_neural1Term'
        'b_3_neural1Term'
        'b_0_neural1Choice'
        'b_0_neural1_TaskA'
        'b_1_neural1Term_TaskA'
        'b_2_neural1Term_TaskA'
        'b_3_neural1Term_TaskA'
        'b_0_neural1Choice_TaskA'
        'logsigma_c_mid'
        };

    %               scl sch betabn3dbn2dbn1db0d b1d b2d b3d bn3xbn2xbn1xb0x b1x b2x b3x mn3 mn2 mn1 m0  m1  m2  m3  sigdlm  lm1 lm4 lmg lmr s1  s2  sa  b0dcb0xcm0c     b0d_TA  b1d_TA  b2d_TA  b3d_TA  b0x_TA  b1x_TA  b2x_TA  b3x_TA  m0_TA   m1_TA   m2_TA   m3_TA   b0dc_TA b0xc_TA m0c_TA  sig_tc  bn3n1   bn2n1   bn1n1   b0n1    b1n1    b2n1    b3n1    b0n1c   b0n1_TA     b1n1_TA     b2n1_TA     b3n1_TA     b0n1c_TA    scm
    c.lb       = [  0   -5  -10 -15 0   0   0   0   0   0   0   0   0   0   0   0   0   -30 0   0   0   0   0   0   -10 0   0   0   0   0   0   0   0   -10 0   -30     -.5     0       0       0       -10     0       0       0       -5      0       0       0       -10     -10     -30     0       0       0       0       0       0       0       0       0       -50         0           0           0           -50         -5]';
    c.ub       = [  10  10  10  2   15  4   3   3   3   30  10  10  10  30  30  30  90  30  10  10  10  10  10  10  2   .25 .2  .2  .4  .4  25  25  30  10  40  30      .5      1.5     1.5     5       10      30      30      90      5       5       5       5       10      10      30      10      150     150     150     150     150     200     300     200     50          200         200         200         50          10]';
    c.lb_gen   = [  1   .5  -2  -2  .1  .1  .1  .1  .1  .1  0   2   2   2   2   2   2   -2  .2  .2  .2  .2  .2  .2  -5   0   0   0   0   0   2   8  2   -2  3   0       -.3     .1      .1      .1      -2      2       2       2       -2      .2      .2      .2      -2      -3      -5      0       0       0       0       0       0       0       0       10      -10         0           0           0           -10         1]';
    c.ub_gen   = [  3.5 1   2   1.2 1.2 1.2 1.2 1.2 1.2 1.2 3   5   5   5   5   5   5   1   1   1   1   1   1   1   1   .1  .1  .1  .2  .1  4   10  10  2   8   2       .3      1.2     1.2     2       2       5       5       30      2       1       1       1       2       3       5       1.7     15      15      15      15      15      15      15      20      10          15          15          15          1           3.5]';
    
    c.beq      = [  1   1   1   -2  .7  .7  .7  .7  .7  .7  2   2   2   2   2   2   2  -2   .7  .7  .7  .7  .7  .7  0   0   0   0   0   0   3   9   0   0   5   .5      0       .3      .3      .3      0       5       5       5       0       1       1       1       0       0       0       3       10      10      20      20      20      50      50      15      0           10          10          10          0           1]';

    %log_params = strncmpi(c.parameter_names,'log',3);

    %fields = {'lb','ub','lb_gen','ub_gen'}; % convert log param bounds
%     c.lb(log_params) = -7;
    %c.lb_gen(log_params) = -1.5;
%     c.ub(log_params) = 7;
    %c.ub_gen(log_params) = 4;
    
%     for field = 1:length(fields)
%         c.(fields{field})(log_params) = log(c.(fields{field})(log_params));
%         c.(fields{field})(c.(fields{field})==-Inf) = -100;
%         c.(fields{field})(c.(fields{field})==Inf) = 100;
%     end
    
    c = taskizer(c);
    c = familyizer(c);
    c = symmetricizer(c);
    c = choiceizer(c);
    c = d_noiseizer(c);
    c = attention1izer(c);
    c = neural1izer(c);
    c = partial_lapseizer(c);
    c = multi_lapseizer(c);
    c = repeat_lapseizer(c);
    c = free_catsizer(c);
    c = sig_ampizer(c);
    
    % calculate uniform param prior
    c.param_prior = prod(1 ./ (c.ub - c.lb)); % this is not great. lapse param should be a beta dist, not uniform. but only applies when doing hessian, which we've moved on from.
    
    % indicate which are lapse and Term params, so that you don't have to do this every sample in parameter_variable_namer
    c.term_params = find(~cellfun(@isempty, strfind(c.parameter_names,'Term')));
    c.lapse_params = find(~cellfun(@isempty, strfind(c.parameter_names,'lambda')));
    
    % put back into model
    fields = fieldnames(c);
    for f = 1:length(fields)
        models(m_id).(fields{f}) = c.(fields{f});
    end
end
end

function c = taskizer(c)
if ~c.joint_task_fit && c.diff_mean_same_std==1
    % TASK A
    otherbounds = find(~cellfun(@isempty, regexp(c.parameter_names, '^[bm]_(.(?!TaskA))*$'))); % this regular expression says that all characters after ^[bm]_ must be a character that is not followed by 'TaskA'
    c = p_stripper(c,otherbounds);
    
    % chop TaskA off the end
    TaskA_bounds = find(~cellfun(@isempty, regexp(c.parameter_names, 'TaskA$')));
    for tb = TaskA_bounds'
        c.parameter_names{tb} = c.parameter_names{tb}(1:end-6);
    end
elseif (~c.joint_task_fit && c.diff_mean_same_std==0) || c.joint_d
    % TASK B or shared
    otherbounds = find(~cellfun(@isempty, regexp(c.parameter_names, '[bm]_.*TaskA')));
    c = p_stripper(c,otherbounds);
end
end

function c = familyizer(c)
% strip out bound parameters from families other than the specified one
optbounds = find(~cellfun(@isempty, regexp(c.parameter_names, 'b_.*d')));
xbounds   = find(~cellfun(@isempty, regexp(c.parameter_names,'b_.*x')));
slopebounds=find(~cellfun(@isempty, regexp(c.parameter_names, 'm_[n0-9]')));
neural1bounds = find(~cellfun(@isempty, regexp(c.parameter_names, 'b_.*neural1')));

if strcmp(c.family, 'quad') || strcmp(c.family, 'lin')
    otherbounds = {optbounds, neural1bounds};
elseif strcmp(c.family, 'fixed') || strcmp(c.family, 'MAP')
    otherbounds = {optbounds, slopebounds, neural1bounds};
elseif strcmp(c.family, 'opt')
    otherbounds = {xbounds, slopebounds, neural1bounds};
elseif strcmp(c.family, 'neural1')
    otherbounds = {xbounds, slopebounds, optbounds};
end

c = p_stripper(c,unique([otherbounds{:}]));
end

function c = symmetricizer(c)
if c.symmetric && ~c.diff_mean_same_std %(~c.joint_task_fit && c.symmetric && ~c.diff_mean_same_std)% || (c.joint_task_fit && c.symmetric)
    % if doing symmetric (opt) model and task B, strip out negative D parameters. Task A doesn't have any neg D params because thye are all symmetric.
    % also strip if doing symmetric and joint task fit. in the latter case, the diffmeansamestd parameter is set to 0. 
    b0term = find(~cellfun(@isempty, regexp(c.parameter_names,'b_0_dTerm')));
    c.parameter_names{b0term} = 'b_0_d';
    fields = {'lb','ub','lb_gen','ub_gen'};
    for f = 1:length(fields)
        c.(fields{f})(b0term)=c.(fields{f})(b0term-3);
    end
    
    negDPs = find(~cellfun(@isempty,regexp(c.parameter_names,'b_n')));
    
    c = p_stripper(c,negDPs);
end
end

function c = choiceizer(c)
choice_bounds = find(~cellfun(@isempty,regexp(c.parameter_names, 'Choice')));
if c.choice_only
    % if only doing choice, strip out extra bound parameters
    all_bounds = find(~cellfun(@isempty, regexp(c.parameter_names, '[bm]_')));
    extra_bounds = setdiff(all_bounds, choice_bounds);
    c = p_stripper(c,extra_bounds);
    % chop Choice off the end
    choice_bounds = find(~cellfun(@isempty,regexp(c.parameter_names, 'Choice'))); % find params again
    for cb = choice_bounds'
        c.parameter_names{cb} = c.parameter_names{cb}(1:end-6);
    end
    
elseif ~c.choice_only
    c = p_stripper(c,choice_bounds);
end
end

function c = d_noiseizer(c)
% if not doing d noise, strip out d noise parameter
if ~c.d_noise
    d_noiseP = find(~cellfun(@isempty, regexp(c.parameter_names, 'sigma_d')));
    c = p_stripper(c,d_noiseP);
end
end

function c = attention1izer(c)
% if not attention1, strip out mid_sig. if three_free_sigs, strip out beta
if ~c.attention1
    midsigP = find(~cellfun(@isempty, regexp(c.parameter_names, 'logsigma_c_mid')));
    c = p_stripper(c, midsigP);
else
    betaP = find(~cellfun(@isempty, regexp(c.parameter_names, 'beta')));
    c = p_stripper(c, betaP);
end
end

function c = neural1izer(c)
% if not neural1, strip out sigma_tc parameter
if ~strcmp(c.family, 'neural1')
    sig_tcP = find(~cellfun(@isempty, regexp(c.parameter_names, 'sigma_tc')));
    c = p_stripper(c, sig_tcP);
end
end

function c = partial_lapseizer(c)
% if not doing partial lapse, strip out partial lapse parameter
if ~c.partial_lapse
    partial_lapseP = find(~cellfun(@isempty, regexp(c.parameter_names, 'lambda_g')));
    c = p_stripper(c,partial_lapseP);
end
end

function c = multi_lapseizer(c)
% if doing multilapse, strip out the single full lapse and leave the multilapse
% if not doing multilapse, strip out the multilapse and leave the full lapse
if c.multi_lapse
    unwantedLapseP = find(~cellfun(@isempty, regexp(c.parameter_names, 'lambda$')));
elseif ~c.multi_lapse % strike the two multilapses
    unwantedLapseP = find(~cellfun(@isempty, regexp(c.parameter_names, 'lambda_[14]')));
end
c = p_stripper(c,unwantedLapseP);
end

function c = repeat_lapseizer(c)
% if not doing repeat lapse, strip out repeat lapse parameter
if ~c.repeat_lapse
    repeat_lapseP = find(~cellfun(@isempty, regexp(c.parameter_names, 'lambda_r')));
    c = p_stripper(c,repeat_lapseP);
end
end

function c = free_catsizer(c)
% if not doing free cats, strip out sig1 and sig2
free_catsP = find(~cellfun(@isempty, regexp(c.parameter_names, 'sig[12]')));
if ~c.free_cats
    c = p_stripper(c,free_catsP);
end

end

function c = sig_ampizer(c)
% if not doing ori dep noise, strip out sig_amplitude
if ~c.ori_dep_noise
    sig_ampP = find(~cellfun(@isempty, regexp(c.parameter_names, 'sig_amplitude')));
    c = p_stripper(c, sig_ampP);
end
end



function c = p_stripper(c, p_to_remove)
% this is called by the above functions to strip out specified parameter from the named fields.
p = setdiff(1:length(c.lb), p_to_remove); % p is the parameters to keep
fields = {'parameter_names','lb','lb_gen','ub','ub_gen','beq'};
for f = 1:length(fields);
    c.(fields{f}) = c.(fields{f})(p);
end
end