@isTest
private class PrimaryContactTest {

 
    private static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }


    @isTest
    static void testSinglePrimaryContact() {
        Account acc = createAccount('Test Account');

        Contact normalContact = new Contact(LastName = 'Normal', AccountId = acc.Id);
        Contact primaryContact = new Contact(LastName = 'Primary', AccountId = acc.Id,
                                            Is_Primar__c = true);

        Test.startTest();
        insert new List<Contact>{ normalContact, primaryContact };
        Test.stopTest();

        Account result = [SELECT Primary_Contact__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(primaryContact.Id, result.Primary_Contact__c,
                        'Account should point to the primary contact');
    }


    @isTest
    static void testPrimaryContactSwitch() {
        Account acc = createAccount('Switch Account');

        Contact oldPrimary = new Contact(LastName = 'Old', AccountId = acc.Id,
                                        Is_Primar__c = true);
        Contact newPrimary = new Contact(LastName = 'New', AccountId = acc.Id);
        insert new List<Contact>{ oldPrimary, newPrimary };

        Test.startTest();
        newPrimary.Is_Primar__c = true;
        update newPrimary;
        Test.stopTest();

        List<Contact> primaries = [SELECT Id FROM Contact
                                   WHERE AccountId = :acc.Id AND Is_Primar__c = true];
        Assert.areEqual(1, primaries.size(), 'Only one contact can be primary');
        Assert.areEqual(newPrimary.Id, primaries[0].Id, 'The new contact should be primary');

        Account result = [SELECT Primary_Contact__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(newPrimary.Id, result.Primary_Contact__c,
                        'Account should point to the new primary contact');
    }


    @isTest
    static void testTwoPrimaryInSameUpdate() {
        Account acc = createAccount('Same Batch Account');

        Contact con1 = new Contact(LastName = 'A1', AccountId = acc.Id);
        Contact con2 = new Contact(LastName = 'A2', AccountId = acc.Id);
        insert new List<Contact>{ con1, con2 };

        Test.startTest();
        con1.Is_Primar__c = true;
        con2.Is_Primar__c = true;
        update new List<Contact>{ con1, con2 };
        Test.stopTest();

        List<Contact> primaries = [SELECT Id FROM Contact
                                   WHERE AccountId = :acc.Id AND Is_Primar__c = true];
        Assert.areEqual(1, primaries.size(), 'Only one contact can be primary');

        Account result = [SELECT Primary_Contact__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(primaries[0].Id, result.Primary_Contact__c,
                        'Account should point to the one remaining primary contact');
    }


    @isTest
    static void testBulkContacts() {
        Account accA = createAccount('Bulk A');
        Account accB = createAccount('Bulk B');

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(
                LastName = 'Bulk' + i,
                AccountId = (Math.mod(i, 2) == 0) ? accA.Id : accB.Id,
                Is_Primar__c = true
            ));
        }

        Test.startTest();
        insert contacts;
        Test.stopTest();


        for (Account acc : [SELECT Id, Primary_Contact__c,
                                   (SELECT Id FROM Contacts WHERE Is_Primar__c = true)
                            FROM Account WHERE Id IN :new List<Id>{ accA.Id, accB.Id }]) {
            Assert.areEqual(1, acc.Contacts.size(), 'Exactly one primary per account');
            Assert.areEqual(acc.Contacts[0].Id, acc.Primary_Contact__c,
                            'Account should point to its primary contact');
        }
    }


    @isTest
    static void testContactWithoutAccount() {
        Contact orphan = new Contact(LastName = 'No Account', Is_Primar__c = true);

        Test.startTest();
        insert orphan;
        Test.stopTest();

        Assert.isNotNull(orphan.Id, 'Contact should save without an error');
    }


    @isTest
    static void testAccountTriggerRecomputesPrimary() {
        Account acc = createAccount('Account Trigger Test');
        Contact primary = new Contact(LastName = 'Primary', AccountId = acc.Id,
                                     Is_Primar__c = true);
        insert primary;

        Test.startTest();
        acc.Primary_Contact__c = null;   
        update acc;                     
        Test.stopTest();

        Account result = [SELECT Primary_Contact__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(primary.Id, result.Primary_Contact__c,
                        'AccountTrigger should set the primary contact again');
    }


    @isTest
    static void testAccountWithNoPrimaryContact() {
        Account acc = createAccount('No Primary');

        Test.startTest();
        acc.Description = 'Changed';
        update acc;
        Test.stopTest();

        Account result = [SELECT Primary_Contact__c FROM Account WHERE Id = :acc.Id];
        Assert.isNull(result.Primary_Contact__c, 'No primary contact should mean null');
    }
}