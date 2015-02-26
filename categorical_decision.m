function categorical_decision(category_type, initial, new_subject_flag, room_letter, exp_number, nExperiments, first_task_letter, attention_manipulation, user)
% Ryan George
% Theoretical Neuroscience Lab, Baylor College of Medicine
% Will Adler
% Ma Lab, New York University

% THIS HAS SOME UNTESTED STUFF: flip_wait_for_experimenter_flip stuff.

try
    rng('shuffle','twister')
catch
    s = RandStream.create('mt19937ar','seed',sum(100*clock));
    RandStream.setDefaultStream(s);
end

Screen('Preference', 'SkipSyncTests', 1); % WTA.
Screen('Preference', 'VisualDebuglevel', 3);

switch user
    case 'rachel'
        dir = pwd;
        datadir = [dir '/data'];
        addpath(genpath(dir))
    otherwise
        if strcmp(computer,'MACI64') % Assuming this is running on my MacBook
            dir = '/Users/will/Google Drive/Ma lab/repos/qamar confidence';
            datadir = '/Users/will/Google Drive/Will - Confidence/Data';
            
        elseif strcmp(computer,'PCWIN64') % Assuming the left Windows psychophysics machine
            dir = 'C:\Users\malab\Documents\GitHub\Confidence-Theory';
            datadir = 'C:\Users\malab\Google Drive/Will - Confidence/Data';
            
        end
end

cd(dir)

%initial = input('Please enter your initials.\n> ', 's'); % 's' returns entered text as a string

%new_subject_flag = input('\nAre you new to this experiment? Please enter y or n.\n> ', 's');
%while ~strcmp(new_subject_flag,'y') && ~strcmp(new_subject_flag,'n')
%    new_subject_flag = input('You must enter y or n.\nAre you new to this experiment? Please enter y or n.\n> ', 's');
%end

%room_letter = input('\nPlease enter the room name [mbp] or [home] or [1139].\n> ', 's');

%initial = 'test';
%new = 'y'
%room_letter = 'mbp';

datetimestamp = datetimefcn; % establishes a timestamp for when the experiment was started

% map keys with 'WaitSecs(0.2); [~, keyCode] = KbWait;find(keyCode==1)' and
% then press a key.
fontsize = 28; % unless the hires_rig below
fontstyle = 0; % unless the hires_rig below

switch room_letter
    case 'home'
        screen_width = 64;%64 %30" cinema display width in cm (.250 mm pixels)
    case 'mbp'
        screen_width = 33.2509;
    case '1139'
        screen_width = 37.632; % left LCD screen
        
        %scr.keyx=88; %x
        %scr.keyz=90; %z
        scr.keyinsert = 45; % insert
        scr.keyenter = 13; % enter
        
        %[scr.key1, scr.key2, scr.key3, scr.key4, scr.key5, scr.key6] = ...
        %deal(49, 50, 51, 48, 189, 187); % This is for keys 1,2,3,0,-,=
        
        %    [scr.key1, scr.key2, scr.key3, scr.key4, scr.key5, scr.key6,...
        %        scr.key7, scr.key8] = deal(65, 83, 68, 70, 72, 74, 75, 76)
        % This is for keys a,s,d,f,h,j,k,l
        
        [scr.key1, scr.key2, scr.key3, scr.key4, scr.key5, scr.key6,...
            scr.key7, scr.key8, scr.key9, scr.key10] ...
            = deal(112, 113, 114, 115, 116, 119, 120, 121, 122, 123);
        % This is for keys F1-5, F8-12.
    case '1139_hires_rig'
        screen_width = 19.7042; %iPad screen width in cm
        scr.keyinsert = 45; % insert
        scr.keyenter = 13; % enter
        [scr.key1, scr.key2, scr.key3, scr.key4, scr.key5, scr.key6,...
            scr.key7, scr.key8, scr.key9, scr.key10] ...
            = deal(112, 113, 114, 115, 116, 119, 120, 121, 122, 123);
        % This is for keys F1-5, F8-12.
        fontsize = 42;
        fontstyle = 1;
    case 'Carrasco_L1'
        screen_width = 40;
        screen_distance = 56;
        
end
if strcmp(room_letter,'home') || strcmp(room_letter,'mbp') || strcmp(room_letter,'Carrasco_L1')
    [scr.key1, scr.key2, scr.key3, scr.key4, scr.key5, scr.key6,...
        scr.key7, scr.key8, scr.key9, scr.key10] ...
        = deal(30, 31, 32, 33, 34, 37, 38, 39, 45, 46); % This is for keys 1,2,3,4,5,8,9,0,-,=
    scr.keyinsert=53;% backspace
    scr.keyenter=42;%tilde
    %scr.keyx=27; %x
    %scr.keyz=29; %z
end

close all;
%%
nDemoTrials = 72; % for 'new' style demo
elapsed_mins = 0;

%Paradigm Parameters stored (mainly) in the two structs 'Training' and 'Test'
P.stim_type = 'grate';  %options: 'grate', 'ellipse'
%category_type = 'same_mean_diff_std'; % 'same_mean_diff_std' or 'diff_mean_same_std' or 'sym_uniform' or 'half_gaussian. Further options for sym_uniform (ie bounds, and overlap) and half_gaussian (sig_s) are in setup_exp_order.m
% attention_manipulation = true;
cue_validity = .7;

% colors in 0:255 space
white = 255;
color.wt = [white white white];
lightgray = 180;
bg = 127.5;
color.bg = bg;
darkgray = 10;
black = 0;
color.bk = [black black black];
color.red = [100 0  0];
color.grn = [0 100 0];

countdown_time = 30; % countdown between blocks

if strcmp(category_type, 'same_mean_diff_std')
    Test.category_params.sigma_1 = 3;
    Test.category_params.sigma_2 = 12;
    task_letter = 'B';
    other_task_letter = 'A';
elseif strcmp(category_type, 'diff_mean_same_std')
    Test.category_params.sigma_s = 5; % these params give a level of performance that is about on par withthe original task (above)
    Test.category_params.mu_1 = -4;
    Test.category_params.mu_2 = 4;
    task_letter = 'A';
    other_task_letter = 'B';
elseif strcmp(category_type, 'sym_uniform')
    if attention_manipulation
        Test.category_params.uniform_range = 15; % 5
    else
        Test.category_params.uniform_range = 15;
    end
    Test.category_params.overlap = 0;
    task_letter = 'A';
    other_task_letter = 'B';
elseif strcmp(category_type, 'half_gaussian')
    Test.category_params.sigma_s = 5;
end
if attention_manipulation
    task_letter = 'Attention';
    other_task_letter = 'Attention';
end
Test.category_params.category_type = category_type;

if strcmp(P.stim_type, 'ellipse')
    Test.category_params.test_sigmas = .4:.1:.9; % are these reasonable eccentricities?
else
    if attention_manipulation
        Test.category_params.test_sigmas = exp(-3.5);
    else
        Test.category_params.test_sigmas= exp(linspace(-5.5,-2,6)); % on previous rig: exp(-4:.5:-1.5)
    end
end

Training.category_params = Test.category_params;
if strcmp(P.stim_type, 'ellipse')
    Training.category_params.test_sigmas = .95;
else
    Training.category_params.test_sigmas = 1;
end

if attention_manipulation
    Test.n.blocks = 5;
    Test.n.sections = 2;
    Test.n.trials = 40; % 9*numel(Test.sigma.int)*2 = 108
else
    Test.n.blocks = 3;% WTA from 3
    Test.n.sections = 3; % WTA from 3
    Test.n.trials = 8*numel(Test.category_params.test_sigmas); % 9*numel(Test.sigma.int)*2 = 108
end

Training.initial.n.blocks = 1; %Do Not Change
Training.initial.n.sections = 2; % WTA: 2
Training.initial.n.trials = 36;% WTA: 36
Training.confidence.n.blocks = 1;
Training.confidence.n.sections = 1;
Training.confidence.n.trials = 24; % WTA: 16
Training.n.blocks = Test.n.blocks; % was 0 before, but 0 is problematic.
Training.n.sections = 1; %changed from '2' on 10/14
Training.n.trials = 48; % WTA: 48

Demo.t.pres = 250;
Demo.t.betwtrials = 200;


Test.t.pres = 50;           %50
Test.t.pause = 200;         %200 isn't used
Test.t.feedback = 1200;     %1200 isn't used
Test.t.betwtrials = 1000;   %1000
Test.t.cue_dur = 150;
Test.t.cue_target_isi = 150;

Training.t.pres = 300; %300 %how long to show first stimulus (ms)
Training.t.pause = 100; %100 time between response and feedback
Training.t.feedback = 1100;  %1700 time of "correct" or "incorrect" onscreen
Training.t.betwtrials = 1000; %1000
Training.t.cue_dur = 150;
Training.t.cue_target_isi = 150;


%%8
if strfind(initial,'fast') > 0 % if 'fast' is in the initials, the exp will be super fast (for debugging)
    [Test.t.pres,Test.t.pause,Test.t.feedback,Test.t.betwtrials,Training.t.pres,Training.t.pause,Training.t.feedback,Training.t.betwtrials,countdown_time, Demo.t.pres, Demo.t.betwtrials]...
        = deal(1);
end

if strfind(initial,'short') > 0 % if 'short' is in the initials, the exp will be short (for debugging)
    [Test.n.trials,Training.initial.n.trials,Training.confidence.n.trials,Training.n.trials]...
        = deal(numel(Test.category_params.test_sigmas)*2, 4, 4, 4);
    nDemoTrials = 5;
    countdown_time = 2;
end

if strfind(initial,'notrain') > 0 % if 'notrain' is in the initials, the exp will not include training (for debugging)
    notrain = 1;
else
    notrain = 0;
end


try
    % Choose screen with maximum id - the secondary display:
    %primary display
    %screenid = min(Screen('Screens'));
    
    %secondary display
    screenid = max(Screen('Screens'));
    
    if strcmp(room_letter,'home')
        screenid = 0;
    end
    
    % OPEN FULL SCREEN
    [scr.win, scr.rect] = Screen('OpenWindow', screenid, color.bg); %scr.win is the window id (10?), and scr.rect is the coordinates in the form [ULx ULy LRx LRy]
    % OPEN IN WINDOW
    %[scr.win, scr.rect] = Screen('OpenWindow', screenid, color.bg, [100 100 1200 1000]);
    
    %LoadIdentityClut(scr.win) % default gamma table
    switch room_letter
        case '1139'
            load('calibration/iPadGammaTable') % gammatable calibrated on Meyer 1139 L Dell monitor, using CalibrateMonitorPhotometer (edits are saved in the calibration folder)
            Screen('LoadNormalizedGammaTable', scr.win, gammaTable*[1 1 1]);
        case 'Carrasco_L1'
            calib = load('../../Displays/0001_james_TrinitonG520_1280x960_57cm_Input1_140129.mat');
            Screen('LoadNormalizedGammaTable', scr.win, repmat(calib.calib.table,1,3));
            % check gamma table
            gammatable = Screen('ReadNormalizedGammaTable', scr.win);
            if nnz(abs(gammatable-repmat(calib.calib.table,1,3))>0.0001)
                error('Gamma table not loaded correctly! Perhaps set screen res and retry.')
            end
    end
    
    scr.w = scr.rect(3); % screen width in pixels
    scr.h = scr.rect(4); % screen height in pixels
    scr.cx = mean(scr.rect([1 3])); % screen center x
    scr.cy = mean(scr.rect([2 4])); % screen center y
    
    if ~strfind(initial,'test')
        HideCursor;
        SetMouse(0,0);
    end
    
    Screen('TextSize', scr.win,fontsize); % Set default text size for this window, ie 28
    Screen('TextStyle', scr.win, fontstyle); % Set default text style for this window. 0 means normal, not bold/condensed/etc
    Screen('Preference', 'TextAlphaBlending', 0);
    
    % screen info
    screen_resolution = [scr.w scr.h];                 % screen resolution ie [1440 900]
    if ~exist('screen_distance','var')
        screen_distance = 50;                      % distance between observer and screen (in cm) NOTE THAT FOR EXP v3 THIS WAS SET TO 50, BUT TRUE DIST WAS ~32
    end
    screen_angle = 2*(180/pi)*(atan((screen_width/2) / screen_distance)) ; % total visual angle of screen in degrees
    P.pxPerDeg = screen_resolution(1) / screen_angle;  % pixels per degree
    
    %set up fixation cross
    switch user
        case 'will'
            f_c_size = 37; % must be odd
            thickness = 5; % must be odd
            f_c = color.bg*ones(f_c_size);
            row1=1+0.5*(f_c_size-thickness);
            row2=0.5*(f_c_size+thickness);
            f_c(row1:row2,:)=black;
            f_c(:,row1:row2)=black;
        case 'rachel'
            if attention_manipulation
                f_c_size = 30;
                fw = 1;
            else
                f_c_size = 18; %pixels
                fw = 0; % 0 results in a line thickness of 1 pixel
            end
            f_c = bg*ones(f_c_size);
            f_c(f_c_size/2 - fw: f_c_size/2 + 1 + fw,:) = darkgray;
            f_c(:,f_c_size/2 - fw: f_c_size/2 + 1 + fw) = darkgray;
    end
    scr.cross = Screen('MakeTexture', scr.win , f_c);

    if attention_manipulation
        cross_whiteL = f_c;
        cross_whiteL(f_c_size/2-fw:f_c_size/2 + 1 + fw, 1:f_c_size/2-1-fw) = white;
        cross_grayL = f_c;
        cross_grayL(f_c_size/2-fw:f_c_size/2 + 1 + fw, 1:f_c_size/2-1-fw) = lightgray;
        
        scr.cueL = Screen('MakeTexture', scr.win, cross_whiteL);
        scr.cueR = Screen('MakeTexture', scr.win, fliplr(cross_whiteL));
        scr.resp_cueL = Screen('MakeTexture', scr.win, cross_grayL);
        scr.resp_cueR = Screen('MakeTexture', scr.win, fliplr(cross_grayL));
    end
    
    % set up grating parameters
    P.grateSigma = .8; % Gabor Gaussian envelope standard deviation (degrees)
    P.grateSigma = P.grateSigma * P.pxPerDeg; %...converted to pixels
    P.grateAspectRatio = 1;
    P.grateSpatialFreq = .8; % cycles/degree
    P.grateSpatialFreq = P.grateSpatialFreq / P.pxPerDeg; % cycles / pixel
    P.grateSpeed = 10; % cycles per second
    P.grateDt = .01; %seconds per frame
    P.grateAlphaMaskSize = round(10*P.grateSigma);
    
    % Ellipse parameters
    P.ellipseAreaDegSq = 1; % ellipse area in degrees squared
    P.ellipseAreaPx = P.pxPerDeg^2 * P.ellipseAreaDegSq; % ellipse area in number of pixels
    P.ellipseColor = 0;
    
    P.attention_stim_spacing = 3.5;% for two stimuli, distance from center, in degrees
    P.stim_dist = round(P.attention_stim_spacing * P.pxPerDeg); % distance from center in pixels
    
    %%%Setup routine. this is some complicated stuff to deal with the
    %%%two-part training thing
    
    InitialTrainingpreR = setup_exp_order(Training.initial.n, Training.category_params, category_type);
    
    Training.n.blocks = Training.n.blocks - 1;
    TrainingpreR = setup_exp_order(Training.n, Training.category_params, category_type);
    
    Training.n.blocks = Training.n.blocks + 1; % undo previous line
    
    Training.R.trial_order{1} = InitialTrainingpreR.trial_order{1};
    Training.R.sigma{1} = InitialTrainingpreR.sigma{1};
    Training.R.draws{1} = InitialTrainingpreR.draws{1};
    Training.R.phase{1} = InitialTrainingpreR.phase{1};
    for spec = 2:Training.n.blocks
        Training.R.trial_order{spec} = TrainingpreR.trial_order{spec-1};
        Training.R.sigma{spec} = TrainingpreR.sigma{spec-1};
        Training.R.draws{spec} = TrainingpreR.draws{spec-1};
        Training.R.phase{spec} = TrainingpreR.phase{spec-1};
    end
    
    Test.R = setup_exp_order(Test.n, Test.category_params, category_type);
    
    if attention_manipulation
        Test.R2 = setup_exp_order(Test.n, Test.category_params, category_type, 1, cue_validity); % second set of stimuli. This also contains the probe/cue info.
    end
    
    Training.confidence.R = setup_exp_order(Training.confidence.n, Test.category_params, category_type);
    
    start_t = tic;
    %% DEMO
    
    stim.ort = 0;
    stim.cur_sigma = Training.category_params.test_sigmas;
    
    if strcmp(P.stim_type, 'grate')
        gabortex = CreateProceduralGabor(scr.win, P.grateAlphaMaskSize, P.grateAlphaMaskSize, [], [0.5 0.5 0.5 0.0],1,0.5);
        Screen('DrawTexture', scr.win, gabortex, [], [], 90-stim.ort, [], [], [], [], kPsychDontDoRotation, [0, P.grateSpatialFreq, P.grateSigma, stim.cur_sigma, P.grateAspectRatio, 0, 0, 0]);
        [nx,ny]=DrawFormattedText(scr.win, 'Example Stimulus\n\n', 'center', scr.cy-P.grateAlphaMaskSize/2, color.wt);
        ny = ny+P.grateAlphaMaskSize/2;
    elseif strcmp(P.stim_type, 'ellipse')
        im = drawEllipse(P.ellipseAreaPx, .95, 0, P.ellipseColor, mean(P.bgColor));
        max_ellipse_d = size(im,1); % in this case, this is the height of the longest (tallest) ellipse
        ellipse(P, scr, [], stim)
        ny = ny+max_ellipse_d;
    end
    
    if strcmp(new_subject_flag,'y')
        flip_wait_for_experimenter_flip(scr.keyenter);
    elseif strcmp(new_subject_flag,'n')
        flip_pak_flip(scr,ny,color,'continue');
    end
    
    hitxt=sprintf('Important: You are now doing Task %s!\n\n',task_letter);
    
    %[nx,ny]=DrawFormattedText(scr.win, ['Important: You are now doing Task ' task_letter '!\n\n'], 'center', 'center', color.wt);
    if strcmp(new_subject_flag,'n')
        if strcmp(task_letter, 'A')
            midtxt = 'In task A, stimuli from Category 1 tend to\n\nbe left-tilted, and stimuli from Category 2\n\ntend to be right-tilted.\n\nSee Task sheet for more info.';
        elseif strcmp(task_letter, 'B')
            midtxt = 'In task B, a flat stimulus is more likely\n\nto be from Category 1, and a strongly tilted\n\nstimulus is more likely\n\nto befrom Category 2.\n\nSee Task sheet for more info.';
        else
            midtxt = '';
        end
    else
        midtxt = '';
    end
    [nx,ny]=DrawFormattedText(scr.win, [hitxt midtxt], 'center', 'center', color.wt);
    flip_pak_flip(scr,ny,color,'continue');
    
    for category = 1 : 2
        DrawFormattedText(scr.win, sprintf('Examples of Category %i stimuli:', category), 'center', scr.cy-60, color.wt);
        Screen('Flip', scr.win);
        WaitSecs(2.5);
        
        for i = 1:nDemoTrials
            
            Screen('DrawTexture', scr.win, scr.cross);
            Screen('Flip', scr.win);
            WaitSecs(Demo.t.betwtrials/1000);
            
            stim.ort = stimulus_orientations(Test.category_params, category_type, category, 1, 1);
            
            if strcmp(P.stim_type, 'gabor')
                r_gabor(P, scr, Demo.t, stim); % haven't yet added phase info to this function
            elseif strcmp(P.stim_type, 'grate')
                stim.phase = 360*rand;
                grate(P, scr, Demo.t, stim);
            elseif strcmp(P.stim_type, 'ellipse')
                ellipse(P, scr, Demo.t, stim);
            end
        end
        
        flip_pak_flip(scr,scr.cy,color,'continue');
    end
    
    %end
    %END DEMO
    
    
    %% START TRIALS
    if ~notrain
        [~,ny]=DrawFormattedText(scr.win,'Coming up: Category Training','center','center',color.wt)
    else
        [~,ny]=DrawFormattedText(scr.win,'Here comes the experiment','center','center',color.wt)
    end
    
    flip_pak_flip(scr,ny,color,'begin');
    
    for k = 1:Test.n.blocks
        if ~notrain
            if k == 1
                Training.initial.n.blocks = Training.n.blocks;
                numbers = Training.initial.n;
            else
                numbers = Training.n;
            end
            
            [Training.responses{k}, flag] = run_exp(numbers, Training.R, Training.t, scr, color, P, 'Training',k, new_subject_flag, task_letter, first_task_letter);
            if flag ==1,  break;  end
            
            if k == 1% && strcmp(new_subject_flag,'y') % if we are on block 1, and subject is new
                [~,ny]=DrawFormattedText(scr.win,['Let''s get some quick practice with confidence ratings.\n\n'...
                    'Coming up: Task ' task_letter ' Confidence Training'],'center',ny,color.wt);
                flip_pak_flip(scr,ny,color,'begin')
                
                [Training.confidence.responses, flag] = run_exp(Training.confidence.n,Training.confidence.R,Test.t,scr,color,P,'Confidence Training',k, new_subject_flag, task_letter, first_task_letter);
                if flag==1,break;end
                
            end
        end
        
        if attention_manipulation
            [Test.responses{k}, flag, blockscore] = run_exp(Test.n, Test.R, Test.t, scr, color, P, 'Test',k, new_subject_flag, task_letter, first_task_letter, Test.R2);
        else
            [Test.responses{k}, flag, blockscore] = run_exp(Test.n, Test.R, Test.t, scr, color, P, 'Test',k, new_subject_flag, task_letter, first_task_letter);
        end
        if flag ==1,  break;  end
        
        
        %load top scores
        load top_ten
        
        ranking = 11 - sum(blockscore>=top_ten.(category_type).scores); % calculate current ranking
        
        if ranking < 11
            top_ten.(category_type).scores = [top_ten.(category_type).scores(1:(ranking-1));  blockscore;  top_ten.(category_type).scores(ranking:9)];
            for m = 10:-1:ranking+1
                top_ten.(category_type).initial{m} = top_ten.(category_type).initial{m-1};
            end
            top_ten.(category_type).initial{ranking} = initial;
            hitxt=['\n\nCongratulations! You made the top ten for Task ' task_letter '!\n\n'];
        else
            hitxt='\n\n\n\n';
        end
        
        if ~any(strfind(initial,'test'))
            save top_ten top_ten;
        end
        elapsed_mins = toc(start_t)/60;
        save(strrep([datadir '/backup/' initial '_' datetimestamp '.mat'],'/',filesep), 'Training', 'Test', 'P','elapsed_mins','category_type') % block by block backup. strrep makes the file separator system-dependent.
        
        [nx,ny] = DrawFormattedText(scr.win,[hitxt 'Your score for Testing Block ' num2str(k) ': ' num2str(blockscore,'%.1f') '%\n\n'...
            'Top Ten for Task ' task_letter ':\n\n'],'center',-90,color.wt);
        for j = 1:10
            [nx,ny] = DrawFormattedText(scr.win,[num2str(j) ') ' num2str(top_ten.(category_type).scores(j),'%.1f') '%    ' top_ten.(category_type).initial{j} '\n'],scr.cx*.8 - (j==10)*20,ny,color.wt);
        end
        
        if k ~= Test.n.blocks % if didn't just finish final testing block
            [nx,ny] = DrawFormattedText(scr.win,'\nPlease take a short break.\n\n\nYou may begin the next Training Block\n\n','center',ny,color.wt);
            [nx,ny] = DrawFormattedText(scr.win,'in ',scr.cx-570,ny,color.wt);
            countx=nx; county=ny;
            [nx,ny] = DrawFormattedText(scr.win,'   seconds, but you may take a\n\n',countx,county,color.wt);
            if ~notrain
                [nx,ny] = DrawFormattedText(scr.win,['longer break and leave the room\n\n'...
                    'or walk around.\n\n\n'...
                    'Coming up: Task ' task_letter ' Category Training before\n\n'...
                    'Task ' task_letter ' Testing Block ' num2str(k+1)],'center',ny,color.wt,50);
            else
                [nx,ny] = DrawFormattedText(scr.win,['longer break and leave the room\n\n'...
                    'or walk around.\n\n\n'...
                    'Coming up:\n\n'...
                    'Task ' task_letter ' Testing Block ' num2str(k+1)],'center',ny,color.wt,50);
            end
            
            countdown
            
            flip_pak_flip(scr,ny,color,'continue','initial_wait',0);
            
            if ~notrain
                [nx,ny] = DrawFormattedText(scr.win,['You will now begin\n\nTask ' task_letter ' Category Training before\n\n'...
                    'Task ' task_letter ' Testing Block ' num2str(k+1) '.'],'center','center',color.wt,50);
            else
                [nx,ny] = DrawFormattedText(scr.win,['You will now begin\n\n'...
                    'Task ' task_letter ' Testing Block ' num2str(k+1) '.'],'center','center',color.wt,50);
            end
            flip_pak_flip(scr,ny,color,'begin');
            
            
            % end top ten scores
            
        elseif k == Test.n.blocks && exp_number ~= nExperiments && strcmp(new_subject_flag,'y')
            [nx,ny] = DrawFormattedText(scr.win,['\nYou''re done with Task ' task_letter '.\n\n\n'...
                'Please go get the experimenter from the other room!'],'center',ny,color.wt);
            %             Screen('Flip',scr.win);
            %WaitSecs(5);
            flip_wait_for_experimenter_flip(scr.keyenter);
            %             KbWait;
            %             Screen('Flip',scr.win);
            
        elseif k == Test.n.blocks && exp_number ~= nExperiments && strcmp(new_subject_flag,'n')% if just finished experiment one, and there's another experiment coming up.
            [nx,ny] = DrawFormattedText(scr.win,['\nYou''re done with Task ' task_letter '.\n\n\n'],'center',ny,color.wt);
            [nx,ny] = DrawFormattedText(scr.win,['You may begin Task ' other_task_letter ' in '],scr.cx-570,ny,color.wt);
            countx=nx; county=ny;
            [nx,ny] = DrawFormattedText(scr.win,'   seconds,\n\n',countx,county,color.wt);
            [nx,ny] = DrawFormattedText(scr.win,['but you may take a longer break\n\n'...
                'and leave the room or walk around.\n\n\n'...
                'Coming up: Task ' other_task_letter],'center',ny,color.wt,50);
            
            countdown
            
            flip_pak_flip(scr,ny,color,'begin','initial_wait',0);
            
            
        elseif k == Test.n.blocks && exp_number == nExperiments % if done with both experiments
            [nx,ny] = DrawFormattedText(scr.win,'\n\n\n\nYou''re done with the experiment.\n\nThank you for participating!','center',ny,color.wt);
            Screen('Flip',scr.win)
            WaitSecs(1);
            KbWait([], 0, GetSecs+180); % automatically quit after 3 minutes
        end
        
        WaitSecs(1);
        
    end
    
    if flag == 1 % when run_exp errors
        initial = [initial '_flaggedinrunexp'];
    end
    
    save top_ten top_ten;
    elapsed_mins = toc(start_t)/60;
    save(strrep([datadir '/' initial '_' datetimestamp '.mat'],'/',filesep), 'Training', 'Test', 'P', 'category_type', 'elapsed_mins') % save complete session
    recycle('on'); % tell delete to just move to recycle bin rather than delete entirely.
    delete([datadir '/backup/' initial '_' datetimestamp '.mat']) % delete the block by block backup
    
    Screen('CloseAll');
    
catch %if error or script is cancelled
    try
        Screen('CloseAll');
    catch; end
    
    %file_name = ['backup/' initial '_recovered'];
    %savedatafcn(file_name, datetimestamp, Training, Test, P); %save what we have
    save(strrep([datadir '/backup/' initial '_recovered_' datetimestamp '.mat'],'/',filesep), 'Training', 'Test', 'P','category_type', 'elapsed_mins')
    
    psychrethrow(psychlasterror);
end

    function countdown
        for i=1:countdown_time+1;
            Screen('FillRect',scr.win,color.bg,[countx county countx+1.6*fontsize county+1.2*fontsize]) %timer background
            DrawFormattedText(scr.win,[num2str(countdown_time+1-i) '  '],countx,county,color.wt);
            Screen('Flip',scr.win,[],1); % flip to screen without clearing
            WaitSecs(1);
        end
    end

end