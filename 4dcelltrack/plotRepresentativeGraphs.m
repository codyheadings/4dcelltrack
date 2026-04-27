function [fig1, fig2] = plotRepresentativeGraphs(inputFile, outputFolder, numTracks, offset, options)
% PLOREPRESENTATIVEGRAPHS Plot 3D displacement graphs for n cell tracks.
%
% INPUT:
%
% Required:
%   inputFile: (char | string)
%       Path to the AggregatedCSVResults.xlsx produced by 
%       aggregateTrackingResults.
%
% Optional:
%   outputFolder: (char | string, default = "" (no files written))
%       Directory where output files are saved. Created automatically 
%       if it does not exist.
%
%   numTracks: (double, default: 8)
%       Number of representative tracks to be plotted on 3D temporal 
%           graphs.
%
%   offset: (double, default: 0)
%       Numerical offset from middle index of sorted cell tracks.
%
%   options
%
%       FileType: (char | string, default = ".fig")
%           File extension of saved figures. Defaults to .fig.
%
%       ShowAxes: (logical, default: true)
%           Output graphs have axes titles.
%   
%       ShowTitle: (logical, default: true)
%           Output graphs have titles.
%
%       TimeScale: (double, default = 1)
%           Scale for colorbar. Defaults to no time scaling. If input time
%           values represent minutes, a TimeScale value of 60 would convert
%           to hours.
%   
%       SpaceUnit: (char | string, default = "μm")
%           Units used in axis titles.
%
%       TimeUnit: (char | string, default = "min")
%           Units used in colorbar title.
%
%       Logs: (logical, default: true)
%           Print progress messages to the command window.
%
% OUTPUT:
%
%   2 MATLAB figures, 1 for cumulative displacement over time, and 1 for
%   vector start-to-end displacement. These are saved as .fig files if an
%   output folder is provided.

    arguments
        inputFile (1,1) string
        outputFolder (1,1) string = ""
        numTracks (1,1) double = 8
        offset (1,1) double = 0
        options.FileType (1,1) string = ".fig"
        options.ShowAxes (1,1) logical = true
        options.ShowTitle (1,1) logical = true
        options.TimeScale (1,1) double = 1
        options.SpaceUnit (1,1) string = "μm"
        options.TimeUnit (1,1) string = "min"
        options.Logs (1,1) logical = true
    end

    if ~isfile(inputFile)
        error('plotRepresentativeTracks:fileNotFound', ...
            'Input file not found:\n%s', inputFile);
    end

    if numTracks <= 0
        error('plotRepresentativeTracks:noPlottedTracks', ...
                'numTracks must be greater than 0.');
    end

    if options.TimeScale <= 0
        error('plotRepresentativeTracks:invalidTimeScale', ...
                'options.TimeScale must be greater than 0.');
    end

    allTracks = segmentTracks(readtable(inputFile));

    if numTracks > length(allTracks)
        warning('plotRepresentativeTracks:tooManyTracks', ...
            'Selected %d tracks, but only %d available. Using all tracks.', ...
            numTracks, length(allTracks));
        numTracks = length(allTracks);
    end

    if abs(offset) > length(allTracks)
        error('plotRepresentativeTracks:offsetOutOfBounds', ...
                'Your index offset cannot be greater than the total number of tracks.');
    end

    %% Compute total track length and sort

    trackLengths = zeros(length(allTracks), 1);
    for k = 1:length(allTracks)
        track = allTracks{k};
        dx = diff(track.X);
        dy = diff(track.Y);
        dz = diff(track.Z);
        trackLengths(k) = sum(sqrt(dx.^2 + dy.^2 + dz.^2));
    end

    [sortedLengths, sortIdx] = sort(trackLengths);
    sortedTracks = allTracks(sortIdx);

    %% Select representative tracks from middle of list

    nSelect = numTracks;
    nTotal = length(sortedTracks);
    nOffset = offset;
    startIdx = round(nTotal / 2) + nOffset;
    halfSpan = floor(nSelect / 2);
    selectedIdx = (startIdx - halfSpan) : (startIdx - halfSpan + nSelect - 1);
    selectedIdx = max(1, min(selectedIdx, nTotal));  % Clamp to valid range
    selectedTracks = sortedTracks(selectedIdx);

    if options.Logs
        fprintf('Total cell tracks: %s\n', num2str(nTotal));
        fprintf('Selected track indices (from sorted order): %s\n', num2str(selectedIdx));
        fprintf('Corresponding total path lengths: %s\n', num2str(sortedLengths(selectedIdx)'));
    end

    %% Plot selected tracks in 3D

    % Get global time max across selected tracks for colorbar
    maxT = 0;
    for k = 1:nSelect
        track = selectedTracks{k};
        maxT = max(maxT, max(track.T / options.TimeScale));
    end

    fig1 = figure();
    colormap(jet)
    hold on
    for k = 1:nSelect
        track = selectedTracks{k};
        trackX = track.X - track.X(1);
        trackY = track.Y - track.Y(1);
        trackZ = track.Z - track.Z(1);
        trackT = track.T / options.TimeScale;

        patch([trackX' nan], [trackY' nan], [trackZ' nan], [trackT' nan], ...
              'FaceColor', 'none', 'EdgeColor', 'interp', 'LineWidth', 2);
    end
    clim([0 maxT]);
    ticks = linspace(0, maxT, 5);
    cb = colorbar('Ticks', ticks);
    cb.TickLabels = compose('%.2f', ticks);
    ylabel(cb, 'Time (' + options.TimeUnit + ')');

    % Add axis labels and title (or don't)
    if options.ShowAxes
        xTitle = "Displacement in X (" + options.SpaceUnit + ")";
        yTitle = "Displacement in Y (" + options.SpaceUnit + ")";
        zTitle = "Displacement in Z (" + options.SpaceUnit + ")";
    else
        xTitle = ""; yTitle = ""; zTitle = "";
    end
    
    if options.ShowTitle
        graphTitle = "Cumulative Displacement in 3D";
    else
        graphTitle = "";
    end

    xlabel(xTitle);
    ylabel(yTitle);
    zlabel(zTitle);
    title(graphTitle);

    set(gca, 'Zdir', 'reverse')
    view(3)
    set(gcf, 'color', 'w');
    grid on;
    hold off;
    
    if outputFolder ~= ""
        if ~isfolder(outputFolder)
            mkdir(outputFolder);
        end

        outputPath = fullfile(outputFolder, 'CumulativeDisplacement3D' + options.FileType);
        saveas(fig1, outputPath)

        if options.Logs
            fprintf('\nSaved Cumulative Displacement Graph to:\n  %s\n', outputPath);
        end
    end

    fig2 = figure();
    colormap(jet);
    hold on;

    for k = 1:nSelect
        track = selectedTracks{k};

        % Compute relative displacement (start to end)
        startX = track.X(1);
        endX = track.X(end);
        startY = track.Y(1);
        endY = track.Y(end);
        startZ = track.Z(1);
        endZ = track.Z(end);

        % Compute relative displacement values
        track2X = [startX, endX] - startX; % Start to end relative X
        track2Y = [startY, endY] - startY; % Start to end relative Y
        track2Z = [startZ, endZ] - startZ; % Start to end relative Z

        % Plot the straight line in 3D space
        line(track2X, track2Y, track2Z, 'Color', [0 0.5 1], 'LineWidth', 2); % Use a solid color for clarity
        scatter3(track2X(2), track2Y(2), track2Z(2), 50, 'filled', 'MarkerFaceColor', [0.8, 0, 0]); % Mark the end point
    end

    % Add axis labels and title (or don't)
    if options.ShowTitle
        graphTitle = "Net Displacement Vectors in 3D";
    else
        graphTitle = "";
    end

    xlabel(xTitle);
    ylabel(yTitle);
    zlabel(zTitle);
    title(graphTitle);

    % Adjust view and other plot settings
    set(gca, 'Zdir', 'reverse');
    view(3);
    set(gcf, 'color', 'w');
    grid on;
    hold off;

    if outputFolder ~= ""
        if ~isfolder(outputFolder)
            mkdir(outputFolder);
        end

        outputPath = fullfile(outputFolder, 'VectorDisplacement3D' + options.FileType);
        saveas(fig2, outputPath)

        if options.Logs
            fprintf('\nSaved Vector Displacement Graph to:\n  %s\n', outputPath);
        end
    end
end
