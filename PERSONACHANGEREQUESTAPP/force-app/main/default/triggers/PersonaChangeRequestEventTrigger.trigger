trigger PersonaChangeRequestEventTrigger on PersonaChangeRequestEvent__e (after insert) {
    for (PersonaChangeRequestEvent__e eventRecord : Trigger.new) {
        List<Id> users = new List<Id>();
        users.add(eventRecord.UserId__c);
        PersonaChangeRequestHandler.updateUserWithPersona(eventRecord.Persona__c, users, eventRecord.FromApp__c, eventRecord.IsRevert__c, eventRecord.HasRevert__c, eventRecord.MirrorAs__c);
    }
}