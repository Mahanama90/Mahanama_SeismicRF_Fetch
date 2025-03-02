
% Clear workspace
clear; clc; close all;

eventFile = '/FOLDER_PATH/Event_RF.txt'; % Earthquake events
stationFile = '/FOLDER_PATH/T_Station.txt'; % Station info

% **READ EARTHQUAKE DATA**

eventData = readmatrix(eventFile, 'Delimiter', '|', 'NumHeaderLines', 1);

% Extract relevant columns for earthquake events
eventLat = eventData(:, 3);    % Latitude
eventLon = eventData(:, 4);    % Longitude
eventDepth = eventData(:, 5);  % Depth (km)
eventMag = eventData(:, 11);   % Magnitude

% **READ STATION DATA**

stationData = readmatrix(stationFile, 'Delimiter', '|', 'NumHeaderLines', 1, 'OutputType', 'string');

% Extract relevant columns for station plotting
network = stationData(:, 1);  % Network
station = stationData(:, 2);  % Station Name
stationLat = str2double(stationData(:, 3)); % Convert to double
stationLon = str2double(stationData(:, 4)); % Convert to double

% **PLOT THE MAP WITH A TRUE TOP-DOWN VIEW FROM THE STATION (FINAL VERSION)**
figure;
hold on;

% Set up **Azimuthal Equidistant Projection** to prevent distortion
ax = axesm('eqaazim', 'Frame', 'off', 'Grid', 'off', ... % Frame is off for a clean look
           'Origin', [stationLat, stationLon, 0], ... % Center at the station
           'FLatLimit', [0 180]); % Display full 180° without shrinking everything

% Load and plot coastlines
load coastlines;
plotm(coastlat, coastlon, 'Color', [0.2 0.2 0.2]); % Darker gray coastlines

% **Custom Brown Colormap for Depth (Light to Dark Brown)**
custom_brown_colormap = [...
    0.9  0.7  0.5;  % Light tan (shallow)
    0.8  0.6  0.4;  
    0.7  0.5  0.3;  
    0.6  0.4  0.2;  
    0.5  0.3  0.1;  
    0.4  0.2  0.05; % Dark brown (deep)
];
colormap(custom_brown_colormap);

% **Fix Earthquake Event Projection Issues**
validEvents = ~isnan(eventLat) & ~isnan(eventLon); % Remove NaN values
markerSize = ((eventMag - min(eventMag) + 1) .^ 3) * 10; % Exponential scaling
scatterm(eventLat(validEvents), eventLon(validEvents), markerSize(validEvents), eventDepth(validEvents), ...
         'filled', 'MarkerFaceAlpha', 0.8, 'MarkerEdgeColor', 'k');

% **Apply the same colormap to the colorbar**
c = colorbar('eastoutside');
caxis([min(eventDepth) max(eventDepth)]);
ylabel(c, 'Depth (km)','FontSize', 12, 'FontWeight', 'bold');

% **Plot station location as a red triangle**
scatterm(stationLat, stationLon, 50, 'r', '^', 'filled');

% **Label the station**
textm(stationLat + 2, stationLon, 'WVT', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');

% Labels and title
title('Global Teleseismic Events for RF analysis');

% **Ensure Radial Circles Are Properly Displayed**
radial_degrees = 10:30:180; % Define distances at 30° intervals
for i = 2:length(radial_degrees) % Start from 2 to avoid 0° (center)
    [circleLat, circleLon] = scircle1(stationLat, stationLon, radial_degrees(i)); % Compute circle
    linem(circleLat, circleLon, 'k', 'LineWidth', 1); % Plot solid circle lines
end

% **Ensure Longitude (Meridian) Lines Radiate Correctly**
setm(ax, 'MLabelLocation', 30, 'MLineLocation', 30, 'GLineWidth', 1);

% **Ensure Equally Spaced Radial Distance Grid**
setm(ax, 'PLabelLocation', 30, 'PLineLocation', 30, 'GLineStyle', '-'); % Set 30° spacing

% Adjust axis appearance for circular display
set(gca, 'XColor', 'none', 'YColor', 'none'); % Remove axis labels
axis off; % Remove the bounding box

% **Magnitude Legend (on the left side)**
pos = get(ax, 'Position');
minMag = min(eventMag);
maxMag = max(eventMag);
legend_sizes = linspace(minMag, maxMag, 6); % Magnitude scale
legend_markers = ((legend_sizes - minMag + 1) .^ 3) * 10; % Apply same scaling

legend_ax = axes('Position', [pos(1) - 0.1, pos(2) + 0.6, 0.15, 0.15]); 
hold(legend_ax, 'on');

legend_y_positions = linspace(1, 3, 6);  
scatter(legend_ax, ones(1, 6), legend_y_positions, legend_markers, 'k', 'filled');

text(ones(1, 6) + 0.3, legend_y_positions, arrayfun(@(x) sprintf('M %.1f', x), legend_sizes, 'UniformOutput', false), ...
    'FontSize', 10, 'HorizontalAlignment', 'left');

axis(legend_ax, 'off');
text(1, max(legend_y_positions) + 0.6, 'Magnitude', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% **Add Event and Station Count as Annotations**
numEvents = length(eventLat(validEvents));
numStations = length(stationLat);
annotation('textbox', [0.16, 0.82, 0.1, 0.1], 'String', ...
    sprintf('Events: %d\nStations: %d', numEvents, numStations), ...
    'FontSize', 12, 'FontWeight', 'bold', 'EdgeColor', 'none', 'BackgroundColor', 'w');

% Display event count
disp(['Plotted ', num2str(numEvents), ' events.']);
disp(['Plotted ', num2str(numStations), ' stations.']);

set(gcf, 'Color', 'w');  
hold off;