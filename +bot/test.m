%% Test class for BOT
classdef test < matlab.unittest.TestCase
   
   %% Test methods block
   methods (Test)
      function testCreateCache(testCase) %#ok<*MANU>
         %% Test creating a BOT cache
         boc = bot.internal.cache; %#ok<*NASGU>
      end
      
      function testOphysTables(testCase)
         %% Test retrieving all OPhys manifest tables
         bom = bot.manifest('ophys');
         bom = bot.internal.ophysmanifest;
         bom.tOPhysSessions;                   % Table of all OPhys experimental sessions
         bom.tOPhysContainers;                 % Table of all OPhys experimental containers
      end
      
      function testEphysTables(testCase)
         %% Test retrieving EPhys manifest tables
         bom = bot.manifest('ephys');
         bom = bot.internal.ephysmanifest;
         bom.tEPhysSessions;                 % Table of all EPhys experimental sessions
         bom.tEPhysChannels;                 % Table of all EPhys channels
         bom.tEPhysProbes;                   % Table of all EPhys probes
         bom.tEPhysUnits;                    % Table of all EPhys units
      end
      
      function testGetOPhysSessionFilter(testCase)
         %% Test creating a session filter object
         bosf = bot.util.ophyssessionfilter;
         bosf.clear_filters();
      end
      
      function testOphysSessionFilterGetAllMethods(testCase)
         %% Test the "get all" methods for the OPhys session filter class
         bosf = bot.util.ophyssessionfilter;
         
         bosf.get_all_cre_lines();
         bosf.get_all_imaging_depths();
         bosf.get_all_session_types();
         bosf.get_all_stimuli();
         bosf.get_all_targeted_structures();
      end
      
      function testOPhysSessionFilterGetSummaryMethods(testCase)
         %% Test the "get summary" methods for the OPhys session filter class
         bosf = bot.util.ophyssessionfilter;
         
         bosf.get_summary_of_containers_along_depths_and_structures();
         bosf.get_summary_of_containers_along_imaging_depths();
         bosf.get_summary_of_containers_along_targeted_structures();
         bosf.get_targeted_structure_acronyms();
         bosf.get_total_num_of_containers();
      end
      
      function testOPhysSessionFilterMethods(testCase)
         %% Test using the OPhys session filter filtering methods
         bom = bot.internal.ophysmanifest;
         bosf = bot.util.ophyssessionfilter;
         
         % CRE lines
         cre_lines = bosf.get_all_cre_lines();
         bosf.clear_filters();
         bosf.filter_session_by_cre_line(cre_lines{1});

         % Imaging depth
         im_depths = bosf.get_all_imaging_depths();
         bosf.clear_filters();
         bosf.filter_sessions_by_imaging_depth(im_depths(1));
         
         % Eye tracking
         bosf.clear_filters();
         bosf.filter_session_by_eye_tracking(true);
         
         % Container ID
         tContainers = bom.tOPhysContainers;
         bosf.clear_filters();
         bosf.filter_sessions_by_container_id(tContainers{1, 'id'});
         
         % Session ID
         tSessions = bom.tOPhysSessions;
         bosf.clear_filters();
         bosf.filter_sessions_by_session_id(tSessions{1, 'id'});
         
         % Session type
         session_types = bosf.get_all_session_types();
         bosf.clear_filters();
         bosf.filter_sessions_by_session_type(session_types{1});
         
         % Stimuli
         stimuli = bosf.get_all_stimuli();
         bosf.clear_filters();
         bosf.filter_sessions_by_stimuli(stimuli{1});
         
         % Targeted structures
         structures = bosf.get_all_targeted_structures();
         bosf.clear_filters();
         bosf.filter_sessions_by_targeted_structure(structures{1});
         
         % Get filtered session table
         bosf.filter_sessions_by_targeted_structure(structures{1});
         t = bosf.filtered_session_table;
      end
      
      function testObtainSessionObject(testCase)
         %% Test creation of an OPhys session object
         bosf = bot.util.ophyssessionfilter();
         
         % - Get session IDs
         vIDs = bosf.valid_session_table{:, 'id'};
         
         % - Create some bot.internal.ophyssession objects
         bot.internal.ophyssession(vIDs(1));
         bot.session(vIDs(1:2));
         bot.internal.ophyssession(bosf.valid_session_table(1, :));
      end
      
      function testCacheSessionObject(testCase)
         %% Test obtaining an OPhys session object data from the cache
         % - Create a bot.internal.ophyssession object
         s = bot.internal.ophyssession(704298735);
         
         % - Ensure the data is in the cache
         s.EnsureCached();
      end
      
      function testSessionDataAccess(testCase)
         %% Test data access methods of the bot.internal.ophyssession class for OPhys data
         % - Create a bot.internal.ophyssession object
         s = bot.internal.ophyssession(496934409);

         % - Test summary methods
         vnCellIDs = s.get_cell_specimen_ids();
         s.get_cell_specimen_indices(vnCellIDs);
         s.fetch_nwb_metadata();
         s.get_session_type();
         s.get_roi_ids();
         s.list_stimuli();
         
         % - Test data access methods
         s.get_fluorescence_timestamps();
         s.get_fluorescence_traces();
         s.get_demixed_traces();
         s.get_corrected_fluorescence_traces();
         s.get_dff_traces();
         s.get_max_projection();
         s.get_motion_correction();
         s.get_neuropil_r();
         s.get_neuropil_traces();
         s.get_roi_mask();
         s.get_roi_mask_array();
         s.get_running_speed();
         s.get_pupil_location();
         s.get_pupil_size();
      end
      
      function testStimulusExtraction(testCase)
         %% Test OPhys session stimulus extraction methods
         % - Create a bot.internal.ophyssession object
         s = bot.internal.ophyssession(528402271);

         % - Get a vector of fluorescence frame IDs
         vnFrameIDs = 1:numel(s.get_fluorescence_timestamps());
         
         % - Obtain per-frame stimulus table
         s.get_stimulus(vnFrameIDs);
         
         % - Obtain stimulus summary table
         s.get_stimulus_epoch_table();
         
         % - Get list of stimuli
         cStimuli = s.list_stimuli();
         
         % - Get a stimulus table for each stimulus
         for cThisStim = cStimuli
            s.get_stimulus_table(cThisStim{1});
         end
         
         % - Get a natural movie stimulus template
         s.get_stimulus_template('natural_movie_one');
         
         % - Get a spontantaneous activity stimulus table
         s.get_spontaneous_activity_stimulus_table();
         
         % - Get an OPhys session with sparse noise
         s = bot.internal.ophyssession(566752133);
         
         % - Get the sparse noise stimulus template
         s.get_stimulus_template('locally_sparse_noise_4deg');
         s.get_locally_sparse_noise_stimulus_template('locally_sparse_noise_4deg');
      end      
      
      function testEPhysManifest(testCase)
         %% Test obtaining EPhys objects
         % - Get the EPhys manifest
         bom = bot.internal.ephysmanifest;
         bom = bot.manifest('ephys');
      end
      
      function testEPhysSessions(testCase)
         %% Test obtaining EPhys objects
         % - Get the EPhys manifest
         bom = bot.manifest('ephys');
         
         % - Get a session
         s = bot.session(bom.tEPhysSessions{1, 'id'});
         s = bot.session(bom.tEPhysSessions(1, :));
      end

      function testEPhysProbes(testCase)
         %% Test obtaining EPhys objects
         % - Get the EPhys manifest
         bom = bot.manifest('ephys');
         
         % - Get a probe, by ID and by table
         p = bom.probe(bom.tEPhysProbes{1, 'id'});
         p = bom.probe(bom.tEPhysProbes(1, :));
         p = bom.probe(bom.tEPhysProbes{[1, 2], 'id'});
         
         p = bot.probe(bom.tEPhysProbes{1, 'id'});
         p = bot.probe(bom.tEPhysProbes{[1, 2], 'id'});
      end

      function testEPhysChannels(testCase)
         %% Test obtaining EPhys objects
         % - Get the EPhys manifest
         bom = bot.manifest('ephys');

         % - Get channels, by ID and by table
         c = bom.channel(bom.tEPhysChannels{1, 'id'});
         c = bom.channel(bom.tEPhysChannels(1, :));
         c = bom.channel(bom.tEPhysChannels{[1, 2], 'id'});
         
         c = bot.channel(bom.tEPhysChannels(1, :));
         c = bot.channel(bom.tEPhysChannels{[1, 2], 'id'});
      end

      function testEPhysUnits(testCase)
         %% Test obtaining EPhys objects
         % - Get the EPhys manifest
         bom = bot.manifest('ephys');
         
         % - Get units, by ID and by table
         u = bom.unit(bom.tEPhysUnits{1, 'id'});
         u = bom.unit(bom.tEPhysUnits(1, :));
         u = bom.unit(bom.tEPhysUnits{[1, 2], 'id'});

         u = bot.unit(915956282);
         u = bot.unit([915956282 915956304]);
      end

      function testLFPCSDExtraction(testCase)
         %% Test LFP and CSD extraction
         % - Get the EPhys manifest
         bom = bot.internal.ephysmanifest;
         bom = bot.manifest('ephys');
         
         % - Get a probe, by ID and by table
         p = bom.probe(bom.tEPhysProbes{1, 'id'});
         
         % - Access LFP data
         p.get_lfp();
         
         % - Access CSD data
         p.get_current_source_density();
      end
   end
end