// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for SEL_LogEntry selector.
 *
 * @see SEL_LogEntry
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class SEL_LogEntry_TEST
{
	/**
	 * @description The class method name used in test log records.
	 */
	private static final String TEST_CLASS_METHOD = 'SEL_LogEntry_TEST/shouldFindByMethod';

	/**
	 * @description Company name that identifies the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_LogEntry_TEST-admin';

	/**
	 * @description Company name that identifies the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the low-privilege tests.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_LogEntry_TEST-low-privilege';

	/**
	 * @description Base fingerprint (without the detail:/rollup: prefix) for the seeded NullPointer problem.
	 */
	private static final String BASE_NULL_POINTER = 'NullPointer:AccountTriggerHandler.handleAfterUpdate';

	/**
	 * @description A second, distinct base fingerprint so multi-signature reads can be asserted.
	 */
	private static final String BASE_OTHER = 'NullPointer:OpportunityService.recalculate';

	/**
	 * @description Emitting-user Id (UserId__c) stamped on seeded sample rows: a generated mock
	 * User Id, never a hardcoded literal.
	 */
	private static final String SEED_USER_ID = UTIL_Random.randomId(User.SObjectType);

	/**
	 * @description A second, distinct generated mock User Id so the UserId__c filter axis can be asserted.
	 */
	private static final String OTHER_USER_ID = UTIL_Random.randomId(User.SObjectType);

	/**
	 * @description A correlation id (CorrelationId__c, a domain value) used to assert the correlation
	 * filter axis.
	 */
	private static final String SEED_CORRELATION_ID = 'log-console-test-correlation';

	/**
	 * @description The correlation id shared by the seeded hops of one logical operation, used to assert
	 * the ordered correlated-trace read.
	 */
	private static final String TRACE_CORRELATION_ID = 'log-console-trace-correlation';

	/**
	 * @description A second, distinct correlation id so the correlated-trace read can be shown to exclude
	 * rows belonging to a different operation.
	 */
	private static final String OTHER_TRACE_CORRELATION_ID = 'log-console-other-correlation';

	/**
	 * @description The tracking id of a seeded action: the root every entry of the action carries, and the correlation of
	 * the entries the action wrote itself.
	 */
	private static final String ACTION_ROOT_ID = UTIL_Random.randomUUID();

	/**
	 * @description The tracking id of a run the seeded action launched; its entries carry it as their correlation and the
	 * action's id as their root.
	 */
	private static final String ACTION_RUN_ID = UTIL_Random.randomUUID();

	/**
	 * @description The tracking id of an action recorded before roots were written: its entries carry it as their
	 * correlation and no root at all.
	 */
	private static final String LEGACY_ACTION_ID = UTIL_Random.randomUUID();

	/**
	 * @description The tracking id of an unrelated action, seeded beside the one under test so a scoped read can be shown
	 * to exclude it.
	 */
	private static final String OTHER_ACTION_ID = UTIL_Random.randomUUID();

	/**
	 * @description The short message the scoped-search test looks for; one row inside the action and one outside carry it.
	 */
	private static final String SCOPED_SEARCH_NEEDLE = 'scoped needle';

	/**
	 * @description The term the scoped body-search test looks for; one row inside the action and one outside carry it, so
	 * the action clause in the SOSL RETURNING WHERE is what separates them.
	 */
	private static final String SOSL_SCOPED_NEEDLE = 'action body needle';

	/**
	 * @description The exception type folded into the primary derived signature in the fold tests.
	 */
	private static final String DERIVED_EXCEPTION_NPE = 'System.NullPointerException';

	/**
	 * @description A second, distinct exception type so a second derived signature can be asserted.
	 */
	private static final String DERIVED_EXCEPTION_DML = 'System.DmlException';

	/**
	 * @description The Class.method folded into the primary derived signature.
	 */
	private static final String DERIVED_METHOD_ACCOUNT = 'AccountTriggerHandler.handleAfterUpdate';

	/**
	 * @description A second, distinct Class.method for the second derived signature.
	 */
	private static final String DERIVED_METHOD_OPPORTUNITY = 'OpportunityService.recalculate';

	/**
	 * @description The throw-site line number stamped on the seeded rows of the primary signature. It is kept on
	 * the row but not part of the grouping key (Number fields are not groupable in SOQL).
	 */
	private static final Integer DERIVED_LINE_ACCOUNT = 142;

	/**
	 * @description A second, distinct throw-site line number, used both for the second signature's rows and
	 * to prove that rows at different lines fold into one signature.
	 */
	private static final Integer DERIVED_LINE_OPPORTUNITY = 88;

	/**
	 * @description The ShortMessage__c surfaced as the primary derived signature's label (MAX ShortMessage__c).
	 */
	private static final String DERIVED_LABEL_NPE = 'Attempt to de-reference a null object';

	/**
	 * @description The ShortMessage__c surfaced as the second derived signature's label.
	 */
	private static final String DERIVED_LABEL_DML = 'Insert failed: a required field is missing';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the low-privilege tests (shouldFindByMethodForLowPrivilegeUser and the others) can use System.runAs
	 * against either without triggering MIXED_DML_OPERATION. User is a Setup object, so User DML
	 * cannot mix with standard/custom-object DML in the same transaction; pre-provisioning here
	 * satisfies that boundary.
	 *
	 * Only the low-privilege tests use these users. The other SEL_LogEntry tests run as the
	 * @IsTest running user without runAs.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests that findByMethod returns a matching log record.
	 */
	@IsTest
	private static void shouldFindByMethod()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.build();

		LogEntry__c result = new SEL_LogEntry().findByMethod(TEST_CLASS_METHOD);

		Assert.isNotNull(result, 'Should return matching log record');
		Assert.areEqual(TEST_CLASS_METHOD, result.ClassMethod__c, 'Should match the class method');
	}

	/**
	 * @description Tests that findAllByMethod returns all matching log records.
	 */
	@IsTest
	private static void shouldFindAllByMethod()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withCount(2)
				.buildList();

		List<LogEntry__c> results = new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD);

		Assert.areEqual(2, results.size(), 'Should return all matching records');
	}

	/**
	 * @description Tests that findPerformanceLogByMethod returns the log whose
	 * ShortMessage contains the performance needle.
	 */
	@IsTest
	private static void shouldFindPerformanceLogByShortMessage()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withOverride(LogEntry__c.ShortMessage__c, 'My op completed in 42ms')
				.build();

		LogEntry__c result = new SEL_LogEntry().findPerformanceLogByMethod(TEST_CLASS_METHOD);

		Assert.isNotNull(result, 'Should match on ShortMessage');
	}

	/**
	 * @description Tests that findPerformanceLogByMethod also matches when the needle
	 * is only in the Message field (ShortMessage can be blank).
	 */
	@IsTest
	private static void shouldFindPerformanceLogByMessage()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withOverride(LogEntry__c.Message__c, 'My op completed in 42ms')
				.build();

		LogEntry__c result = new SEL_LogEntry().findPerformanceLogByMethod(TEST_CLASS_METHOD);

		Assert.isNotNull(result, 'Should match on Message when ShortMessage is blank');
	}

	/**
	 * @description Tests that findPerformanceLogByMethod returns null when no log for
	 * the given method contains the performance needle.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoPerformanceNeedleMatches()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withOverride(LogEntry__c.ShortMessage__c, 'Unrelated message')
				.build();

		LogEntry__c result = new SEL_LogEntry().findPerformanceLogByMethod(TEST_CLASS_METHOD);

		Assert.isNull(result, 'Should return null when no log contains the needle');
	}

	/**
	 * @description Tests that findByLogLevel returns matching log records.
	 */
	@IsTest
	private static void shouldFindByLogLevel()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, 'Error')
				.build();

		List<LogEntry__c> results = new SEL_LogEntry().findByLogLevel('Error');

		Assert.isFalse(results.isEmpty(), 'Should return matching log records');
	}

	/**
	 * @description Tests that getRecordCount returns the correct count.
	 */
	@IsTest
	private static void shouldGetRecordCount()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withCount(3)
				.buildList();

		Integer result = new SEL_LogEntry().getRecordCount();

		Assert.areEqual(3, result, 'Should return count of 3');
	}

	/**
	 * @description Tests that getAll returns records within a test context.
	 */
	@IsTest
	private static void shouldGetAll()
	{
		TST_Builder.of(LogEntry__c.SObjectType).build();

		List<LogEntry__c> results = new SEL_LogEntry().getAll();

		Assert.isFalse(results.isEmpty(), 'Should return records in test context');
	}

	/**
	 * @description Tests that `findAllOrderedByCreatedDateDesc` returns records ordered by CreatedDate
	 * descending in test context. Bypass-audit and performance-log assertions rely on this ordering
	 * so the first match in iteration is the most-recent emission.
	 */
	@IsTest
	private static void shouldFindAllOrderedByCreatedDateDesc()
	{
		TST_Builder.of(LogEntry__c.SObjectType).withCount(3).buildList();

		List<LogEntry__c> results = new SEL_LogEntry().findAllOrderedByCreatedDateDesc();

		Assert.isFalse(results.isEmpty(), 'Should return records in test context');
		for(Integer i = 1; i < results.size(); i++)
		{
			Assert.isTrue(results[i - 1].CreatedDate >= results[i].CreatedDate,
					'Records must be ordered CreatedDate descending so first match is most-recent');
		}
	}

	/**
	 * @description Tests that `parseContextDataForTest` returns the inner context map when the
	 * envelope is well-formed JSON wrapping a `contextData` key.
	 */
	@IsTest
	private static void shouldParseContextDataEnvelopeForTest()
	{
		LogEntry__c entry = new LogEntry__c(ContextData__c = '{"contextData":{"surface":"query","action":"BYPASS"}}');

		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);

		Assert.isNotNull(context, 'Should unwrap the contextData envelope');
		Assert.areEqual('query', context.get('surface'), 'Should expose the surface key');
		Assert.areEqual('BYPASS', context.get('action'), 'Should expose the action key');
	}

	/**
	 * @description Tests that `parseContextDataForTest` returns null for a null entry, a null
	 * `ContextData__c`, or a blank `ContextData__c`. Centralised null-handling lets test helpers
	 * skip per-call guards.
	 */
	@IsTest
	private static void shouldReturnNullForNullOrBlankContextData()
	{
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(null), 'Should return null for null entry');
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(new LogEntry__c()), 'Should return null for null ContextData__c');
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(new LogEntry__c(ContextData__c = '')), 'Should return null for blank ContextData__c');
	}

	/**
	 * @description Tests that findByFingerprints returns only rows whose Fingerprint__c is in
	 * the requested set, and an empty list for blank input. This checks the selector's promise to callers.
	 */
	@IsTest
	private static void shouldFindRowsByFingerprintKeys()
	{
		LogEntry__c matching = new LogEntry__c(Fingerprint__c = TRG_PersistLogEntry.PREFIX_DETAIL + 'selector-test-key', LogLevel__c = 'WARN');
		LogEntry__c other = new LogEntry__c(Fingerprint__c = TRG_PersistLogEntry.PREFIX_DETAIL + 'selector-other-key', LogLevel__c = 'WARN');
		DML_Builder.newTransaction().systemModeInternal().doInsert(new List<LogEntry__c> {matching, other}).execute();

		Test.startTest();
		List<LogEntry__c> found = new SEL_LogEntry().findByFingerprints(new Set<String> {TRG_PersistLogEntry.PREFIX_DETAIL + 'selector-test-key'});
		List<LogEntry__c> none = new SEL_LogEntry().findByFingerprints(new Set<String>());
		Test.stopTest();

		Assert.areEqual(1, found.size(), 'Exactly the matching fingerprint row should return');
		Assert.areEqual(TRG_PersistLogEntry.PREFIX_DETAIL + 'selector-test-key', found[0].Fingerprint__c, 'Returned row should carry the requested key');
		Assert.isTrue(none.isEmpty(), 'Empty input set should return an empty list without querying');
	}

	/**
	 * @description Low-privilege test: proves SEL_LogEntry.findByMethod returns rows when
	 * invoked by a subscriber user on the Minimum Access - Salesforce profile who has no FLS on
	 * kern__LogEntry__c. The framework-owned selector declares `systemModeRequired() = true`, so
	 * its internal QRY_Builder must elevate to SYSTEM_MODE and the query must return the seeded
	 * rows regardless of the running user's FLS.
	 *
	 * The low-privilege user saves the log entry, so they own it. Log entries are private records, and this test is about
	 * field access, not about who may see another user's entry.
	 *
	 * Catches: a future refactor that demotes SEL_LogEntry.systemModeRequired() to false, or
	 * deletes the override entirely, would cause the low-privilege user's query to fail with "No
	 * such column: kern__ClassMethod__c". This test fails at 2GP validated-build time rather than
	 * at subscriber scratch-org time.
	 *
	 * Why findByMethod: the selector has no `findByCorrelationId(id)` method. `findByMethod` covers the same elevation-via-systemModeRequired
	 * regression surface since both go through the shared SEL_Base.query property.
	 *
	 * @see SEL_LogEntry.findByMethod
	 * @see SEL_LogEntry.systemModeRequired
	 */
	@IsTest
	private static void shouldFindByMethodForLowPrivilegeUser()
	{
		final String classMethod = 'SEL_LogEntry_TEST/shouldFindByMethodForLowPrivilegeUser';

		System.runAs(getLowPrivilegeUser())
		{
			TST_Builder.of(LogEntry__c.SObjectType)
					.withOverride(LogEntry__c.ClassMethod__c, classMethod)
					.build();

			LogEntry__c result = new SEL_LogEntry().findByMethod(classMethod);

			Assert.isNotNull(result, 'Should find the seeded LogEntry__c for low-privilege caller');
			Assert.areEqual(classMethod, result.ClassMethod__c, 'ClassMethod__c should match the seeded value');
		}
	}

	/**
	 * @description Tests that findSamplesByBaseFingerprints returns exactly the requested detail:
	 * sample rows by exact key, ignores plain and rollup: rows, and short-circuits to an empty list
	 * for a blank input set. The distinct-problems driver fetches samples by key, never by a date
	 * window, so this read is deliberately window-free.
	 */
	@IsTest
	private static void shouldFetchSamplesByBaseFingerprints()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 17, 23);
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_WARN, 4, 9);
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ShortMessage__c, 'a plain forensic row')
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_ROLLUP + 'NullPointer:Orphan.method:' + UTIL_Date.toUtcDayBucket(Datetime.now()))
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.OccurrenceCount__c, 3)
				.build();

		Set<String> detailKeys = new Set<String> {TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER};

		Test.startTest();
		List<LogEntry__c> sampleRows = new SEL_LogEntry().findSamplesByBaseFingerprints(detailKeys);
		List<LogEntry__c> emptyResult = new SEL_LogEntry().findSamplesByBaseFingerprints(new Set<String>());
		Test.stopTest();

		Assert.areEqual(2, sampleRows.size(), 'Exactly the two requested detail: samples should return');
		Set<String> returnedFingerprints = new Set<String>();
		for(LogEntry__c sampleRow : sampleRows)
		{
			returnedFingerprints.add(sampleRow.Fingerprint__c);
		}
		Assert.isTrue(returnedFingerprints.contains(TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER), 'The NPE sample should be returned by exact key');
		Assert.isTrue(returnedFingerprints.contains(TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER), 'The OTHER sample should be returned by exact key');
		Assert.isTrue(emptyResult.isEmpty(), 'A blank key set should short-circuit to an empty list without querying');
	}

	/**
	 * @description Tests that findRollupRowsInWindow returns only the rollup: counter rows, each
	 * carrying a non-null OccurrenceCount__c that matches the seeded values.
	 */
	@IsTest
	private static void shouldReturnRollupRowsInWindow()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 17, 23);

		Test.startTest();
		List<LogEntry__c> rollupRows = new SEL_LogEntry().findRollupRowsInWindow(new SEL_LogEntry.BrowseCriteria(), 2000);
		Test.stopTest();

		Assert.areEqual(2, rollupRows.size(), 'Both rollup: rows should return; the detail: sample is excluded');
		Set<Decimal> occurrenceCounts = new Set<Decimal>();
		for(LogEntry__c rollupRow : rollupRows)
		{
			Assert.isTrue(rollupRow.Fingerprint__c.startsWith(TRG_PersistLogEntry.PREFIX_ROLLUP), 'Only rollup: rows should return');
			Assert.isNotNull(rollupRow.OccurrenceCount__c, 'Each rollup row should carry OccurrenceCount__c');
			occurrenceCounts.add(rollupRow.OccurrenceCount__c);
		}
		Assert.isTrue(occurrenceCounts.contains(17) && occurrenceCounts.contains(23), 'The seeded occurrence counts should round-trip');
	}

	/**
	 * @description Tests that findRollupRowsInWindow fetches one probe row beyond the requested maximum,
	 * so a caller can tell an exactly-filled candidate set from an overflowed one, and that a candidate
	 * set at the maximum returns only its own rows (no probe row exists to fetch).
	 */
	@IsTest
	private static void shouldFetchOneProbeRowBeyondRollupMaximum()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 17, 23);
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_ERROR, 5, 7);

		Test.startTest();
		List<LogEntry__c> overflowed = new SEL_LogEntry().findRollupRowsInWindow(new SEL_LogEntry.BrowseCriteria(), 2);
		List<LogEntry__c> exactlyFilled = new SEL_LogEntry().findRollupRowsInWindow(new SEL_LogEntry.BrowseCriteria(), 4);
		Test.stopTest();

		Assert.areEqual(3, overflowed.size(), 'Four in-window rollup rows at a maximum of two should fetch the probe row: two candidates plus one');
		Assert.areEqual(4, exactlyFilled.size(), 'Four in-window rollup rows at a maximum of four should return exactly the four rows, with no fifth to probe');
	}

	/**
	 * @description Low-privilege test: the all-entries ribbon aggregate (summariseEntriesInWindow) counts every user's
	 * entries for a Minimum Access user with no field access on kern__LogEntry__c. Log entries are Private and the test
	 * administrator owns the seeded rows, so the read must waive field-level security (SYSTEM_MODE) and record sharing
	 * (bypassSharingInternal()). The by-id aggregate below reads the same way.
	 */
	@IsTest
	private static void shouldAggregateWindowForLowPrivilegeUser()
	{
		System.runAs(getTestAdmin())
		{
			seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 3);
		}

		System.runAs(getLowPrivilegeUser())
		{
			SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesInWindow(new SEL_LogEntry.BrowseCriteria(), 200);

			Integer total = 0;
			for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
			{
				total += levelCount.rowCount;
			}
			Assert.areEqual(3, total, 'A low-privilege caller should still fold every framework-owned forensic row under bypassSharingInternal()');
		}
	}

	/**
	 * @description Low-privilege test: the by-id ribbon aggregate (summariseEntriesByIds) counts every entry it is given
	 * for a Minimum Access user with no field access on kern__LogEntry__c. Log entries are Private and the test
	 * administrator owns the seeded rows, so the read must waive field-level security (SYSTEM_MODE) and record sharing
	 * (bypassSharingInternal()), as the windowed aggregate above does.
	 */
	@IsTest
	private static void shouldAggregateByIdsForLowPrivilegeUser()
	{
		Set<Id> seededIds = new Set<Id>();
		System.runAs(getTestAdmin())
		{
			seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 3);
			for(LogEntry__c row : new SEL_LogEntry().getAll())
			{
				seededIds.add(row.Id);
			}
		}

		System.runAs(getLowPrivilegeUser())
		{
			SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesByIds(seededIds, 200);

			Integer total = 0;
			for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
			{
				total += levelCount.rowCount;
			}
			Assert.areEqual(3, total, 'A low-privilege caller should still fold every supplied framework-owned row under bypassSharingInternal()');
		}
	}

	/**
	 * @description Tests that findEntriesFiltered returns the forensic rows (detail samples and
	 * plain rows) but never the rollup: counter rows, which are excluded by the OccurrenceCount__c
	 * is-null condition, and that totalRecords reflects that filtered count.
	 */
	@IsTest
	private static void shouldExcludeRollupRowsFromEntriesView()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 17, 23);
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ShortMessage__c, 'a plain forensic row')
				.build();

		Test.startTest();
		QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(new SEL_LogEntry.BrowseCriteria(), LogEntry__c.CreatedDate, true, 1, 50);
		Test.stopTest();

		Assert.areEqual(2, page.totalRecords, 'Only the detail sample and the plain row should count; both rollups excluded');
		for(LogEntry__c entry : (List<LogEntry__c>)page.records)
		{
			Assert.isNull(entry.OccurrenceCount__c, 'No rollup: counter row should appear in the entries view');
		}
	}

	/**
	 * @description Tests that findEntriesFiltered pages the forensic rows server-side: a page size of
	 * two over five rows yields a two-row first page, a total of five, three pages, and hasMorePages true.
	 */
	@IsTest
	private static void shouldPaginateEntries()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withCount(5)
				.buildList();

		Test.startTest();
		QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(new SEL_LogEntry.BrowseCriteria(), LogEntry__c.CreatedDate, true, 1, 2);
		Test.stopTest();

		Assert.areEqual(2, page.records.size(), 'The first page should hold exactly the page size');
		Assert.areEqual(5, page.totalRecords, 'Total should be the full filtered count');
		Assert.areEqual(3, page.totalPages, 'Five rows at two per page is three pages');
		Assert.isTrue(page.hasMorePages, 'Page one of three should report more pages');
	}

	/**
	 * @description Tests that findByIdForConsole returns the single row for the detail pane with
	 * CreatedDate and the heavy Limits__c field selected, so the detail-pane reads never throw an
	 * SObjectException at runtime (the jest-passes/runtime-throws trap).
	 */
	@IsTest
	private static void shouldFindByIdForConsole()
	{
		LogEntry__c detailRow = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'Attempt to de-reference a null object')
				.withOverride(LogEntry__c.Limits__c, '\nQueries: 4 of 100\nCpu Time: 1543 of 10000')
				.build();

		Test.startTest();
		LogEntry__c foundEntry = new SEL_LogEntry().findByIdForConsole(detailRow.Id);
		Test.stopTest();

		Assert.isNotNull(foundEntry, 'The row should be found by Id');
		Assert.areEqual(detailRow.Id, foundEntry.Id, 'The returned row should be the requested one');
		Assert.isNotNull(foundEntry.CreatedDate, 'CreatedDate must be selected for the detail pane');
		Assert.isTrue(foundEntry.Limits__c?.contains('Cpu Time: 1543 of 10000') == true,
				'Limits__c must be selected and carry the seeded limit lines so the governor-limit bars can render');
	}

	/**
	 * @description Tests that findByCorrelationIdOrdered returns exactly the forensic rows sharing the
	 * given CorrelationId__c, ordered by CreatedDate ascending, and excludes both the rollup: counter
	 * rows (OccurrenceCount__c non-null) and rows carrying a different correlation. A blank correlation
	 * short-circuits to an empty list without querying.
	 */
	@IsTest
	private static void shouldFindByCorrelationIdOrdered()
	{
		LogEntry__c firstHop = seedCorrelatedHop(BASE_NULL_POINTER, 'AccountTriggerHandler.handleAfterUpdate', TRACE_CORRELATION_ID, Datetime.now().addMinutes(-3));
		LogEntry__c secondHop = seedCorrelatedHop(BASE_OTHER, 'OpportunityService.recalculate', TRACE_CORRELATION_ID, Datetime.now().addMinutes(-2));
		LogEntry__c thirdHop = seedCorrelatedHop('NullPointer:NotificationService.send', 'NotificationService.send', TRACE_CORRELATION_ID, Datetime.now().addMinutes(-1));
		seedCorrelatedHop('NullPointer:Unrelated.run', 'Unrelated.run', OTHER_TRACE_CORRELATION_ID, Datetime.now().addMinutes(-2));
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_ROLLUP + BASE_NULL_POINTER + ':' + UTIL_Date.toUtcDayBucket(Datetime.now()))
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.OccurrenceCount__c, 5)
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.build();

		Test.startTest();
		List<LogEntry__c> trace = new SEL_LogEntry().findByCorrelationIdOrdered(TRACE_CORRELATION_ID);
		List<LogEntry__c> blankResult = new SEL_LogEntry().findByCorrelationIdOrdered('   ');
		Test.stopTest();

		Assert.areEqual(3, trace.size(), 'Exactly the three forensic hops sharing the correlation should return; the rollup and the unrelated row are excluded');
		Assert.areEqual(firstHop.Id, trace[0].Id, 'The earliest hop should sort first (CreatedDate ascending)');
		Assert.areEqual(secondHop.Id, trace[1].Id, 'The middle hop should sort second');
		Assert.areEqual(thirdHop.Id, trace[2].Id, 'The latest hop should sort last');
		for(LogEntry__c hop : trace)
		{
			Assert.isNull(hop.OccurrenceCount__c, 'No rollup: counter row should appear in a correlated trace');
		}
		Assert.isTrue(blankResult.isEmpty(), 'A blank correlation id should short-circuit to an empty list');
	}

	/**
	 * @description Tests that findByCorrelationIdOrdered bounds the correlated trace at the row cap plus one,
	 * so a pathological correlation cannot return an unbounded result set and the controller can detect the
	 * overflow by the one extra row.
	 */
	@IsTest
	private static void shouldCapCorrelatedTraceAtTheRowCap()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ClassMethod__c, 'AccountTriggerHandler.handleAfterUpdate')
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.withCount(SEL_LogEntry.CORRELATION_TRACE_ROW_CAP + 5)
				.buildList();

		Test.startTest();
		List<LogEntry__c> trace = new SEL_LogEntry().findByCorrelationIdOrdered(TRACE_CORRELATION_ID);
		Test.stopTest();

		Assert.areEqual
				(
						SEL_LogEntry.CORRELATION_TRACE_ROW_CAP + 1, trace.size(),
						'The correlated-trace query fetches at most the row cap plus one, so the controller can detect overflow'
				);
	}

	/**
	 * @description The action scope lists the action's own entries and the entries of every run launched under it, and
	 * nothing else: rows whose root is the action's id or whose correlation is the action's id.
	 */
	@IsTest
	private static void shouldScopeTheEntriesPageToTheWholeAction()
	{
		LogEntry__c ownEntry = seedScopedEntry(ACTION_ROOT_ID, ACTION_ROOT_ID, 'the action itself', Datetime.now().addMinutes(-3));
		LogEntry__c runEntry = seedScopedEntry(ACTION_RUN_ID, ACTION_ROOT_ID, 'a step of the run', Datetime.now().addMinutes(-2));
		seedScopedEntry(OTHER_ACTION_ID, OTHER_ACTION_ID, 'another action', Datetime.now().addMinutes(-1));

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.rootCorrelationId = ACTION_ROOT_ID;

		Test.startTest();
		QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(criteria, LogEntry__c.CreatedDate, false, 1, 50);
		Test.stopTest();

		Set<Id> returnedIds = new Map<Id, SObject>(page.records).keySet();
		Assert.areEqual(2, page.totalRecords, 'The scope holds the action\'s own entry and its run\'s entry');
		Assert.isTrue(returnedIds.contains(ownEntry.Id), 'The entry the action wrote itself is inside the scope');
		Assert.isTrue(returnedIds.contains(runEntry.Id), 'The entry of a run launched under the action is inside the scope');
	}

	/**
	 * @description An action recorded before roots were written has entries with no root; the scope finds them by
	 * correlation, so a legacy action is reachable by its id alone.
	 */
	@IsTest
	private static void shouldScopeALegacyActionByItsCorrelationAlone()
	{
		LogEntry__c legacyEntry = seedScopedEntry(LEGACY_ACTION_ID, null, 'recorded before roots', Datetime.now().addMinutes(-3));
		seedScopedEntry(OTHER_ACTION_ID, OTHER_ACTION_ID, 'another action', Datetime.now().addMinutes(-1));

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.rootCorrelationId = LEGACY_ACTION_ID;

		Test.startTest();
		QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(criteria, LogEntry__c.CreatedDate, false, 1, 50);
		Test.stopTest();

		Assert.areEqual(1, page.totalRecords, 'A rootless entry is found through the correlation half of the scope');
		Assert.areEqual(legacyEntry.Id, page.records[0].Id, 'The legacy entry is the one row in scope');
	}

	/**
	 * @description A search term typed while the console is filtered to one action searches inside that action: the SOQL search leg keeps
	 * the scope, so a matching row outside the action is not returned.
	 */
	@IsTest
	private static void shouldSearchInsideTheActionScope()
	{
		LogEntry__c insideRow = seedScopedEntry(ACTION_RUN_ID, ACTION_ROOT_ID, SCOPED_SEARCH_NEEDLE, Datetime.now().addMinutes(-2));
		seedScopedEntry(OTHER_ACTION_ID, OTHER_ACTION_ID, SCOPED_SEARCH_NEEDLE, Datetime.now().addMinutes(-1));

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.rootCorrelationId = ACTION_ROOT_ID;

		Test.startTest();
		Set<Id> matchedIds = new SEL_LogEntry().findIdsBySearch(SCOPED_SEARCH_NEEDLE, criteria, 100);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {insideRow.Id}, matchedIds, 'Only the matching row inside the action is returned');
	}

	/**
	 * @description The action's first and last entries are read without a date window: a row ten days old is the first
	 * entry however narrow the list's range is, and the newest row is the last.
	 */
	@IsTest
	private static void shouldFindTheFirstAndLastEntriesOfAnActionWithoutAWindow()
	{
		LogEntry__c oldest = seedScopedEntry(ACTION_ROOT_ID, ACTION_ROOT_ID, 'the action started', Datetime.now().addDays(-10));
		seedScopedEntry(ACTION_RUN_ID, ACTION_ROOT_ID, 'a step in between', Datetime.now().addDays(-5));
		LogEntry__c newest = seedScopedEntry(ACTION_RUN_ID, ACTION_ROOT_ID, 'the last step', Datetime.now().addMinutes(-1));
		seedScopedEntry(OTHER_ACTION_ID, OTHER_ACTION_ID, 'another action, even older', Datetime.now().addDays(-20));

		Test.startTest();
		LogEntry__c first = new SEL_LogEntry().findFirstInScope(ACTION_ROOT_ID);
		LogEntry__c last = new SEL_LogEntry().findLastInScope(ACTION_ROOT_ID);
		Test.stopTest();

		Assert.areEqual(oldest.Id, first.Id, 'The first entry is the oldest row in scope, outside any list window');
		Assert.areEqual(newest.Id, last.Id, 'The last entry is the newest row in scope');
		Assert.isNotNull(first.CreatedDate, 'The edge reads select CreatedDate for the banner');
		Assert.isNull(new SEL_LogEntry().findFirstInScope(null), 'A blank id reads nothing');
		Assert.isNull(new SEL_LogEntry().findLastInScope(UTIL_Random.randomUUID()), 'An id with no entries reads nothing');
	}

	/**
	 * @description The ribbon's count and its summary read the same scope the list does, so the numbers under an action
	 * pill describe the action.
	 */
	@IsTest
	private static void shouldCountAndSummariseEntriesUnderTheActionScope()
	{
		seedScopedEntry(ACTION_ROOT_ID, ACTION_ROOT_ID, 'the action itself', Datetime.now().addMinutes(-3));
		seedScopedEntry(ACTION_RUN_ID, ACTION_ROOT_ID, 'a step of the run', Datetime.now().addMinutes(-2));
		seedScopedEntry(OTHER_ACTION_ID, OTHER_ACTION_ID, 'another action', Datetime.now().addMinutes(-1));

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.rootCorrelationId = ACTION_ROOT_ID;
		criteria.windowStart = Datetime.now().addDays(-1);
		criteria.windowEnd = Datetime.now();

		Test.startTest();
		Integer counted = new SEL_LogEntry().countEntriesInWindow(criteria);
		SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesInWindow(criteria, 200);
		Test.stopTest();

		Integer summarised = 0;
		for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
		{
			summarised += levelCount.rowCount;
		}
		Assert.areEqual(2, counted, 'The count covers the two rows in scope');
		Assert.areEqual(2, summarised, 'The per-level summary covers the same two rows');
	}

	/**
	 * @description One indexed read answers what a tracking id is: for an action's id the returned row carries it as its
	 * root, for a run's id the row carries it as its correlation beside the action's root, for a legacy action's id the row
	 * carries it as its correlation with no root, and an unknown or blank id reads nothing.
	 */
	@IsTest
	private static void shouldReturnTheRootAndCorrelationOfOneEntryForATrackingId()
	{
		seedScopedEntry(ACTION_ROOT_ID, ACTION_ROOT_ID, 'the action itself', Datetime.now().addMinutes(-3));
		seedScopedEntry(ACTION_RUN_ID, ACTION_ROOT_ID, 'a step of the run', Datetime.now().addMinutes(-2));
		seedScopedEntry(LEGACY_ACTION_ID, null, 'recorded before roots', Datetime.now().addMinutes(-1));

		Test.startTest();
		LogEntry__c byRoot = new SEL_LogEntry().findOneByRootOrCorrelation(ACTION_ROOT_ID);
		LogEntry__c byRun = new SEL_LogEntry().findOneByRootOrCorrelation(ACTION_RUN_ID);
		LogEntry__c byLegacy = new SEL_LogEntry().findOneByRootOrCorrelation(LEGACY_ACTION_ID);
		LogEntry__c unknown = new SEL_LogEntry().findOneByRootOrCorrelation(UTIL_Random.randomUUID());
		LogEntry__c blank = new SEL_LogEntry().findOneByRootOrCorrelation(' ');
		Test.stopTest();

		Assert.areEqual(ACTION_ROOT_ID, byRoot.RootCorrelationId__c, 'An action\'s id comes back as the root of a matching row');
		Assert.areEqual(ACTION_RUN_ID, byRun.CorrelationId__c, 'A run\'s id comes back as the correlation of a matching row');
		Assert.areEqual(ACTION_ROOT_ID, byRun.RootCorrelationId__c, 'A run\'s row carries the action\'s root, which is how the resolver tells a run from an action');
		Assert.areEqual(LEGACY_ACTION_ID, byLegacy.CorrelationId__c, 'A legacy action\'s id comes back as the correlation of a matching row');
		Assert.isNull(byLegacy.RootCorrelationId__c, 'A legacy action\'s row carries no root');
		Assert.isNull(unknown, 'An id no entry carries reads nothing');
		Assert.isNull(blank, 'A blank id reads nothing');
	}

	/**
	 * @description Low-privilege test: proves the three action-scope reads behind the console's banner and its search resolver
	 * (findFirstInScope, findLastInScope and findOneByRootOrCorrelation) still return the framework-owned row for a
	 * Minimum Access user with no field access on kern__LogEntry__c. Log entries are Private and the test administrator
	 * owns the seeded row, so each read must waive field-level security (SYSTEM_MODE) and record sharing
	 * (bypassSharingInternal()).
	 */
	@IsTest
	private static void shouldReadTheActionScopeForLowPrivilegeUser()
	{
		LogEntry__c seeded;
		System.runAs(getTestAdmin())
		{
			seeded = seedScopedEntry(ACTION_ROOT_ID, ACTION_ROOT_ID, 'the action itself', Datetime.now().addMinutes(-3));
		}

		System.runAs(getLowPrivilegeUser())
		{
			LogEntry__c first = new SEL_LogEntry().findFirstInScope(ACTION_ROOT_ID);
			LogEntry__c last = new SEL_LogEntry().findLastInScope(ACTION_ROOT_ID);
			LogEntry__c resolved = new SEL_LogEntry().findOneByRootOrCorrelation(ACTION_ROOT_ID);

			Assert.areEqual(seeded.Id, first.Id, 'A low-privilege caller still reads the action\'s first entry');
			Assert.areEqual(seeded.Id, last.Id, 'A low-privilege caller still reads the action\'s last entry');
			Assert.areEqual(seeded.Id, resolved.Id, 'A low-privilege caller still resolves a tracking id to its entry');
		}
	}

	/**
	 * @description A body search typed while the console is filtered to one action searches inside that action: the SOSL leg puts the action
	 * scope in its RETURNING WHERE, so of two rows the search index matches, only the one belonging to the action returns.
	 */
	@IsTest
	private static void shouldKeepTheSoslSearchLegInsideTheActionScope()
	{
		LogEntry__c insideRow = seedScopedEntry(ACTION_RUN_ID, ACTION_ROOT_ID, SOSL_SCOPED_NEEDLE, Datetime.now().addMinutes(-2));
		LogEntry__c outsideRow = seedScopedEntry(OTHER_ACTION_ID, OTHER_ACTION_ID, SOSL_SCOPED_NEEDLE, Datetime.now().addMinutes(-1));
		Test.setFixedSearchResults(new List<Id> {insideRow.Id, outsideRow.Id});

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.rootCorrelationId = ACTION_ROOT_ID;

		Test.startTest();
		Set<Id> hits = new SEL_LogEntry().findIdsByBodySosl(SOSL_SCOPED_NEEDLE, criteria, 2000);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {insideRow.Id}, hits, 'Only the row inside the action survives the action clause in the RETURNING WHERE');
	}

	/**
	 * @description The derived problems fold reads the action scope too, so the problems listed under an action pill are
	 * folded from the action's own rows alone and a row belonging to another action is left out of the scan.
	 */
	@IsTest
	private static void shouldKeepTheDerivedFoldInsideTheActionScope()
	{
		newDerivedNullPointerRowBuilder()
				.withOverride(LogEntry__c.CorrelationId__c, ACTION_ROOT_ID)
				.withOverride(LogEntry__c.RootCorrelationId__c, ACTION_ROOT_ID)
				.build();
		newDerivedNullPointerRowBuilder()
				.withOverride(LogEntry__c.CorrelationId__c, ACTION_RUN_ID)
				.withOverride(LogEntry__c.RootCorrelationId__c, ACTION_ROOT_ID)
				.build();
		newDerivedNullPointerRowBuilder()
				.withOverride(LogEntry__c.CorrelationId__c, OTHER_ACTION_ID)
				.withOverride(LogEntry__c.RootCorrelationId__c, OTHER_ACTION_ID)
				.build();

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.rootCorrelationId = ACTION_ROOT_ID;

		Test.startTest();
		Integer scopedToAction = new SEL_LogEntry().countFoldableRowsInWindow(criteria, new List<String> {LOG_Engine.LEVEL_ERROR});
		Integer everyAction = new SEL_LogEntry().countFoldableRowsInWindow(new SEL_LogEntry.BrowseCriteria(), new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(2, scopedToAction, 'The fold scans the action\'s own row and its run\'s row, and nothing else');
		Assert.areEqual(3, everyAction, 'Without the action scope the same fold scans the other action\'s row as well');
	}

	/**
	 * @description Tests that the shared browse criteria narrows on UserId__c (the emitting user), not
	 * CreatedById (always the Automated Process user that persists the platform event), returning only
	 * the row whose UserId__c matches the requested filter.
	 */
	@IsTest
	private static void shouldFilterByUserIdNotCreatedById()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.UserId__c, SEED_USER_ID)
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.UserId__c, OTHER_USER_ID)
				.build();

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.userId = SEED_USER_ID;

		Test.startTest();
		QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(criteria, LogEntry__c.CreatedDate, true, 1, 50);
		Test.stopTest();

		Assert.areEqual(1, page.totalRecords, 'Only the row for the requested UserId__c should return');
		Assert.areEqual(SEED_USER_ID, ((LogEntry__c)page.records[0]).UserId__c, 'The returned row should carry the requested UserId__c');
	}

	/**
	 * @description Low-privilege test: proves the Log Console distinct-view read (findRollupRowsInWindow) returns
	 * org-wide rows for a Minimum-Access user with no FLS on kern__LogEntry__c, because
	 * systemModeRequired() elevates the query to SYSTEM_MODE and bypassSharingInternal() removes the
	 * sharing restriction. A future demotion of systemModeRequired() to false fails this at 2GP
	 * validated-build time rather than in a subscriber org.
	 */
	@IsTest
	private static void shouldElevateForLowPrivilegeUser()
	{
		System.runAs(getTestAdmin())
		{
			seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 5, 0);
		}

		System.runAs(getLowPrivilegeUser())
		{
			List<LogEntry__c> rollupRows = new SEL_LogEntry().findRollupRowsInWindow(new SEL_LogEntry.BrowseCriteria(), 5000);

			Assert.isFalse(rollupRows.isEmpty(), 'A low-privilege caller should still read framework-owned rollup rows via SYSTEM_MODE elevation');
		}
	}

	/**
	 * @description Tests that a null criteria applies no filters: findEntriesFiltered returns every
	 * forensic row (OccurrenceCount__c null) when the controller's filter object is absent.
	 */
	@IsTest
	private static void shouldReturnAllEntriesForNullCriteria()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withCount(2)
				.buildList();

		Test.startTest();
		QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(null, LogEntry__c.CreatedDate, true, 1, 50);
		Test.stopTest();

		Assert.areEqual(2, page.totalRecords, 'A null criteria should apply no filters and return every forensic row');
	}

	/**
	 * @description Tests that every browse filter (level, execution context, user, free-text search,
	 * correlation id and the date window) is applied together, returning only the row that satisfies
	 * all of them.
	 */
	@IsTest
	private static void shouldApplyAllBrowseFilters()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.BATCH_APEX.name())
				.withOverride(LogEntry__c.ShortMessage__c, 'Attempt to de-reference a null object')
				.withOverride(LogEntry__c.CorrelationId__c, SEED_CORRELATION_ID)
				.withOverride(LogEntry__c.UserId__c, SEED_USER_ID)
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.SYNCHRONOUS.name())
				.withOverride(LogEntry__c.ShortMessage__c, 'an unrelated message')
				.withOverride(LogEntry__c.CorrelationId__c, 'unrelated-correlation')
				.withOverride(LogEntry__c.UserId__c, OTHER_USER_ID)
				.build();

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.levels = new List<String> {'ERROR'};
		criteria.executionEvents = new List<String> {'BATCH_APEX'};
		criteria.userId = SEED_USER_ID;
		criteria.searchTerm = 'de-reference';
		criteria.correlationId = SEED_CORRELATION_ID;
		criteria.windowStart = Datetime.now().addDays(-1);
		criteria.windowEnd = Datetime.now().addDays(1);

		Test.startTest();
		QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(criteria, LogEntry__c.CreatedDate, true, 1, 50);
		Test.stopTest();

		Assert.areEqual(1, page.totalRecords, 'Only the row matching every filter should return');
		Assert.areEqual(TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER, ((LogEntry__c)page.records[0]).Fingerprint__c,
				'The matching ERROR/BATCH_APEX row should be the one returned');
	}

	/**
	 * @description Tests that the SOQL search leg matches the term against BOTH ShortMessage__c AND
	 * CorrelationId__c, combining the Ids, and that a blank term short-circuits to an empty set.
	 */
	@IsTest
	private static void shouldFindIdsBySearchAcrossShortMessageAndCorrelation()
	{
		LogEntry__c shortMatch = seedSearchableRow(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 'needleSHORT in the message', 'unrelated body a', 'plain-correlation');
		LogEntry__c correlationMatch = seedSearchableRow(BASE_OTHER, LOG_Engine.LEVEL_INFO, 'an unrelated short message', 'unrelated body b', 'needleCORR-7777');

		SEL_LogEntry selector = new SEL_LogEntry();
		Test.startTest();
		Set<Id> shortHits = selector.findIdsBySearch('needleSHORT', new SEL_LogEntry.BrowseCriteria(), 2000);
		Set<Id> correlationHits = selector.findIdsBySearch('needleCORR', new SEL_LogEntry.BrowseCriteria(), 2000);
		Set<Id> blankHits = selector.findIdsBySearch('', new SEL_LogEntry.BrowseCriteria(), 2000);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {shortMatch.Id}, shortHits, 'The short-message term should match only the ShortMessage__c row');
		Assert.areEqual(new Set<Id> {correlationMatch.Id}, correlationHits, 'The correlation term should match only the CorrelationId__c row');
		Assert.isTrue(blankHits.isEmpty(), 'A blank term should short-circuit to an empty set');
	}

	/**
	 * @description Tests that the SOSL body leg returns exactly the search-index hits (modelled with
	 * Test.setFixedSearchResults) that also satisfy the RETURNING WHERE clause, and that a blank or
	 * under-two-character term short-circuits before issuing the SOSL.
	 */
	@IsTest
	private static void shouldFindIdsByBodySoslFromFixedResults()
	{
		LogEntry__c bodyMatch = seedSearchableRow(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 'generic short message',
				'System.DmlException: deep body needle in the long message', 'plain-correlation');
		Test.setFixedSearchResults(new List<Id> {bodyMatch.Id});

		SEL_LogEntry selector = new SEL_LogEntry();
		Test.startTest();
		Set<Id> bodyHits = selector.findIdsByBodySosl('needle', new SEL_LogEntry.BrowseCriteria(), 2000);
		Set<Id> blankHits = selector.findIdsByBodySosl('', new SEL_LogEntry.BrowseCriteria(), 2000);
		Set<Id> shortTermHits = selector.findIdsByBodySosl('a', new SEL_LogEntry.BrowseCriteria(), 2000);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {bodyMatch.Id}, bodyHits, 'The body SOSL leg should return the fixed search result satisfying the WHERE clause');
		Assert.isTrue(blankHits.isEmpty(), 'A blank term should short-circuit before the SOSL');
		Assert.isTrue(shortTermHits.isEmpty(), 'A single-character term is below the SOSL minimum and should short-circuit');
	}

	/**
	 * @description Tests that a term the reader typed reaches SOSL as a literal. Every SOSL reserved
	 * character gains a leading backslash, a character outside that set is left alone, a backslash the
	 * reader typed is escaped once and never twice, and the whole term is wrapped in double quotes, which
	 * is what stops AND, OR and AND NOT being read as operators whatever their case. The live matching
	 * behaviour behind each of these rules was measured against a real search index; a test cannot
	 * re-measure it, because Test.setFixedSearchResults answers with the fixed rows whatever the term
	 * says. So the rules are checked here, on the one function that builds the term.
	 */
	@IsTest
	private static void shouldBuildLiteralSoslSearchTerm()
	{
		List<String> reservedCharacters = new List<String>
		{
				'?', '&', '|', '!', '{', '}', '[', ']', '(', ')',
				'^', '~', '*', ':', '"', '\'', '+', '-', '\\'
		};

		Test.startTest();
		String plain = SEL_LogEntry.toLiteralSearchTerm('needle');
		String unreserved = SEL_LogEntry.toLiteralSearchTerm('needle#hash');
		String star = SEL_LogEntry.toLiteralSearchTerm('order*id');
		String question = SEL_LogEntry.toLiteralSearchTerm('order?id');
		String typedBackslash = SEL_LogEntry.toLiteralSearchTerm('c:\\temp');
		String alreadyEscaped = SEL_LogEntry.toLiteralSearchTerm('order\\*id');
		String upperCaseOperators = SEL_LogEntry.toLiteralSearchTerm('alpha AND NOT beta OR gamma');
		String lowerCaseOperators = SEL_LogEntry.toLiteralSearchTerm('alpha and not beta or gamma');
		Test.stopTest();

		for(String character : reservedCharacters)
		{
			Assert.areEqual('"needle\\' + character + '"', SEL_LogEntry.toLiteralSearchTerm('needle' + character),
					'Every SOSL reserved character must reach FIND behind a backslash, including ' + character);
		}
		Assert.areEqual('"needle"', plain, 'A term with nothing to escape must simply be quoted');
		Assert.areEqual('"needle#hash"', unreserved, 'A character SOSL does not reserve must be left exactly as the reader typed it');
		Assert.areEqual('"order\\*id"', star, 'A star must stop being a wildcard');
		Assert.areEqual('"order\\?id"', question, 'A question mark must stop being a single-character wildcard');
		Assert.areEqual('"c\\:\\\\temp"', typedBackslash, 'A backslash the reader typed must itself be escaped');
		Assert.areEqual('"order\\\\\\*id"', alreadyEscaped,
				'A term that already carries a backslash must be escaped once in a single pass, never twice');
		Assert.areEqual('"alpha AND NOT beta OR gamma"', upperCaseOperators,
				'The quotes are what neutralise the operator words, so the words themselves stay as typed');
		Assert.areEqual('"alpha and not beta or gamma"', lowerCaseOperators,
				'Operator words are case-insensitive to SOSL, and the quotes neutralise them in either case');
	}

	/**
	 * @description Tests that the SOSL body leg honours the criteria filters in its RETURNING WHERE: a
	 * fixed search result whose level is outside the criteria level filter is excluded.
	 */
	@IsTest
	private static void shouldExcludeBodySoslResultOutsideCriteria()
	{
		LogEntry__c warnRow = seedSearchableRow(BASE_OTHER, LOG_Engine.LEVEL_WARN, 'warn short', 'a body needle only on a WARN row', 'plain-correlation');
		Test.setFixedSearchResults(new List<Id> {warnRow.Id});

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.levels = new List<String> {'ERROR'};
		criteria.executionEvents = new List<String> {'BATCH_APEX'};
		criteria.userId = SEED_USER_ID;
		criteria.windowStart = Datetime.now().addDays(-1);
		criteria.windowEnd = Datetime.now().addDays(1);

		Test.startTest();
		Set<Id> hits = new SEL_LogEntry().findIdsByBodySosl('needle', criteria, 2000);
		Test.stopTest();

		Assert.isTrue(hits.isEmpty(), 'A WARN fixed result must be excluded when the criteria filters to ERROR (and every WHERE branch is built)');
	}

	/**
	 * @description Tests that the SOQL search leg keeps the correlation id on the criteria: two rows whose
	 * ShortMessage__c carries the term but under different correlation ids yield only the row matching the
	 * criteria correlation, so a Chain-Monitor deep-link keeps its scope once a search term is added.
	 */
	@IsTest
	private static void shouldScopeSearchLegByCorrelation()
	{
		LogEntry__c matching = seedSearchableRow(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 'needleSHARED in the short message', 'unrelated body a', SEED_CORRELATION_ID);
		seedSearchableRow(BASE_OTHER, LOG_Engine.LEVEL_ERROR, 'needleSHARED in the short message', 'unrelated body b', 'a-different-correlation');

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.correlationId = SEED_CORRELATION_ID;

		Test.startTest();
		Set<Id> hits = new SEL_LogEntry().findIdsBySearch('needleSHARED', criteria, 2000);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {matching.Id}, hits,
				'The SOQL search leg must keep the correlation scope: only the row under the criteria correlation should match, though both carry the term');
	}

	/**
	 * @description Tests that the SOSL body leg scopes its RETURNING WHERE to the correlation id on the
	 * criteria: of two fixed search results under different correlation ids, only the one matching the
	 * criteria correlation is returned, so a body search keeps a deep-link's correlation scope.
	 */
	@IsTest
	private static void shouldScopeBodySoslLegByCorrelation()
	{
		LogEntry__c matching = seedSearchableRow(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 'generic short one',
				'deep body needle under the matching correlation', SEED_CORRELATION_ID);
		LogEntry__c other = seedSearchableRow(BASE_OTHER, LOG_Engine.LEVEL_ERROR, 'generic short two', 'deep body needle under a different correlation', 'a-different-correlation');
		Test.setFixedSearchResults(new List<Id> {matching.Id, other.Id});

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.correlationId = SEED_CORRELATION_ID;

		Test.startTest();
		Set<Id> hits = new SEL_LogEntry().findIdsByBodySosl('needle', criteria, 2000);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {matching.Id}, hits,
				'The SOSL body leg must scope its RETURNING WHERE to the criteria correlation: only the matching-correlation fixed result should return');
	}

	/**
	 * @description Tests that the SOSL body leg scopes its RETURNING WHERE to the source on the criteria: of two fixed
	 * search results under different sources, only the one whose ClassMethod__c equals the criteria source is
	 * returned, so a body search under an active source pill cannot surface another source's entry. The rows are
	 * seeded through TST_Factory.seedLogEntry with the source field the scenario needs.
	 */
	@IsTest
	private static void shouldScopeBodySoslLegBySource()
	{
		LogEntry__c matching = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ShortMessage__c => 'generic short one',
				LogEntry__c.Message__c => 'deep body needle under the matching source',
				LogEntry__c.CorrelationId__c => SEED_CORRELATION_ID,
				LogEntry__c.ClassMethod__c => DERIVED_METHOD_ACCOUNT
		});
		LogEntry__c other = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ShortMessage__c => 'generic short two',
				LogEntry__c.Message__c => 'deep body needle under a different source',
				LogEntry__c.CorrelationId__c => SEED_CORRELATION_ID,
				LogEntry__c.ClassMethod__c => DERIVED_METHOD_OPPORTUNITY
		});
		Test.setFixedSearchResults(new List<Id> {matching.Id, other.Id});

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.classMethod = DERIVED_METHOD_ACCOUNT;

		Test.startTest();
		Set<Id> hits = new SEL_LogEntry().findIdsByBodySosl('needle', criteria, 2000);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {matching.Id}, hits,
				'The SOSL body leg must scope its RETURNING WHERE to the criteria source: only the matching-source fixed result should return');
	}

	/**
	 * @description Tests that criteria values carrying SOSL string-literal metacharacters reach the
	 * RETURNING WHERE clause as data and never as syntax. The body leg is the one predicate in this
	 * selector assembled as text rather than through QRY_Builder, so that separation is a contract
	 * rather than a structural guarantee: each payload below closes a literal and appends a predicate
	 * that would match every row, and a trailing backslash would, in a written-out literal, escape the
	 * closing quote and break the query outright. Every payload must therefore match nothing, while the
	 * control proves the same harness does surface a row when the filter genuinely matches, so a
	 * widening regression cannot hide behind an empty result. Covers every bound site: the single-value
	 * clauses (correlation, user, class-method, writer name) and the IN-list clauses (levels, execution
	 * events, origins).
	 */
	@IsTest
	private static void shouldNeutraliseSoslMetacharactersInBodyLegCriteria()
	{
		LogEntry__c bodyMatch = seedSearchableRow(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 'generic short message',
				'a deep body needle for the metacharacter probe', SEED_CORRELATION_ID);
		Test.setFixedSearchResults(new List<Id> {bodyMatch.Id});

		String quoteBreakout = 'zzz\' OR ' + String.valueOf(LogEntry__c.CorrelationId__c) + ' != \'';
		String trailingBackslash = 'zzz\\';

		SEL_LogEntry.BrowseCriteria correlationPayload = new SEL_LogEntry.BrowseCriteria();
		correlationPayload.correlationId = quoteBreakout;

		SEL_LogEntry.BrowseCriteria backslashPayload = new SEL_LogEntry.BrowseCriteria();
		backslashPayload.correlationId = trailingBackslash;

		SEL_LogEntry.BrowseCriteria userPayload = new SEL_LogEntry.BrowseCriteria();
		userPayload.userId = quoteBreakout;

		SEL_LogEntry.BrowseCriteria classMethodPayload = new SEL_LogEntry.BrowseCriteria();
		classMethodPayload.classMethod = quoteBreakout;

		SEL_LogEntry.BrowseCriteria levelListPayload = new SEL_LogEntry.BrowseCriteria();
		levelListPayload.levels = new List<String> {'WARN\' OR ' + String.valueOf(LogEntry__c.LogLevel__c) + ' != \''};

		SEL_LogEntry.BrowseCriteria eventListPayload = new SEL_LogEntry.BrowseCriteria();
		eventListPayload.executionEvents = new List<String> {'BATCH_APEX\' OR ' + String.valueOf(LogEntry__c.ExecutionEvent__c) + ' != \''};

		SEL_LogEntry.BrowseCriteria originListPayload = new SEL_LogEntry.BrowseCriteria();
		originListPayload.origins = new List<String> {LOG_Engine.Origin.APEX.name() + '\' OR ' + String.valueOf(LogEntry__c.Origin__c) + ' != \''};

		SEL_LogEntry.BrowseCriteria writerPayload = new SEL_LogEntry.BrowseCriteria();
		writerPayload.source = quoteBreakout;

		SEL_LogEntry.BrowseCriteria control = new SEL_LogEntry.BrowseCriteria();
		control.correlationId = SEED_CORRELATION_ID;

		SEL_LogEntry selector = new SEL_LogEntry();
		Test.startTest();
		Set<Id> correlationHits = selector.findIdsByBodySosl('needle', correlationPayload, 2000);
		Set<Id> backslashHits = selector.findIdsByBodySosl('needle', backslashPayload, 2000);
		Set<Id> userHits = selector.findIdsByBodySosl('needle', userPayload, 2000);
		Set<Id> classMethodHits = selector.findIdsByBodySosl('needle', classMethodPayload, 2000);
		Set<Id> levelHits = selector.findIdsByBodySosl('needle', levelListPayload, 2000);
		Set<Id> eventHits = selector.findIdsByBodySosl('needle', eventListPayload, 2000);
		Set<Id> originHits = selector.findIdsByBodySosl('needle', originListPayload, 2000);
		Set<Id> writerHits = selector.findIdsByBodySosl('needle', writerPayload, 2000);
		Set<Id> controlHits = selector.findIdsByBodySosl('needle', control, 2000);
		Test.stopTest();

		Assert.areEqual(new Set<Id> {bodyMatch.Id}, controlHits,
				'Control: a genuinely matching correlation filter must surface the row, so an empty payload result is meaningful');
		Assert.isTrue(correlationHits.isEmpty(), 'A quote-breakout correlation value must be escaped to data and match nothing');
		Assert.isTrue(backslashHits.isEmpty(), 'A trailing-backslash correlation value must be escaped rather than escaping the closing quote');
		Assert.isTrue(userHits.isEmpty(), 'A quote-breakout user id must be escaped to data and match nothing');
		Assert.isTrue(classMethodHits.isEmpty(), 'A quote-breakout class-method value must be escaped to data and match nothing');
		Assert.isTrue(levelHits.isEmpty(), 'A quote-breakout level in the IN list must be escaped to data and match nothing');
		Assert.isTrue(eventHits.isEmpty(), 'A quote-breakout execution event in the IN list must be escaped to data and match nothing');
		Assert.isTrue(originHits.isEmpty(), 'A quote-breakout origin in the IN list must be escaped to data and match nothing');
		Assert.isTrue(writerHits.isEmpty(), 'A quote-breakout writer name must be escaped to data and match nothing');
	}

	/**
	 * @description Tests that findSortedPageByIds fetches exactly the requested Ids server-side paged, and
	 * that an empty id set yields an empty page rather than an unbounded query.
	 */
	@IsTest
	private static void shouldFindSortedPageByIds()
	{
		LogEntry__c first = seedSearchableRow(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, 'page row one', 'body one', 'corr-one');
		LogEntry__c second = seedSearchableRow(BASE_OTHER, LOG_Engine.LEVEL_WARN, 'page row two', 'body two', 'corr-two');
		seedSearchableRow('excluded', LOG_Engine.LEVEL_INFO, 'page row excluded', 'body excluded', 'corr-excluded');

		SEL_LogEntry selector = new SEL_LogEntry();
		Test.startTest();
		QRY_Builder.QueryPage page = selector.findSortedPageByIds(new Set<Id> {first.Id, second.Id}, LogEntry__c.CreatedDate, true, 1, 50);
		QRY_Builder.QueryPage emptyPage = selector.findSortedPageByIds(new Set<Id>(), LogEntry__c.CreatedDate, true, 1, 50);
		Test.stopTest();

		Assert.areEqual(2, page.totalRecords, 'Only the two requested Ids should be fetched');
		Assert.areEqual(0, emptyPage.totalRecords, 'An empty id set should yield an empty page');
	}

	/**
	 * @description Tests that the derived fold groups plain forensic rows by (exception type, class method,
	 * log level), folds COUNT / MIN-firstSeen / MAX-lastSeen / MAX-label, and orders by count
	 * descending.
	 */
	@IsTest
	private static void shouldFoldPlainRowsIntoDerivedSignatures()
	{
		Datetime now = Datetime.now();
		List<LogEntry__c> nullPointerRows =
				seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 3);
		Test.setCreatedDate(nullPointerRows[0].Id, now.addDays(-3));
		Test.setCreatedDate(nullPointerRows[1].Id, now.addDays(-2));
		Test.setCreatedDate(nullPointerRows[2].Id, now.addDays(-1));
		seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_DML, 2);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(2, signatures.size(), 'Both attributed signatures should fold');
		SEL_LogEntry.DerivedSignature top = signatures[0];
		Assert.areEqual(3, top.occurrenceCount, 'The NullPointer signature should fold three occurrences and sort first by count');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, top.exceptionType, 'The folded exception type should be carried on the signature');
		Assert.areEqual(DERIVED_METHOD_ACCOUNT, top.classMethod, 'The folded class method should be carried on the signature');
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, top.logLevel, 'The folded log level should be carried on the signature');
		Assert.areEqual(DERIVED_LABEL_NPE, top.label, 'The ShortMessage label should be surfaced via MAX(ShortMessage__c)');
		Assert.areEqual(now.addDays(-3).date(), top.firstSeen.date(), 'firstSeen should be the earliest occurrence (MIN CreatedDate)');
		Assert.areEqual(now.addDays(-1).date(), top.lastSeen.date(), 'lastSeen should be the latest occurrence (MAX CreatedDate)');
		Assert.areEqual(2, signatures[1].occurrenceCount, 'The DmlException signature should fold two occurrences');
	}

	/**
	 * @description Tests that a signature keyed on exception type alone (null ClassMethod__c) still folds,
	 * because the ADR-6 attribution guard passes on ExceptionType__c.
	 */
	@IsTest
	private static void shouldFoldSignaturesWithNullClassMethod()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, null, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 3);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'A signature keyed on exception type alone should still fold (ADR-6 passes on ExceptionType__c)');
		Assert.areEqual(3, signatures[0].occurrenceCount, 'All three null-class-method rows should fold into one signature');
		Assert.isNull(signatures[0].classMethod, 'The class method should be null on the folded signature');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, signatures[0].exceptionType, 'The exception type keys the signature when class method is null');
	}

	/**
	 * @description Tests that rows with neither an exception type nor a class method are excluded from the
	 * fold (the ADR-6 attribution guard), so structureless logs never collapse into one mega-group.
	 */
	@IsTest
	private static void shouldExcludeUnattributedRowsFromFold()
	{
		seedDerivedOccurrences(null, null, null, LOG_Engine.LEVEL_ERROR, 'a structureless error string', 4);
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'Rows with neither exception type nor class method must be excluded (ADR-6 attribution guard)');
		Assert.areEqual(2, signatures[0].occurrenceCount, 'Only the attributed rows should fold');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, signatures[0].exceptionType, 'The single folded signature should be the attributed one');
	}

	/**
	 * @description Tests that HAVING COUNT >= minOccurrences drops a signature whose occurrence count is
	 * below the floor.
	 */
	@IsTest
	private static void shouldApplyHavingMinimumOccurrences()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 3);
		seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_DML, 1);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'The single-occurrence signature should be dropped by HAVING COUNT >= minOccurrences');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, signatures[0].exceptionType, 'Only the signature meeting the minimum-occurrences floor should survive');
	}

	/**
	 * @description Tests that the fold is scoped to the requested log levels, so a same-identity signature at
	 * an out-of-scope level is excluded.
	 */
	@IsTest
	private static void shouldScopeFoldToRequestedLevels()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_INFO, DERIVED_LABEL_NPE, 2);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'Only the ERROR-level signature should fold when the level scope is ERROR');
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, signatures[0].logLevel, 'The folded signature should be the in-scope ERROR one; the INFO rows are out of scope');
	}

	/**
	 * @description Tests that the group cap (LIMIT) bounds the number of returned signatures.
	 */
	@IsTest
	private static void shouldCapDerivedGroupsAtGroupCap()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_DML, 2);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 1, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'The group cap (LIMIT) should bound the number of returned signatures');
	}

	/**
	 * @description Tests that the fold is bounded to the CreatedDate window, exercising both the windowStart
	 * and windowEnd predicate branches: a ten-day-old signature outside the window is excluded.
	 */
	@IsTest
	private static void shouldBoundFoldToCreatedDateWindow()
	{
		Datetime now = Datetime.now();
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		List<LogEntry__c> oldRows =
				seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_DML, 2);
		for(LogEntry__c oldRow : oldRows)
		{
			Test.setCreatedDate(oldRow.Id, now.addDays(-10));
		}

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.windowStart = now.addDays(-1);
		criteria.windowEnd = now.addDays(1);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry().foldDerivedSignaturesInWindow(criteria, 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'Only the in-window signature should fold; the ten-day-old rows fall outside the CreatedDate window');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, signatures[0].exceptionType, 'The recent NullPointer signature should be the one returned');
	}

	/**
	 * @description Tests that an empty level scope applies no level filter, so signatures at every level fold.
	 */
	@IsTest
	private static void shouldFoldAllLevelsWhenLevelScopeEmpty()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_INFO, DERIVED_LABEL_DML, 2);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry().foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 2000, 2, new List<String>());
		Test.stopTest();

		Assert.areEqual(2, signatures.size(), 'An empty level scope should apply no level filter, folding both the ERROR and INFO signatures');
	}

	/**
	 * @description Tests that the pre-flight scan count sizes exactly the population the fold would scan,
	 * and nothing else. The count exists to decline a fold that would exhaust the query-row governor, so a
	 * count over a wider population than the fold scans would decline healthy folds, and one over a narrower
	 * population would let through the fold that breaks the view, a failure that cannot be
	 * caught. Every exclusion the fold applies is asserted here: rollup counter rows, fingerprinted rows,
	 * rows carrying neither an exception type nor a class method, and rows outside the level scope.
	 */
	@IsTest
	private static void shouldCountOnlyTheRowsTheFoldWouldScan()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_DML, 3);
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_INFO, DERIVED_LABEL_NPE, 4);
		// Structureless rows: no exception type and no class method, so the attribution guard excludes them.
		seedDerivedOccurrences(null, null, null, LOG_Engine.LEVEL_ERROR, 'a message with no structure', 5);
		// A rollup counter row and a fingerprinted detail row: neither is a plain forensic row.
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, DERIVED_EXCEPTION_NPE)
				.withOverride(LogEntry__c.ClassMethod__c, DERIVED_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.OccurrenceCount__c, 9)
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, DERIVED_EXCEPTION_NPE)
				.withOverride(LogEntry__c.ClassMethod__c, DERIVED_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.build();

		Test.startTest();
		Integer errorScope = new SEL_LogEntry().countFoldableRowsInWindow(new SEL_LogEntry.BrowseCriteria(), new List<String> {LOG_Engine.LEVEL_ERROR});
		Integer allLevels = new SEL_LogEntry().countFoldableRowsInWindow(new SEL_LogEntry.BrowseCriteria(), new List<String>());
		Test.stopTest();

		Assert.areEqual(5, errorScope,
				'Only the five attributed, plain, ERROR forensic rows should be counted, not the INFO rows, structureless rows, rollup counter or fingerprinted detail');
		Assert.areEqual(9, allLevels,
				'An empty level scope should widen the count to the INFO rows too, while still excluding the structureless, rollup and fingerprinted rows');
	}

	/**
	 * @description Tests that the pre-flight scan count is bounded by BOTH ends of the CreatedDate window.
	 * The window is the setting a subscriber actually changes, and a custom range has no upper bound, so a
	 * count that ignored it would size every request against the whole table and decline folds that are
	 * safe. The window is placed wholly in the past so rows fall out on each side independently: excluding
	 * only by the lower bound would leave the windowEnd predicate executed but never proven.
	 */
	@IsTest
	private static void shouldBoundFoldableRowCountToBothEndsOfTheCreatedDateWindow()
	{
		Datetime now = Datetime.now();
		List<LogEntry__c> insideRows = seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		for(LogEntry__c insideRow : insideRows)
		{
			Test.setCreatedDate(insideRow.Id, now.addDays(-7));
		}
		List<LogEntry__c> beforeWindowRows =
				seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_DML, 3);
		for(LogEntry__c beforeWindowRow : beforeWindowRows)
		{
			Test.setCreatedDate(beforeWindowRow.Id, now.addDays(-20));
		}
		// Left at "now", so these sit AFTER windowEnd and can only be excluded by the upper bound.
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 4);

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.windowStart = now.addDays(-10);
		criteria.windowEnd = now.addDays(-5);

		SEL_LogEntry.BrowseCriteria lowerBoundOnly = new SEL_LogEntry.BrowseCriteria();
		lowerBoundOnly.windowStart = now.addDays(-10);

		Test.startTest();
		Integer windowed = new SEL_LogEntry().countFoldableRowsInWindow(criteria, new List<String> {LOG_Engine.LEVEL_ERROR});
		Integer lowerOnly = new SEL_LogEntry().countFoldableRowsInWindow(lowerBoundOnly, new List<String> {LOG_Engine.LEVEL_ERROR});
		Integer countWithoutWindow = new SEL_LogEntry().countFoldableRowsInWindow(new SEL_LogEntry.BrowseCriteria(), new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(2, windowed, 'Only the two rows inside both bounds should be counted');
		Assert.areEqual(6, lowerOnly,
				'Dropping only the upper bound must readmit the four rows created now, proving windowEnd, not windowStart, is what excluded them');
		Assert.areEqual(9, countWithoutWindow, 'With no window at all the count should span every foldable row, proving both bounds narrowed it');
	}

	/**
	 * @description Tests that rows sharing an exception type, class method and log level but recorded at
	 * different line numbers fold into ONE signature. The line number is not part of the grouping key
	 * (Number fields are not groupable in SOQL), and the folded COUNT spans the lines.
	 */
	@IsTest
	private static void shouldFoldAcrossLineNumbers()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'Same exception/method/level rows at different line numbers should fold into one signature');
		Assert.areEqual(4, signatures[0].occurrenceCount, 'The COUNT should span both line numbers (line is not a grouping key)');
	}

	/**
	 * @description Tests that a non-positive groupCap and minOccurrences fall back to the selector defaults
	 * (default minimum of two drops the single-occurrence signature).
	 */
	@IsTest
	private static void shouldDefaultCapAndMinimumWhenNonPositive()
	{
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		seedDerivedOccurrences(DERIVED_EXCEPTION_DML, DERIVED_METHOD_OPPORTUNITY, DERIVED_LINE_OPPORTUNITY, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_DML, 1);

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry()
				.foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 0, 0, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'A non-positive minOccurrences should fall back to the default floor of two, dropping the single-occurrence signature');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, signatures[0].exceptionType, 'Only the signature meeting the default minimum should survive');
	}

	/**
	 * @description Tests that findDerivedRepresentative returns the most-recent in-window occurrence of a
	 * signature (ORDER BY CreatedDate DESC), with CreatedDate selected.
	 */
	@IsTest
	private static void shouldFindDerivedRepresentativeMostRecentRow()
	{
		Datetime now = Datetime.now();
		List<LogEntry__c> rows = seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 3);
		Test.setCreatedDate(rows[0].Id, now.addDays(-3));
		Test.setCreatedDate(rows[1].Id, now.addDays(-1));
		Test.setCreatedDate(rows[2].Id, now.addDays(-2));
		SEL_LogEntry.DerivedSignature key = new SEL_LogEntry.DerivedSignature(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, LOG_Engine.LEVEL_ERROR);
		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.windowStart = now.addDays(-5);
		criteria.windowEnd = now.addDays(1);

		Test.startTest();
		LogEntry__c representative = new SEL_LogEntry().findDerivedRepresentative(key, criteria);
		Test.stopTest();

		Assert.isNotNull(representative, 'A representative row should be returned for a matching signature');
		Assert.areEqual(rows[1].Id, representative.Id, 'The most-recent occurrence in the window should be returned (ORDER BY CreatedDate DESC)');
		Assert.isNotNull(representative.CreatedDate, 'CreatedDate should be selected on the representative row');
	}

	/**
	 * @description Tests that findDerivedRepresentative resolves a representative for a signature whose class
	 * method is null, matching it with IS NULL (the identity is exception type, class method and log level).
	 */
	@IsTest
	private static void shouldFindDerivedRepresentativeForNullClassMethodSignature()
	{
		Datetime now = Datetime.now();
		seedDerivedOccurrences(DERIVED_EXCEPTION_NPE, null, DERIVED_LINE_ACCOUNT, LOG_Engine.LEVEL_ERROR, DERIVED_LABEL_NPE, 2);
		SEL_LogEntry.DerivedSignature key = new SEL_LogEntry.DerivedSignature(DERIVED_EXCEPTION_NPE, null, LOG_Engine.LEVEL_ERROR);
		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.windowStart = now.addDays(-5);
		criteria.windowEnd = now.addDays(1);

		Test.startTest();
		LogEntry__c representative = new SEL_LogEntry().findDerivedRepresentative(key, criteria);
		Test.stopTest();

		Assert.isNotNull(representative, 'A null-class-method signature should still resolve a representative row (IS NULL match)');
		Assert.isNull(representative.ClassMethod__c, 'The representative row should match the null class method identity');
	}

	/**
	 * @description Tests that findDerivedRepresentative returns null when no forensic row matches the
	 * signature, and that a null signature short-circuits to null.
	 */
	@IsTest
	private static void shouldReturnNullRepresentativeWhenNoRowMatches()
	{
		Datetime now = Datetime.now();
		SEL_LogEntry.DerivedSignature key = new SEL_LogEntry.DerivedSignature(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, LOG_Engine.LEVEL_ERROR);
		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.windowStart = now.addDays(-5);
		criteria.windowEnd = now.addDays(1);

		Test.startTest();
		LogEntry__c noMatch = new SEL_LogEntry().findDerivedRepresentative(key, criteria);
		LogEntry__c nullSignature = new SEL_LogEntry().findDerivedRepresentative(null, null);
		Test.stopTest();

		Assert.isNull(noMatch, 'No representative should be returned when no forensic row matches the signature');
		Assert.isNull(nullSignature, 'A null signature should short-circuit to null');
	}

	/**
	 * @description Tests that the fold applies the shared user scope: only rows recorded for the scoped user
	 * fold into signatures. This is the same rule the rollup leg's criteria already honor, so a user-filtered
	 * Problems view never counts another user's derived occurrences.
	 */
	@IsTest
	private static void shouldScopeFoldToUserFilter()
	{
		String scopedUser = UTIL_Random.randomId(User.SObjectType);
		String otherUser = UTIL_Random.randomId(User.SObjectType);
		newDerivedNullPointerRowBuilder()
				.withOverride(LogEntry__c.UserId__c, scopedUser)
				.withCount(2)
				.buildList();
		newDerivedDmlRowBuilder()
				.withOverride(LogEntry__c.UserId__c, otherUser)
				.withCount(2)
				.buildList();
		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.userId = scopedUser;

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry().foldDerivedSignaturesInWindow(criteria, 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'Only the scoped user\'s rows should fold into a signature');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, signatures[0].exceptionType, 'The surviving signature should be the scoped user\'s');
		Assert.areEqual(2, signatures[0].occurrenceCount, 'Only the scoped user\'s occurrences should count');
	}

	/**
	 * @description Tests that the fold applies the shared execution-context scope: only rows recorded in the
	 * scoped context fold into signatures. This is the same rule the rollup leg's criteria already honor.
	 */
	@IsTest
	private static void shouldScopeFoldToExecutionContextFilter()
	{
		newDerivedNullPointerRowBuilder()
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.AURA.name())
				.withCount(2)
				.buildList();
		newDerivedDmlRowBuilder()
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.BATCH_APEX.name())
				.withCount(2)
				.buildList();
		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.executionEvents = new List<String> {Quiddity.AURA.name()};

		Test.startTest();
		List<SEL_LogEntry.DerivedSignature> signatures = new SEL_LogEntry().foldDerivedSignaturesInWindow(criteria, 2000, 2, new List<String> {LOG_Engine.LEVEL_ERROR});
		Test.stopTest();

		Assert.areEqual(1, signatures.size(), 'Only the scoped execution context\'s rows should fold into a signature');
		Assert.areEqual(DERIVED_EXCEPTION_NPE, signatures[0].exceptionType, 'The surviving signature should be the scoped context\'s');
		Assert.areEqual(2, signatures[0].occurrenceCount, 'Only the scoped context\'s occurrences should count');
	}

	/**
	 * @description Tests that findDerivedRepresentative applies the shared correlation scope: with a NEWER
	 * un-correlated occurrence of the same signature present, a correlation-scoped lookup returns the
	 * most-recent CORRELATED row, so the opened representative always sits inside the filtered view that
	 * listed the problem.
	 */
	@IsTest
	private static void shouldScopeDerivedRepresentativeToCorrelation()
	{
		Datetime now = Datetime.now();
		String scopedCorrelationId = UTIL_Random.randomUUID();
		LogEntry__c correlated = (LogEntry__c)newDerivedNullPointerRowBuilder()
				.withOverride(LogEntry__c.CorrelationId__c, scopedCorrelationId)
				.build();
		LogEntry__c uncorrelated = (LogEntry__c)newDerivedNullPointerRowBuilder().build();
		Test.setCreatedDate(correlated.Id, now.addMinutes(-10));
		Test.setCreatedDate(uncorrelated.Id, now.addMinutes(-1));
		SEL_LogEntry.DerivedSignature key = new SEL_LogEntry.DerivedSignature(DERIVED_EXCEPTION_NPE, DERIVED_METHOD_ACCOUNT, LOG_Engine.LEVEL_ERROR);
		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.windowStart = now.addDays(-5);
		criteria.windowEnd = now.addDays(1);
		criteria.correlationId = scopedCorrelationId;

		Test.startTest();
		LogEntry__c representative = new SEL_LogEntry().findDerivedRepresentative(key, criteria);
		Test.stopTest();

		Assert.isNotNull(representative, 'A correlation-scoped representative should be found');
		Assert.areEqual(correlated.Id, representative.Id, 'The correlation scope should exclude the newer un-correlated row');
	}

	/**
	 * @description Tests that summariseEntriesInWindow folds the forensic rows (OccurrenceCount__c null) into
	 * per-level and per-source row counts, excluding the rollup: counter rows (OccurrenceCount__c non-null).
	 */
	@IsTest
	private static void shouldSummariseForensicEntriesByLevelAndSource()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'AlphaService.run')
				.withOverride(LogEntry__c.Source__c, 'AlphaService')
				.withCount(3)
				.buildList();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.ClassMethod__c, 'BravoService.run')
				.withOverride(LogEntry__c.Source__c, 'BravoService')
				.withCount(2)
				.buildList();
		TST_Factory.seedLogRollup(BASE_NULL_POINTER, UTIL_Date.toUtcDayBucket(Datetime.now()), LOG_Engine.LEVEL_ERROR, 99);

		Test.startTest();
		SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesInWindow(new SEL_LogEntry.BrowseCriteria(), 200);
		Test.stopTest();

		Map<String, Integer> byLevel = new Map<String, Integer>();
		for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
		{
			byLevel.put(levelCount.logLevel, levelCount.rowCount);
		}
		Assert.areEqual(3, byLevel.get(LOG_Engine.LEVEL_ERROR), 'Three ERROR forensic rows should count; the OccurrenceCount rollup is excluded');
		Assert.areEqual(2, byLevel.get(LOG_Engine.LEVEL_WARN), 'Two WARN forensic rows should count');

		Map<String, Integer> bySource = new Map<String, Integer>();
		for(SEL_LogEntry.SourceRowCount sourceCount : aggregate.sourceCounts)
		{
			bySource.put(sourceCount.source, sourceCount.rowCount);
		}
		Assert.areEqual(3, bySource.get('AlphaService'), 'Alpha forensic rows should count by their stored source');
		Assert.areEqual(2, bySource.get('BravoService'), 'Bravo forensic rows should count by their stored source');
	}

	/**
	 * @description Tests that summariseEntriesInWindow honours every browse filter branch (level, execution
	 * context, user, correlation, free-text search, origin, writer name and the date window), so only the row
	 * satisfying all of them is folded into the aggregate.
	 */
	@IsTest
	private static void shouldScopeEntryAggregateByEveryCriterion()
	{
		String writerName = 'AccountTriggerHandler';
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, DERIVED_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.BATCH_APEX.name())
				.withOverride(LogEntry__c.UserId__c, SEED_USER_ID)
				.withOverride(LogEntry__c.CorrelationId__c, SEED_CORRELATION_ID)
				.withOverride(LogEntry__c.ShortMessage__c, 'de-reference needle here')
				.withOverride(LogEntry__c.Origin__c, LOG_Engine.Origin.APEX.name())
				.withOverride(LogEntry__c.Source__c, writerName)
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, DERIVED_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.BATCH_APEX.name())
				.withOverride(LogEntry__c.UserId__c, SEED_USER_ID)
				.withOverride(LogEntry__c.CorrelationId__c, SEED_CORRELATION_ID)
				.withOverride(LogEntry__c.ShortMessage__c, 'de-reference needle here too')
				.withOverride(LogEntry__c.Origin__c, LOG_Engine.Origin.FLOW.name())
				.withOverride(LogEntry__c.Source__c, 'Order Intake')
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ClassMethod__c, DERIVED_METHOD_OPPORTUNITY)
				.withOverride(LogEntry__c.ShortMessage__c, 'an unrelated message')
				.build();

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.levels = new List<String> {'ERROR'};
		criteria.executionEvents = new List<String> {'BATCH_APEX'};
		criteria.userId = SEED_USER_ID;
		criteria.correlationId = SEED_CORRELATION_ID;
		criteria.searchTerm = 'needle';
		criteria.origins = new List<String> {LOG_Engine.Origin.APEX.name()};
		criteria.source = writerName;
		criteria.windowStart = Datetime.now().addDays(-1);
		criteria.windowEnd = Datetime.now().addDays(1);

		Test.startTest();
		SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesInWindow(criteria, 200);
		Test.stopTest();

		Integer total = 0;
		for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
		{
			total += levelCount.rowCount;
		}
		Assert.areEqual(1, total, 'Only the row matching every browse criterion should count in the aggregate');
	}

	/**
	 * @description Tests that summariseEntriesByIds folds the per-level and per-source forensic row counts over
	 * exactly the supplied id set (the ribbon aggregate the controller runs over the matched-id set under a
	 * search term), and that an empty id set yields an empty aggregate rather than an unbounded query.
	 */
	@IsTest
	private static void shouldSummariseEntriesByIds()
	{
		LogEntry__c errorAlpha = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'AlphaService.run')
				.withOverride(LogEntry__c.Source__c, 'AlphaService')
				.withOverride(LogEntry__c.ShortMessage__c, 'error alpha')
				.build();
		LogEntry__c errorAlphaTwo = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'AlphaService.run')
				.withOverride(LogEntry__c.Source__c, 'AlphaService')
				.withOverride(LogEntry__c.ShortMessage__c, 'error alpha two')
				.build();
		LogEntry__c warnBravo = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.ClassMethod__c, 'BravoService.run')
				.withOverride(LogEntry__c.Source__c, 'BravoService')
				.withOverride(LogEntry__c.ShortMessage__c, 'warn bravo')
				.build();

		SEL_LogEntry selector = new SEL_LogEntry();
		Test.startTest();
		SEL_LogEntry.EntryAggregate aggregate = selector.summariseEntriesByIds(new Set<Id> {errorAlpha.Id, errorAlphaTwo.Id, warnBravo.Id}, 200);
		SEL_LogEntry.EntryAggregate empty = selector.summariseEntriesByIds(new Set<Id>(), 200);
		Test.stopTest();

		Integer total = 0;
		Map<String, Integer> byLevel = new Map<String, Integer>();
		for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
		{
			total += levelCount.rowCount;
			byLevel.put(levelCount.logLevel, levelCount.rowCount);
		}
		Map<String, Integer> bySource = new Map<String, Integer>();
		for(SEL_LogEntry.SourceRowCount sourceCount : aggregate.sourceCounts)
		{
			bySource.put(sourceCount.source, sourceCount.rowCount);
		}
		Assert.areEqual(3, total, 'The aggregate should count exactly the three supplied rows');
		Assert.areEqual(2, byLevel.get(LOG_Engine.LEVEL_ERROR), 'Two ERROR rows fold into the ERROR level count');
		Assert.areEqual(1, byLevel.get(LOG_Engine.LEVEL_WARN), 'One WARN row folds into the WARN level count');
		Assert.areEqual(2, bySource.get('AlphaService'), 'Two rows share the AlphaService source');
		Assert.areEqual(1, bySource.get('BravoService'), 'One row is BravoService');
		Assert.isTrue(empty.levelCounts.isEmpty() && empty.sourceCounts.isEmpty(), 'An empty id set yields an empty aggregate, never an unbounded query');
	}

	/**
	 * @description Tests that the windowed ribbon aggregate matches a search term against ShortMessage__c
	 * OR CorrelationId__c (the same two fields the entries table's SOQL search leg matches), so a
	 * correlation-only match counts and an unmatched row does not. Guards the two-field OR: changing it
	 * to a single-field match, or dropping the search branch entirely, fails on the exact count.
	 */
	@IsTest
	private static void shouldMatchWindowAggregateSearchAcrossShortMessageAndCorrelation()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'needle in the message')
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.CorrelationId__c, 'corr-needle-123')
				.withOverride(LogEntry__c.ShortMessage__c, 'plain message')
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'unrelated message')
				.build();

		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.searchTerm = 'needle';

		Test.startTest();
		SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesInWindow(criteria, 200);
		Test.stopTest();

		Integer total = 0;
		for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
		{
			total += levelCount.rowCount;
		}
		Assert.areEqual(2, total, 'The search term should match the short-message row and the correlation row, and exclude the unmatched row');
	}

	/**
	 * @description The all-entries ribbon folds by the stored source and origin, ranks by rows, and carries the
	 * origin on each row; rows with no origin fold into their own group for the caller to skip.
	 */
	@IsTest
	private static void shouldFoldSourceCountsByStoredSourceAndOrigin()
	{
		String frameworkSource = 'UTIL_AsyncChain';
		Integer frameworkRowCount = 3;
		for(Integer i = 0; i < frameworkRowCount; i++)
		{
			TST_Factory.seedLogEntry(new Map<SObjectField, Object>
			{
					LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
					LogEntry__c.ClassMethod__c => 'kern.UTIL_AsyncChain.ChainExecutor.execute',
					LogEntry__c.Origin__c => LOG_Engine.Origin.FRAMEWORK.name(),
					LogEntry__c.Source__c => frameworkSource
			});
		}
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'AccountTriggerHandler.handleAfterUpdate',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'AccountTriggerHandler'
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'Legacy.row'
		});

		SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesInWindow(new SEL_LogEntry.BrowseCriteria(), 200);

		Assert.areEqual(frameworkSource, aggregate.sourceCounts[0].source, 'The busiest source ranks first, by its stored name');
		Assert.areEqual(LOG_Engine.Origin.FRAMEWORK.name(), aggregate.sourceCounts[0].origin, 'The row carries its origin');
		Assert.areEqual(frameworkRowCount, aggregate.sourceCounts[0].rowCount, 'Three rows folded');
		Assert.areEqual(3, aggregate.sourceCounts.size(), 'The two attributed sources and the unattributed group');
	}

	/**
	 * @description The origins list and the exact source apply on the entries read, the ribbon fold, the
	 * problems fold and the body-search leg alike.
	 */
	@IsTest
	private static void shouldFilterByOriginsAndBySource()
	{
		String flowSource = 'Order Intake';
		String flowClassMethod = 'Flow/Order Intake';
		String sharedTerm = 'needle';
		LogEntry__c flowRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_INFO,
				LogEntry__c.ClassMethod__c => flowClassMethod,
				LogEntry__c.Origin__c => LOG_Engine.Origin.FLOW.name(),
				LogEntry__c.Source__c => flowSource,
				LogEntry__c.ShortMessage__c => sharedTerm
		});
		LogEntry__c apexRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_INFO,
				LogEntry__c.ClassMethod__c => 'OrderService.intake',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'OrderService',
				LogEntry__c.ShortMessage__c => sharedTerm
		});

		SEL_LogEntry.BrowseCriteria byOrigin = new SEL_LogEntry.BrowseCriteria();
		byOrigin.origins = new List<String> {LOG_Engine.Origin.FLOW.name()};
		SEL_LogEntry.BrowseCriteria bySource = new SEL_LogEntry.BrowseCriteria();
		bySource.source = flowSource;
		SEL_LogEntry.BrowseCriteria searched = new SEL_LogEntry.BrowseCriteria();
		searched.searchTerm = sharedTerm;
		searched.origins = new List<String> {LOG_Engine.Origin.FLOW.name()};

		List<String> infoOnly = new List<String> {LOG_Engine.LEVEL_INFO};
		QRY_Builder.QueryPage searchedPage = new SEL_LogEntry().findEntriesFiltered(searched, LogEntry__c.CreatedDate, true, 1, 10);
		List<SEL_LogEntry.DerivedSignature> originSignatures = new SEL_LogEntry().foldDerivedSignaturesInWindow(byOrigin, 200, 1, infoOnly);
		List<SEL_LogEntry.DerivedSignature> sourceSignatures = new SEL_LogEntry().foldDerivedSignaturesInWindow(bySource, 200, 1, infoOnly);
		Test.setFixedSearchResults(new List<Id> {flowRow.Id, apexRow.Id});
		Set<Id> originBodyHits = new SEL_LogEntry().findIdsByBodySosl(sharedTerm, byOrigin, 2000);
		Set<Id> sourceBodyHits = new SEL_LogEntry().findIdsByBodySosl(sharedTerm, bySource, 2000);

		Assert.areEqual(1, new SEL_LogEntry().countEntriesInWindow(byOrigin), 'Only the Flow row matches the origin');
		Assert.areEqual(1, new SEL_LogEntry().countEntriesInWindow(bySource), 'Only the Flow row matches the source');
		Assert.areEqual(1, new SEL_LogEntry().summariseEntriesInWindow(byOrigin, 200).sourceCounts.size(), 'The fold honours the origin');
		Assert.areEqual(1, searchedPage.records.size(), 'The searched leg returns the Flow row alone');
		Assert.areEqual(flowRow.Id, searchedPage.records[0].Id, 'The searched leg honours the origin');
		Assert.areEqual(1, originSignatures.size(), 'The problems fold honours the origin: the Apex row folds into no signature');
		Assert.areEqual(flowClassMethod, originSignatures[0].classMethod, 'The one origin-scoped problem is the Flow one');
		Assert.areEqual(1, sourceSignatures.size(), 'The problems fold honours the source: the Apex row folds into no signature');
		Assert.areEqual(flowClassMethod, sourceSignatures[0].classMethod, 'The one source-scoped problem is the Flow one');
		Assert.areEqual(new Set<Id> {flowRow.Id}, originBodyHits, 'The body-search leg narrows the fixed results to the Flow row by the origin alone');
		Assert.areEqual(new Set<Id> {flowRow.Id}, sourceBodyHits, 'The body-search leg narrows the fixed results to the Flow row by the source alone');
	}

	/**
	 * @description A signature whose rows carry more than one origin says Mixed; one whose rows are null against
	 * one origin says that origin; the source rides the fold as the stored name.
	 */
	@IsTest
	private static void shouldCarryOriginAndSourceOnDerivedSignaturesAndSayMixedAcrossOrigins()
	{
		String mixedClassMethod = 'AccountTriggerHandler.handleAfterUpdate';
		String plainClassMethod = 'OrderService.intake';
		String mixedSource = 'AccountTriggerHandler';
		for(String origin : new List<String> {LOG_Engine.Origin.APEX.name(), LOG_Engine.Origin.FLOW.name()})
		{
			TST_Factory.seedLogEntry(new Map<SObjectField, Object>
			{
					LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
					LogEntry__c.ExceptionType__c => 'System.NullPointerException',
					LogEntry__c.ClassMethod__c => mixedClassMethod,
					LogEntry__c.Origin__c => origin,
					LogEntry__c.Source__c => mixedSource,
					LogEntry__c.ShortMessage__c => 'npe'
			});
		}
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ExceptionType__c => 'System.DmlException',
				LogEntry__c.ClassMethod__c => plainClassMethod,
				LogEntry__c.ShortMessage__c => 'dml'
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ExceptionType__c => 'System.DmlException',
				LogEntry__c.ClassMethod__c => plainClassMethod,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'OrderService',
				LogEntry__c.ShortMessage__c => 'dml'
		});

		Map<String, SEL_LogEntry.DerivedSignature> byClassMethod = new Map<String, SEL_LogEntry.DerivedSignature>();
		List<String> errorOnly = new List<String> {LOG_Engine.LEVEL_ERROR};
		for(SEL_LogEntry.DerivedSignature signature : new SEL_LogEntry().foldDerivedSignaturesInWindow(new SEL_LogEntry.BrowseCriteria(), 200, 2, errorOnly))
		{
			byClassMethod.put(signature.classMethod, signature);
		}

		Assert.areEqual(SEL_LogEntry.ORIGIN_MIXED, byClassMethod.get(mixedClassMethod).origin, 'Two origins in one signature say Mixed');
		Assert.areEqual(mixedSource, byClassMethod.get(mixedClassMethod).source, 'The source rides the fold');
		Assert.areEqual(LOG_Engine.Origin.APEX.name(), byClassMethod.get(plainClassMethod).origin, 'Null against one origin says that origin');
		Assert.areEqual(2, byClassMethod.get(plainClassMethod).occurrenceCount, 'The pre-upgrade row and the attributed row stay one problem');
	}

	/**
	 * @description Seeds one forensic sample row (OccurrenceCount__c null) carrying the searchable text
	 * fields the search legs match against, so the SOQL/SOSL/page reads can be asserted without repeating
	 * the builder chain per test.
	 *
	 * @param base The base fingerprint (without the detail: prefix).
	 * @param level The log level (DEBUG/INFO/WARN/ERROR).
	 * @param shortMessage The ShortMessage__c value (the SOQL short-message leg matches this).
	 * @param message The Message__c value (the SOSL body leg matches this).
	 * @param correlationId The CorrelationId__c value (the SOQL correlation leg matches this).
	 *
	 * @return The inserted forensic sample row.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static LogEntry__c seedSearchableRow(String base, String level, String shortMessage, String message, String correlationId)
	{
		return (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + base)
				.withOverride(LogEntry__c.LogLevel__c, level)
				.withOverride(LogEntry__c.ShortMessage__c, shortMessage)
				.withOverride(LogEntry__c.Message__c, message)
				.withOverride(LogEntry__c.CorrelationId__c, correlationId)
				.build();
	}

	/**
	 * @description Seeds one detail: sample row and two rollup: counter rows (two distinct UTC day
	 * buckets) for a base fingerprint, mirroring the production flood-control key shapes, and
	 * back-dates their CreatedDate so first-seen aggregation can be asserted. Returns the detail row.
	 *
	 * @param base The base fingerprint (without the detail:/rollup: prefix).
	 * @param level The log level for all three rows (DEBUG/INFO/WARN/ERROR).
	 * @param dayOneCount The OccurrenceCount__c for the earlier (two-days-ago) rollup row.
	 * @param dayTwoCount The OccurrenceCount__c for the later (one-day-ago) rollup row.
	 *
	 * @return The inserted detail: sample row.
	 */
	private static LogEntry__c seedProblem(String base, String level, Integer dayOneCount, Integer dayTwoCount)
	{
		LogEntry__c detailRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + base,
				LogEntry__c.LogLevel__c => level,
				LogEntry__c.ExceptionType__c => 'System.NullPointerException',
				LogEntry__c.ClassMethod__c => 'AccountTriggerHandler.handleAfterUpdate',
				LogEntry__c.LineNumber__c => 142,
				LogEntry__c.ShortMessage__c => 'Attempt to de-reference a null object',
				LogEntry__c.ExecutionEvent__c => Quiddity.BATCH_APEX.name(),
				LogEntry__c.UserId__c => SEED_USER_ID
		});
		LogEntry__c rollupDayOne = TST_Factory.seedLogRollup(base, UTIL_Date.toUtcDayBucket(Datetime.now().addDays(-2)), level, dayOneCount);
		LogEntry__c rollupDayTwo = TST_Factory.seedLogRollup(base, UTIL_Date.toUtcDayBucket(Datetime.now().addDays(-1)), level, dayTwoCount);
		Test.setCreatedDate(detailRow.Id, Datetime.now().addDays(-2));
		Test.setCreatedDate(rollupDayOne.Id, Datetime.now().addDays(-2));
		Test.setCreatedDate(rollupDayTwo.Id, Datetime.now().addDays(-1));
		return detailRow;
	}

	/**
	 * @description Seeds one forensic log row (OccurrenceCount__c null) for a correlated operation,
	 * carrying the given correlation id and a distinct fingerprint, and back-dates its CreatedDate so the
	 * ordered correlated-trace read can be asserted. Returns the inserted row.
	 *
	 * @param base The base fingerprint (without the detail:/rollup: prefix), distinct per hop.
	 * @param classMethod The Class.method whose first segment is the hop's source class.
	 * @param correlationId The CorrelationId__c tying the hop to one logical operation.
	 * @param createdDate The CreatedDate to back-date the hop to, so the ascending order can be asserted.
	 *
	 * @return The inserted forensic hop row.
	 */
	private static LogEntry__c seedCorrelatedHop(String base, String classMethod, String correlationId, Datetime createdDate)
	{
		LogEntry__c hop = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + base)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, classMethod)
				.withOverride(LogEntry__c.LineNumber__c, 42)
				.withOverride(LogEntry__c.ShortMessage__c, 'hop ' + classMethod)
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.QUEUEABLE.name())
				.withOverride(LogEntry__c.CorrelationId__c, correlationId)
				.build();
		Test.setCreatedDate(hop.Id, createdDate);
		return hop;
	}

	/**
	 * @description Seeds `occurrences` plain forensic rows (Fingerprint__c and OccurrenceCount__c left null,
	 * so the derived fold treats them as input) for one signature, omitting any null identity field so it
	 * defaults to null and the ADR-6 / null-identity branches can be exercised. Returns the inserted rows so
	 * a test can back-date their CreatedDate for window / MIN / MAX assertions.
	 *
	 * @param exceptionType The ExceptionType__c value, or null to leave it unset.
	 * @param classMethod The ClassMethod__c value, or null to leave it unset.
	 * @param lineNumber The LineNumber__c value, or null to leave it unset.
	 * @param level The LogLevel__c value for every seeded row.
	 * @param shortMessage The ShortMessage__c value (surfaced as the derived label via MAX).
	 * @param occurrences The number of rows to seed.
	 *
	 * @return The inserted forensic rows.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static List<LogEntry__c> seedDerivedOccurrences(String exceptionType, String classMethod, Integer lineNumber, String level, String shortMessage, Integer occurrences)
	{
		TST_Builder.Builder builder = TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, level)
				.withOverride(LogEntry__c.ShortMessage__c, shortMessage)
				.withCount(occurrences);
		if(exceptionType != null)
		{
			builder = builder.withOverride(LogEntry__c.ExceptionType__c, exceptionType);
		}
		if(classMethod != null)
		{
			builder = builder.withOverride(LogEntry__c.ClassMethod__c, classMethod);
		}
		if(lineNumber != null)
		{
			builder = builder.withOverride(LogEntry__c.LineNumber__c, lineNumber);
		}
		return builder.buildList();
	}

	/**
	 * @description Starts a builder for the standard NullPointer derived row (ERROR level, the NPE
	 * exception/method/label constants) so the scope tests can vary just the scope field under test
	 * without repeating the identity overrides.
	 *
	 * @return The builder, ready for scope-field overrides and build.
	 */
	private static TST_Builder.Builder newDerivedNullPointerRowBuilder()
	{
		return TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, DERIVED_EXCEPTION_NPE)
				.withOverride(LogEntry__c.ClassMethod__c, DERIVED_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.ShortMessage__c, DERIVED_LABEL_NPE);
	}

	/**
	 * @description Starts a builder for the standard DML derived row (ERROR level, the DML
	 * exception/method/label constants): the second, distinct signature the scope tests seed beside the
	 * NullPointer row so the scope filter has something to exclude.
	 *
	 * @return The builder, ready for scope-field overrides and build.
	 */
	private static TST_Builder.Builder newDerivedDmlRowBuilder()
	{
		return TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, DERIVED_EXCEPTION_DML)
				.withOverride(LogEntry__c.ClassMethod__c, DERIVED_METHOD_OPPORTUNITY)
				.withOverride(LogEntry__c.ShortMessage__c, DERIVED_LABEL_DML);
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * low-privilege tests to seed the LogEntry__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the low-privilege tests to exercise SEL_LogEntry reads such as findByMethod and
	 * prove the framework-owned selector elevates internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description The newest-rows read spans BOTH reference legs and deduplicates them: an entry
	 * matched by correlation, one matched only by its record reference, and one matched by both
	 * return as three rows, newest first through the Id tiebreak on same-transaction timestamps; an
	 * unrelated forensic row and an occurrence rollup carrying the correlation never appear.
	 */
	@IsTest
	private static void shouldFindNewestRowsAcrossCorrelationAndRecordLegs()
	{
		String correlationId = UTIL_Random.randomUUID();
		Id recordId = UTIL_Random.randomId(AsyncChainExecution__c.SObjectType);
		LogEntry__c correlationOnly = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.CorrelationId__c, correlationId).build();
		LogEntry__c recordOnly = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();
		LogEntry__c bothReferences = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.CorrelationId__c, correlationId)
				.withOverride(LogEntry__c.RecordId__c, recordId)
				.build();
		TST_Builder.of(LogEntry__c.SObjectType).build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.CorrelationId__c, correlationId)
				.withOverride(LogEntry__c.OccurrenceCount__c, 3)
				.build();

		List<LogEntry__c> rows = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(correlationId, recordId, 10);

		Assert.areEqual(3, rows.size(), 'Exactly the three referencing forensic rows return, deduplicated across the legs');
		Assert.areEqual(bothReferences.Id, rows[0].Id, 'The newest row leads: same-timestamp order is fixed by the Id tiebreak');
		Assert.areEqual(recordOnly.Id, rows[1].Id, 'The record-referenced row follows in insert order');
		Assert.areEqual(correlationOnly.Id, rows[2].Id, 'The correlation-only row is oldest');
	}

	/**
	 * @description The single-leg cap: with a null record reference only the correlation leg reads,
	 * and it returns the newest rows up to the supplied limit.
	 */
	@IsTest
	private static void shouldCapNewestRowsAtTheRowLimit()
	{
		String correlationId = UTIL_Random.randomUUID();
		TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.CorrelationId__c, correlationId).withCount(2).buildList();
		LogEntry__c olderOfTheNewest = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.CorrelationId__c, correlationId).build();
		LogEntry__c newest = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.CorrelationId__c, correlationId).build();

		List<LogEntry__c> rows = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(correlationId, null, 2);

		Assert.areEqual(2, rows.size(), 'The read caps at the supplied row limit');
		Assert.areEqual(newest.Id, rows[0].Id, 'The newest row survives the cap');
		Assert.areEqual(olderOfTheNewest.Id, rows[1].Id, 'The second-newest row survives the cap');
	}

	/**
	 * @description The cross-leg merge cap, the rule the two-leg design exists to
	 * guarantee: when BOTH legs fill to the limit, the final bounded fetch returns the true global
	 * newest rows across the union, not either leg's slice. Three correlation-only rows inserted
	 * first and three record-only rows after, read with a limit of three, must yield exactly the
	 * record-only block newest-first. Dropping or inverting the union query's ordering fails this
	 * test while every test of a single leg still passes.
	 */
	@IsTest
	private static void shouldMergeBothLegsAndKeepOnlyTheGlobalNewestRows()
	{
		String correlationId = UTIL_Random.randomUUID();
		Id recordId = UTIL_Random.randomId(AsyncChainExecution__c.SObjectType);
		TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.CorrelationId__c, correlationId).withCount(3).buildList();
		LogEntry__c oldestRecordReferenced = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();
		LogEntry__c middleRecordReferenced = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();
		LogEntry__c newestRecordReferenced = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();

		List<LogEntry__c> rows = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(correlationId, recordId, 3);

		Assert.areEqual(3, rows.size(), 'The merged read caps at the supplied row limit');
		Assert.areEqual(newestRecordReferenced.Id, rows[0].Id, 'The global newest row leads the merged result');
		Assert.areEqual(middleRecordReferenced.Id, rows[1].Id, 'The global second-newest row follows');
		Assert.areEqual(oldestRecordReferenced.Id, rows[2].Id, 'The record-only block wholly displaces the older correlation leg');
	}

	/**
	 * @description Each reference leg skips independently: with a blank correlation the record leg
	 * still reads alone, and with both references absent the read returns empty without querying.
	 */
	@IsTest
	private static void shouldSkipReferenceLegsIndependently()
	{
		Id recordId = UTIL_Random.randomId(AsyncChainExecution__c.SObjectType);
		LogEntry__c recordReferenced = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();

		List<LogEntry__c> recordLegOnly = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(UTIL_String.EMPTY, recordId, 5);
		List<LogEntry__c> bothLegsSkipped = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(UTIL_String.EMPTY, null, 5);

		Assert.areEqual(1, recordLegOnly.size(), 'The record leg reads alone when the correlation leg skips');
		Assert.areEqual(recordReferenced.Id, recordLegOnly[0].Id, 'The record-referenced row returns from the lone leg');
		Assert.isTrue(bothLegsSkipped.isEmpty(), 'Both legs skipped yields an empty read');
	}

	/**
	 * @description Tests the batched representative read's empty contract: a null signature list and an
	 * empty one each return an empty list without issuing a query, matching the selector convention that
	 * blank input never becomes an unbounded read. The resolution behaviour itself is proven through the
	 * problems page in CTRL_LogConsole_TEST.
	 */
	@IsTest
	private static void shouldReturnEmptyRepresentativesForNullOrEmptySignatures()
	{
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();

		List<LogEntry__c> forNull = new SEL_LogEntry().findDerivedRepresentatives(null, new SEL_LogEntry.BrowseCriteria());
		List<LogEntry__c> forEmpty = new SEL_LogEntry().findDerivedRepresentatives(new List<SEL_LogEntry.DerivedSignature>(), null);

		Assert.isTrue(forNull.isEmpty(), 'A null signature list yields an empty read');
		Assert.isTrue(forEmpty.isEmpty(), 'An empty signature list yields an empty read');
		Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Neither empty-contract call should issue a query');
	}

	/**
	 * @description Seeds one forensic entry carrying a correlation id and a root (null for an entry persisted before
	 * roots were written), back-dated so the ordered edge reads can be asserted.
	 *
	 * @param correlationId The entry's own tracking id.
	 * @param rootCorrelationId The action's id, or null for a legacy entry.
	 * @param shortMessage The short message, distinct per row so a search can pick one.
	 * @param createdDate The CreatedDate to back-date the row to.
	 *
	 * @return The inserted row.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static LogEntry__c seedScopedEntry(String correlationId, String rootCorrelationId, String shortMessage, Datetime createdDate)
	{
		LogEntry__c row = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withOverride(LogEntry__c.ShortMessage__c, shortMessage)
				.withOverride(LogEntry__c.CorrelationId__c, correlationId)
				.withOverride(LogEntry__c.RootCorrelationId__c, rootCorrelationId)
				.build();
		Test.setCreatedDate(row.Id, createdDate);
		return row;
	}
}