@IsTest
private class BlushWorkspaceControllerTest {
    @IsTest
    static void testWorkspaceLookupsAndRecordTypes() {
        Map<String, Product2> catalog = TestDataFactory.createCatalog();
        Account accountRecord = TestDataFactory.createAccount('Workspace Retail Customer', 'Retail', TestDataFactory.MAHARASHTRA);
        Opportunity opportunityRecord = TestDataFactory.buildOpportunity('Retail', 'Workspace Prospect', 'workspace.prospect@example.com', '9812345678');
        insert opportunityRecord;
        Campaign campaignRecord = new Campaign(Name = 'Workspace Campaign', IsActive = true, Status = 'In Progress', Type = 'Advertisement');
        insert campaignRecord;
        Task taskRecord = new Task(Subject = 'Workspace follow-up', Status = 'Not Started', Priority = 'Normal', ActivityDate = Date.today(), WhatId = opportunityRecord.Id);
        insert taskRecord;
        Event eventRecord = new Event(Subject = 'Workspace meeting', StartDateTime = System.now().addDays(1), EndDateTime = System.now().addDays(1).addHours(1), WhatId = opportunityRecord.Id);
        insert eventRecord;

        Test.startTest();
        System.assert(BlushWorkspaceController.getRecordTypeOptions('Opportunity').size() >= 2, 'Opportunity Retail and Wholesale record types should be listed.');
        System.assert(BlushWorkspaceController.getRecordTypeOptions('Order').size() >= 2, 'Order Retail and Wholesale record types should be listed.');
        System.assert(BlushWorkspaceController.getRecordTypeOptions('Account').size() >= 2, 'Account Retail and Wholesale record types should be listed.');
        System.assert(!BlushWorkspaceController.getRecentProducts().isEmpty(), 'The catalogue should be returned.');
        System.assert(!BlushWorkspaceController.getRecentAccounts().isEmpty(), 'Accounts should be returned.');
        System.assert(!BlushWorkspaceController.getRecentOpportunities().isEmpty(), 'Opportunities should be returned.');
        System.assert(!BlushWorkspaceController.getRecentCampaigns().isEmpty(), 'Campaigns should be returned.');
        System.assert(!BlushWorkspaceController.getRecentTasks().isEmpty(), 'Tasks should be returned.');
        System.assert(!BlushWorkspaceController.getRecentEvents().isEmpty(), 'Events should be returned.');
        System.assert(!BlushWorkspaceController.getProductPricing(catalog.get('Necklace').Id).isEmpty(), 'Product price books should be returned.');
        System.assert(!BlushWorkspaceController.getAvailableProductsForOpportunity(opportunityRecord.Id).isEmpty(), 'Opportunity channel products should be returned.');
        System.assertNotEquals(null, accountRecord.Id);
        Test.stopTest();
    }

    @IsTest
    static void testOpportunityProductAndOrderLineLifecycle() {
        Map<String, Product2> catalog = TestDataFactory.createCatalog();
        Opportunity opportunityRecord = TestDataFactory.buildOpportunity('Retail', 'Workspace Order Customer', 'workspace.order@example.com', '9822223333');
        insert opportunityRecord;
        opportunityRecord = [SELECT Id, AccountId, Pricebook2Id FROM Opportunity WHERE Id = :opportunityRecord.Id];

        PricebookEntry oppEntry = [
            SELECT Id, UnitPrice FROM PricebookEntry
            WHERE Product2Id = :catalog.get('Necklace').Id AND Pricebook2Id = :opportunityRecord.Pricebook2Id AND IsActive = TRUE LIMIT 1
        ];
        Test.startTest();
        Id opportunityLineId = BlushWorkspaceController.addOpportunityProduct(opportunityRecord.Id, oppEntry.Id, 2, 'Test opportunity line');
        Test.stopTest();
        System.assertNotEquals(null, opportunityLineId, 'Opportunity product should be created.');
        System.assertEquals(1, BlushWorkspaceController.getOpportunityLineItems(opportunityRecord.Id).size(), 'The opportunity line should be visible.');

        Account accountRecord = [SELECT Id FROM Account WHERE Id = :opportunityRecord.AccountId LIMIT 1];
        Order orderRecord = TestDataFactory.createOrder(accountRecord, 'Retail');
        orderRecord = [SELECT Id, Pricebook2Id FROM Order WHERE Id = :orderRecord.Id];
        PricebookEntry orderEntry = [
            SELECT Id FROM PricebookEntry
            WHERE Product2Id = :catalog.get('Necklace').Id AND Pricebook2Id = :orderRecord.Pricebook2Id AND IsActive = TRUE LIMIT 1
        ];
        Id orderLineId = BlushWorkspaceController.addOrderItem(orderRecord.Id, orderEntry.Id, 2, 10, 'Initial order line');
        System.assertNotEquals(null, orderLineId, 'Order product should be created.');
        BlushWorkspaceController.updateOrderItemLine(orderLineId, 3, 20, 'Updated order line');
        Order updatedOrder = BlushWorkspaceController.getOrderSummary(orderRecord.Id);
        System.assertEquals(2340, updatedOrder.Effective_Order_Amount__c, 'Taxable order total should recalculate after quantity and discount edits.');
        System.assertEquals(70.20, updatedOrder.Total_GST__c, 'GST should recalculate after quantity and discount edits.');
        System.assertEquals('Approval is not required because no line discount is above 10%.', BlushWorkspaceController.submitOrderForApproval(orderRecord.Id, null));
        System.assertEquals('Payment details saved successfully.', BlushWorkspaceController.updateOrderPayment(orderRecord.Id, 'Cash', 'Pending'));
        BlushWorkspaceController.deleteOrderItemLine(orderLineId);
        System.assertEquals(0, BlushWorkspaceController.getOrderLineItems(orderRecord.Id).size(), 'Deleting a line should update the line list.');
    }
}