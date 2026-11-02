@IsTest
private class InvoiceControllerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createCatalog();
    }

    private static Order createOrderWithLines(String state) {
        Account acc = TestDataFactory.createAccount('Invoice Customer', 'Retail', state);
        Order o = TestDataFactory.createOrder(acc, 'Retail');
        Map<String, Product2> catalog = new Map<String, Product2>();
        for (Product2 p : [SELECT Id, Name FROM Product2]) {
            catalog.put(p.Name, p);
        }
        insert new List<OrderItem>{ TestDataFactory.buildItem(o, catalog.get('Jeans'), 1, 25), TestDataFactory.buildItem(o, catalog.get('Necklace'), 2, 0) };
        o.Payment_Mode__c = 'UPI';
        update o;
        return o;
    }

    @IsTest
    static void loadsInvoiceDataForIntraStateOrder() {
        Order o = createOrderWithLines(TestDataFactory.MAHARASHTRA);

        Test.setCurrentPage(Page.BlushInvoice);
        InvoiceController controller = new InvoiceController(new ApexPages.StandardController(o));

        Assert.areEqual(2, controller.items.size());
        Assert.areEqual('Blush - FC Road', controller.store.Name);
        Assert.areEqual('Invoice Customer', controller.order.Customer_Name__c);
        Assert.areEqual('UPI', controller.order.Payment_Mode__c);
        Assert.isTrue(controller.order.Invoice_Number__c.startsWith('INV-'));
        Assert.isTrue(controller.isIntraState, 'Maharashtra invoices show CGST and SGST');
        Assert.areEqual('10#001', controller.items[0].Product_Code__c);
    }

    @IsTest
    static void interStateInvoiceShowsIgst() {
        Order o = createOrderWithLines(TestDataFactory.KARNATAKA);
        InvoiceController controller = new InvoiceController(new ApexPages.StandardController(o));
        Assert.isFalse(controller.isIntraState);
        Assert.isTrue(controller.order.Total_IGST__c > 0);
    }

    @IsTest
    static void orderWithoutStoreFallsBackToBrandName() {
        Order o = createOrderWithLines(TestDataFactory.MAHARASHTRA);
        o.Store__c = null;
        update o;
        InvoiceController controller = new InvoiceController(new ApexPages.StandardController(o));
        Assert.areEqual('Blush', controller.store.Name);
    }

    @IsTest
    static void savesInvoicePdfToOrderFiles() {
        Order o = createOrderWithLines(TestDataFactory.MAHARASHTRA);

        Test.startTest();
        Id documentId = InvoiceController.saveInvoicePdf(o.Id);
        Test.stopTest();

        ContentDocumentLink link = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :o.Id];
        Assert.areEqual(documentId, link.ContentDocumentId);
        String invoiceNumber = [SELECT Invoice_Number__c FROM Order WHERE Id = :o.Id].Invoice_Number__c;
        Assert.areEqual(invoiceNumber, [SELECT Title FROM ContentDocument WHERE Id = :documentId].Title);
    }

    @IsTest
    static void saveInvoiceReportsErrors() {
        try {
            InvoiceController.saveInvoicePdf(null);
            Assert.fail('Expected an error for a missing order');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
    }
}