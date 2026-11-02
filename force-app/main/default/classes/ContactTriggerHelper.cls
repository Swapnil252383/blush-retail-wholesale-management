public with sharing class ContactTriggerHelper {

    public static void makeOnlyOnePrimary(List<Contact> newContacts) {

    
        Map<Id, Contact> winnerByAccount = new Map<Id, Contact>();
        for (Contact c : newContacts) {
            if (c.Is_Primar__c == true && c.AccountId != null) {
                winnerByAccount.put(c.AccountId, c);
            }
        }

  
        if (winnerByAccount.isEmpty()) {
            return;
        }

        Set<Id> winnerIds = new Set<Id>();
        for (Contact winner : winnerByAccount.values()) {
            winnerIds.add(winner.Id);
        }

     
        List<Contact> contactsToUncheck = new List<Contact>();
        for (Contact other : [SELECT Id
                              FROM Contact
                              WHERE AccountId IN :winnerByAccount.keySet()
                              AND Is_Primar__c = true
                              AND Id NOT IN :winnerIds]) {
            other.Is_Primar__c = false;
            contactsToUncheck.add(other);
        }

  
        if (!contactsToUncheck.isEmpty()) {
            update contactsToUncheck;
        }


        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : winnerByAccount.keySet()) {
            accountsToUpdate.add(new Account(
                Id = accId,
                Primary_Contact__c = winnerByAccount.get(accId).Id
            ));
        }

  
        update accountsToUpdate;
    }
}