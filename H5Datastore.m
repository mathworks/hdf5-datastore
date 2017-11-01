classdef H5Datastore < matlab.io.Datastore %& matlab.io.datastore.Partitionable
    % H5Datastore - datastore for HDF5 format
    % ---------------------------------------------------------------------
    % Abstract: This object provides a datastore interface for data files
    % stored in HDF5 format.
    %
    % Syntax:
    %           obj = H5Datastore(rootDir)
    %
    % Constructor Inputs:
    %
    %     rootDir - the root folder path in which to search for H5 files
    %
    %
    % Example:
    %   
    %     %% Create a datastore
    %     ds = H5Datastore(pwd);
    %
    %     %% Choose variables
    %     ds.SelectedVariableNames = ({'Data1','Data2'});
    %
    %     %% Read Data
    %     [data, info] = ds.read();
    %
    % Notes:
    %   - Writing to HDF5 files is not currently supported in this
    %   datastore
    %
    %   - This initial version is does not yet support Partitionable
    
    % Copyright 2015-2017 The MathWorks, Inc.
    %
    % Auth/Revision:
    %   MathWorks Consulting
    %   $Author: rjackey $
    %   $Revision: 1769 $  $Date: 2017-11-01 10:09:26 -0400 (Wed, 01 Nov 2017) $
    % ---------------------------------------------------------------------
    
    %% Properties   
    properties (SetAccess=protected)
        Decimation uint32 = 1 %decimation to use in reading the data (1 = all data)
        H5Info table %table of H5 file information
        H5Datasets table %table of H5 dataset information
    end
    
    properties (Dependent, SetAccess=protected)
        VariableNames %available variables to read
    end
    
    properties
        SelectedVariableNames cell %VariableNames selected to read
    end
    
    properties (Access=protected)
        FileSet matlab.io.datastore.DsFileSet
        CurrentFileIndex uint32
        RootDir char
        ReadVarsIdx uint32
    end
    
    
    
    %% Constructor / Destructor
    methods
        function obj = H5Datastore(rootDir)
            
            % Use current directory if unspecified
            if nargin<1
                rootDir = pwd;
            end
            obj.RootDir = rootDir;
            
            obj.FileSet = matlab.io.datastore.DsFileSet(rootDir, ...
                'IncludeSubfolders', true, ...
                'FileExtensions', '.h5', ...
                'FileSplitSize', 8e9);
            
            obj.readFileInfo();
            
            % Default to read all variables
            obj.SelectedVariableNames = obj.VariableNames;
            
            % Reset to the first file
            obj.reset();
            
        end %function
    end %% Constructor / Destructor
    
    
    
    %% Public Methods
    methods
        
        function tf = hasdata(obj)
            % Returns true if more data is available.
            tf = hasfile(obj.FileSet);
        end
        
        function [data, info] = read(obj)
            
            % Get the files to read
            fileInfo = nextfile(obj.FileSet);
            filePath = char(fileInfo.FileName);
            
            % The datasets that will be read
            dsToRead = obj.H5Datasets(obj.ReadVarsIdx,:);
            
            % Calculate start location and size to read in this split
            bytesPerRow = prod(dsToRead.BytesPerRow);
            offset = fileInfo.Offset;
            splitSize = fileInfo.SplitSize;
            numRowsToRead = ceil(splitSize/bytesPerRow);
            startRow = offset/bytesPerRow + 1;
            
            % Track where we got to the end
            atEndOfVar = false(height(dsToRead),1);
            
            % Loop on each variable that must be read
            for idx=1:height(dsToRead)
                
                % Get info on this variable
                thisDs = dsToRead(idx,:);
                varName = thisDs.Name{:};
                varPath = thisDs.Path{:};
                varSize = thisDs.Size{:};
                thisNumRows = varSize(1);
                if numRowsToRead <= (thisNumRows-startRow)
                    numRowsToRead = (thisNumRows-startRow);
                    atEndOfVar(idx) = true;
                end
                thisRowsToRead = min(varSize(1), numRowsToRead);
                
                % Calculate indices and size to read
                startIdx = [startRow ones(1,numel(varSize)-1)];
                dataSize = [thisRowsToRead varSize(2:end)];
                decimation = [double(obj.Decimation) ones(1,numel(varSize)-1)];
                
                % Read the data
                data.(varName) = h5read(filePath, varPath, ...
                    startIdx, dataSize, decimation);
                
            end %for idx=1:height(dsToRead)
            
            % Increment file counter if we hit the end
            if all(atEndOfVar)
                obj.CurrentFileIndex = obj.CurrentFileIndex + 1;
            end
            
            % Output: info
            info = dsToRead;
            
        end
        
        
        
        function reset(obj)
            % Reset to the first file in the set
            obj.FileSet.reset();
            obj.CurrentFileIndex = 1;
        end
        
        function frac = progress(obj)
            frac = (obj.CurrentFileIndex-1)/obj.FileSet.NumFiles;
        end
        
    end %Public methods
    
    
    
    
    %% Private methods
    methods (Access=private)
        
        function readFileInfo(obj)
            
            % Gather file info
            fileInfo = obj.FileSet.resolve();
            for fIdx = height(fileInfo):-1:1
                thisFilePath = char(fileInfo.FileName(fIdx));
                thisInfo(fIdx) = h5info(thisFilePath);
            end %while
            obj.H5Info = struct2table(thisInfo);
            
            % Gather the Dataset info from the first file
            if ~isempty(obj.H5Info)
                
                t = table;
                thisDatasets = thisInfo(1).Datasets;
                thisNames = {thisDatasets.Name}';
                thisDataType = [thisDatasets.Datatype];
                thisDataSpace = [thisDatasets.Dataspace];
                
                % Base properties
                t.Name = thisNames;
                %t.Name = {thisDatasets.Name}';
                t.Path = strcat('/', thisNames);
                
                % Datatype properties
                t.DataTypeName = {thisDataType.Name}';
                t.DataTypeClass = {thisDataType.Class}';
                t.DataTypeType = {thisDataType.Type}';
                t.DataTypeSize = [thisDataType.Size]';
                t.DataTypeAttributes = {thisDataType.Attributes}';
                
                % Dataspace properties
                t.Size = {thisDataSpace.Size}';
                t.MaxSize = {thisDataSpace.MaxSize}';
                t.DataSpaceType = {thisDataSpace.Type}';
                
                % More base properties
                t.ChunkSize = {thisDatasets.ChunkSize}';
                t.FillValue = {thisDatasets.FillValue}';
                t.Filters = {thisDatasets.Filters}';
                t.Attributes = {thisDatasets.Attributes}';
                
                % Calculate the bytes per row
                for rIdx = 1:height(t)
                    thisSize = t.Size{rIdx};
                    elemPerRow = prod(thisSize(2:end));
                    if isempty(elemPerRow)
                        t.BytesPerRow(rIdx) = 0;
                    else
                        t.BytesPerRow(rIdx) = elemPerRow * t.DataTypeSize(rIdx);
                    end
                end %for rIdx = 1:height(t)
                
                % Store the table
                obj.H5Datasets = t;
                
            end %if ~isempty(obj.H5Info)
            
            
            % Validate the remaining files match
            for rIdx = 2:numel(thisInfo)
                
                % What is in this file?
                thisDatasets = thisInfo(rIdx).Datasets;
                thisNames = {thisDatasets.Name}';
                
                % Does each variable from file 1 exist in this additional
                % file?
                hasVar = contains(t.Name, thisNames);
                
                % For now, assume that if the same variable name exists, it
                % will have the same size, attributes, etc. in each file.
                toRemove = ~hasVar;
                
                % Remove variables that don't exist in all files
                if any(toRemove)
                    namesToRemove = t.Name(toRemove);
                    removeStr = strjoin(namesToRemove,', ');
                    warning('HFDatastore:InconsistentVariable',...
                        'The following variables: \n\t%s\nwere not found file ''%s''.',...
                        removeStr, char(fileInfo.FileName(rIdx)) );
                    t(toRemove,:) = [];
                end
                
            end %for rIdx = 2:numel(thisInfo)
            
        end %function
        
    end %Private methods
    
    
    
    %% Get/Set methods
    methods
        
        function value = get.VariableNames(obj)
            % This is a dependent property which means it populates the
            % value when you get the value
            value = obj.H5Datasets.Name';
        end
        
        function set.SelectedVariableNames(obj,value)
            
            % Validation
            validateattributes(value,{'cell'},{})
            if ~iscellstr(value)
                error('Expected a cellstr for SelectedVariableNames');
            end
            [isValid,varIdx] = ismember(value, obj.VariableNames); %#ok<MCSUP>
            if any(~isValid)
                badVars = strjoin(value(isValid),', ');
                error('Invalid SelectedVariableNames specified: %s',badVars);
            end
            
            % Store the variables and their indices
            obj.SelectedVariableNames = value;
            obj.ReadVarsIdx = varIdx; %#ok<MCSUP> %internal property
            
        end
        
    end %Get/Set methods
    
    
end %classdef

