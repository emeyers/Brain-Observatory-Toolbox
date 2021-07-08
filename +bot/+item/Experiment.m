classdef Experiment < bot.item.internal.abstract.Item
%
% This class represents direct, linked, and derived data for a Visual Coding 2P dataset [1] experiment container. 
%
% [1] Copyright 2016 Allen Institute for Brain Science. Visual Coding 2P dataset. Available from: portal.brain-map.org/explore/circuits/visual-coding-2p.
%    
    %% PROPERTIES - VISIBLE 
    properties (SetAccess = private)
      sessions;
    end
   
   %% PROPERTIES - HIDDEN
    % SUPERCLASS IMPLEMENTATION (bot.item.internal.abstract.Item)
    properties (Hidden, Access = protected, Constant)
        DATASET_TYPE = bot.item.internal.enum.DatasetType.Ophys;
        ITEM_TYPE = bot.item.internal.enum.ItemType.Experiment;
    end        
    
    properties (Hidden, Access = protected)
        CORE_PROPERTIES = string.empty(1,0);
        LINKED_ITEM_PROPERTIES = ["sessions"];
    end
   
   %% LIFECYCLE 
   
   % CONSTRUCTOR
   methods
      function obj = Experiment(itemIDSpec)
         % Superclass construction
         obj = obj@bot.item.internal.abstract.Item(itemIDSpec);

         if ~istable(itemIDSpec) && numel(itemIDSpec) == 1
            % Assign linked Item tables (downstream)
            obj.sessions = obj.manifest.ophys_sessions(obj.manifest.ophys_sessions.experiment_container_id == obj.info.id, :);
         end
      end
   end   
end

