public with sharing class CounterService {
    public static void incrementCounter(Id counterRecordId) {
        Counter_Record__c counterRecord = [
            SELECT Id, Counter__c
            FROM Counter_Record__c
            WHERE Id = :counterRecordId
            LIMIT 1
        ];

        counterRecord.Counter__c = (counterRecord.Counter__c == null)
            ? 1
            : counterRecord.Counter__c + 1;
        update counterRecord;
    }
}
