clc;
clear all;

% MQTT parameters
brokerAddress = 'ws://broker.hivemq.com';
port = 8000;
Publisher_topic = "NRC/Topic_1";
Subscriber_topic = "NRC/topic_2";
username = "MatlabClient";
password = "NeuroRoboControl_2";

% Create MQTT client
mqttClient = mqttclient(brokerAddress, 'ClientID', 'MatlabClient', 'Port', port, 'Username', username, 'Password', password);
a = arduino('COM2', 'Uno');

% Create figure for real-time plotting
figure;

% Initialize empty arrays for storing data
FrontElectrode_data_raw = [];
CentreElectrode_data_raw = [];
RightElectrode_data_raw = [];
LeftElectode_data_raw = [];

% Initialize filter states
z1_1 = 0; z2_1 = 0;
z1_2 = 0; z2_2 = 0;
z1_3 = 0; z2_3 = 0;
z1_4 = 0; z2_4 = 0;

% Create and configure real-time plot
h = plot(0, 0, 'r', 0, 0, 'g', 0, 0, 'b', 0, 0, 'm');
xlabel('Time');
ylabel('Sensor Value');
legend('FrontElectrode(Raw)', 'CentreElectrode(Raw)', 'RightElectrode(Raw)', 'LeftElectode(Raw)');
title('Real-time Sensor Data');

% Create a function to filter out the EEG Signal from environmental Noise
function [EEGSignal, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4] = EnvironmentalNoiseReduction(output, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4)
    % Calculate filter coefficients
    b0_1 = 0.00735282; b1_1 = 0.01470564; b2_1 = 0.00735282;
    a1_1 = -0.95391350; a2_1 = 0.25311356;

    b0_2 = 1.00000000; b1_2 = 2.00000000; b2_2 = 1.00000000;
    a1_2 = -1.20596630; a2_2 = 0.60558332;

    b0_3 = 1.00000000; b1_3 = -2.00000000; b2_3 = 1.00000000;
    a1_3 = -1.97690645; a2_3 = 0.97706395;

    b0_4 = 1.00000000; b1_4 = -2.00000000; b2_4 = 1.00000000;
    a1_4 = -1.99071687; a2_4 = 0.99086813;

    % First filter section
    x = output - a1_1 * z1_1 - a2_1 * z2_1;
    output = b0_1 * x + b1_1 * z1_1 + b2_1 * z2_1;
    z2_1 = z1_1;
    z1_1 = x;

    % Second filter section
    x = output - a1_2 * z1_2 - a2_2 * z2_2;
    output = b0_2 * x + b1_2 * z1_2 + b2_2 * z2_2;
    z2_2 = z1_2;
    z1_2 = x;

    % Third filter section
    x = output - a1_3 * z1_3 - a2_3 * z2_3;
    output = b0_3 * x + b1_3 * z1_3 + b2_3 * z2_3;
    z2_3 = z1_3;
    z1_3 = x;

    % Fourth filter section
    x = output - a1_4 * z1_4 - a2_4 * z2_4;
    output = b0_4 * x + b1_4 * z1_4 + b2_4 * z2_4;
    z2_4 = z1_4;
    z1_4 = x;

    EEGSignal = output;
end

while 1
    % Read raw data from electrodes
    FrontElectrode_raw = readVoltage(a, 'A1');
    CentreElectrode_raw = readVoltage(a, 'A0');
    RightElectrode_raw = readVoltage(a, 'A3');
    LeftElectode_raw = readVoltage(a, 'A2');

    % Filter raw data
    [FrontElectrode_No_Noise, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4] = EnvironmentalNoiseReduction(FrontElectrode_raw, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4);
    [CentreElectrode_No_Noise, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4] = EnvironmentalNoiseReduction(CentreElectrode_raw, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4);
    [RightElectrode_No_Noise, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4] = EnvironmentalNoiseReduction(RightElectrode_raw, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4);
    [LeftElectode_No_Noise, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4] = EnvironmentalNoiseReduction(LeftElectode_raw, z1_1, z2_1, z1_2, z2_2, z1_3, z2_3, z1_4, z2_4);

    % Send EEG data to MQTT Topic1
    eeg_data = struct('FrontElectrode', FrontElectrode_No_Noise, 'CentreElectrode', CentreElectrode_No_Noise, 'RightElectrode', RightElectrode_No_Noise, 'LeftElectode', LeftElectode_No_Noise);
    write(mqttClient, Publisher_topic, jsonencode(eeg_data));

    % Update data arrays for raw data
    FrontElectrode_data_raw = [FrontElectrode_data_raw, FrontElectrode_raw];
    CentreElectrode_data_raw = [CentreElectrode_data_raw, CentreElectrode_raw];
    RightElectrode_data_raw = [RightElectrode_data_raw, RightElectrode_raw];
    LeftElectode_data_raw = [LeftElectode_data_raw, LeftElectode_raw];

    % Update plot for raw data
    set(h(1), 'YData', FrontElectrode_data_raw, 'XData', 1:length(FrontElectrode_data_raw));
    set(h(2), 'YData', CentreElectrode_data_raw, 'XData', 1:length(CentreElectrode_data_raw));
    set(h(3), 'YData', RightElectrode_data_raw, 'XData', 1:length(RightElectrode_data_raw));
    set(h(4), 'YData', LeftElectode_data_raw, 'XData', 1:length(LeftElectode_data_raw));

    drawnow;
end
