// Schedules the nightly opportunity follow-up job (1 AM every day) and runs it once now.
// Run: sf apex run --file scripts/apex/schedule-jobs.apex --target-org MyDevOrg
String jobName = 'Blush - Opportunity Follow-up (nightly)';
if ([SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :jobName] == 0) {
    System.schedule(jobName, '0 0 1 * * ?', new OpportunityFollowUpBatch());
}
Database.executeBatch(new OpportunityFollowUpBatch(), 200);
