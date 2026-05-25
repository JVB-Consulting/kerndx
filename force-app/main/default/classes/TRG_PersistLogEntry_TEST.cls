// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for TRG_PersistLogEntry trigger action.
 *
 * @see TRG_PersistLogEntry
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date January 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_PersistLogEntry_TEST
{
	private static final String TEST_CLASS_METHOD = 'TestClass/testMethod';
	private static final String TEST_MESSAGE = 'Test log message';

	/**
	 * @description Tests that a LogEntry__c record is created when a LogEntryEvent__e is published.
	 */
	@IsTest
	private static void shouldCreateLogEntryFromEvent()
	{
		LogEntryEvent__e event = new LogEntryEvent__e();
		event.ClassMethod__c = TEST_CLASS_METHOD;
		event.Message__c = TEST_MESSAGE;
		event.LogLevel__c = 'ERROR';

		Test.startTest();

		Database.SaveResult result = EventBus.publish(event);

		Test.stopTest();

		Assert.isTrue(result.isSuccess(), 'Event should be published successfully');

		List<LogEntry__c> logs =
		[
				SELECT ClassMethod__c,
						Message__c,
						LogLevel__c
				FROM LogEntry__c
				WHERE ClassMethod__c = :TEST_CLASS_METHOD
		];
		Assert.areEqual(1, logs.size(), 'One log record should be created');
		Assert.areEqual(TEST_CLASS_METHOD, logs[0].ClassMethod__c, 'ClassMethod should match');
		Assert.areEqual(TEST_MESSAGE, logs[0].Message__c, 'Message should match');
	}

	/**
	 * @description Tests that multiple LogEntry__c records are created from multiple events.
	 */
	@IsTest
	private static void shouldCreateMultipleLogEntriesFromEvents()
	{
		List<LogEntryEvent__e> events = new List<LogEntryEvent__e>();

		for(Integer i = 0; i < 5; i++)
		{
			LogEntryEvent__e event = new LogEntryEvent__e();
			event.ClassMethod__c = TEST_CLASS_METHOD + i;
			event.Message__c = TEST_MESSAGE + i;
			event.LogLevel__c = 'INFO';
			events.add(event);
		}

		Test.startTest();

		List<Database.SaveResult> results = EventBus.publish(events);

		Test.stopTest();

		for(Database.SaveResult result : results)
		{
			Assert.isTrue(result.isSuccess(), 'All events should be published successfully');
		}

		List<LogEntry__c> logs =
		[
				SELECT ClassMethod__c
				FROM LogEntry__c
				WHERE ClassMethod__c LIKE :TEST_CLASS_METHOD + '%'
		];
		Assert.areEqual(5, logs.size(), 'Five log records should be created');
	}

	/**
	 * @description Tests that correlation fields (CorrelationId, TransactionId, ParentTransactionId)
	 * are correctly persisted from LogEntryEvent__e to LogEntry__c.
	 */
	@IsTest
	private static void shouldPersistCorrelationFields()
	{
		String testCorrelationId = 'test-correlation-persist-123';
		String testTransactionId = 'test-txn-456';
		String testParentTransactionId = 'test-parent-txn-789';

		LogEntryEvent__e event = new LogEntryEvent__e();
		event.ClassMethod__c = TEST_CLASS_METHOD;
		event.Message__c = TEST_MESSAGE;
		event.LogLevel__c = 'INFO';
		event.CorrelationId__c = testCorrelationId;
		event.TransactionId__c = testTransactionId;
		event.ParentTransactionId__c = testParentTransactionId;

		Test.startTest();

		EventBus.publish(event);

		Test.stopTest();

		List<LogEntry__c> logs =
		[
				SELECT CorrelationId__c,
						TransactionId__c,
						ParentTransactionId__c
				FROM LogEntry__c
				WHERE ClassMethod__c = :TEST_CLASS_METHOD
		];
		Assert.areEqual(1, logs.size(), 'One log record should be created');
		Assert.areEqual(testCorrelationId, logs[0].CorrelationId__c, 'CorrelationId should be persisted');
		Assert.areEqual(testTransactionId, logs[0].TransactionId__c, 'TransactionId should be persisted');
		Assert.areEqual(testParentTransactionId, logs[0].ParentTransactionId__c, 'ParentTransactionId should be persisted');
	}

	/**
	 * @description Tests that multiple log entries sharing the same CorrelationId and TransactionId
	 * are all persisted correctly, enabling end-to-end correlation queries.
	 */
	@IsTest
	private static void shouldCorrelateMultipleEntriesFromSameTransaction()
	{
		String sharedCorrelationId = 'shared-correlation-456';
		String sharedTransactionId = 'shared-txn-789';

		List<LogEntryEvent__e> events = new List<LogEntryEvent__e>();

		for(String classMethod : new List<String> {'CTRL_Account/saveAccount', 'TRG_SetDefaults/beforeInsert', 'API_Notify/process'})
		{
			LogEntryEvent__e event = new LogEntryEvent__e();
			event.ClassMethod__c = classMethod;
			event.Message__c = 'Correlated log entry';
			event.LogLevel__c = 'INFO';
			event.CorrelationId__c = sharedCorrelationId;
			event.TransactionId__c = sharedTransactionId;
			events.add(event);
		}

		Test.startTest();

		EventBus.publish(events);

		Test.stopTest();

		List<LogEntry__c> logs =
		[
				SELECT ClassMethod__c,
						CorrelationId__c,
						TransactionId__c
				FROM LogEntry__c
				WHERE CorrelationId__c = :sharedCorrelationId
				ORDER BY ClassMethod__c ASC
		];
		Assert.areEqual(3, logs.size(), 'Three correlated entries should be created');

		Set<String> classMethodValues = new Set<String>();
		for(LogEntry__c log : logs)
		{
			Assert.areEqual(sharedCorrelationId, log.CorrelationId__c, 'All entries should share the CorrelationId');
			Assert.areEqual(sharedTransactionId, log.TransactionId__c, 'All entries should share the TransactionId');
			classMethodValues.add(log.ClassMethod__c);
		}

		Assert.isTrue(classMethodValues.contains('API_Notify/process'), 'API log should be present');
		Assert.isTrue(classMethodValues.contains('CTRL_Account/saveAccount'), 'Controller log should be present');
		Assert.isTrue(classMethodValues.contains('TRG_SetDefaults/beforeInsert'), 'Trigger log should be present');
	}

	/**
	 * @description Tests that long text fields are stored correctly.
	 */
	@IsTest
	private static void shouldStoreLongFields()
	{
		LogSetting__c setting = new LogSetting__c();
		setting.IsEnabled__c = true;
		setting.LogLevelThreshold__c = 'DEBUG';
		setting.EnableTriggerPerformanceLogging__c = false;
		LOG_Engine.logSettingOverride = setting;

		String longMessage = 'A'.repeat(40000);

		LogEntryEvent__e event = new LogEntryEvent__e();
		event.ClassMethod__c = TEST_CLASS_METHOD;
		event.Message__c = longMessage;
		event.LogLevel__c = 'DEBUG';

		Test.startTest();

		EventBus.publish(event);

		Test.stopTest();

		List<LogEntry__c> logs =
		[
				SELECT Message__c
				FROM LogEntry__c
				WHERE ClassMethod__c = :TEST_CLASS_METHOD
		];
		Assert.areEqual(1, logs.size(), 'One log record should be created');
		Assert.areEqual(40000, logs[0].Message__c.length(), 'Message should be stored in full');
	}
}