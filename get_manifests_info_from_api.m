% download contain_manifest, seesion_manifest, cell_speciman_mapping from brain observatory api as
% matlab tables, and store them in a struct called "references" for further
% reference

function manifests = get_manifests_info_from_api(varargin)
tic
if (nargin > 0 && ~exist([char(varargin) 'manifests.mat'],'file'))|| nargin == 0
    
    container_manifest_url = 'http://api.brain-map.org/api/v2/data/query.json?q=model::ExperimentContainer,rma::include,ophys_experiments,isi_experiment,specimen%28donor%28conditions,age,transgenic_lines%29%29,targeted_structure,rma::options%5Bnum_rows$eq%27all%27%5D%5Bcount$eqfalse%5D';
    session_manifest_url = 'http://api.brain-map.org/api/v2/data/query.json?q=model::OphysExperiment,rma::include,experiment_container,well_known_files%28well_known_file_type%29,targeted_structure,specimen%28donor%28age,transgenic_lines%29%29,rma::options%5Bnum_rows$eq%27all%27%5D%5Bcount$eqfalse%5D';
    cell_id_mapping_url = 'http://api.brain-map.org/api/v2/well_known_file_download/590985414';
    
    options1 = weboptions('ContentType','JSON','TimeOut',60);
    
    container_manifest_raw = webread(container_manifest_url,options1);
    manifests.container_manifest = struct2table(container_manifest_raw.msg);
    
    session_manifest_raw = webread(session_manifest_url,options1);
    manifests.session_manifest = struct2table(session_manifest_raw.msg);
    
    options2 = weboptions('ContentType','table','TimeOut',60);
    
    manifests.cell_id_mapping = webread(cell_id_mapping_url,options2);
    
    % create cre_lines table and append it to container_manifest table (all experiments within an experiment container
    % were performed on a single rat and shared imaging plane
    cont_table = manifests.container_manifest;
    cre_lines = cell(size(cont_table,1),1);
    for i = 1:size(cont_table,1)
        donor_info = cont_table(i,:).specimen.donor;
        transgenic_lines_info = struct2table(donor_info.transgenic_lines);
        cre_lines(i,1) = transgenic_lines_info.name(string(transgenic_lines_info.transgenic_line_type_name) == 'driver' & ...
            contains(transgenic_lines_info.name, 'Cre'));
    end
    
    manifests.container_manifest = [cont_table, cre_lines];
    manifests.container_manifest.Properties.VariableNames{'Var13'} = 'cre_line';
    
    if nargin == 1
    save([char(varargin) 'manifests.mat'],'manifests')
    toc
    end
    
else 
    fprintf([char(varargin) 'manifests.mat' ' already exists'])
    
end

end



