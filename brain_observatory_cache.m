classdef brain_observatory_cache < handle
    
% add help file information!!!    
%    
%
% this will appear


    
    properties
        session_table
        container_table
        manifests
        filtered_session_table
        stimuli
        targeted_structure
        imaging_depth
        container_id
        session_id
        session_type
        
    end
    
    properties (Access = private)
        failed = 0
        need_restriction_on_property = 1
    end
    
    methods
        
        % initialize
        function boc = brain_observatory_cache(manifests)
            
            boc.session_table = manifests.session_manifest;
            boc.container_table = manifests.container_manifest;
            boc.manifests = manifests;
            
            % get rid of failed ones
            if boc.failed == 0
                failed_container_id = boc.container_table((boc.container_table.failed == 1),:).id;
                boc.session_table = boc.session_table(~ismember(boc.session_table.experiment_container_id,failed_container_id),:);
                boc.container_table = boc.container_table((boc.container_table.failed ~= 1),:);          
            end
            
            boc.filtered_session_table =  boc.session_table;
            
            boc.update_properties;
        end
        
        
        % This function gets the total number of experiment containers
        function result = get_total_num_of_containers(boc)
            result = size(boc.container_table(boc.container_table.failed==0,:),1);
        end
        
        
        
        function result = get_all_imaging_depths(boc)
            result = unique(boc.filtered_session_table.imaging_depth);
        end
        
         function result = get_all_targeted_structures (boc)
            if size(boc.filtered_session_table,1) > 1
                container_targeted_structure_table = struct2table(boc.filtered_session_table.targeted_structure);
            result = categories(categorical(cellstr(container_targeted_structure_table.acronym)));
            elseif size(boc.filtered_session_table,1) == 1
                result = boc.filtered_session_table.targeted_structure.acronym;
            end
           
        end
        
         
        function result = get_all_session_types (boc)
            result = categories(categorical(cellstr(boc.filtered_session_table.stimulus_name)));
        end
        
        
        function result = get_all_stimuli (boc)
            session_by_stimuli = boc.get_session_by_stimuli();
            result = [];
            for iSession = 1: length(boc.session_type)
                result = [result, session_by_stimuli.(char(boc.session_type(iSession)))];
            end
            result = categories(categorical(result));
        end
        
        
        
        function result = get_all_cre_lines (boc)
            result = categories(categorical(boc.container_table.cre_lines));
        end
        
        function get_summary_of_containers_along_imaging_depths(boc)
            summary(categorical(cellstr(num2str((boc.container_table.imaging_depth)))))
        end
        
          
        function get_summary_of_containers_along_targeted_structures (boc)
            container_targeted_structure_table = struct2table(boc.container_table.targeted_structure);
            summary(categorical(cellstr(container_targeted_structure_table.acronym)))
        end
        
        
       
        
        function summary_table = get_summary_of_containers_along_depths_and_structures(boc)
            
            summary_matrix = NaN(size(boc.get_all_imaging_depths(),1),size(boc.get_all_targeted_structures(),1));
            all_depths =  boc.get_all_imaging_depths();
            all_structures = boc.get_all_targeted_structures;
            boc.need_restriction_on_property = 0;
            
            
            for cur_depth = 1: size(boc.get_all_imaging_depths(),1)
                for cur_structure = 1: size(boc.get_all_targeted_structures,1)
                    boc.filter_sessions_by_imaging_depth(all_depths(cur_depth));
                    boc.filter_sessions_by_targeted_structure(string(all_structures(cur_structure)));
                    total_of_containers = size(boc.filtered_session_table,1)/3;
                    summary_matrix(cur_depth,cur_structure) = total_of_containers;
                    boc.refresh();
                end
            end
            
                        all_depths = cellstr(num2str( boc.get_all_imaging_depths()));

            summarize_by_depths = sum(summary_matrix,2);
            summary_matrix = [summary_matrix,summarize_by_depths];
            summarize_by_structures = sum(summary_matrix,1);
            summary_matrix = [summary_matrix; summarize_by_structures];
            summary_table = array2table(summary_matrix);
            summary_table.Properties.VariableNames = [all_structures;'total'];
            summary_table.Properties.RowNames = [all_depths;'total'];
            
        end
        
        
        
        
        function result = get.filtered_session_table(boc)
            if boc.need_restriction_on_property == 1 && isempty(boc.filtered_session_table)
                error(sprintf(['Not a single session meet all of your criteria\n'...
                    ' The last criterion has been declined\n '...
                    ' !!!This is not a bug. It is not my fault!!!\n'...
                    'Actually, if I do not yell at you for killing all sessions, Matlab will'...
                    ' yell at me for indexing an empty table.\n'...
                    'Sorry about that...']))
            else
                result = boc.filtered_session_table;
            end
        end
        
        
       
        
        
       
        
      
        
        % get_session_by_session_id
        function boc = filter_sessions_by_session_id(boc,session_id)
            
            boc.filtered_session_table = boc.filtered_session_table(boc.filtered_session_table.id == session_id, :);
            
            boc.update_properties
        
        end
        
        
        
        
        function boc = filter_sessions_by_container_id(boc,container_id)
            boc.filtered_session_table = boc.filtered_session_table(boc.filtered_session_table.experiment_container_id == container_id, :);
            
            boc.update_properties
        
        end
        
        
        
        function boc = filter_sessions_by_stimuli(boc,stimuli)
            session_by_stimuli = boc.get_session_by_stimuli();
            % filter sessions by stimuli
            boc.filtered_session_table =  boc.filtered_session_table(ismember(boc.filtered_session_table.stimulus_name,...
                boc.find_session_for_stimuli(stimuli,session_by_stimuli)), :);
            
           
            boc.update_properties
            
        end
        
        
        
        function boc = filter_sessions_by_imaging_depth(boc,depth)
            % filter sessions by imaging_depth
            boc.filtered_session_table = boc.filtered_session_table(boc.filtered_session_table.imaging_depth == depth, :);
            
            boc.update_properties
        end
        
        
        function boc = filter_sessions_by_targeted_structure(boc,structure)
            % filter sessions by targeted_structure
            if size(boc.filtered_session_table,1) > 1
                exp_targeted_structure_session_table = struct2table(boc.filtered_session_table.targeted_structure);
                boc.filtered_session_table = boc.filtered_session_table(ismember(exp_targeted_structure_session_table.acronym, structure), :);
            elseif size(boc.filtered_session_table,1) == 1
                boc.filtered_session_table = boc.filtered_session_table(strcmp( boc.filtered_session_table.targeted_structure.acronym, structure),:);
            end
          
            
            boc.update_properties
        end
        
         function refresh(boc)
            
            boc.session_table = boc.manifests.session_manifest;
            boc.container_table = boc.manifests.container_manifest;
            
            % remove failed containers
            if boc.failed == 0
                failed_container_id = boc.container_table((boc.container_table.failed == 1),:).id;
                boc.session_table = boc.session_table(~ismember(boc.session_table.experiment_container_id,failed_container_id),:);
                boc.container_table = boc.container_table((boc.container_table.failed ~= 1),:);
            end
            boc.filtered_session_table =  boc.session_table;
            
        end
        
        
        
        
        function download_nwb(boc, save_directory_name)
            
            % prepare folder
            if ~exist(save_directory_name,'dir')
                mkdir(save_directory_name)
            end
            
            % get the NWB file URL for filtered sessions
            allen_institute_base_url = 'http://api.brain-map.org';
            for cur = 1 : size(boc.filtered_session_table,1)
                cur_url = boc.filtered_session_table(cur, :). well_known_files.download_link;
                full_url = [allen_institute_base_url cur_url];
                cur_id = boc.filtered_session_table(cur, :).id;
                save_file_name = [save_directory_name num2str(cur_id) '.nwb'];
                if ~exist(save_file_name,'file')
                    fprintf('downloading the nwb file')
                    tic
                    websave(save_file_name, full_url);
                    fprintf('the new nwb file is finally donwloaded')
                    toc
                else
                    fprintf('desired nwb file already exists')
                end
            end
        end % end of function get_session_data
    end % end of public dynamic methods
    
    methods (Access = private)
        
        function update_properties(boc)
            
            if boc.need_restriction_on_property == 1
            % update session_type
            boc.session_type = boc.get_all_session_types;
            
            % update session_id
            boc.session_id = boc.filtered_session_table.id;
            
            % update stimuli
            boc.stimuli = boc.get_all_stimuli;
            
            % update imaging_depth
            boc.imaging_depth = boc.get_all_imaging_depths;
            
            % update targeted_structure
            boc.targeted_structure = boc.get_all_targeted_structures;
            
            % update container_id
            boc.container_id = unique(boc.filtered_session_table.experiment_container_id);
            end
 
        end
         
       
    end % end of private dynamic methods
    
    
    methods (Static  =  true, Access = private)
        
        function filtered_session = find_session_for_stimuli(stimuli,session_by_stimuli)
            filtered_session = {};
            fields = fieldnames(session_by_stimuli);
            for i = 1 :length(fields)
                if sum(ismember(session_by_stimuli.(char(fields(i))),stimuli)) >= 1
                    filtered_session(length(filtered_session)+1) = cellstr(fields(i));
                end
            end
        end
        
        function session_by_stimuli = get_session_by_stimuli()
            session_by_stimuli.three_session_A = {'drifting_gratings','natural_movie_one','natural_movie_three','spontaneous_activity'};
            session_by_stimuli.three_session_B = {'static_gratings','natural_scene','natural_movie_one','spontaneous_activity'};
            session_by_stimuli.three_session_C = {'locally_sparse_noise_four_degree','natural_movie_one','natural_movie_two','spontaneous_activity'};
            session_by_stimuli.three_session_C2 = {'locally_sparse_noise_four_degree','locally_sparse_noise_eight_degree', ...
                'natural_movie_one','natural_movie_two','spontaneous_activity'};
        end
    end % end of static method
end % end of class