// Marks outbound API calls an earlier version left at Retry with no Next Retry time as Failed, 2000 at a time.
// Run it again until it reports 0 rows. It sends nothing and changes no API issue.
List<kern__ApiCall__c> stranded = [SELECT Id FROM kern__ApiCall__c WHERE kern__Direction__c = 'Outbound' AND kern__Status__c = 'Retry' AND kern__NextRetry__c = null LIMIT 2000];
for(kern__ApiCall__c item : stranded)
{
    item.kern__Status__c = 'Failed';
}
List<Database.SaveResult> saveResults = Database.update(stranded, false);
Integer marked = 0;
for(Integer index = 0; index < saveResults.size(); index++)
{
    if(saveResults[index].isSuccess())
    {
        marked++;
    }
    else
    {
        System.debug(LoggingLevel.ERROR, 'Not marked ' + stranded[index].Id + ': ' + saveResults[index].getErrors()[0].getMessage());
    }
}
System.debug(LoggingLevel.ERROR, 'Marked Failed: ' + marked + ' of ' + stranded.size());
