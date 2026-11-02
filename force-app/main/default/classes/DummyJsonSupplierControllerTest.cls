@IsTest
private class DummyJsonSupplierControllerTest {
    private class DummyJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            String endpoint = request.getEndpoint();

            if (endpoint.contains('/products/search?') ||
                endpoint.contains('/products/category/') ||
                endpoint.contains('/products?')) {
                response.setBody(
                    '{"products":[{"id":1,"title":"Demo Jewellery Item",' +
                    '"description":"Sample item for testing",' +
                    '"category":"womens-jewellery","price":9.99,"stock":20,' +
                    '"thumbnail":"https://cdn.dummyjson.com/product-images/1/thumbnail.jpg"}], ' +
                    '"total":1,"skip":0,"limit":20}'
                );
            } else if (endpoint.endsWith('/products/1')) {
                response.setBody(
                    '{"id":1,"title":"Demo Jewellery Item",' +
                    '"description":"Sample item for testing",' +
                    '"category":"womens-jewellery","price":9.99,"stock":20,' +
                    '"thumbnail":"https://cdn.dummyjson.com/product-images/1/thumbnail.jpg"}'
                );
            } else if (endpoint.endsWith('/products/2')) {
                response.setBody(
                    '{"id":2,"title":"Sample Mascara",' +
                    '"description":"Unsupported category for Blush",' +
                    '"category":"beauty","price":9.99,"stock":20,' +
                    '"thumbnail":"https://cdn.dummyjson.com/product-images/2/thumbnail.jpg"}'
                );
            } else {
                response.setStatusCode(404);
                response.setBody('{"message":"Product not found"}');
            }
            return response;
        }
    }

    @IsTest
    static void searchAndImportCreatesProduct2AndListing() {
        Test.setMock(HttpCalloutMock.class, new DummyJsonMock());
        Test.startTest();
        List<DummyJsonSupplierController.ProductResult> results =
            DummyJsonSupplierController.searchProducts('', 'womens-jewellery');
        Integer imported = DummyJsonSupplierController.importSelectedProducts(
            new List<String>{ '1', '1' }
        );
        Integer importedAgain = DummyJsonSupplierController.importSelectedProducts(
            new List<String>{ '1' }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One sample product should be returned.');
        System.assertEquals('1', results[0].id);
        System.assertEquals('Demo Jewellery Item', results[0].title);
        System.assertEquals(1, imported, 'Duplicate IDs in one request should be de-duplicated.');
        System.assertEquals(1, importedAgain, 'Reimport should update the existing listing.');

        List<Supplier_Listing__c> savedListings = [
            SELECT Id, External_Product_ID__c, Title__c, Source__c, Import_Status__c,
                   Demo_Price__c, Blush_Product__c
            FROM Supplier_Listing__c
            WHERE External_Product_ID__c = '1'
        ];
        System.assertEquals(1, savedListings.size(), 'A unique external ID should prevent duplicate listings.');
        System.assertEquals('DummyJSON', savedListings[0].Source__c);
        System.assertEquals('Matched', savedListings[0].Import_Status__c);
        System.assertEquals(9.99, savedListings[0].Demo_Price__c);
        System.assertNotEquals(null, savedListings[0].Blush_Product__c, 'Listing should link to Product2.');

        List<Product2> savedProducts = [
            SELECT Id, Name, ProductCode, Description, Category__c, IsActive,
                   Base_Price__c, Sales_Channel__c, DummyJSON_Product_ID__c
            FROM Product2
            WHERE DummyJSON_Product_ID__c = '1'
        ];
        System.assertEquals(1, savedProducts.size(), 'Reimport must not create another Product2.');
        System.assertEquals('Demo Jewellery Item', savedProducts[0].Name);
        System.assertEquals('DJ-1', savedProducts[0].ProductCode);
        System.assertEquals('Jewellery', savedProducts[0].Category__c);
        System.assertEquals(false, savedProducts[0].IsActive, 'Imported Product2 starts inactive for review.');
        System.assertEquals(null, savedProducts[0].Base_Price__c, 'Demo price must not be copied to Blush price.');
        System.assertEquals(null, savedProducts[0].Sales_Channel__c, 'Product must be priced before sale.');
        System.assertEquals(savedProducts[0].Id, savedListings[0].Blush_Product__c);
    }

    @IsTest
    static void rejectsUnsupportedCategoryBeforeSaving() {
        Test.setMock(HttpCalloutMock.class, new DummyJsonMock());
        Test.startTest();
        try {
            DummyJsonSupplierController.importSelectedProducts(new List<String>{ '2' });
            System.assert(false, 'Unsupported DummyJSON categories should be rejected.');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('not mapped to Blush'));
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM Supplier_Listing__c WHERE External_Product_ID__c = '2']);
        System.assertEquals(0, [SELECT count() FROM Product2 WHERE DummyJSON_Product_ID__c = '2']);
    }

    @IsTest
    static void rejectsTooManyItems() {
        List<String> ids = new List<String>();
        for (Integer i = 1; i <= 11; i++) {
            ids.add(String.valueOf(i));
        }
        try {
            DummyJsonSupplierController.importSelectedProducts(ids);
            System.assert(false, 'Expected an AuraHandledException.');
        } catch (AuraHandledException expected) {
            System.assert(expected.getMessage().contains('at most 10'));
        }
    }
}
