/**
 * Nightly follow-up reminders (requirements D.14 - D.17).
 * For every open opportunity that has an incomplete task, or an event not marked Completed, dated
 * within the last five days (run date - 5 .. run date), create one reminder task for the
 * opportunity owner. An opportunity never receives more than one follow-up reminder.
 *
 * Schedule (1 AM daily):
 *   System.schedule('Blush - Opportunity Follow-up', '0 0 1 * * ?', new OpportunityFollowUpBatch());
 *
 * Runs without sharing: a system job must see every open opportunity regardless of the scheduler.
 */
public without sharing class OpportunityFollowUpBatch implements Database.Batchable<SObject>, Schedulable {
    public static final Integer LOOKBACK_DAYS = 5;
    public static final String REMINDER_SUBJECT = 'Follow up: open opportunity has pending activities';

    private final Date runDate;

    public OpportunityFollowUpBatch() {
        this(Date.today());
    }

    public OpportunityFollowUpBatch(Date runDate) {
        this.runDate = runDate;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id, Name, OwnerId FROM Opportunity WHERE IsClosed = FALSE]);
    }

    public void execute(Database.BatchableContext context, List<Opportunity> scope) {
        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>(scope);
        Date fromDate = runDate.addDays(-LOOKBACK_DAYS);

        Set<Id> qualifying = new Set<Id>();
        for (Task t : [
            SELECT WhatId
            FROM Task
            WHERE
                WhatId IN :opportunities.keySet()
                AND IsClosed = FALSE
                AND Is_Follow_Up_Reminder__c = FALSE
                AND ActivityDate >= :fromDate
                AND ActivityDate <= :runDate
        ]) {
            qualifying.add(t.WhatId);
        }
        for (Event e : [
            SELECT WhatId
            FROM Event
            WHERE WhatId IN :opportunities.keySet() AND Is_Completed__c = FALSE AND ActivityDate >= :fromDate AND ActivityDate <= :runDate
        ]) {
            qualifying.add(e.WhatId);
        }
        if (qualifying.isEmpty()) {
            return;
        }
        for (Task reminder : [SELECT WhatId FROM Task WHERE WhatId IN :qualifying AND Is_Follow_Up_Reminder__c = TRUE]) {
            qualifying.remove(reminder.WhatId);
        }

        List<Task> reminders = new List<Task>();
        for (Id oppId : qualifying) {
            Opportunity opp = opportunities.get(oppId);
            reminders.add(
                new Task(
                    OwnerId = opp.OwnerId,
                    WhatId = opp.Id,
                    Subject = REMINDER_SUBJECT,
                    Description = 'Opportunity "' + opp.Name + '" has incomplete activities from the last ' + LOOKBACK_DAYS + ' days. Please follow up with the customer.',
                    ActivityDate = runDate,
                    Priority = 'High',
                    Status = 'Not Started',
                    Is_Follow_Up_Reminder__c = true
                )
            );
        }
        // Partial success: one inactive owner must not block reminders for everyone else.
        for (Database.SaveResult result : Database.insert(reminders, false)) {
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR, 'Follow-up reminder not created: ' + result.getErrors()[0].getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        System.debug(LoggingLevel.INFO, 'Opportunity follow-up batch finished for ' + runDate);
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new OpportunityFollowUpBatch(), 200);
    }
}