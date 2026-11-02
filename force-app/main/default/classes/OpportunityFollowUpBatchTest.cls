@IsTest
private class OpportunityFollowUpBatchTest {
    private static final Date RUN_DATE = Date.newInstance(2026, 7, 15);

    @TestSetup
    static void setup() {
        TestDataFactory.createPricebooks();
        Account acc = TestDataFactory.createAccount('Follow-up Customer', 'Retail', TestDataFactory.MAHARASHTRA);
        List<Opportunity> opps = new List<Opportunity>();
        for (String name : new List<String>{ 'Recent Task', 'Old Task', 'Completed Task', 'Recent Event', 'Completed Event', 'Closed Deal', 'No Activity' }) {
            Opportunity opp = TestDataFactory.buildOpportunity('Retail', name, null, null);
            opp.Name = name;
            opp.AccountId = acc.Id;
            if (name == 'Closed Deal') {
                opp.StageName = 'Closed Won';
            }
            opps.add(opp);
        }
        insert opps;
    }

    private static Id oppId(String name) {
        return [SELECT Id FROM Opportunity WHERE Name = :name].Id;
    }

    private static Task task(String oppName, Date activityDate, String status) {
        return new Task(WhatId = oppId(oppName), Subject = 'Call customer', ActivityDate = activityDate, Status = status);
    }

    private static Event event(String oppName, Date activityDate, Boolean completed) {
        Datetime start = Datetime.newInstance(activityDate, Time.newInstance(11, 0, 0, 0));
        return new Event(WhatId = oppId(oppName), Subject = 'Store visit', StartDateTime = start, EndDateTime = start.addHours(1), Is_Completed__c = completed);
    }

    private static Set<Id> remindedOpportunities() {
        Set<Id> ids = new Set<Id>();
        for (Task t : [SELECT WhatId, OwnerId, ActivityDate, Subject FROM Task WHERE Is_Follow_Up_Reminder__c = TRUE]) {
            Assert.areEqual(UserInfo.getUserId(), t.OwnerId, 'Reminder goes to the opportunity owner');
            Assert.areEqual(RUN_DATE, t.ActivityDate);
            Assert.areEqual(OpportunityFollowUpBatch.REMINDER_SUBJECT, t.Subject);
            ids.add(t.WhatId);
        }
        return ids;
    }

    @IsTest
    static void remindsOnlyForOpenOpportunitiesWithRecentIncompleteActivities() {
        insert new List<Task>{
            task('Recent Task', Date.newInstance(2026, 7, 12), 'Not Started'), // qualifies (example in requirement)
            task('Old Task', Date.newInstance(2026, 7, 1), 'Not Started'), // older than five days
            task('Completed Task', Date.newInstance(2026, 7, 14), 'Completed'),
            task('Closed Deal', Date.newInstance(2026, 7, 14), 'Not Started')
        };
        insert new List<Event>{ event('Recent Event', Date.newInstance(2026, 7, 10), false), event('Completed Event', Date.newInstance(2026, 7, 13), true) };

        Test.startTest();
        Database.executeBatch(new OpportunityFollowUpBatch(RUN_DATE));
        Test.stopTest();

        Set<Id> reminded = remindedOpportunities();
        Assert.areEqual(new Set<Id>{ oppId('Recent Task'), oppId('Recent Event') }, reminded);
    }

    @IsTest
    static void windowBoundariesAreInclusive() {
        insert new List<Task>{
            task('Recent Task', RUN_DATE.addDays(-5), 'Not Started'),
            task('Old Task', RUN_DATE.addDays(-6), 'Not Started'),
            task('Recent Event', RUN_DATE, 'In Progress')
        };

        Test.startTest();
        Database.executeBatch(new OpportunityFollowUpBatch(RUN_DATE));
        Test.stopTest();

        Assert.areEqual(new Set<Id>{ oppId('Recent Task'), oppId('Recent Event') }, remindedOpportunities());
    }

    @IsTest
    static void createsAtMostOneReminderPerOpportunity() {
        Id recent = oppId('Recent Task');
        insert new List<Task>{ task('Recent Task', RUN_DATE.addDays(-1), 'Not Started'), task('Recent Task', RUN_DATE.addDays(-2), 'Not Started') };
        insert new Task(
            WhatId = recent,
            Subject = OpportunityFollowUpBatch.REMINDER_SUBJECT,
            ActivityDate = RUN_DATE.addDays(-1),
            Status = 'Not Started',
            Is_Follow_Up_Reminder__c = true
        );

        Test.startTest();
        Database.executeBatch(new OpportunityFollowUpBatch(RUN_DATE));
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Task WHERE WhatId = :recent AND Is_Follow_Up_Reminder__c = TRUE]);
    }

    @IsTest
    static void reminderTasksDoNotTriggerFurtherReminders() {
        insert new Task(
            WhatId = oppId('No Activity'),
            Subject = OpportunityFollowUpBatch.REMINDER_SUBJECT,
            ActivityDate = RUN_DATE,
            Status = 'Not Started',
            Is_Follow_Up_Reminder__c = true
        );
        Test.startTest();
        Database.executeBatch(new OpportunityFollowUpBatch(RUN_DATE));
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM Task WHERE Is_Follow_Up_Reminder__c = TRUE]);
    }

    @IsTest
    static void noQualifyingActivitiesCreatesNothing() {
        Test.startTest();
        Database.executeBatch(new OpportunityFollowUpBatch());
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Task]);
    }

    @IsTest
    static void schedulerQueuesTheBatch() {
        Test.startTest();
        Id jobId = System.schedule('Blush follow-up test', '0 0 1 * * ?', new OpportunityFollowUpBatch());
        Test.stopTest();

        CronTrigger job = [SELECT CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual('0 0 1 * * ?', job.CronExpression);
        Assert.areEqual(0, job.TimesTriggered);
    }
}