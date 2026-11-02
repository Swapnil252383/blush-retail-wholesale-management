trigger Product2Trigger on Product2 (after insert, after update) {
    ProductPricebookService.syncPricebookEntries(Trigger.new, Trigger.oldMap);
}