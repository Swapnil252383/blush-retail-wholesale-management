@isTest
private class SetSkillsTest {


    private static Set<String> toSet(String skills) {
        return skills == null ? new Set<String>() : new Set<String>(skills.split(';'));
    }

    @isTest
    static void syncSkillsFromContactToAccount() {
  
        Account acc = new Account(Name = 'Test account');
        insert acc;

        Contact con  = new Contact(LastName = 'A1', AccountId = acc.Id, Skills__c = 'A;B');
        Contact con1 = new Contact(LastName = 'A2', AccountId = acc.Id, Skills__c = 'A;C');
        Contact con2 = new Contact(LastName = 'A3', AccountId = acc.Id, Skills__c = 'A;B;C');
        insert new List<Contact>{ con, con1, con2 };

   
        Account result = [SELECT Skills__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(new Set<String>{'A','B','C'}, toSet(result.Skills__c),
                        'Account should have skills of all contacts');

   
        con.Skills__c  = 'A';
        con1.Skills__c = 'A';
        con2.Skills__c = 'C';
        update new List<Contact>{ con, con1, con2 };

        result = [SELECT Skills__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(new Set<String>{'A','C'}, toSet(result.Skills__c),
                        'Account skills should update when contacts change');


        delete con2;

        result = [SELECT Skills__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(new Set<String>{'A'}, toSet(result.Skills__c),
                        'Deleted contact skills should be removed');

     
        undelete con2;

        result = [SELECT Skills__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(new Set<String>{'A','C'}, toSet(result.Skills__c),
                        'Undeleted contact skills should come back');


        Account acc2 = new Account(Name = 'Second account');
        insert acc2;
        con2.AccountId = acc2.Id;
        update con2;

        Account oldAcc = [SELECT Skills__c FROM Account WHERE Id = :acc.Id];
        Account newAcc = [SELECT Skills__c FROM Account WHERE Id = :acc2.Id];
        Assert.areEqual(new Set<String>{'A'}, toSet(oldAcc.Skills__c),
                        'Old account should lose the moved contact skills');
        Assert.areEqual(new Set<String>{'C'}, toSet(newAcc.Skills__c),
                        'New account should get the moved contact skills');

    
        con.Skills__c  = null;
        con1.Skills__c = null;
        update new List<Contact>{ con, con1 };

        result = [SELECT Skills__c FROM Account WHERE Id = :acc.Id];
        Assert.isNull(result.Skills__c, 'Account skills should be empty');
    }

    @isTest
    static void bulkTest() {
  
        Account acc = new Account(Name = 'Bulk account');
        insert acc;

        List<Contact> cons = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            cons.add(new Contact(LastName = 'Bulk' + i, AccountId = acc.Id, Skills__c = 'A;B'));
        }
        insert cons;

        Account result = [SELECT Skills__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(new Set<String>{'A','B'}, toSet(result.Skills__c),
                        'Bulk insert should work');
    }
}