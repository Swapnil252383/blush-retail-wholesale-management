public with sharing class AccountTriggerHandler {

    public static void beforeUpdate(List<Account> newAccounts) {
        AccountTriggerHelper.setPrimaryContact(newAccounts);
    }
}