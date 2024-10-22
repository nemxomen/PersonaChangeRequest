public with sharing class PersonaSelectionController {

    // List to hold personas from metadata
    public List<SelectOption> personaOptions { get; set; }
    
    // Variable to store selected persona
    public String selectedPersona { get; set; }

    // Variable to store selected MirrorAs User
    public Id selectedUserId { get; set; }

     // New field for storing the user name
    public String selectedUserName { get; set; } 

    // Boolean flag to indicate whether a persona has been selected
    public Boolean isPersonSelected { get; set; }

    // List to hold search results
    public List<User> searchResults { get; set; } 

    // Object to store persona details fetched from PersonaInfo class
    public PersonaInfo personaInfor { get; set; }

    // Object to store Mirror persona details fetched from PersonaInfo class
    public PersonaInfo mirrorPersona { get; set; }

    // String to store MirrorAs data
    public String jsonMirrorAs { get; set; }
    
    // Boolean flag to indicate whether a persona has been selected
    public Boolean isPersonaSelected { get; set; }

    // Boolean flag to indicate whether the running user is setup to Revert yet
    public Boolean userHasActiveRevertRecord { get; set; }

    // Boolean flag to indicate whether the running user is setup to Revert yet
    public Boolean revertSelected { get; set; }

    // Store Revert Record
    public Persona_Change_Request__c revertRecord { get; set; }
    
    // Additional fields for display in the Visualforce page
    public String profileName { get; set; }
    public String roleName { get; set; }
    public String permissionSetNames { get; set; }
    public String permissionSetGroupNames { get; set; }
    public String publicGroupNames { get; set; }
    public String userPerms { get; set; }
    public String userFields { get; set; }

        // Additional fields for display in the Visualforce page
    public String mirrorUserName { get; set; }
    public String mirrorProfileName { get; set; }
    public String mirrorRoleName { get; set; }
    public String mirrorPermissionSetNames { get; set; }
    public String mirrorPermissionSetGroupNames { get; set; }
    public String mirrorPublicGroupNames { get; set; }
    public String mirrorUserPerms { get; set; }
    public String mirrorUserFields { get; set; }

    public String getFormattedUserAttributeMap() {
        return userPerms != null ? String.join(personaInfor.userAttributeMap.keySet(), ', ') : 'No attributes available';
    }
    
    // Constructor to fetch the personas from metadata
    public PersonaSelectionController() {
        personaOptions = new List<SelectOption>();
        checkUserRevertStatus();
        populatePersonaOptions();
        fetchPersonaDetails();

        selectedUserName = '';
        selectedUserId = null;
        searchResults = new List<User>();
        
    }
    
    // Method to populate the persona options from Persona__mdt
    public void populatePersonaOptions() {
        List<Persona__mdt> personas = [SELECT Label FROM Persona__mdt];
        personaOptions.add(new SelectOption(' ',' ')); 
        for (Persona__mdt persona : personas) {
            personaOptions.add(new SelectOption(persona.Label, persona.Label));
        }
        if(userHasActiveRevertRecord){
            personaOptions.add(new SelectOption('Original Persona', 'Original Persona'));
            selectedPersona ='Original Persona';
        }
    }
    
    // Method to fetch the persona details when a persona is selected
    public void fetchPersonaDetails() {
        if (selectedPersona != null && selectedPersona != ' ') {
            if(selectedPersona=='Original Persona'){
                personaInfor = PersonaInfo.fromJson(revertRecord.JSON_Revert_Blob__c);
                isPersonaSelected = true;
                revertSelected = true;
                clearMirrorAs();
                
            }else{
                personaInfor = PersonaInfo.getPersona(selectedPersona); // Static method call
                isPersonaSelected = true;
                revertSelected = false;
                clearMirrorAs();
            }

            // Populate individual fields for display
            if (personaInfor != null) {
                profileName = personaInfor.profileName;
                roleName = personaInfor.roleName;
                permissionSetNames = String.join(personaInfor.permissionSetNames, ', ');
                permissionSetGroupNames = String.join(personaInfor.permissionSetGroupNames, ', ');
                publicGroupNames = String.join(personaInfor.publicGroupNames, ', ');
                userPerms = String.join(filterKeySet(personaInfor.userAttributeMap.keySet(),'UserPermissions',true), ', ');
                userFields = String.join(filterKeySet(personaInfor.userAttributeMap.keySet(),'UserPermissions',false), ', ');
               //userAttributeMap = personaInfor.userAttributeMap.toString().removeStart('{').removeEnd('}').replaceAll('=', ':');                
            }

        } else {
            isPersonaSelected = false;
            revertSelected = false;
        }
    }

   public void clearMirrorAs(){
        isPersonaSelected = true;
        isPersonSelected = false;
        selectedUserName = '';
        searchResults = new List<User>();
    }

    // Method to fetch the persona details when a persona is selected
    public void fetchPersonaDetailsMirror() {

        // Populate individual fields for display
        if (mirrorPersona != null) {
            mirrorUserName = selectedUserName;
            mirrorProfileName = mirrorPersona.profileName;
            mirrorRoleName = mirrorPersona.roleName;
            mirrorPermissionSetNames = String.join(mirrorPersona.permissionSetNames, ', ');
            mirrorPermissionSetGroupNames = String.join(mirrorPersona.permissionSetGroupNames, ', ');
            mirrorPublicGroupNames = String.join(mirrorPersona.publicGroupNames, ', ');
            mirrorUserPerms = String.join(filterKeySet(mirrorPersona.userAttributeMap.keySet(),'UserPermissions',true), ', ');
            mirrorUserFields = String.join(filterKeySet(mirrorPersona.userAttributeMap.keySet(),'UserPermissions',false), ', ');
            //userAttributeMap = personaInfor.userAttributeMap.toString().removeStart('{').removeEnd('}').replaceAll('=', ':');                
        }


    }
        
    
    // Method to search for users based on name input
    public void searchUsers() {
        if (selectedUserName != null && selectedUserName != '') {
            searchResults = [SELECT Id, Name FROM User WHERE IsActive=TRUE AND UserType='Standard' AND Profile.UserLicense.Name='Salesforce' AND Name LIKE :('%' + selectedUserName + '%') AND Id !=:UserInfo.getUserId()  LIMIT 10];
        } else {
            searchResults.clear();
        }

        selectedPersona ='';
        isPersonaSelected=false;
    }

    // Method to select the user from search results
    public void selectUser() {
        selectedUserName ='';
        selectedUserName = [SELECT Name FROM User WHERE Id =:selectedUserId].Name;  // Get the name of the selected user
        isPersonSelected=true;
        mirrorAs();
    }


        
    public void mirrorAs() {
        // Fetch the user and original persona details to populate the record

        // Create a PersonaInfo object to hold the user's current state
        PersonaInfo currentPersona = new PersonaInfo();
        Map<String,String> userAttributeMap = new Map<String,String>();

        List<PersonaInfo> personaList = getAllPersonas();
        Set<String> additionalFields = getAllPersonaCustomAttributes(personaList);
        User user = dynamicQueryForRevert(selectedUserId, additionalFields)[0]; 

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
        WHERE AssigneeId = :selectedUserId AND PermissionSetGroupId = null AND PermissionSet.IsOwnedByProfile = FALSE ];

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
                WHERE AssigneeId = :selectedUserId AND PermissionSetGroupId != null AND PermissionSet.IsOwnedByProfile = FALSE ];
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
        WHERE UserOrGroupId = :selectedUserId];
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

        jsonMirrorAs=userSnapshotJson;
        mirrorPersona=currentPersona;
        fetchPersonaDetailsMirror();
        return;
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

    public static List<String> filterKeySet(Set<String> keys, String search, Boolean lookingFor){
        List<String> newKeys = new List<String>();
        if(lookingFor){
            for (String s: keys){
                if(s.contains(search)){
                    newKeys.add(s);
                }
                
            }
        }else{
            for (String s: keys){
                if(!s.contains(search)){
                    newKeys.add(s);
                }
                
            }
        }
        newKeys.sort();
        return newKeys;
    }


    // Method to handle form submission and create Persona_Change_Request__c
    public PageReference submitPersonaRequest() {
        try {
            
            if (personaInfor != null) {

                if(personaInfor.validatePersona()){
               // Create a new Persona_Change_Request__c record
                Persona_Change_Request__c changeRequest = new Persona_Change_Request__c();
                changeRequest.RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Persona_Change_Request__c' AND Name = 'Change Request' LIMIT 1].Id;
                changeRequest.Requested_By__c = UserInfo.getUserId();
                changeRequest.Status__c = 'Pending';
                changeRequest.Persona__c = selectedPersona;
                
                // Insert the record
                insert changeRequest;
                // List<Id> users = new List<Id>();
                // users.add(UserInfo.getUserId());
                // PersonaChangeRequestHandler.updateUserWithPersona(personaInfor,users);
                
                // Redirect to the newly created record
                return new PageReference('/' + changeRequest.Id); 

                } else{
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + personaInfor.errorMessage));
                }

            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()));
            return null;
        }
        return null;
    }

        // Method to handle form submission and create Persona_Change_Request__c
        public PageReference mirrorAsRequest() {
            try {
                
                if (isPersonSelected && selectedUserId!=null) {
    
                // Create a new Persona_Change_Request__c record
                Persona_Change_Request__c changeRequest = new Persona_Change_Request__c();
                changeRequest.RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Persona_Change_Request__c' AND Name = 'Change Request' LIMIT 1].Id;
                changeRequest.Requested_By__c = UserInfo.getUserId();
                changeRequest.MirrorAs__c = selectedUserId;
                changeRequest.Status__c = 'Pending';
                changeRequest.JSON_MirrorAs_Blob__c = jsonMirrorAs;
                
                // Insert the record
                insert changeRequest;
                // List<Id> users = new List<Id>();
                // users.add(UserInfo.getUserId());
                // PersonaChangeRequestHandler.updateUserWithPersona(personaInfor,users);
                
                // Redirect to the newly created record
                return new PageReference('/' + changeRequest.Id); 
    
    
                }
            } catch (Exception e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()));
                return null;
            }
            return null;
        }

    // Method to populate the persona options from Persona__mdt
    public void checkUserRevertStatus() {
        List<Persona_Change_Request__c> revertRecords = [SELECT Id, JSON_Revert_Blob__c, IsActive__c, Status__c FROM Persona_Change_Request__c WHERE IsActive__c=true AND RecordType.Name = 'Original Persona' AND Requested_By__c=:UserInfo.getUserId() LIMIT 1];
       
        if(revertRecords.size() > 0) {
            userHasActiveRevertRecord = true;
            revertRecord=revertRecords[0];
        } else {
            userHasActiveRevertRecord = false;
        }
    }


    // Method to handle Revert Persona action
    public PageReference revertPersona() {
        try {
            // Logic to handle revert action
            // (e.g., update records, revert user state, etc.)
            revertRecord.IsActive__c = FALSE;
            revertRecord.Status__c = 'Reverted';
            update revertRecord;

            List<Id> users = new List<Id>();
            users.add(UserInfo.getUserId());
            PersonaChangeRequestHandler.updateUserWithPersona(revertRecord.JSON_Revert_Blob__c,users,false,true,false);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Persona reverted successfully.'));
            return new PageReference('/' + revertRecord.Id); 
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()));
        }
        return null;
    }

    // Method to handle cancellation
    public PageReference cancel() {
        return new PageReference('/home/home.jsp'); // Redirects to the homepage on cancel
    }

    
}
