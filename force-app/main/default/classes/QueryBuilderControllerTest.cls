@IsTest
private class QueryBuilderControllerTest {

    // Q1: Test available objects
    @IsTest
    static void testGetObjects() {
        Test.startTest();
        List<QueryBuilderController.OptionWrapper> results =
            QueryBuilderController.getObjects();
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(!results.isEmpty());

        Boolean foundAccount = false;

        for (QueryBuilderController.OptionWrapper option : results) {
            if (option.value == 'Account') {
                foundAccount = true;
                break;
            }
        }

        System.assert(foundAccount, 'Account should be available.');
    }

    // Q2: Test available fields
    @IsTest
    static void testGetFields() {
        Test.startTest();
        List<QueryBuilderController.OptionWrapper> results =
            QueryBuilderController.getFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(!results.isEmpty());

        Boolean foundName = false;

        for (QueryBuilderController.OptionWrapper option : results) {
            if (option.value == 'Name') {
                foundName = true;
                break;
            }
        }

        System.assert(foundName, 'Account Name should be available.');
    }

    // Q3: Test blank object name
    @IsTest
    static void testBlankObject() {
        Boolean exceptionThrown = false;

        try {
            QueryBuilderController.getFields('');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }

    // Q4: Test invalid object name
    @IsTest
    static void testInvalidObject() {
        Boolean exceptionThrown = false;

        try {
            QueryBuilderController.getFields('Invalid_Object__c');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }

    // Q5: Test successful query with Name
    @IsTest
    static void testExecuteQueryWithName() {
        Account testAccount =
            new Account(Name = 'Query Builder Test');
        insert testAccount;

        Test.startTest();

        QueryBuilderController.QueryResultWrapper result =
            QueryBuilderController.executeQuery(
                'SELECT Id, Name FROM Account WHERE Id = \'' +
                testAccount.Id + '\'',
                500
            );

        Test.stopTest();

        System.assertEquals(1, result.records.size());
        System.assertEquals(
            testAccount.Id,
            (Id) result.records[0].get('Id')
        );
        System.assertEquals(
            'Query Builder Test',
            result.records[0].get('Name')
        );
        System.assertEquals(
            '/' + testAccount.Id,
            result.records[0].get('RecordUrl')
        );
        System.assertEquals(
            'Query Builder Test',
            result.records[0].get('RecordLabel')
        );
        System.assert(result.fields.contains('Id'));
        System.assert(result.fields.contains('Name'));
    }

    // Q6: Test query without Name
    @IsTest
    static void testExecuteQueryWithoutName() {
        Account testAccount =
            new Account(Name = 'Id Only Test');
        insert testAccount;

        QueryBuilderController.QueryResultWrapper result =
            QueryBuilderController.executeQuery(
                'SELECT Id FROM Account WHERE Id = \'' +
                testAccount.Id + '\'',
                500
            );

        System.assertEquals(1, result.records.size());
        System.assertEquals(
            String.valueOf(testAccount.Id),
            result.records[0].get('RecordLabel')
        );
        System.assertEquals(
            '/' + testAccount.Id,
            result.records[0].get('RecordUrl')
        );
    }

    // Q7: Test query returning no records
    @IsTest
    static void testQueryNoRecords() {
        QueryBuilderController.QueryResultWrapper result =
            QueryBuilderController.executeQuery(
                'SELECT Id, Name FROM Account ' +
                'WHERE Name = \'No Such Account Exists\'',
                500
            );

        System.assertEquals(0, result.records.size());
        System.assertEquals(0, result.fields.size());
    }

    // Q8: Test blank query
    @IsTest
    static void testBlankQuery() {
        assertQueryThrows('', 500);
        assertQueryThrows('   ', 500);
    }

    // Q9: Test invalid record limits
    @IsTest
    static void testInvalidLimits() {
        assertQueryThrows('SELECT Id FROM Account', 100);
        assertQueryThrows('SELECT Id FROM Account', null);
    }

    // Q10: Test non-SELECT query
    @IsTest
    static void testInvalidQueryType() {
        assertQueryThrows('DELETE FROM Account', 500);
    }

    // Q11: Test multiple statements
    @IsTest
    static void testSemicolonQuery() {
        assertQueryThrows(
            'SELECT Id FROM Account;',
            500
        );
    }

    // Q12: Test FOR UPDATE restriction
    @IsTest
    static void testForUpdateQuery() {
        assertQueryThrows(
            'SELECT Id FROM Account FOR UPDATE',
            500
        );
    }

    // Q13: Test OFFSET restriction
    @IsTest
    static void testOffsetQuery() {
        assertQueryThrows(
            'SELECT Id FROM Account OFFSET 1',
            500
        );
    }

    // Q14: Test non-numeric LIMIT
    @IsTest
    static void testNonNumericLimit() {
        assertQueryThrows(
            'SELECT Id FROM Account LIMIT abc',
            500
        );
    }

    // Q15: Test LIMIT zero
    @IsTest
    static void testZeroLimit() {
        assertQueryThrows(
            'SELECT Id FROM Account LIMIT 0',
            500
        );
    }

    // Q16: Test valid user-supplied LIMIT
    @IsTest
    static void testValidUserLimit() {
        Account testAccount =
            new Account(Name = 'Limit Test');
        insert testAccount;

        QueryBuilderController.QueryResultWrapper result =
            QueryBuilderController.executeQuery(
                'SELECT Id FROM Account WHERE Id = \'' +
                testAccount.Id + '\' LIMIT 1',
                500
            );

        System.assertEquals(1, result.records.size());
    }

    // Q17: Test invalid SOQL handled by catch block
    @IsTest
    static void testMalformedSoql() {
        assertQueryThrows(
            'SELECT InvalidField__c FROM Account',
            500
        );
    }

    // Common helper for testing expected exceptions
    private static void assertQueryThrows(
        String soql,
        Integer recordLimit
    ) {
        Boolean exceptionThrown = false;

        try {
            QueryBuilderController.executeQuery(
                soql,
                recordLimit
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(
            exceptionThrown,
            'Expected an exception for query: ' + soql
        );
    }
}