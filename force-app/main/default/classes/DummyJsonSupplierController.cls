public with sharing class DummyJsonSupplierController {
    private static final String API_BASE = 'callout:DummyJSON_API';
    private static final Integer RESULT_LIMIT = 20;
    private static final Integer MAX_IMPORT = 10;
    private static final Set<String> ALLOWED_CATEGORIES = new Set<String>{
        'womens-jewellery', 'womens-dresses', 'tops', 'mens-shirts'
    };

    public class ProductResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public Decimal price { get; set; }
        @AuraEnabled public Integer stock { get; set; }
        @AuraEnabled public String thumbnail { get; set; }
    }

    @AuraEnabled
    public static List<ProductResult> searchProducts(String searchTerm, String category) {
        String path;
        if (String.isNotBlank(searchTerm)) {
            path = '/products/search?q=' + EncodingUtil.urlEncode(searchTerm.trim(), 'UTF-8')
                + '&limit=' + RESULT_LIMIT;
        } else if (String.isNotBlank(category) && category != 'all') {
            if (!ALLOWED_CATEGORIES.contains(category)) {
                throw new AuraHandledException('Select one of the supported sample categories.');
            }
            path = '/products/category/' + category + '?limit=' + RESULT_LIMIT;
        } else {
            path = '/products?limit=' + RESULT_LIMIT;
        }

        Map<String, Object> payload = getJson(path);
        List<Object> rawProducts = (List<Object>) payload.get('products');
        List<ProductResult> results = new List<ProductResult>();
        if (rawProducts == null) {
            return results;
        }
        for (Object rawProduct : rawProducts) {
            results.add(toProductResult((Map<String, Object>) rawProduct));
        }
        return results;
    }

    // Imports selected listings and creates an INACTIVE Product2 record for each new supported item.
    // DummyJSON price and stock are sample values and are intentionally not copied to Blush price/inventory.
    @AuraEnabled
    public static Integer importSelectedProducts(List<String> externalIds) {
        if (externalIds == null || externalIds.isEmpty()) {
            throw new AuraHandledException('Select at least one sample product to import.');
        }
        if (externalIds.size() > MAX_IMPORT) {
            throw new AuraHandledException('Import at most 10 products at a time.');
        }

        Set<String> uniqueIds = new Set<String>();
        for (String rawId : externalIds) {
            if (String.isBlank(rawId)) {
                continue;
            }
            Integer numericId;
            try {
                numericId = Integer.valueOf(rawId.trim());
            } catch (Exception e) {
                throw new AuraHandledException('A selected product ID is invalid. Search again and retry.');
            }
            if (numericId <= 0) {
                throw new AuraHandledException('A selected product ID is invalid.');
            }
            uniqueIds.add(String.valueOf(numericId));
        }
        if (uniqueIds.isEmpty()) {
            throw new AuraHandledException('Select at least one valid sample product.');
        }

        // Complete every external callout before performing any Salesforce DML.
        Map<String, ProductResult> fetchedById = new Map<String, ProductResult>();
        for (String productId : uniqueIds) {
            Map<String, Object> payload = getJson('/products/' + productId);
            ProductResult result = toProductResult(payload);
            if (result.id != productId) {
                throw new AuraHandledException('DummyJSON returned an unexpected product ID.');
            }
            if (String.isBlank(mapBlushCategory(result.category))) {
                throw new AuraHandledException(
                    'The selected item "' + result.title + '" has DummyJSON category "' + result.category +
                    '", which is not mapped to Blush. Use Jewellery sample or Garments sample (dresses, tops, shirts). ' +
                    'No records were imported.'
                );
            }
            fetchedById.put(result.id, result);
        }

        Map<String, Supplier_Listing__c> existingListingByExternalId = new Map<String, Supplier_Listing__c>();
        for (Supplier_Listing__c listing : [
            SELECT Id, External_Product_ID__c, Import_Status__c, Blush_Product__c
            FROM Supplier_Listing__c
            WHERE External_Product_ID__c IN :uniqueIds
        ]) {
            existingListingByExternalId.put(listing.External_Product_ID__c, listing);
        }

        Map<String, Id> productIdByExternalId = new Map<String, Id>();
        for (Product2 product : [
            SELECT Id, DummyJSON_Product_ID__c
            FROM Product2
            WHERE DummyJSON_Product_ID__c IN :uniqueIds
        ]) {
            productIdByExternalId.put(product.DummyJSON_Product_ID__c, product.Id);
        }

        // Respect a product match the employee has already chosen on Supplier Listing.
        for (String externalId : uniqueIds) {
            Supplier_Listing__c existingListing = existingListingByExternalId.get(externalId);
            if (existingListing != null && existingListing.Blush_Product__c != null) {
                productIdByExternalId.put(externalId, existingListing.Blush_Product__c);
            }
        }

        // Create Product2 only for IDs that do not already have a linked/external-ID Product2.
        List<Product2> productsToInsert = new List<Product2>();
        for (ProductResult result : fetchedById.values()) {
            if (productIdByExternalId.containsKey(result.id)) {
                continue;
            }
            Product2 product = new Product2();
            product.Name = truncate(result.title, 255);
            product.ProductCode = 'DJ-' + result.id;
            product.Description = truncate(result.description, 4000);
            product.DummyJSON_Product_ID__c = result.id;
            product.Category__c = mapBlushCategory(result.category);
            product.IsActive = false;
            // Do not copy result.price to Base_Price__c: DummyJSON values are not verified INR prices.
            // Do not set Sales_Channel__c: the product must be priced/reviewed before sale.
            productsToInsert.add(product);
        }

        if (!productsToInsert.isEmpty()) {
            insert productsToInsert;
            for (Product2 product : productsToInsert) {
                productIdByExternalId.put(product.DummyJSON_Product_ID__c, product.Id);
            }
        }

        List<Supplier_Listing__c> listingsToSave = new List<Supplier_Listing__c>();
        for (ProductResult result : fetchedById.values()) {
            Supplier_Listing__c listing = existingListingByExternalId.get(result.id);
            if (listing == null) {
                listing = new Supplier_Listing__c(
                    External_Product_ID__c = result.id,
                    Import_Status__c = 'New'
                );
            }
            // Refresh only marketplace data; don't overwrite an employee's existing match or review status.
            listing.Source__c = 'DummyJSON';
            listing.Title__c = truncate(result.title, 255);
            listing.Description__c = truncate(result.description, 32000);
            listing.External_Category__c = result.category;
            listing.Demo_Price__c = result.price;
            listing.Demo_Stock__c = result.stock;
            listing.Thumbnail_URL__c = result.thumbnail;
            listing.Last_Synced_At__c = System.now();
            if (listing.Blush_Product__c == null) {
                listing.Blush_Product__c = productIdByExternalId.get(result.id);
            }
            if (listing.Blush_Product__c != null &&
                (listing.Import_Status__c == null || listing.Import_Status__c == 'New')) {
                listing.Import_Status__c = 'Matched';
            }
            listingsToSave.add(listing);
        }

        upsert listingsToSave External_Product_ID__c;
        return listingsToSave.size();
    }

    private static String mapBlushCategory(String externalCategory) {
        if (externalCategory == 'womens-jewellery') {
            return 'Jewellery';
        }
        if (externalCategory == 'womens-dresses' || externalCategory == 'tops' || externalCategory == 'mens-shirts') {
            return 'Garments';
        }
        return null;
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private static Map<String, Object> getJson(String path) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(API_BASE + path);
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(20000);

        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Could not connect to DummyJSON. Check the DummyJSON_API Named Credential and try again.'
            );
        }

        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new AuraHandledException('DummyJSON returned HTTP ' + response.getStatusCode() + '. Try again later.');
        }
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        } catch (Exception e) {
            throw new AuraHandledException('DummyJSON returned an unexpected response format.');
        }
    }

    private static ProductResult toProductResult(Map<String, Object> raw) {
        ProductResult result = new ProductResult();
        result.id = raw.get('id') == null ? null : String.valueOf(raw.get('id'));
        result.title = (String) raw.get('title');
        result.description = (String) raw.get('description');
        result.category = (String) raw.get('category');
        result.price = raw.get('price') == null ? null : Decimal.valueOf(String.valueOf(raw.get('price')));
        result.stock = raw.get('stock') == null ? null : Integer.valueOf(String.valueOf(raw.get('stock')));
        result.thumbnail = (String) raw.get('thumbnail');
        return result;
    }
}
