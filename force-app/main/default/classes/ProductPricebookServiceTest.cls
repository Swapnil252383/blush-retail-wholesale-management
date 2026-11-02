@IsTest
private class ProductPricebookServiceTest {
    private static Map<Id, PricebookEntry> entriesByPricebook(Id productId) {
        Map<Id, PricebookEntry> result = new Map<Id, PricebookEntry>();
        for (PricebookEntry entry : [SELECT Pricebook2Id, UnitPrice, IsActive FROM PricebookEntry WHERE Product2Id = :productId]) {
            result.put(entry.Pricebook2Id, entry);
        }
        return result;
    }

    @IsTest
    static void productForBothChannelsGetsRetailAndWholesalePrices() {
        Map<String, Id> pricebooks = TestDataFactory.createPricebooks();
        Product2 jeans = TestDataFactory.buildProduct('Jeans', '10#001', 'Garments', 'Retail;Wholesale', 500);

        Test.startTest();
        insert jeans;
        Test.stopTest();

        Map<Id, PricebookEntry> entries = entriesByPricebook(jeans.Id);
        Assert.areEqual(3, entries.size(), 'Standard, retail and wholesale entries expected');
        Assert.areEqual(500, entries.get(Test.getStandardPricebookId()).UnitPrice);
        Assert.areEqual(500, entries.get(pricebooks.get('Retail')).UnitPrice, 'Retail price = base price');
        Assert.areEqual(350, entries.get(pricebooks.get('Wholesale')).UnitPrice, 'Wholesale price = base price less 30%');
    }

    @IsTest
    static void retailOnlyProductHasNoWholesaleEntry() {
        Map<String, Id> pricebooks = TestDataFactory.createPricebooks();
        Product2 gown = TestDataFactory.buildProduct('Gown', '10#002', 'Garments', 'Retail', 1500);
        insert gown;

        Map<Id, PricebookEntry> entries = entriesByPricebook(gown.Id);
        Assert.isTrue(entries.containsKey(pricebooks.get('Retail')));
        Assert.isFalse(entries.containsKey(pricebooks.get('Wholesale')));
    }

    @IsTest
    static void productWithoutChannelGetsNoEntries() {
        TestDataFactory.createPricebooks();
        Product2 draft = TestDataFactory.buildProduct('Draft', 'D1', 'Jewellery', null, 100);
        insert draft;
        Assert.areEqual(0, entriesByPricebook(draft.Id).size());
    }

    @IsTest
    static void addingAChannelLaterCreatesTheEntry() {
        Map<String, Id> pricebooks = TestDataFactory.createPricebooks();
        Product2 ring = TestDataFactory.buildProduct('Ring', '20#002', 'Jewellery', 'Retail', 1000);
        insert ring;

        ring.Sales_Channel__c = 'Retail;Wholesale';
        update ring;

        PricebookEntry wholesale = entriesByPricebook(ring.Id).get(pricebooks.get('Wholesale'));
        Assert.isNotNull(wholesale, 'Sales users can sell to wholesale with no admin setup');
        Assert.areEqual(700, wholesale.UnitPrice);
        Assert.isTrue(wholesale.IsActive);
    }

    @IsTest
    static void removingAChannelDeactivatesTheEntry() {
        Map<String, Id> pricebooks = TestDataFactory.createPricebooks();
        Product2 jeans = TestDataFactory.buildProduct('Jeans', '10#001', 'Garments', 'Retail;Wholesale', 500);
        insert jeans;

        jeans.Sales_Channel__c = 'Retail';
        update jeans;

        Map<Id, PricebookEntry> entries = entriesByPricebook(jeans.Id);
        Assert.isFalse(entries.get(pricebooks.get('Wholesale')).IsActive);
        Assert.isTrue(entries.get(pricebooks.get('Retail')).IsActive);
    }

    @IsTest
    static void basePriceChangeUpdatesAllPrices() {
        Map<String, Id> pricebooks = TestDataFactory.createPricebooks();
        Product2 jeans = TestDataFactory.buildProduct('Jeans', '10#001', 'Garments', 'Retail;Wholesale', 500);
        insert jeans;

        jeans.Base_Price__c = 999.99;
        update jeans;

        Map<Id, PricebookEntry> entries = entriesByPricebook(jeans.Id);
        Assert.areEqual(999.99, entries.get(Test.getStandardPricebookId()).UnitPrice);
        Assert.areEqual(999.99, entries.get(pricebooks.get('Retail')).UnitPrice);
        Assert.areEqual(699.99, entries.get(pricebooks.get('Wholesale')).UnitPrice, '999.99 x 0.7 = 699.993, rounded half up');
    }

    @IsTest
    static void deactivatingProductDeactivatesChannelEntries() {
        Map<String, Id> pricebooks = TestDataFactory.createPricebooks();
        Product2 jeans = TestDataFactory.buildProduct('Jeans', '10#001', 'Garments', 'Retail;Wholesale', 500);
        insert jeans;

        jeans.IsActive = false;
        update jeans;

        Map<Id, PricebookEntry> entries = entriesByPricebook(jeans.Id);
        Assert.isFalse(entries.get(pricebooks.get('Retail')).IsActive);
        Assert.isFalse(entries.get(pricebooks.get('Wholesale')).IsActive);
    }

    @IsTest
    static void unrelatedUpdateDoesNotTouchEntries() {
        TestDataFactory.createPricebooks();
        Product2 jeans = TestDataFactory.buildProduct('Jeans', '10#001', 'Garments', 'Retail', 500);
        insert jeans;
        Integer queriesBefore = Limits.getQueries();

        jeans.Description = 'Blue denim';
        update jeans;

        Assert.areEqual(queriesBefore, Limits.getQueries(), 'No price book work when channel, price and status are unchanged');
    }

    @IsTest
    static void missingPricebooksBlockChannelAssignment() {
        Product2 jeans = TestDataFactory.buildProduct('Jeans', '10#001', 'Garments', 'Retail', 500);
        try {
            insert jeans;
            Assert.fail('Expected an error when Blush price books do not exist');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('price books are missing'), e.getMessage());
        }
    }

    @IsTest
    static void channelWithoutBasePriceIsRejected() {
        TestDataFactory.createPricebooks();
        Product2 jeans = TestDataFactory.buildProduct('Jeans', '10#001', 'Garments', 'Retail', null);
        try {
            insert jeans;
            Assert.fail('Validation rule should require a base price');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Base Price'), e.getMessage());
        }
    }

    @IsTest
    static void bulkInsertCreatesEntriesForEveryProduct() {
        TestDataFactory.createPricebooks();
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < 200; i++) {
            products.add(TestDataFactory.buildProduct('Bulk ' + i, 'B' + i, Math.mod(i, 2) == 0 ? 'Garments' : 'Jewellery', 'Retail;Wholesale', 100 + i));
        }

        Test.startTest();
        insert products;
        Test.stopTest();

        Assert.areEqual(600, [SELECT COUNT() FROM PricebookEntry WHERE Product2Id IN :products]);
    }
}