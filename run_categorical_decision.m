function run_categorical_decision(initial)
% cd C:\GitHub\Confidence-Theory

% initial = 'rd_p1_run02_notrain'; % 'rdshortnotrain'
initial = 'testfast';

new_subject = false;
room_letter = '1139'; % 'mbp','Carrasco_L1'

category_type = 'same_mean_diff_std'; % 'same_mean_diff_std','sym_uniform'
attention_manipulation = true;

categorical_decision(category_type, initial, new_subject, ...
    room_letter, attention_manipulation)