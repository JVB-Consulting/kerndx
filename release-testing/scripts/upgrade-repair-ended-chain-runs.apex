// Sets each chain run that an earlier version left at Stalled with an end time back to the status it really ended with.
// A run whose steps all succeeded becomes Completed; any other run becomes Failed. The end time is kept.
List<kern__AsyncChainExecution__c> endedRuns = [SELECT Id, kern__StepLog__c, kern__ErrorMessage__c FROM kern__AsyncChainExecution__c WHERE kern__Status__c = 'Stalled' AND kern__CompletedAt__c != null];
Integer messageLength = Schema.SObjectType.kern__AsyncChainExecution__c.fields.kern__ErrorMessage__c.getLength();
List<kern__AsyncChainExecution__c> repairs = new List<kern__AsyncChainExecution__c>();
for(kern__AsyncChainExecution__c run : endedRuns)
{
    List<Map<String, Object>> entries = new List<Map<String, Object>>();
    try
    {
        for(Object item : (List<Object>)JSON.deserializeUntyped(run.kern__StepLog__c))
        {
            entries.add((Map<String, Object>)item);
        }
    }
    catch(Exception error)
    {
        System.debug(LoggingLevel.ERROR, 'Skipped ' + run.Id + ': its step log could not be read (' + error.getMessage() + ')');
        continue;
    }
    Boolean allStepsSucceeded = true;
    for(Map<String, Object> entry : entries)
    {
        Boolean isHandler = entry.get('isErrorHandler') == true || entry.get('isCompletionHandler') == true;
        if(!isHandler && entry.get('success') != true)
        {
            allStepsSucceeded = false;
        }
    }
    kern__AsyncChainExecution__c repair = new kern__AsyncChainExecution__c(Id = run.Id);
    repair.kern__Status__c = allStepsSucceeded ? 'Completed' : 'Failed';
    repair.kern__FailureCategory__c = allStepsSucceeded ? null : 'StepException';
    repair.kern__ActiveDeduplicationKey__c = null;
    String earlierMessage = run.kern__ErrorMessage__c == null ? '' : run.kern__ErrorMessage__c;
    repair.kern__ErrorMessage__c = ('Repaired on ' + Date.today().format() + ': ' + earlierMessage).left(messageLength);
    repairs.add(repair);
}
List<Database.SaveResult> saveResults = Database.update(repairs, false);
for(Integer index = 0; index < saveResults.size(); index++)
{
    if(saveResults[index].isSuccess())
    {
        System.debug(LoggingLevel.ERROR, 'Repaired ' + repairs[index].Id + ': ' + repairs[index].kern__Status__c);
    }
    else
    {
        System.debug(LoggingLevel.ERROR, 'Not repaired ' + repairs[index].Id + ': ' + saveResults[index].getErrors()[0].getMessage());
    }
}
