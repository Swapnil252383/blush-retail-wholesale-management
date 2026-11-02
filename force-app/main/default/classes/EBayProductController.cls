
public with sharing class EBayProductController {

    private static final String DEFAULT_MARKETPLACE = 'EBAY_US';

    private static final Set<String> ALLOWED_MARKETPLACES =
        new Set<String>{
            'EBAY_US',
            'EBAY_GB',
            'EBAY_DE',
            'EBAY_AU',
            'EBAY_CA'
        };

    private static final Set<String> ALLOWED_CATEGORIES =
        new Set<String>{ 'Garments', 'Jewellery' };

    private static final Set<String> ALLOWED_CHANNELS =
        new Set<String>{ 'Retail', 'Wholesale' };


    // =====================================================
    // DTO: EBAY LISTING DATA
    // =====================================================

    public class ListingDTO {

        @AuraEnabled public String itemId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String itemUrl { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
        @AuraEnabled public String condition { get; set; }
        @AuraEnabled public Decimal supplierPrice { get; set; }
        @AuraEnabled public String currencyCode { get; set; }
    }


    // =====================================================
    // DTO: IMPORT RESULT
    // =====================================================

    public class ImportResult {

        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Boolean alreadyExists { get; set; }
        @AuraEnabled public String message { get; set; }
    }


    // =====================================================
    // 1. SEARCH EBAY LISTINGS
    // =====================================================

    @AuraEnabled(cacheable=false)
    public static List<ListingDTO> searchListings(
        String searchTerm,
        String marketplaceId
    ) {

        if (String.isBlank(searchTerm)) {
            throw new AuraHandledException(
                'Enter a product name to search eBay.'
            );
        }

        if (searchTerm.length() > 100) {
            throw new AuraHandledException(
                'Search term cannot exceed 100 characters.'
            );
        }

        String marketplace = normalizeMarketplace(marketplaceId);

        HttpRequest req = new HttpRequest();

        String endpoint =
            'callout:EBay_Browse/buy/browse/v1/'
            + 'item_summary/search?q='
            + encodeUrlValue(searchTerm.trim())
            + '&limit=20';

        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(20000);
        req.setHeader('Accept', 'application/json');

        req.setHeader(
            'X-EBAY-C-MARKETPLACE-ID',
            marketplace
        );

        HttpResponse res;

        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Unable to connect to eBay. Check your '
                + 'Named Credential and authentication configuration.'
            );
        }

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(
                'eBay search failed. HTTP status: '
                + res.getStatusCode()
                + '. Check API access, credentials and marketplace.'
            );
        }

        Map<String, Object> responseData =
            (Map<String, Object>) JSON.deserializeUntyped(
                res.getBody()
            );

        List<ListingDTO> results = new List<ListingDTO>();

        Object rawItems = responseData.get('itemSummaries');

        if (rawItems == null) {
            return results;
        }

        for (Object rawItem : (List<Object>) rawItems) {

            Map<String, Object> item =
                (Map<String, Object>) rawItem;

            ListingDTO listing = mapListing(item);

            results.add(listing);
        }

        return results;
    }


    // =====================================================
    // 2. IMPORT SELECTED LISTING INTO PRODUCT2
    // =====================================================

    @AuraEnabled
    public static ImportResult addListingToProducts(
        String itemId,
        String category,
        Decimal basePrice,
        List<String> salesChannels,
        String marketplaceId
    ) {

        // -----------------------------
        // Validate user inputs
        // -----------------------------

        if (String.isBlank(itemId)) {
            throw new AuraHandledException(
                'Select a valid eBay listing.'
            );
        }

        if (itemId.length() > 100) {
            throw new AuraHandledException(
                'The eBay item ID exceeds the configured field length.'
            );
        }

        if (!ALLOWED_CATEGORIES.contains(category)) {
            throw new AuraHandledException(
                'Select Garments or Jewellery.'
            );
        }

        if (basePrice == null || basePrice <= 0) {
            throw new AuraHandledException(
                'Enter a valid Blush retail selling price greater than zero.'
            );
        }

        if (salesChannels == null || salesChannels.isEmpty()) {
            throw new AuraHandledException(
                'Select at least one sales channel.'
            );
        }

        Set<String> requestedChannels =
            new Set<String>(salesChannels);

        for (String channel : requestedChannels) {
            if (!ALLOWED_CHANNELS.contains(channel)) {
                throw new AuraHandledException(
                    'Only Retail and Wholesale channels are supported.'
                );
            }
        }

        // Build the multi-select picklist value consistently.
        List<String> orderedChannels = new List<String>();

        if (requestedChannels.contains('Retail')) {
            orderedChannels.add('Retail');
        }

        if (requestedChannels.contains('Wholesale')) {
            orderedChannels.add('Wholesale');
        }

        String marketplace = normalizeMarketplace(marketplaceId);

        // -----------------------------
        // Check object and field access
        // -----------------------------

        checkProductCreatePermissions();

        // -----------------------------
        // Prevent duplicate imports
        // -----------------------------

        List<Product2> existingProducts = [
            SELECT Id, Name
            FROM Product2
            WHERE Source_eBay_Item_ID__c = :itemId
            LIMIT 1
        ];

        if (!existingProducts.isEmpty()) {
            return existingResult(existingProducts[0]);
        }

        // -----------------------------
        // Fetch authoritative listing data
        // -----------------------------

        ListingDTO listing = getListingDetails(
            itemId,
            marketplace
        );

        if (String.isBlank(listing.title)) {
            throw new AuraHandledException(
                'The selected eBay listing does not contain a title.'
            );
        }

        String productName = listing.title;

        if (productName.length() > 255) {
            productName = productName.substring(0, 255);
        }

        // -----------------------------
        // Create Blush Product2 record
        // -----------------------------

        Product2 product = new Product2();

        product.Name = productName;
        product.IsActive = true;

        // Blush selling information
        product.Category__c = category;
        product.Base_Price__c = basePrice;

        product.Sales_Channel__c =
            String.join(orderedChannels, ';');

        // Original eBay listing information
        product.Source_eBay_Item_ID__c = itemId;
        product.Supplier_Listing_URL__c = listing.itemUrl;
        product.Supplier_Price__c = listing.supplierPrice;
        product.Supplier_Currency__c = listing.currencyCode;
        product.Supplier_Condition__c = listing.condition;
        product.Supplier_Image_URL__c = listing.imageUrl;

        try {

            insert product;

        } catch (DmlException ex) {

            // getDmlType returns System.StatusCode.
            // This avoids comparing a String with StatusCode.

            if (
                ex.getNumDml() > 0 &&
                ex.getDmlType(0) ==
                    System.StatusCode.DUPLICATE_VALUE
            ) {

                List<Product2> duplicateProducts = [
                    SELECT Id, Name
                    FROM Product2
                    WHERE Source_eBay_Item_ID__c = :itemId
                    LIMIT 1
                ];

                if (!duplicateProducts.isEmpty()) {
                    return existingResult(duplicateProducts[0]);
                }
            }

            throw new AuraHandledException(
                'Salesforce could not create the product: '
                + ex.getMessage()
            );
        }

        // Product2Trigger and ProductPricebookService
        // will handle the configured price book automation.

        ImportResult result = new ImportResult();

        result.productId = product.Id;
        result.productName = product.Name;
        result.alreadyExists = false;

        result.message =
            'Product created successfully in the Blush catalogue.';

        return result;
    }


    // =====================================================
    // 3. RETRIEVE THE SELECTED EBAY LISTING
    // =====================================================

    private static ListingDTO getListingDetails(
        String itemId,
        String marketplace
    ) {

        HttpRequest req = new HttpRequest();

        String endpoint =
            'callout:EBay_Browse/buy/browse/v1/item/'
            + encodeUrlValue(itemId);

        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(20000);
        req.setHeader('Accept', 'application/json');

        req.setHeader(
            'X-EBAY-C-MARKETPLACE-ID',
            marketplace
        );

        HttpResponse res;

        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Unable to retrieve the selected eBay listing.'
            );
        }

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(
                'The selected eBay listing could not be retrieved. '
                + 'It may be unavailable or inaccessible.'
            );
        }

        Map<String, Object> details =
            (Map<String, Object>) JSON.deserializeUntyped(
                res.getBody()
            );

        return mapListing(details);
    }


    // =====================================================
    // 4. CONVERT EBAY JSON INTO LISTINGDTO
    // =====================================================

    private static ListingDTO mapListing(
        Map<String, Object> item
    ) {

        ListingDTO listing = new ListingDTO();

        listing.itemId = (String) item.get('itemId');
        listing.title = (String) item.get('title');
        listing.itemUrl = (String) item.get('itemWebUrl');
        listing.condition = (String) item.get('condition');

        // Extract the primary image.
        Map<String, Object> imageData =
            (Map<String, Object>) item.get('image');

        if (imageData != null) {
            listing.imageUrl =
                (String) imageData.get('imageUrl');
        }

        // Extract supplier price and currency.
        Map<String, Object> priceData =
            (Map<String, Object>) item.get('price');

        if (
            priceData != null &&
            priceData.get('value') != null
        ) {

            listing.supplierPrice = Decimal.valueOf(
                String.valueOf(priceData.get('value'))
            );

            listing.currencyCode =
                (String) priceData.get('currency');
        }

        return listing;
    }


    // =====================================================
    // 5. RETURN EXISTING PRODUCT WHEN ALREADY IMPORTED
    // =====================================================

    private static ImportResult existingResult(
        Product2 existing
    ) {

        ImportResult result = new ImportResult();

        result.productId = existing.Id;
        result.productName = existing.Name;
        result.alreadyExists = true;

        result.message =
            'This eBay listing is already imported as '
            + existing.Name + '.';

        return result;
    }


    // =====================================================
    // 6. CHECK PRODUCT CREATE PERMISSIONS
    // =====================================================

    private static void checkProductCreatePermissions() {

        // Object permissions:
        // Use the object token directly. Do not call
        // getDescribe() on a DescribeSObjectResult.

        if (!Schema.sObjectType.Product2.isAccessible()) {
            throw new AuraHandledException(
                'You do not have permission to read Salesforce products.'
            );
        }

        if (!Schema.sObjectType.Product2.isCreateable()) {
            throw new AuraHandledException(
                'You do not have permission to create Salesforce products.'
            );
        }

        // Fields required for the duplicate check.
        if (
            !Schema.sObjectType.Product2.fields.Name.isAccessible() ||
            !Schema.sObjectType.Product2.fields
                .Source_eBay_Item_ID__c.isAccessible()
        ) {
            throw new AuraHandledException(
                'You need read access to the product name '
                + 'and eBay item ID fields.'
            );
        }

        // Fields assigned when creating a new product.
        if (
            !Schema.sObjectType.Product2.fields.Name.isCreateable() ||
            !Schema.sObjectType.Product2.fields.IsActive.isCreateable() ||
            !Schema.sObjectType.Product2.fields.Category__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields.Base_Price__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields.Sales_Channel__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields
                .Source_eBay_Item_ID__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields
                .Supplier_Listing_URL__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields
                .Supplier_Price__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields
                .Supplier_Currency__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields
                .Supplier_Condition__c.isCreateable() ||
            !Schema.sObjectType.Product2.fields
                .Supplier_Image_URL__c.isCreateable()
        ) {
            throw new AuraHandledException(
                'You do not have create access to one or more '
                + 'required Product2 fields. Check your permission set.'
            );
        }
    }


    // =====================================================
    // 7. VALIDATE MARKETPLACE
    // =====================================================

    private static String normalizeMarketplace(String value) {

        String marketplace = String.isBlank(value)
            ? DEFAULT_MARKETPLACE
            : value.trim().toUpperCase();

        if (!ALLOWED_MARKETPLACES.contains(marketplace)) {
            throw new AuraHandledException(
                'Unsupported eBay marketplace. '
                + 'Configure a supported marketplace in Apex.'
            );
        }

        return marketplace;
    }


    // =====================================================
    // 8. ENCODE URL PARAMETERS
    // =====================================================

    private static String encodeUrlValue(String value) {

        return EncodingUtil.urlEncode(value, 'UTF-8')
            .replace('+', '%20');
    }

}
