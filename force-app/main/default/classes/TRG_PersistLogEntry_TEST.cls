// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for TRG_PersistLogEntry trigger action.
 *
 * @see TRG_PersistLogEntry
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date January 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=false)
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
	 * store a row under this key for real, then hide it from the presence check, so the handler
	 * inserts a row the database refuses. That is the state a writer is in when another transaction wins
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
	 * @description Grouping key for the fold-arithmetic test on a detail row, kept apart from the other
	 * duplicate-key tests' keys so no two stored rows ever share a fingerprint.
	 */
	private static final String COUNTED_KEY_FINGERPRINT = 'f1-counted-key';

	/**
	 * @description Grouping key for the fold-arithmetic test on a counter row, kept apart for the same reason.
	 */
	private static final String ROLLUP_KEY_FINGERPRINT = 'f1-rollup-key';

	/**
	 * @description Occurrence count already on the row a refused row folds into: an arbitrary non-zero value, so
	 * a fold that adopted the refused row's empty count or reset the counter to zero would read differently.
	 */
	private static final Integer STORED_OCCURRENCE_COUNT = 7;

	/**
	 * @description Occurrences the refused counter row carries in the counter-row fold test: one event in the chunk.
	 */
	private static final Integer REFUSED_ROLLUP_OCCURRENCES = 1;

	/**
	 * @description Fixed publish instant stamped on the counter-row fold test's event, so the stored counter sits
	 * under the exact rollup key the handler composes for it and the test cannot flake across UTC midnight.
	 */
	private static final String ROLLUP_PUBLISH_INSTANT = '2026-09-04T12:00:00.000Z';

	/**
	 * @description Tally the breadcrumb must carry when the one refused row folded into the row already stored.
	 */
	private static final String TALLY_ONE_FOLDED = '1 folded into the row already stored';

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
	 * @description A grouping key filling `LogEntryEvent__e.Fingerprint__c` to its limit: valid on
	 * the event, and longer than the prefixed `detail:`/`rollup:` key the row is stored under.
	 */
	private static final String FIELD_LENGTH_FINGERPRINT = 'f1-field-length-key'.rightPad(MAXIMUM_EVENT_FINGERPRINT_LENGTH, 'x');

	/**
	 * @description Class/method stamp on the events whose flood-control row the database refuses, so
	 * the rows recovered from them are distinguishable from every other row in their chunk.
	 */
	private static final String REFUSED_CLASS_METHOD = 'TestClass/refusedFloodControlRow';

	/**
	 * @description Class/method the fallback breadcrumb is stamped with. The test sets this value
	 * itself, so it checks the handler's own stamp independently.
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
	 * existing rollup row instead of inserting new rows: the normal path once a fingerprint is known.
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
						TRG_PersistLogEntry.decodeBaseFromRollupKey(rollupKey),
						'Decoding the rollup key strips exactly the prefix and the day suffix, even when the base contains colons'
				);
	}

	/**
	 * @description The origin and the source on the event reach every row the trigger writes: the plain row, the
	 * detail sample and the rollup counter.
	 */
	@IsTest
	private static void shouldCopyOriginAndSourceToEveryRowKind()
	{
		String source = UTIL_Random.randomName();
		String plainClassMethod = UTIL_Random.randomName();
		LogEntryEvent__e plainEvent = buildEvent(null);
		plainEvent.ClassMethod__c = plainClassMethod;
		plainEvent.LogLevel__c = LoggingLevel.ERROR.name();
		plainEvent.Origin__c = LOG_Engine.Origin.FLOW.name();
		plainEvent.Source__c = source;
		LogEntryEvent__e groupedEvent = buildEvent(TEST_FINGERPRINT);
		groupedEvent.Origin__c = LOG_Engine.Origin.COMPONENT.name();
		groupedEvent.Source__c = source;

		Test.startTest();
		EventBus.publish(new List<LogEntryEvent__e> {plainEvent, groupedEvent});
		Test.stopTest();

		LogEntry__c plainRow = new SEL_LogEntry().findByMethod(plainClassMethod);
		Assert.areEqual(LOG_Engine.Origin.FLOW.name(), plainRow.Origin__c, 'The plain row keeps the event\'s origin');
		Assert.areEqual(source, plainRow.Source__c, 'The plain row keeps the event\'s source');

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		LogEntry__c detail = rows.get(PREFIX_DETAIL + TEST_FINGERPRINT);
		Assert.areEqual(LOG_Engine.Origin.COMPONENT.name(), detail.Origin__c, 'The detail sample keeps the origin');
		Assert.areEqual(source, detail.Source__c, 'The detail sample keeps the source');
		LogEntry__c rollup = findRollup(rows, TEST_FINGERPRINT);
		Assert.areEqual(LOG_Engine.Origin.COMPONENT.name(), rollup.Origin__c, 'The rollup counter keeps the origin');
		Assert.areEqual(source, rollup.Source__c, 'The rollup counter keeps the source');
	}

	/**
	 * @description Tests that events without a fingerprint follow the existing plain path
	 * unchanged. This guards that Fingerprint__c and OccurrenceCount__c stay null on that path.
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
	 * @description Tests that an empty chunk persists nothing and consumes no DML. This is the
	 * defensive early-return guard for a no-op delivery.
	 */
	@IsTest
	private static void shouldPersistNothingForEmptyChunk()
	{
		Test.startTest();
		Integer dmlBefore = UTIL_Limits.dmlStatements().used();
		new TRG_PersistLogEntry().afterInsert(new List<SObject>());
		Integer dmlUsed = UTIL_Limits.dmlStatements().used() - dmlBefore;
		Test.stopTest();

		Assert.areEqual(0, dmlUsed, 'An empty chunk must consume no DML');
		Assert.isTrue(new SEL_LogEntry().getAll().isEmpty(), 'An empty chunk must persist no rows');
	}

	/**
	 * @description Checks the governor cost at full chunk scale: 2000 fingerprinted events across
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
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		Integer dmlBefore = UTIL_Limits.dmlStatements().used();
		new TRG_PersistLogEntry().afterInsert(events);
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;
		Integer dmlUsed = UTIL_Limits.dmlStatements().used() - dmlBefore;
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
	 * sent would live under a value no lookup of the key as sent can match. The presence check
	 * would miss it every time and every persist of that key would be refused, permanently. The
	 * assertion that no fallback breadcrumb exists is the point of the test: the rows are never
	 * refused, not merely recovered afterwards.
	 *
	 * Driven through `persist` directly, the entry point `LOG_Engine` uses when a log is emitted
	 * inside an event trigger: there the events are handed over in memory, exactly as the caller
	 * built them, so edge whitespace survives. Publishing would not reproduce it, because the platform
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
		Assert.isTrue
				(
						new SEL_LogEntry().findAllByMethod(BREADCRUMB_CLASS_METHOD).isEmpty(),
						'A recurring padded key is counted, not refused, so no fallback breadcrumb is written'
				);
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
	 * (a query timeout, or a query the platform rejects), and a chunk of log events disappearing to
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
	 * plain. A row is stored under the key for real and hidden from the handler, so the database
	 * refuses the duplicate the handler then inserts: a real refusal on the unique index.
	 *
	 * The rows stay hidden from the recovery re-read as well as the presence check, because both run off
	 * the one selector, and that is why the outcome asserted here is the PLAIN arm: with the rows hidden
	 * from the re-read too, nothing is findable under the refused row's key. A true two-writer race takes the
	 * FOLD arm instead, because the first writer has committed before the refused writer re-reads; the three fold tests
	 * below stage that by hiding the stored rows from the next read only (`hideStoredRowsFromTheNextFingerprintRead`).
	 */
	@IsTest
	private static void shouldPersistARefusedRowPlainWhenTheRecoveryReReadFindsNoStoredRow()
	{
		storeDetailRow();
		LogEntryEvent__e racing = buildEvent(DUPLICATE_KEY_FINGERPRINT);
		racing.ClassMethod__c = REFUSED_CLASS_METHOD;
		hideStoredRowsFromEveryFingerprintRead();

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
	 * @description Tests that a flood-control row the database refuses for a duplicate key folds into the row
	 * already stored under that key instead of taking the chunk down: the stored sample survives untouched, the
	 * stored row keeps no counter (neither side counts), the rollup row of the same chunk persists, and one WARN
	 * breadcrumb quotes the refusal and tallies the fold. Staged as the refused writer in a two-writer race: the row is
	 * stored for real, the row is hidden from the presence check alone (the next read), the insert collides on the
	 * unique index, and the recovery re-read finds the first writer's row in the database. Only a refused insert
	 * writes the breadcrumb. If another read used up the hiding first, this assertion would fail.
	 */
	@IsTest
	private static void shouldFoldARefusedDetailRowIntoTheRowAlreadyStored()
	{
		storeDetailRow();
		hideStoredRowsFromTheNextFingerprintRead();

		Test.startTest();
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {buildEvent(DUPLICATE_KEY_FINGERPRINT)});
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		LogEntry__c storedDetail = rows.get(PREFIX_DETAIL + DUPLICATE_KEY_FINGERPRINT);
		Assert.isNotNull(storedDetail, 'The stored detail row must survive the refused duplicate');
		Assert.areEqual(STORED_SAMPLE_MESSAGE, storedDetail.Message__c, 'The refused duplicate must not overwrite the sample on file');
		Assert.isNull(storedDetail.OccurrenceCount__c, 'Folding a refused detail row into a stored detail row leaves the stored row without a counter');

		LogEntry__c rollup = findRollup(rows, DUPLICATE_KEY_FINGERPRINT);
		Assert.isNotNull(rollup, 'The rollup row must persist even though its detail twin was refused');
		Assert.areEqual(1, rollup.OccurrenceCount__c?.intValue(), 'The refused detail row costs the window no occurrences');

		LogEntry__c breadcrumb = findSingleBreadcrumb();
		Assert.isTrue(breadcrumb.Message__c.contains(DUPLICATE_VALUE_TEXT), 'The breadcrumb quotes the duplicate-key refusal: ' + breadcrumb.Message__c);
		Assert.isTrue(breadcrumb.Message__c.contains(TALLY_ONE_FOLDED), 'The breadcrumb tallies the folded row: ' + breadcrumb.Message__c);
	}

	/**
	 * @description Tests that folding a refused row into a stored row that already counts occurrences leaves that
	 * count exactly as it was: a refused detail row contributes none, so the fold must neither adopt its empty
	 * count nor reset the stored counter to zero. Staged as the detail fold above: the row is stored for real, the
	 * row is hidden from the next read alone, the recovery re-read finds the stored row. The breadcrumb proves the fold path ran.
	 */
	@IsTest
	private static void shouldLeaveAStoredOccurrenceCountUntouchedWhenARefusedDetailRowFoldsIntoIt()
	{
		detailRowBuilder(COUNTED_KEY_FINGERPRINT).withOverride(LogEntry__c.OccurrenceCount__c, STORED_OCCURRENCE_COUNT).build();
		hideStoredRowsFromTheNextFingerprintRead();

		Test.startTest();
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {buildEvent(COUNTED_KEY_FINGERPRINT)});
		Test.stopTest();

		LogEntry__c stored = rowsByFingerprint().get(PREFIX_DETAIL + COUNTED_KEY_FINGERPRINT);
		Assert.isNotNull(stored, 'The stored row must survive the refused duplicate');
		Assert.areEqual(STORED_OCCURRENCE_COUNT, stored.OccurrenceCount__c?.intValue(), 'A refused row that counts nothing must leave the stored count exactly as it was');
		Assert.isTrue(findSingleBreadcrumb().Message__c.contains(TALLY_ONE_FOLDED), 'The breadcrumb tallies the folded row, which only a refused insert produces');
	}

	/**
	 * @description Tests the fold's arithmetic when the collision is on a COUNTER row: a rollup row stored with a
	 * count and a refused rollup insert carrying the chunk's count fold to their sum, so no occurrence is lost to
	 * the race. The stored row sits under the exact key the handler composes for the event's publish instant
	 * (`buildRollupKey` with a fixed instant carried on the event), never a re-derived day suffix. The detail row
	 * of the same chunk has no stored twin and inserts normally. The update path, taken if another read used up the hiding first, also
	 * arrives at the same sum, which is why the breadcrumb, written only for a refused insert, is what proves the fold ran.
	 */
	@IsTest
	private static void shouldSumBothOccurrenceCountsWhenARefusedRollupRowFoldsIntoTheStoredCounter()
	{
		LogEntryEvent__e event = buildEventPublishedAt(ROLLUP_KEY_FINGERPRINT, ROLLUP_PUBLISH_INSTANT);
		String rollupKey = TRG_PersistLogEntry.buildRollupKey(ROLLUP_KEY_FINGERPRINT, event.CreatedDate);
		storedRowBuilder(rollupKey).withOverride(LogEntry__c.OccurrenceCount__c, STORED_OCCURRENCE_COUNT).build();
		hideStoredRowsFromTheNextFingerprintRead();

		Test.startTest();
		TRG_PersistLogEntry.persist(new List<LogEntryEvent__e> {event});
		Test.stopTest();

		Map<String, LogEntry__c> rows = rowsByFingerprint();
		Assert.areEqual(STORED_OCCURRENCE_COUNT + REFUSED_ROLLUP_OCCURRENCES, rows.get(rollupKey).OccurrenceCount__c?.intValue(),
				'The refused rollup row\'s count folds into the stored counter: both operands summed');
		Assert.isNotNull(rows.get(PREFIX_DETAIL + ROLLUP_KEY_FINGERPRINT), 'The detail row of the chunk, with no stored twin, inserts normally');
		LogEntry__c breadcrumb = findSingleBreadcrumb();
		Assert.isTrue(breadcrumb.Message__c.contains(TALLY_ONE_FOLDED), 'The breadcrumb tallies the folded row, which only a refused insert produces: ' + breadcrumb.Message__c);
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
		hideStoredRowsFromEveryFingerprintRead();

		Test.startTest();
		Integer publishesBefore = UTIL_Limits.publishImmediateDml().used();
		TRG_PersistLogEntry.persist(events);
		Integer publishesUsed = UTIL_Limits.publishImmediateDml().used() - publishesBefore;
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
		detailRowBuilder(DUPLICATE_KEY_FINGERPRINT).build();
	}

	/**
	 * @description Builds, but does not yet store, a detail row under the given grouping key, so a caller needing
	 * one more field on it (an occurrence count, say) can add it before storing.
	 *
	 * @param fingerprint The bare grouping key the row is stored under.
	 *
	 * @return The builder for the unstored detail row.
	 */
	private static TST_Builder.Builder detailRowBuilder(String fingerprint)
	{
		return storedRowBuilder(PREFIX_DETAIL + fingerprint);
	}

	/**
	 * @description Builds, but does not yet store, the row the duplicate-key tests race against, under the exact
	 * stored key given: a prefixed detail key, or a rollup key the handler composed.
	 *
	 * @param storedKey The full Fingerprint__c value the row is stored under.
	 *
	 * @return The builder for the unstored row.
	 */
	private static TST_Builder.Builder storedRowBuilder(String storedKey)
	{
		return TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, STORED_SAMPLE_CLASS_METHOD)
				.withOverride(LogEntry__c.Message__c, STORED_SAMPLE_MESSAGE)
				.withOverride(LogEntry__c.LogLevel__c, LoggingLevel.WARN.name())
				.withOverride(LogEntry__c.Fingerprint__c, storedKey);
	}

	/**
	 * @description Hides every stored LogEntry__c row from every read the handler makes, so it reports no
	 * row under a key the database does in fact hold. Registering an empty mock list is what hides the
	 * rows; the rows themselves stay stored, so the unique index still refuses the insert. The refusal is
	 * real even though the hiding is staged.
	 *
	 * The hiding is not selective: the presence check and the recovery re-read both go through
	 * `findByKey`, so hiding rows from one hides them from the other. A caller therefore gets a
	 * refused row whose key looks unstored on re-read, the PLAIN arm. The FOLD arm's tests hide the stored rows from the
	 * next read only (`hideStoredRowsFromTheNextFingerprintRead`).
	 *
	 * A stored row the handler cannot see is the only cause of a refusal the framework itself can now
	 * produce, because malformed keys are normalized where the stored keys are composed; a subscriber's own validation rule or
	 * trigger on LogEntry__c can still refuse a row for reasons of its own.
	 */
	private static void hideStoredRowsFromEveryFingerprintRead()
	{
		TST_Mock.register(LogEntry__c.SObjectType, new List<SObject>());
	}

	/**
	 * @description Hides the stored rows from the handler's NEXT read of LogEntry__c only: the presence check
	 * reports no row under a key the database holds, so the insert is refused for real, and the recovery re-read
	 * then reads the database and finds the stored row. That is what the refused writer sees when the other
	 * writer has already committed. The read sequence this relies on: `findByKey` for the presence check, then
	 * `findByKey` again inside the recovery, with nothing else reading LogEntry__c in between. Only a refused
	 * insert writes a breadcrumb, so if any other read uses up the empty answer queued for it, the fold tests fail on the
	 * breadcrumb instead of passing by the update path.
	 */
	private static void hideStoredRowsFromTheNextFingerprintRead()
	{
		TST_Mock.registerNext(LogEntry__c.SObjectType, new List<SObject>());
	}

	/**
	 * @description Restores real LogEntry__c querying so the assertions read the database rather than whatever a
	 * test staged in front of it: `TST_Mock.clear` removes the registration outright and drops any registered
	 * query exception.
	 */
	private static void restoreLogEntryQuerying()
	{
		TST_Mock.clear(LogEntry__c.SObjectType);
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
	 * @description Builds an event under the suite's default grouping key whose read-only CreatedDate is pre-set.
	 *
	 * @param publishInstant The ISO 8601 UTC instant to stamp as the event publish time.
	 *
	 * @return The unpublished event carrying the pre-set CreatedDate.
	 */
	private static LogEntryEvent__e buildEventPublishedAt(String publishInstant)
	{
		return buildEventPublishedAt(TEST_FINGERPRINT, publishInstant);
	}

	/**
	 * @description Builds a fingerprinted event whose read-only CreatedDate is pre-set via a JSON
	 * round-trip. Serializing a real event emits context-correct field API names (namespace-prefixed
	 * in a managed install), so the payload never hardcodes a field-name literal; CreatedDate is a
	 * standard field and carries no prefix in any context.
	 *
	 * @param fingerprint The grouping key to stamp on the event.
	 * @param publishInstant The ISO 8601 UTC instant to stamp as the event publish time.
	 *
	 * @return The unpublished event carrying the pre-set CreatedDate.
	 */
	private static LogEntryEvent__e buildEventPublishedAt(String fingerprint, String publishInstant)
	{
		Map<String, Object> raw = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(buildEvent(fingerprint)));
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
	 * environment-fragile. A doubling regression still fails this count because doubled rows share
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