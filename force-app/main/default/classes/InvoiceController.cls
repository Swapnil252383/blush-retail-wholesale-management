/**
 * Backs the BlushInvoice Visualforce PDF and the "Generate Invoice" quick action (requirements G.23, G.24).
 */
public with sharing class InvoiceController {
    public Order order { get; private set; }
    public List<OrderItem> items { get; private set; }
    public Store__c store { get; private set; }

    public InvoiceController(ApexPages.StandardController controller) {
        Id orderId = controller.getId();
        order = [
            SELECT
                Id,
                OrderNumber,
                Invoice_Number__c,
                EffectiveDate,
                Customer_Name__c,
                Account.Phone,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry,
                Payment_Mode__c,
                Payment_Status__c,
                Tax_Type__c,
                Sales_Channel__c,
                Total_Discount__c,
                Effective_Order_Amount__c,
                Total_CGST__c,
                Total_SGST__c,
                Total_IGST__c,
                Total_GST__c,
                Net_Amount__c,
                Store__c
            FROM Order
            WHERE Id = :orderId
            WITH USER_MODE
        ];
        items = [
            SELECT
                Id,
                Product_Code__c,
                Product_Name__c,
                Description,
                Quantity,
                UnitPrice,
                Discount__c,
                GST_Rate__c,
                CGST__c,
                SGST__c,
                IGST__c,
                Net_Price__c
            FROM OrderItem
            WHERE OrderId = :orderId
            WITH USER_MODE
            ORDER BY OrderItemNumber
        ];
        List<Store__c> stores = [
            SELECT Name, Street__c, City__c, State__c, Postal_Code__c, GSTIN__c, Phone__c, Website__c
            FROM Store__c
            WHERE Id = :order.Store__c
            WITH USER_MODE
        ];
        store = stores.isEmpty() ? new Store__c(Name = 'Blush') : stores[0];
    }

    /** True when CGST/SGST apply; false for IGST. The page shows only the relevant columns. */
    public Boolean isIntraState {
        get {
            return order.Tax_Type__c != BlushConstants.TAX_TYPE_INTER_STATE;
        }
    }

    /** Renders the invoice PDF and saves it to the order's Files. Returns the ContentDocumentId. */
    @AuraEnabled
    public static Id saveInvoicePdf(Id orderId) {
        try {
            Order o = [SELECT Id, Invoice_Number__c FROM Order WHERE Id = :orderId WITH USER_MODE];
            PageReference page = Page.BlushInvoice;
            page.getParameters().put('id', orderId);
            // getContentAsPDF is not supported in tests.
            Blob pdf = Test.isRunningTest() ? Blob.valueOf('Invoice ' + o.Invoice_Number__c) : page.getContentAsPDF();
            ContentVersion version = new ContentVersion(
                Title = o.Invoice_Number__c,
                PathOnClient = o.Invoice_Number__c + '.pdf',
                VersionData = pdf,
                FirstPublishLocationId = orderId
            );
            insert as user version;
            return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id WITH USER_MODE].ContentDocumentId;
        } catch (Exception e) {
            AuraHandledException error = new AuraHandledException(e.getMessage());
            error.setMessage(e.getMessage());
            throw error;
        }
    }
}