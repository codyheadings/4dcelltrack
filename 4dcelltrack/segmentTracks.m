function tracks = segmentTracks(data)
% SEGMENTTRACKS Split a tracking table (X Y Z T) into a cell array of 
% individual track tables. A new track begins each time the T column 
% resets to 0.

    if ~istable(data) || ~ismember('T', data.Properties.VariableNames)
        error('segmentTracks:invalidInput', ...
            'Input must be a table with a column named "T".');
    end

    % Find track boundaries
    cellStarts = find(data.T == 0);
    cellStarts = [cellStarts; height(data) + 1];

    nTracks = numel(cellStarts) - 1;
    tracks = cell(nTracks, 1);

    for i = 1:nTracks
        idx = cellStarts(i):(cellStarts(i+1)-1);
        tracks{i} = data(idx, :);
    end
end
