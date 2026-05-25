// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_Logging_DEMO.
 *
 * Validates two things subscribers care about:
 * 1. That LOG_Builder.scope() batching works end-to-end and log entries are queryable
 *    by kern__UserId__c after Test.getEventBus().deliver().
 * 2. That the single-shot criticalAlert() path persists an ERROR-level entry.
 *
 * Query pattern: kern__LogEntry__c filtered by kern__UserId__c = UserInfo.getUserId()
 * NOT CreatedById — TRG_PersistLogEntry runs as the Automated Process user.
 *
 * @see FastStart_Logging_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_Logging_DEMO_TEST
{
	/** @description Log level constant for INFO entries. */
	private static final String LOG_LEVEL_INFO = 'INFO';

	/** @description Log level constant for ERROR entries. */
	private static final String LOG_LEVEL_ERROR = 'ERROR';

	/** @description Message text used in the critical alert test. */
	private static final String ALERT_MESSAGE = 'Critical configuration missing';

	/**
	 * @description Verifies that processOrders() emits correlated INFO entries visible
	 * after platform event delivery, queried by kern__UserId__c.
	 */
	@IsTest
	private static void shouldCreateScopedLogEntriesForProcessedAccounts()
	{
		// Bypass subscriber-side Account validation rules so the test focuses on logging.
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		new FastStart_Logging_DEMO().processOrders(new List<Account>{ account });
		Test.getEventBus().deliver();
		Test.stopTest();

		Id currentUserId = UserInfo.getUserId();
		String processOrdersAt = 'FastStart_Logging_DEMO.processOrders';
		List<kern__LogEntry__c> entries = [
			SELECT kern__Message__c, kern__LogLevel__c, kern__CorrelationId__c
			FROM kern__LogEntry__c
			WHERE kern__UserId__c = :currentUserId AND kern__ClassMethod__c = :processOrdersAt
		];

		Assert.isFalse(entries.isEmpty(), 'Expected log entries to be persisted after event delivery');

		Boolean foundInfo = false;

		for(kern__LogEntry__c entry : entries)
		{
			if(entry.kern__LogLevel__c == LOG_LEVEL_INFO)
			{
				foundInfo = true;
			}
		}

		Assert.isTrue(foundInfo, 'Expected at least one INFO entry from processOrders()');
	}

	/**
	 * @description Verifies that criticalAlert() persists a single ERROR-level entry
	 * with the supplied message, queried by kern__UserId__c.
	 */
	@IsTest
	private static void shouldPersistErrorEntryForCriticalAlert()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		new FastStart_Logging_DEMO().criticalAlert(ALERT_MESSAGE);
		Test.getEventBus().deliver();
		Test.stopTest();

		Id currentUserId = UserInfo.getUserId();
		String criticalAlertAt = 'FastStart_Logging_DEMO.criticalAlert';
		List<kern__LogEntry__c> entries = [
			SELECT kern__Message__c, kern__LogLevel__c
			FROM kern__LogEntry__c
			WHERE kern__UserId__c = :currentUserId AND kern__ClassMethod__c = :criticalAlertAt AND kern__LogLevel__c = :LOG_LEVEL_ERROR
		];

		Assert.isFalse(entries.isEmpty(), 'Expected one ERROR entry from criticalAlert()');
		Assert.areEqual(ALERT_MESSAGE, entries[0].kern__Message__c, 'Message should match the alert text');
	}
}
