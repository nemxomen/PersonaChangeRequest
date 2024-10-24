public with sharing class PersonaChangeRequestHandler {
    
    public static void handleBeforeInsertUpdate(List<Persona_Change_Request__c> requests) {
        List<PersonaChangeRequestEvent__e> events = new List<PersonaChangeRequestEvent__e>();
        for (Persona_Change_Request__c request : requests) {
            if (String.isBlank(request.MirrorAs__c)) {
                // Call the getPersona method to retrieve the PersonaInfo
                PersonaInfo personaInfo = PersonaInfo.getPersona(request.Persona__c);
                personaInfo.validatePersona();
                // Check if the persona was retrieved successfully
                if (personaInfo.hasErrors) {
                    // // If there are validation errors, update the change request record with the error message
                    request.Status__c = 'Rejected'; 
                    request.Error_Message__c = personaInfo.errorMessage.length()>255 ? (personaInfo.errorMessage).substring(0,255): personaInfo.errorMessage;
                } else {

                    Boolean hasRevert = checkRevertExists(request.Requested_By__c);
                    // Proceed with the update logic if validation is successful
                    try {
                        // List<Id> users = new List<Id>();
                        // users.add(request.Requested_By__c);
                        PersonaChangeRequestEvent__e eventInstance = new PersonaChangeRequestEvent__e(
                            Persona__c = request.Persona__c,
                            UserId__c = request.Requested_By__c,     
                            FromApp__c = true,
                            IsRevert__c = false,
                            HasRevert__c = hasRevert,
                            MirrorAs__c = false
                        );
                        events.add(eventInstance);
                        //updateUserWithPersona(personaInfo.personaName, users, true, false, hasRevert);
                    } catch (Exception e) {
                        // Handle any exceptions and update the change request record with the error
                        request.Status__c = 'Rejected'; 
                        request.Error_Message__c = ('Error updating user: ' + e.getMessage()).length()>255 ? ('Error updating user: ' + e.getMessage()).substring(0,255): ('Error updating user: ' + e.getMessage());
                    }
                }
            } else if (String.isNotBlank(request.MirrorAs__c)) {
                Boolean hasRevert = checkRevertExists(request.Requested_By__c);
                // Proceed with the update logic if validation is successful
                // Persona name is blank
                try {
                    // List<Id> users = new List<Id>();
                    // users.add(request.Requested_By__c);
                        PersonaChangeRequestEvent__e eventInstance = new PersonaChangeRequestEvent__e(
                            Persona__c = request.JSON_MirrorAs_Blob__c,
                            UserId__c = request.Requested_By__c,     
                            FromApp__c = true,
                            IsRevert__c = true,
                            HasRevert__c = hasRevert,
                            MirrorAs__c = true
                        );
                        events.add(eventInstance);
                    //updateUserWithPersona(request.JSON_MirrorAs_Blob__c, users, true, true, hasRevert);
                } catch (Exception e) {
                    // Handle any exceptions and update the change request record with the error
                    request.Status__c = 'Rejected'; 
                    request.Error_Message__c = ('Error updating user: ' + e.getMessage()).length()>255 ? ('Error updating user: ' + e.getMessage()).substring(0,255): ('Error updating user: ' + e.getMessage());
                }
            }else {
                // Persona name is blank
                request.Status__c = 'Rejected'; 
                request.Error_Message__c = 'Persona name is blank';
            }
          
        }
        // Publish platform events
        if (!events.isEmpty()) {
            EventBus.publish(events);
        }

    }

    public static void updateUserWithPersona(String persona, List<Id> users, Boolean fromApp, Boolean isRevert, Boolean hasRevert, Boolean mirrorAs) {
        SavePoint sp;
        try{
            PersonaInfo pi = isRevert ==false ? PersonaInfo.getPersona(persona) : PersonaInfo.fromJson(persona);

            if(hasRevert){
                Persona_Change_Request__c revertRecord = [SELECT Id,JSON_Revert_Blob__c FROM Persona_Change_Request__c WHERE IsActive__c=true AND RecordType.Name = 'Original Persona' AND Requested_By__c=:users[0] LIMIT 1][0];
                PersonaInfo op = PersonaInfo.fromJson(revertRecord.JSON_Revert_Blob__c);
                //removes any changes between persona switches that were not on original persona if any before reverting
                pi.userAttributeMap = injectOriginalPersonaAttributes(op.userAttributeMap,pi.userAttributeMap);

            }   

            if(!isRevert){
                pi.validatePersona();
                
            }

            
            // Create a map to hold lists of sObjects for different operations
            Map<String, Map<String, List<sObject>>> sObjectMap = new Map<String, Map<String, List<sObject>>>(); 

            // Create lists to hold the records for insertion/updation
            List<User> usersToUpdatePerms = new List<User>();
            List<User> usersToUpdateProfile = new List<User>();
            List<PermissionSetAssignment> psAssignments = new List<PermissionSetAssignment>();
            List<PermissionSetAssignment> psgAssignments = new List<PermissionSetAssignment>();
            List<GroupMember> groupMembers = new List<GroupMember>();

            // Lists to hold records for deletion
            List<PermissionSetAssignment> psAssignmentsToDelete = new List<PermissionSetAssignment>();
            List<PermissionSetAssignment> psgAssignmentsToDelete = new List<PermissionSetAssignment>();
            List<GroupMember> groupMembersToDelete = new List<GroupMember>();

            // Lists for existing records
            List<PermissionSetAssignment> existingPsAssignments;
            List<PermissionSetAssignment> existingPsgAssignments;
            List<GroupMember> existingGroupMembers;

            // Validate persona attributes and fetch necessary information
            // Assuming the PersonaInfo class has a method to get validated attributes
            if (!pi.hasErrors) {

                if(pi.permissionSets.size()>0 || pi.isPermissionSetTrueUp|| isRevert){
                    // Fetch existing permission set assignments for the users
                    existingPsAssignments = [
                    SELECT Id, PermissionSet.Name, AssigneeId, PermissionSetId,PermissionSetGroupId, PermissionSet.IsOwnedByProfile 
                    FROM PermissionSetAssignment 
                    WHERE AssigneeId IN :users and PermissionSetGroupId =null
                ];
                }

                if(pi.permissionSetGroups.size()>0 || pi.isPermissionSetGroupTrueUp|| isRevert){
                // Fetch existing permission set group assignments for the users
                existingPsgAssignments = [
                    SELECT Id, AssigneeId, PermissionSetGroupId, PermissionSet.IsOwnedByProfile
                    FROM PermissionSetAssignment 
                    WHERE AssigneeId IN :users and PermissionSetGroupId !=null
                ];
                }

                if(pi.publicGroups.size()>0 || pi.isPublicGroupTrueUp|| isRevert){
                // Fetch existing group members for the users
                existingGroupMembers = [
                    SELECT Id, UserOrGroupId, GroupId 
                    FROM GroupMember 
                    WHERE UserOrGroupId IN :users
                ];
                }

                // Fetch the user records that need to be updated
                List<User> usersToUpdate = dynamicQuery(pi,users); 

                // Create a map to hold the users being updated for efficient lookup
                Map<Id, User> userMap = new Map<Id, User>(usersToUpdate);

                // List to hold users that need to be updated
                List<User> usersToUpdateDML = new List<User>();

                Map<String, Schema.SObjectField> userFields = Schema.sObjectType.User.fields.getMap();

                // Step 2: Compare values and prepare for DML
                for (Id user : users) {
                    User currentUser = userMap.get(user);
                    if (currentUser != null) {
                        Boolean hasChanges = false;
                        User userUpdate = new User(Id = user);

                        // Update Profile if needed
                        if (currentUser.ProfileId != pi.profileId) {
                            userUpdate.put('ProfileId',pi.profileId );
                            hasChanges = true;
                        }

                        // Update Profile if needed
                        if (currentUser.UserRoleId != pi.roleId) {
                            userUpdate.put('UserRoleId',pi.roleId );
                            hasChanges = true;
                        }

                        // Check userCustomFieldMap for changes
                        for (String customAttr : pi.userAttributeMap.keySet()) {
                            if (currentUser.get(customAttr) != pi.userAttributeMap.get(customAttr)) {
                                SObjectField sf = userFields.get(customAttr);
                                String fieldType = String.valueOf(sf.getDescribe().getType());
                                
                                // Retrieve the value from userCustomFieldMap
                                String fieldValue = pi.userAttributeMap.get(customAttr);
                                
                                // Check the field type and cast/parse accordingly
                                if(!String.isBlank(fieldValue)){
                                    switch on fieldType {
                                        when 'BOOLEAN' {
                                            userUpdate.put(customAttr, Boolean.valueOf(fieldValue));
                                        }
                                        when 'DATE' {
                                            userUpdate.put(customAttr, Date.valueOf(fieldValue));
                                        }
                                        when 'DATETIME' {
                                            userUpdate.put(customAttr, DateTime.valueOf(fieldValue));
                                        }
                                        when 'INTEGER' {
                                            userUpdate.put(customAttr, Integer.valueOf(fieldValue));
                                        }
                                        when 'DOUBLE' {
                                            userUpdate.put(customAttr, Double.valueOf(fieldValue));
                                        }
                                        when 'STRING' {
                                            userUpdate.put(customAttr, fieldValue);
                                        }
                                        when 'CURRENCY' {
                                            userUpdate.put(customAttr, Decimal.valueOf(fieldValue));
                                        }
                                        when 'PERCENT' {
                                            userUpdate.put(customAttr, Decimal.valueOf(fieldValue));
                                        }
                                        when 'PHONE', 'URL', 'EMAIL', 'TEXTAREA' {
                                            // For field types that are essentially text-based, treat them as strings
                                            userUpdate.put(customAttr, fieldValue);
                                        }
                                        when else {
                                            // Handle other types as needed
                                            System.debug('Unhandled field type: ' + fieldType);
                                            throw new NullPointerException();
                                            
                                        }
                                    }
                                }else{
                                    //just try to let user nullify values a string
                                    System.debug(customAttr +' value: ' + fieldValue);
                                    userUpdate.put(customAttr, null);
                                }
     
                                hasChanges = true;
                            }
                        }

                        // If there are changes, add to the list for DML
                        if (hasChanges) {
                            usersToUpdateDML.add(userUpdate);
                            System.System.debug(userUpdate);
                        }

                        // Add permission sets and groups only if the corresponding boolean is false
                        if(pi.permissionSets.size()>0){
                            Set<Id> permissionSetUpdates = isPermissionSetAssigned(user, pi.permissionSets, existingPsAssignments);

                            if (!permissionSetUpdates.isEmpty()) {
                                for (Id psaID : permissionSetUpdates) {
                                    PermissionSetAssignment psa = new PermissionSetAssignment();
                                    psa.AssigneeId = user;
                                    psa.PermissionSetId = psaID;
                                    psAssignments.add(psa);
                                }
                                System.debug('Assigned user to PermissionSet(s): ' + currentUser.Name);
                            }
                        }

                        // Identify PermissionSetAssignments to delete
                        if(pi.isPermissionSetTrueUp || isRevert){
                            for (PermissionSetAssignment psa : existingPsAssignments) {
                                if (psa.AssigneeId == user && !pi.permissionSets.contains(psa.PermissionSetId) && !psa.PermissionSet.IsOwnedByProfile && psa.PermissionSet.Name!='PersonaChangeRequestApp') {
                                    psAssignmentsToDelete.add(psa);
                                }
                            }
                        }

                        // Add permission sets and groups only if the corresponding boolean is false
                        if(pi.permissionSetGroups.size()>0){
                            Set<Id> permissionSetGroupUpdates = isPermissionSetGroupAssigned(user, pi.permissionSetGroups, existingPsgAssignments);

                            if (!permissionSetGroupUpdates.isEmpty()) {
                                for (Id psgaID : permissionSetGroupUpdates) {
                                    PermissionSetAssignment psga = new PermissionSetAssignment();
                                    psga.AssigneeId = user;
                                    psga.PermissionSetGroupId = psgaID;
                                    psgAssignments.add(psga);
                                }
                                System.debug('Assigned user to PermissionSetGroup(s): ' + currentUser.Name);
                            } 
                        }

                        // Identify PermissionSetGroupAssignments to delete
                        if(pi.isPermissionSetGroupTrueUp || isRevert){
                            for (PermissionSetAssignment psga : existingPsgAssignments) {
                                if (psga.AssigneeId == user && !pi.permissionSetGroups.contains(psga.PermissionSetGroupId) && !psga.PermissionSet.IsOwnedByProfile) {
                                    psgAssignmentsToDelete.add(psga);
                                }
                            }
                        }

                        // Add permission sets and groups only if the corresponding boolean is false
                        if(pi.publicGroups.size()>0){
                            Set<Id> groupMemberUpdates = isUserInGroup(user, pi.publicGroups, existingGroupMembers);
                            if (!groupMemberUpdates.isEmpty()) {
                                for (Id gmID : groupMemberUpdates) {
                                    GroupMember gm = new GroupMember();
                                    gm.UserOrGroupId = user;
                                    gm.GroupId = gmID;
                                    groupMembers.add(gm);
                                }
                                System.debug('Assigned user to public group(s): ' + currentUser.Name);
                            } 
                        
                        }

                        // Identify GroupMembers to delete
                        if(pi.isPublicGroupTrueUp || isRevert){
                            for (GroupMember gm : existingGroupMembers) {
                                if (gm.UserOrGroupId == user && !pi.publicGroups.contains(gm.GroupId)) {
                                    groupMembersToDelete.add(gm);
                                }
                            }
                        }

                    }
                }

                sp = Database.setSavepoint();
                // add all potential updates to master map
                addToSObjectMap(sObjectMap, 'PSA', 'insert', psAssignments);
                addToSObjectMap(sObjectMap, 'PSA', 'delete', psAssignmentsToDelete);
                addToSObjectMap(sObjectMap, 'PSGA', 'insert', psgAssignments);
                addToSObjectMap(sObjectMap, 'PSGA', 'delete', psgAssignmentsToDelete);
                addToSObjectMap(sObjectMap, 'GM', 'insert', groupMembers);
                addToSObjectMap(sObjectMap, 'GM', 'delete', groupMembersToDelete);
                addToSObjectMap(sObjectMap, 'Users', 'update', usersToUpdateDML);

                // Call the utility method to process all the sObject lists
                processSObjectMap(sObjectMap);

                if(fromApp){
                    updatePersonaRequestSuccess(users, isRevert, mirrorAs);
                }

            } else {
                // Handle validation errors if personaInfo is not valid
                // You can log or throw an exception here as per your requirements
                System.debug('Invalid PersonaInfo: ' + pi.errorMessage);
                if(fromApp){
                    updatePersonaRequestRejected (users, 'Invalid PersonaInfo: ' + pi.errorMessage, isRevert, mirrorAs);
                }
            }

    } catch (Exception e) {
        // Handle any exceptions and update the change request record with the error
        System.debug('Error updating user: ' + + e.getMessage());
        Database.rollback(sp);
        if(fromApp){
            updatePersonaRequestRejected (users, 'Error updating user: ' + e.getMessage(), isRevert, mirrorAs);
        }
        
 
    }


    }

    @future
    public static void updatePersonaRequestSuccess(List<Id> users, Boolean isRevert, Boolean mirrorAs){
        if(isRevert && !mirrorAs){
            Persona_Change_Request__c revertRecord = [SELECT Id, CreatedDate, IsActive__c, Status__c,Error_Message__c FROM Persona_Change_Request__c WHERE IsActive__c=true AND RecordType.Name = 'Original Persona' AND Requested_By__c =:users Order By CreatedDate Desc LIMIT 1][0];
            revertRecord.IsActive__c = false;
            revertRecord.Error_Message__c = '';
            revertRecord.Status__c = 'Reverted';
            update revertRecord;
        }else {
            Persona_Change_Request__c request = [SELECT Id, CreatedDate, Status__c FROM Persona_Change_Request__c WHERE Requested_By__c =:users AND RecordType.Name = 'Change Request' AND Status__c ='Pending' Order By CreatedDate Desc LIMIT 1][0];
            request.Status__c = 'Changed';
            update request;
        }
       

    }

    @future
    public static void updatePersonaRequestRejected(List<Id> users, String errorMessage, Boolean isRevert, Boolean mirrorAs){
        if(isRevert && !mirrorAs){
            Persona_Change_Request__c revertRecord = [SELECT Id, CreatedDate, IsActive__c, Status__c,Error_Message__c FROM Persona_Change_Request__c WHERE IsActive__c=true AND RecordType.Name = 'Original Persona' AND Requested_By__c =:users Order By CreatedDate Desc LIMIT 1][0];
            revertRecord.Error_Message__c = errorMessage.length()>255 ? (errorMessage).substring(0,255): errorMessage;
            revertRecord.Status__c = 'Rejected';
            update revertRecord;
        }else{
            Persona_Change_Request__c request = [SELECT Id, CreatedDate, Status__c, Error_Message__c FROM Persona_Change_Request__c WHERE Requested_By__c =:users AND RecordType.Name = 'Change Request' AND Status__c ='Pending' Order By CreatedDate Desc LIMIT 1][0];
            request.Error_Message__c = errorMessage.length()>255 ? (errorMessage).substring(0,255): errorMessage;
            request.Status__c = 'Rejected';
            update request;
        }
        

    }
    
    public static Map<String, String> injectOriginalPersonaAttributes(Map<String, String> originalAttributes, Map<String, String> personaAttributes) {
        // Create a copy of personaAttributes so as not to modify the original map
        Map<String, String> updatedAttributes = new Map<String, String>(personaAttributes);
    
        // Iterate over the original attributes
        for (String key : originalAttributes.keySet()) {
            // Only add the attribute if it's not already present in personaAttributes
            if (!updatedAttributes.containsKey(key)) {
                updatedAttributes.put(key, originalAttributes.get(key));
            }
        }
    
        return updatedAttributes;
    }


        // Helper methods to get IDs from sObject lists
    public static Set<Id> getIdsFromList(List<sObject> records) {
        Set<Id> ids = new Set<Id>();
        for (sObject record : records) {
            if (record != null && record.get('Id') != null) {
                ids.add((Id) record.get('Id'));
            }
        }
        return ids;
    }

    // Helper methods to check if a user has an assignment or group membership
    public static Set<Id> isPermissionSetAssigned(Id userId, Set<Id> permissionSet, List<PermissionSetAssignment> existingAssignments) {
        Set<Id> found = new Set<Id>(permissionSet);
        for (PermissionSetAssignment assignment : existingAssignments) {
            if (assignment.AssigneeId == userId) {
                found.remove(assignment.PermissionSetId);
            }
        }
        return found;
    }

    public static Set<Id> isPermissionSetGroupAssigned(Id userId, Set<Id> permissionSetGroup, List<PermissionSetAssignment> existingAssignments) {
        Set<Id> found = new Set<Id>(permissionSetGroup);
        for (PermissionSetAssignment assignment : existingAssignments) {
            if (assignment.AssigneeId == userId) {
                found.remove(assignment.PermissionSetGroupId);
            }
        }
        return found;
    }

    public static Set<Id> isUserInGroup(Id userId, Set<Id> publicGroup, List<GroupMember> existingGroupMembers) {
        Set<Id> found = new Set<Id>(publicGroup);
        for (GroupMember gm : existingGroupMembers) {
            if (gm.UserOrGroupId == userId) {
                found.remove(gm.GroupId);
            }
        }
        return found;
    }

    // Utility method to process the sObject map for DML operations
    public static void processSObjectMap(Map<String, Map<String, List<sObject>>> sObjectMap) {
        for (String sObjectType : sObjectMap.keySet()) {
            Map<String, List<sObject>> operationMap = sObjectMap.get(sObjectType);
            for (String operation : operationMap.keySet()) {
                List<sObject> records = operationMap.get(operation);
                
                // Perform the appropriate DML operation based on the key (insert, update)
                if (operation == 'insert' && !records.isEmpty()) {
                    insert records;
                    System.debug('Inserted ' + records.size() + ' records for ' + sObjectType);
                } else if (operation == 'update' && !records.isEmpty()) {
                    update records;
                    System.debug('Updated ' + records.size() + ' records for ' + sObjectType);
                }else if (operation == 'delete' && !records.isEmpty()) {
                    delete records;
                    System.debug('Deleted ' + records.size() + ' records for ' + sObjectType);
                }
            }
        }
    }

    // Helper function to add/merge lists into the map by sObject type and operation
    public static void addToSObjectMap(Map<String, Map<String, List<sObject>>> sObjectMap, String sObjectType, String operation, List<sObject> records) {
        if (!records.isEmpty()) {
            // Check if the sObject type already exists in the map
            if (!sObjectMap.containsKey(sObjectType)) {
                sObjectMap.put(sObjectType, new Map<String, List<sObject>>());
            }
            // Get the map of operations (e.g., insert, update) for the sObject type
            Map<String, List<sObject>> operationMap = sObjectMap.get(sObjectType);
            
            // Check if the operation already exists in the map for the specific sObject type
            if (operationMap.containsKey(operation)) {
                // Merge the new records with the existing ones
                List<sObject> existingRecords = operationMap.get(operation);
                existingRecords.addAll(records);
                operationMap.put(operation, existingRecords);
            } else {
                // Add the new operation with its records
            // System.debug(records);
                operationMap.put(operation, records);
            }
        }
    }

    public static List<User> dynamicQuery(PersonaInfo personaInfo, List<Id> userIds) {
        // Start building the base query
        String baseQuery = 'SELECT Id, Name, ProfileId, UserRoleId ';
    
        // Create a list to hold additional fields
        List<String> additionalFields = new List<String>();

        // Convert the Set<Id> to List<String>
        List<String> userIdsList = new List<String>();
        for (Id userId : userIds) {
            userIdsList.add('\'' + String.valueOf(userId) + '\''); // Enclose each Id in single quotes
        }

        String userIdsString = String.join(userIdsList, ',');

        // Add fields from userAttributeMap
        if (personaInfo.userAttributeMap.size()>0) {
            for (String attr : personaInfo.userAttributeMap.keySet()) {
                additionalFields.add(attr);
            }
        }
    
        // Append additional fields to the base query
        if (!additionalFields.isEmpty()) {
            baseQuery += ', ' + String.join(additionalFields, ', ');
        }
    
        // Finalize the query with the WHERE clause
        // Assuming you want to filter users based on the IDs in a specific context (like the requested_by user or a persona-specific criteria)
        baseQuery += ' FROM User WHERE Id IN ('+ userIdsString +')'; // You will need to define what :users contains
    
        // Debugging
        System.debug('Dynamic SOQL Query: ' + baseQuery);
    
        // Execute the dynamic query
        List<User> usersToUpdate = Database.query(baseQuery);
        
        return usersToUpdate;
    }

    // Method to populate the persona options from Persona__mdt
    public static Boolean checkRevertExists(Id user) {
        List<Persona_Change_Request__c> revertRecord = [SELECT Id FROM Persona_Change_Request__c WHERE IsActive__c=true AND RecordType.Name = 'Original Persona' AND Requested_By__c=:User LIMIT 1];
        
        if(revertRecord.size() > 0) {
            System.debug('User has an active revert record already');
            return true;
        } else {
            upsertRevertRecord(user);
            return false;
        }
    }
    
    public static void upsertRevertRecord(Id userId) {
        // Fetch the user and original persona details to populate the record

        // Create a PersonaInfo object to hold the user's current state
        PersonaInfo currentPersona = new PersonaInfo();
        Map<String,String> userAttributeMap = new Map<String,String>();

        List<PersonaInfo> personaList = getAllPersonas();
        Set<String> additionalFields = getAllPersonaCustomAttributes(personaList);
        User user = dynamicQueryForRevert(userId, additionalFields)[0]; 

        Map<String,Object> mapFields = user.getPopulatedFieldsAsMap();


        for(String k: mapFields.keySet()){
            if(k=='ProfileId'){
                currentPersona.profileId=Id.valueOf(JSON.serialize(mapFields.get(k)).replaceAll('"', ''));
            }else if (k=='Profile'){
                Profile profileMap = (Profile)mapFields.get(k);
                currentPersona.profileName=String.valueOf(JSON.serialize(profileMap.get('Name')).replaceAll('"', ''));
            }else if (k=='UserRoleId'){
                    currentPersona.roleId=Id.valueOf(JSON.serialize(mapFields.get(k)).replaceAll('"', ''));
            }else if(k=='UserRole') {
                UserRole roleMap = (UserRole)mapFields.get(k);
                currentPersona.roleName=String.valueOf(JSON.serialize(roleMap.get('Name')).replaceAll('"', ''));
            } else if (k != 'Name' && k != 'Id') {
                userAttributeMap.put(k, String.valueOf(mapFields.get(k)));
            }
            System.debug(k);
        }

        userAttributeMap=populateEmptyFields(additionalFields,userAttributeMap);

        currentPersona.userAttributeMap=userAttributeMap;

            // Fetch user's permission sets
        List<PermissionSetAssignment> userPermSets = [SELECT PermissionSetId, PermissionSet.Name 
        FROM PermissionSetAssignment 
        WHERE AssigneeId = :userId AND PermissionSetGroupId = null AND PermissionSet.IsOwnedByProfile = FALSE ];

        Set<Id> permissionSetIds = new Set<Id>();
        Set<String> permissionSetNames = new Set<String>();

        for (PermissionSetAssignment psa : userPermSets) {
            permissionSetIds.add(psa.PermissionSetId);
            permissionSetNames.add(psa.PermissionSet.Name);
        }
    
        currentPersona.permissionSets = permissionSetIds;
        currentPersona.permissionSetNames = permissionSetNames;

        // Fetch user's permission set groups
        List<PermissionSetAssignment> userPermSetGroups = [SELECT PermissionSetGroupId, PermissionSetGroup.DeveloperName
                FROM PermissionSetAssignment 
                WHERE AssigneeId = :userId AND PermissionSetGroupId != null AND PermissionSet.IsOwnedByProfile = FALSE ];
        Set<Id> permissionSetGroupIds = new Set<Id>();
        Set<String> permissionSetGroupNames = new Set<String>();

        for (PermissionSetAssignment psg : userPermSetGroups) {
            permissionSetGroupIds.add(psg.PermissionSetGroupId);
            permissionSetGroupNames.add(psg.PermissionSetGroup.DeveloperName);
        }

        currentPersona.permissionSetGroups = permissionSetGroupIds;
        currentPersona.permissionSetGroupNames = permissionSetGroupNames;

        // Fetch user's public group memberships
        List<GroupMember> userGroups = [SELECT GroupId, Group.Name 
        FROM GroupMember 
        WHERE UserOrGroupId = :userId];
        Set<Id> groupIds = new Set<Id>();
        Set<String> groupNames = new Set<String>();

        for (GroupMember gm : userGroups) {
            groupIds.add(gm.GroupId);
            groupNames.add(gm.Group.Name);
        }

        currentPersona.publicGroups = groupIds;
        currentPersona.publicGroupNames = groupNames;

        // Convert PersonaInfo to JSON
        String userSnapshotJson = JSON.serialize(currentPersona);

        // Check if the user has a related persona record (you can modify based on your logic)
        List<Persona_Change_Request__c> existingRevertRecords = [
            SELECT Id FROM Persona_Change_Request__c 
            WHERE IsActive__c = false AND RecordType.Name = 'Original Persona' AND Requested_By__c = :userId
            LIMIT 1
        ];
        
        Persona_Change_Request__c personaRequest;
        
        if (existingRevertRecords.size() > 0) {
            // Update existing record if found
            personaRequest = existingRevertRecords[0];
        } else {
            // Create a new record if none exist
            personaRequest = new Persona_Change_Request__c();
            personaRequest.RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Persona_Change_Request__c' AND Name = 'Original Persona' LIMIT 1].Id;
            personaRequest.Requested_By__c = userId;
            
        }
        
        // Populate or update fields for the persona request
        personaRequest.IsActive__c = true;
        personaRequest.Status__c = 'Pending Revert'; // Example status; change as per your use case
        personaRequest.Error_Message__c = '';
        personaRequest.JSON_Revert_Blob__c = userSnapshotJson;
        personaRequest.Persona__c = 'Original Persona';
        
        // Perform upsert (will insert if new or update if existing)
        try {
            upsert personaRequest;
            System.debug('Revert record successfully created/updated.');
        } catch (DmlException e) {
            System.debug('Error during upsert: ' + e.getMessage());
        }
    }

    
    public static Map<String, String> populateEmptyFields(Set<String> additionalFields, Map<String, String> userAttributeMap) {
        // Loop through the additional fields
        for (String fieldName : additionalFields) {
            // Check if the field is missing or not present in the userAttributeMap
            if (!userAttributeMap.containsKey(fieldName)) {
                // Set the field to false or empty (you can modify this depending on the desired default value)
                userAttributeMap.put(fieldName, '');
            }
        }
        return userAttributeMap; // Return the updated map
    }
    

    public static List<PersonaInfo> getAllPersonas() {

        List<PersonaInfo> personas = new List<PersonaInfo>();

        try {

            // Query to get persona metadata and children details
            List<Persona__mdt> personaRecords = [
                SELECT  Label
                FROM Persona__mdt
            ];

            if (!personaRecords.isEmpty()) {
                // Process the children records
                for(Persona__mdt p:personaRecords){
                    PersonaInfo persona = PersonaInfo.getPersona(p.Label);
                    persona.validatePersona();
                    if(!persona.hasErrors){
                        personas.add(persona);
                    }
                }
                
            } 
            return personas;

        } catch (Exception e) {
            System.debug('The following exception has occurred: ' + e.getMessage());
            return personas;
        }
    }

    public static Set<String> getAllPersonaCustomAttributes(List<PersonaInfo> personaList){
        // Create a list to hold additional fields
        Set<String> additionalFields = new Set<String>();

        // Loop through each persona and consolidate the fields
        for (PersonaInfo persona : personaList) {
            // Add fields from userAttributeMap
            if (!persona.HasErrors){
    
                if (persona.userAttributeMap.size() > 0) {
                    for (String attr : persona.userAttributeMap.keySet()) {
                        additionalFields.add(attr); // Using a Set ensures no duplicates
                    }
                }
            }
        }

        return additionalFields;
    }


    public static List<User> dynamicQueryForRevert( Id user, Set<String> additionalFields) {
        // Start building the base query
        String baseQuery = 'SELECT Id, Name, ProfileId, Profile.Name, UserRoleId, UserRole.Name ';
    
        // Append additional fields to the base query
        if (!additionalFields.isEmpty()) {
            baseQuery += ', ' + String.join(new List<String>(additionalFields), ', ');
        }
    
        // Finalize the query with the WHERE clause
        baseQuery += ' FROM User WHERE Id=:user';
    
        // Debugging
        System.debug('Dynamic SOQL Query for Revert: ' + baseQuery);
    
        // Execute the dynamic query
        List<User> usersToRevert = Database.query(baseQuery);
        
        return usersToRevert;
    }
    
    
    
}
