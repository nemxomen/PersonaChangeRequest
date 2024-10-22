trigger PersonaChangeRequestTrigger on Persona_Change_Request__c (before insert, before update) {
    if (Trigger.isBefore) {
        // Get the valid RecordTypeIds based on the name (adjust to the correct RecordType name)
        String changeRequestType = 'Change Request';  // Add valid record type names here
        RecordType rtChangeRequestType = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Persona_Change_Request__c' AND Name IN :changeRequestType limit 1][0];
        
        // Create a list to hold records with valid RecordTypeIds
        List<Persona_Change_Request__c> validRecords = new List<Persona_Change_Request__c>();
        
        for (Persona_Change_Request__c request : Trigger.new) {
            if (rtChangeRequestType.Id == request.RecordTypeId) {
                validRecords.add(request);
            }
        }
        
        // Only handle the valid records
        if (!validRecords.isEmpty()) {
            PersonaChangeRequestHandler.handleBeforeInsertUpdate(validRecords);
        }
    }
}
