/**
 * Read/write helpers used by the Blush Control Center LWC.
 * Business calculations remain in ProductPricebookService, OrderService,
 * OrderItemTaxService, OpportunityCustomerService and the existing triggers.
 */
public with sharing class BlushWorkspaceController {
    public class RecordTypeOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String developerName;
        public RecordTypeOption(String labelValue, Id idValue, String developerValue) {
            label = labelValue;
            value = String.valueOf(idValue);
            developerName = developerValue;
        }
    }

    public class PricingRow {
        @AuraEnabled public String pricebookName;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Boolean entryActive;
        @AuraEnabled public Boolean pricebookActive;
        public PricingRow(String nameValue, Decimal priceValue, Boolean entryValue, Boolean bookValue) {
            pricebookName = nameValue;
            listPrice = priceValue;
            entryActive = entryValue;
            pricebookActive = bookValue;
        }
    }

    public class ProductOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String category;
        @AuraEnabled public String productCode;
        public ProductOption(PricebookEntry entry) {
            value = String.valueOf(entry.Id);
            unitPrice = entry.UnitPrice;
            category = entry.Product2.Category__c;
            productCode = entry.Product2.ProductCode;
            label = entry.Product2.Name + ' — ' + entry.UnitPrice.setScale(2).format() + ' (' + entry.Product2.Category__c + ')';
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordTypeOption> getRecordTypeOptions(String objectApiName) {
        if (objectApiName != 'Opportunity' && objectApiName != 'Order' && objectApiName != 'Account') {
            throw new AuraHandledException('Record type lookup is not enabled for this object.');
        }
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            throw new AuraHandledException('Unknown Salesforce object: ' + objectApiName);
        }
        List<RecordTypeOption> results = new List<RecordTypeOption>();
        for (Schema.RecordTypeInfo info : objectType.getDescribe().getRecordTypeInfos()) {
            if (info.isAvailable() && !info.isMaster() && (info.getDeveloperName() == 'Retail' || info.getDeveloperName() == 'Wholesale')) {
                results.add(new RecordTypeOption(info.getName(), info.getRecordTypeId(), info.getDeveloperName()));
            }
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Product2> getRecentProducts() {
        return [
            SELECT Id, Name, ProductCode, IsActive, Category__c, Sales_Channel__c, Base_Price__c, Wholesale_Price__c, CreatedDate
            FROM Product2 WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> getRecentAccounts() {
        return [
            SELECT Id, Name, Phone, Type, BillingCity, BillingState, Sales_Channel__c, RecordTypeId, CreatedDate
            FROM Account WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getRecentContacts() {
        return [
            SELECT Id, Name, AccountId, Account.Name, Email, Phone, CreatedDate
            FROM Contact WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Task> getRecentTasks() {
        return [
            SELECT Id, Subject, WhatId, ActivityDate, Status, Priority, Is_Follow_Up_Reminder__c, CreatedDate
            FROM Task WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Event> getRecentEvents() {
        return [
            SELECT Id, Subject, WhatId, StartDateTime, EndDateTime, Is_Completed__c, CreatedDate
            FROM Event WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<CampaignMember> getRecentCampaignMembers() {
        return [
            SELECT Id, CampaignId, Campaign.Name, LeadId, Lead.Name, ContactId, Contact.Name, Status, CreatedDate
            FROM CampaignMember WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getRecentLeads() {
        return [
            SELECT Id, Name, Company, Email, Phone, Status, Customer_Type__c, IsConverted, CreatedDate
            FROM Lead WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getRecentOpportunities() {
        return [
            SELECT Id, Name, StageName, CloseDate, Amount, AccountId, Account.Name, Customer_Name__c,
                   Customer_Email__c, Customer_Phone__c, Sales_Channel__c, RecordTypeId, CreatedDate
            FROM Opportunity WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Order> getRecentOrders() {
        return [
            SELECT Id, OrderNumber, Status, EffectiveDate, AccountId, Account.Name, OpportunityId,
                   Payment_Status__c, Payment_Mode__c, Approval_Status__c, Sales_Channel__c,
                   Effective_Order_Amount__c, Total_Discount__c, Total_GST__c, Net_Amount__c,
                   Total_CGST__c, Total_SGST__c, Total_IGST__c, Tax_Type__c, Commission__c,
                   Invoice_Number__c, Max_Discount_Percent__c, CreatedDate
            FROM Order WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Campaign> getRecentCampaigns() {
        return [
            SELECT Id, Name, Status, Type, StartDate, EndDate, IsActive, BudgetedCost, ActualCost, CreatedDate
            FROM Campaign WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Store__c> getRecentStores() {
        return [
            SELECT Id, Name, City__c, State__c, Phone__c, GSTIN__c, Is_Default__c, CreatedDate
            FROM Store__c WITH USER_MODE ORDER BY Is_Default__c DESC, Name ASC LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<PricingRow> getProductPricing(Id productId) {
        if (productId == null) return new List<PricingRow>();
        List<PricingRow> rows = new List<PricingRow>();
        for (PricebookEntry entry : [
            SELECT UnitPrice, IsActive, Pricebook2.Name, Pricebook2.IsActive
            FROM PricebookEntry
            WHERE Product2Id = :productId
            WITH USER_MODE
            ORDER BY Pricebook2.Name
        ]) {
            rows.add(new PricingRow(entry.Pricebook2.Name, entry.UnitPrice, entry.IsActive, entry.Pricebook2.IsActive));
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static Order getOrderSummary(Id orderId) {
        if (orderId == null) return null;
        List<Order> records = [
            SELECT Id, OrderNumber, Status, EffectiveDate, AccountId, Account.Name, OpportunityId, Opportunity.Name,
                   Pricebook2Id, Pricebook2.Name, Payment_Status__c, Payment_Mode__c, Approval_Status__c,
                   Sales_Channel__c, Effective_Order_Amount__c, Total_Discount__c, Total_GST__c, Net_Amount__c,
                   Total_CGST__c, Total_SGST__c, Total_IGST__c, Tax_Type__c, Commission__c,
                   Invoice_Number__c, Max_Discount_Percent__c, BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry
            FROM Order WHERE Id = :orderId WITH USER_MODE LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getOpportunityLineItems(Id opportunityId) {
        if (opportunityId == null) return new List<OpportunityLineItem>();
        return [
            SELECT Id, OpportunityId, PricebookEntryId, Product2.Name, Product2.ProductCode,
                   Quantity, UnitPrice, TotalPrice, Description, CreatedDate
            FROM OpportunityLineItem WHERE OpportunityId = :opportunityId WITH USER_MODE ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<OrderItem> getOrderLineItems(Id orderId) {
        if (orderId == null) return new List<OrderItem>();
        return [
            SELECT Id, OrderId, OrderItemNumber, PricebookEntryId, Product2Id, Product2.Name,
                   Product_Name__c, Product_Code__c, Description, Quantity, UnitPrice, Discount__c,
                   Discount_Percent__c, Line_Discount__c, Product_Category__c, Taxable_Amount__c,
                   GST_Rate__c, CGST__c, SGST__c, IGST__c, Total_Tax__c, Net_Price__c
            FROM OrderItem WHERE OrderId = :orderId WITH USER_MODE ORDER BY OrderItemNumber
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductOption> getAvailableProductsForOpportunity(Id opportunityId) {
        if (opportunityId == null) return new List<ProductOption>();
        Opportunity parentOpportunity = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :opportunityId WITH USER_MODE LIMIT 1];
        if (parentOpportunity.Pricebook2Id == null) {
            throw new AuraHandledException('This opportunity has no price book. Check the Retail / Wholesale record type and price book setup.');
        }
        List<ProductOption> choices = new List<ProductOption>();
        for (PricebookEntry entry : [
            SELECT Id, UnitPrice, Product2.Name, Product2.ProductCode, Product2.Category__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :parentOpportunity.Pricebook2Id AND IsActive = TRUE AND Product2.IsActive = TRUE
            WITH USER_MODE
            ORDER BY Product2.Name
        ]) {
            choices.add(new ProductOption(entry));
        }
        return choices;
    }

    @AuraEnabled
    public static Id addOpportunityProduct(Id opportunityId, Id pricebookEntryId, Decimal quantity, String description) {
        try {
            if (opportunityId == null || pricebookEntryId == null) {
                throw new AuraHandledException('Choose an Opportunity and product before adding a product line.');
            }
            if (quantity == null || quantity <= 0) throw new AuraHandledException('Quantity must be greater than zero.');
            Opportunity parentOpportunity = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :opportunityId WITH USER_MODE LIMIT 1];
            PricebookEntry entry = [
                SELECT Id, UnitPrice, Pricebook2Id, IsActive, Product2.IsActive
                FROM PricebookEntry WHERE Id = :pricebookEntryId WITH USER_MODE LIMIT 1
            ];
            if (entry.Pricebook2Id != parentOpportunity.Pricebook2Id) {
                throw new AuraHandledException('Selected product does not belong to this Opportunity price book.');
            }
            if (!entry.IsActive || !entry.Product2.IsActive) throw new AuraHandledException('The product or price book entry is inactive.');
            OpportunityLineItem line = new OpportunityLineItem(
                OpportunityId = opportunityId,
                PricebookEntryId = pricebookEntryId,
                Quantity = quantity,
                UnitPrice = entry.UnitPrice,
                Description = description
            );
            insert as user line;
            return line.Id;
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    @AuraEnabled
    public static Id updateOrderItemLine(Id orderItemId, Decimal quantity, Decimal discountPerUnit, String description) {
        try {
            if (orderItemId == null) throw new AuraHandledException('Choose an order product line to edit.');
            if (quantity == null || quantity <= 0) throw new AuraHandledException('Quantity must be greater than zero.');
            OrderItem line = [SELECT Id, Quantity, Discount__c, Description FROM OrderItem WHERE Id = :orderItemId WITH USER_MODE LIMIT 1];
            line.Quantity = quantity;
            line.Discount__c = discountPerUnit == null ? 0 : discountPerUnit;
            line.Description = description;
            update as user line;
            return line.Id;
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    @AuraEnabled
    public static void deleteOrderItemLine(Id orderItemId) {
        try {
            if (orderItemId == null) throw new AuraHandledException('Choose an order product line to remove.');
            OrderItem line = [SELECT Id FROM OrderItem WHERE Id = :orderItemId WITH USER_MODE LIMIT 1];
            delete as user line;
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductOption> getAvailableProducts(Id orderId) {
        if (orderId == null) return new List<ProductOption>();
        Order parentOrder = [SELECT Id, Pricebook2Id FROM Order WHERE Id = :orderId WITH USER_MODE LIMIT 1];
        if (parentOrder.Pricebook2Id == null) {
            throw new AuraHandledException('This order has no price book yet. Link a valid Opportunity or check the Blush price book setup.');
        }
        List<ProductOption> choices = new List<ProductOption>();
        for (PricebookEntry entry : [
            SELECT Id, UnitPrice, Product2.Name, Product2.ProductCode, Product2.Category__c
            FROM PricebookEntry
            WHERE Pricebook2Id = :parentOrder.Pricebook2Id AND IsActive = TRUE AND Product2.IsActive = TRUE
            WITH USER_MODE
            ORDER BY Product2.Name
        ]) {
            choices.add(new ProductOption(entry));
        }
        return choices;
    }

    @AuraEnabled
    public static Id addOrderItem(Id orderId, Id pricebookEntryId, Decimal quantity, Decimal discountPerUnit, String description) {
        try {
            if (orderId == null || pricebookEntryId == null) {
                throw new AuraHandledException('Choose an order and a product before adding a line.');
            }
            if (quantity == null || quantity <= 0) {
                throw new AuraHandledException('Quantity must be greater than zero.');
            }
            Order parentOrder = [SELECT Id, Pricebook2Id, Payment_Status__c FROM Order WHERE Id = :orderId WITH USER_MODE LIMIT 1];
            PricebookEntry entry = [
                SELECT Id, UnitPrice, Pricebook2Id, IsActive, Product2.IsActive
                FROM PricebookEntry WHERE Id = :pricebookEntryId WITH USER_MODE LIMIT 1
            ];
            if (entry.Pricebook2Id != parentOrder.Pricebook2Id) {
                throw new AuraHandledException('That product price does not belong to this order’s price book. Select a product from the current order channel.');
            }
            if (!entry.IsActive || !entry.Product2.IsActive) {
                throw new AuraHandledException('The selected product or price book entry is inactive.');
            }
            OrderItem newLine = new OrderItem(
                OrderId = orderId,
                PricebookEntryId = pricebookEntryId,
                Quantity = quantity,
                UnitPrice = entry.UnitPrice,
                Discount__c = discountPerUnit == null ? 0 : discountPerUnit,
                Description = description
            );
            insert as user newLine;
            return newLine.Id;
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    @AuraEnabled
    public static String updateOrderPayment(Id orderId, String paymentMode, String paymentStatus) {
        try {
            if (orderId == null) throw new AuraHandledException('Choose an order first.');
            Order currentOrder = [SELECT Id, Payment_Mode__c, Payment_Status__c FROM Order WHERE Id = :orderId WITH USER_MODE LIMIT 1];
            currentOrder.Payment_Mode__c = paymentMode;
            currentOrder.Payment_Status__c = paymentStatus;
            update as user currentOrder;
            return 'Payment details saved successfully.';
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    @AuraEnabled
    public static String submitOrderForApproval(Id orderId, String comments) {
        try {
            if (orderId == null) throw new AuraHandledException('Choose an order first.');
            Order orderRecord = [
                SELECT Id, OrderNumber, Max_Discount_Percent__c, Approval_Status__c
                FROM Order WHERE Id = :orderId WITH USER_MODE LIMIT 1
            ];
            Decimal maxDiscount = orderRecord.Max_Discount_Percent__c == null ? 0 : orderRecord.Max_Discount_Percent__c;
            if (maxDiscount <= 10) return 'Approval is not required because no line discount is above 10%.';
            if (orderRecord.Approval_Status__c == 'Pending') return 'This order already has a pending approval request.';
            if (orderRecord.Approval_Status__c == 'Approved') return 'This order is already approved. If its discount increased, save the changed order lines first.';

            Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
            request.setObjectId(orderId);
            request.setProcessDefinitionNameOrId(BlushConstants.APPROVAL_PROCESS_NAME);
            request.setComments(String.isBlank(comments) ? 'Submitted from Blush Control Center.' : comments.trim());
            Approval.ProcessResult result = Approval.process(request);
            if (!result.isSuccess()) {
                String detail = 'The approval request could not be submitted.';
                if (result.getErrors() != null && result.getErrors().size() > 0) detail += ' ' + result.getErrors()[0].getMessage();
                throw new AuraHandledException(detail);
            }
            return 'Order submitted for discount approval.';
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    @AuraEnabled
    public static String processOrderApproval(Id orderId, String actionName, String comments) {
        try {
            if (orderId == null) throw new AuraHandledException('Choose an order first.');
            if (actionName != 'Approve' && actionName != 'Reject') throw new AuraHandledException('Choose Approve or Reject.');
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id, ActorId, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :orderId
                WITH USER_MODE
                ORDER BY CreatedDate ASC LIMIT 1
            ];
            if (workItems.isEmpty()) throw new AuraHandledException('No pending approval work item was found for this order. It may not be submitted, or your user may not be the assigned approver.');
            Approval.ProcessWorkitemRequest request = new Approval.ProcessWorkitemRequest();
            request.setWorkitemId(workItems[0].Id);
            request.setAction(actionName);
            request.setComments(String.isBlank(comments) ? actionName + ' from Blush Control Center.' : comments.trim());
            Approval.ProcessResult result = Approval.process(request);
            if (!result.isSuccess()) {
                String detail = 'The approval action could not be completed.';
                if (result.getErrors() != null && result.getErrors().size() > 0) detail += ' ' + result.getErrors()[0].getMessage();
                throw new AuraHandledException(detail);
            }
            return actionName == 'Approve' ? 'Order discount request approved.' : 'Order discount request rejected.';
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    @AuraEnabled
    public static String runFollowUpBatch() {
        try {
            Boolean isManager = FeatureManagement.checkPermission(BlushConstants.PERMISSION_EDIT_PAID_ORDERS);
            Profile currentProfile = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
            if (!isManager && currentProfile.Name != 'System Administrator') {
                throw new AuraHandledException('Only a Blush manager or Salesforce administrator can run the follow-up batch manually.');
            }
            Id jobId = Database.executeBatch(new OpportunityFollowUpBatch(), 200);
            return String.valueOf(jobId);
        } catch (AuraHandledException handled) {
            throw handled;
        } catch (Exception ex) {
            throw friendlyError(ex);
        }
    }

    private static AuraHandledException friendlyError(Exception ex) {
        String message = ex == null ? 'An unexpected error occurred.' : ex.getMessage();
        if (String.isBlank(message)) message = 'An unexpected error occurred. Review the record fields and your Salesforce permissions.';
        AuraHandledException handled = new AuraHandledException(message);
        handled.setMessage(message);
        return handled;
    }
}