// Blush demo data: price books, stores, product catalogue, leads, campaigns, opportunities and orders.
// Run once after deploying (and after create-users.apex):
//   sf apex run --file scripts/apex/setup-demo-data.apex --target-org MyDevOrg
// Running user needs the Blush_Manager permission set and the Marketing User checkbox.

Date monthStart = Date.today().toStartOfMonth();

// ------------------------------------------------------------------ price books
Pricebook2 standard = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
if (!standard.IsActive) {
    standard.IsActive = true;
    update standard;
}
Map<String, Pricebook2> books = new Map<String, Pricebook2>();
for (Pricebook2 pb : [SELECT Id, Name FROM Pricebook2 WHERE Name IN ('Blush Retail Price Book', 'Blush Wholesale Price Book')]) {
    books.put(pb.Name, pb);
}
List<Pricebook2> newBooks = new List<Pricebook2>();
if (!books.containsKey('Blush Retail Price Book')) {
    newBooks.add(new Pricebook2(Name = 'Blush Retail Price Book', IsActive = true, Description = 'Retail (B2C) prices = base price'));
}
if (!books.containsKey('Blush Wholesale Price Book')) {
    newBooks.add(new Pricebook2(Name = 'Blush Wholesale Price Book', IsActive = true, Description = 'Wholesale (B2B) prices = base price less 30%'));
}
insert newBooks;
for (Pricebook2 pb : newBooks) {
    books.put(pb.Name, pb);
}

// ------------------------------------------------------------------ stores
if ([SELECT COUNT() FROM Store__c] == 0) {
    insert new List<Store__c>{
        new Store__c(Name = 'Blush - FC Road', Street__c = 'Shop 4, Ashirwad Complex, FC Road', City__c = 'Pune', State__c = 'Maharashtra',
            Postal_Code__c = '411004', GSTIN__c = '27AABCB1234C1Z5', Phone__c = '020-25531234', Website__c = 'https://www.blush.example.com', Is_Default__c = true),
        new Store__c(Name = 'Blush - Andheri West', Street__c = '12 Link Road, Andheri West', City__c = 'Mumbai', State__c = 'Maharashtra',
            Postal_Code__c = '400053', GSTIN__c = '27AABCB1234C2Z4', Phone__c = '022-26301234', Website__c = 'https://www.blush.example.com')
    };
}

// ------------------------------------------------------------------ products (same data as data/Blush_Products.csv)
List<Product2> catalogue = new List<Product2>{
    new Product2(ProductCode = '10#001', Name = 'Jeans', Category__c = 'Garments', Sales_Channel__c = 'Retail;Wholesale', Base_Price__c = 500),
    new Product2(ProductCode = '10#002', Name = 'Gown', Category__c = 'Garments', Sales_Channel__c = 'Retail', Base_Price__c = 1500),
    new Product2(ProductCode = '10#003', Name = 'Cotton Kurti', Category__c = 'Garments', Sales_Channel__c = 'Retail;Wholesale', Base_Price__c = 650),
    new Product2(ProductCode = '10#004', Name = 'Printed T-Shirt', Category__c = 'Garments', Sales_Channel__c = 'Retail;Wholesale', Base_Price__c = 350),
    new Product2(ProductCode = '10#005', Name = 'Silk Saree', Category__c = 'Garments', Sales_Channel__c = 'Retail', Base_Price__c = 2800),
    new Product2(ProductCode = '10#006', Name = 'Designer Lehenga', Category__c = 'Garments', Sales_Channel__c = 'Retail', Base_Price__c = 4500),
    new Product2(ProductCode = '10#007', Name = 'Palazzo Pants', Category__c = 'Garments', Sales_Channel__c = 'Wholesale', Base_Price__c = 450),
    new Product2(ProductCode = '20#001', Name = 'Kundan Necklace Set', Category__c = 'Jewellery', Sales_Channel__c = 'Retail;Wholesale', Base_Price__c = 1200),
    new Product2(ProductCode = '20#002', Name = 'Oxidised Jhumka Earrings', Category__c = 'Jewellery', Sales_Channel__c = 'Retail;Wholesale', Base_Price__c = 299),
    new Product2(ProductCode = '20#003', Name = 'Glass Bangles (Set of 12)', Category__c = 'Jewellery', Sales_Channel__c = 'Wholesale', Base_Price__c = 180),
    new Product2(ProductCode = '20#004', Name = 'American Diamond Ring', Category__c = 'Jewellery', Sales_Channel__c = 'Retail', Base_Price__c = 799),
    new Product2(ProductCode = '20#005', Name = 'Pearl Maang Tikka', Category__c = 'Jewellery', Sales_Channel__c = 'Retail;Wholesale', Base_Price__c = 450)
};
Set<String> existingCodes = new Set<String>();
for (Product2 p : [SELECT ProductCode FROM Product2 WHERE ProductCode LIKE '10#%' OR ProductCode LIKE '20#%']) {
    existingCodes.add(p.ProductCode);
}
List<Product2> newProducts = new List<Product2>();
for (Product2 p : catalogue) {
    if (!existingCodes.contains(p.ProductCode)) {
        p.IsActive = true;
        newProducts.add(p);
    }
}
insert newProducts; // Product2Trigger creates the standard, retail and wholesale price book entries.

if ([SELECT COUNT() FROM Opportunity WHERE Name LIKE 'BLUSH DEMO%'] > 0) {
    throw new HandledException('Demo data already exists - nothing to do.');
}

Map<String, Id> retailEntry = new Map<String, Id>();
Map<String, Id> wholesaleEntry = new Map<String, Id>();
Map<String, Decimal> retailPrice = new Map<String, Decimal>();
Map<String, Decimal> wholesalePrice = new Map<String, Decimal>();
for (PricebookEntry e : [
    SELECT Id, UnitPrice, Pricebook2.Name, Product2.ProductCode
    FROM PricebookEntry
    WHERE Pricebook2.Name IN ('Blush Retail Price Book', 'Blush Wholesale Price Book') AND IsActive = TRUE
]) {
    if (e.Pricebook2.Name == 'Blush Retail Price Book') {
        retailEntry.put(e.Product2.ProductCode, e.Id);
        retailPrice.put(e.Product2.ProductCode, e.UnitPrice);
    } else {
        wholesaleEntry.put(e.Product2.ProductCode, e.Id);
        wholesalePrice.put(e.Product2.ProductCode, e.UnitPrice);
    }
}

// ------------------------------------------------------------------ leads and campaigns
List<Lead> leads = new List<Lead>{
    new Lead(FirstName = 'Anita', LastName = 'Desai', Company = 'Anita Desai', Email = 'anita.desai@example.com', Phone = '9822012345',
        Customer_Type__c = 'Retail', LeadSource = 'Web', Status = 'Working - Contacted'),
    new Lead(FirstName = 'Rohan', LastName = 'Joshi', Company = 'Joshi Boutique', Email = 'rohan@joshiboutique.example.com', Phone = '9890011223',
        Customer_Type__c = 'Wholesale', LeadSource = 'Trade Show', Status = 'Open - Not Contacted'),
    new Lead(FirstName = 'Meera', LastName = 'Nair', Company = 'Meera Nair', Email = 'meera.nair@example.com', Phone = '9001122334',
        Customer_Type__c = 'Retail', LeadSource = 'Advertisement', Status = 'Open - Not Contacted'),
    new Lead(FirstName = 'Vikram', LastName = 'Shah', Company = 'Shah Textiles', Email = 'vikram@shahtextiles.example.com', Phone = '9123409876',
        Customer_Type__c = 'Wholesale', LeadSource = 'Partner Referral', Status = 'Working - Contacted')
};
insert leads;

Campaign diwali = new Campaign(Name = 'Diwali Festive Sale', Type = 'Advertisement', Status = 'In Progress', IsActive = true,
    StartDate = monthStart, EndDate = monthStart.addMonths(1).addDays(-1), BudgetedCost = 50000, ExpectedRevenue = 400000,
    Description = 'Up to 10% off on festive garments and jewellery');
Campaign wedding = new Campaign(Name = 'Wedding Season Jewellery', Type = 'Email', Status = 'Planned', IsActive = true,
    StartDate = monthStart.addDays(14), EndDate = monthStart.addMonths(2), BudgetedCost = 30000, ExpectedRevenue = 250000);
Campaign monsoon = new Campaign(Name = 'Monsoon Clearance', Type = 'Direct Mail', Status = 'Completed', IsActive = false,
    StartDate = monthStart.addMonths(-3), EndDate = monthStart.addMonths(-2), BudgetedCost = 20000, ActualCost = 18500);
insert new List<Campaign>{ diwali, wedding, monsoon };
insert new List<CampaignMember>{
    new CampaignMember(CampaignId = diwali.Id, LeadId = leads[0].Id, Status = 'Responded'),
    new CampaignMember(CampaignId = diwali.Id, LeadId = leads[2].Id, Status = 'Sent'),
    new CampaignMember(CampaignId = wedding.Id, LeadId = leads[1].Id, Status = 'Sent')
};

// ------------------------------------------------------------------ opportunities (customers are found or created automatically)
Id oppRetail = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Retail').getRecordTypeId();
Id oppWholesale = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Wholesale').getRecordTypeId();
List<User> reps = [SELECT Id FROM User WHERE Username LIKE 'sneha.patil@blush-%' AND IsActive = TRUE LIMIT 1];
Id repId = reps.isEmpty() ? UserInfo.getUserId() : reps[0].Id;

List<Opportunity> opps = new List<Opportunity>{
    new Opportunity(Name = 'BLUSH DEMO - Priya Sharma Festive Shopping', RecordTypeId = oppRetail, StageName = 'Closed Won', CloseDate = Date.today(),
        Customer_Name__c = 'Priya Sharma', Customer_Email__c = 'priya.sharma@example.com', Customer_Phone__c = '9876543210', CampaignId = diwali.Id),
    new Opportunity(Name = 'BLUSH DEMO - Anita Desai Bridal Jewellery', RecordTypeId = oppRetail, StageName = 'Closed Won', CloseDate = Date.today(),
        Customer_Name__c = 'Anita Desai', Customer_Email__c = 'Anita.Desai@example.com', CampaignId = diwali.Id, OwnerId = repId),
    new Opportunity(Name = 'BLUSH DEMO - Fashion Hub Bulk Order', RecordTypeId = oppWholesale, StageName = 'Closed Won', CloseDate = Date.today(),
        Customer_Name__c = 'Rahul Mehta', Customer_Email__c = 'rahul@fashionhub.example.com', Customer_Phone__c = '9822001122', Company_Name__c = 'Fashion Hub Traders'),
    new Opportunity(Name = 'BLUSH DEMO - Joshi Boutique Q4 Stock', RecordTypeId = oppWholesale, StageName = 'Negotiation/Review', CloseDate = Date.today().addDays(10),
        Customer_Name__c = 'Rohan Joshi', Customer_Phone__c = '+91 98900 11223', OwnerId = repId),
    new Opportunity(Name = 'BLUSH DEMO - Kavya Iyer Gown Purchase', RecordTypeId = oppRetail, StageName = 'Proposal/Price Quote', CloseDate = Date.today().addDays(7),
        Customer_Name__c = 'Kavya Iyer', Customer_Email__c = 'kavya.iyer@example.com', Customer_Phone__c = '9988776655', OwnerId = repId)
};
insert opps;
Map<String, Opportunity> oppByCustomer = new Map<String, Opportunity>();
for (Opportunity o : [SELECT Id, AccountId, Customer_Name__c, OwnerId FROM Opportunity WHERE Id IN :opps]) {
    oppByCustomer.put(o.Customer_Name__c, o);
}

// Billing addresses: Fashion Hub is in Karnataka (IGST); everyone else is in Maharashtra (CGST + SGST).
List<Account> accounts = new List<Account>();
for (String customer : oppByCustomer.keySet()) {
    Boolean outOfState = customer == 'Rahul Mehta';
    accounts.add(new Account(Id = oppByCustomer.get(customer).AccountId, BillingStreet = outOfState ? '45 Commercial Street' : '7 Prabhat Road',
        BillingCity = outOfState ? 'Bengaluru' : 'Pune', BillingState = outOfState ? 'Karnataka' : 'Maharashtra',
        BillingPostalCode = outOfState ? '560001' : '411004', BillingCountry = 'India'));
}
update accounts;

// Joshi Boutique opportunity products - copied automatically to the order created from it.
insert new List<OpportunityLineItem>{
    new OpportunityLineItem(OpportunityId = oppByCustomer.get('Rohan Joshi').Id, PricebookEntryId = wholesaleEntry.get('10#003'), Quantity = 40, UnitPrice = wholesalePrice.get('10#003'), Discount = 5),
    new OpportunityLineItem(OpportunityId = oppByCustomer.get('Rohan Joshi').Id, PricebookEntryId = wholesaleEntry.get('20#002'), Quantity = 100, UnitPrice = wholesalePrice.get('20#002'))
};

// ------------------------------------------------------------------ orders across three months
Id orderRetail = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('Retail').getRecordTypeId();
Id orderWholesale = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('Wholesale').getRecordTypeId();
Opportunity priya = oppByCustomer.get('Priya Sharma');
Opportunity anita = oppByCustomer.get('Anita Desai');
Opportunity hub = oppByCustomer.get('Rahul Mehta');
Opportunity joshi = oppByCustomer.get('Rohan Joshi');

List<Order> orders = new List<Order>{
    new Order(AccountId = priya.AccountId, RecordTypeId = orderRetail, EffectiveDate = monthStart.addMonths(-2).addDays(5), Status = 'Draft'),
    new Order(AccountId = anita.AccountId, RecordTypeId = orderRetail, EffectiveDate = monthStart.addMonths(-1).addDays(9), Status = 'Draft', Sales_Representative__c = repId),
    new Order(AccountId = hub.AccountId, RecordTypeId = orderWholesale, EffectiveDate = monthStart.addMonths(-1).addDays(3), Status = 'Draft'),
    new Order(AccountId = priya.AccountId, OpportunityId = priya.Id, EffectiveDate = Date.today(), Status = 'Draft'),
    new Order(AccountId = hub.AccountId, OpportunityId = hub.Id, EffectiveDate = Date.today(), Status = 'Draft'),
    new Order(AccountId = anita.AccountId, OpportunityId = anita.Id, EffectiveDate = Date.today(), Status = 'Draft'),
    new Order(OpportunityId = joshi.Id, EffectiveDate = Date.today(), Status = 'Draft')
};
insert orders;

List<OrderItem> items = new List<OrderItem>{
    // 0: Priya - two months ago (sample invoice lines)
    new OrderItem(OrderId = orders[0].Id, PricebookEntryId = retailEntry.get('10#001'), Quantity = 1, UnitPrice = retailPrice.get('10#001'), Discount__c = 25),
    new OrderItem(OrderId = orders[0].Id, PricebookEntryId = retailEntry.get('20#002'), Quantity = 2, UnitPrice = retailPrice.get('20#002')),
    // 1: Anita - last month
    new OrderItem(OrderId = orders[1].Id, PricebookEntryId = retailEntry.get('20#001'), Quantity = 1, UnitPrice = retailPrice.get('20#001'), Discount__c = 100),
    new OrderItem(OrderId = orders[1].Id, PricebookEntryId = retailEntry.get('10#005'), Quantity = 1, UnitPrice = retailPrice.get('10#005'), Discount__c = 200),
    // 2: Fashion Hub - last month (Karnataka -> IGST)
    new OrderItem(OrderId = orders[2].Id, PricebookEntryId = wholesaleEntry.get('10#001'), Quantity = 50, UnitPrice = wholesalePrice.get('10#001')),
    new OrderItem(OrderId = orders[2].Id, PricebookEntryId = wholesaleEntry.get('10#004'), Quantity = 100, UnitPrice = wholesalePrice.get('10#004'), Discount__c = 10),
    // 3: Priya - this month (gown above Rs. 1,000 -> 12% GST)
    new OrderItem(OrderId = orders[3].Id, PricebookEntryId = retailEntry.get('10#002'), Quantity = 1, UnitPrice = retailPrice.get('10#002'), Discount__c = 100),
    // 4: Fashion Hub - this month
    new OrderItem(OrderId = orders[4].Id, PricebookEntryId = wholesaleEntry.get('20#003'), Quantity = 200, UnitPrice = wholesalePrice.get('20#003'), Discount__c = 6),
    new OrderItem(OrderId = orders[4].Id, PricebookEntryId = wholesaleEntry.get('10#007'), Quantity = 60, UnitPrice = wholesalePrice.get('10#007')),
    // 5: Anita - this month, 15% discount -> sent for approval automatically
    new OrderItem(OrderId = orders[5].Id, PricebookEntryId = retailEntry.get('10#006'), Quantity = 1, UnitPrice = retailPrice.get('10#006'), Discount__c = 675)
};
insert items;

// Mark the completed orders as paid (orders 5 and 6 stay in processing).
List<Order> paid = new List<Order>{
    new Order(Id = orders[0].Id, Payment_Mode__c = 'UPI', Payment_Status__c = 'Paid'),
    new Order(Id = orders[1].Id, Payment_Mode__c = 'Card', Payment_Status__c = 'Paid'),
    new Order(Id = orders[2].Id, Payment_Mode__c = 'Net Banking', Payment_Status__c = 'Paid'),
    new Order(Id = orders[3].Id, Payment_Mode__c = 'Cash', Payment_Status__c = 'Paid'),
    new Order(Id = orders[4].Id, Payment_Mode__c = 'Cheque', Payment_Status__c = 'Paid')
};
update paid;

// ------------------------------------------------------------------ follow-up reminder demo
Opportunity kavya = oppByCustomer.get('Kavya Iyer');
insert new List<Task>{
    new Task(WhatId = kavya.Id, OwnerId = kavya.OwnerId, Subject = 'Call Kavya about gown fitting', ActivityDate = Date.today().addDays(-3), Status = 'Not Started'),
    new Task(WhatId = joshi.Id, OwnerId = joshi.OwnerId, Subject = 'Send wholesale catalogue', ActivityDate = Date.today().addDays(-12), Status = 'Not Started')
};
System.debug('Blush demo data created.');
