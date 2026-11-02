trigger OpportunityTrigger on Opportunity (before insert, before update, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        OpportunityCustomerService.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        OpportunityCustomerService.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter) {
        OpportunityCustomerService.afterSave(Trigger.new, Trigger.oldMap);
    }
}