public with sharing class AccountTriggerHelper {

    public static void setPrimaryContact(List<Account> accounts) {


        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }


        Map<Id, Id> primaryContactByAccount = new Map<Id, Id>();
        for (Contact con : [SELECT Id, AccountId
                            FROM Contact
                            WHERE AccountId IN :accountIds
                            AND 	Is_Primar__c = true]) {
            primaryContactByAccount.put(con.AccountId, con.Id);
        }

        for (Account acc : accounts) {
            acc.Primary_Contact__c = primaryContactByAccount.get(acc.Id);
        }
    }
}