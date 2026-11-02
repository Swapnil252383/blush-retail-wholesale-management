@IsTest
private class OpportunityCustomerServiceTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createPricebooks();
    }

    private static Opportunity reload(Id oppId) {
        return [
            SELECT Id, AccountId, Account.Name, Account.RecordType.DeveloperName, Customer_Contact__c, Pricebook2.Name
            FROM Opportunity
            WHERE Id = :oppId
        ];
    }

    private static Lead createLead(String lastName, String email, String phone) {
        Lead l = new Lead(LastName = lastName, Company = lastName, Email = email, Phone = phone, Customer_Type__c = 'Retail');
        insert l;
        return l;
    }

    @IsTest
    static void newRetailCustomerIsCreatedFromOpportunity() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Priya Sharma', 'priya@example.com', '9876543210');

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity saved = reload(opp.Id);
        Assert.areEqual('Priya Sharma', saved.Account.Name);
        Assert.areEqual('Retail', saved.Account.RecordType.DeveloperName);
        Assert.areEqual(BlushConstants.RETAIL_PRICEBOOK, saved.Pricebook2.Name);
        Contact c = [SELECT FirstName, LastName, Email, Phone, AccountId FROM Contact WHERE Id = :saved.Customer_Contact__c];
        Assert.areEqual('Priya', c.FirstName);
        Assert.areEqual('Sharma', c.LastName);
        Assert.areEqual('priya@example.com', c.Email);
        Assert.areEqual(saved.AccountId, c.AccountId);
        OpportunityContactRole role = [SELECT ContactId, IsPrimary FROM OpportunityContactRole WHERE OpportunityId = :opp.Id];
        Assert.areEqual(c.Id, role.ContactId);
        Assert.isTrue(role.IsPrimary);
    }

    @IsTest
    static void newWholesaleCustomerUsesCompanyNameAndWholesalePricing() {
        Opportunity opp = TestDataFactory.buildOpportunity('Wholesale', 'Rahul Mehta', 'rahul@fashionhub.example.com', '9822001122');
        opp.Company_Name__c = 'Fashion Hub Traders';
        insert opp;

        Opportunity saved = reload(opp.Id);
        Assert.areEqual('Fashion Hub Traders', saved.Account.Name);
        Assert.areEqual('Wholesale', saved.Account.RecordType.DeveloperName);
        Assert.areEqual(BlushConstants.WHOLESALE_PRICEBOOK, saved.Pricebook2.Name);
    }

    @IsTest
    static void singleWordNameBecomesLastName() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Madhuri', 'madhuri@example.com', null);
        insert opp;
        Contact c = [SELECT FirstName, LastName FROM Contact WHERE Id = :reload(opp.Id).Customer_Contact__c];
        Assert.isNull(c.FirstName);
        Assert.areEqual('Madhuri', c.LastName);
    }

    @IsTest
    static void matchingLeadByEmailIsConverted() {
        Lead l = createLead('Anita Desai', 'Anita@Example.com', null);
        Opportunity opp = TestDataFactory.buildOpportunity('Wholesale', 'Anita Desai', 'anita@example.com', null);

        Test.startTest();
        insert opp;
        Test.stopTest();

        Lead converted = [SELECT IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted);
        Assert.isNull(converted.ConvertedOpportunityId, 'Lead conversion must not create a second opportunity');
        Opportunity saved = reload(opp.Id);
        Assert.areEqual(converted.ConvertedAccountId, saved.AccountId);
        Assert.areEqual(converted.ConvertedContactId, saved.Customer_Contact__c);
        Assert.areEqual('Wholesale', saved.Account.RecordType.DeveloperName, 'Converted account follows the opportunity channel');
        Assert.areEqual(1, [SELECT COUNT() FROM Opportunity]);
    }

    @IsTest
    static void matchingLeadByPhoneIgnoresFormatting() {
        Lead l = createLead('Kiran Rao', null, '9123456780');
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Kiran Rao', null, '+91 9123456780');
        insert opp;

        Assert.isTrue([SELECT IsConverted FROM Lead WHERE Id = :l.Id].IsConverted);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void emailMatchWinsOverPhoneMatch() {
        Lead byEmail = createLead('Email Lead', 'same@example.com', '9000000001');
        Lead byPhone = createLead('Phone Lead', 'other@example.com', '9000000002');
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Someone', 'same@example.com', '9000000002');
        insert opp;

        Assert.isTrue([SELECT IsConverted FROM Lead WHERE Id = :byEmail.Id].IsConverted);
        Assert.isFalse([SELECT IsConverted FROM Lead WHERE Id = :byPhone.Id].IsConverted);
    }

    @IsTest
    static void existingContactIsReusedInsteadOfCreatingDuplicate() {
        Account acc = TestDataFactory.createAccount('Sneha Kulkarni', 'Retail', TestDataFactory.MAHARASHTRA);
        Contact c = new Contact(AccountId = acc.Id, LastName = 'Kulkarni', FirstName = 'Sneha', Email = 'sneha@example.com');
        insert c;
        createLead('Sneha Lead', 'sneha@example.com', null);

        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Sneha Kulkarni', 'SNEHA@example.com', null);
        insert opp;

        Opportunity saved = reload(opp.Id);
        Assert.areEqual(acc.Id, saved.AccountId);
        Assert.areEqual(c.Id, saved.Customer_Contact__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'No duplicate customer account');
        Assert.areEqual(0, [SELECT COUNT() FROM Lead WHERE IsConverted = TRUE], 'Existing customer takes precedence over the lead');
    }

    @IsTest
    static void selectedAccountIsKept() {
        Account acc = TestDataFactory.createAccount('Walk-in Customer', 'Retail', null);
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Ignored', null, null);
        opp.AccountId = acc.Id;
        insert opp;
        Assert.areEqual(acc.Id, reload(opp.Id).AccountId);
    }

    @IsTest
    static void opportunityWithoutAccountEmailOrPhoneIsRejected() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'No Contact Details', null, null);
        Database.SaveResult result = Database.insert(opp, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('Customer Email or Customer Phone'));
    }

    @IsTest
    static void newCustomerRequiresName() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', null, 'nobody@example.com', null);
        opp.Name = 'Unnamed';
        Database.SaveResult result = Database.insert(opp, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('Customer Name is required'));
        Assert.areEqual(0, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void retailOpportunityCannotUseWholesaleAccount() {
        Account acc = TestDataFactory.createAccount('Trader', 'Wholesale', TestDataFactory.MAHARASHTRA);
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Trader', null, null);
        opp.AccountId = acc.Id;
        Database.SaveResult result = Database.insert(opp, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('must be linked to a Retail account'));
    }

    @IsTest
    static void retailOpportunityCannotUseWholesalePricebook() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Wrong Book', 'wrong@example.com', null);
        opp.Pricebook2Id = PricebookService.getChannelPricebookId('Wholesale');
        Database.SaveResult result = Database.insert(opp, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains(BlushConstants.RETAIL_PRICEBOOK));
    }

    @IsTest
    static void changingRecordTypeSwitchesPricebook() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Switcher', 'switch@example.com', null);
        insert opp;
        Account acc = [SELECT Id FROM Account];
        acc.RecordTypeId = BlushConstants.recordTypeId(Account.SObjectType, 'Wholesale');
        update acc;

        opp.RecordTypeId = BlushConstants.recordTypeId(Opportunity.SObjectType, 'Wholesale');
        update opp;

        Assert.areEqual(BlushConstants.WHOLESALE_PRICEBOOK, reload(opp.Id).Pricebook2.Name);
    }

    @IsTest
    static void missingChannelPricebookIsReported() {
        delete [SELECT Id FROM Pricebook2 WHERE Name = :BlushConstants.RETAIL_PRICEBOOK];
        PricebookService.clearCache();
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'No Book', 'nobook@example.com', null);
        Database.SaveResult result = Database.insert(opp, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('missing or inactive'));
    }

    @IsTest
    static void bulkOpportunitiesCreateOneCustomerEach() {
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(TestDataFactory.buildOpportunity(Math.mod(i, 2) == 0 ? 'Retail' : 'Wholesale', 'Customer ' + i, 'bulk' + i + '@example.com', null));
        }

        Test.startTest();
        insert opps;
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM Account]);
        Assert.areEqual(200, [SELECT COUNT() FROM OpportunityContactRole]);
        Assert.areEqual(100, [SELECT COUNT() FROM Account WHERE RecordType.DeveloperName = 'Wholesale']);
    }

    @IsTest
    static void queueOwnedLeadIsConvertedToTheCurrentUser() {
        Group queue = new Group(Name = 'Blush Web Leads', Type = 'Queue');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert queue;
            insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Lead');
        }
        Lead l = new Lead(LastName = 'Queue Lead', Company = 'Queue Lead', Email = 'queue@example.com', OwnerId = queue.Id);
        insert l;

        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Queue Lead', 'queue@example.com', null);
        insert opp;

        Assert.isTrue([SELECT IsConverted FROM Lead WHERE Id = :l.Id].IsConverted);
        Assert.areEqual(UserInfo.getUserId(), [SELECT OwnerId FROM Account WHERE Id = :reload(opp.Id).AccountId].OwnerId);
    }

    @IsTest
    static void failedLeadConversionIsReportedOnTheOpportunity() {
        User formerRep = TestDataFactory.createUser('Standard User', null);
        Lead l = new Lead(LastName = 'Orphan Lead', Company = 'Orphan Lead', Email = 'orphan@example.com', OwnerId = formerRep.Id);
        insert l;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            formerRep.IsActive = false;
            update formerRep;
        }

        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Orphan Lead', 'orphan@example.com', null);
        Database.SaveResult result = Database.insert(opp, false);

        Assert.isFalse(result.isSuccess(), 'A lead owned by an inactive user cannot be converted');
        Assert.isTrue(result.getErrors()[0].getMessage().contains('could not be converted'), result.getErrors()[0].getMessage());
        Assert.isFalse([SELECT IsConverted FROM Lead WHERE Id = :l.Id].IsConverted);
    }

    @IsTest
    static void clearingTheAccountOnUpdateResolvesTheCustomerAgain() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'First Customer', 'first@example.com', null);
        insert opp;
        Id firstAccount = reload(opp.Id).AccountId;

        opp.AccountId = null;
        opp.Customer_Name__c = 'Second Customer';
        opp.Customer_Email__c = 'second@example.com';
        update opp;

        Opportunity saved = reload(opp.Id);
        Assert.areNotEqual(firstAccount, saved.AccountId);
        Assert.areEqual('Second Customer', saved.Account.Name);
        Assert.areEqual(2, [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :opp.Id]);
    }

    @IsTest
    static void switchingToAContactThatAlreadyHasARoleAddsNoDuplicate() {
        Opportunity opp = TestDataFactory.buildOpportunity('Retail', 'Family Buyer', 'family@example.com', null);
        insert opp;
        Opportunity saved = reload(opp.Id);
        Contact spouse = new Contact(AccountId = saved.AccountId, LastName = 'Spouse', Email = 'spouse@example.com');
        insert spouse;
        insert new OpportunityContactRole(OpportunityId = opp.Id, ContactId = spouse.Id, Role = 'Influencer');

        opp.Customer_Contact__c = spouse.Id;
        update opp;

        Assert.areEqual(2, [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :opp.Id]);
    }

    @IsTest
    static void phoneNormalization() {
        Assert.areEqual('9876543210', OpportunityCustomerService.normalizePhone('+91 98765-43210'));
        Assert.areEqual('9876543210', OpportunityCustomerService.normalizePhone('09876543210'));
        Assert.areEqual('2012345', OpportunityCustomerService.normalizePhone('20-12345'));
        Assert.isNull(OpportunityCustomerService.normalizePhone('123'));
        Assert.isNull(OpportunityCustomerService.normalizePhone('  '));
        Assert.areEqual('a@b.com', OpportunityCustomerService.normalizeEmail(' A@B.com '));
    }
}