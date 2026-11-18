// Elastic limits probe: save one outbound call for the RetryLiveGet handler, the way a subscriber's own code saves one.
//
// Token:
//   __MODE__  queued: Direction Outbound, Status Queued, which is the start filter of the InvokeOutboundApiCall flow,
//                     so the save queues the first send.
//             retry:  Direction Outbound, Status Retry, NextRetry__c one minute out and one retry counted (the state
//                     section 84a leaves a failed GET in), which is the start filter of the RetryOutboundApiCall flow;
//                     its scheduled path fires about a minute later, outside this script, and read-budget.apex
//                     reports what it did.
//             retrying: Direction Outbound, Status Retrying, NextRetry__c five minutes ago and one retry counted: the
//                     state a retry is left in when its background job stopped and nothing will finish it. Neither
//                     outbound flow starts on a call at Retrying, so nothing sends it; only the outbound retry
//                     watchdog (schedule-once.apex with outboundWatchdog) deals with it.
//
// The handler's credential names a Named Credential that does not exist, so every send fails at the send point and
// nothing leaves the org. The script does not call the dispatcher. It catches the save's exception and prints its type
// and message, then queries whether the row exists (an after-save flow that fails rolls the whole save back) and, if
// it does, its status, retry time, retry count and the first 1000 characters of its error text.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f <rendered copy with the token replaced> --json > <file>
final String MODE = '__MODE__';
final String SERVICE_GET = API_RetryLiveGet.class.getName();
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';

System.OrgLimit daily = OrgLimits.getMap().get('DailyAsyncApexExecutions');
Datetime startedAt = System.now().addSeconds(-1);
Integer rowsBefore = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_GET];
System.debug('PROBE CALL INSERT time=' + System.now().format(TIME_FORMAT, TIME_ZONE) + ' mode=' + MODE + ' remaining=' + (daily.getLimit() - daily.getValue())
		+ ' rowsBefore=' + rowsBefore);

kern__ApiCall__c call = kern.TST_Factory.newOutboundApiCall(SERVICE_GET);
call.kern__Direction__c = 'Outbound';
if(MODE == 'retry')
{
	call.kern__Status__c = 'Retry';
	call.kern__NextRetry__c = System.now().addMinutes(1);
	call.kern__Retries__c = 1;
}
else if(MODE == 'retrying')
{
	call.kern__Status__c = 'Retrying';
	call.kern__NextRetry__c = System.now().addMinutes(-5);
	call.kern__Retries__c = 1;
}
else
{
	call.kern__Status__c = 'Queued';
}
try
{
	insert call;
	System.debug('PROBE CALL INSERT saved id=' + call.Id);
}
catch(Exception saveError)
{
	System.debug('PROBE CALL INSERT refused ' + saveError.getTypeName() + ': ' + saveError.getMessage());
}

List<kern__ApiCall__c> rows = [SELECT Id, kern__Status__c, kern__NextRetry__c, kern__Retries__c, kern__ErrorMessages__c FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = :SERVICE_GET AND CreatedDate >= :startedAt];
System.debug('PROBE CALL INSERT rowExists=' + !rows.isEmpty() + (rows.isEmpty() ? '' : ' id=' + rows[0].Id + ' status=' + rows[0].kern__Status__c
		+ ' nextRetry=' + rows[0].kern__NextRetry__c?.format(TIME_FORMAT, TIME_ZONE) + ' retries=' + rows[0].kern__Retries__c
		+ ' errors=' + rows[0].kern__ErrorMessages__c?.abbreviate(1000)));
for(AsyncApexJob job : [SELECT Id, ApexClass.Name, Status FROM AsyncApexJob WHERE CreatedDate >= :startedAt ORDER BY CreatedDate])
{
	System.debug('PROBE CALL INSERT job id=' + job.Id + ' class=' + job.ApexClass?.Name + ' status=' + job.Status);
}
