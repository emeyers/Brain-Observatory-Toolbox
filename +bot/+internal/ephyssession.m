%% CLASS bot.internal.ephyssession - Encapsulate and provide data access to an EPhys session dataset from the Allen Brain Observatory

classdef ephyssession < bot.internal.ephysitem & bot.internal.session_base & matlab.mixin.CustomDisplay
   %% Properties
   properties (SetAccess = private)
      units;                          % A Table of all units in this session
      probes;                         % A Table of all probes in this session
      channels;                       % A Table of all channels in this session

      specimen_name;                % Metadata: name of the animal used in this session
      age_in_days;                  % Metadata: age of the animal used in this session, in days
      sex;                          % Metadata: sex of the animal used in this session
      full_genotype;                % Metadata: genotype of the animal used in this session
      session_type;                 % Metadata: string describing the type of session (group of stimuli used)      

      num_units;                    % Number of units (putative neurons) recorded in this session
      num_probes;                   % Number of probes recorded in this session
      num_channels;                 % Number of channels recorded in this session      
   end
   
   %% - Lazy loading properties
   properties (SetAccess = private)
      rig_geometry_data;               % Metadata about the geometry of the rig used in this session
      rig_equipment_name;              % Metadata: name of the rig used in this session

      inter_presentation_intervals;    % The elapsed time between each immediately sequential pair of stimulus presentations. This is a dataframe with a two-level multiindex (levels are 'from_presentation_id' and 'to_presentation_id'). It has a single column, 'interval', which reports the elapsed time between the two presentations in seconds on the experiment's master clock
      running_speed;                   % [Tx2] array of running speeds, where each row is [timestamp running_speed]
      mean_waveforms;                  % Table mapping unit ids to matrices containing mean spike waveforms for that unit
      stimulus_presentations;          % Table whose rows are stimulus presentations and whose columns are presentation characteristics. A stimulus presentation is the smallest unit of distinct stimulus presentation and lasts for (usually) 1 60hz frame. Since not all parameters are relevant to all stimuli, this table contains many 'null' values
      stimulus_conditions;             % Table indicating unique stimulus presentations presented in this experiment
      optogenetic_stimulation_epochs;  % Table of optogenetic stimulation epochs for this experimental session (if present)
      session_start_time;              % Timestamp of start of session
      spike_amplitudes;                % Table of extracted spike amplitudes for all units
      invalid_times;                   % Table indicating invalid recording times
      
      num_stimulus_presentations;   % Number of stimulus presentations in this session
      stimulus_names;               % Names of stimuli presented in this session
      structure_acronyms;           % EPhys structures recorded across all channels in this session
      structurewise_unit_counts;    % Numbers of units (putative neurons) recorded in each of the EPhys structures recorded in this session
      
      stimulus_epochs;              % Table of stimulus presentation epochs
      
      stimulus_templates;           % Stimulus template table
   end
   
   properties (Hidden = true, SetAccess = immutable, GetAccess = private)
      metadata_property_list = ["metadata", "id", "specimen_name", "age_in_days", ...
         "sex", "full_genotype", "session_type", ...
         "num_units", "num_probes", "num_channels", ...
         ];
      contained_objects_property_list = ["probes", "channels", "units"];
      lazy_property_list = ["rig_geometry_data", ...
         "rig_equipment_name", "inter_presentation_intervals", ...
         "running_speed", "mean_waveforms", "stimulus_presentations", ...
         "stimulus_conditions", "optogenetic_stimulation_epochs", ...
         "session_start_time", "spike_amplitudes", "invalid_times", ...
         "num_stimulus_presentations", "stimulus_names", "structure_acronyms", ...
         "structurewise_unit_counts", "stimulus_templates", ...
         "stimulus_epochs", ...
         ];
   end
   
   methods (Access = protected)
      function groups = getPropertyGroups(obj)
         if ~isscalar(obj)
            groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
         else
            % - Default properties
            groups(1) = matlab.mixin.util.PropertyGroup(obj.metadata_property_list, 'Metadata');
            groups(2) = matlab.mixin.util.PropertyGroup(obj.contained_objects_property_list, 'Contained experimental data');
            
            if obj.is_nwb_cached()
               description = '[cached]';
            else
               description = '[not cached]';
            end
            
            propList = struct();
            for prop = obj.lazy_property_list
               propList.(prop) = description;
            end
            
            groups(3) = matlab.mixin.util.PropertyGroup(propList, 'Lazy loading');
         end
      end
   end   
   
   %% Private properties
   properties (Hidden = true, Access = public, Transient = true)
      spike_times;                  % Maps integer unit ids to arrays of spike times (float) for those units
      nwb_metadata;
      rig_metadata;                 % Metadata: structure containing metadata about the rig used in this experimental session

      nwb_file bot.nwb.nwb_ephys = bot.nwb.nwb_ephys();                % NWB file acess object
      
      NON_STIMULUS_PARAMETERS = [
         "start_time", ...
         "stop_time", ...
         "duration", ...
         "stimulus_block", ...
         "stimulus_condition_id"]
      
      DETAILED_STIMULUS_PARAMETERS = [
         "colorSpace", ...
         "flipHoriz", ...
         "flipVert", ...
         "depth", ...
         "interpolate", ...
         "mask", ...
         "opacity", ...
         "rgbPedestal", ...
         "tex", ...
         "texRes", ...
         "units", ...
         "rgb", ...
         "signalDots", ...
         "noiseDots", ...
         "fieldSize", ...
         "fieldShape", ...
         "fieldPos", ...
         "nDots", ...
         "dotSize", ...
         "dotLife", ...
         "color_triplet"]
   end
   
   
   %% Constructor
   methods
      function session = ephyssession(session_id, manifest)
         % bot.internal.ephyssession - CONSTRUCTOR Construct an object containing an experimental session from an Allen Brain Observatory dataset
         %
         % Usage: bsObj = bot.internal.ephyssession(id, manifest)
         %        vbsObj = bot.internal.ephyssession(ids, manifest)
         %        bsObj = bot.internal.ephyssession(session_table_row, manifest)
         %
         % `manifest` is the EPhys manifest object. `id` is the session ID
         % of an EPhys experimental session. Optionally, a vector `ids` of
         % multiple session IDs may be provided to return a vector of
         % session objects. A table row of the EPhys sessions manifest
         % table may also be provided as `session_table_row`.
         if nargin == 0
            return;
         end
         
         if ~exist('manifest', 'var') || isempty(manifest)
            manifest = bot.internal.ephysmanifest.instance();
         end
         
         % - Handle a vector of session IDs
         if ~istable(session_id) && numel(session_id) > 1
            for index = numel(session_id):-1:1
               session(session_id) = bot.internal.ephyssession(session_id(index), manifest);
            end
            return;
         end
         
         % - Assign metadata
         session = session.check_and_assign_metadata(session_id, manifest.ephys_sessions, 'session');
         session_id = session.id;
         
         % - Ensure that we were given an EPhys session
         if session.metadata.type ~= "EPhys"
            error('BOT:Usage', '`bot.internal.ephyssession` objects may only refer to EPhys experimental sessions.');
         end
         
         % - Assign associated table rows
         session.probes = manifest.ephys_probes(manifest.ephys_probes.ephys_session_id == session_id, :);
         session.channels = manifest.ephys_channels(manifest.ephys_channels.ephys_session_id == session_id, :);
         session.units = manifest.ephys_units(manifest.ephys_units.ephys_session_id == session_id, :);
      end
   end
   
   %%
   methods
      function nwb = get.nwb_file(self)
         % - Retrieve and cache the NWB file
         if ~self.in_cache('nwb_file')
            self.property_cache.nwb_file = bot.nwb.nwb_ephys(self.EnsureCached());
         end
         
         % - Return an NWB file access object
         nwb = self.property_cache.nwb_file;
      end
   end
   
   %% Getters for public properties requiring cached data access
   methods
      
      function inter_presentation_intervals = get.inter_presentation_intervals(self)
         inter_presentation_intervals = self.fetch_cached('inter_presentation_intervals', @self.build_inter_presentation_intervals);
      end
      
      function mean_waveforms = get.mean_waveforms(self)
         n = self.nwb_file;
         mean_waveforms = self.fetch_cached('mean_waveforms', @n.fetch_mean_waveforms);
      end
      
      function stimulus_conditions = get.stimulus_conditions(self)
         self.cache_stimulus_presentations();
         stimulus_conditions = self.property_cache.stimulus_conditions_raw;
      end
      
      function spike_times = get.spike_times(self)
         if ~self.in_cache('checked_spike_times')
            self.warn_invalid_spike_intervals();
            self.property_cache.checked_spike_times = true;
         end
         
         if ~self.in_cache('spike_times')
            self.property_cache.spike_times = self.build_spike_times(self.nwb_file.fetch_spike_times());
         end
         
         spike_times = self.property_cache.spike_times;
      end
      
      function stimulus_presentations = get.stimulus_presentations(self)
         % - Generate and cache stimulus presentations table
         self.cache_stimulus_presentations();
         
         % - Clean and return stimulus presentations table
         stimulus_presentations = self.remove_detailed_stimulus_parameters(self.property_cache.stimulus_presentations_raw);
      end
      
      function optogenetic_stimulation_epochs = get.optogenetic_stimulation_epochs(self)
         n = self.nwb_file;
         try
            optogenetic_stimulation_epochs = self.fetch_cached('optogenetic_stimulation_epochs', @n.fetch_optogenetic_stimulation);
         catch
            warning('BOT:DataNotPresent', 'Optogenetic stimulation data is not present for this session');
         end
      end
      
      function session_start_time = get.session_start_time(self)
         n = self.nwb_file;
         session_start_time = self.fetch_cached('session_start_time', @n.fetch_session_start_time);
      end
      
      function spike_amplitudes = get.spike_amplitudes(self)
         n = self.nwb_file;
         spike_amplitudes = self.fetch_cached('spike_amplitudes', @n.fetch_spike_amplitudes);
      end
      
      function invalid_times = get.invalid_times(self)
         n = self.nwb_file;
         invalid_times = self.fetch_cached('invalid_times', @n.fetch_invalid_times);
      end
      
      function running_speed = get.running_speed(self)
         n = self.nwb_file;
         running_speed = self.fetch_cached('running_speed', @n.fetch_running_speed);
      end
   end
   
   %% Derived public properties
   methods
      function num_units = get.num_units(self)
         num_units = size(self.units, 1);
      end
      
      function num_probes = get.num_probes(self)
         num_probes = size(self.probes, 1);
      end
      
      function num_channels = get.num_channels(self)
         num_channels = size(self.channels, 1);
      end
      
      function num_stimulus_presentations = get.num_stimulus_presentations(self)
         num_stimulus_presentations = size(self.stimulus_presentations, 1);
      end
      
      function stimulus_names = get.stimulus_names(self)
         stimulus_names = unique(self.stimulus_presentations.stimulus_name);
      end
      
      function structure_acronyms = get.structure_acronyms(self)
         all_acronyms = self.channels.ephys_structure_acronym;
         is_string = cellfun(@ischar, self.channels.ephys_structure_acronym);
         structure_acronyms = unique(all_acronyms(is_string));
      end
      
      function structurewise_unit_counts = get.structurewise_unit_counts(self)
         all_acronyms = self.units.ephys_structure_acronym;
         [ephys_structure_acronym, ~, structurewise_unit_ids] = unique(all_acronyms);
         count = accumarray(structurewise_unit_ids, 1);
         
         structurewise_unit_counts = table(ephys_structure_acronym, count);
         structurewise_unit_counts = sortrows(structurewise_unit_counts, 2, 'descend');
      end
   end
   
   %% Metadata public property getters
   methods
      function metadata = get.nwb_metadata(self)
         n = self.nwb_file;
         try
            metadata = self.fetch_cached('metadata', @n.fetch_nwb_metadata);
         catch
            metadata = [];
         end
      end
      
      function rig_metadata = get.rig_metadata(self)
         n = self.nwb_file;
         try
            rig_metadata = self.fetch_cached('rig_metadata', @n.fetch_rig_metadata);
         catch
            rig_metadata = [];
         end
      end
      function rig_geometry_data = get.rig_geometry_data(self)
         try
            rig_geometry_data = self.rig_metadata.rig_geometry_data;
         catch
            rig_geometry_data = [];
         end
      end
      
      function rig_equipment_name = get.rig_equipment_name(self)
         try
            rig_equipment_name = self.rig_metadata.rig_equipment;
         catch
            rig_equipment_name = [];
         end
      end
      
      function specimen_name = get.specimen_name(self)
         specimen_name = self.metadata.specimen_name;
      end
      
      function age_in_days = get.age_in_days(self)
         age_in_days = self.metadata.age_in_days;
      end
      
      function sex = get.sex(self)
         sex = self.metadata.sex;
      end
      
      function full_genotype = get.full_genotype(self)
         full_genotype = self.metadata.full_genotype;
      end
      
      function session_type = get.session_type(self)
         session_type = self.metadata.session_type;
      end
      
      function stimulus_table = get.stimulus_templates(self)
         % - Query list of stimulus templates from Allen Brain API
         ecephys_product_id = 714914585;
         query = sprintf("rma::criteria,well_known_file_type[name$eq\'Stimulus\'][attachable_type$eq\'Product\'][attachable_id$eq%d]", ecephys_product_id);
         stimulus_table = self.bot_cache.CachedAPICall('criteria=model::WellKnownFile', query);
         
         % - Convert table variables to sensible types
         stimulus_table.attachable_id = int64(stimulus_table.attachable_id);
         stimulus_table.attachable_type = string(stimulus_table.attachable_type);
         stimulus_table.download_link = string(stimulus_table.download_link);
         stimulus_table.id = int64(stimulus_table.id);
         stimulus_table.path = string(stimulus_table.path);
         stimulus_table.well_known_file_type_id = int64(stimulus_table.well_known_file_type_id);
         
         % - Loop over stimulus templates
         scene_number = nan(size(stimulus_table, 1), 1);
         movie_number = nan(size(stimulus_table, 1), 1);
         for row_ind = 1:size(stimulus_table, 1)
            row = stimulus_table(row_ind, :);
            
            if contains(row.path, 'natural_movie_')
               [~, str_movie_number, ~] = fileparts(row.path);
               movie_number(row_ind) = sscanf(str_movie_number, 'natural_movie_%d');
               scene_number(row_ind) = nan;
               
            elseif contains(row.path, '.tiff')
               [~, scene_number(row_ind), ~] = fileparts(row.path);
               movie_number(row_ind) = nan;
            end
         end
         
         stimulus_table.scene_number = scene_number;
         stimulus_table.movie_number = movie_number;
      end
      
   end
   
   %% Public methods
   methods
      function epochs = get.stimulus_epochs(self)
         epochs = self.fetch_stimulus_epochs();
      end
      
      function epochs = fetch_stimulus_epochs(self, duration_thresholds)
         % fetch_stimulus_epochs - METHOD Reports continuous periods of time during which a single kind of stimulus was presented
         %
         % Usage: epochs = sess.fetch_stimulus_epochs(<duration_thresholds>)
         %
         % `duration_thresholds` is an optional structure, linking stimulus
         % names to times in seconds. If present in the structure, any
         % stimulus with the matching name, for which an epoch of that
         % stimulus shorter than the threshold duration given in the
         % structure, will be removed from the returned stimulus epochs.
         % `epochs` will be a table of stimulus epochs for the stimuli in
         % this session.
         arguments
            self;
            duration_thresholds = struct('spontaneous_activity', 90);
         end
         
         presentations = self.stimulus_presentations;
         diff_indices = nan_intervals(presentations.stimulus_block);
         
         epochs.start_time = presentations.start_time(diff_indices(1:end-1));
         epochs.stop_time = presentations.stop_time(diff_indices(2:end)-1);
         epochs.stimulus_name = presentations.stimulus_name(diff_indices(1:end-1));
         epochs.stimulus_block = presentations.stimulus_block(diff_indices(1:end-1));
         
         epochs = struct2table(epochs);
         epochs.duration = epochs.stop_time - epochs.start_time;
         
         for strField = fieldnames(duration_thresholds)
            select_epochs = epochs.stimulus_name ~= strField{1};
            select_epochs = select_epochs | epochs.duration >= duration_thresholds.(strField{1});
            epochs = epochs(select_epochs, :);
         end
         
         epochs = epochs(:, ["start_time", "stop_time", "duration", "stimulus_name", "stimulus_block"]);
      end
      
      function pupil_data = fetch_pupil_data(self, suppress_pupil_data)
         % fetch_pupil_data - METHOD Return the pupil-tracking data for this session, if present
         %
         % Usage: pupil_data = sess.fetch_pupil_data(<suppress_pupil_data>)
         %
         % `pupil_data` will be a table containing pupil location data for
         % the current session.
         %
         % `suppress_pupil_data` is an optional flag (default: `true`),
         % indicating that detailed gaze mapping adat should be excluded
         % from the returned table.
         arguments
            self;
            suppress_pupil_data logical = true;
         end
         
         n = self.nwb_file;
         pupil_data = n.fetch_pupil_data(suppress_pupil_data);
      end
      
      function [tiled_data, time_base] = presentationwise_spike_counts(self, ...
            bin_edges, stimulus_presentation_ids, unit_ids, binarize, ...
            large_bin_size_threshold, time_domain_callback)
         % presentationwise_spike_counts - METHODS Build an array of spike counts surrounding stimulus onset per unit and stimulus frame
         %
         % Parameters
         % ---------
         % bin_edges : numpy.ndarray
         %    Spikes will be counted into the bins defined by these edges. Values are in seconds, relative
         %    to stimulus onset.
         % stimulus_presentation_ids : array-like
         %    Filter to these stimulus presentations
         % unit_ids : array-like
         %    Filter to these units
         % binarize : bool, optional
         %    If true, all counts greater than 0 will be treated as 1. This results in lower storage overhead,
         %    but is only reasonable if bin sizes are fine (<= 1 millisecond).
         % large_bin_size_threshold : float, optional
         %    If binarize is True and the largest bin width is greater than this value, a warning will be emitted.
         % time_domain_callback : callable, optional
         %    The time domain is a numpy array whose values are trial-aligned bin
         %    edges (each row is aligned to a different trial). This optional function will be
         %    applied to the time domain before counting spikes.
         %
         % Returns
         % -------
         % Table whose dimensions are stimulus presentation, unit, and time bin and whose values are spike counts.
      arguments
         self;
         bin_edges;
         stimulus_presentation_ids;
         unit_ids;
         binarize logical = false;
         large_bin_size_threshold = 0.001;
         time_domain_callback function_handle = str2func('@(x)x');
      end
      
      % - Filter stimulus_presentations table
      stimulus_presentations = self.stimulus_presentations; %#ok<PROPLC>
      select_stimuli = ismember(stimulus_presentations.stimulus_presentation_id, stimulus_presentation_ids); %#ok<PROPLC>
      stimulus_presentations = stimulus_presentations(select_stimuli, :); %#ok<PROPLC>
      
      % - Filter units table
      select_units = ismember(self.units.id, unit_ids);
      units_selected = self.units(select_units, :);
      
      largest_bin_size = max(diff(bin_edges));
      
      if binarize && largest_bin_size > large_bin_size_threshold
         warning('BOT:BinarizeLargeBin', ...
            ['You''ve elected to binarize spike counts, but your maximum bin width is {largest_bin_size:2.5f} seconds. \n', ...
            'Binarizing spike counts with such a large bin width can cause significant loss of accuracy! ', ...
            'Please consider only binarizing spike counts when your bins are <= %.2f seconds wide.'], large_bin_size_threshold);
      end
      
      domain = build_time_window_domain(bin_edges, stimulus_presentations.start_time, time_domain_callback); %#ok<PROPLC>
      
      out_of_order = diff(domain) < 0;
      if any(out_of_order)
         rows, cols = find(out_of_order);
         error('BOT:OutOfOrder', 'The time domain specified contains out-of-order bin edges at indices\n%s', sprintf("[%d %d]\n", rows, cols));
      end
      
      ends = domain(end, :);
      starts = domain(1, :);
      time_diffs = starts(2:end) - ends(1:end-1);
      overlapping = find(time_diffs < 0, 1);
      
      if ~isempty(overlapping)
         warning('BOT:OverlappingIntervals', ['You''ve specified some overlapping time intervals between neighboring rows. \n%s\n', ...
            'with a maximum overlap of %.2f seconds.']);%, sprintf('[%d %d]\n', [overlapping; overlapping+1]), abs(min(time_diffs)));
      end
      
      % - Build a histogram of spikes
      tiled_data = build_spike_histogram(domain, self.spike_times, units_selected.id, binarize);
      
      % - Generate a time base for `tiled_data`
      time_base = bin_edges(1:end-1) + diff(bin_edges) / 2;
   end
   
   function spikes_with_onset = presentationwise_spike_times(self, stimulus_presentation_ids, unit_ids)
   % presentationwise_spike_times - METHOD Produce a table associating spike times with units and stimulus presentations
   %
   % Usage: spikes_with_onset = sess.presentationwise_spike_times(self, stimulus_presentation_ids, unit_ids)
   %
   %   Parameters
   %   ----------
   %   stimulus_presentation_ids : array-like
   %       Filter to these stimulus presentations
   %   unit_ids : array-like
   %       Filter to these units
   %
   %   Returns
   %   -------
   %   pandas.DataFrame :
   %   Index is
   %       spike_time : float
   %           On the session's master clock.
   %   Columns are
   %       stimulus_presentation_id : int
   %           The stimulus presentation on which this spike occurred.
   %       unit_id : int
   %           The unit that emitted this spike.
   arguments
      self;
      stimulus_presentation_ids = [];
      unit_ids = [];
   end
   
      % - Filter stimulus_presentations table
      stimulus_presentations = self.stimulus_presentations; %#ok<PROPLC>
      
      if ~isempty(stimulus_presentation_ids)
         select_stimuli = ismember(stimulus_presentations.stimulus_presentation_id, stimulus_presentation_ids); %#ok<PROPLC>
         stimulus_presentations = stimulus_presentations(select_stimuli, :); %#ok<PROPLC>
      end
   
      % - Filter units table
      if ~isempty(unit_ids)
         select_units = ismember(self.units.id, unit_ids);
         units_selected = self.units(select_units, :);
      else
         units_selected = self.units;
      end

      presentation_times = zeros(size(stimulus_presentations, 1) * 2, 1); %#ok<PROPLC>
      presentation_times(1:2:end) = stimulus_presentations.start_time; %#ok<PROPLC>
      presentation_times(2:2:end) = stimulus_presentations.stop_time; %#ok<PROPLC>
      all_presentation_ids = stimulus_presentations.stimulus_presentation_id; %#ok<PROPLC>
      
      presentation_ids = [];
      unit_ids = [];
      spike_times = []; %#ok<PROPLC>
      
      for unit_index = 1:numel(units_selected.id)
         unit_id = units_selected.id(unit_index);         
         
         % - Extract the spike times for this unit
         select_stimuli = self.spike_times.unit_id == unit_id;
         data = self.spike_times(select_stimuli, :).spike_times{1};
         
         % - Find the locations of the presentation times in the spike data
         indices = searchsorted(presentation_times, data) - 2;
         
         index_valid = mod(indices, 2) == 0;
         p_indices = floor(indices / 2);
         p_indices(p_indices == -1) = numel(all_presentation_ids)-1;
         p_indices = p_indices + 1;
         presentations = all_presentation_ids(p_indices);
         
         [presentations, order] = sort(presentations);
         index_valid = index_valid(order);
         data = data(order);
         
         changes = find([1; diff(presentations); 1]);
         for change_index = 1:numel(changes)-1
            ii = changes(change_index);
            jj = changes(change_index+1)-1;
            
            values = data(ii:jj);
            values = values(index_valid(ii:jj));
            
            if isempty(values)
               continue
            end
            
            unit_ids = [unit_ids; zeros(numel(values), 1, 'like', unit_id) + unit_id]; %#ok<AGROW>
            presentation_ids = [presentation_ids; zeros(numel(values), 1, 'like', presentations) + presentations(ii)]; %#ok<AGROW>
            spike_times = [spike_times; values]; %#ok<AGROW,PROPLC>
         end
      end
      
      % - Handle the case when no spikes occurred
      if isempty(spike_times) %#ok<PROPLC>
         spikes_with_onset = table('VariableNames', ...
            {'spike_times', 'stimulus_presentation', ...
            'unit_id', 'time_since_stimulus_presentation_onset'});
         return;
      end
      
      stimulus_presentation_id = presentation_ids;
      unit_id = unit_ids;
      
      spike_df = table(spike_times, stimulus_presentation_id, unit_id); %#ok<PROPLC>
      
      % - Filter stimulus_presentations table
      onset_times = self.stimulus_presentations;
      select_stimuli = ismember(onset_times.stimulus_presentation_id, all_presentation_ids);
      onset_times = onset_times(select_stimuli, {'stimulus_presentation_id', 'start_time'});

      spikes_with_onset = join(spike_df, onset_times, 'Keys', 'stimulus_presentation_id');
      spikes_with_onset.time_since_stimulus_presentation_onset = spikes_with_onset.spike_times - spikes_with_onset.start_time;
      
      spikes_with_onset = sortrows(spikes_with_onset, 'spike_times');
      spikes_with_onset = removevars(spikes_with_onset, 'start_time');
   end
   
   function summary = conditionwise_spike_statistics(self, stimulus_presentation_ids, unit_ids, use_rates)
      % """ Produce summary statistics for each distinct stimulus condition
      %
      % Parameters
      % ----------
      % stimulus_presentation_ids : array-like
      %    identifies stimulus presentations from which spikes will be considered
      % unit_ids : array-like
      %    identifies units whose spikes will be considered
      % use_rates : bool, optional
      %    If True, use firing rates. If False, use spike counts.
      %
      % Returns
      % -------
      % pd.DataFrame :
      %    Rows are indexed by unit id and stimulus condition id. Values are summary statistics describing spikes
      %    emitted by a specific unit across presentations within a specific condition.
      arguments
         self;
         stimulus_presentation_ids {mustBeNumeric} = [];
         unit_ids {mustBeNumeric} = [];
         use_rates logical = false;
      end
      
      if isempty(stimulus_presentation_ids)
         stimulus_presentation_ids = self.stimulus_presentations.stimulus_presentation_id;
      end
      
      select_presentations = ismember(self.stimulus_presentations.stimulus_presentation_id, stimulus_presentation_ids);
      presentations = self.stimulus_presentations(select_presentations, {'stimulus_presentation_id', 'stimulus_condition_id', 'duration'});
      
      spikes = self.presentationwise_spike_times(stimulus_presentation_ids, unit_ids);
      
      if isempty(unit_ids)
         unit_ids = unique(spikes.unit_id, 'stable');
      end
      
      % - Set up spike counts table
      [stimulus_presentation_id, unit_id] = ndgrid(stimulus_presentation_ids, unit_ids);
      stimulus_presentation_id = stimulus_presentation_id(:);
      unit_id = unit_id(:);
      spike_count = zeros(size(stimulus_presentation_id));
      spike_counts = table(stimulus_presentation_id, unit_id, spike_count);
      
      if ~isempty(spikes)
         [found_spike_counts, ~, u_indices] = unique(spikes(:, {'stimulus_presentation_id', 'unit_id'}), 'rows');
         found_spike_counts.spike_count = accumarray(u_indices, 1);
         
         for row = 1:size(found_spike_counts, 1)
            % - Fill in spike counts
            spike_count_row = (spike_counts.stimulus_presentation_id == found_spike_counts.stimulus_presentation_id(row)) & ...
               (spike_counts.unit_id == found_spike_counts.unit_id(row));
            spike_counts(spike_count_row, 'spike_count') = found_spike_counts(row, 'spike_count');   
         end
         
         for row = 1:size(spike_counts, 1)
            % - Add stimulus presentation information
            stimulus_row = presentations.stimulus_presentation_id == spike_counts.stimulus_presentation_id(row);
            spike_counts.stimulus_condition_id(row) = presentations.stimulus_condition_id(stimulus_row);
            spike_counts.duration(row) = presentations.duration(stimulus_row);
         end
      end
      
      if use_rates
         spike_counts.spike_rate = spike_counts.spike_count / spike_counts.duration;
         spike_counts = removevars(spike_counts, 'spike_count');
         extractor = @extract_summary_rate_statistics;
      else
         spike_counts = removevars(spike_counts, 'duration');
         extractor = @extract_summary_count_statistics;
      end
      
      [unique_sp, u_indices, sp_indices] = unique(spike_counts(:, {'stimulus_condition_id', 'unit_id'}), 'rows', 'stable');
      
      summary = table();
      for index = 1:numel(u_indices)
         group = spike_counts(sp_indices == u_indices(index), :);
         summary = [summary; extractor(unique_sp(index, :), group)]; %#ok<AGROW>
      end
   end
   
   function param_values = fetch_parameter_values_for_stimulus(self, stimulus_name, drop_nulls)
   % """ For each stimulus parameter, report the unique values taken on by that
   % parameter while a named stimulus was presented.
   %
   % Parameters
   % ----------
   % stimulus_name : str
   %    filter to presentations of this stimulus
   %
   % Returns
   % -------
   % dict :
   %    maps parameters (column names) to their unique values.
      arguments
         self;
         stimulus_name char;
         drop_nulls logical = true;
      end
   
      presentation_ids = self.fetch_stimulus_table(stimulus_name).stimulus_presentation_id;
      param_values = self.fetch_stimulus_parameter_values(presentation_ids, drop_nulls);   
   end
   
   function parameters = fetch_stimulus_parameter_values(self, stimulus_presentation_ids, drop_nulls)
   % fetch_stimulus_parameter_values - METHOD For each stimulus parameter, report the unique values taken on by that parameter throughout the course of the  session
      arguments
         self;
         stimulus_presentation_ids {mustBeNumeric} = [];
         drop_nulls logical = true;
      end

      % - Filter stimulus_presentations table
      stimulus_presentations = self.stimulus_presentations; %#ok<PROPLC>

      if ~isempty(stimulus_presentation_ids)
         select_stimuli = ismember(stimulus_presentations.stimulus_presentation_id, stimulus_presentation_ids); %#ok<PROPLC>
         stimulus_presentations = stimulus_presentations(select_stimuli, :); %#ok<PROPLC>
      end

      stimulus_presentations = removevars(stimulus_presentations, ['stimulus_name' 'stimulus_presentation_id' self.NON_STIMULUS_PARAMETERS]); %#ok<PROPLC>
      stimulus_presentations = remove_unused_stimulus_presentation_columns(stimulus_presentations); %#ok<PROPLC>

      parameters = struct();

      for colname = stimulus_presentations.Properties.VariableNames %#ok<PROPLC>
         uniques = unique(stimulus_presentations.(colname{1})); %#ok<PROPLC>

         is_null = arrayfun(@(s)isequal(s, "null"), uniques);
         is_null = is_null | arrayfun(@(s)isequal(s, ""), uniques);
         if isnumeric(uniques)
            is_null = is_null | isnan(uniques);
         end
         
         non_null = uniques(~is_null);

         if ~drop_nulls && any(is_null)
            non_null = [non_null; nan]; %#ok<AGROW>
         end

         parameters.(colname{1}) = non_null;
      end
   end
   
   function [labels, intervals] = channel_structure_intervals(self, channel_ids)
   % """ find on a list of channels the intervals of channels inserted into particular structures
   %
   % Parameters
   % ----------
   % channel_ids : list
   %    A list of channel ids
   %
   % Returns
   % -------
   % labels : np.ndarray
   %    for each detected interval, the label associated with that interval
   % intervals : np.ndarray
   %    one element longer than labels. Start and end indices for intervals.
   arguments
      self;
      channel_ids {mustBeNumeric};
   end
   
   structure_id_key = "ephys_structure_id";
   structure_label_key = "ephys_structure_acronym";

   channel_ids = sort(channel_ids);
   
   select_channels = ismember(self.channels.id, channel_ids);
   channels_selected = self.channels(select_channels, :);
   
   unique_probes = unique(channels_selected.ephys_probe_id);
   if numel(unique_probes) > 1
      warning("Calculating structure boundaries across channels from multiple probes.")
   end
   
   intervals = nan_intervals(channels_selected.(structure_id_key));
   labels = channels_selected.(structure_label_key)(intervals);
   end
end

%% Private low-level data getter methods
methods
   function nwb_url = nwb_url(bos)
      % nwb_url - METHOD Get the cloud URL for the NWB dtaa file corresponding to this session
      %
      % Usage: nwb_url = nwb_url(bos)
      
      % - Get well known files
      vs_well_known_files = bos.metadata.well_known_files;
      
      % - Find (first) NWB file
      vsTypes = [vs_well_known_files.well_known_file_type];
      cstrTypeNames = {vsTypes.name};
      nwb_file_index = find(cellfun(@(c)strcmp(c, 'EcephysNwb'), cstrTypeNames), 1, 'first');
      
      % - Build URL
      nwb_url = [bos.bot_cache.strABOBaseUrl vs_well_known_files(nwb_file_index).download_link];
   end
end

%% Private methods
methods (Hidden)

      function inter_presentation_intervals = fetch_inter_presentation_intervals_for_stimulus(self, stimulus_names)
         % ''' Get a subset of this session's inter-presentation intervals, filtered by stimulus name.
         %
         % Parameters
         % ----------
         % stimulus_names : array-like of str
         %    The names of stimuli to include in the output.
         %
         % Returns
         % -------
         % pd.DataFrame :
         %    inter-presentation intervals, filtered to the requested stimulus names.
         
         self.cache_stimulus_presentations();
         
         select_stimuli = ismember(self.property_cache.stimulus_presentations_raw.stimulus_name, stimulus_names);
         filtered_presentations = self.property_cache.stimulus_presentations_raw(select_stimuli, :);
         filtered_ids = filtered_presentations.stimulus_presentation_id;
         
         
         select_intervals = ismember(self.inter_presentation_intervals.from_presentation_id, filtered_ids) & ...
            ismember(self.inter_presentation_intervals.to_presentation_id, filtered_ids);
         
         inter_presentation_intervals = self.inter_presentation_intervals(select_intervals, :);
      end
      
      function presentations = fetch_stimulus_table(self, stimulus_names, include_detailed_parameters, include_unused_parameters)
         arguments
            self;
            stimulus_names = self.stimulus_names;
            include_detailed_parameters logical = false;
            include_unused_parameters logical = false;
         end
         % '''Get a subset of stimulus presentations by name, with irrelevant parameters filtered off
         %
         % Parameters
         % ----------
         % stimulus_names : array-like of str
         %    The names of stimuli to include in the output.
         %
         % Returns
         % -------
         % pd.DataFrame :
         %    Rows are filtered presentations, columns are the relevant subset of stimulus parameters
         
         self.cache_stimulus_presentations();
         
         select_stimuli = ismember(self.property_cache.stimulus_presentations_raw.stimulus_name, stimulus_names);
         presentations = self.property_cache.stimulus_presentations_raw(select_stimuli, :);
         
         if ~include_detailed_parameters
            presentations = self.remove_detailed_stimulus_parameters(presentations);
         end
         
         if ~include_unused_parameters
            presentations = remove_unused_stimulus_presentation_columns(presentations);
         end
      end
      
   function fetch_natural_movie_template(self, number) %#ok<INUSD>
      error('BOT:NotImplemented', 'This method is not implemented');

      well_known_files = self.stimulus_templates(self.stimulus_templates.movie_number == number, :); %#ok<UNRCH>
      
      if size(well_known_files, 1) ~= 1
         error('BOT:NotFound', ...
            'Expected exactly one natural movie template with number %d, found %d.', number, size(well_known_files, 1));
      end
      
      download_url = self.bot_cache.strABOBaseUrl + well_known_files.download_link;
      local_filename = self.bot_cache.CacheFile(download_url, well_known_files.path);
      
      %         well_known_files = self.stimulus_templates[self.stimulus_templates["movie_number"] == number]
      %         if well_known_files.shape[0] != 1:
      %             raise ValueError(f"expected exactly one natural movie template with number {number}, found {well_known_files}")
      %
      %         download_link = well_known_files.iloc[0]["download_link"]
      %         return self.rma_engine.stream(download_link)
   end
   
   function fetch_natural_scene_template(self, number) %#ok<INUSD>
      error('BOT:NotImplemented', 'This method is not implemented');
      
      %         well_known_files = self.stimulus_templates[self.stimulus_templates["scene_number"] == number]
      %         if well_known_files.shape[0] != 1:
      %             raise ValueError(f"expected exactly one natural scene template with number {number}, found {well_known_files}")
      %
      %         download_link = well_known_files.iloc[0]["download_link"]
      %         return self.rma_engine.stream(download_link)
   end
   
   function valid_time_points = fetch_valid_time_points(self, time_points, invalid_time_intevals) %#ok<STOUT,INUSD>
      error('BOT:NotImplemented', 'This method is not implemented');
      
      
      %         all_time_points = xr.DataArray(
      %             name="time_points",
      %             data=[True] * len(time_points),
      %             dims=['time'],
      %             coords=[time_points]
      %         )
      %
      %         valid_time_points = all_time_points
      %         for ix, invalid_time_interval in invalid_time_intevals.iterrows():
      %             invalid_time_points = (time_points >= invalid_time_interval['start_time']) & (time_points <= invalid_time_interval['stop_time'])
      %             valid_time_points = np.logical_and(valid_time_points, np.logical_not(invalid_time_points))
      %
      %         return valid_time_points
      
   end
   
   function invalid_times = filter_invalid_times_by_tags(self, tags)
      arguments
         self;
         tags string;
      end
   
      % """
      % Parameters
      % ----------
      % invalid_times: pd.DataFrame
      %    of invalid times
      % tags: list
      %    of tags
      %
      % Returns
      % -------
      % pd.DataFrame of invalid times having tags
      
      invalid_times = self.invalid_times;
      
      if ~isempty(invalid_times)
         mask = cellfun(@(c)any(ismember(string(c), string(tags))), invalid_times.tags);
         invalid_times = invalid_times(mask, :);
      end
   end
   
   function stimulus_presentations = mask_invalid_stimulus_presentations(self, stimulus_presentations)
      arguments
         self;
         stimulus_presentations table;
      end
      % """Mask invalid stimulus presentations
      %
      % Find stimulus presentations overlapping with invalid times
      % Mask stimulus names with "invalid_presentation", keep "start_time" and "stop_time", mask remaining data with np.nan
      %
      % Parameters
      % ----------
      % stimulus_presentations : pd.DataFrame
      %    table including all stimulus presentations
      %
      % Returns
      % -------
      % pd.DataFrame :
      %     table with masked invalid presentations
      
      fail_tags = "stimulus";
      invalid_times_filt = self.filter_invalid_times_by_tags(fail_tags);
      
      is_numeric = table2array(varfun(@isnumeric, stimulus_presentations(1, :)));
      
      for nRowIndex = 1:size(stimulus_presentations, 1)
         sp = stimulus_presentations(nRowIndex, :);
         id = sp.stimulus_presentation_id;
         stim_epoch = [sp.start_time, sp.stop_time];
         
         for invalid_time_index = 1:size(invalid_times_filt, 1)
            it = invalid_times_filt(invalid_time_index, :);
            invalid_interval = [it.start_time, it.stop_time];
            
            if overlap(stim_epoch, invalid_interval)
               sp(1, is_numeric) = {nan};
               sp(1, ~is_numeric) = {""}; %#ok<STRSCALR>
               sp.stimulus_name = "invalid_presentation";
               sp.start_time = stim_epoch(1);
               sp.stop_time = stim_epoch(2);
               sp.stimulus_presentation_id = id;
               stimulus_presentations(nRowIndex, :) = sp;
            end
         end
      end
   end
   
   function output_spike_times = build_spike_times(self, spike_times_raw)
      % - Filter spike times by unit ID
      retained_units = self.units.id;
      select = ismember(uint64(spike_times_raw.unit_id), uint64(retained_units));
      output_spike_times = spike_times_raw(select, :);
   end
   
   function cache_stimulus_presentations(self)
      if ~self.in_cache('stimulus_presentations_raw') || ~self.in_cache('stimulus_conditions_raw')
         % - Read stimulus presentations from NWB file
         stimulus_presentations_raw = self.nwb_file.fetch_stimulus_presentations();
         
         % - Build stimulus presentations tables
         [stimulus_presentations_raw, stimulus_conditions_raw] = self.build_stimulus_presentations(stimulus_presentations_raw);
         
         % - Mask invalid presentations
         stimulus_presentations_raw = self.mask_invalid_stimulus_presentations(stimulus_presentations_raw);
         
         % - Insert into cache
         self.property_cache.stimulus_presentations_raw = stimulus_presentations_raw;
         self.property_cache.stimulus_conditions_raw = stimulus_conditions_raw;
      end
   end
   
   function [stimulus_presentations, stimulus_conditions] = build_stimulus_presentations(~, stimulus_presentations)
      stimulus_presentations = removevars(stimulus_presentations, {'stimulus_index'});
      
      % - Add a "duration" variable
      stimulus_presentations.duration = stimulus_presentations.stop_time - stimulus_presentations.start_time;
      stimulus_presentations_filled = fillmissing(stimulus_presentations, 'constant', inf, 'DataVariables', @isnumeric);
      
      % - Identify unique stimulus conditions
      params_only = removevars_ifpresent(stimulus_presentations_filled, ["start_time", "stop_time", "duration", "stimulus_block", "stimulus_presentation_id", "stimulus_block_id", "id", "stimulus_condition_id"]);
      [stimulus_conditions, stimulus_condition_id_unique, stimulus_condition_id] = unique(params_only, 'rows', 'stable');
      stimulus_presentations.stimulus_condition_id = stimulus_condition_id - 1;
      stimulus_conditions.stimulus_condition_id = stimulus_condition_id_unique - 1;
   end
   
   function units_table = fetch_units_table_from_nwb(self)
      % - Build the units table from the session NWB file
      % - Allen SDK ecephys_session.units
      units_table = self.build_units_table(self.nwb_file.fetch_units());
   end
   
   function units_table = build_units_table(self, units_table) %#ok<INUSD>
      error('BOT:NotImplemented', 'This method is not implemented');
      
%       channels = self.fetch_channels_from_nwb;
%       probes = self.fetch_probes_from_nwb;
%       
%       unmerged_units = units_table;
      %          units_table = merge(units_table, channels, left_on='peak_channel_id', right_index=True, suffixes=['_unit', '_channel']);
      
      
      %     def _build_units_table(self, units_table):
      %         channels = self.channels.copy()
      %         probes = self.probes.copy()
      %
      %         self._unmerged_units = units_table.copy()
      %         table = pd.merge(units_table, channels, left_on='peak_channel_id', right_index=True, suffixes=['_unit', '_channel'])
      %         table = pd.merge(table, probes, left_on='probe_id', right_index=True, suffixes=['_unit', '_probe'])
      %
      %         table.index.name = 'unit_id'
      %         table = table.rename(columns={
      %             'description': 'probe_description',
      %             'local_index_channel': 'channel_local_index',
      %             'PT_ratio': 'waveform_PT_ratio',
      %             'amplitude': 'waveform_amplitude',
      %             'duration': 'waveform_duration',
      %             'halfwidth': 'waveform_halfwidth',
      %             'recovery_slope': 'waveform_recovery_slope',
      %             'repolarization_slope': 'waveform_repolarization_slope',
      %             'spread': 'waveform_spread',
      %             'velocity_above': 'waveform_velocity_above',
      %             'velocity_below': 'waveform_velocity_below',
      %             'sampling_rate': 'probe_sampling_rate',
      %             'lfp_sampling_rate': 'probe_lfp_sampling_rate',
      %             'has_lfp_data': 'probe_has_lfp_data',
      %             'l_ratio': 'L_ratio',
      %             'pref_images_multi_ns': 'pref_image_multi_ns',
      %         })
      %
      %         return table.sort_values(by=['probe_description', 'probe_vertical_position', 'probe_horizontal_position'])
   end
   
   function output_waveforms = build_nwb1_waveforms(self, mean_waveforms) %#ok<STOUT,INUSD>
      %         # _build_mean_waveforms() assumes every unit has the same number of waveforms and that a unit-waveform exists
      %         # for all channels. This is not true for NWB 1 files where each unit has ONE waveform on ONE channel
      
      error('BOT:NotImplemented', 'This method is not implemented');
   end
   
   function output_waveforms = build_mean_waveforms(self, mean_waveforms) %#ok<STOUT,INUSD>
      error('BOT:NotImplemented', 'This method is not implemented');
   end
   
   function intervals = build_inter_presentation_intervals(self)
      self.cache_stimulus_presentations();
      from_presentation_id = self.property_cache.stimulus_presentations_raw.stimulus_presentation_id(1:end-1);
      to_presentation_id = self.property_cache.stimulus_presentations_raw.stimulus_presentation_id(2:end);
      interval = self.property_cache.stimulus_presentations_raw.start_time(2:end) - self.property_cache.stimulus_presentations_raw.stop_time(1:end-1);
      
      intervals = table(from_presentation_id, to_presentation_id, interval);
   end
   
   function df = filter_owned_df(self, key, ids)
      arguments
         self;
         key;
         ids = [];
      end
      
      df = self.(key);
      
      if isempty(ids)
         return;
      end
      
      %          ids = coerce_scalar(ids);
      
      df = df(ids, :);
      
      if isempty(df)
         warning('BOT:Empty', 'Filtering to an empty set of %s!', key);
      end
   end
   
   function warn_invalid_spike_intervals(self)
      fail_tags = self.probes.name;
      fail_tags{end+1} = 'all_probes';
      
      if ~isempty(self.filter_invalid_times_by_tags(fail_tags))
         warning('BOT:InvalidIntervals', ['Session includes invalid time intervals that could be accessed with the attribute `invalid_times`.\n', ...
            'Spikes within these intervals are invalid and may need to be excluded from the analysis.'])
      end
   end
   
   function presentations = remove_detailed_stimulus_parameters(self, presentations)
      matching_vars = ismember(self.DETAILED_STIMULUS_PARAMETERS, presentations.Properties.VariableNames);
      presentations = removevars(presentations, self.DETAILED_STIMULUS_PARAMETERS(matching_vars));
   end
end

%% Static class methods
methods(Static)
   function from_nwb_path(cls, path, nwb_version, api_kwargs) %#ok<INUSD>
      error('BOT:NotImplemented', 'This method is not implemented');
   end
end
end

%% Helper functions

function tiled_data = build_spike_histogram(time_domain, spike_times, unit_ids, binarize, dtype)
arguments
   time_domain;
   spike_times;
   unit_ids;
   binarize logical = false;
   dtype char = '';
end

if isempty(dtype)
   if binarize
      dtype = 'logical';
   else
      dtype = 'uint16';
   end
end

% - Preallocate tiled data
slice_size = [size(time_domain, 1) - 1, size(time_domain, 2)];
tiled_data = zeros([slice_size numel(unit_ids)], dtype);

starts = time_domain(1:end-1, :);
ends = time_domain(2:end, :);

for unit_index = 1:numel(unit_ids)
   unit_id = unit_ids(unit_index);
   data = spike_times(spike_times.unit_id == unit_id, :).spike_times{1};
   
   start_positions = searchsorted(data, starts(:));
   end_positions = searchsorted(data, ends(:), true);
   
   counts = end_positions - start_positions;
   
   if binarize
      tiled_data(:, :, unit_index) = counts > 0;
   else
      tiled_data(:, :, unit_index) = reshape(counts, slice_size);
   end
end

%     time_domain = np.array(time_domain)
%     unit_ids = np.array(unit_ids)
%
%     tiled_data = np.zeros(
%         (time_domain.shape[0], time_domain.shape[1] - 1, unit_ids.size),
%         dtype=(np.uint8 if binarize else np.uint16) if dtype is None else dtype
%     )
%
%     starts = time_domain[:, :-1]
%     ends = time_domain[:, 1:]
%
%     for ii, unit_id in enumerate(unit_ids):
%         data = np.array(spike_times[unit_id])
%
%         start_positions = np.searchsorted(data, starts.flat)
%         end_positions = np.searchsorted(data, ends.flat, side="right")
%         counts = (end_positions - start_positions)
%
%         tiled_data[:, :, ii].flat = counts > 0 if binarize else counts
%
%     return tiled_data
end

function indices = searchsorted(sorted_array, values, right_side)
arguments
   sorted_array;
   values;
   right_side = false;
end

   function insert_idx = find_right(v)
      insert_idx = find(sorted_array <= v, 1, 'last') + 1;
      if isempty(insert_idx)
         insert_idx = numel(sorted_array) + 1;
      end
   end

   function insert_idx = find_left(v)
%       insert_idx = find(sorted_array > v, 1, 'first');
      insert_idx = builtin('ismembc2', false, sorted_array > v) + 1;
%       [~, insert_idx] = builtin('_ismemberhelper', true, sorted_array > v);
      if isempty(insert_idx)
         insert_idx = numel(sorted_array) + 1;
      end
   end

% - Select left or right side lambda
if right_side
   fhFind = @find_right;
else
   fhFind = @find_left;
end

% - Find insertion locations
indices = arrayfun(fhFind, values);
end

function domain = build_time_window_domain(bin_edges, offsets, callback)
arguments
   bin_edges;
   offsets;
   callback function_handle = str2func('@(x)x');
end

[domain, offsets] = ndgrid(bin_edges(:), offsets(:));
domain = callback(domain + offsets);
end


function stimulus_presentations = remove_unused_stimulus_presentation_columns(stimulus_presentations)
is_string_col = varfun(@isstring, stimulus_presentations(1, :), 'OutputFormat', 'uniform');

is_empty_col = varfun(@(c)all(isempty(c)), stimulus_presentations, 'OutputFormat', 'uniform');
is_empty_col(~is_string_col) = is_empty_col(~is_string_col) | varfun(@(c)all(isnan(c)), stimulus_presentations(:, ~is_string_col), 'OutputFormat', 'uniform');
is_empty_col = is_empty_col | varfun(@(c)all(isequal(c, 'null')), stimulus_presentations, 'OutputFormat', 'uniform');

stimulus_presentations = stimulus_presentations(:, ~is_empty_col);
end


function intervals = nan_intervals(array)
%     """ find interval bounds (bounding consecutive identical values) in an array, which may contain nans
%
%     Parameters
%     -----------
%     array : np.ndarray
%
%     Returns
%     -------
%     np.ndarray :
%         start and end indices of detected intervals (one longer than the number of intervals)

intervals = [];
current = 0;

for nIndex = 2:numel(array)
   item = array(nIndex);
   if is_distinct_from(item, current)
      intervals(end+1) = nIndex + 1; %#ok<AGROW>
   end
   current = item;
end

intervals(end+1) = numel(array);
intervals = unique(intervals);
end

function is_distinct = is_distinct_from(left, right)
if isnan(left) && isnan(right)
   is_distinct = false;
else
   is_distinct = ~isequal(left, right);
end
end


% function coerce_scalar(value, message, warn)
% error('BOT:NotImplemented', 'This function is not implemented.');
% end


function t = extract_summary_count_statistics(index, group)
% - Extract statistics
stimulus_condition_id = index.stimulus_condition_id;
unit_id = index.unit_id;
spike_count = sum(group.spike_count);
stimulus_presentation_count = size(group, 1);
spike_mean = mean(group.spike_count);
spike_std = std(group.spike_count);
spike_sem = spike_std/sqrt(numel(group.spike_count));

% - Construct a table
t = table(stimulus_condition_id, unit_id, spike_count, ...
   stimulus_presentation_count, spike_mean, spike_std, spike_sem);
end


function t = extract_summary_rate_statistics(index, group)
% - Extract statistics
stimulus_condition_id = index.stimulus_condition_id;
unit_id = index.unit_id;
stimulus_presentation_count = size(group, 1);
spike_mean = mean(group.spike_rate);
spike_std = std(group.spike_rate);
spike_sem = spike_std/sqrt(numel(group.spike_rate));

% - Construct a table
t = table(stimulus_condition_id, unit_id, ...
   stimulus_presentation_count, spike_mean, spike_std, spike_sem);
end

function is_overlap = overlap(a, b)
%     """Check if the two intervals overlap
%
%     Parameters
%     ----------
%     a : tuple
%         start, stop times
%     b : tuple
%         start, stop times
%     Returns
%     -------
%     bool : True if overlap, otherwise False
is_overlap = max(a(1), b(1)) <= min(a(2), b(2));
end

function source_table = removevars_ifpresent(source_table, variables)
   vbHasVariable = ismember(variables, source_table.Properties.VariableNames);
   
   if any(vbHasVariable)
      source_table = removevars(source_table, variables(vbHasVariable));
   end
end
