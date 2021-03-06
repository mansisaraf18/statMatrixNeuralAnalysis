function behavMatrixTrialStruct = OrganizeTrialData_SM(behavMatrix, behavMatrixColIDs, trialLims, trialStart)
%% OrganizeTrialData_SM
%   Organizes statMatrix data into a trial-wise organization. 
%% Check Inputs
% The input trialLims is designed to specify the time period around a trial
% to extract on each trial.
if nargin==1
    error('Not enough inputs');
elseif nargin==2 || isempty(trialLims)
    trialLims = [-1 3];
    trialStart = 'Odor';
elseif nargin==3 || isempty(trialStart)
    trialStart = 'Odor';
end

%% Extract Timestamps
tsVect = behavMatrix(:,1);
sampleRate = 1/mode(diff(tsVect));
trlWindow = [round(trialLims(1)*sampleRate) round(trialLims(2)*sampleRate)];

%% Extract Trial Indexes & Poke Events
% separate out odor and position columns 
odorTrlMtx = behavMatrix(:,cellfun(@(a)~isempty(a), strfind(behavMatrixColIDs, 'Odor')));
positionTrlMtx = behavMatrix(:,cellfun(@(a)~isempty(a), regexp(behavMatrixColIDs, 'Position[1-9]$')));
% Sum them on 2d to extract trial indices
trialVect = sum(odorTrlMtx,2);
trialIndices = find(trialVect);
numTrials = sum(trialVect);
% Pull out Poke events and identify pokeIn/Out indices
pokeVect = behavMatrix(:, cellfun(@(a)~isempty(a), strfind(behavMatrixColIDs, 'PokeEvents')));
pokeInNdxs = find(pokeVect==1);
pokeOutNdxs = find(pokeVect==-1);
% Pull out Front Reward Indices
frontRwrdVect = behavMatrix(:, cellfun(@(a)~isempty(a), strfind(behavMatrixColIDs, 'FrontReward')));
frontRwrdNdxs = find(frontRwrdVect);
% Pull out Rear Reward Indices
rearRwrdVect = behavMatrix(:, cellfun(@(a)~isempty(a), strfind(behavMatrixColIDs, 'BackReward')));
rearRwrdNdxs = find(rearRwrdVect);
% Pull out Error Indices
errorSigVect = behavMatrix(:, cellfun(@(a)~isempty(a), strfind(behavMatrixColIDs, 'ErrorSignal')));
errorSigNdxs = find(errorSigVect);
% Pull out Sequence Length
seqLength = size(positionTrlMtx,2);
% Identify trial performance 
trialPerfVect = behavMatrix(:, cellfun(@(a)~isempty(a), strfind(behavMatrixColIDs, 'Performance')));
% Identify InSeq logical
inSeqLog = behavMatrix(:, cellfun(@(a)~isempty(a), strfind(behavMatrixColIDs, 'InSeqLog')));

%% Create Data input structures
seqNum = cell(1,numTrials);
trialOdor = cell(1,numTrials);
trialPosition = cell(1,numTrials);
trialPerf = cell(1,numTrials);
trialTransDist = cell(1,numTrials);
trialItmItmDist = cell(1,numTrials);
trialPokeInNdx = repmat({nan}, [1, numTrials]);
trialOdorNdx = repmat({nan}, [1, numTrials]);
trialPokeOutNdx = repmat({nan}, [1, numTrials]);
trialRewardNdx = repmat({nan}, [1, numTrials]);
trialErrorNdx = repmat({nan}, [1, numTrials]);
trialLogVect = cell(1,numTrials);
trialNum = cell(1,numTrials);
pokeDuration = cell(1,numTrials);
seq = 0;
%% Go through each trial and pull out trial information and create a logical vector for that trial's time periods specified by the input trialLims
for trl = 1:numTrials
    trialNum{trl} = trl;
    % Identify Trial/Position/Descriptors
    curTrlOdor = find(odorTrlMtx(trialIndices(trl),:)==1);
    curTrlPos = find(positionTrlMtx(trialIndices(trl),:)==1);
    curTrlPerf = trialPerfVect(trialIndices(trl))==1;
    curTrlInSeqLog = inSeqLog(trialIndices(trl))==1;
    
    trialOdor{trl} = curTrlOdor;
    trialPosition{trl} = curTrlPos;
    trialPerf{trl} = curTrlPerf;
    % Increment the sequence counter as necessary
    if curTrlPos==1                                                         % Increment if trial is in the first position
        seq = seq+1;
    elseif trl==1 && curTrlPos ~= 1                                         % Also increment if it's the first trial in the session but the position is not 1 (happens when first trial is curated out)
        seq = seq+1;
    elseif curTrlPos <= trialPosition{trl-1}                                % Only gets here if the first trial in a sequence was curated out 
        seq = seq+1;
    end
    % Identify temporal context feature
    if curTrlInSeqLog
        trialItmItmDist{trl} = 1;
        trialTransDist{trl} = 0;
    else
        trialTransDist{trl} = curTrlPos - curTrlOdor;
        trialItmItmDist{trl} = curTrlOdor - curTrlPos + 1;
    end
    seqNum{trl} = seq;
    
    % Create trial logical vector
    tempLogVect = false(size(behavMatrix,1),1);
    curPokeIn = pokeInNdxs(find(pokeInNdxs<trialIndices(trl)==1,1, 'last'));
    curPokeOut = pokeOutNdxs(find(pokeOutNdxs>trialIndices(trl)==1,1, 'first'));
    pokeDuration{trl} = (curPokeOut-curPokeIn)/sampleRate;
    
    trialPokeInNdx{trl} = curPokeIn;
    trialOdorNdx{trl} = trialIndices(trl);
    trialPokeOutNdx{trl} = curPokeOut;
    curFrontRwrdNdx = frontRwrdNdxs(find(frontRwrdNdxs>trialIndices(trl)==1,1, 'first'));
    if  isempty(curFrontRwrdNdx) || trl==numTrials || curFrontRwrdNdx<trialIndices(trl+1)
        trialRewardNdx{trl} = curFrontRwrdNdx;
    else
        trialRewardNdx{trl} = nan;
    end
    curErrSigNdx = errorSigNdxs(find(errorSigNdxs>trialIndices(trl)==1,1,'first'));
    if isempty(curErrSigNdx) || trl==numTrials || curErrSigNdx<trialIndices(trl+1)
        trialErrorNdx{trl} = curErrSigNdx;
    else
        trialErrorNdx{trl} = nan;
    end
    switch trialStart
        case 'Odor'
            curIndex = trialIndices(trl);
        case 'PokeIn'
            curIndex = curPokeIn;
        case 'PokeOut'
            curIndex = curPokeOut;
        case 'FrontReward'
            curIndex = trialRewardNdx{trl};
        case 'RearReward'
            curIndex = rearRwrdNdxs(find(rearRwrdNdxs>trialIndices(trl)==1,1,'first'));
            if  isempty(curIndex) || trl==numTrials || curIndex<trialIndices(trl+1)
            else
                curIndex = nan;
            end
        case 'ErrorSignal'
            curIndex = trialErrorNdx{trl};
    end
    if ~isnan(curIndex)
        curWindow = curIndex + trlWindow;
        tempLogVect(curWindow(1):curWindow(2)) = true;
    end
    trialLogVect{trl} = tempLogVect;
end

%% Create behavMatrixTrialStruct
behavMatrixTrialStruct = struct( 'TrialNum', trialNum, 'SequenceNum', seqNum,...
    'Odor', trialOdor, 'Position', trialPosition, 'PokeDuration', pokeDuration, 'Performance', trialPerf,...
    'PokeInIndex', trialPokeInNdx, 'OdorIndex', trialOdorNdx, 'PokeOutIndex', trialPokeOutNdx,...
    'RewardIndex', trialRewardNdx, 'ErrorIndex', trialErrorNdx,...
    'TranspositionDistance', trialTransDist, 'ItemItemDistance', trialItmItmDist,...
    'TrialLogVect', trialLogVect);
behavMatrixTrialStruct(1).SeqLength = seqLength;
    
    