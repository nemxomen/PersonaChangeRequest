public with sharing class PersonaInfo {

    public String personaName;
    public String profileName;
    public String roleName;
    public Set<String> permissionSetNames = new Set<String>();
    public Set<String> permissionSetGroupNames = new Set<String>();
    public Set<String> publicGroupNames = new Set<String>();
    public Map<String,String> userAttributeMap = new Map<String,String>();
    public Id profileId;
    public Id roleId;
    public Set<Id> permissionSets = new Set<Id>();
    public Set<Id> permissionSetGroups = new Set<Id>();
    public Set<Id> publicGroups = new Set<Id>();
    public Boolean isPermissionSetGroupTrueUp = false;
    public Boolean isPermissionSetTrueUp = false;
    public Boolean isPublicGroupTrueUp = false;
    public Boolean isPersonaReviewed = false;
    public Boolean hasErrors = false;
    public String errorMessage;

    // Constructor to initialize persona info
    public PersonaInfo(String personaName, String profileName, String roleName, Set<String> permissionSets, Set<String> permissionSetGroups, Set<String> publicGroups, Map<String,String> userAttributes, Boolean isPermissionSetGroupTrueUp, Boolean isPermissionSetTrueUp, Boolean isPublicGroupTrueUp) {
        this.personaName = personaName;
        this.profileName = profileName;
        this.roleName = roleName;
        this.permissionSetNames = permissionSets;
        this.permissionSetGroupNames = permissionSetGroups;
        this.publicGroupNames = publicGroups;
        this.userAttributeMap = userAttributes;
        this.isPermissionSetGroupTrueUp = isPermissionSetGroupTrueUp;
        this.isPermissionSetTrueUp = isPermissionSetTrueUp;
        this.isPublicGroupTrueUp = isPublicGroupTrueUp;
    }

    public PersonaInfo (Boolean isPersonaReviewed, Boolean hasErrors, String errorMessage){
        this.isPersonaReviewed = isPersonaReviewed;
        this.hasErrors = hasErrors;
        this.errorMessage = errorMessage;
    }

    public PersonaInfo (){
  
    }

    // Retrieve persona information from metadata or custom settings
    public static PersonaInfo getPersona(String personaName) {
        try {
            // Query to get persona metadata and children details
            List<Persona__mdt> personas = [
                SELECT Id, Label, ProfileName__c, RoleName__c, PermissionSetGroupTrueUp__c, PermissionSetTrueUp__c, PublicGroupTrueUp__c,
                    (SELECT Label, Type__c, UserAttributeValue__c
                    FROM Persona_Childern__r)  
                FROM Persona__mdt 
                WHERE Label = :personaName LIMIT 1
            ];

            if (!personas.isEmpty()) {
                // Process the children records
                return processPersonaChildern(personas[0]);
            } 
        } catch (Exception e) {
            System.debug('The following exception has occurred: ' + e.getMessage());
            return new PersonaInfo(true,true, personaName + ' Error: ' + e.getMessage()); 
        }
        return new PersonaInfo(true, true, personaName + ' Not Found in Custom Metadata Types');
    }
    // Method to deserialize JSON into a PersonaInfo object
    public static PersonaInfo fromJson(String userSnapshotJson) {
        // Deserialize the JSON string into a PersonaInfo object
        PersonaInfo personaInfo = (PersonaInfo)JSON.deserialize(userSnapshotJson, PersonaInfo.class);
        return personaInfo;
    }
    
    // Process the persona children metadata
    public static PersonaInfo processPersonaChildern(Persona__mdt persona) {
        Map<String, String> userAttributes = new Map<String, String>();
        String profileName;
        String roleName;
        String personaName;
        Set<String> permissionSetNames = new Set<String>();
        Set<String> permissionSetGroupNames = new Set<String>();
        Set<String> publicGroupNames = new Set<String>();
        Boolean isPermissionSetGroupTrueUp = false;
        Boolean isPermissionSetTrueUp = false;
        Boolean isPublicGroupTrueUp = false;

        personaName = persona.Label;
        profileName = persona.ProfileName__c;
        roleName = persona.RoleName__c;
        isPermissionSetGroupTrueUp = persona.PermissionSetGroupTrueUp__c;
        isPermissionSetTrueUp = persona.PermissionSetTrueUp__c;
        isPublicGroupTrueUp = persona.PublicGroupTrueUp__c;

        // Iterate over child records (Persona_Childern__r is the child relationship)
        for (Persona_Childern__mdt child : persona.Persona_Childern__r) {
            // Process based on Type__c field (e.g., PermissionSet, PermissionSetGroup, UserAttributes)
            switch on child.Type__c {
                when 'PermissionSet' {
                    // Add permission set to the list
                    permissionSetNames.add(child.Label);
                }
                when 'PermissionSetGroup' {
                    // Add permission set group to the list
                    permissionSetGroupNames.add(child.Label);
                }
                when 'PublicGroup' {
                    // Add public group to the list
                    publicGroupNames.add(child.Label);
                }
                when 'UserAttribute' {
                    // Add user attribute to the map (assumed to be Boolean)
                    userAttributes.put(child.Label, child.UserAttributeValue__c);
                }
            }
        }

        System.debug('Processed persona children: ' + persona.Label);
        System.debug('Permission Set Names: ' + permissionSetNames);
        System.debug('Permission Set Group Names: ' + permissionSetGroupNames);
        System.debug('Public Group Names: ' + publicGroupNames);
        System.debug('User Attributes: ' + userAttributes);

        return new PersonaInfo(personaName,profileName, roleName, permissionSetNames, permissionSetGroupNames, publicGroupNames, userAttributes, isPermissionSetGroupTrueUp, isPermissionSetTrueUp, isPublicGroupTrueUp);
    }

    // Validate the persona to ensure all necessary fields are present
    public Boolean validatePersona() {
        if (!isPersonaReviewed) {
            // Validate required profileName
            if (String.isBlank(profileName)) {

                hasErrors = true;
                String profileMissing = 'Profile is blank or missing';
                errorMessage = updateErrorMessage(errorMessage, profileMissing);
            } else {
                try {
                    // Query and validate Profile if profileId is not null
                    Profile queriedProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
                    if (queriedProfile == null) {
                        hasErrors = true;
                        String profileNotFound = 'Profile not found';
                        errorMessage = updateErrorMessage(errorMessage, profileNotFound);
                    } else {
                        profileId = queriedProfile.Id; // Store the ID
                    }
                } catch (Exception e) {
                    hasErrors = true;
                    errorMessage = updateErrorMessage(errorMessage, 'Error querying Profile: ' + e.getMessage());
                }
            }
    
            // Validate required roleName
            if (!String.isBlank(roleName)) {
                try {
                    // Query and validate Role if roleId is not null
                    UserRole queriedRole = [SELECT Id FROM UserRole WHERE Name = :roleName LIMIT 1];
                    if (queriedRole == null) {
                        hasErrors = true;
                        String roleNotFound = 'Role not found';
                        errorMessage = updateErrorMessage(errorMessage, roleNotFound);
                    } else {
                        roleId = queriedRole.Id; // Store the ID
                    }
                } catch (Exception e) {
                    hasErrors = true;
                    errorMessage = updateErrorMessage(errorMessage, 'Error querying Role: ' + e.getMessage());
                }
            }
    
            // Validate and query permission sets
            if (!permissionSetNames.isEmpty()) {
                try {
                    List<PermissionSet> queriedPermissionSets = [
                        SELECT Id FROM PermissionSet WHERE Name IN :permissionSetNames
                    ];
                    if (queriedPermissionSets.size() != permissionSetNames.size()) {
                        hasErrors = true;
                        String permissionSetMismatch = 'Mismatch in permission sets, queried: ' + queriedPermissionSets.size() + ' but expected: ' + permissionSetNames.size();
                        errorMessage = updateErrorMessage(errorMessage, permissionSetMismatch);
                    } else {
                        for (PermissionSet ps : queriedPermissionSets) {
                            permissionSets.add(ps.Id); // Store the IDs
                        }
                    }
                } catch (Exception e) {
                    hasErrors = true;
                    errorMessage = updateErrorMessage(errorMessage, 'Error querying Permission Sets: ' + e.getMessage());
                }
            }
    
            // Validate and query permission set groups
            if (!permissionSetGroupNames.isEmpty()) {
                try {
                    List<PermissionSetGroup> queriedPermissionSetGroups = [
                        SELECT Id FROM PermissionSetGroup WHERE DeveloperName IN :permissionSetGroupNames
                    ];
                    if (queriedPermissionSetGroups.size() != permissionSetGroupNames.size()) {
                        hasErrors = true;
                        String permissionSetGroupMismatch = 'Mismatch in permission set groups, queried: ' + queriedPermissionSetGroups.size() + ' but expected: ' + permissionSetGroupNames.size();
                        errorMessage = updateErrorMessage(errorMessage, permissionSetGroupMismatch);
                    } else {
                        for (PermissionSetGroup psg : queriedPermissionSetGroups) {
                            permissionSetGroups.add(psg.Id); // Store the IDs
                        }
                    }
                } catch (Exception e) {
                    hasErrors = true;
                    errorMessage = updateErrorMessage(errorMessage, 'Error querying Permission Set Groups: ' + e.getMessage());
                }
            }
    
            // Validate and query public groups
            if (!publicGroupNames.isEmpty()) {
                try {
                    List<Group> queriedPublicGroups = [
                        SELECT Id FROM Group WHERE Name IN :publicGroupNames
                    ];
                    if (queriedPublicGroups.size() != publicGroupNames.size()) {
                        hasErrors = true;
                        String publicGroupMismatch = 'Mismatch in public groups, queried: ' + queriedPublicGroups.size() + ' but expected: ' + publicGroupNames.size();
                        errorMessage = updateErrorMessage(errorMessage, publicGroupMismatch);
                    } else {
                        for (Group pg : queriedPublicGroups) {
                            publicGroups.add(pg.Id); // Store the IDs
                        }
                    }
                } catch (Exception e) {
                    hasErrors = true;
                    errorMessage = updateErrorMessage(errorMessage, 'Error querying Public Groups: ' + e.getMessage());
                }
            }
    
            // Validate custom fields (example structure)
            if (!userAttributeMap.isEmpty()) {
                // Validate and query custom fields
                List<String> missingAttributes = new List<String>();
                List<String> badFieldValues = new List<String>();
                Map<String, Schema.SObjectField> userFields = Schema.sObjectType.User.fields.getMap();
                SObjectField sf;
                String fieldType;
                String fieldValue;

                for (String customFieldName : userAttributeMap.keySet()) {
                    if (!userFields.containsKey(customFieldName)) {
                        missingAttributes.add(customFieldName);
                    }else{
                        try{

                            sf = userFields.get(customFieldName);
                            fieldType = String.valueOf(sf.getDescribe().getType());
                            
                            // Retrieve the value from userCustomFieldMap
                            fieldValue = userAttributeMap.get(customFieldName);
                            // Check the field type and cast/parse accordingly
                            if(!String.isBlank(fieldValue)){
                                switch on fieldType {
                                    when 'BOOLEAN' {
                                        if(!validateBooleanString(fieldValue)){
                                            throw new NullPointerException();
                                        }
                                    }
                                    when 'DATE' {
                                        Date.valueOf(fieldValue);
                                    }
                                    when 'DATETIME' {
                                        DateTime.valueOf(fieldValue);
                                    }
                                    when 'INTEGER' {
                                        Integer.valueOf(fieldValue);
                                    }
                                    when 'DOUBLE' {
                                        Double.valueOf(fieldValue);
                                    }
                                    when 'STRING' {
                                        //String.valueOf(fieldValue);
                                    }
                                    when 'CURRENCY' {
                                        Decimal.valueOf(fieldValue);
                                    }
                                    when 'PERCENT' {
                                        Decimal.valueOf(fieldValue);
                                    }
                                    when 'PHONE', 'URL', 'EMAIL', 'TEXTAREA' {
                                        // For field types that are essentially text-based, treat them as strings
                                        //String.valueOf(fieldValue);
                                    }
                                    when else {
                                        // Handle other types as needed
                                        System.debug('Unhandled field type: ' + fieldType);
                                        throw new NullPointerException();
                                        
                                    }
                                }
                            }else{
                                switch on fieldType {
                                    when 'BOOLEAN' {
                                        if(!validateBooleanString(fieldValue)){
                                            throw new NullPointerException();
                                        }
                                    }
                                }

                            }

                        }catch (Exception e) {
                            badFieldValues.add(customFieldName +' is of fieldType: ' +fieldType +' Could not set this value: ' +fieldValue);
                             
                        }

                    }
                    
                }
                if (!missingAttributes.isEmpty()) {
                    hasErrors = true;
                    String attributesNotFound = 'Missing user attributes: ' + String.join(missingAttributes, ', ');
                    errorMessage = updateErrorMessage(errorMessage, attributesNotFound);
                }
                if (!badFieldValues.isEmpty()) {
                    hasErrors = true;
                    String fieldTypeIssue = 'System cannont assert types: ' + String.join(badFieldValues, ', ');
                    errorMessage = updateErrorMessage(errorMessage, fieldTypeIssue);
                }
            }
    
            // Mark the persona as reviewed
            isPersonaReviewed = true;
    
            // Return false if there are any errors
            if (hasErrors) {
                return false;
            }
    
            // If no errors, return true
            return true;
        } else {
            return !hasErrors;
        }
    }

    public static Boolean validateBooleanString(String value) {
        if (String.isBlank(value)) {
            return false;
        }
    
        // Convert the value to lowercase for case-insensitive comparison
        String lowerValue = value.trim().toLowerCase();
    
        // Define sets of acceptable true and false values
        Set<String> values = new Set<String>{'true', 'false'};
    
        // Check if the value is in the true or false set
        if (values.contains(lowerValue)) {
            return true;
        } else {
            return false;
        }
    }

    String updateErrorMessage(String originalErrorMessage, String newErrorMessage){
        return  String.isBlank(originalErrorMessage)? newErrorMessage + '; ' : errorMessage + newErrorMessage +'; ';
    }


}