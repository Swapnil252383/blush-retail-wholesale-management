/**
 * Test data for the Blush test classes.
 */
@IsTest
public class TestDataFactory {
    public static final String MAHARASHTRA = 'Maharashtra';
    public static final String KARNATAKA = 'Karnataka';

    public static Map<String, Id> createPricebooks() {
        Pricebook2 retail = new Pricebook2(Name = BlushConstants.RETAIL_PRICEBOOK, IsActive = true);
        Pricebook2 wholesale = new Pricebook2(Name = BlushConstants.WHOLESALE_PRICEBOOK, IsActive = true);
        insert new List<Pricebook2>{ retail, wholesale };
        PricebookService.clearCache();
        return new Map<String, Id>{ BlushConstants.CHANNEL_RETAIL => retail.Id, BlushConstants.CHANNEL_WHOLESALE => wholesale.Id };
    }

    public static Store__c createStore() {
        Store__c store = new Store__c(
            Name = 'Blush - FC Road',
            Street__c = '12 FC Road',
            City__c = 'Pune',
            State__c = MAHARASHTRA,
            Postal_Code__c = '411004',
            GSTIN__c = '27ABCDE1234F1Z5',
            Phone__c = '020-12345678',
            Website__c = 'https://blush.example.com',
            Is_Default__c = true
        );
        insert store;
        return store;
    }

    public static Product2 buildProduct(String name, String code, String category, String channels, Decimal basePrice) {
        return new Product2(Name = name, ProductCode = code, Category__c = category, Sales_Channel__c = channels, Base_Price__c = basePrice, IsActive = true);
    }

    /** Pricebooks, default store and three products: Jeans and Necklace (both channels), Gown (retail only). */
    public static Map<String, Product2> createCatalog() {
        createPricebooks();
        createStore();
        Map<String, Product2> products = new Map<String, Product2>{
            'Jeans' => buildProduct('Jeans', '10#001', 'Garments', 'Retail;Wholesale', 500),
            'Gown' => buildProduct('Gown', '10#002', 'Garments', 'Retail', 1500),
            'Necklace' => buildProduct('Necklace', '20#001', 'Jewellery', 'Retail;Wholesale', 800)
        };
        insert products.values();
        return products;
    }

    public static Account createAccount(String name, String channel, String state) {
        Account acc = new Account(
            Name = name,
            Phone = '9800000000',
            RecordTypeId = BlushConstants.recordTypeId(Account.SObjectType, channel),
            BillingStreet = '1 Main Road',
            BillingCity = state == KARNATAKA ? 'Bengaluru' : 'Pune',
            BillingState = state,
            BillingCountry = state == null ? null : 'India'
        );
        insert acc;
        return acc;
    }

    public static Order buildOrder(Account acc, String channel) {
        return new Order(
            AccountId = acc.Id,
            RecordTypeId = BlushConstants.recordTypeId(Order.SObjectType, channel),
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
    }

    public static Order createOrder(Account acc, String channel) {
        Order o = buildOrder(acc, channel);
        insert o;
        return o;
    }

    public static OrderItem buildItem(Order o, Product2 product, Decimal quantity, Decimal discountPerUnit) {
        Id pricebookId = [SELECT Pricebook2Id FROM Order WHERE Id = :o.Id].Pricebook2Id;
        PricebookEntry entry = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND Product2Id = :product.Id];
        return new OrderItem(OrderId = o.Id, PricebookEntryId = entry.Id, Quantity = quantity, UnitPrice = entry.UnitPrice, Discount__c = discountPerUnit);
    }

    public static OrderItem createItem(Order o, Product2 product, Decimal quantity, Decimal discountPerUnit) {
        OrderItem item = buildItem(o, product, quantity, discountPerUnit);
        insert item;
        return item;
    }

    public static Opportunity buildOpportunity(String channel, String customerName, String email, String phone) {
        return new Opportunity(
            Name = customerName + ' - ' + channel,
            RecordTypeId = BlushConstants.recordTypeId(Opportunity.SObjectType, channel),
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Customer_Name__c = customerName,
            Customer_Email__c = email,
            Customer_Phone__c = phone
        );
    }

    public static User createUser(String profileName, String permissionSetName) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = :profileName];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            ProfileId = profile.Id,
            Username = 'blush.test.' + unique + '@example.com',
            Email = 'blush.test.' + unique + '@example.com',
            LastName = 'Tester',
            FirstName = 'Blush',
            Alias = 'bt' + unique.left(5),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        // Setup objects run in their own context to avoid mixed DML with business records.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            if (permissionSetName != null) {
                insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName].Id);
            }
        }
        return u;
    }
}