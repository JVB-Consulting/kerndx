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
 * @date January 2026, August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
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
	 * @description Grouping key used by the durability tests that force a rejected detail row: they
	 * store a row under this key for real, then blind the presence check to it, so the handler
	 * inserts a row the database refuses — the state a writer is in when another transaction wins
	 * the race between its presence check and its insert.
	 */
	private static final String DUPLICATE_KEY_FINGERPRINT = 'f1-duplicate-key';

	/**
	 * @description Message stamped on the pre-stored detail row so the tests can prove the rejected
	 * duplicate never overwrote the sample already on file.
	 */
	private static final String STORED_SAMPLE_MESSAGE = 'Detail row already on file';

	/**
	 * @description Class/method stamp on the pre-stored detail row, kept apart from every other stamp
	 * so counting the rows of one class/method never accidentally counts the row the test seeded.
	 */
	private static final String STORED_SAMPLE_CLASS_METHOD = 'TestClass/storedDetailSample';

	/**
	 * @description Bare grouping key the whitespace tests group under, kept apart from the padded
	 * form so the assertions never re-derive the trimmed key the way the handler does.
	 */
	private static final String PADDED_FINGERPRINT_BASE = 'f1-padded-key';

	/**
	 * @description The grouping key as the event actually carries it: the bare key wrapped in the
	 * edge whitespace Salesforce strips on save.
	 */
	private static final String PADDED_FINGERPRINT = UTIL_String.SPACE + PADDED_FINGERPRINT_BASE + UTIL_String.SPACE;

	/**
	 * @description Longest grouping key `LogEntryEvent__e.Fingerprint__c` accepts, read off the field
	 * itself so the test tracks the platform's own limit rather than a copied number.
	 */
	private static final Integer MAXIMUM_EVENT_FINGERPRINT_LENGTH = LogEntryEvent__e.Fingerprint__c.getDescribe().getLength();

	/**
	 * @description A grouping key filling `LogEntryEvent__e.Fingerprint__c` to its limit — valid on
	 * the event, and longer than the prefixed `detail:`/`rollup:` key the row is stored under.
	 */
	private static final String FIELD_LENGTH_FINGERPRINT = 'f1-field-length-key'.rightPad(MAXIMUM_EVENT_FINGERPRINT_LENGTH, 'x');

	/**
	 * @description Class/method stamp on the events whose flood-control row the database refuses, so
	 * the rows recovered from them are distinguishable from every other row in their chunk.
	 */
	private static final String REFUSED_CLASS_METHOD = 'TestClass/refusedFloodControlRow';

	/**
	 * @description Class/method the fallback breadcrumb is stamped with — this test's independent
	 * oracle of the handler's own stamp.
	 */
	private static final String BREADCRUMB_CLASS_METHOD = TRG_PersistLogEntry.class.getName() + '/persist';

	/**
	 * @description Opening phrase every fallback breadcrumb carries.
	 */
	private static final String BREADCRUMB_PREFIX = 'flood-control fallback:';

	/**
	 * @description Separator after which the breadcrumb quotes the database's own rejection text.
	 */
	private static final String BREADCRUMB_ERROR_SEPARATOR = 'first error: ';

	/**
	 * @description Platform wording of a unique-index rejection, the signature the flood-control
	 * fallback exists to make visible.
	 */
	private static final String DUPLICATE_VALUE_TEXT = 'duplicate value found';

	/**
	 * @description Tally the breadcrumb must carry when the one rejected row was stored plain.
	 */
	private static final String TALLY_ONE_STORED_PLAIN = '1 events stored plain';

	/**
	 * @description Message on the query failure the durability test stages, so the failure the
	 * fallback answers is this test's own and never an incidental one.
	 */
	private static final String SIMULATED_QUERY_FAILURE = 'Simulated presence-check query failure';

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
	 * @description Tests that a grouping key arriving with edge whitespace is stored under its
	 * trimmed form. Salesforce strips a text field's edge whitespace on save, so a key stored as
	 * sent would live under a value no lookup of the key as sent can match — the presence check
	 * would miss it every time and every persist of that key would be refused, permanently. The
	 * assertion that no fallback breadcrumb exists is the point of the test: the rows are never
	 * refused, not merely recovered afterwards.
	 *
	 * Driven through `persist` directly, the entry point `LOG_Engine` uses when a log is emitted
	 * inside an event trigger: there the events are handed over in memory, exactly as the caller
	 * built them, so edge whitespace survives. Publishing would not reproduce it — the platform
	 * strips the event field's own edge whitespace before delivery.
	 */
	@IsTest
	private static void shouldStoreAPaddedGroupingKeyUnderItsTrimmedForm()
	{
		Test.startTest();
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {buildEvent(PADDED_FINGERPRINT)});
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.isNotNull(rows.get(PREFIX_DETAIL + PADDED_FINGERPRINT_BASE), 'A padded key stores its detail row under the trimmed key');
		Assert.areEqual(1, findRollup(rows, PADDED_FINGERPRINT_BASE).OccurrenceCount__c?.intValue(), 'The trimmed key counts its first occurrence');
		Assert.isTrue(new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD).isEmpty(), 'A key normalized on arrival is never refused, so no fallback breadcrumb is written');
	}

	/**
	 * @description Tests that a second occurrence of a padded grouping key increments the counter of
	 * the window the first occurrence opened, rather than colliding with it. This is the steady state
	 * the defect denied: an untrimmed key could never be found again, so every later occurrence was
	 * refused instead of counted, and each one wrote another fallback breadcrumb. Driven through the
	 * in-memory `persist` entry point for the reason the first-occurrence test records.
	 */
	@IsTest
	private static void shouldIncrementTheRollupWhenAPaddedGroupingKeyRecurs()
	{
		Test.startTest();
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {buildEvent(PADDED_FINGERPRINT)});
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {buildEvent(PADDED_FINGERPRINT)});
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.areEqual(2, findRollup(rows, PADDED_FINGERPRINT_BASE).OccurrenceCount__c?.intValue(), 'The second occurrence increments the window the first opened');
		Assert.isNotNull(rows.get(PREFIX_DETAIL + PADDED_FINGERPRINT_BASE), 'The forensic sample stays a single detail row');
		Assert.isTrue(new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD).isEmpty(), 'A recurring padded key is counted, not refused, so no fallback breadcrumb is written');
	}

	/**
	 * @description Tests that a grouping key filling the event field to its limit is stored under its
	 * SHA-256 hash. The event field and the row field are the same width, so a key the event happily
	 * carries is longer than the field once the `detail:`/`rollup:` prefix is stamped on it, and both
	 * rows would be refused outright. Hashing (rather than truncating) keeps keys that differ only
	 * past the cut apart.
	 */
	@IsTest
	private static void shouldHashAGroupingKeyLongerThanItsStoredFormAllows()
	{
		String expectedBase = UTIL_Crypto.generateSHA256Hash(FIELD_LENGTH_FINGERPRINT);

		Test.startTest();
		EventBus.publish(buildEvent(FIELD_LENGTH_FINGERPRINT));
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.isNotNull(rows.get(PREFIX_DETAIL + expectedBase), 'A key too long for its stored form is hashed to one that fits');
		Assert.areEqual(1, findRollup(rows, expectedBase).OccurrenceCount__c?.intValue(), 'The hashed key counts its first occurrence');
		Assert.isTrue(new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD).isEmpty(), 'A key hashed on arrival fits the field, so no fallback breadcrumb is written');
	}

	/**
	 * @description Tests the compute-level durability fallback: when the presence check cannot run,
	 * the chunk's fingerprinted events persist as ordinary rows instead of being lost. A query
	 * against the fingerprint index can fail in production for reasons this handler cannot influence
	 * — a query timeout, or a query the platform rejects — and a chunk of log events disappearing to
	 * one is exactly the silent loss the fallback exists to prevent.
	 *
	 * Staged by making every LogEntry__c query throw, which is what the aggregation compute cannot
	 * survive. Two events sharing one grouping key are used deliberately: flood control would
	 * collapse them into a single detail row plus a counter, so two plain rows can only mean the
	 * fallback ran and neither event was dropped on the way.
	 */
	@IsTest
	private static void shouldPersistFingerprintedEventsPlainWhenTheAggregationComputeFails()
	{
		TST_Mock.throwsException(LogEntry__c.SObjectType, SIMULATED_QUERY_FAILURE);

		Test.startTest();
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {buildEvent(TEST_FINGERPRINT), buildEvent(TEST_FINGERPRINT)});
		restoreLogEntryQuerying();
		Test.stopTest();

		List<LogEntry__c> rows = new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD);
		Assert.areEqual(2, rows.size(), 'Both fingerprinted events must survive a failed aggregation, one plain row each');
		for(LogEntry__c row : rows)
		{
			Assert.isNull(row.Fingerprint__c, 'A fallback row carries no fingerprint, so it can never trip the unique index');
			Assert.isNull(row.OccurrenceCount__c, 'A fallback row is a forensic row, not a counter');
			Assert.areEqual(TEST_MESSAGE, row.Message__c, 'A fallback row keeps the payload of the event it came from');
		}
		Assert.isTrue(new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD).isEmpty(),
				'The compute fallback writes no flood-control breadcrumb: nothing reached the database to be refused');
	}

	/**
	 * @description Tests that a flood-control row the database rejects persists as a plain row
	 * instead of being lost, that a plain event sharing the same chunk is untouched by the
	 * rejection, and that one WARN breadcrumb quotes the rejection and tallies what was stored
	 * plain. A row is stored under the key for real and the handler is blinded to it, so the database
	 * refuses the duplicate the handler then inserts — a real refusal on the unique index.
	 *
	 * The blind covers the recovery re-read as well as the presence check, because both run off the
	 * one selector, and that is why the outcome asserted here is the PLAIN arm: with the re-read
	 * blinded too, nothing is findable under the refused row's key. A true two-writer race would take
	 * the FOLD arm instead — its winner has committed and IS findable by the time the loser re-reads —
	 * which no single transaction can stage while both reads answer identically (sequenced per-call
	 * mock returns are BACKLOG-1.8 §4).
	 */
	@IsTest
	private static void shouldPersistARefusedRowPlainWhenTheRecoveryReReadFindsNoStoredRow()
	{
		storeDetailRow();
		LogEntryEvent__e racing = buildEvent(DUPLICATE_KEY_FINGERPRINT);
		racing.ClassMethod__c = REFUSED_CLASS_METHOD;
		blindTheFingerprintPresenceCheck();

		Test.startTest();
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {buildEvent(null), racing});
		restoreLogEntryQuerying();
		Test.stopTest();

		Assert.areEqual(1, new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD).size(), 'A plain event must survive a rejected flood-control chunk');

		List<LogEntry__c> recovered = new List<LogEntry__c>();
		for(LogEntry__c row : new SEL_LogEntry().findAllByMethod(REFUSED_CLASS_METHOD))
		{
			if(row.Fingerprint__c == null)
			{
				recovered.add(row);
			}
		}
		Assert.areEqual(1, recovered.size(), 'The rejected flood-control row must persist as a plain row, carrying no fingerprint so it can never collide again');
		Assert.isNull(recovered[0].OccurrenceCount__c, 'A recovered row is a forensic row, not a counter');
		Assert.areEqual(TEST_MESSAGE, recovered[0].Message__c, 'A recovered row keeps the payload of the event it came from');

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.isNotNull(findRollup(rows, DUPLICATE_KEY_FINGERPRINT), 'The rollup row of the same chunk must persist even though its detail twin was rejected');
		Assert.areEqual(STORED_SAMPLE_MESSAGE, rows.get(PREFIX_DETAIL + DUPLICATE_KEY_FINGERPRINT).Message__c,
				'The rejected duplicate must not overwrite the sample already on file');

		LogEntry__c breadcrumb = findSingleBreadcrumb();
		Assert.isTrue(breadcrumb.Message__c.contains(DUPLICATE_VALUE_TEXT), 'The breadcrumb quotes the duplicate-key rejection: ' + breadcrumb.Message__c);
		Assert.isTrue(breadcrumb.Message__c.contains(TALLY_ONE_STORED_PLAIN), 'The breadcrumb tallies what was stored plain: ' + breadcrumb.Message__c);
	}

	/**
	 * @description Tests that the fallback breadcrumb never re-enters the path it is protecting: it
	 * publishes no LogEntryEvent__e, never reaches either engine buffer, and leaves nothing queued
	 * that a later delivery could turn into a second breadcrumb.
	 */
	@IsTest
	private static void shouldNotPublishALogEventWhenTheFloodControlFallbackFires()
	{
		storeDetailRow();
		List<LogEntryEvent__e> events = new List<LogEntryEvent__e> {buildEvent(DUPLICATE_KEY_FINGERPRINT)};
		blindTheFingerprintPresenceCheck();

		Test.startTest();
		Integer publishesBefore = Limits.getPublishImmediateDML();
		TRG_PersistLogEntry.persist(events);
		Integer publishesUsed = Limits.getPublishImmediateDML() - publishesBefore;
		restoreLogEntryQuerying();
		Integer breadcrumbsWhenTheFallbackFired = new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD).size();
		Test.getEventBus().deliver();
		Test.stopTest();

		Assert.areEqual(0, publishesUsed, 'The breadcrumb must never publish a log event back into the persist path');
		Assert.areEqual(0, LOG_Engine.getBufferSize(), 'The breadcrumb must never enter the engine log buffer');
		Assert.areEqual(0, LOG_Engine.getAuditBufferSize(), 'The breadcrumb must never enter the engine audit buffer');
		Assert.areEqual(1, breadcrumbsWhenTheFallbackFired, 'The fallback persists exactly one breadcrumb');
		Assert.areEqual(1, new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD).size(), 'Delivering again must not produce a second breadcrumb');
	}

	/**
	 * @description Stores, for real, the detail row the duplicate-key tests race against.
	 */
	private static void storeDetailRow()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, STORED_SAMPLE_CLASS_METHOD)
				.withOverride(LogEntry__c.Message__c, STORED_SAMPLE_MESSAGE)
				.withOverride(LogEntry__c.LogLevel__c, LoggingLevel.WARN.name())
				.withOverride(LogEntry__c.Fingerprint__c, PREFIX_DETAIL + DUPLICATE_KEY_FINGERPRINT)
				.build();
	}

	/**
	 * @description Hides every stored LogEntry__c row from the handler, so it reports no row under a
	 * key the database does in fact hold. Registering an empty mock list is what blinds the read; the
	 * rows themselves stay stored, so the unique index still refuses the insert — the refusal is real
	 * even though the blindness is staged.
	 *
	 * The blind is not selective: the presence check and the recovery re-read both go through
	 * `findByKey`, so hiding rows from one hides them from the other. A caller therefore gets a
	 * refused row whose key looks unstored on re-read — the PLAIN arm — and cannot reach the FOLD arm
	 * this way. Splitting the two would need sequenced per-call mock returns (BACKLOG-1.8 §4).
	 *
	 * Blindness is the only shape of rejection the framework itself can now produce, malformed keys
	 * being normalized where the stored keys are composed; a subscriber's own validation rule or
	 * trigger on LogEntry__c can still refuse a row for reasons of its own.
	 */
	private static void blindTheFingerprintPresenceCheck()
	{
		TST_Mock.register(LogEntry__c.SObjectType, new List<SObject>());
	}

	/**
	 * @description Restores real LogEntry__c querying so the assertions read the database rather than
	 * whatever a test staged in front of it. Both calls are needed: `TST_Mock.clear` is what drops a
	 * registered query exception, but it re-registers an empty mock list, which still intercepts and
	 * would answer every assertion with no rows — so a null mock list follows, which removes the
	 * registration outright.
	 */
	private static void restoreLogEntryQuerying()
	{
		TST_Mock.clear(LogEntry__c.SObjectType);
		QRY_Builder.setMock(LogEntry__c.SObjectType, null);
	}

	/**
	 * @description Returns the one fallback breadcrumb the persist path is expected to have written,
	 * asserting its identity (exactly one, WARN, the documented opening phrase, a quoted database
	 * error) so each caller asserts only what is specific to its own rejection.
	 *
	 * @return The single breadcrumb row.
	 */
	private static LogEntry__c findSingleBreadcrumb()
	{
		List<LogEntry__c> breadcrumbs = new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD);
		Assert.areEqual(1, breadcrumbs.size(), 'The fallback persists exactly one breadcrumb');
		Assert.areEqual(LoggingLevel.WARN.name(), breadcrumbs[0].LogLevel__c, 'The breadcrumb is a WARN so it surfaces in the problem summary');
		Assert.isNull(breadcrumbs[0].Fingerprint__c, 'The breadcrumb carries no fingerprint, so it can never collide or re-enter flood control');
		Assert.isTrue(breadcrumbs[0].Message__c.startsWith(BREADCRUMB_PREFIX), 'The breadcrumb names the fallback: ' + breadcrumbs[0].Message__c);
		String quotedError = breadcrumbs[0].Message__c.substringAfter(BREADCRUMB_ERROR_SEPARATOR);
		Assert.isTrue(String.isNotBlank(quotedError), 'The breadcrumb quotes the database rejection that caused the fallback: ' + breadcrumbs[0].Message__c);
		return breadcrumbs[0];
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