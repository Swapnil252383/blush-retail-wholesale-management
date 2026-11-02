// Runs the opportunity follow-up job immediately (it also runs every night at 1 AM).
Database.executeBatch(new OpportunityFollowUpBatch(), 200);
