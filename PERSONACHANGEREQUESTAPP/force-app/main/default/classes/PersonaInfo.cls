public with sharing class PersonaInfo {

    public String profileName;
    public List<String> permissionSetNames = new List<String>();
    public List<String> permissionSetGroupNames = new List<String>();
    public List<String> publicGroupNames = new List<String>();
    public Map<String,Boolean> userAttributeMap = new Map<String,Boolean>();
    public Map<String,String> userCustomFieldMap = new Map<String,String>();
    public Id profileId;
    public List<Id> permissionSets = new List<Id>();
    public List<Id> permissionSetGroups = new List<Id>();
    public List<Id> publicGroups = new List<Id>();
    public Boolean isPermissionSetGroupTrueUp = false;
    public Boolean isPermissionSetTrueUp = false;
    public Boolean isPublicGroupTrueUp = false;
    public Boolean isPersonaReviewed = false;
    public String errorMessage;

    // Constructor to initialize persona info
    public PersonaInfo(String profileName, List<String> permissionSets, List<String> permissionSetGroups, List<String> publicGroups, Map<String,Boolean> userAttributes, Map<String,String> userCustomFields, Boolean isPermissionSetGroupTrueUp, Boolean isPermissionSetTrueUp, Boolean isPublicGroupTrueUp) {
        this.profileName = profileName;
        this.permissionSetNames = permissionSets;
        this.permissionSetGroupNames = permissionSetGroups;
        this.publicGroupNames = publicGroups;
        this.userAttributeMap = userAttributes;
        this.userCustomFieldMap = userCustomFields;
        this.isPermissionSetGroupTrueUp = isPermissionSetGroupTrueUp;
        this.isPermissionSetTrueUp = isPermissionSetTrueUp;
        this.isPublicGroupTrueUp = isPublicGroupTrueUp;
    }

    public PersonaInfo (Boolean isPersonaReviewed, String errorMessage){
        this.isPersonaReviewed = isPersonaReviewed;
        this.errorMessage = errorMessage;
    }

    // Retrieve persona information from metadata or custom settings
    public static PersonaInfo getPersona(String personaName) {
        try {
            // Query to get persona metadata and children details
            List<Persona__mdt> personas = [
                SELECT Id, Label, ProfileName__c, PermissionSetGroupTrueUp__c, PermissionSetTrueUp__c, PublicGroupTrueUp__c,
                    (SELECT Label, Type__c, UserAttributeValue__c, UserCustomFieldValue__c 
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
            return new PersonaInfo(true, personaName + ' Error: ' + e.getMessage()); 
        }
        return new PersonaInfo(true, personaName + ' Not Found in Custom Metadata Types');
    }

    // Process the persona children metadata
    public static PersonaInfo processPersonaChildern(Persona__mdt persona) {
        Map<String, Boolean> userAttributes = new Map<String, Boolean>();
        Map<String, String> customFields = new Map<String, String>();
        String profileName;
        List<String> permissionSetNames = new List<String>();
        List<String> permissionSetGroupNames = new List<String>();
        List<String> publicGroupNames = new List<String>();
        Boolean isPermissionSetGroupTrueUp = false;
        Boolean isPermissionSetTrueUp = false;
        Boolean isPublicGroupTrueUp = false;

        profileName = persona.ProfileName__c;
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
                when 'CustomField' {
                    // Add custom field value to the map (String value)
                    customFields.put(child.Label, child.UserCustomFieldValue__c);
                }
            }
        }

        System.debug('Processed persona children: ' + persona.Label);
        System.debug('Permission Set Names: ' + permissionSetNames);
        System.debug('Permission Set Group Names: ' + permissionSetGroupNames);
        System.debug('Public Group Names: ' + publicGroupNames);
        System.debug('User Attributes: ' + userAttributes);
        System.debug('Custom Fields: ' + customFields);

        return new PersonaInfo(profileName, permissionSetNames, permissionSetGroupNames, publicGroupNames, userAttributes, customFields, isPermissionSetGroupTrueUp, isPermissionSetTrueUp, isPublicGroupTrueUp);
    }
}