function preProcessND2(inputFile, outputFolder, options)
% PREPROCESSND2 Load .nd2 microscope images, apply binning,
% Gaussian background subtraction, and save as BigTIFF.
%
% This function reads a specified series and channel from an ND2 file,
% performs optional spatial binning, subtracts a smoothed background,
% and exports the processed data as a BigTIFF stack.
%
% INPUT:
%
% Required:
%   fileIn: (string | char)
%       Full path to the input ND2 file.
%
%   outputFolder: (string | char)
%       Directory where processed TIFF files will be saved.
%
% Optional:
%   options
%
%       SeriesIndex: (double, default: 1)
%           Series index to process (1-based).
%
%       ChannelIndex: (double, default: 1)
%           Channel index to process (1-based).
%
%       BinSize: (double, default: 1)
%           Spatial binning factor.
%
%       GaussianSigma: (1x3 double, default: [21 21 9])
%           Sigma for 3D Gaussian background subtraction.
%
%       Logs: (logical, default: true)
%           Print progress messages to console.
%
% OUTPUT:
%   Saves processed TIFF files to outputFolder.

    arguments
        inputFile (1,1) string
        outputFolder (1,1) string
        options.SeriesIndex (1,1) double = 1
        options.ChannelIndex (1,1) double = 1
        options.BinSize (1,1) double = 1
        options.GaussianSigma (1,3) double = [21 21 9]
        options.Logs (1,1) logical = true
    end

    if ~isfile(inputFile)
        error('preProcessND2:fileNotFound', ...
            'Input file not found:\n%s', inputFile);
    end

    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    %% Initialize Bio-Formats reader
    try
        inputFile = char(inputFile);
        reader = bfGetReader(inputFile);
    catch ME
        error('preProcessND2:readerInitFailed', ...
            'Failed to initialize Bio-Formats reader:\n%s', ME.message);
    end

    nSeries = reader.getSeriesCount;

    if options.SeriesIndex > nSeries
        error('preProcessND2:seriesOutOfBounds', ...
            'Selected series index (%d) exceeds available series (%d).', ...
            options.SeriesIndex, nSeries);
    end

    reader.setSeries(options.SeriesIndex - 1);

    %% Extract dimensions
    nC = reader.getSizeC;
    nT = reader.getSizeT;
    nZ = reader.getSizeZ;
    sizeX = reader.getSizeX;
    sizeY = reader.getSizeY;

    if options.ChannelIndex > nC
        error('preProcessND2:invalidChannel', ...
            'Selected channel index (%d) exceeds available channels (%d).', ...
            options.ChannelIndex, nC);
    end

    binSize = options.BinSize;
    sizeXBin = floor(sizeX / binSize);
    sizeYBin = floor(sizeY / binSize);

    if options.Logs
        fprintf('Processing Series %d | Channel %d\n', ...
            options.SeriesIndex, options.ChannelIndex);
        fprintf('Dimensions: %dT x %dZ x %dC | %dx%d px\n', ...
            nT, nZ, nC, sizeX, sizeY);
    end

    %% Load data
    tLoad = tic;

    img = zeros(sizeXBin, sizeYBin, nZ, nT, 'uint16');

    for iT = 1:nT
        if options.Logs
            fprintf('  Loading T=%d/%d\n', iT, nT);
        end

        for iZ = 1:nZ
            planeIndex = reader.getIndex(iZ-1, options.ChannelIndex-1, iT-1) + 1;

            try
                tmpIn = bfGetPlane(reader, planeIndex);
            catch ME
                error('preProcessND2:readError', ...
                    'Error reading plane (T=%d, Z=%d): %s', ...
                    iT, iZ, ME.message);
            end

            % Crop to bin-compatible size
            cropY = floor(size(tmpIn, 1) / binSize) * binSize;
            cropX = floor(size(tmpIn, 2) / binSize) * binSize;
            tmpIn = tmpIn(1:cropY, 1:cropX);

            % Binning
            tmpIn = reshape(tmpIn, binSize, cropY/binSize, ...
                                     binSize, cropX/binSize);
            tmpIn = sum(sum(tmpIn, 1), 3);
            tmpIn = squeeze(tmpIn);
            tmpIn = permute(tmpIn, [2 1]);

            img(:,:,iZ,iT) = uint16(tmpIn);
        end
    end

    if options.Logs
        fprintf('Data loading completed in %.2f seconds\n', toc(tLoad));
    end

    %% Background subtraction
    tBG = tic;

    if options.Logs
        fprintf('Applying Gaussian background subtraction...\n');
    end

    bgImg = zeros(size(img), 'uint16');

    parfor iT = 1:nT
        bgImg(:,:,:,iT) = imgaussfilt3(img(:,:,:,iT), options.GaussianSigma);
    end

    img = img - bgImg;

    if options.Logs
        fprintf('Background subtraction completed in %.2f seconds\n', toc(tBG));
    end

    %% Final formatting (X,Y,Z,C,T)
    M_final = uint16(permute(img, [1, 2, 3, 5, 4]));

    if options.Logs
        fprintf('Saving processed file...\n');
    end

    %% Save output
    outFile = fullfile(outputFolder, ...
        sprintf('Processed_S%d_C%d.tif', ...
        options.SeriesIndex, options.ChannelIndex));

    tSave = tic;

    try
        outFile = char(outFile);
        bfsave(M_final, outFile, 'BigTiff', true);
    catch ME
        error('preProcessND2:saveError', ...
            'Failed to save output file:\n%s\nReason: %s', ...
            outFile, ME.message);
    end

    if options.Logs
        fprintf('Saved file:\n  %s\n', outFile);
        fprintf('Saving completed in %.2f seconds\n', toc(tSave));
    end

    %% Cleanup
    reader.close();

    if options.Logs
        fprintf('Processing complete.\n');
    end
    
end
