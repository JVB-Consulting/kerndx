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
 * @date January 2026, July 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_PersistLogEntry_TEST
{
	/**
	 * @description Class/method stamp used on test events.
	 */
	private static final String TEST_CLASS_METHOD = 'TestClass/testMethod';

	/**
	 * @description Message body used on test events.
	 */
	private static final String TEST_MESSAGE = 'Test log message';

	/**
	 * @description Grouping key used by the flood-control tests.
	 */
	private static final String TEST_FINGERPRINT = 'aggregator-test-key';

	/**
	 * @description Key prefix marking the single forensic detail row per fingerprint.
	 */
	private static final String PREFIX_DETAIL = 'detail:';

	/**
	 * @description Key prefix marking windowed rollup counter rows.
	 */
	private static final String PREFIX_ROLLUP = 'rollup:';

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

		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD);
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

		List<LogEntry__c> logs = new List<LogEntry__c>();
		for(LogEntry__c log : new SEL_LogEntry().getAll())
		{
			if(log.ClassMethod__c?.startsWith(TEST_CLASS_METHOD) == true)
			{
				logs.add(log);
			}
		}
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

		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD);
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

		List<LogEntry__c> logs = new SEL_LogEntry().findByField(LogEntry__c.CorrelationId__c, sharedCorrelationId);
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

		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD);
		Assert.areEqual(1, logs.size(), 'One log record should be created');
		Assert.areEqual(40000, logs[0].Message__c.length(), 'Message should be stored in full');
	}

	/**
	 * @description Tests that the first occurrence of a novel fingerprint persists a full detail
	 * row AND a rollup row counting it (count includes the detailed occurrence).
	 */
	@IsTest
	private static void shouldInsertDetailAndRollupOnFirstOccurrence()
	{
		Test.startTest();
		EventBus.publish(buildEvent(TEST_FINGERPRINT));
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		LogEntry__c detail = rows.get(PREFIX_DETAIL + TEST_FINGERPRINT);
		Assert.isNotNull(detail, 'Novel fingerprint must produce a detail row');
		Assert.areEqual(TEST_MESSAGE, detail.Message__c, 'Detail row is a full forensic sample');
		Assert.isNull(detail.OccurrenceCount__c, 'Detail rows carry no occurrence count');

		LogEntry__c rollup = findRollup(rows, TEST_FINGERPRINT);
		Assert.isNotNull(rollup, 'A rollup row for the current window must exist');
		Assert.areEqual(1, rollup.OccurrenceCount__c?.intValue(), 'Window count includes the detailed occurrence');
	}

	/**
	 * @description Tests that repeats of one fingerprint within a single chunk collapse to one
	 * detail row and one rollup row whose count equals the total occurrences.
	 */
	@IsTest
	private static void shouldCollapseRepeatsWithinOneChunk()
	{
		List<LogEntryEvent__e> events = new List<LogEntryEvent__e>();
		for(Integer i = 0; i < 5; i++)
		{
			events.add(buildEvent(TEST_FINGERPRINT));
		}

		Test.startTest();
		EventBus.publish(events);
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.isNotNull(rows.get(PREFIX_DETAIL + TEST_FINGERPRINT), 'Exactly one detail row');
		Assert.areEqual(5, findRollup(rows, TEST_FINGERPRINT).OccurrenceCount__c?.intValue(), 'All five occurrences counted');
		Assert.areEqual(2, countOwnFingerprintRows(rows), 'Five identical events collapse to detail + rollup');
	}

	/**
	 * @description Tests that a known fingerprint (detail row already present) increments the
	 * existing rollup row instead of inserting new rows — the steady-state path.
	 */
	@IsTest
	private static void shouldIncrementExistingRollupForKnownFingerprint()
	{
		Test.startTest();
		EventBus.publish(buildEvent(TEST_FINGERPRINT));
		Test.getEventBus().deliver();
		EventBus.publish(buildEvent(TEST_FINGERPRINT));
		Test.getEventBus().deliver();
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.areEqual(2, countOwnFingerprintRows(rows), 'Steady state stays at detail + rollup');
		Assert.areEqual(2, findRollup(rows, TEST_FINGERPRINT).OccurrenceCount__c?.intValue(), 'Second occurrence incremented the window count');
	}

	/**
	 * @description Tests the presence invariant self-heal: when the detail row is purged, the
	 * next occurrence re-inserts it (logs cleared → fingerprint re-introduces itself).
	 */
	@IsTest
	private static void shouldReArmDetailRowAfterPurge()
	{
		Test.startTest();
		EventBus.publish(buildEvent(TEST_FINGERPRINT));
		Test.getEventBus().deliver();

		LogEntry__c detail = rowsByFingerprint().get(PREFIX_DETAIL + TEST_FINGERPRINT);
		DML_Builder.newTransaction().systemModeInternal().doDelete(detail).execute();

		EventBus.publish(buildEvent(TEST_FINGERPRINT));
		Test.getEventBus().deliver();
		Test.stopTest();

		Assert.isNotNull(rowsByFingerprint().get(PREFIX_DETAIL + TEST_FINGERPRINT), 'Purged detail row must re-arm on next occurrence');
	}

	/**
	 * @description Tests that window assignment follows the event publish time (CreatedDate), not
	 * persist time: events from two different UTC days produce two rollup rows (a delivery backlog
	 * crossing midnight must not mis-bucket). CreatedDate is read-only on platform events, so the
	 * events are JSON-deserialized with it pre-set and handed to afterInsert directly.
	 */
	@IsTest
	private static void shouldBucketRollupsByEventPublishDay()
	{
		LogEntryEvent__e dayOne = buildEventPublishedAt('2026-06-06T23:59:00.000Z');
		LogEntryEvent__e dayTwo = buildEventPublishedAt('2026-06-07T00:01:00.000Z');

		Test.startTest();
		new TRG_PersistLogEntry().afterInsert(new List<SObject> {dayOne, dayTwo});
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.isNotNull(rows.get(PREFIX_ROLLUP + TEST_FINGERPRINT + ':20260606'), 'Day-one bucket row expected');
		Assert.isNotNull(rows.get(PREFIX_ROLLUP + TEST_FINGERPRINT + ':20260607'), 'Day-two bucket row expected');
		Assert.areEqual(1, rows.get(PREFIX_ROLLUP + TEST_FINGERPRINT + ':20260606').OccurrenceCount__c?.intValue(), 'One occurrence per day bucket');
		Assert.isNotNull(rows.get(PREFIX_DETAIL + TEST_FINGERPRINT), 'Single detail row spans both windows');
	}

	/**
	 * @description Tests that the fingerprint-key codec round-trips against this class's independent
	 * key-shape oracles: a base that itself contains the colon separator composes into the documented
	 * detail:/rollup: shapes and decodes back to the identical base, so a read layer decoding through the
	 * codec can never truncate a base fingerprint.
	 */
	@IsTest
	private static void shouldRoundTripFingerprintKeyCodec()
	{
		String base = 'NullPointer:MyClass.method';
		Datetime occurredAt = Datetime.newInstanceGmt(2026, 6, 26, 23, 59, 59);

		String detailKey = TRG_PersistLogEntry.buildDetailKey(base);
		String rollupKey = TRG_PersistLogEntry.buildRollupKey(base, occurredAt);

		Assert.areEqual(PREFIX_DETAIL + base, detailKey, 'The detail key is the documented prefix plus the base');
		Assert.areEqual(PREFIX_ROLLUP + base + ':20260626', rollupKey, 'The rollup key carries the GMT day bucket of the occurrence instant');
		Assert.areEqual(base, TRG_PersistLogEntry.decodeBaseFromDetailKey(detailKey), 'Decoding the detail key recovers the identical base');
		Assert.areEqual
				(
						base,
						TRG_PersistLogEntry.decodeBaseFromRollupKey(rollupKey), 'Decoding the rollup key strips exactly the prefix and the day suffix, even when the base contains colons'
				);
	}

	/**
	 * @description Tests that events without a fingerprint follow the existing plain path
	 * unchanged — the regression guard pinning Fingerprint__c and OccurrenceCount__c null.
	 */
	@IsTest
	private static void shouldPersistUnfingerprintedEventsUnchanged()
	{
		Test.startTest();
		EventBus.publish(buildEvent(null));
		Test.stopTest();

		List<LogEntry__c> all = new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD);
		Assert.areEqual(1, all.size(), 'One plain row');
		Assert.isNull(all[0].Fingerprint__c, 'Plain rows carry no fingerprint');
		Assert.isNull(all[0].OccurrenceCount__c, 'Plain rows carry no count');
	}

	/**
	 * @description Tests that an empty chunk persists nothing and consumes no DML — the
	 * defensive early-return guard for a no-op delivery.
	 */
	@IsTest
	private static void shouldPersistNothingForEmptyChunk()
	{
		Test.startTest();
		Integer dmlBefore = Limits.getDmlStatements();
		new TRG_PersistLogEntry().afterInsert(new List<SObject>());
		Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;
		Test.stopTest();

		Assert.areEqual(0, dmlUsed, 'An empty chunk must consume no DML');
		Assert.isTrue(new SEL_LogEntry().getAll().isEmpty(), 'An empty chunk must persist no rows');
	}

	/**
	 * @description Pins the governor cost at full chunk scale: 2000 fingerprinted events across
	 * mixed novel keys must aggregate with at most one fingerprint SOQL query and bulkified DML
	 * (equality IN on the unique index, index seek by construction).
	 */
	@IsTest
	private static void shouldAggregateFullChunkWithinGovernorBudget()
	{
		List<SObject> events = new List<SObject>();
		for(Integer i = 0; i < 2000; i++)
		{
			events.add(buildEvent(TEST_FINGERPRINT + '-' + Math.mod(i, 50)));
		}

		Test.startTest();
		Integer queriesBefore = Limits.getQueries();
		Integer dmlBefore = Limits.getDmlStatements();
		new TRG_PersistLogEntry().afterInsert(events);
		Integer queriesUsed = Limits.getQueries() - queriesBefore;
		Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;
		Test.stopTest();

		Assert.isTrue(queriesUsed <= 1, 'Aggregation must use at most one SOQL query, used: ' + queriesUsed);
		Assert.isTrue(dmlUsed <= 2, 'Aggregation must use bulkified DML (insert+update at most), used: ' + dmlUsed);
		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.areEqual(100, rows.size(), '50 keys produce 50 detail + 50 rollup rows');
		Assert.areEqual(40, findRollup(rows, TEST_FINGERPRINT + '-0').OccurrenceCount__c?.intValue(), '2000 events over 50 keys = 40 per key');
	}

	/**
	 * @description Builds a fingerprinted LogEntryEvent__e for publishing.
	 *
	 * @param fingerprint The grouping key to stamp on the event.
	 *
	 * @return The unpublished event.
	 */
	private static LogEntryEvent__e buildEvent(String fingerprint)
	{
		LogEntryEvent__e event = new LogEntryEvent__e();
		event.ClassMethod__c = TEST_CLASS_METHOD;
		event.Message__c = TEST_MESSAGE;
		event.LogLevel__c = 'WARN';
		event.Fingerprint__c = fingerprint;
		return event;
	}

	/**
	 * @description Builds a fingerprinted event whose read-only CreatedDate is pre-set via a JSON
	 * round-trip. Serializing a real event emits context-correct field API names (namespace-prefixed
	 * in a managed install), so the payload never hardcodes a field-name literal; CreatedDate is a
	 * standard field and carries no prefix in any context.
	 *
	 * @param publishInstant The ISO 8601 UTC instant to stamp as the event publish time.
	 *
	 * @return The unpublished event carrying the pre-set CreatedDate.
	 */
	private static LogEntryEvent__e buildEventPublishedAt(String publishInstant)
	{
		Map<String, Object> raw = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(buildEvent(TEST_FINGERPRINT)));
		raw.put('CreatedDate', publishInstant);
		return (LogEntryEvent__e)JSON.deserialize(JSON.serialize(raw), LogEntryEvent__e.class);
	}

	/**
	 * @description Returns all persisted rows carrying a fingerprint, keyed by Fingerprint__c.
	 *
	 * @return Map of fingerprint key to row.
	 */
	private static Map<String, LogEntry__c> rowsByFingerprint()
	{
		Map<String, LogEntry__c> rows = new Map<String, LogEntry__c>();
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(String.isNotBlank(row.Fingerprint__c))
			{
				rows.put(row.Fingerprint__c, row);
			}
		}
		return rows;
	}

	/**
	 * @description Finds the (single) rollup row for a key irrespective of its day-bucket suffix.
	 *
	 * @param rows All fingerprinted rows keyed by Fingerprint__c.
	 * @param fingerprint The bare grouping key.
	 *
	 * @return The rollup row, or null when absent.
	 */
	private static LogEntry__c findRollup(Map<String, LogEntry__c> rows, String fingerprint)
	{
		for(String key : rows.keySet())
		{
			if(key.startsWith(PREFIX_ROLLUP + fingerprint + ':'))
			{
				return rows.get(key);
			}
		}
		return null;
	}

	/**
	 * @description Counts only the rows keyed by this test's own fingerprint. Orgs with their own
	 * flag-gated trigger actions (e.g. a subscriber harness) legitimately persist additional
	 * flood-controlled skip rows during the same transaction, so unfiltered map-size assertions are
	 * environment-fragile — a doubling regression still fails this count because doubled rows share
	 * the test's key.
	 *
	 * @param rows All fingerprinted rows keyed by Fingerprint__c.
	 *
	 * @return The number of rows whose key contains this test's fingerprint.
	 */
	private static Integer countOwnFingerprintRows(Map<String, LogEntry__c> rows)
	{
		Integer ownRows = 0;
		for(String key : rows.keySet())
		{
			if(key.contains(TEST_FINGERPRINT))
			{
				ownRows++;
			}
		}
		return ownRows;
	}
}