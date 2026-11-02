// public with sharing class QueryBuilderController {

//     public class OptionWrapper {
//         @AuraEnabled public String label { get; set; }
//         @AuraEnabled public String value { get; set; }

//         public OptionWrapper(String label, String value) {
//             this.label = label;
//             this.value = value;
//         }
//     }

//     public class QueryResultWrapper {
//         @AuraEnabled public List<String> fields { get; set; }
//         @AuraEnabled public List<Map<String, Object>> records { get; set; }

//         public QueryResultWrapper() {
//             fields = new List<String>();
//             records = new List<Map<String, Object>>();
//         }
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<OptionWrapper> getObjects() {
//         List<OptionWrapper> options = new List<OptionWrapper>();
//         Map<String, Schema.SObjectType> objectMap =
//             Schema.getGlobalDescribe();

//         List<String> objectNames = new List<String>();

//         for (String objectName : objectMap.keySet()) {
//             Schema.DescribeSObjectResult objDescribe =
//                 objectMap.get(objectName).getDescribe();

//             if (objDescribe.isQueryable() &&
//                 objDescribe.isAccessible() &&
//                 !objDescribe.isDeprecatedAndHidden()) {

//                 objectNames.add(objectName);
//             }
//         }

//         objectNames.sort();

//         for (String objectName : objectNames) {
//             options.add(new OptionWrapper(objectName, objectName));
//         }

//         return options;
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<OptionWrapper> getFields(String objectName) {
//         Map<String, Schema.SObjectType> objectMap =
//             Schema.getGlobalDescribe();

//         if (String.isBlank(objectName) ||
//             !objectMap.containsKey(objectName)) {
//             throw new AuraHandledException('Invalid object selected.');
//         }

//         Schema.DescribeSObjectResult objDescribe =
//             objectMap.get(objectName).getDescribe();

//         if (!objDescribe.isQueryable() ||
//             !objDescribe.isAccessible()) {
//             throw new AuraHandledException(
//                 'You do not have permission to query this object.'
//             );
//         }

//         Map<String, Schema.SObjectField> fieldMap =
//             objDescribe.fields.getMap();

//         List<String> fieldNames = new List<String>();

//         for (String fieldName : fieldMap.keySet()) {
//             Schema.DescribeFieldResult fieldDescribe =
//                 fieldMap.get(fieldName).getDescribe();

//             if (fieldDescribe.isAccessible()) {
//                 fieldNames.add(fieldName);
//             }
//         }

//         fieldNames.sort();

//         List<OptionWrapper> options = new List<OptionWrapper>();

//         for (String fieldName : fieldNames) {
//             options.add(new OptionWrapper(fieldName, fieldName));
//         }

//         return options;
//     }

//     @AuraEnabled
//     public static QueryResultWrapper executeQuery(
//         String soql,
//         Integer recordLimit
//     ) {
//         if (String.isBlank(soql)) {
//             throw new AuraHandledException(
//                 'Please enter a SOQL query.'
//             );
//         }

//         if (recordLimit == null ||
//             !new Set<Integer>{500, 1000, 5000, 50000}
//                 .contains(recordLimit)) {
//             throw new AuraHandledException('Invalid record limit.');
//         }

//         String queryText = soql.trim();

//         if (!queryText.toUpperCase().startsWith('SELECT ')) {
//             throw new AuraHandledException(
//                 'Only SELECT queries are allowed.'
//             );
//         }

//         if (queryText.contains(';')) {
//             throw new AuraHandledException(
//                 'Multiple statements are not allowed.'
//             );
//         }

//         String upperQuery = queryText.toUpperCase();

//         if (upperQuery.contains(' FOR UPDATE') ||
//             upperQuery.contains(' OFFSET ')) {
//             throw new AuraHandledException(
//                 'FOR UPDATE and OFFSET are not supported.'
//             );
//         }

//         Integer effectiveLimit = recordLimit;
//         Integer limitPosition = upperQuery.lastIndexOf(' LIMIT ');

//         if (limitPosition >= 0) {
//             String suppliedLimit = queryText.substring(
//                 limitPosition + 7
//             ).trim();

//             if (!Pattern.matches('[0-9]+', suppliedLimit)) {
//                 throw new AuraHandledException(
//                     'Use a numeric LIMIT at the end of the query.'
//                 );
//             }

//             Integer userLimit = Integer.valueOf(suppliedLimit);

//             if (userLimit < 1) {
//                 throw new AuraHandledException(
//                     'LIMIT must be greater than zero.'
//                 );
//             }

//             effectiveLimit = Math.min(recordLimit, userLimit);

//             queryText = queryText.substring(0, limitPosition).trim();
//         }

//         queryText += ' LIMIT ' + effectiveLimit;

//         try {
//             List<SObject> queriedRecords =
//                 Database.query(queryText, AccessLevel.USER_MODE);

//             QueryResultWrapper result = new QueryResultWrapper();

//             for (SObject recordItem : queriedRecords) {
//                 Map<String, Object> row =
//                     new Map<String, Object>();

//                 Map<String, Object> rawFields =
//                     recordItem.getPopulatedFieldsAsMap();

//                 for (String fieldName : rawFields.keySet()) {
//                     row.put(fieldName, rawFields.get(fieldName));

//                     if (!result.fields.contains(fieldName)) {
//                         result.fields.add(fieldName);
//                     }
//                 }

//                 Id recordId = (Id) recordItem.get('Id');

//                 row.put(
//                     'RecordUrl',
//                     recordId == null ? null : '/' + recordId
//                 );

//                 String recordLabel = String.valueOf(recordId);

//                 if (rawFields.containsKey('Name') &&
//                     rawFields.get('Name') != null) {
//                     recordLabel = String.valueOf(rawFields.get('Name'));
//                 }

//                 row.put('RecordLabel', recordLabel);
//                 result.records.add(row);
//             }

//             result.fields.sort();
//             return result;

//         } catch (Exception e) {
//             throw new AuraHandledException(
//                 'Invalid SOQL query: ' + e.getMessage()
//             );
//         }
//     }
// }







public with sharing class QueryBuilderController {

    public class OptionWrapper {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public OptionWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class QueryResultWrapper {
        @AuraEnabled public List<String> fields { get; set; }
        @AuraEnabled public List<Map<String, Object>> records { get; set; }

        public QueryResultWrapper() {
            fields = new List<String>();
            records = new List<Map<String, Object>>();
        }
    }

    // Get available queryable objects.
    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getObjects() {
        List<OptionWrapper> options = new List<OptionWrapper>();

        Map<String, Schema.SObjectType> objectMap =
            Schema.getGlobalDescribe();

        List<String> objectNames = new List<String>();

        for (String objectName : objectMap.keySet()) {
            Schema.DescribeSObjectResult objDescribe =
                objectMap.get(objectName).getDescribe();

            if (objDescribe.isQueryable() &&
                objDescribe.isAccessible() &&
                !objDescribe.isDeprecatedAndHidden()) {

                objectNames.add(objectName);
            }
        }

        objectNames.sort();

        for (String objectName : objectNames) {
            options.add(new OptionWrapper(objectName, objectName));
        }

        return options;
    }

    // Get accessible fields for the selected object.
    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getFields(String objectName) {
        Map<String, Schema.SObjectType> objectMap =
            Schema.getGlobalDescribe();

        if (String.isBlank(objectName) ||
            !objectMap.containsKey(objectName)) {

            throw new AuraHandledException('Invalid object selected.');
        }

        Schema.DescribeSObjectResult objDescribe =
            objectMap.get(objectName).getDescribe();

        if (!objDescribe.isQueryable() ||
            !objDescribe.isAccessible()) {

            throw new AuraHandledException(
                'You do not have permission to query this object.'
            );
        }

        Map<String, Schema.SObjectField> fieldMap =
            objDescribe.fields.getMap();

        List<String> fieldNames = new List<String>();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldName).getDescribe();

            if (fieldDescribe.isAccessible()) {
                fieldNames.add(fieldName);
            }
        }

        fieldNames.sort();

        List<OptionWrapper> options = new List<OptionWrapper>();

        for (String fieldName : fieldNames) {
            options.add(new OptionWrapper(fieldName, fieldName));
        }

        return options;
    }

    // Save a named SOQL query in Salesforce.
    @AuraEnabled
    public static Id saveQuery(String queryName, String soql) {
        if (String.isBlank(queryName)) {
            throw new AuraHandledException(
                'Please enter a name for the saved query.'
            );
        }

        if (queryName.trim().length() > 80) {
            throw new AuraHandledException(
                'Query name cannot exceed 80 characters.'
            );
        }

        if (String.isBlank(soql)) {
            throw new AuraHandledException(
                'Please enter a SOQL query to save.'
            );
        }

        if (soql.length() > 32768) {
            throw new AuraHandledException(
                'The SOQL query is too long to save.'
            );
        }

        try {
            Saved_Query__c savedQuery = new Saved_Query__c(
                Name = queryName.trim(),
                SOQL_Query__c = soql.trim()
            );

            Database.insert(savedQuery, AccessLevel.USER_MODE);

            return savedQuery.Id;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to save query: ' + e.getMessage()
            );
        }
    }

    // Get saved queries for the dropdown.
    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getSavedQueries() {
        List<OptionWrapper> options = new List<OptionWrapper>();

        try {
            List<Saved_Query__c> savedQueries = [
                SELECT Id, Name
                FROM Saved_Query__c
                WITH USER_MODE
                ORDER BY Name
            ];

            for (Saved_Query__c savedQuery : savedQueries) {
                options.add(
                    new OptionWrapper(
                        savedQuery.Name,
                        String.valueOf(savedQuery.Id)
                    )
                );
            }

        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load saved queries. Check your Saved Query '
                + 'object and field permissions.'
            );
        }

        return options;
    }

    // Retrieve the SOQL text of the selected saved query.
    @AuraEnabled
    public static String getSavedQuery(Id savedQueryId) {
        if (savedQueryId == null) {
            throw new AuraHandledException(
                'Please select a saved query.'
            );
        }

        try {
            List<Saved_Query__c> savedQueries = [
                SELECT Id, SOQL_Query__c
                FROM Saved_Query__c
                WHERE Id = :savedQueryId
                WITH USER_MODE
                LIMIT 1
            ];

            if (savedQueries.isEmpty()) {
                throw new AuraHandledException(
                    'Saved query not found or access denied.'
                );
            }

            return savedQueries[0].SOQL_Query__c;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to retrieve saved query. Check your permissions.'
            );
        }
    }

    // Execute a SELECT query and return its records.
    @AuraEnabled
    public static QueryResultWrapper executeQuery(
        String soql,
        Integer recordLimit
    ) {
        if (String.isBlank(soql)) {
            throw new AuraHandledException(
                'Please enter a SOQL query.'
            );
        }

        if (recordLimit == null ||
            !new Set<Integer>{500, 1000, 5000, 50000}
                .contains(recordLimit)) {

            throw new AuraHandledException('Invalid record limit.');
        }

        String queryText = soql.trim();

        if (!queryText.toUpperCase().startsWith('SELECT ')) {
            throw new AuraHandledException(
                'Only SELECT queries are allowed.'
            );
        }

        if (queryText.contains(';')) {
            throw new AuraHandledException(
                'Multiple statements are not allowed.'
            );
        }

        String upperQuery = queryText.toUpperCase();

        if (upperQuery.contains(' FOR UPDATE') ||
            upperQuery.contains(' OFFSET ')) {

            throw new AuraHandledException(
                'FOR UPDATE and OFFSET are not supported.'
            );
        }

        Integer effectiveLimit = recordLimit;
        Integer limitPosition = upperQuery.lastIndexOf(' LIMIT ');

        if (limitPosition >= 0) {
            String suppliedLimit = queryText.substring(
                limitPosition + 7
            ).trim();

            if (!Pattern.matches('[0-9]+', suppliedLimit)) {
                throw new AuraHandledException(
                    'Use a numeric LIMIT at the end of the query.'
                );
            }

            Integer userLimit;

            try {
                userLimit = Integer.valueOf(suppliedLimit);
            } catch (Exception e) {
                throw new AuraHandledException(
                    'The supplied LIMIT is too large.'
                );
            }

            if (userLimit < 1) {
                throw new AuraHandledException(
                    'LIMIT must be greater than zero.'
                );
            }

            effectiveLimit = Math.min(recordLimit, userLimit);

            queryText = queryText.substring(0, limitPosition).trim();
        }

        queryText += ' LIMIT ' + effectiveLimit;

        try {
            List<SObject> queriedRecords =
                Database.query(queryText, AccessLevel.USER_MODE);

            QueryResultWrapper result = new QueryResultWrapper();

            for (SObject recordItem : queriedRecords) {
                Map<String, Object> row =
                    new Map<String, Object>();

                Map<String, Object> rawFields =
                    recordItem.getPopulatedFieldsAsMap();

                for (String fieldName : rawFields.keySet()) {
                    row.put(fieldName, rawFields.get(fieldName));

                    if (!result.fields.contains(fieldName)) {
                        result.fields.add(fieldName);
                    }
                }

                Id recordId = (Id) recordItem.get('Id');

                row.put(
                    'RecordUrl',
                    recordId == null ? null : '/' + recordId
                );

                String recordLabel = String.valueOf(recordId);

                if (rawFields.containsKey('Name') &&
                    rawFields.get('Name') != null) {

                    recordLabel = String.valueOf(rawFields.get('Name'));
                }

                row.put('RecordLabel', recordLabel);
                result.records.add(row);
            }

            result.fields.sort();
            return result;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Invalid SOQL query: ' + e.getMessage()
            );
        }
    }
}