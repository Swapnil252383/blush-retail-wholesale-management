@IsTest
private class OrderServiceTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createCatalog();
    }

    private static Product2 product(String name) {
        return [SELECT Id FROM Product2 WHERE Name = :name];
    }

    @IsTest
    static void orderFromOpportunityInheritsCustomerChannelRepAndProducts() {
        Opportunity opp = TestDataFactory.buildOpportunity('Wholesale', 'Rahul Mehta', 'rahul@example.com', null);
        opp.Company_Name__c = 'Mehta Garments';
        insert opp;
        Account acc = [SELECT Id FROM Account];
        acc.BillingState = TestDataFactory.KARNATAKA;
        acc.BillingCountry = 'India';
        update acc;
        PricebookEntry entry = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id = :product('Jeans').Id AND Pricebook2.Name = :BlushConstants.WHOLESALE_PRICEBOOK
        ];
        insert new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = entry.Id, Quantity = 4, UnitPrice = entry.UnitPrice, Discount = 10);

        Order o = new Order(OpportunityId = opp.Id, EffectiveDate = Date.today(), Status = 'Draft');
        Test.startTest();
        insert o;
        Test.stopTest();

        Order saved = [
            SELECT AccountId, RecordType.DeveloperName, Pricebook2.Name, Sales_Representative__c, Store__c, Tax_Type__c, BillingState,
                Effective_Order_Amount__c, Approval_Status__c, Payment_Status__c
            FROM Order
            WHERE Id = :o.Id
        ];
        Assert.areEqual(acc.Id, saved.AccountId);
        Assert.areEqual('Wholesale', saved.RecordType.DeveloperName);
        Assert.areEqual(BlushConstants.WHOLESALE_PRICEBOOK, saved.Pricebook2.Name);
        Assert.areEqual(UserInfo.getUserId(), saved.Sales_Representative__c, 'Opportunity owner handles the customer');
        Assert.isNotNull(saved.Store__c, 'Default store applied');
        Assert.areEqual(TestDataFactory.KARNATAKA, saved.BillingState, 'Billing address copied from account');
        Assert.areEqual(BlushConstants.TAX_TYPE_INTER_STATE, saved.Tax_Type__c);
        Assert.areEqual('Pending', saved.Payment_Status__c);

        OrderItem line = [SELECT Quantity, UnitPrice, Discount__c FROM OrderItem WHERE OrderId = :o.Id];
        Assert.areEqual(4, line.Quantity);
        Assert.areEqual(350, line.UnitPrice);
        Assert.areEqual(35, line.Discount__c, '10% opportunity discount becomes Rs. 35 per unit');
        Assert.areEqual(1260, saved.Effective_Order_Amount__c, '(350 - 35) x 4');
        Assert.areEqual(BlushConstants.APPROVAL_NOT_REQUIRED, saved.Approval_Status__c);
    }

    @IsTest
    static void orderWithoutRecordTypeDefaultsToRetail() {
        Account acc = TestDataFactory.createAccount('Walk-in', 'Retail', null);
        Order o = new Order(AccountId = acc.Id, EffectiveDate = Date.today(), Status = 'Draft');
        insert o;
        Order saved = [SELECT RecordType.DeveloperName, Pricebook2.Name, Tax_Type__c FROM Order WHERE Id = :o.Id];
        Assert.areEqual('Retail', saved.RecordType.DeveloperName);
        Assert.areEqual(BlushConstants.RETAIL_PRICEBOOK, saved.Pricebook2.Name);
        Assert.areEqual(BlushConstants.TAX_TYPE_INTRA_STATE, saved.Tax_Type__c, 'Blank billing state = counter sale in Maharashtra');
    }

    @IsTest
    static void retailOrderCannotUseWholesaleAccount() {
        Account acc = TestDataFactory.createAccount('Trader', 'Wholesale', TestDataFactory.MAHARASHTRA);
        Database.SaveResult result = Database.insert(TestDataFactory.buildOrder(acc, 'Retail'), false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('must be placed for a Retail account'));
    }

    @IsTest
    static void retailOrderCannotUseWholesalePricebook() {
        Account acc = TestDataFactory.createAccount('Retail Buyer', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.buildOrder(acc, 'Retail');
        o.Pricebook2Id = PricebookService.getChannelPricebookId('Wholesale');
        Database.SaveResult result = Database.insert(o, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains(BlushConstants.RETAIL_PRICEBOOK));
    }

    @IsTest
    static void changingBillingStateRecalculatesTaxes() {
        Account acc = TestDataFactory.createAccount('Mover', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        OrderItem item = TestDataFactory.createItem(o, product('Jeans'), 1, 0);
        Assert.areEqual(12.5, [SELECT CGST__c FROM OrderItem WHERE Id = :item.Id].CGST__c);

        Test.startTest();
        o.BillingState = TestDataFactory.KARNATAKA;
        o.BillingCountry = 'India';
        update o;
        Test.stopTest();

        OrderItem saved = [SELECT CGST__c, SGST__c, IGST__c FROM OrderItem WHERE Id = :item.Id];
        Assert.areEqual(0, saved.CGST__c);
        Assert.areEqual(0, saved.SGST__c);
        Assert.areEqual(25, saved.IGST__c);
        Order totals = [SELECT Tax_Type__c, Total_IGST__c, Total_CGST__c FROM Order WHERE Id = :o.Id];
        Assert.areEqual(BlushConstants.TAX_TYPE_INTER_STATE, totals.Tax_Type__c);
        Assert.areEqual(25, totals.Total_IGST__c);
        Assert.areEqual(0, totals.Total_CGST__c);
    }

    @IsTest
    static void changingTheStatePicklistCodeSwitchesToIgst() {
        Account acc = TestDataFactory.createAccount('Code Change', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        o = [SELECT Id, BillingState, BillingCountry FROM Order WHERE Id = :o.Id];

        o.BillingState = null;
        o.put('BillingStateCode', 'KA');
        o.put('BillingCountryCode', 'IN');
        update o;

        Assert.areEqual(BlushConstants.TAX_TYPE_INTER_STATE, [SELECT Tax_Type__c FROM Order WHERE Id = :o.Id].Tax_Type__c);
    }

    @IsTest
    static void orderKeepsItsOwnBillingAddress() {
        Account acc = TestDataFactory.createAccount('Ship Elsewhere', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.buildOrder(acc, 'Retail');
        o.BillingCity = 'Bengaluru';
        o.BillingState = TestDataFactory.KARNATAKA;
        o.BillingCountry = 'India';
        insert o;

        Order saved = [SELECT BillingCity, Tax_Type__c FROM Order WHERE Id = :o.Id];
        Assert.areEqual('Bengaluru', saved.BillingCity, 'Account address must not overwrite the order address');
        Assert.areEqual(BlushConstants.TAX_TYPE_INTER_STATE, saved.Tax_Type__c);
    }

    @IsTest
    static void clearedSalesRepIsRestoredToOwner() {
        Account acc = TestDataFactory.createAccount('Rep Check', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        o.Sales_Representative__c = null;
        update o;
        Assert.areEqual(UserInfo.getUserId(), [SELECT Sales_Representative__c FROM Order WHERE Id = :o.Id].Sales_Representative__c);
    }

    @IsTest
    static void taxTypeRules() {
        Assert.areEqual(BlushConstants.TAX_TYPE_INTRA_STATE, OrderService.taxTypeFor(new Order(BillingState = 'Maharashtra', BillingCountry = 'India'), null));
        Assert.areEqual(BlushConstants.TAX_TYPE_INTRA_STATE, OrderService.taxTypeFor(new Order(BillingState = 'maharashtra'), null));
        Assert.areEqual(BlushConstants.TAX_TYPE_INTER_STATE, OrderService.taxTypeFor(new Order(BillingState = 'Gujarat', BillingCountry = 'India'), null));
        Assert.areEqual(BlushConstants.TAX_TYPE_INTER_STATE, OrderService.taxTypeFor(new Order(BillingState = 'MH', BillingCountry = 'Mexico'), null));
        Assert.areEqual(BlushConstants.TAX_TYPE_INTRA_STATE, OrderService.taxTypeFor(new Order(), null));
    }

    @IsTest
    static void paidOrderCannotBeEditedOrDeletedBySalesUser() {
        User rep = TestDataFactory.createUser('Standard User', 'Blush_Sales_User');
        Account acc = TestDataFactory.createAccount('Paid', 'Retail', TestDataFactory.MAHARASHTRA);
        Product2 jeans = product('Jeans');

        System.runAs(rep) {
            Order o = TestDataFactory.createOrder(acc, 'Retail');
            TestDataFactory.createItem(o, jeans, 1, 0);
            o.Description = 'Rep can edit while processing';
            update o;
            o.Payment_Mode__c = 'UPI';
            o.Payment_Status__c = 'Paid';
            update o;

            o.Description = 'Changed after payment';
            Database.SaveResult updateResult = Database.update(o, false);
            Assert.isFalse(updateResult.isSuccess());
            Assert.isTrue(updateResult.getErrors()[0].getMessage().contains('can no longer be edited'));

            Database.DeleteResult deleteResult = Database.delete(o, false);
            Assert.isFalse(deleteResult.isSuccess());
            Assert.isTrue(deleteResult.getErrors()[0].getMessage().contains('cannot be deleted'));
        }
    }

    @IsTest
    static void managerWithPermissionCanEditPaidOrder() {
        User manager = TestDataFactory.createUser('System Administrator', 'Blush_Manager');
        Account acc = TestDataFactory.createAccount('Paid', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        o.Payment_Mode__c = 'Cash';
        o.Payment_Status__c = 'Paid';
        update o;

        System.runAs(manager) {
            o.Description = 'Corrected by manager';
            update o;
            delete o;
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Order WHERE Id = :o.Id]);
    }

    @IsTest
    static void paymentModeIsRequiredWhenPaid() {
        Account acc = TestDataFactory.createAccount('No Mode', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        o.Payment_Status__c = 'Paid';
        Database.SaveResult result = Database.update(o, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('Payment Mode'));
    }

    @IsTest
    static void unpaidOrderCanBeEditedAndDeleted() {
        Account acc = TestDataFactory.createAccount('Draft', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        o.Description = 'Still processing';
        update o;
        delete o;
        Assert.areEqual(0, [SELECT COUNT() FROM Order WHERE Id = :o.Id]);
    }
}