
%% LSTM network applied on sequencies from NASA dataset
%% Data extraction
clc
clear all

load("B0005.mat");
load("B0006.mat");
load("B0007.mat");
load("B0018.mat");


[~, SoH5] = ExtractPartialCurve(B0005, 3.8, 0.1, 3.9);
[~, SoH6] = ExtractPartialCurve(B0006, 3.8, 0.1, 3.9);
[~, SoH7] = ExtractPartialCurve(B0007, 3.8, 0.1, 3.9);
[~, SoH18] = ExtractPartialCurve(B0018, 3.8, 0.1, 3.9);


nom_capacity5 = B0005.cycle(2).data.Capacity;
EoL_5 = find(SoH5./nom_capacity5<0.75,1);

nom_capacity6 = B0006.cycle(2).data.Capacity;
EoL_6 = find(SoH6./nom_capacity6<0.75,1);

nom_capacity7 = B0007.cycle(2).data.Capacity;
EoL_7 = find(SoH7./nom_capacity7<0.75,1);

nom_capacity18 = B0018.cycle(3).data.Capacity;
EoL_18 = find(SoH18./nom_capacity18<0.75,1);


SoH5(EoL_5:end) = [];
SoH6(EoL_6:end) = [];
SoH7(EoL_7:end) = [];
SoH18(EoL_18:end) = [];


N_cycle5 = 1:length(SoH5);
N_cycle6 = 1:length(SoH6);
N_cycle7 = 1:length(SoH7);
N_cycle18 = 1:length(SoH18);


RUL5 = flip(1:EoL_5-1);
RUL6 = flip(1:EoL_6-1);
RUL7 = flip(1:EoL_7-1);
RUL18 = flip(1:EoL_18-1);

%% Train raw and Test sets

net = load("net_B7_25U.mat");
net1 = net.net1;
net2 = net.net2;
net3 = net.net3;


%%
%Pick the battery to experiment on
N_cycle = N_cycle7;
SoH = SoH7;
nom_capacity = nom_capacity7;

XTrain = cell(3,1);
YTrain = cell(3,1);
XTest = cell(3,1);
YTest = cell(3,1);

XTrain{1} = N_cycle(1:80);
XTrain{2} = N_cycle(1:100);
XTrain{3} = N_cycle(1:120);

YTrain{1} = SoH(1:80);
YTrain{2} = SoH(1:100);
YTrain{3} = SoH(1:120);

XTest{1} = N_cycle(80:end);
XTest{2} = N_cycle(100:end);
XTest{3} = N_cycle(120:end);

YTest{1} = SoH(80:end);
YTest{2} = SoH(100:end);
YTest{3} = SoH(120:end);


%Single exp function

single_exp = fittype( @(a,b,x) nom_capacity + a.*exp(b./x));

%% Train single/double exp
XTrainSingle = cell(3,1);
XTrainDouble = cell(3,1);


%% Fittings

XTrainSingle{1} = fit(transpose(XTrain{1}), transpose(YTrain{1}), single_exp);
XTrainSingle{2} = fit(transpose(XTrain{2}), transpose(YTrain{2}), single_exp);
XTrainSingle{3} = fit(transpose(XTrain{3}), transpose(YTrain{3}), single_exp);

XTrainDouble{1} = fit(transpose(XTrain{1}), transpose(YTrain{1}), 'exp2');
XTrainDouble{2} = fit(transpose(XTrain{2}), transpose(YTrain{2}), 'exp2');
XTrainDouble{3} = fit(transpose(XTrain{3}), transpose(YTrain{3}), 'exp2');


%% Training options
rng(0);

maxEpochs = 4000; %5500;
miniBatchSize = 1;

options = trainingOptions('adam', ...
    'MaxEpochs',maxEpochs, ...
    'MiniBatchSize',miniBatchSize, ...
    'InitialLearnRate',0.1, ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',1200,...
    'LearnRateDropFactor',0.2,...
    'GradientThreshold',1, ...
    'Shuffle','never', ...
    'ValidationData', {N_cycle, SoH}, ...
    'ValidationPatience', 300, ...
    'ValidationFrequency',10, ...
    'Plots','training-progress',...
    'OutputNetwork','best-validation-loss',...
    'Verbose',1,...
    'VerboseFrequency', 100);


%% Network

miniBatchSize = 1;
numFeatures = 1;
numResponses = 1;
numHiddenUnits = 25;  % 50 good for k=80. 5 good for k=100  More than 50-100 units add bias to the prediction

%use 30, 25, 15, 12,4,2 or 50
layers = [ ...
    sequenceInputLayer(numFeatures)
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    fullyConnectedLayer(50)
    dropoutLayer(0.5)
    fullyConnectedLayer(numResponses)
    regressionLayer];

%analyzeNetwork(layers)


%% Training single

X = 80/100 : 80/100 : 80;
Y = transpose(XTrainSingle{1}(X));
%figure()
%plot(X, Y);
%hold

net1 = trainNetwork(X, Y ,layers,options);

X = 1 : 1 : 100;
Y = transpose(XTrainSingle{2}(X));

%plot(X, Y);
net2 = trainNetwork(X, Y,layers,options);

X = 120/100 : 120/100 : 120;
Y = transpose(XTrainSingle{3}(X));

%plot(X, Y);
net3 = trainNetwork(X, Y,layers,options);




%% Training raw
%{
net1 = trainNetwork(XTrain{1},YTrain{1},layers,options);
net2 = trainNetwork(XTrain{2},YTrain{2},layers,options);
net3 = trainNetwork(XTrain{3},YTrain{3},layers,options);
%}


%% Training double
%{
X = 80/100 : 80/100 : 80;
Y = transpose(XTrainDouble{1}(X));
figure()
plot(X, Y);
hold
net1 = trainNetwork(X, Y ,layers,options);

X = 1 : 1 : 100;
Y = transpose(XTrainDouble{2}(X));
plot(X, Y);
net2 = trainNetwork(X, Y,layers,options);

X = 120/100 : 120/100 : 120;
Y = transpose(XTrainDouble{3}(X));
plot(X, Y);
net3 = trainNetwork(X, Y,layers,options);
%}
%% Test the network

%predictions of last portion only
YPred1 = predict(net1,XTest{1},'MiniBatchSize',1);
YPred2 = predict(net2,XTest{2},'MiniBatchSize',1);
YPred3 = predict(net3,XTest{3},'MiniBatchSize',1);

%predictions of all curve
YPredFull1 = predict(net1,N_cycle,'MiniBatchSize',1);
YPredFull2 = predict(net2,N_cycle,'MiniBatchSize',1);
YPredFull3 = predict(net3,N_cycle,'MiniBatchSize',1);


%% Compute RUL  and RUL error
%errors good 1 2 0
%errors bad 20 - 5

FTH_7 = 1.475;

error_1 = abs(find(SoH7<FTH_7,1) - find(YPredFull1<FTH_7,1))
error_2 = abs(find(SoH7<FTH_7,1) - find(YPredFull2<FTH_7,1))
error_3 = abs(find(SoH7<FTH_7,1) - find(YPredFull3<FTH_7,1))


%% Visualize predictions

figure
plot(N_cycle, SoH,'--')
hold on
ylim([1.35 1.95])
%plot(XTest{1}, YPred1,'.-')
col=hsv(20);
plot(N_cycle, YPredFull1, '.-', 'Color',col(1,:))
plot(N_cycle, YPredFull2, '.-', 'Color',col(2,:))
plot(N_cycle, YPredFull3, '.-', 'Color',col(3,:))
yline(1.475, '--', 'Color','red', 'Label', "EoL")
xline(80, '-', 'Color',col(1,:), 'LineWidth',1.5, 'Label', "K = "+ num2str(80), 'DisplayName', "K = "+ num2str(80));
xline(100, '-', 'Color',col(2,:), 'LineWidth',1.5, 'Label', "K = "+ num2str(100), 'DisplayName', "K = "+ num2str(100));
xline(120, '-', 'Color',col(3,:), 'LineWidth',1.5, 'Label', "K = "+ num2str(120), 'DisplayName', "K = "+ num2str(120));
hold off
%title("Battery 7, single exponential ")
xlabel("Cycles", "FontSize",20)
ylabel("Capacity", "FontSize",20)
legend(["Test Data" "Predicted 80" "Predicted 100" "Predicted 120"],'Location','southwest', FontSize=15)
%legend(["Test Data" "Predicted partial" "Predicted full"],'Location','southwest')

%{
figure
plot(N_cycle5, SoH5,'--')
hold on
ylim([1.35 1.95])
%plot(XTest{2}, YPred2,'.-')
plot(N_cycle5, YPredFull2, '.-')
xline(100, '-', 'LineWidth',1.5, 'Label', "K = "+ num2str(100), 'DisplayName', "K = "+ num2str(100));
hold off
title("Test Observation 100 prediction cycle ")
xlabel("Time Step")
ylabel("SoH")
legend(["Test Data" "Predicted partial" "Predicted full"],'Location','southwest')

figure

plot(N_cycle5, SoH5,'--')
hold on
ylim([1.35 1.95])
%plot(XTest{3}, YPred3,'.-')
plot(N_cycle5, YPredFull3, '.-')
xline(120, '-', 'LineWidth',1.5, 'Label', "K = "+ num2str(120), 'DisplayName', "K = "+ num2str(120));
hold off
title("Test Observation 120 prediction cycle ")
xlabel("Time Step")
ylabel("SoH")
legend(["Test Data" "Predicted partial" "Predicted full"],'Location','southwest')
%}





%% RMSE of predictions


%{
for i = 1:numel(YTest)
    YTestLast(i) = YTest{i}(end);
    YPredLast(i) = YPred{i}(end);
end
figure
rmse = sqrt(mean((YPredLast - YTestLast).^2))
histogram(YPredLast - YTestLast)
title("RMSE = " + rmse)
ylabel("Frequency")
xlabel("Error")

%}

%save('net_B7_25U', 'net1','net2','net3');
