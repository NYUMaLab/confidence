function [gen, aborted]=optimize_fcn(varargin)

opt_models = struct;

opt_models(1).family = 'MAP';
opt_models(1).multi_lapse = 0;
opt_models(1).partial_lapse = 0;
opt_models(1).repeat_lapse = 0;
opt_models(1).choice_only = 1;
opt_models(1).d_noise = 0;
opt_models(1).ori_dep_noise = 0;
opt_models(1).diff_mean_same_std = 0;
opt_models(1).joint_task_fit = 0;
opt_models(1).nFreesigs = 0;
opt_models(1).symmetric = 0;

opt_models = parameter_constraints(opt_models);

% MAP choice_only, A/B work
% MAP conf A works
% MAP conf B DOESN'T WORK

% MAP choice_only ODN A
% MAP choice_only ODN B
% MAP conf ODN A
% MAP conf ODN B

%%
hpc = false;
assignopts(who,varargin);

active_opt_models = 1:length(opt_models);

nRegOptimizations = 40;
nDNoiseOptimizations = 8;
nMAPOriDepNoiseOptimizations = 4;

nDNoiseSets = 101;
maxWorkers = Inf; % set this to 0 to turn parfor loops into for loops

progress_report_interval = Inf;
time_lim = Inf; % time limit (secs) for slice_sample
end_early = false;

x0_reasonable = true; %limits starting points for optimization to those reasonable ranges defined in lb_gen and ub_gen

optimization_method = 'fmincon'; % 'fmincon', 'mcmc_slice'
nKeptSamples = 1e4; % for mcmc_slice
nChains = 4;
aborted = false;

data_type = 'real'; % 'real' or 'fake'
% 'fake' generates trials and responses, to do parameter/model recovery
% 'real' takes real trials and real responses, to extract parameters

%% fake data generation parameters
fake_data_params =  'random'; % 'extracted' or 'random'
% category_type = 'same_mean_diff_std'; % 'same_mean_diff_std' (Qamar) or 'diff_mean_same_std' or 'sym_uniform' or 'half_gaussian' (Kepecs)
attention_manipulation = false;

category_params.sigma_s = 5; % for 'diff_mean_same_std' and 'half_gaussian'
category_params.a = 0; % overlap for sym_uniform
category_params.mu_1 = -4; % mean for 'diff_mean_same_std'
category_params.mu_2 = 4;
category_params.uniform_range = 1;
category_params.sigma_1 = 3;
category_params.sigma_2 = 12;

gen_models = opt_models;

active_gen_models = 1 : length(gen_models);
gen_nSamples = 3240;
fixed_params_gen = []; % can fix parameters here. goes with fixed values in beq, in parameter_constraints.m....
fixed_params_opt = [];
fixed_params_gen_values = [];  % ... unless specific parameter values are specified here.
fixed_params_opt_values = [];

slimdown = true; % throws away information like hessian for every optimization, etc. that takes up a lot of space.
crossvalidate = false;
k = 1; % for k-fold cross-validation

if ~crossvalidate
    k = 1;
end

nll_tolerance = 1e-3; % this is for determining what "good" parameters are.


job_id = datetimefcn;
assignopts(who,varargin);
filename = sprintf('%s.mat',job_id);

if hpc
    datadir_joint='/home/wta215/data/v3';
    savedir = '/home/wta215/Analysis/output/';
else
    datadir_joint = '/Users/will/Google Drive/Will - Confidence/Data/v3b_ellipse';
    savedir = '/Users/will/Google Drive/Ma lab/output/';
end

log_fid = fopen([savedir job_id '.txt'],'a'); % open up a log
assignopts(who,varargin);

datadirA = [datadir_joint '/taskA'];
datadirB = [datadir_joint '/taskB'];
assignopts(who,varargin);

if hpc
    my_print = @(s) fprintf(log_fid,'%s\n',s); % print to log instead of to console.
else
    my_print = @fprintf;
end

cd(savedir)


if strcmp(optimization_method,'fmincon')
    fmincon_opts = optimoptions(@fmincon,'Algorithm','interior-point', 'display', 'off', 'UseParallel', 'never');
end

if strcmp(data_type, 'real')
    gen = compile_data('datadir', datadirA, 'crossvalidate', crossvalidate, 'k', k);
    if ~isempty(datadirB)
        genB = compile_data('datadir', datadirB, 'crossvalidate', crossvalidate, 'k', k);
    end
    nDatasets = length(gen.data);
    datasets = 1 : nDatasets;
    gen_models = struct; % to make it length 1, to execute big optimization loop just once.
    active_gen_models = 1;
elseif strcmp(data_type,'fake')
    nDatasets = 6;
    assignopts(who,varargin);
    datasets = 1:nDatasets;
    extracted_param_file = '';
elseif strcmp(data_type,'fake_pre_generated')
    gen = struct;
    assignopts(who,varargin); % gen is assigned in the argument
    nDatasets = length(gen(1).data);
    datasets = 1:nDatasets;
end

assignopts(who,varargin); % reassign datasets (for multiple jobs)

%% GENERATE FAKE DATA %%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(data_type, 'fake')
    
    for gen_model_id = active_gen_models;
        
        g = gen_models(gen_model_id);
        o = g; % this is for log_posterior function
        
        if g.diff_mean_same_std
            category_type = 'diff_mean_same_std';
        elseif ~g.diff_mean_same_std
            category_type = 'same_mean_diff_std';
        end
        
        if attention_manipulation && g.nFreesigs ~= 3
            error('attention_manipulation is indicated, but you don''t have nFreesigs equal to 3.')
        end
            
        % generate parameters, or use previously extracted parameters
        switch fake_data_params
            case 'random'
                nParams = length(g.lb);
                if ~isempty(fixed_params_gen_values)
                    if numel(fixed_params_gen_values) ~= numel(fixed_params_gen);
                        error('fixed_params_gen_values is not the same length as fixed_params_gen')
                    else
                        g.beq(fixed_params_gen) = fixed_params_gen_values;
                    end
                end
                gen(gen_model_id).p = random_param_generator(nDatasets, g, 'fixed_params', fixed_params_gen, 'generating_flag', 1);
                gen(gen_model_id).p

            case 'extracted' % previously extracted using this script (deprecated, add model(i)... or something)
                
                if hpc
                    exm=load(extracted_param_file);
                else
                    exm=load('/Users/will/Google Drive/Will - Confidence/Analysis/4confmodels.mat');
                end
                
                for dataset = 1 : nDatasets;
                    gen(gen_model_id).p(:,dataset) = exm.m(gen_model_id).extracted(dataset).best_params;
                end
        end
        for dataset = datasets;
            % generate data from parameters
%             save before
            while true
                d = trial_generator(gen(gen_model_id).p(:,dataset), g, 'n_samples', gen_nSamples, 'category_params', category_params, 'attention_manipulation', attention_manipulation, 'category_type', category_type);
                gen(gen_model_id).data(dataset).raw = d;
                gen(gen_model_id).data(dataset).true_nll = nloglik_fcn(gen(gen_model_id).p(:,dataset), d, g, nDNoiseSets, category_params);
                gen(gen_model_id).data(dataset).true_logposterior = -gen(gen_model_id).data(dataset).true_nll + log_prior(gen(gen_model_id).p(:,dataset)');
                
                % if the dataset doesn't just make the same choice for every trial, accept dataset by breaking while loop, and generate next one
                if g.choice_only
                    if length(unique(d.Chat))==2
                        break
                    else % if the dataset is the same choice for every trial, generate new parameters and try again
                        gen(gen_model_id).p(:,dataset) = random_param_generator(1, g, 'fixed_params', fixed_params_gen, 'generating_flag', 1);
                    end
                else
                    if length(unique(d.resp))==8
                        break
                    else
                        gen(gen_model_id).p(:,dataset) = random_param_generator(1, g, 'fixed_params', fixed_params_gen, 'generating_flag', 1);
                    end
                end
            end
%             figure(dataset)
%             subplot(1,2,1)
%             plot(d.s,d.x,'.')
%             subplot(1,2,2)
%             if g.choice_only
%                 plot(d.x,d.Chat,'.')
%             else
%                 plot(d.x,d.resp,'.')
%             end
        end
%         pause(.1)
%         save after
%         return
    end
    
    genB = gen; % this is how task B data gets loaded. dirty
elseif strcmp(data_type, 'fake_pre_generated')
    for gen_model_id = active_gen_models;
        g = gen_models(gen_model_id);
        o = g;
        for dataset = datasets
            gen(gen_model_id).data(dataset).true_logposterior = -gen(gen_model_id).data(dataset).true_nll + log_prior(gen(gen_model_id).p(:,dataset)');
        end
    end
end


%% OPTIMIZATION %%%%%%%%%%%%%%%%%%%%%%%%%

start_t=tic;

for gen_model_id = active_gen_models
    if ~strcmp(data_type,'real')
        my_print(sprintf('\n\n########### GENERATING MODEL ''%s'' ############################################\n\n',gen_models(gen_model_id).name));
    end
    
    for opt_model_id = active_opt_models
        model_start_t = tic;
        o = opt_models(opt_model_id);
        nParams = length(o.lb);
        my_print(sprintf('\n\n########### FITTING MODEL ''%s'' #################################\n\n', o.name));
        
        if strcmp(o.family, 'opt') && o.d_noise
            nOptimizations = nDNoiseOptimizations;
        elseif strcmp(o.family, 'MAP') && o.ori_dep_noise
            nOptimizations = nMAPOriDepNoiseOptimizations;
        else
            nOptimizations = nRegOptimizations;
        end
                
        if strcmp(optimization_method,'mcmc_slice')
            nSamples = nOptimizations; % real samples to run
            burnin = 0;%round(nSamples/2);
            postburn = round(nKeptSamples/3);
            thin = ceil(nSamples/nKeptSamples);
            nOptimizations = nChains;
        end
        
        if o.joint_task_fit
            % prepare the two submodels. not doing all fields, just the ones needed by nloglik_fcn()
            sm=prepare_submodels(o);
        end
        
        unfixed_params = setdiff(1:nParams, fixed_params_opt);
        o.Aeq = eye(nParams);
        o.Aeq(unfixed_params, unfixed_params) = 0;
        o.beq(unfixed_params) = 0;
        if ~isempty(fixed_params_opt_values)
            if numel(fixed_params_opt_values) ~= numel(fixed_params_opt) && min(size(fixed_params_opt_values))==1 % if its not a matrix, and isn't the same size
                error('fixed_params_opt_values is not the same length as fixed_params_opt')
            elseif min(size(fixed_params_opt_values))==1
                o.beq(fixed_params_opt) = fixed_params_opt_values;
            end
        end
        
        [extracted_p, extracted_grad] = deal(zeros(nParams, nOptimizations)); % these will be filled with each optimization and overwritten for each dataset
        extracted_nll = zeros(1, nOptimizations);
        extracted_hessian=zeros(nParams, nParams, nOptimizations);
        tmp = o;
        tmp.extracted(max(datasets)) = struct;
        gen(gen_model_id).opt(opt_model_id) = tmp;
        
        % OPTIMIZE
        for dataset = datasets;
            my_print(sprintf('\n\n########### DATASET %i ######################\n\n', dataset));
            
            if min(size(fixed_params_opt_values))>1 % if it's a matrix, assign the different datasets the different values. this is hacky
                o.beq(fixed_params_opt) = fixed_params_opt_values(:,dataset);
            end
            
            ex = struct;
            for trainset = 1:k % this is just 1 if not cross-validating
                %% OPTIMIZE PARAMETERS
                % random starting points x0 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                x0 = random_param_generator(nOptimizations, o, 'generating_flag', x0_reasonable, 'fixed_params', fixed_params_opt); % try turning on generating_flag.

                if crossvalidate
                    d      = gen(gen_model_id).data(dataset).train(trainset);
                    d_test = gen(gen_model_id).data(dataset).test(trainset);
                else
                    if o.joint_task_fit
                        data_taskA = gen (gen_model_id).data(dataset).raw;
                        data_taskB = genB(gen_model_id).data(dataset).raw;
                        
                        if strcmp(data_type, 'real'); dataset_name = gen(gen_model_id).data(dataset).name; end
                    elseif ~o.joint_task_fit
                        if ~o.diff_mean_same_std % task B
                            data =       genB(gen_model_id).data(dataset).raw;
                            
                            if strcmp(data_type, 'real'); dataset_name = genB(gen_model_id).data(dataset).name; end
                        elseif o.diff_mean_same_std % task A
                            data =       gen (gen_model_id).data(dataset).raw;
                            
                            if strcmp(data_type, 'real'); dataset_name = gen(gen_model_id).data(dataset).name; end
                        end
                    end
                end
                
                % use anon objective function to fix data parameter.
                if ~o.joint_task_fit
                    loglik_wrapper = @(p) -nloglik_fcn(p, data, o, nDNoiseSets, category_params);%, optimization_method, randn_samples{dataset});
                elseif o.joint_task_fit
                    loglik_wrapper = @(p) two_task_ll_wrapper(p, data_taskA, data_taskB, sm, nDNoiseSets, category_params);
                end
                
                logprior_wrapper = @log_prior;
                
                nloglik_wrapper = @(p) -loglik_wrapper(p);% -logprior_wrapper(p); % uncomment this for log posterior
                
                % possible outputs
                % fmincon only
                ex_exitflag = nan(1, nOptimizations);
                ex_output = cell(1,nOptimizations);
                ex_lambda = cell(1,nOptimizations);
                ex_grad = nan(nParams, nOptimizations);
                ex_hessian = nan(nParams, nParams, nOptimizations);
                % mcmc only
                ex_ncall=nan(1,nOptimizations);
                
                if strcmp(optimization_method,'mcmc_slice')
                    ex_p = nan(nKeptSamples,nParams,nOptimizations);
                    ex_nll = nan(nKeptSamples,nOptimizations);
                    ex_logprior = nan(nKeptSamples,nOptimizations);
                else
                    ex_p = nan(nParams,nOptimizations);
                    ex_nll = nan(1,nOptimizations);
                    ex_logprior = nan(1,nOptimizations);
                end
                
                
                switch optimization_method
                    case 'mcmc_slice'
                        aborted_flags = zeros(1,nOptimizations);
                        
                        if exist([savedir 'aborted/aborted_' filename],'file')
                            % RESUME PREVIOUSLY ABORTED SAMPLING
                            load([savedir 'aborted/aborted_' filename])
                            log_fid = fopen([savedir job_id '.txt'],'a'); % open up a log
                            remaining_samples = isnan(ex_nll);
                            nRemSamples = sum(remaining_samples);
                            %remaining_p = isnan(ex_p);
                            [s_tmp,ll_tmp,lp_tmp] = deal(cell(1,nOptimizations));
                            fclose(log_fid);

                            % HERE FOLLOWS SOME TERRIBLE, REDUNDANT CODE.
                            if maxWorkers == 0
                                for optimization = 1:nOptimizations
                                    log_fid = fopen([job_id '.txt'],'a'); % reopen log for parfor
                                    [samples, loglikes, logpriors, aborted_flags(optimization)] = slice_sample(nRemSamples(optimization), loglik_wrapper, ex_p(end-nRemSamples(optimization),:,optimization), (o.ub-o.lb)', 'logpriordist',logprior_wrapper,...
                                        'burn',burnin,'thin',thin,'progress_report_interval',progress_report_interval,'chain_id',optimization, 'time_lim',.97*time_lim,'log_fid',log_fid,'static_dims',fixed_params_opt);
                                    s_tmp{optimization} = samples';
                                    ll_tmp{optimization} = -loglikes';
                                    lp_tmp{optimization} = logpriors';
                                    fclose(log_fid);
                                end
                            else
                                parfor (optimization = 1:nOptimizations, maxWorkers)
                                    log_fid = fopen([job_id '.txt'],'a'); % reopen log for parfor
                                    [samples, loglikes, logpriors, aborted_flags(optimization)] = slice_sample(nRemSamples(optimization), loglik_wrapper, ex_p(end-nRemSamples(optimization),:,optimization), (o.ub-o.lb)', 'logpriordist',logprior_wrapper,...
                                        'burn',burnin,'thin',thin,'progress_report_interval',progress_report_interval,'chain_id',optimization, 'time_lim',.97*time_lim,'log_fid',log_fid,'static_dims',fixed_params_opt);
                                    s_tmp{optimization} = samples';
                                    ll_tmp{optimization} = -loglikes';
                                    lp_tmp{optimization} = logpriors';
                                    fclose(log_fid);
                                end
                            end
                            fopen([job_id '.txt'],'a');
                            for optimization = 1:nOptimizations
                                ex_p(remaining_samples(:,optimization),:,optimization) = s_tmp{optimization};
                                ex_nll(remaining_samples(:,optimization),optimization) = ll_tmp{optimization};
                                ex_logprior(remaining_samples(:,optimization),optimization) = lp_tmp{optimization};
                            end
                            clear s_tmp ll_tmp lp_tmp samples loglikes logpriors
                        else
                            % NEW SAMPLING
                            if maxWorkers==0
                                for optimization = 1 : nOptimizations
                                    [samples, loglikes, logpriors, aborted_flags(optimization)] = slice_sample(nKeptSamples, loglik_wrapper, x0(:,optimization), (o.ub-o.lb)', 'logpriordist',logprior_wrapper,...
                                        'burn',burnin,'thin',thin,'progress_report_interval',progress_report_interval,'chain_id',optimization, 'time_lim',.97*time_lim,'log_fid',log_fid,'static_dims',fixed_params_opt);
                                    ex_p(:,:,optimization) = samples';
                                    ex_nll(:,optimization) = -loglikes';
                                    ex_logprior(:,optimization) = logpriors';
                                end
                            else
                                fclose(log_fid);
                                parfor (optimization = 1 : nOptimizations, maxWorkers)
                                    log_fid = fopen(sprintf('%s.txt',job_id),'a'); % reopen log for parfor
                                    [samples, loglikes, logpriors, aborted_flags(optimization)] = slice_sample(nKeptSamples, loglik_wrapper, x0(:,optimization), (o.ub-o.lb)', 'logpriordist',logprior_wrapper,...
                                        'burn',burnin,'thin',thin,'progress_report_interval',progress_report_interval,'chain_id',optimization, 'time_lim',.97*time_lim,'log_fid',log_fid,'static_dims',fixed_params_opt);
                                    ex_p(:,:,optimization) = samples';
                                    ex_nll(:,optimization) = -loglikes';
                                    ex_logprior(:,optimization) = logpriors';
                                    fclose(log_fid);
                                end
                            end
                            clear samples loglikes logpriors
                            log_fid=fopen([job_id '.txt'],'a');
                        end
                        
                        if any(aborted_flags)
                            my_print(sprintf('aborted during slice_sample'));
                            save([savedir 'aborted/aborted_' filename])
                            aborted=true;
                            fclose(log_fid);
                            return
                        else
                            aborted=false;
%                             if exist([savedir 'aborted/aborted_' filename])
%                                 delete([savedir 'aborted/aborted_' filename])
%                             end
                        end
                        
                        if end_early
                            %%
                            min_chain_completion = min(sum(~isnan(ex_nll)));
                            ex_nll = ex_nll(1:min_chain_completion,:);
                            ex_logprior = ex_logprior(1:min_chain_completion,:);
                            ex_p = ex_p(1:min_chain_completion,:,:);
                            postburn = 0;
                        end
                        
                        % post-burn
                        ex_p = ex_p(postburn+1:end,:,:);
                        ex_nll = ex_nll(postburn+1:end,:);
                        ex_logprior = ex_logprior(postburn+1:end,:);
                        
                    case 'fmincon'
                        if maxWorkers == 0
                            for optimization = 1 : nOptimizations
                                if rand < 1 / progress_report_interval % every so often, print est. time remaining.
                                    my_print(sprintf('Dataset: %.0f\nElapsed: %.1f mins\n\n', dataset, toc(start_t)/60));
                                end
                                [ex_p(:, optimization), ex_nll(optimization), ex_exitflag(optimization), ex_output{optimization}, ex_lambda{optimization}, ex_grad(:,optimization), ex_hessian(:,:,optimization)] = fmincon(nloglik_wrapper, x0(:,optimization), [], [], o.Aeq, o.beq, o.lb, o.ub, [], fmincon_opts);
                            end
                        else
                            fclose(log_fid);
                            parfor (optimization = 1 : nOptimizations, maxWorkers)
                                log_fid = fopen(sprintf('%s.txt',job_id),'a') % reopen log for parfor
                                if rand < 1 / progress_report_interval % every so often, print est. time remaining.
                                    my_print(sprintf('Dataset: %.0f\nElapsed: %.1f mins\n\n', dataset, toc(start_t)/60));
                                end
                                [ex_p(:, optimization), ex_nll(optimization), ex_exitflag(optimization), ex_output{optimization}, ex_lambda{optimization}, ex_grad(:,optimization), ex_hessian(:,:,optimization)] = fmincon(nloglik_wrapper, x0(:,optimization), [], [], o.Aeq, o.beq, o.lb, o.ub, [], fmincon_opts);
                                fclose(log_fid);
                            end
                            log_fid=fopen([job_id '.txt'],'a');
                        end
                end
                
                %                 priorlikt = tic;
                %                 if strcmp(optimization_method,'mcmc_slice')
                %                     parfor (optimization = 1:nOptimizations, maxWorkers)
                %                         for s = 1:nKeptSamples
                %                             ex_nll(s,optimization) = f(ex_p(s,:,optimization));
                %                             ex_logprior(s,optimization) = logprior_fcn(ex_p(s,:,optimization),o);
                %                             ex_logposterior(s,optimization) = ex_logprior(s,optimization)-ex_nll(s,optimization);
                %                         end
                %                     end
                %                 end
                %
                %                 my_print('\nIt took %g minutes to re-compute sample logpriors and loglikelihoods.\n\n',round(toc(priorlikt)*100/60)/100)
                %%
                ex.p = ex_p;
                ex.nll = ex_nll;
                ex.exitflag = ex_exitflag;
                ex.output = ex_output;
                ex.lambda = ex_lambda;
                ex.grad = ex_grad;
                ex.hessian = ex_hessian;
                ex.ncall = ex_ncall;
                ex.logprior = ex_logprior;
                
                ex.logposterior = ex_logprior - ex_nll;
                %%
                if crossvalidate
                    ex.train(trainset).p = ex.p;
                    ex.train(trainset).nll = ex.nll;
                    ex.train(trainset).exitflag = ex.exitflag;
                    ex.train(trainset).output = ex.output;
                    ex.train(trainset).lambda = ex.lambda;
                    ex.train(trainset).grad = ex.grad;
                    ex.train(trainset).hessian = ex.hessian;
                    
                    [ex.train(trainset).min_nll, ex.train(trainset).min_idx] = min(ex.train(trainset).nll);
                    ex.train(trainset).best_params = ex.train(trainset).p(:, ex.train(trainset).min_idx);
                    
                    ex.train(trainset).test_nll = nloglik_fcn(ex.train(trainset).best_params, d_test, fitting_model, nDNoiseSets, category_params);
                end
                
            end
            
            if crossvalidate
                ex.sum_test_nll = sum([ex.train.test_nll]);
                ex.mean_test_nll= mean([ex.train.test_nll]);
            end
            
            %% COMPILE BEST EXTRACTED PARAMETERS AND SCORES AND STUFF
            if crossvalidate
                fields = fieldnames(ex);
                for field = 1 : length(fields)
                    gen(gen_model_id).opt(opt_model_id).extracted(dataset).(fields{field}) = ex.(fields{field});
                end
            else
                if strcmp(optimization_method, 'mcmc_slice')
                    %                     all_nll = vertcat(ex.nll{:});
                    all_nll = reshape(ex.nll, numel(ex.nll),1);
                    %                     all_p = vertcat(ex.p{:});
                    all_p = reshape(permute(ex.p,[1 3 2]),[],size(ex.p,2),1);
                    [ex.min_nll, ex.min_idx] = min(all_nll);
                    ex.best_params = all_p(ex.min_idx,:)';
                    ex.mean_params = mean(all_p);
                    dbar = 2*mean(all_nll);
                    %nloglik_wrapper = @(p) nloglik_fcn(p, d, o, nDNoiseSets, category_params);%, optimization_method, randn_samples{dataset});
                    
                    dtbar= -2*loglik_wrapper(ex.mean_params);
                    ex.dic=2*dbar-dtbar; %DIC = 2(LL(theta_bar)-2LL_bar)
                    
                    ex.best_hessian = [];
                    ex.hessian = [];
                    ex.laplace = [];
                    ex.n_good_params = [];
                else
                    [ex.min_nll, ex.min_idx]    = min(ex.nll);
                    ex.dic = [];
                    ex.best_params          = ex.p(:, ex.min_idx);
                    ex.n_good_params                          = sum(ex.nll < ex.min_nll + nll_tolerance & ex.nll > 10);
                    paramprior      = prod(1 ./ (o.ub - o.lb));
                    ex.best_hessian = ex.hessian(:,:,ex.min_idx);
                    h               = ex.best_hessian;
                    ex.laplace = -ex.min_nll + log(paramprior) +  (nParams/2)*log(2*pi) - .5 * log(det(h));
                end
                [ex.aic, ex.bic, ex.aicc] = aicbic(-ex.min_nll, nParams, gen_nSamples);
                
                if strcmp(data_type, 'real')
                    gen(gen_model_id).opt(opt_model_id).extracted(dataset).name = dataset_name;
                end
                if slimdown
                    fields = {'p','nll','logprior','hessian','min_nll','min_idx','best_params','n_good_params','aic','bic','aicc','dic','best_hessian','laplace'};
                else
                    fields = fieldnames(ex)
                end
                
                for field = 1 : length(fields)
                    gen(gen_model_id).opt(opt_model_id).extracted(dataset).(fields{field}) = ex.(fields{field});
                end
            end
            clear ex;
            save([savedir filename '~'])
        end
        
        my_print(sprintf('Total model %s time: %.1f mins\n\n', o.name, toc(model_start_t)/60));
        
    end
end

my_print(sprintf('Total optimization time: %.2f mins.\n',toc(start_t)/60));
clear ex_p ex_nll ex_logposterior ex_logprior all_nll all_p d varargin;
if hpc
    for g = active_gen_models
        for d = datasets
            gen(g).data(d).raw = [];
        end
    end
    data = [];
end

%%
if ~hpc
    %diagnosis_plots
% gen.opt=model; % this is for after CCO
if ~strcmp(optimization_method,'mcmc_slice') && strcmp(data_type,'fake') && length(active_opt_models)==1 && length(active_gen_models) == 1 && strcmp(opt_models(active_opt_models).name, gen_models(active_gen_models).name)
    % COMPARE TRUE AND FITTED PARAMETERS IN SUBPLOTS
    figure;
    % for each parameter, plot all datasets
    for parameter = 1 : nParams
        subplot(5,5,parameter);
        extracted_params = [gen(active_gen_models).opt(active_opt_models).extracted.best_params];
        plot(gen(active_gen_models).p(parameter,:), extracted_params(parameter,:), '.','markersize',10);
        hold on
        xlim([g.lb_gen(parameter) g.ub_gen(parameter)]);
        ylim([g.lb(parameter)     g.ub(parameter)]);
        
        %axis square;
        plot([g.lb(parameter) g.ub(parameter)], [g.lb(parameter) g.ub(parameter)], '--');
        
        title(g.parameter_names{parameter});
    end
    %         suplabel('true parameter', 'x');
    %         suplabel('extracted parameter', 'y');
elseif strcmp(optimization_method,'mcmc_slice')
    % DIAGNOSE MCMC
    % open windows for every model/dataset combo.
    for gen_model_id = 1%:length(gen)
        g = gen_models(gen_model_id);
        if strcmp(data_type,'real')
            g.name = [];
        end
        for opt_model_id = 1:length(gen(gen_model_id).opt) % active_opt_models
            o = gen(gen_model_id).opt(opt_model_id);
            for dataset_id = 1:length(o.extracted) % dataset
                ex = o.extracted(dataset_id);
                
%                 warning('move this stuff up or out of here. it happens in CCO')
%                 % move this up
%                 ex.logposterior = ex.logprior - ex.nll;
%                 for c = 1:size(ex.logposterior,2)
%                     lp_tmp{c}=ex.logposterior(:,c);
%                     samp{c}=ex.p(:,:,c);
%                 end
%                 ex.logposterior = lp_tmp;
%                 ex.p = samp;
                
                if ~isempty(ex.p) % if there's data here                    
                    [true_p,true_logposterior]=deal([]);
                    if strcmp(data_type,'fake') && strcmp(o.name, g.name)
                        true_p = gen(gen_model_id).p(:,dataset_id);
                        true_logposterior = gen(gen_model_id).data(dataset_id).true_logposterior;
                    end
                    tic
                    [fh,ah]=mcmcdiagnosis(ex.p,'logposterior',ex.logposterior,'fit_model',o,'true_p',true_p,'true_logposterior',true_logposterior,'dataset',dataset_id,'dic',ex.dic,'gen_model',g);
                    toc
                    pause(.00001); % to plot
                end
            end
        end
    end
end

end
%%
fh = [];
fclose(log_fid);
delete([savedir filename '~'])
save([savedir filename])

%%
    function lp = log_prior(x)
        x = reshape(x, length(x), 1); % make sure x is column vector
        
        lapse_sum = lapse_rate_sum(x, o);
        if any(x<o.lb) || any(x>o.ub) || lapse_sum > 1
            lp = -Inf;
        else
            non_lapse_params = setdiff(1:length(x), o.lapse_params);
            uniform_range = o.ub(non_lapse_params) - o.lb(non_lapse_params);
            a=1; % beta dist params
            b=20;
            lp=sum(log(1./uniform_range))+sum(log(betapdf(x(o.lapse_params),a,b)));
        end
    end
end