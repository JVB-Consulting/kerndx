// Stuck Retry re-save probe, setup: make two outbound calls that are stuck at Retry, as the 1.11 limit left them.
//
// A stuck call is at Retry, its Next Retry time is in the past, it has no API issue and no scheduled path of the
// RetryOutboundApiCall flow waits for it. This script makes that state the way the elastic limits probe did (Task 1d):
//   1. save two calls at Retry with Next Retry one minute out and one retry counted;
//   2. delete them, which removes the scheduled paths the save started;
//   3. undelete them. A record-triggered flow does not run on an undelete, so no path waits for them any more.
// The object's trigger is turned off around the delete and the undelete only, because its delete guards refuse to
// delete an API call for a user without the Delete API Records permission.
// The calls are saved with the trigger action that fills Triggering Record Index turned off for this script only, so
// the field stays blank, as on a call saved before 1.12. That is the row the release note's backfill script picks.
//
// One call is the probe (the backfill save is run on it); the other is the control (it is saved again with a new
// future Next Retry time to prove the flow still sends a call). Both use the service API_Echo with Direction Outbound:
// the handler is an inbound class, so a send never makes a callout and nothing leaves the org: the send job runs and
// ends the call at Aborted. Only that job and the change of the call's status show that a send happened.
//
// Prints the two Ids, the Next Retry time and the read-back of each row. Times are Eastern (America/New_York).
// Run: sf apex run -o YourDevOrgAlias -f release-testing/scripts/ws2-stuck-retry-resave-setup.apex --json > <file>
final String SERVICE_NAME = API_Echo.class.getName();
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';
final String STATUS_RETRY = 'Retry';

Datetime nextRetry = System.now().addMinutes(1);
TRG_Base.bypassAction(TRG_SetTriggeringRecordIndex.class.getName());

List<ApiCall__c> calls = new List<ApiCall__c>();
for(Integer callNumber = 0; callNumber < 2; callNumber++)
{
	ApiCall__c call = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());
	call.Status__c = STATUS_RETRY;
	call.NextRetry__c = nextRetry;
	call.Retries__c = 1;
	calls.add(call);
}
insert calls;
System.debug('WS2 SETUP saved time=' + System.now().format(TIME_FORMAT, TIME_ZONE) + ' nextRetry=' + nextRetry.format(TIME_FORMAT, TIME_ZONE));
TRG_Base.bypass(ApiCall__c.SObjectType);
delete calls;
System.debug('WS2 SETUP deleted time=' + System.now().format(TIME_FORMAT, TIME_ZONE));
undelete calls;
System.debug('WS2 SETUP undeleted time=' + System.now().format(TIME_FORMAT, TIME_ZONE));
TRG_Base.clearBypass(ApiCall__c.SObjectType);
TRG_Base.clearActionBypass(TRG_SetTriggeringRecordIndex.class.getName());

System.debug('WS2 SETUP probeId=' + calls[0].Id + ' controlId=' + calls[1].Id);
for(ApiCall__c row : [SELECT Id, Name, Status__c, NextRetry__c, Retries__c, TriggeringRecordId__c, TriggeringRecordIndex__c, LastModifiedDate FROM ApiCall__c
		WHERE Id IN :calls ORDER BY CreatedDate, Id])
{
	System.debug('WS2 SETUP row id=' + row.Id + ' name=' + row.Name + ' status=' + row.Status__c + ' nextRetry=' + row.NextRetry__c?.format(TIME_FORMAT, TIME_ZONE)
			+ ' retries=' + row.Retries__c + ' triggeringId=' + row.TriggeringRecordId__c + ' index=' + row.TriggeringRecordIndex__c
			+ ' lastModified=' + row.LastModifiedDate.format(TIME_FORMAT, TIME_ZONE));
}
