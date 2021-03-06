%
% This class represents direct, linked, and derived data for a Visual Coding 2P dataset [1] experiment container. 
%
% [1] Copyright 2016 Allen Institute for Brain Science. Visual Coding 2P dataset. Available from: portal.brain-map.org/explore/circuits/visual-coding-2p.
%

classdef Experiment < handle
    
   %% PROPERTIES - VISIBLE   
   properties (SetAccess = private)
      metadata;   % Metadata associated with this experiment container
      id;         % Experiment container ID
      
      sessions;   % Table of sessions in this experiment container
   end
   
   %% PROPERTIES - HIDDEN
   properties (Hidden, GetAccess = private, SetAccess = private)
      manifest = bot.internal.manifest.instance('ophys');
   end
   
   %% LIFECYCLE 
   
   % CONSTRUCTOR
   methods
      function exp = Experiment(id)
         % experiment - CLASS Encapsulate an experiment container
         
         % - Handle no-argument calling case
         if nargin == 0
            return;
         end
         
         % - Handle a vector of session IDs
         if ~istable(id) && numel(id) > 1
            for nIndex = numel(id):-1:1
               exp(id) = bot.item.experiment(id(nIndex));
            end
            return;
         end
         
         % - Assign experiment container information
         exp.info = table2struct(exp.find_manifest_row(id));
         exp.id = exp.info.id;
         
         % - Extarct matching sessions
         matching_sessions = exp.manifest.ophys_sessions.experiment_container_id == exp.id;
         exp.sessions = exp.manifest.ophys_sessions(matching_sessions, :);
      end
   end
   
   %% STATIC METHODS
   
   methods (Static, Hidden)
      function manifest_row = find_manifest_row(id)
         % - Were we provided a table?
         if istable(id)
            experiment_row = id;
            
            % - Check for an 'id' column
            if ~ismember(experiment_row.Properties.VariableNames, 'id')
               error('BOT:InvalidExperimentTable', ...
                  'The provided table does not describe an experiment container.');
            end
            
            % - Extract the session IDs
            id = experiment_row.id;
         end
         
         % - Check for a numeric argument
         if ~isnumeric(id)
            help bot.experiment;
            error('BOT:Usage', ...
               'The experiment ID must be numeric.');
         end
         
         % - Find these sessions in the experiment manifest
         manifest = bot.internal.manifest.instance('ophys');
         matching_ophys_container = manifest.ophys_containers.id == id;
         
         % - Extract the appropriate table row from the manifest
         if any(matching_ophys_container)
            manifest_row = manifest.ophys_containers(matching_ophys_container, :);
         end
         
         % - Check to see if the session exists
         if ~exist('manifest_row', 'var')
            error('BOT:InvalidExperimentID', ...
               'The provided experiment container ID [%d] was not found in the Allen Brain Observatory manifest.', ...
               id);
         end
      end
   end   
end

