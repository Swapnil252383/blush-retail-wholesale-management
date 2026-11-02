@IsTest
private class OrderItemTaxServiceTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createCatalog();
    }

    private static Map<String, Product2> products() {
        Map<String, Product2> result = new Map<String, Product2>();
        for (Product2 p : [SELECT Id, Name FROM Product2]) {
            result.put(p.Name, p);
        }
        return result;
    }

    private static Order reloadOrder(Id orderId) {
        return [
            SELECT
                Tax_Type__c,
                Total_Discount__c,
                Effective_Order_Amount__c,
                Total_CGST__c,
                Total_SGST__c,
                Total_IGST__c,
                Total_GST__c,
                Net_Amount__c,
                Commission__c,
                Max_Discount_Percent__c,
                Approval_Status__c
            FROM Order
            WHERE Id = :orderId
        ];
    }

    private static OrderItem reloadItem(Id itemId) {
        return [
            SELECT Taxable_Amount__c, GST_Rate__c, CGST__c, SGST__c, IGST__c, Total_Tax__c, Net_Price__c, Discount_Percent__c, Line_Discount__c
            FROM OrderItem
            WHERE Id = :itemId
        ];
    }

    @IsTest
    static void maharashtraGarmentLineSplitsGstIntoCgstAndSgst() {
        Account acc = TestDataFactory.createAccount('Priya', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');

        Test.startTest();
        OrderItem item = TestDataFactory.createItem(o, products().get('Jeans'), 1, 25);
        Test.stopTest();

        // Sample invoice: Jeans 500, discount 25 -> taxable 475, GST 5% = 23.75
        OrderItem saved = reloadItem(item.Id);
        Assert.areEqual(475, saved.Taxable_Amount__c);
        Assert.areEqual(5, saved.GST_Rate__c);
        Assert.areEqual(23.75, saved.Total_Tax__c);
        Assert.areEqual(11.88, saved.CGST__c);
        Assert.areEqual(11.87, saved.SGST__c);
        Assert.areEqual(0, saved.IGST__c);
        Assert.areEqual(498.75, saved.Net_Price__c, '(500 - 25) x 1 + 23.75');
        Assert.areEqual(5, saved.Discount_Percent__c);

        Order totals = reloadOrder(o.Id);
        Assert.areEqual(BlushConstants.TAX_TYPE_INTRA_STATE, totals.Tax_Type__c);
        Assert.areEqual(475, totals.Effective_Order_Amount__c, 'Effective amount = net received minus taxes');
        Assert.areEqual(4.75, totals.Commission__c, '1% of 475');
        Assert.areEqual(BlushConstants.APPROVAL_NOT_REQUIRED, totals.Approval_Status__c);
    }

    @IsTest
    static void outOfStateGarmentAboveThousandUsesTwelvePercentIgst() {
        Account acc = TestDataFactory.createAccount('Bengaluru Buyer', 'Retail', TestDataFactory.KARNATAKA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');

        OrderItem item = TestDataFactory.createItem(o, products().get('Gown'), 2, 100);

        OrderItem saved = reloadItem(item.Id);
        Assert.areEqual(2800, saved.Taxable_Amount__c, '(1500 - 100) x 2');
        Assert.areEqual(12, saved.GST_Rate__c, 'Per-unit value 1400 is above Rs. 1,000');
        Assert.areEqual(336, saved.IGST__c);
        Assert.areEqual(0, saved.CGST__c);
        Assert.areEqual(0, saved.SGST__c);
        Assert.areEqual(3136, saved.Net_Price__c);
        Assert.areEqual(200, saved.Line_Discount__c);

        Order totals = reloadOrder(o.Id);
        Assert.areEqual(BlushConstants.TAX_TYPE_INTER_STATE, totals.Tax_Type__c);
        Assert.areEqual(336, totals.Total_IGST__c);
        Assert.areEqual(30, totals.Commission__c, 'Flat Rs. 30 above Rs. 1,000');
    }

    @IsTest
    static void jewelleryUsesThreePercentAndOrderTotalsAddUp() {
        Account acc = TestDataFactory.createAccount('Mixed Basket', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        Map<String, Product2> catalog = products();
        insert new List<OrderItem>{
            TestDataFactory.buildItem(o, catalog.get('Jeans'), 2, 0),
            TestDataFactory.buildItem(o, catalog.get('Necklace'), 1, 50)
        };

        Order totals = reloadOrder(o.Id);
        // Jeans 2 x 500 = 1000 @5% = 50; Necklace 750 @3% = 22.50
        Assert.areEqual(1750, totals.Effective_Order_Amount__c);
        Assert.areEqual(72.5, totals.Total_GST__c);
        Assert.areEqual(36.25, totals.Total_CGST__c);
        Assert.areEqual(36.25, totals.Total_SGST__c);
        Assert.areEqual(1822.5, totals.Net_Amount__c);
        Assert.areEqual(50, totals.Total_Discount__c);
        Assert.areEqual(30, totals.Commission__c);
    }

    @IsTest
    static void commissionAtExactlyOneThousandIsOnePercent() {
        Account acc = TestDataFactory.createAccount('Boundary', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        TestDataFactory.createItem(o, products().get('Jeans'), 2, 0);
        Order totals = reloadOrder(o.Id);
        Assert.areEqual(1000, totals.Effective_Order_Amount__c);
        Assert.areEqual(10, totals.Commission__c);
    }

    @IsTest
    static void wholesaleOrderUsesWholesalePrice() {
        Account acc = TestDataFactory.createAccount('Trader', 'Wholesale', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Wholesale');
        OrderItem item = TestDataFactory.createItem(o, products().get('Jeans'), 10, 0);
        Assert.areEqual(350, [SELECT UnitPrice FROM OrderItem WHERE Id = :item.Id].UnitPrice);
        Assert.areEqual(3500, reloadOrder(o.Id).Effective_Order_Amount__c);
    }

    @IsTest
    static void discountAboveTenPercentIsSubmittedForApproval() {
        Account acc = TestDataFactory.createAccount('Bargain Hunter', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');

        Test.startTest();
        TestDataFactory.createItem(o, products().get('Jeans'), 1, 60); // 12%
        Test.stopTest();

        Order saved = reloadOrder(o.Id);
        Assert.areEqual(12, saved.Max_Discount_Percent__c);
        Assert.areEqual(BlushConstants.APPROVAL_PENDING, saved.Approval_Status__c);
        Assert.areEqual(1, [SELECT COUNT() FROM ProcessInstance WHERE TargetObjectId = :o.Id AND Status = 'Pending']);
    }

    @IsTest
    static void discountOfExactlyTenPercentNeedsNoApproval() {
        Account acc = TestDataFactory.createAccount('Fair Discount', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        TestDataFactory.createItem(o, products().get('Jeans'), 1, 50);
        Assert.areEqual(BlushConstants.APPROVAL_NOT_REQUIRED, reloadOrder(o.Id).Approval_Status__c);
        Assert.areEqual(0, [SELECT COUNT() FROM ProcessInstance WHERE TargetObjectId = :o.Id]);
    }

    @IsTest
    static void unapprovedDiscountBlocksPayment() {
        Account acc = TestDataFactory.createAccount('Unapproved', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        TestDataFactory.createItem(o, products().get('Jeans'), 1, 100);

        o.Payment_Mode__c = 'UPI';
        o.Payment_Status__c = 'Paid';
        Database.SaveResult result = Database.update(o, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('must be approved'), result.getErrors()[0].getMessage());
    }

    @IsTest
    static void approvedDiscountAllowsPayment() {
        Account acc = TestDataFactory.createAccount('Approved', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        TestDataFactory.createItem(o, products().get('Jeans'), 1, 100);
        ProcessInstanceWorkitem work = [SELECT Id FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId = :o.Id];
        Approval.ProcessWorkitemRequest approve = new Approval.ProcessWorkitemRequest();
        approve.setWorkitemId(work.Id);
        approve.setAction('Approve');
        Approval.process(approve);
        Assert.areEqual(BlushConstants.APPROVAL_APPROVED, reloadOrder(o.Id).Approval_Status__c);

        o.Payment_Mode__c = 'Cash';
        o.Payment_Status__c = 'Paid';
        update o;
        Assert.areEqual('Paid', [SELECT Payment_Status__c FROM Order WHERE Id = :o.Id].Payment_Status__c);
    }

    @IsTest
    static void discountAboveUnitPriceIsRejected() {
        Account acc = TestDataFactory.createAccount('Too Much', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        OrderItem item = TestDataFactory.buildItem(o, products().get('Jeans'), 1, 600);
        Database.SaveResult result = Database.insert(item, false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('between 0 and the unit price'));
    }

    @IsTest
    static void deletingALineUpdatesTotals() {
        Account acc = TestDataFactory.createAccount('Changer', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        OrderItem item = TestDataFactory.createItem(o, products().get('Jeans'), 1, 0);
        delete item;
        Order totals = reloadOrder(o.Id);
        Assert.areEqual(0, totals.Net_Amount__c);
        Assert.areEqual(0, totals.Commission__c);
    }

    @IsTest
    static void paidOrderLinesCannotBeChangedOrDeletedBySalesUser() {
        User rep = TestDataFactory.createUser('Standard User', 'Blush_Sales_User');
        Account acc = TestDataFactory.createAccount('Paid Customer', 'Retail', TestDataFactory.MAHARASHTRA);
        Product2 jeans = products().get('Jeans');

        System.runAs(rep) {
            Order o = TestDataFactory.createOrder(acc, 'Retail');
            OrderItem item = TestDataFactory.createItem(o, jeans, 1, 0);
            o.Payment_Mode__c = 'Card';
            o.Payment_Status__c = 'Paid';
            update o;

            item.Quantity = 2;
            Database.SaveResult updateResult = Database.update(item, false);
            Assert.isFalse(updateResult.isSuccess());
            Assert.isTrue(updateResult.getErrors()[0].getMessage().contains('paid order'));

            Database.DeleteResult deleteResult = Database.delete(item, false);
            Assert.isFalse(deleteResult.isSuccess());
            Assert.isTrue(deleteResult.getErrors()[0].getMessage().contains('paid order'));
        }
    }

    @IsTest
    static void managerCanCorrectLinesOnPaidOrder() {
        User manager = TestDataFactory.createUser('System Administrator', 'Blush_Manager');
        Account acc = TestDataFactory.createAccount('Correction', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        OrderItem item = TestDataFactory.createItem(o, products().get('Jeans'), 1, 0);
        o.Payment_Mode__c = 'Card';
        o.Payment_Status__c = 'Paid';
        update o;

        System.runAs(manager) {
            Assert.isTrue(FeatureManagement.checkPermission(BlushConstants.PERMISSION_EDIT_PAID_ORDERS), 'Manager has Edit Paid Orders');
            item.Quantity = 2;
            update item;
            Assert.areEqual(1000, reloadOrder(o.Id).Effective_Order_Amount__c);
            Assert.areEqual('Paid', [SELECT Payment_Status__c FROM Order WHERE Id = :o.Id].Payment_Status__c);
            delete item;
        }
        Assert.areEqual(0, reloadOrder(o.Id).Effective_Order_Amount__c);
    }

    @IsTest
    static void approvedOrderIsResubmittedWhenDiscountIncreases() {
        Account acc = TestDataFactory.createAccount('Haggler', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        Map<String, Product2> catalog = products();
        TestDataFactory.createItem(o, catalog.get('Jeans'), 1, 60); // 12%
        Approval.ProcessWorkitemRequest approve = new Approval.ProcessWorkitemRequest();
        approve.setWorkitemId([SELECT Id FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId = :o.Id].Id);
        approve.setAction('Approve');
        Approval.process(approve);

        Test.startTest();
        TestDataFactory.createItem(o, catalog.get('Necklace'), 1, 160); // 20%
        Test.stopTest();

        Order saved = reloadOrder(o.Id);
        Assert.areEqual(20, saved.Max_Discount_Percent__c);
        Assert.areEqual(BlushConstants.APPROVAL_PENDING, saved.Approval_Status__c, 'A bigger discount needs a fresh approval');
    }

    @IsTest
    static void approvedOrderStaysApprovedWhenDiscountDoesNotIncrease() {
        Account acc = TestDataFactory.createAccount('Steady', 'Retail', TestDataFactory.MAHARASHTRA);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        Map<String, Product2> catalog = products();
        TestDataFactory.createItem(o, catalog.get('Jeans'), 1, 60); // 12%
        Approval.ProcessWorkitemRequest approve = new Approval.ProcessWorkitemRequest();
        approve.setWorkitemId([SELECT Id FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId = :o.Id].Id);
        approve.setAction('Approve');
        Approval.process(approve);

        TestDataFactory.createItem(o, catalog.get('Necklace'), 1, 0);

        Assert.areEqual(BlushConstants.APPROVAL_APPROVED, reloadOrder(o.Id).Approval_Status__c);
    }

    @IsTest
    static void unknownCategoryCannotBeTaxed() {
        OrderItem item = new OrderItem(UnitPrice = 100, Quantity = 1, Discount__c = 0);
        OrderItemTaxService.calculateLine(item, 'Footwear', BlushConstants.TAX_TYPE_INTRA_STATE);
        Assert.isTrue(item.hasErrors());
        Assert.isNull(item.Net_Price__c);
    }

    @IsTest
    static void bulkLinesAreTaxedInOneTransaction() {
        Account acc = TestDataFactory.createAccount('Bulk Buyer', 'Wholesale', TestDataFactory.KARNATAKA);
        Order o = TestDataFactory.createOrder(acc, 'Wholesale');
        OrderItem template = TestDataFactory.buildItem(o, products().get('Jeans'), 1, 0);
        List<OrderItem> items = new List<OrderItem>();
        for (Integer i = 0; i < 200; i++) {
            items.add(template.clone());
        }

        Test.startTest();
        insert items;
        Test.stopTest();

        Order totals = reloadOrder(o.Id);
        Assert.areEqual(70000, totals.Effective_Order_Amount__c, '200 x 350');
        Assert.areEqual(3500, totals.Total_IGST__c);
    }
}