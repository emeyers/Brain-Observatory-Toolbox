classdef Item < handle & matlab.mixin.CustomDisplay
    
    %% PROPERTIES
    properties (SetAccess = protected)
        info;         % Struct containing info about this item
        id;               % ID of this item
    end
    
    %% HIDDEN PROPERTIES
    
    properties (Hidden, Access = protected)
        manifest; % Handle to pertinent manifest containing all available Items of this class
    end
    
    properties (Abstract, Hidden, Access = protected, Constant)
        DATASET_TYPE(1,1) bot.item.internal.enum.DatasetType
        ITEM_TYPE(1,1) bot.item.internal.enum.ItemType
    end
    
    properties (Abstract, Hidden, Access = protected)
        CORE_PROPERTIES (1,:) string;
        LINKED_ITEM_PROPERTIES (1,:) string;
    end
    
    properties (Hidden, SetAccess=protected, GetAccess = protected)
        ITEM_INFO_VALUE_PROPERTIES (1,:) string = string.empty(1,0);
        LINKED_ITEM_VALUE_PROPERTIES (1,:) string = string.empty(1,0);
    end
    
    %% CONSTRUCTOR
    
    methods
        
        function obj = Item(itemIDSpec)
            
            arguments
                itemIDSpec {bot.item.internal.abstract.Item.mustBeItemIDSpec};                
            end
            
            % No Input Argument Constructor Requirement
            if nargin == 0 
                return;
            end
            
            % Handle case of ID array
            if ~istable(itemIDSpec) && numel(itemIDSpec) > 1
                for idx = numel(itemIDSpec):-1:1
                   obj(idx) = bot.(lower(string(obj(1).ITEM_TYPE)))(itemIDSpec(idx));
                end
                return;
            end
            
            % Identify associated manifest containing all Items of this class
            switch obj.DATASET_TYPE
                case "Ephys"
                    obj.manifest = bot.internal.ephysmanifest.instance();
                case "Ophys"
                    obj.manifest = bot.internal.ophysmanifest.instance();
                otherwise
                    assert(false);
            end                       
            
            
            % Identify the manifest table row(s) associated to itemIDSpec
            if istable(itemIDSpec)                
                manifestTableRow = itemIDSpec;
            elseif isnumeric(itemIDSpec)
                itemIDSpec = uint32(round(itemIDSpec));
                
                manifestTablePrefix = lower(string(obj.DATASET_TYPE));
                manifestTableSuffix = lower(string(obj.ITEM_TYPE)) + "s"; 
                
                manifestTable = obj.manifest.([manifestTablePrefix + "_" + manifestTableSuffix]); %#ok<NBRAK>
                                               
                matchingRow = manifestTable.id == itemIDSpec;
                manifestTableRow = manifestTable(matchingRow, :);                          
            else
                assert(false);
            end
            
            assert(~isempty(manifestTableRow),"BOT:Item:idNotFound","Specified numeric ID not found within manifest(s) of all available Items of class %s", mfilename('class'));
            
            % - Assign the table data to the metadata structure
            obj.info = table2struct(manifestTableRow);
            obj.id = obj.info.id;                                              
            
        end
        
        
    end
    
    
    
    %% HIDDEN METHODS  SUPERCLASS IMPLEMENTATION (matlab.mixin.CustomDisplay)
    methods (Hidden, Access = protected)
        function groups = getPropertyGroups(obj)
            if ~isscalar(obj)
                groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            else
                
                % Core properties
                mc = metaclass(obj);
                dcs = [mc.PropertyList.DefiningClass];
                corePropsLocal = findobj(mc.PropertyList(string({dcs.Name}) == mfilename('class')),'GetAccess','public','-and','Hidden',false);
                groups(1) = matlab.mixin.util.PropertyGroup([corePropsLocal.Name obj.CORE_PROPERTIES]);
                
                % Derived properties from Info
                if ~isempty(obj.ITEM_INFO_VALUE_PROPERTIES)
                    groups(end+1) = matlab.mixin.util.PropertyGroup(obj.ITEM_INFO_VALUE_PROPERTIES, 'Info Derived Values');
                end
                
                % Linked item tables
                groups(end+1) = matlab.mixin.util.PropertyGroup(obj.LINKED_ITEM_PROPERTIES, 'Linked Items');
                
                % Derived properties from Linked Item Tables
                if ~isempty(obj.LINKED_ITEM_VALUE_PROPERTIES)
                    groups(end+1) = matlab.mixin.util.PropertyGroup(obj.LINKED_ITEM_VALUE_PROPERTIES, 'Linked Item Derived Values');
                end
            end
        end
        
    end
    

    
    %% HIDDEN METHODS - STATIC
    
    methods (Hidden, Static)        
        function  mustBeItemIDSpec(val)
            %MUSTBEITEMIDSPEC Validation function for items specified to BOT item factory functions for item object array construction
                        
            eidTypePrefix = "mustBeBOTItemId:";
            eidTypeSuffix = "";
            msgType = "";
            
            if istable(val)
                
                eidTypeSuffix = "invalidItemTable";
                
                if ~ismember(val.Properties.VariableNames, 'id')
                    msgType = "Table supplied not recognized as a valid BOT Item information table";
                end
                
                if height(val) ~= 1
                    msgType = "Table supplied must have one and only one row";
                end                                               
                
            elseif ~isnumeric(val) || ~isvector(val) || ~all(isfinite(val)) || any(val<=0)
                eidTypeSuffix = "invalidItemIDs";
                msgType = "Must specify BOT item object(s) to create with either a numeric vector of valid ID values or a valid Item information table";
            elseif ~isinteger(val) && ~all(round(val)==val)
                eidTypeSuffix = "invalidItemIDs";
                msgType = "Must specify BOT item object(s) to create with either a numeric vector of valid ID values or a valid Item information table";
            end
            
            
            % Throw error
            if strlength(msgType) > 0
                throwAsCaller(MException(eidTypePrefix + eidTypeSuffix,msgType));
            end
        end         
    end
    
    %    methods (Static)
    %
    %        function tbl = removeUnusedCategories(tbl)
    %        % TODO: Consider if it's a desired behavior for category lists to be narrowed for linked item tables? Or better to retain the "global" view of all available in the container session?
    %
    %            if isempty(tbl)
    %                return;
    %            end
    %
    %            varTypes = string(cellfun(@class,table2cell(tbl(1,:)),'UniformOutput',false));
    %            varNames = string(tbl.Properties.VariableNames);
    %
    %            catVarIdxs = find(varTypes.matches("categorical"));
    %
    %            for idx = catVarIdxs
    %                varName = varNames(idx);
    %
    %                validCats = unique(tbl.(varName));
    %                allCats = categories(tbl{1,varName});
    %                invalidCats = setdiff(allCats,validCats);
    %
    %                tbl.(varName) = removecats(tbl.(varName),invalidCats);
    %
    %            end
    %
    %        end
    %    end
    
end