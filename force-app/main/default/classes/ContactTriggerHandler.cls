public with sharing class ContactTriggerHandler {

    public static void afterInsert(List<Contact> newContacts) {
        ContactTriggerHelper.makeOnlyOnePrimary(newContacts);
    }

    public static void afterUpdate(List<Contact> newContacts) {
        ContactTriggerHelper.makeOnlyOnePrimary(newContacts);
    }
}