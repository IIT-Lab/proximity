%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Simulation of Power Allocation in femtocell network using 
%   Reinforcement Learning with random adding of femtocells to the network
%   Which contains two phase, Independent and Cooperative Learning (IL&CL) 
%   
%
function FBS_out = PA_IL_CL2(FBS_in, fbsCount,femtocellPermutation, NumRealization, saveNum)

%% Initialization
% clear all;
clc;
% format short
% format compact
tic;
%% Parameters
Pmin = -20;                                                                                                                                                                                                                                                                                                                                                                           %dBm
Pmax = 25; %dBm
Npower = 31;

dth = 25;
Kp = 100; % penalty constant for MUE capacity threshold
Gmue = 1.37; % bps/Hz
StepSize = 1.5; % dB
K = 1000;
PBS = 50 ; %dBm
sinr_th = 1.64;%10^(2/10); % I am not sure if it is 2 or 20!!!!!
gamma_th = log2(1+sinr_th);
%% Minimum Rate Requirements for N MUE users
N = 3;
q_mue = 1.00; q_fue=1.0;
%% Q-Learning variables
% Actions
actions = zeros(1,31);
for i=1:31
    actions(i) = Pmin + (i-1) * 1.5; % dBm
end

% States
states = allcomb(0:3 , 0:3); % states = (dMUE , dBS)

% Q-Table
% Q = zeros(size(states,1) , size(actions , 2));
Q_init = ones(size(states,1) , size(actions , 2)) * 0.0;
Q1 = ones(size(states,1) , size(actions , 2)) * inf;
sumQ = ones(size(states,1) , size(actions , 2)) * 0.0;
meanQ = ones(size(states,1) , size(actions , 2)) * 0.0;

alpha = 0.5; gamma = 0.9; epsilon = 0.1 ; Iterations = 50000;
%% Generate the UEs
 mue(1) = UE(204, 207);
% mue(1) = UE(150, 150);
% mue(1) = UE(-200, 0);
% selectedMUE = mue(mueNumber);
MBS = BaseStation(0 , 0 , 50);
%%
%Generate fbsCount=16 FBSs, FemtoStation is the agent of RL algorithm
FBS_Max = cell(1,16);
for i=1:3
%     if i<= fbsCount
        FBS_Max{i} = FemtoStation(180+(i-1)*35,150, MBS, mue, 10);
%     end
end

for i=1:3
%     if i+3<= fbsCount
        FBS_Max{i+3} = FemtoStation(165+(i-1)*30,180, MBS, mue, 10);
%     end
end

for i=1:4
%     if i+6<= fbsCount
        FBS_Max{i+6} = FemtoStation(150+(i-1)*35,200, MBS, mue, 10);
%     end
end

for i=1:3
%     if i+10<= fbsCount
        FBS_Max{i+10} = FemtoStation(160+(i-1)*35,240, MBS, mue, 10);
%     end
end

for i=1:3
%     if i+13<= fbsCount
        FBS_Max{i+13} = FemtoStation(150+(i-1)*35,280, MBS, mue, 10);
%     end
end
%%
% 
FBS = cell(1,fbsCount);

for i=1:fbsCount
    FBS{i} = FBS_Max{femtocellPermutation(i)};
end

    %% Initialization and find MUE Capacity
    % permutedPowers = npermutek(actions,3);
    permutedPowers = randperm(size(actions,2),size(FBS,2));
    
    if fbsCount > 4
        for j=1:fbsCount-1
            FBS{j} = FBS_in{j};
            meanQ = meanQ + FBS{j}.Q;
        end
        meanQ = meanQ/(fbsCount-1);
        FBS{fbsCount} = FBS{fbsCount}.getDistanceStatus;
        FBS{fbsCount} = FBS{fbsCount}.setQTable(Q_init);
        for kk = 1:size(states,1)
            if states(kk,:) == FBS{fbsCount}.state
                break;
            end
        end
        FBS{fbsCount}.Q(kk,:)=meanQ(kk,:); %Receiving info from other Agents(FBSs) with the same state
    else 
        for j=1:size(FBS,2)
            fbs = FBS{j};
            fbs = fbs.setPower(actions(permutedPowers(j)));
            fbs = fbs.getDistanceStatus;
            fbs = fbs.setQTable(Q_init);
            FBS{j} = fbs;
        end
    end
%     selectedMUE.SINR = SINR_MUE(FBS, BS, selectedMUE, -120, 1000);
%     selectedMUE.C = log2(1+selectedMUE.SINR);

%     if selectedMUE.C < gamma_th
%         I = 1;
%     else
%         I = 0;
%     end
% 
%     for j=1:size(FBS,2)
%         fbs = FBS{j};
%         fbs.state(1,1) = I;
%         FBS{j} = fbs;
%     end
%% Calc channel coefficients
    fbsNum = size(FBS,2);
    G = zeros(fbsNum+1, fbsNum+1); % Matrix Containing small scale fading coefficients
    L = zeros(fbsNum+1, fbsNum+1); % Matrix Containing large scale fading coefficients
    [G, L] = measure_channel(FBS,MBS,mue,NumRealization);
    %% Main Loop
    fprintf('Loop for %d number of FBS :\t', fbsCount);
%     textprogressbar(sprintf('calculating outputs:'));
    count = 0;
    MUE_C = zeros(1,Iterations);
    xx = zeros(1,Iterations);
    errorVector = zeros(1,Iterations);
    dth = 25; %meter

    for episode = 1:Iterations
%         textprogressbar((episode/Iterations)*100);
        permutedPowers = randperm(size(actions,2),size(FBS,2));
        sumQ = sumQ * 0.0;
        for j=1:size(FBS,2)
            fbs = FBS{j};
            sumQ = sumQ + fbs.Q; 
        end
        
        if (episode/Iterations)*100 < 80
            % Action selection with epsilon=0.1
            if rand<epsilon
                for j=1:size(FBS,2)
                    fbs = FBS{j};
                    fbs = fbs.setPower(actions(permutedPowers(j)));
                    FBS{j} = fbs;
                end
            else
                for j=1:size(FBS,2)
                    fbs = FBS{j};
                    for kk = 1:size(states,1)
                        if states(kk,:) == fbs.state
                            break;
                        end
                    end
                    if size(FBS,2) > 4 
                        [M, index] = max(sumQ(kk,:));     % CL method
                    else                                    
                        [M, index] = max(fbs.Q(kk,:));   %IL method
                    end
                    fbs = fbs.setPower(actions(index));
                    FBS{j} = fbs;
                end
            end
        else
            for j=1:size(FBS,2)
                fbs = FBS{j};
                for kk = 1:size(states,1)
                    if states(kk,:) == fbs.state
                        break;
                    end
                end
                
                if size(FBS,2) > 4 
                    [M, index] = max(sumQ(kk,:));     % CL method
                else                                    
                    [M, index] = max(fbs.Q(kk,:));   %IL method
                end
                fbs = fbs.setPower(actions(index));
                FBS{j} = fbs;
            end
        end 

        % calc FUEs and MUEs capacity
        SINR_FUE_Vec = SINR_FUE_2(G, L, FBS, MBS, -120);
        C_FUE_Vec = log2(1+SINR_FUE_Vec);
        for i=1:size(mue,2)
            MUE = mue(i);
            MUE.SINR = SINR_MUE_4(G, L, FBS, MBS, MUE, -120);
            MUE = MUE.setCapacity(log2(1+MUE.SINR));
            mue(i)=MUE;
        end
        
%         MUE_C(1,episode) = selectedMUE.C;
        xx(1,episode) = episode;
%         R = K - (selectedMUE.SINR - sinr_th)^2;
%             deviation_FUE=0.0;
%             for i=1:size(FBS,2)
%                 deviation_FUE = deviation_FUE + (fbs.C_FUE-q_M)^2;
%             end
        dum1 = 1.0;
        for i=1:size(mue,2)
            dum1 = dum1 * (mue(i).C-q_mue)^2;
        end
        
        for j=1:size(FBS,2)
            fbs = FBS{j};
            fbs = fbs.setCapacity(log2(1+SINR_FUE_Vec(j)));
            FBS{j}=fbs;
        end
        for j=1:size(FBS,2)
            fbs = FBS{j};
            qMax=max(fbs.Q,[],2);
            for jjj = 1:31
                if actions(1,jjj) == fbs.P
                    break;
                end
            end
            for kk = 1:size(states,1)
                if states(kk,:) == fbs.state
                    break;
                end
            end
            % CALCULATING NEXT STATE AND REWARD
            beta = fbs.dMUE/dth;
            R = beta*fbs.C_FUE*(mue(1).C).^2 -(fbs.C_FUE-q_fue).^2 - (1/beta)*dum1;
            for nextState=1:size(states,1)
                if states(nextState,:) == fbs.state
                    fbs.Q(kk,jjj) = fbs.Q(kk,jjj) + alpha*(R+gamma*qMax(nextState)-fbs.Q(kk,jjj));
                end
            end
            FBS{j}=fbs;
        end

        % break if convergence: small deviation on q for 1000 consecutive
        errorVector(episode) =  sum(sum(abs(Q1-sumQ)));
        if sum(sum(abs(Q1-sumQ)))<0.001 && sum(sum(sumQ >0))
            if count>1000
                episode  % report last episode
                break % for
            else
                count=count+1; % set counter if deviation of q is small
            end
        else
            Q1=sumQ;
            count=0;  % reset counter when deviation of q from previous q is large
        end

%         if selectedMUE.C < gamma_th
%             I = 1;
%         else
%             I = 0;
%         end
% 
%         for j=1:size(FBS,2) 
%             fbs = FBS{j};
%             fbs.state(1,1) = I;
%             FBS{j} = fbs;
%         end
    end
    Q = sumQ;
    answer.mue = mue;
    answer.Q = sumQ;
    answer.Error = errorVector;
    answer.FBS = FBS;
%     min_CFUE = inf;
    for j=1:size(FBS,2)
%         C = FBS{1,j}.C_profile;
        c_fue(1,j) = FBS{1,j}.C_FUE;%sum(C(40000:size(C,2)))/(-40000+size(C,2));
%         if min_CFUE > c_fue(1,j)
%             min_CFUE = c_fue(1,j);
%         end
    end
    sum_CFUE = 0.0;
    for i=1:size(FBS,2)
        sum_CFUE = sum_CFUE + FBS{i}.C_FUE;
    end
    answer.C_FUE = c_fue;
    answer.sum_CFUE = sum_CFUE;
%     answer.min_CFUE = min_CFUE;
    answer.episode = episode;
    answer.time = toc;
    QFinal = answer;
    save(sprintf('oct17/R_18_CL2/pro_%d_%d.mat',fbsCount, saveNum),'QFinal');
    FBS_out = FBS;
end
