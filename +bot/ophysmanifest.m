%% CLASS bot.ophysmanifest
%
% This class can be used to obtain a raw list of available experimental
% sessions from the Allen Brain Observatory dataset [1, 2].
%
% Construction:
% >> bom = bot.manifest('ophys')
% >> bom = bot.ophysmanifest
%
% Get information about all OPhys experimental sessions:
% >> bom.tOphysSessions
% ans =
%      date_of_acquisition      experiment_container_id    fail_eye_tracking  ...
%     ______________________    _______________________    _________________  ...
%     '2016-03-31T20:22:09Z'    5.1151e+08                 true               ...
%     '2016-07-06T15:22:01Z'    5.2755e+08                 false              ...
%     ...
%
% Force an update of the manifest representing Allen Brain Observatory dataset contents:
% >> bom.UpdateManifests()
%
% Access data from an experimental session:
% >> nSessionID = bom.tOphysSessions(1, 'id');
% >> bos = bot.session(nSessionID)
% bos =
%   ophyssession with properties:
%
%                sSessionInfo: [1x1 struct]
%     strLocalNWBFileLocation: []
%
% (See documentation for the `bot.ophyssession` class for more information)
%
% [1] Copyright 2016 Allen Institute for Brain Science. Allen Brain Observatory. Available from: portal.brain-map.org/explore/circuits
% [2] Copyright 2015 Allen Brain Atlas API. Allen Brain Observatory. Available from: brain-map.org/api/index.html
%

%% Class definition

classdef ophysmanifest < handle
   properties (Access = private, Transient = true)
      oCache = bot.internal.cache;        % BOT Cache object
      sAPIAccess;                         % Function handles for low-level API access
   end
   
   properties (SetAccess = private, Dependent = true)
      tOPhysSessions;                   % Table of all OPhys experimental sessions
      tOPhysContainers;                 % Table of all OPhys experimental containers
   end
   
   %% Constructor
   methods
      function oManifest = ophysmanifest()
         % Memoize manifest getter
         oManifest.sAPIAccess.get_cached_ophys_manifests = memoize(@oManifest.get_cached_ophys_manifests);
      end
   end
   
   %% Getters for manifest tables
   methods
      function tOPhysSessions = get.tOPhysSessions(oManifest)
         ophys_manifests = oManifest.sAPIAccess.get_cached_ophys_manifests();
         tOPhysSessions = ophys_manifests.ophys_session_manifest;
      end
      
      function tOPhysContainers = get.tOPhysContainers(oManifest)
         ophys_manifests = oManifest.sAPIAccess.get_cached_ophys_manifests();
         tOPhysContainers = ophys_manifests.ophys_container_manifest;
      end
   end
   
   %% Manifest update method
   methods
      function UpdateManifests(oManifest)
         % - Invalidate API manifests in cache
         oManifest.oCache.ccCache.RemoveURLsMatchingSubstring('criteria=model::ExperimentContainer');
         oManifest.oCache.ccCache.RemoveURLsMatchingSubstring('criteria=model::OphysExperiment');
         
         % - Remove cached manifest tables
         oManifest.oCache.RemoveObject('allen_brain_observatory_ophys_manifests')
         
         % - Clear all caches for memoized access functions
         for strField = fieldnames(oManifest.sAPIAccess)'
            oManifest.sAPIAccess.(strField{1}).clearCache();
         end
      end
   end
   
   methods (Access = private)
      %% Low-level getter method for OPhys manifests
      function [ophys_manifests] = get_ophys_manifests_info_from_api(oManifest)
         % get_ophys_manifests_info_from_api - PRIVATE METHOD Download manifests of content from Allen Brain Observatory dataset via the Allen Brain Atlas API
         %
         % Usage: [ophys_manifests] = get_ophys_manifests_info_from_api(oCache)
         %
         % Download `container_manifest`, `session_manifest`,
         % `cell_id_mapping` as MATLAB tables. Returns the tables as fields
         % of a structure. Converts various columns to appropriate formats,
         % including categorical arrays.
         
         disp('Fetching OPhys manifests...');
         
         % - Specify URLs for download
         cell_id_mapping_url = 'http://api.brain-map.org/api/v2/well_known_file_download/590985414';
         
         %% - Fetch OPhys container manifest
         ophys_container_manifest = oManifest.oCache.CachedAPICall('criteria=model::ExperimentContainer', 'rma::include,ophys_experiments,isi_experiment,specimen(donor(conditions,age,transgenic_lines)),targeted_structure');
         
         % - Convert varibales to useful types
         ophys_container_manifest.id = uint32(ophys_container_manifest.id);
         ophys_container_manifest.failed_facet = uint32(ophys_container_manifest.failed_facet);
         ophys_container_manifest.isi_experiment_id = uint32(ophys_container_manifest.isi_experiment_id);
         ophys_container_manifest.specimen_id = uint32(ophys_container_manifest.specimen_id);
         
         ophys_manifests.ophys_container_manifest = ophys_container_manifest;
         
         %% - Fetch OPhys session manifest
         ophys_session_manifest = oManifest.oCache.CachedAPICall('criteria=model::OphysExperiment', 'rma::include,experiment_container,well_known_files(well_known_file_type),targeted_structure,specimen(donor(age,transgenic_lines))');
         
         % - Label as ophys sessions
         ophys_session_manifest = addvars(ophys_session_manifest, ...
            repmat(categorical({'OPhys'}, {'EPhys', 'OPhys'}), size(ophys_session_manifest, 1), 1), ...
            'NewVariableNames', 'BOT_session_type', ...
            'before', 1);
         
         % - Create `cre_line` variable from specimen field of session
         % manifests and append it back to session_manifest tables.
         % `cre_line` is important, makes life easier if it's explicit
         
         % - Extract from OPhys sessions manifest
         tAllSessions = ophys_session_manifest;
         cre_line = cell(size(tAllSessions, 1), 1);
         for i = 1:size(tAllSessions, 1)
            donor_info = tAllSessions(i, :).specimen.donor;
            transgenic_lines_info = struct2table(donor_info.transgenic_lines);
            cre_line(i,1) = transgenic_lines_info.name(not(cellfun('isempty', strfind(transgenic_lines_info.transgenic_line_type_name, 'driver')))...
               & not(cellfun('isempty', strfind(transgenic_lines_info.name, 'Cre'))));
         end
         
         ophys_session_manifest = addvars(ophys_session_manifest, cre_line, ...
            'NewVariableNames', 'cre_line');
         
         % - Convert experiment containiner variables to useful types
         ophys_session_manifest.experiment_container_id = uint32(ophys_session_manifest.experiment_container_id);
         ophys_session_manifest.id = uint32(ophys_session_manifest.id);
         ophys_session_manifest.date_of_acquisition = datetime(ophys_session_manifest.date_of_acquisition,'InputFormat','yyyy-MM-dd''T''HH:mm:ss''Z''','TimeZone','UTC');
         ophys_session_manifest.specimen_id = uint32(ophys_session_manifest.specimen_id);
         
         ophys_manifests.ophys_session_manifest = ophys_session_manifest;
         
         %% - Fetch cell ID mapping
         
         options = weboptions('ContentType', 'table', 'TimeOut', 60);
         ophys_manifests.cell_id_mapping = oManifest.oCache.ccCache.webread(cell_id_mapping_url, [], options);
      end
      
      function [ophys_manifests] = get_cached_ophys_manifests(oManifest)
         strKey = 'allen_brain_observatory_ophys_manifests';
         
         if oManifest.oCache.IsObjectInCache(strKey)
            ophys_manifests = oManifest.oCache.RetrieveObject(strKey);
            
         else
            ophys_manifests = get_ophys_manifests_info_from_api(oManifest);
            oManifest.oCache.InsertObject(strKey, ophys_manifests);
         end
      end
   end
end