// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber proof for the 1.2 record-id input on the Flow logging action
 * (kern.FLOW_LoggerLog). The action's DTO_Request gains a recordId @InvocableVariable; when
 * set, execute() ties the persisted log entry to that record via forRecord(), the same way a
 * log written from Apex can be. These tests invoke the global invocable directly from Apex
 * (construct the request, call execute, deliver the platform event) and assert the persisted
 * kern__LogEntry__c carries kern__RecordId__c.
 *
 * Query pattern: kern__LogEntry__c filtered by kern__UserId__c = UserInfo.getUserId()
 * NOT CreatedById — TRG_PersistLogEntry runs as the Automated Process user.
 *
 * Runs IsParallel=false on purpose: these tests publish a LogEntryEvent__e and persist it via
 * Test.getEventBus().deliver(), and concurrent LogEntry__c inserts from the rest of the suite
 * can starve that delivery under load. Serial execution keeps the event-delivery assertion stable.
 *
 * @see kern.FLOW_LoggerLog
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class Subscriber_FlowLoggerRecordId_TEST
{
	/**
	 * @description Log level used for the Flow log entries under test.
	 */
	private static final String LOG_LEVEL_INFO = 'INFO';

	/**
	 * @description Class/method stamp the Flow logging action records on its entries when no
	 * flowStep is supplied (FLOW_LoggerLog builds 'Flow/' + (flowStep ?: 'action')).
	 */
	private static final String FLOW_CLASS_METHOD = 'Flow/action';

	/**
	 * @description Verifies that a recordId supplied to the Flow logging action ties the
	 * persisted log entry to that record via kern__RecordId__c. The correlation suffix is
	 * alphanumeric, never an epoch timestamp: a Luhn-valid thirteen-digit run is card-shaped and
	 * gets redacted by the framework's card masking, so the read-back query would find nothing.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldLinkLogEntryToRecordWhenRecordIdSupplied()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		kern.LOG_Builder.ignoreTestMode = true;
		String correlationId = 'flow-recordid-' + kern.UTIL_Random.randomAlphanumeric(12);

		kern.FLOW_LoggerLog.DTO_Request request = new kern.FLOW_LoggerLog.DTO_Request();
		request.correlationId = correlationId;
		request.message = 'Linked to record';
		request.logLevel = LOG_LEVEL_INFO;
		request.recordId = account.Id;

		Test.startTest();
		kern.FLOW_LoggerLog.execute(new List<kern.FLOW_LoggerLog.DTO_Request> {request});
		Test.getEventBus().deliver();
		Test.stopTest();

		List<kern__LogEntry__c> flowEntries = flowLogEntries(correlationId);
		Assert.isFalse(flowEntries.isEmpty(), 'The Flow logging action should persist a log entry');
		for(kern__LogEntry__c entry : flowEntries)
		{
			Assert.areEqual(account.Id, entry.kern__RecordId__c, 'Each Flow log entry should be linked to the supplied record Id');
		}
	}

	/**
	 * @description Verifies that omitting recordId leaves the Flow log entry unlinked
	 * (kern__RecordId__c null), proving the link is driven by the new input rather than
	 * stamped unconditionally. The correlation suffix is alphanumeric for the same
	 * card-masking reason as the linked-record case above.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldLeaveLogEntryUnlinkedWhenRecordIdOmitted()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		String correlationId = 'flow-norecordid-' + kern.UTIL_Random.randomAlphanumeric(12);

		kern.FLOW_LoggerLog.DTO_Request request = new kern.FLOW_LoggerLog.DTO_Request();
		request.correlationId = correlationId;
		request.message = 'No record link';
		request.logLevel = LOG_LEVEL_INFO;

		Test.startTest();
		kern.FLOW_LoggerLog.execute(new List<kern.FLOW_LoggerLog.DTO_Request> {request});
		Test.getEventBus().deliver();
		Test.stopTest();

		List<kern__LogEntry__c> flowEntries = flowLogEntries(correlationId);
		Assert.isFalse(flowEntries.isEmpty(), 'The Flow logging action should persist a log entry');
		for(kern__LogEntry__c entry : flowEntries)
		{
			Assert.isNull(entry.kern__RecordId__c, 'No Flow log entry should be linked when no recordId is supplied');
		}
	}

	/**
	 * @description Queries the Flow logging action's persisted entries for a correlation Id.
	 * Scopes to kern__ClassMethod__c = 'Flow/action' (the FLOW_LoggerLog stamp) so incidental
	 * framework logs sharing the transaction correlation are excluded, and filters by
	 * kern__UserId__c because TRG_PersistLogEntry runs as the Automated Process user.
	 *
	 * @param correlationId The correlation Id set on the Flow request.
	 *
	 * @return The Flow log entries for that correlation.
	 */
	private static List<kern__LogEntry__c> flowLogEntries(String correlationId)
	{
		return
		[
				SELECT kern__RecordId__c
				FROM kern__LogEntry__c
				WHERE kern__UserId__c = :UserInfo.getUserId()
				AND kern__CorrelationId__c = :correlationId
				AND kern__ClassMethod__c = :FLOW_CLASS_METHOD
		];
	}
}
