function metadata = readRigMetadata(nwbFileName)
% readRigMetadata - Read rig metadata from an NWB file

    import bot.internal.nwb.readDatasetsToStruct
    import bot.internal.nwb.readAttributesToStruct

    DATASET_MAPPING = struct(...
        'camera_position_mm', '/processing/eye_tracking_rig_metadata/eye_tracking_rig_metadata/camera_position', ...
        'camera_rotation_deg', '/processing/eye_tracking_rig_metadata/eye_tracking_rig_metadata/camera_rotation', ...
        'monitor_position_mm', '/processing/eye_tracking_rig_metadata/eye_tracking_rig_metadata/monitor_position', ...
        'monitor_rotation_deg', '/processing/eye_tracking_rig_metadata/eye_tracking_rig_metadata/monitor_rotation', ...
        'led_position', '/processing/eye_tracking_rig_metadata/eye_tracking_rig_metadata/led_position' ...
        );



    ATTRIBUTES_MAPPING = struct(...
        'equipment', {{'/processing/eye_tracking_rig_metadata/eye_tracking_rig_metadata', 'equipment' }} ...
        );

    metadata = readDatasetsToStruct(nwbFileName, DATASET_MAPPING);
    %metadata = structfun(@(v) string(v), metadata, 'UniformOutput', false);

    metadata = bot.internal.util.structmerge(metadata, ...
        readAttributesToStruct(nwbFileName, ATTRIBUTES_MAPPING));

    %metadata = readAttributesToStruct(nwbFileName, ATTRIBUTES_MAPPING);
end
