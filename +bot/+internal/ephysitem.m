classdef ephysitem < handle
   properties (SetAccess = protected)
      metadata;
      id;
   end
   
   properties (Hidden = true)
      sPropertyCache;
   end
   
   methods (Access = protected)
      function item = check_and_assign_metadata(item, nID, tManifestTable, strType, varargin)
         % - Check usage
         if istable(nID)
            assert(size(nID, 1) == 1, 'BOT:Usage', 'Only a single table row may be provided.')
            tItem = nID;
         else
            assert(isnumeric(nID), 'BOT:Usage', '`nID` must be an integer ID.');
            nID = uint32(round(nID));
            
            % - Locate an ID in the manifest table
            vbTableRow = tManifestTable.id == nID;
            if ~any(vbTableRow)
               error('BOT:Usage', 'Item not found in %s manifest.', strType);
            end
            
            tItem = tManifestTable(vbTableRow, :);
         end
         
         % - Assign the table data to the metadata structure
         item.metadata = table2struct(tItem);
         item.id = item.metadata.id;
      end
   end   
   
   methods (Access = protected)
      function oData = get_cached(self, strProperty, fhAccessFun)
         % - Check for cached property
         if ~isfield(self.sPropertyCache, strProperty)
            % - Use the access function
            self.sPropertyCache.(strProperty) = fhAccessFun();
         end
         
         % - Return the cached property
         oData = self.sPropertyCache.(strProperty);
      end
      
      function bInCache = in_cache(self, strProperty)
         bInCache = isfield(self.sPropertyCache, strProperty) && ~isempty(self.sPropertyCache.(strProperty));
      end
   end
end