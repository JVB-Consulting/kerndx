// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for the CTRL_LogConsole console controller — the distinct-problems fold,
 * the flat entries page, the scope summary, and the single-entry detail (with governor-limit bars).
 *
 * @see CTRL_LogConsole
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date June 2026, July 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class CTRL_LogConsole_TEST
{
	/**
	 * @description Base fingerprint (without the detail:/rollup: prefix) for the seeded NullPointer problem.
	 */
	private static final String BASE_NULL_POINTER = 'NullPointer:AccountTriggerHandler.handleAfterUpdate';

	/**
	 * @description A second, distinct base fingerprint so multi-signature folds can be asserted.
	 */
	private static final String BASE_OTHER = 'NullPointer:OpportunityService.recalculate';

	/**
	 * @description A third, distinct base fingerprint for the correlated-trace tests, so each hop carries
	 * its own unique fingerprint key.
	 */
	private static final String BASE_NOTIFICATION = 'NullPointer:NotificationService.send';

	/**
	 * @description The correlation id shared by the seeded hops of one logical operation, so the ordered
	 * correlated trace can be asserted.
	 */
	private static final String TRACE_CORRELATION_ID = 'log-console-trace-correlation';

	/**
	 * @description Class.method for the Account-trigger signature; its first segment is the source class.
	 */
	private static final String CLASS_METHOD_ACCOUNT = 'AccountTriggerHandler.handleAfterUpdate';

	/**
	 * @description Class.method for the Opportunity-service signature, a distinct source class.
	 */
	private static final String CLASS_METHOD_OPPORTUNITY = 'OpportunityService.recalculate';

	/**
	 * @description Window covering seven days, so the back-dated rollup rows fall inside the scope.
	 */
	private static final Integer WINDOW_SEVEN_DAYS = 10080;

	/**
	 * @description The default twenty-four hour window.
	 */
	private static final Integer WINDOW_ONE_DAY = 1440;

	/**
	 * @description A ContextData__c value that is not valid JSON, so the controller falls back to carrying
	 * it through verbatim rather than unwrapping it.
	 */
	private static final String MALFORMED_CONTEXT_JSON = '{ this is not valid json';

	/**
	 * @description A Limits__c value whose first line lacks the 'label: used of maximum' shape and whose
	 * second line has a non-numeric used value, so only the third (valid) line yields a bar.
	 */
	private static final String MALFORMED_LIMITS_TEXT = 'Junk line without the expected shape\nHeap Size: not-a-number of 6000000\nQueries: 5 of 100';

	/**
	 * @description Tests that getLogProblems folds the rollup rows for a signature into one distinct
	 * problem carrying SUM(OccurrenceCount__c), the sample's Log Number, and a first-seen earlier
	 * than its last-seen.
	 */
	@IsTest
	private static void shouldReturnDistinctProblemsWithFoldedCounts()
	{
		LogEntry__c detailRow = seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});
		String expectedLogNumber = new SEL_LogEntry().findByIdForConsole(detailRow.Id).Name;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};
		request.sortField = 'occurrenceCount';
		request.pageSize = 50;
		request.pageNumber = 1;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, result.totalCount, 'The two rollup rows fold into one distinct problem');
		Assert.areEqual(1, result.records.size(), 'The page holds the single folded problem');
		Assert.areEqual(40, result.records[0].occurrenceCount, 'Occurrences should be SUM(17, 23)');
		Assert.areEqual(expectedLogNumber, result.records[0].logNumber, 'Log Number should come from the detail sample');
		Assert.isNotNull(result.records[0].firstSeen, 'First-seen should be set from the rollup fold');
		Assert.isNotNull(result.records[0].lastSeen, 'Last-seen should be set from the rollup fold');
		Assert.isTrue(result.records[0].lastSeen >= result.records[0].firstSeen, 'Last-seen is at or after first-seen');
		Assert.isTrue(result.records[0].firstSeen < Datetime.now().addDays(-1), 'First-seen is the earliest (two-days-ago) rollup');
	}

	/**
	 * @description The canonical recurring-error regression: a problem first seen days ago but still
	 * firing today must appear in a recent window, because the distinct list is driven off in-window
	 * rollup activity, not the frozen first-seen CreatedDate of the detail sample.
	 */
	@IsTest
	private static void shouldShowLongLivedProblemInRecentWindow()
	{
		LogEntry__c detailRow = seedNpeDetail(new Map<SObjectField, Object>());
		TST_Factory.seedLogRollup(BASE_NULL_POINTER, UTIL_Date.toUtcDayBucket(Datetime.now()), LOG_Engine.LEVEL_ERROR, 9);
		Test.setCreatedDate(detailRow.Id, Datetime.now().addDays(-3));

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_ONE_DAY;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		request.sortField = 'occurrenceCount';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, result.records.size(), 'A three-days-old problem still firing today appears in a 24h window');
		Assert.areEqual(9, result.records[0].occurrenceCount, 'Only the in-window rollup count is folded');
	}

	/**
	 * @description Tests that getLogProblems sorts the distinct problems by occurrence count descending.
	 */
	@IsTest
	private static void shouldSortProblemsByCountDescending()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_OPPORTUNITY, new List<Integer> {2, 3});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		request.sortField = 'occurrenceCount';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, result.records.size(), 'Both signatures should fold into two distinct problems');
		Assert.areEqual(40, result.records[0].occurrenceCount, 'The highest-count problem should sort first');
		Assert.areEqual(5, result.records[1].occurrenceCount, 'The lower-count problem should sort second');
	}

	/**
	 * @description Tests that getLogEntries returns the flat forensic rows (detail samples and plain
	 * rows) and excludes the rollup counter rows.
	 */
	@IsTest
	private static void shouldReturnFlatEntriesPage()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withCount(3)
				.buildList();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.pageSize = 50;
		request.pageNumber = 1;

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage result = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(4, result.totalCount, 'One detail sample plus three plain rows; the two rollups are excluded');
		Assert.areEqual(4, result.records.size(), 'The page should hold all four forensic rows');
	}

	/**
	 * @description Tests that a free-text search narrows the distinct-problems view by matching the
	 * SAMPLE's text (not the rollup counters, which carry no text): a class-name term returns only the
	 * matching signature, a shared-message term returns both, and an unmatched term returns none. Proves
	 * the rollup fold is not zeroed out by the search filter.
	 */
	@IsTest
	private static void shouldFilterDistinctProblemsBySearchTerm()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_OPPORTUNITY, new List<Integer> {5});

		CTRL_LogConsole.DTO_Request byClass = new CTRL_LogConsole.DTO_Request();
		byClass.windowMinutes = WINDOW_SEVEN_DAYS;
		byClass.searchTerm = 'OpportunityService';

		CTRL_LogConsole.DTO_Request bySharedMessage = new CTRL_LogConsole.DTO_Request();
		bySharedMessage.windowMinutes = WINDOW_SEVEN_DAYS;
		bySharedMessage.searchTerm = 'de-reference';

		CTRL_LogConsole.DTO_Request unmatched = new CTRL_LogConsole.DTO_Request();
		unmatched.windowMinutes = WINDOW_SEVEN_DAYS;
		unmatched.searchTerm = 'no-such-token-zzz';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage byClassPage = CTRL_LogConsole.getLogProblems(JSON.serialize(byClass));
		CTRL_LogConsole.DTO_LogProblemPage bySharedMessagePage = CTRL_LogConsole.getLogProblems(JSON.serialize(bySharedMessage));
		CTRL_LogConsole.DTO_LogProblemPage unmatchedPage = CTRL_LogConsole.getLogProblems(JSON.serialize(unmatched));
		Test.stopTest();

		Assert.areEqual(1, byClassPage.totalCount, 'A class-name term should match only the sample whose ClassMethod__c contains it');
		Assert.areEqual(2, bySharedMessagePage.totalCount, 'A term in the shared short message should match both signatures');
		Assert.areEqual(0, unmatchedPage.totalCount, 'A term matching no sample should yield an empty distinct view (the rollup fold is not zeroed)');
	}

	/**
	 * @description Tests that the distinct-problems in-memory matcher covers every sample search field the
	 * ribbon's SOQL leg cannot reach on text-less rollups: a term found only in the sample's Message__c,
	 * only in its StackTrace__c, or only in its CorrelationId__c (matched as text, not as the correlation
	 * scope filter) each return exactly that one signature. Pins the single-sourced field list — dropping
	 * any leg fails its needle.
	 */
	@IsTest
	private static void shouldMatchDistinctProblemsAcrossAllSampleSearchFields()
	{
		String baseBody = 'body-needle-base';
		String baseStack = 'stack-needle-base';
		String baseCorrelation = 'correlation-needle-base';
		seedSampleSearchProblem(baseBody, new Map<SObjectField, Object> {LogEntry__c.Message__c => 'bodyonlyneedle appears in the long body'});
		seedSampleSearchProblem(baseStack, new Map<SObjectField, Object> {LogEntry__c.StackTrace__c => 'Class.Alpha.run: line 12 stackonlyneedle'});
		seedSampleSearchProblem(baseCorrelation, new Map<SObjectField, Object> {LogEntry__c.CorrelationId__c => 'corridneedle-777'});

		CTRL_LogConsole.DTO_Request byBody = new CTRL_LogConsole.DTO_Request();
		byBody.windowMinutes = WINDOW_SEVEN_DAYS;
		byBody.searchTerm = 'bodyonlyneedle';

		CTRL_LogConsole.DTO_Request byStack = new CTRL_LogConsole.DTO_Request();
		byStack.windowMinutes = WINDOW_SEVEN_DAYS;
		byStack.searchTerm = 'stackonlyneedle';

		CTRL_LogConsole.DTO_Request byCorrelationText = new CTRL_LogConsole.DTO_Request();
		byCorrelationText.windowMinutes = WINDOW_SEVEN_DAYS;
		byCorrelationText.searchTerm = 'corridneedle';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage bodyPage = CTRL_LogConsole.getLogProblems(JSON.serialize(byBody));
		CTRL_LogConsole.DTO_LogProblemPage stackPage = CTRL_LogConsole.getLogProblems(JSON.serialize(byStack));
		CTRL_LogConsole.DTO_LogProblemPage correlationPage = CTRL_LogConsole.getLogProblems(JSON.serialize(byCorrelationText));
		Test.stopTest();

		Assert.areEqual(1, bodyPage.totalCount, 'A term found only in the sample Message__c body should match exactly that signature');
		Assert.areEqual(1, stackPage.totalCount, 'A term found only in the sample StackTrace__c should match exactly that signature');
		Assert.areEqual(1, correlationPage.totalCount, 'A term found only in the sample CorrelationId__c should match it as text');
	}

	/**
	 * @description Seeds one distinct problem (detail sample plus rollup counter, both in-window) whose
	 * sample carries the supplied field overrides on top of a neutral text baseline, so a search-field
	 * test can isolate a needle in exactly one field.
	 *
	 * @param base The base fingerprint for the detail and rollup keys.
	 * @param overrides The sample fields carrying the isolated needle.
	 */
	private static void seedSampleSearchProblem(String base, Map<SObjectField, Object> overrides)
	{
		Map<SObjectField, Object> sampleFields = new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + base,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.ShortMessage__c => 'neutral sample text',
				LogEntry__c.ExecutionEvent__c => Quiddity.BATCH_APEX.name()
		};
		sampleFields.putAll(overrides);
		LogEntry__c sample = TST_Factory.seedLogEntry(sampleFields);
		Test.setCreatedDate(sample.Id, Datetime.now().addHours(-1));
		LogEntry__c rollup = TST_Factory.seedLogRollup(base, UTIL_Date.toUtcDayBucket(Datetime.now()), LOG_Engine.LEVEL_ERROR, 3);
		Test.setCreatedDate(rollup.Id, Datetime.now().addHours(-1));
	}

	/**
	 * @description Tests that a correlation deep-link narrows the distinct-problems view to the sample
	 * carrying that CorrelationId__c, and excludes signatures whose sample has no matching correlation.
	 */
	@IsTest
	private static void shouldFilterDistinctProblemsByCorrelationDeepLink()
	{
		LogEntry__c correlatedSample = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.ShortMessage__c => 'Attempt to de-reference a null object',
				LogEntry__c.ExecutionEvent__c => Quiddity.BATCH_APEX.name(),
				LogEntry__c.CorrelationId__c => TRACE_CORRELATION_ID
		});
		Test.setCreatedDate(correlatedSample.Id, Datetime.now().addHours(-1));
		LogEntry__c correlatedRollup = TST_Factory.seedLogRollup(BASE_NULL_POINTER, UTIL_Date.toUtcDayBucket(Datetime.now()), LOG_Engine.LEVEL_ERROR, 9);
		Test.setCreatedDate(correlatedRollup.Id, Datetime.now().addHours(-1));
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_WARN, CLASS_METHOD_OPPORTUNITY, new List<Integer> {4});

		CTRL_LogConsole.DTO_Request matching = new CTRL_LogConsole.DTO_Request();
		matching.windowMinutes = WINDOW_SEVEN_DAYS;
		matching.correlationId = TRACE_CORRELATION_ID;

		CTRL_LogConsole.DTO_Request other = new CTRL_LogConsole.DTO_Request();
		other.windowMinutes = WINDOW_SEVEN_DAYS;
		other.correlationId = 'a-different-correlation';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage matchingPage = CTRL_LogConsole.getLogProblems(JSON.serialize(matching));
		CTRL_LogConsole.DTO_LogProblemPage otherPage = CTRL_LogConsole.getLogProblems(JSON.serialize(other));
		Test.stopTest();

		Assert.areEqual(1, matchingPage.totalCount, 'Only the sample carrying the deep-linked correlation should show');
		Assert.areEqual(0, otherPage.totalCount, 'A non-matching correlation deep-link should exclude every signature');
	}

	/**
	 * @description Tests that getLogEntries unions both search legs: the SOQL leg (short message ∪
	 * correlation id) and the SOSL body leg (modelled with Test.setFixedSearchResults), so a short-message
	 * match and a body-only match both surface.
	 */
	@IsTest
	private static void shouldUnionDualLegSearchInEntries()
	{
		LogEntry__c shortMatch = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'searchneedle in the short message')
				.build();
		LogEntry__c bodyMatch = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.ShortMessage__c, 'plain short message')
				.withOverride(LogEntry__c.Message__c, 'searchneedle hidden in the long body')
				.build();
		Test.setFixedSearchResults(new List<Id> {bodyMatch.Id});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'searchneedle';

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage result = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Test.stopTest();

		Set<Id> returnedIds = new Set<Id>();
		for(CTRL_LogConsole.DTO_LogEntrySummary record : result.records)
		{
			returnedIds.add(record.id);
		}
		Assert.areEqual(2, result.totalCount, 'The union should surface both the short-message match and the body match');
		Assert.isTrue(returnedIds.contains(shortMatch.Id), 'The SOQL leg should contribute the short-message match');
		Assert.isTrue(returnedIds.contains(bodyMatch.Id), 'The SOSL leg should contribute the body match');
		Assert.isFalse(result.resultsTruncated, 'Two matches under the cap should not flag the page as capped');
	}

	/**
	 * @description Tests that getLogEntries flags the page capped when the search match count reaches the
	 * candidate cap (lowered via the @TestVisible cap so the branch runs without seeding thousands of rows).
	 */
	@IsTest
	private static void shouldFlagCappedWhenSearchHitsCap()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'cappedneedle one')
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'cappedneedle two')
				.build();
		CTRL_LogConsole.PROBLEM_CANDIDATE_CAP = 1;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'cappedneedle';

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage result = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Test.stopTest();

		Assert.isTrue(result.resultsTruncated, 'A match count reaching the cap should flag the page capped');
	}

	/**
	 * @description Tests that getLogEntries keeps the correlation deep-link scope when a free-text search term
	 * is also active: two forensic rows whose short message carries the term but under different correlation
	 * ids yield only the row matching the requested correlation. Guards the Chain-Monitor deep-link + search
	 * path, where the correlation filter was previously dropped the moment a search term was present.
	 */
	@IsTest
	private static void shouldKeepCorrelationScopeInEntriesUnderSearch()
	{
		LogEntry__c matching = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'needleSHARED in the short message')
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ShortMessage__c, 'needleSHARED in the short message')
				.withOverride(LogEntry__c.CorrelationId__c, 'a-different-correlation')
				.build();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'needleSHARED';
		request.correlationId = TRACE_CORRELATION_ID;

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage result = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, result.totalCount, 'The correlation scope must survive an active search term: only the row under the requested correlation should return');
		Assert.areEqual(matching.Id, result.records[0].id, 'The single returned entry should be the one matching the requested correlation');
	}

	/**
	 * @description Tests that getLogSummary folds occurrences across the scope, reports per-level totals,
	 * and names the top source class with its share of occurrences.
	 */
	@IsTest
	private static void shouldComputeSummaryOverScope()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_WARN, CLASS_METHOD_OPPORTUNITY, new List<Integer> {4, 6});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(50, summary.totalOccurrences, 'Total occurrences should be 40 (ERROR) + 10 (WARN)');
		CTRL_LogConsole.DTO_LevelSummary errorSummary = levelSummaryFor(summary, LOG_Engine.LEVEL_ERROR);
		Assert.isNotNull(errorSummary, 'There should be a per-level entry for ERROR');
		Assert.areEqual(40, errorSummary.occurrences, 'ERROR occurrences should fold to 40');
		Assert.areEqual(1, errorSummary.distinctCount, 'There is one distinct ERROR signature');
		Assert.areEqual('AccountTriggerHandler', summary.topSources[0].name, 'The 40-occurrence class is the top source');
		Assert.areEqual(40, summary.topSources[0].count, 'The top source folded 40 occurrences');
		Assert.areEqual(80, summary.topSources[0].percent, 'The top source is 40 of 50 occurrences');
	}

	/**
	 * @description Tests that an active free-text search scopes the grouped-problems summary to the matching
	 * signatures WITHOUT zeroing it (the A1 regression): the rollup fold must ignore the search term (rollup
	 * counter rows carry no message text), while the in-memory sample scope narrows the folded totals. A
	 * class-name term folds only its signature's occurrences; a shared-message term folds both.
	 */
	@IsTest
	private static void shouldScopeSummaryToSearchWithoutZeroing()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {40});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_OPPORTUNITY, new List<Integer> {10});

		CTRL_LogConsole.DTO_Request byClass = new CTRL_LogConsole.DTO_Request();
		byClass.windowMinutes = WINDOW_SEVEN_DAYS;
		byClass.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		byClass.searchTerm = 'OpportunityService';

		CTRL_LogConsole.DTO_Request bySharedMessage = new CTRL_LogConsole.DTO_Request();
		bySharedMessage.windowMinutes = WINDOW_SEVEN_DAYS;
		bySharedMessage.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		bySharedMessage.searchTerm = 'de-reference';

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary byClassSummary = CTRL_LogConsole.getLogSummary(JSON.serialize(byClass));
		CTRL_LogConsole.DTO_LogSummary bySharedMessageSummary = CTRL_LogConsole.getLogSummary(JSON.serialize(bySharedMessage));
		Test.stopTest();

		Assert.areEqual(10, byClassSummary.totalOccurrences, 'A class-name search must fold only that signature (10), never zero the ribbon');
		Assert.areEqual(1, byClassSummary.distinctCount, 'Only the OpportunityService signature is in scope for the class-name search');
		Assert.areEqual(50, bySharedMessageSummary.totalOccurrences, 'A shared-message term should fold both signatures (40 + 10)');
		Assert.areEqual(2, bySharedMessageSummary.distinctCount, 'Both signatures share the searched message');
	}

	/**
	 * @description Tests that the grouped-problems summary ranks the top THREE source classes by folded
	 * occurrence count (descending), each carrying its raw count and its whole-number share of the total, and
	 * excludes the fourth-ranked source.
	 */
	@IsTest
	private static void shouldReturnTopThreeSourcesRankedByOccurrences()
	{
		seedProblem('NullPointer:AlphaService.run', LOG_Engine.LEVEL_ERROR, 'AlphaService.run', new List<Integer> {40});
		seedProblem('NullPointer:BravoService.run', LOG_Engine.LEVEL_ERROR, 'BravoService.run', new List<Integer> {30});
		seedProblem('NullPointer:CharlieService.run', LOG_Engine.LEVEL_ERROR, 'CharlieService.run', new List<Integer> {20});
		seedProblem('NullPointer:DeltaService.run', LOG_Engine.LEVEL_ERROR, 'DeltaService.run', new List<Integer> {10});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(100, summary.totalOccurrences, 'Total occurrences should be 40 + 30 + 20 + 10');
		Assert.areEqual(3, summary.topSources.size(), 'Exactly the top three sources are ranked; the fourth is excluded');
		Assert.areEqual('AlphaService', summary.topSources[0].name, 'The 40-occurrence source ranks first');
		Assert.areEqual(40, summary.topSources[0].count, 'The first source carries its folded occurrence count');
		Assert.areEqual(40, summary.topSources[0].percent, 'The first source is 40 of 100 occurrences');
		Assert.areEqual('BravoService', summary.topSources[1].name, 'The 30-occurrence source ranks second');
		Assert.areEqual('CharlieService', summary.topSources[2].name, 'The 20-occurrence source ranks third');
	}

	/**
	 * @description Tests that two sources with an equal folded occurrence count are ranked by source name
	 * ascending, so the tie-break direction is behaviourally pinned (a flipped tie-break would fail here).
	 */
	@IsTest
	private static void shouldBreakTopSourceTiesByNameAscending()
	{
		seedProblem('NullPointer:ZuluService.run', LOG_Engine.LEVEL_ERROR, 'ZuluService.run', new List<Integer> {20});
		seedProblem('NullPointer:AlphaService.run', LOG_Engine.LEVEL_ERROR, 'AlphaService.run', new List<Integer> {20});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, summary.topSources.size(), 'Both equal-count sources are ranked');
		Assert.areEqual('AlphaService', summary.topSources[0].name, 'On a count tie the source name breaks it ascending (Alpha before Zulu)');
		Assert.areEqual('ZuluService', summary.topSources[1].name, 'Zulu ranks after Alpha on the name-ascending tie-break');
	}

	/**
	 * @description Tests that getEntrySummary folds the forensic rows (OccurrenceCount__c null) in the window
	 * into a total row count and a per-level row-count breakdown, excluding the rollup: counter rows, and that
	 * the total equals the sum of the per-level counts (the ribbon invariant).
	 */
	@IsTest
	private static void shouldSummariseAllEntriesByLevelWithTotalEqualToSum()
	{
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, 'AlphaService.run', 'an error row');
		seedForensicEntries(2, LOG_Engine.LEVEL_WARN, 'BravoService.run', 'a warning row');
		seedForensicEntries(1, LOG_Engine.LEVEL_INFO, 'CharlieService.run', 'an info row');
		TST_Factory.seedLogRollup(BASE_NULL_POINTER, UTIL_Date.toUtcDayBucket(Datetime.now()), LOG_Engine.LEVEL_ERROR, 99);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(6, summary.totalRows, 'Six forensic rows should count; the OccurrenceCount rollup is excluded');
		Integer perLevelSum = 0;
		for(CTRL_LogConsole.DTO_EntryLevelCount levelCount : summary.perLevel)
		{
			perLevelSum += levelCount.rowCount;
		}
		Assert.areEqual(summary.totalRows, perLevelSum, 'Total rows must equal the sum of the per-level counts (the ribbon invariant)');
		Assert.areEqual(3, entryLevelCountFor(summary, LOG_Engine.LEVEL_ERROR), 'Three ERROR forensic rows');
		Assert.areEqual(2, entryLevelCountFor(summary, LOG_Engine.LEVEL_WARN), 'Two WARN forensic rows');
		Assert.areEqual(1, entryLevelCountFor(summary, LOG_Engine.LEVEL_INFO), 'One INFO forensic row');
	}

	/**
	 * @description Tests that getEntrySummary ranks the top THREE source classes by forensic row count
	 * (descending), each carrying its row count and its share of the total, and excludes the fourth source.
	 */
	@IsTest
	private static void shouldRankTopThreeEntrySourcesByRowCount()
	{
		seedForensicEntries(4, LOG_Engine.LEVEL_ERROR, 'AlphaService.run', 'alpha row');
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, 'BravoService.run', 'bravo row');
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, 'CharlieService.run', 'charlie row');
		seedForensicEntries(1, LOG_Engine.LEVEL_ERROR, 'DeltaService.run', 'delta row');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(10, summary.totalRows, 'Ten forensic rows in total');
		Assert.areEqual(3, summary.topSources.size(), 'Exactly the top three sources are ranked; the fourth is excluded');
		Assert.areEqual('AlphaService', summary.topSources[0].name, 'The four-row source ranks first');
		Assert.areEqual(4, summary.topSources[0].count, 'The first source carries its forensic row count');
		Assert.areEqual(40, summary.topSources[0].percent, 'The first source is 4 of 10 rows');
		Assert.areEqual('BravoService', summary.topSources[1].name, 'The three-row source ranks second');
		Assert.areEqual('CharlieService', summary.topSources[2].name, 'The two-row source ranks third');
	}

	/**
	 * @description Tests that a forensic row with no class attribution (null ClassMethod__c) still counts in
	 * the ribbon total and per-level breakdown but produces no blank source bucket — the blank-key guard on
	 * the source fold skips it instead of ranking an unnamed source.
	 */
	@IsTest
	private static void shouldSkipBlankSourceBucketForUnattributedRows()
	{
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, 'AlphaService.run', 'an attributed row');
		seedForensicEntries(1, LOG_Engine.LEVEL_ERROR, null, 'a row with no class attribution');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(3, summary.totalRows, 'The unattributed row still counts in the ribbon total');
		Assert.areEqual(1, summary.topSources.size(), 'Only the attributed source is ranked; no blank bucket appears');
		Assert.areEqual('AlphaService', summary.topSources[0].name, 'The attributed source is the only ranked bucket');
	}

	/**
	 * @description Tests that getEntrySummary scopes the all-entries ribbon to the free-text search (matched
	 * against the short message), so only the rows whose short message carries the term are counted.
	 */
	@IsTest
	private static void shouldScopeEntrySummaryToSearchTerm()
	{
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, 'AlphaService.run', 'alpha searchneedle row');
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, 'BravoService.run', 'bravo unrelated row');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'searchneedle';

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, summary.totalRows, 'Only the two rows whose short message carries the search term should count');
		Assert.areEqual(1, summary.topSources.size(), 'Only the matching source remains under the search scope');
		Assert.areEqual('AlphaService', summary.topSources[0].name, 'The matching source is AlphaService');
	}

	/**
	 * @description Tests that getEntrySummary counts SOSL body matches, not only short-message/correlation LIKE
	 * matches, so the all-entries ribbon totals equal the entries table for the same term. A row whose body
	 * (Message__c) carries the term but whose short message does not must be counted in the ribbon.
	 */
	@IsTest
	private static void shouldCountBodyMatchesInEntrySummary()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'AlphaService.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'searchneedle in the short message')
				.build();
		LogEntry__c bodyMatch = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.ClassMethod__c, 'BravoService.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'plain short message')
				.withOverride(LogEntry__c.Message__c, 'searchneedle hidden in the long body')
				.build();
		Test.setFixedSearchResults(new List<Id> {bodyMatch.Id});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'searchneedle';

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, summary.totalRows, 'The ribbon must count the SOSL body match as well as the short-message match, matching the entries table for the same term');
		Assert.areEqual(1, entryLevelCountFor(summary, LOG_Engine.LEVEL_ERROR), 'The short-message match contributes one ERROR row');
		Assert.areEqual(1, entryLevelCountFor(summary, LOG_Engine.LEVEL_WARN), 'The body match contributes one WARN row');
		Set<String> sourceNames = new Set<String>();
		for(CTRL_LogConsole.DTO_SourceCount source : summary.topSources)
		{
			sourceNames.add(source.name);
		}
		Assert.areEqual(new Set<String> {'AlphaService', 'BravoService'}, sourceNames, 'Both the short-message and the body-match sources should rank in the ribbon top sources');
	}

	/**
	 * @description Tests that getEntrySummary keeps the correlation scope when a search term is also active,
	 * so the reshape to count body matches never widens the ribbon past a Chain-Monitor deep-link: two rows
	 * carrying the term under different correlation ids yield a ribbon total of one.
	 */
	@IsTest
	private static void shouldScopeEntrySummaryCorrelationUnderSearch()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'AlphaService.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'searchneedle in the short message')
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.build();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'BravoService.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'searchneedle in the short message')
				.withOverride(LogEntry__c.CorrelationId__c, 'a-different-correlation')
				.build();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'searchneedle';
		request.correlationId = TRACE_CORRELATION_ID;

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, summary.totalRows, 'The ribbon must keep the correlation scope under an active search term: only the row under the requested correlation should count');
	}

	/**
	 * @description Tests the ribbon-equals-table invariant directly: for a body-only search term, the entries
	 * table's totalCount (getLogEntries) equals the ribbon's totalRows (getEntrySummary), so the two
	 * @AuraEnabled entry points can never desync. Guards against a future edit to one method's matched-id
	 * computation silently diverging the ribbon from the table.
	 */
	@IsTest
	private static void shouldKeepRibbonTotalEqualToTableCountUnderSearch()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'AlphaService.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'searchneedle in the short message')
				.build();
		LogEntry__c bodyMatch = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.ClassMethod__c, 'BravoService.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'plain short message')
				.withOverride(LogEntry__c.Message__c, 'searchneedle hidden in the long body')
				.build();
		Test.setFixedSearchResults(new List<Id> {bodyMatch.Id});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'searchneedle';

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage tablePage = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		CTRL_LogConsole.DTO_EntrySummary ribbon = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, tablePage.totalCount, 'Both the short-message and the body match should surface in the entries table');
		Assert.areEqual(tablePage.totalCount, ribbon.totalRows, 'The ribbon total must equal the entries-table count for the same term (ribbon equals table)');
	}

	/**
	 * @description Tests that getLogEntryDetail returns the heavy forensic payload, resolves the
	 * originating user's display name, and parses the Limits__c text into governor-limit bars, dropping
	 * zero-use limits and pre-computing the level band.
	 */
	@IsTest
	private static void shouldReturnEntryDetailWithLimitBars()
	{
		LogEntry__c detailRow = seedNpeDetail(new Map<SObjectField, Object>
		{
				LogEntry__c.Message__c => 'NullPointerException: Attempt to de-reference a null object',
				LogEntry__c.StackTrace__c => 'Class.AccountTriggerHandler.handleAfterUpdate: line 142, column 1',
				LogEntry__c.ContextData__c => '{"contextData":{"recordId":"001000000000001","action":"update"}}',
				LogEntry__c.Limits__c => '\nQueries: 47 of 100\nCpu Time: 8200 of 10000\nCallouts: 0 of 100',
				LogEntry__c.UserId__c => UserInfo.getUserId()
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(detailRow.Id);
		Test.stopTest();

		Assert.isNotNull(detail, 'The detail should be returned for a valid Id');
		Assert.isTrue(detail.message.contains('NullPointerException'), 'The full message should be carried');
		Assert.isTrue(detail.stackTrace.contains('line 142'), 'The stack trace should be carried');
		Assert.isTrue(detail.contextJson.contains('recordId'), 'The unwrapped inner context JSON should be carried');
		Assert.areEqual(UserInfo.getName(), detail.userName, 'The originating user Id should resolve to the display name');
		Assert.areEqual(2, detail.limitBars.size(), 'The zero-use Callouts limit is dropped; Queries and Cpu Time remain');
		CTRL_LogConsole.DTO_LimitBar soqlBar = limitBarNamed(detail, 'Queries');
		Assert.areEqual(47, soqlBar.percentage, 'Queries should be 47 of 100');
		Assert.areEqual('green', soqlBar.level, 'A 47% limit is green');
		CTRL_LogConsole.DTO_LimitBar cpuBar = limitBarNamed(detail, 'Cpu Time');
		Assert.areEqual(82, cpuBar.percentage, 'Cpu Time should be 82% of its maximum');
		Assert.areEqual('amber', cpuBar.level, 'An 82% limit is amber');
	}

	/**
	 * @description Tests that getLogEntryDetail leaves userName null, without throwing, when UserId__c is
	 * blank or malformed — the plain text field carries no lookup guarantee, so the drawer falls back to
	 * showing the raw value.
	 */
	@IsTest
	private static void shouldLeaveUserNameNullForBlankOrMalformedUserId()
	{
		LogEntry__c blankUserRow = seedNpeDetail(new Map<SObjectField, Object> {LogEntry__c.UserId__c => ''});
		LogEntry__c malformedUserRow = seedNpeDetail(new Map<SObjectField, Object>
		{
				LogEntry__c.UserId__c => 'not-an-id',
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail blankUserDetail = CTRL_LogConsole.getLogEntryDetail(blankUserRow.Id);
		CTRL_LogConsole.DTO_LogEntryDetail malformedUserDetail = CTRL_LogConsole.getLogEntryDetail(malformedUserRow.Id);
		Test.stopTest();

		Assert.isNull(blankUserDetail.userName, 'A blank UserId__c should yield no user name');
		Assert.isNull(malformedUserDetail.userName, 'A malformed UserId__c should yield no user name, not an exception');
	}

	/**
	 * @description Tests that getCorrelatedTrace returns the correlated hops ordered by CreatedDate
	 * ascending, marks the opened entry isSelf, and carries the raw execution context and timestamp so the
	 * LWC can render the hop label and relative offset.
	 */
	@IsTest
	private static void shouldReturnCorrelatedTraceOrderedWithSelfMarked()
	{
		LogEntry__c firstHop = seedCorrelatedHop(BASE_NULL_POINTER, CLASS_METHOD_ACCOUNT, TRACE_CORRELATION_ID, Datetime.now().addMinutes(-3));
		LogEntry__c openedHop = seedCorrelatedHop(BASE_OTHER, CLASS_METHOD_OPPORTUNITY, TRACE_CORRELATION_ID, Datetime.now().addMinutes(-2));
		LogEntry__c lastHop = seedCorrelatedHop(BASE_NOTIFICATION, 'NotificationService.send', TRACE_CORRELATION_ID, Datetime.now().addMinutes(-1));

		Test.startTest();
		List<CTRL_LogConsole.DTO_TraceEntry> trace = CTRL_LogConsole.getCorrelatedTrace(openedHop.Id).entries;
		Test.stopTest();

		Assert.areEqual(3, trace.size(), 'All three correlated hops should return');
		Assert.areEqual(firstHop.Id, trace[0].id, 'The trace should be ordered by CreatedDate ascending');
		Assert.areEqual(openedHop.Id, trace[1].id, 'The opened entry sits in the middle of the trace');
		Assert.areEqual(lastHop.Id, trace[2].id, 'The latest hop is last');
		Assert.isFalse(trace[0].isSelf, 'The first hop is not the opened entry');
		Assert.isTrue(trace[1].isSelf, 'The opened entry is marked isSelf');
		Assert.isFalse(trace[2].isSelf, 'The last hop is not the opened entry');
		Assert.areEqual('OpportunityService', trace[1].className, 'The class name is the first dotted segment of ClassMethod__c');
		Assert.areEqual('hop ' + CLASS_METHOD_OPPORTUNITY, trace[1].shortMessage, 'The short message is carried for the ordered correlated-entries list');
		Assert.areEqual(Quiddity.QUEUEABLE.name(), trace[1].executionEvent, 'The raw execution context is carried for the LWC hop label');
		Assert.isNotNull(trace[1].createdDate, 'The raw CreatedDate is carried for the LWC relative-offset rendering');
	}

	/**
	 * @description Tests that getCorrelatedTrace returns a single-self trace when the opened entry has no
	 * correlation (the chain is always present, spec §6), and returns an empty list for both a null Id and
	 * a well-formed Id that resolves to no row.
	 */
	@IsTest
	private static void shouldReturnSelfOnlyTraceWhenCorrelationBlank()
	{
		LogEntry__c soloRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.LineNumber__c => 17,
				LogEntry__c.ShortMessage__c => 'an uncorrelated warning'
		});

		Test.startTest();
		List<CTRL_LogConsole.DTO_TraceEntry> selfOnly = CTRL_LogConsole.getCorrelatedTrace(soloRow.Id).entries;
		List<CTRL_LogConsole.DTO_TraceEntry> fromNull = CTRL_LogConsole.getCorrelatedTrace(null).entries;
		List<CTRL_LogConsole.DTO_TraceEntry> fromMissing = CTRL_LogConsole.getCorrelatedTrace(UTIL_Random.randomId(LogEntry__c.SObjectType)).entries;
		Test.stopTest();

		Assert.areEqual(1, selfOnly.size(), 'A row with no correlation yields a single-self trace; the chain is always present');
		Assert.areEqual(soloRow.Id, selfOnly[0].id, 'The single node is the opened entry');
		Assert.isTrue(selfOnly[0].isSelf, 'The single node is marked isSelf');
		Assert.isTrue(fromNull.isEmpty(), 'A null entry Id yields an empty trace, not an exception');
		Assert.isTrue(fromMissing.isEmpty(), 'A well-formed Id that resolves to no row yields an empty trace, not an exception');
	}

	/**
	 * @description Tests that getCorrelatedTrace surfaces the transaction-tree fields — each hop's own
	 * transaction Id, its parent transaction Id, and its duration — so the LWC can group the entries into
	 * transactions and build the correlation tree.
	 */
	@IsTest
	private static void shouldSurfaceTransactionTreeFieldsOnCorrelatedTrace()
	{
		Decimal rootDurationMs = 120;
		Decimal childDurationMs = 340;
		String rootTransactionId = UTIL_Random.randomUUID();
		String childTransactionId = UTIL_Random.randomUUID();
		LogEntry__c rootHop = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, CLASS_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.LineNumber__c, 42)
				.withOverride(LogEntry__c.ShortMessage__c, 'root hop')
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.AURA.name())
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.withOverride(LogEntry__c.TransactionId__c, rootTransactionId)
				.withOverride(LogEntry__c.DurationMs__c, rootDurationMs)
				.build();
		Test.setCreatedDate(rootHop.Id, Datetime.now().addMinutes(-2));
		LogEntry__c childHop = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, CLASS_METHOD_OPPORTUNITY)
				.withOverride(LogEntry__c.LineNumber__c, 42)
				.withOverride(LogEntry__c.ShortMessage__c, 'child hop')
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.QUEUEABLE.name())
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.withOverride(LogEntry__c.TransactionId__c, childTransactionId)
				.withOverride(LogEntry__c.ParentTransactionId__c, rootTransactionId)
				.withOverride(LogEntry__c.DurationMs__c, childDurationMs)
				.build();
		Test.setCreatedDate(childHop.Id, Datetime.now().addMinutes(-1));

		Test.startTest();
		List<CTRL_LogConsole.DTO_TraceEntry> trace = CTRL_LogConsole.getCorrelatedTrace(childHop.Id).entries;
		Test.stopTest();

		Assert.areEqual(2, trace.size(), 'Both correlated hops should return');
		Assert.areEqual(rootTransactionId, trace[0].transactionId, 'The root hop carries its own transaction Id so the LWC groups its entries');
		Assert.isNull(trace[0].parentTransactionId, 'The root hop has no parent transaction');
		Assert.areEqual(rootDurationMs, trace[0].durationMs, 'The root hop carries its duration');
		Assert.areEqual(childTransactionId, trace[1].transactionId, 'The child hop carries its own transaction Id');
		Assert.areEqual(rootTransactionId, trace[1].parentTransactionId, 'The child hop links to the parent transaction so the LWC builds the tree');
		Assert.areEqual(childDurationMs, trace[1].durationMs, 'The child hop carries its duration');
	}

	/**
	 * @description Tests that getCorrelatedTrace flags the trace truncated and trims it to the row cap when
	 * the correlation holds more forensic rows than the cap, so the console points the user to the Chain
	 * Monitor for the full chain.
	 */
	@IsTest
	private static void shouldFlagTruncationWhenCorrelatedTraceExceedsRowCap()
	{
		List<LogEntry__c> rows = TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ClassMethod__c, CLASS_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.ShortMessage__c, 'chatty hop')
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.withCount(SEL_LogEntry.CORRELATION_TRACE_ROW_CAP + 1)
				.buildList();

		Test.startTest();
		CTRL_LogConsole.DTO_TracePage page = CTRL_LogConsole.getCorrelatedTrace(rows[0].Id);
		Test.stopTest();

		Assert.isTrue(page.truncated, 'A trace that exceeds the row cap is flagged truncated so the console shows the Chain Monitor escape hatch');
		Assert.areEqual(SEL_LogEntry.CORRELATION_TRACE_ROW_CAP, page.entries.size(), 'The trace is trimmed to the row cap');
	}

	/**
	 * @description Tests that getCorrelatedTrace does not flag truncation when the correlation holds exactly
	 * the row cap, guarding the off-by-one boundary.
	 */
	@IsTest
	private static void shouldNotFlagTruncationWhenCorrelatedTraceAtRowCap()
	{
		List<LogEntry__c> rows = TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ClassMethod__c, CLASS_METHOD_ACCOUNT)
				.withOverride(LogEntry__c.ShortMessage__c, 'chatty hop')
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.withCount(SEL_LogEntry.CORRELATION_TRACE_ROW_CAP)
				.buildList();

		Test.startTest();
		CTRL_LogConsole.DTO_TracePage page = CTRL_LogConsole.getCorrelatedTrace(rows[0].Id);
		Test.stopTest();

		Assert.isFalse(page.truncated, 'A trace exactly at the row cap is not truncated');
		Assert.areEqual(SEL_LogEntry.CORRELATION_TRACE_ROW_CAP, page.entries.size(), 'All rows up to the cap are returned');
	}

	/**
	 * @description Tests that getLogEntryDetail flags chainExists when a registered async chain shares the
	 * entry's correlation, so the drawer offers Open in Chain Monitor.
	 */
	@IsTest
	private static void shouldFlagChainExistsWhenRegisteredChainSharesCorrelation()
	{
		LogEntry__c hop = seedCorrelatedHop(BASE_NULL_POINTER, CLASS_METHOD_ACCOUNT, TRACE_CORRELATION_ID, Datetime.now().addMinutes(-1));
		TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, 'IncidentChain')
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.build();

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(hop.Id);
		Test.stopTest();

		Assert.isTrue(detail.chainExists, 'A registered chain sharing the correlation gates Open in Chain Monitor on');
	}

	/**
	 * @description Tests that getLogEntryDetail leaves chainExists false when no registered chain shares the
	 * entry's correlation and when the entry has no correlation at all, so the drawer hides Open in Chain
	 * Monitor unless there is a chain to open.
	 */
	@IsTest
	private static void shouldNotFlagChainExistsWithoutRegisteredChain()
	{
		LogEntry__c correlatedHop = seedCorrelatedHop(BASE_NULL_POINTER, CLASS_METHOD_ACCOUNT, TRACE_CORRELATION_ID, Datetime.now().addMinutes(-1));
		LogEntry__c standaloneRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_OPPORTUNITY,
				LogEntry__c.LineNumber__c => 17,
				LogEntry__c.ShortMessage__c => 'a standalone entry'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail correlatedButNoChain = CTRL_LogConsole.getLogEntryDetail(correlatedHop.Id);
		CTRL_LogConsole.DTO_LogEntryDetail standalone = CTRL_LogConsole.getLogEntryDetail(standaloneRow.Id);
		Test.stopTest();

		Assert.isFalse(correlatedButNoChain.chainExists, 'A correlated entry with no registered chain does not gate Open in Chain Monitor on');
		Assert.isFalse(standalone.chainExists, 'A standalone entry with no correlation does not gate Open in Chain Monitor on');
	}

	/**
	 * @description Tests the request guards: a null or blank requestJson defaults sensibly, an unknown
	 * sort field falls back without error, and getLogEntryDetail returns null for a null Id.
	 */
	@IsTest
	private static void shouldDefaultAndGuardRequest()
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.sortField = 'not_a_real_field';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage fromNull = CTRL_LogConsole.getLogProblems(null);
		CTRL_LogConsole.DTO_LogProblemPage fromBlank = CTRL_LogConsole.getLogProblems('');
		CTRL_LogConsole.DTO_LogProblemPage fromBadSort = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogEntryDetail nullDetail = CTRL_LogConsole.getLogEntryDetail(null);
		Test.stopTest();

		Assert.isNotNull(fromNull, 'A null requestJson should return a default page, not throw');
		Assert.isNotNull(fromBlank, 'A blank requestJson should return a default page, not throw');
		Assert.isNotNull(fromBadSort, 'An unknown sort field should fall back to the default sort, not throw');
		Assert.isNull(nullDetail, 'A null entry Id should return null, not throw');
	}

	/**
	 * @description Tests that both list endpoints handle bad paging parameters gracefully: a negative or
	 * zero page size falls back to the default size, a non-positive page number falls back to the first
	 * page, and a positive page number beyond the last page yields an empty slice — none throw.
	 */
	@IsTest
	private static void shouldHandleBadPagingParametersGracefully()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_OPPORTUNITY, new List<Integer> {2, 3});

		CTRL_LogConsole.DTO_Request negative = new CTRL_LogConsole.DTO_Request();
		negative.windowMinutes = WINDOW_SEVEN_DAYS;
		negative.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		negative.pageSize = -5;
		negative.pageNumber = 0;

		CTRL_LogConsole.DTO_Request beyondEnd = new CTRL_LogConsole.DTO_Request();
		beyondEnd.windowMinutes = WINDOW_SEVEN_DAYS;
		beyondEnd.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		beyondEnd.pageSize = 50;
		beyondEnd.pageNumber = 999;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage negativePage = CTRL_LogConsole.getLogProblems(JSON.serialize(negative));
		CTRL_LogConsole.DTO_LogProblemPage beyondPage = CTRL_LogConsole.getLogProblems(JSON.serialize(beyondEnd));
		CTRL_LogConsole.DTO_LogEntryPage negativeEntries = CTRL_LogConsole.getLogEntries(JSON.serialize(negative));
		Test.stopTest();

		Assert.areEqual(1, negativePage.pageNumber, 'A non-positive page number should fall back to the first page');
		Assert.areEqual(2, negativePage.totalCount, 'Both problems should be counted regardless of the bad page size');
		Assert.areEqual(2, negativePage.records.size(), 'A negative page size should fall back to the default size and return both problems on page one');
		Assert.areEqual(1, negativePage.totalPages, 'Two problems at the default page size fit on a single page');
		Assert.isFalse(negativePage.hasMorePages, 'A single page has no further pages');

		Assert.areEqual(999, beyondPage.pageNumber, 'A positive page number beyond the end is echoed back unchanged');
		Assert.isTrue(beyondPage.records.isEmpty(), 'A page beyond the last yields an empty slice rather than throwing');
		Assert.isFalse(beyondPage.hasMorePages, 'There is no page after a beyond-the-end page');

		Assert.areEqual(1, negativeEntries.pageNumber, 'The flat entries page should also fall back to the first page for a non-positive page number');
		Assert.isFalse(negativeEntries.records.isEmpty(), 'A negative page size should fall back to the default size and return the seeded forensic rows');
	}

	/**
	 * @description Tests that an explicit custom ISO-8601 date range overrides the preset window: a range
	 * covering the roll ups includes the problem, while a range entirely before them excludes it.
	 */
	@IsTest
	private static void shouldHonourCustomDateRange()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});

		CTRL_LogConsole.DTO_Request coveringRange = new CTRL_LogConsole.DTO_Request();
		coveringRange.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		coveringRange.customStart = UTIL_Date.toIso8601(Datetime.now().addDays(-3));
		coveringRange.customEnd = UTIL_Date.toIso8601(Datetime.now());

		CTRL_LogConsole.DTO_Request priorRange = new CTRL_LogConsole.DTO_Request();
		priorRange.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		priorRange.customStart = UTIL_Date.toIso8601(Datetime.now().addDays(-10));
		priorRange.customEnd = UTIL_Date.toIso8601(Datetime.now().addDays(-5));

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage withinRange = CTRL_LogConsole.getLogProblems(JSON.serialize(coveringRange));
		CTRL_LogConsole.DTO_LogProblemPage beforeRange = CTRL_LogConsole.getLogProblems(JSON.serialize(priorRange));
		Test.stopTest();

		Assert.areEqual(1, withinRange.records.size(), 'A custom range covering the rollups includes the problem');
		Assert.areEqual(0, beforeRange.records.size(), 'A custom range entirely before the rollups excludes the problem');
	}

	/**
	 * @description Tests that a custom range expressed with a non-GMT UTC offset (+10:00) is filtered by its
	 * absolute instant, not its wall-clock read as GMT: a ±two-hour window around a row's instant, written in
	 * a +10:00 offset, includes the row (a naive GMT misread would shift the bounds ten hours and exclude it),
	 * while a window entirely after the instant, in the same offset, excludes it.
	 */
	@IsTest
	private static void shouldFilterOffsetBearingCustomRangeByAbsoluteInstant()
	{
		LogEntry__c detailRow = seedNpeDetail(new Map<SObjectField, Object>());
		LogEntry__c rollupRow = TST_Factory.seedLogRollup(BASE_NULL_POINTER, UTIL_Date.toUtcDayBucket(Datetime.now()), LOG_Engine.LEVEL_ERROR, 9);
		Datetime anchorInstant = Datetime.now().addHours(-1);
		Test.setCreatedDate(detailRow.Id, anchorInstant);
		Test.setCreatedDate(rollupRow.Id, anchorInstant);

		CTRL_LogConsole.DTO_Request covering = new CTRL_LogConsole.DTO_Request();
		covering.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		covering.customStart = offsetIso(anchorInstant.addHours(-2));
		covering.customEnd = offsetIso(anchorInstant.addHours(2));

		CTRL_LogConsole.DTO_Request after = new CTRL_LogConsole.DTO_Request();
		after.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		after.customStart = offsetIso(anchorInstant.addHours(1));
		after.customEnd = offsetIso(anchorInstant.addHours(3));

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage coveringPage = CTRL_LogConsole.getLogProblems(JSON.serialize(covering));
		CTRL_LogConsole.DTO_LogProblemPage afterPage = CTRL_LogConsole.getLogProblems(JSON.serialize(after));
		Test.stopTest();

		Assert.areEqual(1, coveringPage.records.size(), 'A +10:00 range covering the row instant includes it (the offset is honoured, not read as GMT)');
		Assert.areEqual(0, afterPage.records.size(), 'A +10:00 range entirely after the row instant excludes it (a real absolute-instant bound)');
	}

	/**
	 * @description Tests that the flat-entries view orders by every allow-listed sort field, and that each
	 * field is genuinely applied rather than silently degrading to the CreatedDate fallback. The two rows are
	 * ANTI-aligned on CreatedDate (the unrecognised-sort fallback) against every other field: the alpha row is
	 * the NEWER row but is lower on level, class name, duration, short message, execution context and
	 * correlation id, so an ascending sort by any of those six must return the alpha row first, while an
	 * ascending sort by createdDate returns the zulu row first. A broken sort-field mapping that degraded to
	 * CreatedDate would flip the result and fail. The level field uses INFO vs ERROR so it also proves the
	 * picklist-severity ordering (INFO precedes ERROR in the picklist even though it follows it
	 * alphabetically); BATCH_APEX precedes QUEUEABLE in both alphabetical and picklist-definition order, so the
	 * execution-context axis is stable regardless of which rule the platform applies. The server re-sorts each
	 * request statelessly.
	 */
	@IsTest
	private static void shouldSortEntriesByEachSortField()
	{
		LogEntry__c alphaRow = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + 'NullPointer:AlphaService.run')
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ClassMethod__c, 'AlphaService.run')
				.withOverride(LogEntry__c.DurationMs__c, 10)
				.withOverride(LogEntry__c.ShortMessage__c, 'aaa earliest failure')
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.BATCH_APEX.name())
				.withOverride(LogEntry__c.CorrelationId__c, 'corr-aaa')
				.build();
		LogEntry__c zuluRow = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + 'NullPointer:ZuluService.run')
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'ZuluService.run')
				.withOverride(LogEntry__c.DurationMs__c, 99)
				.withOverride(LogEntry__c.ShortMessage__c, 'zzz latest failure')
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.QUEUEABLE.name())
				.withOverride(LogEntry__c.CorrelationId__c, 'corr-zzz')
				.build();
		Test.setCreatedDate(alphaRow.Id, Datetime.now().addHours(-1));
		Test.setCreatedDate(zuluRow.Id, Datetime.now().addHours(-2));

		Map<String, Id> expectedFirstBySortField = new Map<String, Id>
		{
				'createdDate' => zuluRow.Id,
				'level' => alphaRow.Id,
				'className' => alphaRow.Id,
				'durationMs' => alphaRow.Id,
				'shortMessage' => alphaRow.Id,
				'executionEvent' => alphaRow.Id,
				'correlationId' => alphaRow.Id
		};

		Test.startTest();
		for(String sortField : expectedFirstBySortField.keySet())
		{
			CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
			request.windowMinutes = WINDOW_SEVEN_DAYS;
			request.sortField = sortField;
			request.sortAscending = true;
			CTRL_LogConsole.DTO_LogEntryPage page = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
			Assert.areEqual(expectedFirstBySortField.get(sortField), page.records[0].id, 'Ascending sort by ' + sortField + ' should put the expected row first');
		}
		Test.stopTest();
	}

	/**
	 * @description Tests that getLogEntryDetail returns null (not an exception) for a well-formed Id that
	 * resolves to no row — a stale or deleted entry link.
	 */
	@IsTest
	private static void shouldReturnNullDetailForMissingEntry()
	{
		Id missingEntryId = UTIL_Random.randomId(LogEntry__c.SObjectType);

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(missingEntryId);
		Test.stopTest();

		Assert.isNull(detail, 'A well-formed Id that resolves to no row returns null, not an exception');
	}

	/**
	 * @description Tests that an orphan rollup row (its detail sample purged) is skipped by the scope
	 * summary, so it neither crashes the fold nor inflates the totals.
	 */
	@IsTest
	private static void shouldExcludeOrphanRollupFromSummary()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {17, 23});
		TST_Factory.seedLogRollup(BASE_OTHER, UTIL_Date.toUtcDayBucket(Datetime.now()), LOG_Engine.LEVEL_ERROR, 99);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(40, summary.totalOccurrences, 'The orphan rollup with no sample is excluded; only the folded problem counts');
		Assert.areEqual(1, summary.distinctCount, 'Only the problem that has a detail sample is counted as distinct');
	}

	/**
	 * @description Tests the minimal-detail path: a row with no context data and no limits text yields a
	 * null context JSON and no limit bars, and a class method with no dot is itself the class name with
	 * the line number standing alone as the method line.
	 */
	@IsTest
	private static void shouldReturnMinimalDetailWhenContextAndLimitsAbsent()
	{
		LogEntry__c minimalRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_INFO,
				LogEntry__c.ClassMethod__c => 'StandaloneMethodName',
				LogEntry__c.LineNumber__c => 55,
				LogEntry__c.ShortMessage__c => 'A bare informational entry'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(minimalRow.Id);
		Test.stopTest();

		Assert.isNull(detail.contextJson, 'A row with no context data yields a null context JSON');
		Assert.isTrue(detail.limitBars.isEmpty(), 'A row with no limits text yields no limit bars');
		Assert.areEqual('StandaloneMethodName', detail.className, 'A class method with no dot is itself the class name');
		Assert.areEqual('55', detail.methodLine, 'With no method segment the method line is just the line number');
	}

	/**
	 * @description Tests that the source class is extracted from a Class/method value (the slash form the
	 * logging framework writes for some entries), matching LOG_Engine's canonical parser, so the console and
	 * the engine agree on what the source class is.
	 */
	@IsTest
	private static void shouldExtractClassNameFromSlashFormClassMethod()
	{
		LogEntry__c slashRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_INFO,
				LogEntry__c.ClassMethod__c => 'BatchRecalc/execute',
				LogEntry__c.ShortMessage__c => 'a slash-form source'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(slashRow.Id);
		Test.stopTest();

		Assert.areEqual('BatchRecalc', detail.className, 'The source class is the segment before the slash in a Class/method value (matching the logging framework)');
	}

	/**
	 * @description Tests the resilient parsing path: unparseable context data is carried through verbatim,
	 * and limit lines that lack the expected shape or carry a non-numeric value are dropped, leaving only
	 * the one valid bar.
	 */
	@IsTest
	private static void shouldFallBackOnMalformedContextAndLimits()
	{
		LogEntry__c malformedRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_OPPORTUNITY,
				LogEntry__c.LineNumber__c => 7,
				LogEntry__c.ShortMessage__c => 'Malformed payloads',
				LogEntry__c.ContextData__c => MALFORMED_CONTEXT_JSON,
				LogEntry__c.Limits__c => MALFORMED_LIMITS_TEXT
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(malformedRow.Id);
		Test.stopTest();

		Assert.areEqual(MALFORMED_CONTEXT_JSON, detail.contextJson, 'Unparseable context data is carried through verbatim');
		Assert.areEqual(1, detail.limitBars.size(), 'The shapeless line and the non-numeric limit are dropped; only the valid limit survives');
		Assert.areEqual('Queries', detail.limitBars[0].name, 'The one valid limit line is parsed into a bar');
	}

	/**
	 * @description Tests that every distinct-problems sort field orders the page by that column: level,
	 * class name, short message, execution context and log number each put the expected problem first,
	 * and the last-seen sort returns the full set.
	 */
	@IsTest
	private static void shouldSortProblemsByEachSortField()
	{
		seedDistinctProblem('NullPointer:AaaHandler.run', new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'AaaHandler.run',
				LogEntry__c.ShortMessage__c => 'Aaa earliest failure',
				LogEntry__c.ExecutionEvent__c => Quiddity.BATCH_APEX.name()
		}, 40);
		seedDistinctProblem('NullPointer:ZzzService.run', new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
				LogEntry__c.ClassMethod__c => 'ZzzService.run',
				LogEntry__c.ShortMessage__c => 'Zzz latest failure',
				LogEntry__c.ExecutionEvent__c => Quiddity.QUEUEABLE.name()
		}, 5);

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblem topByLevel = firstProblemSortedAscendingBy('level');
		CTRL_LogConsole.DTO_LogProblem topByClassName = firstProblemSortedAscendingBy('className');
		CTRL_LogConsole.DTO_LogProblem topByShortMessage = firstProblemSortedAscendingBy('shortMessage');
		CTRL_LogConsole.DTO_LogProblem topByExecutionEvent = firstProblemSortedAscendingBy('executionEvent');
		CTRL_LogConsole.DTO_LogProblem topByLogNumber = firstProblemSortedAscendingBy('logNumber');
		CTRL_LogConsole.DTO_LogProblemPage byLastSeen = problemsSortedAscendingBy('lastSeen');
		Test.stopTest();

		Assert.areEqual(LOG_Engine.LEVEL_WARN, topByLevel.level, 'Ascending level sort orders by severity, putting WARN before ERROR');
		Assert.areEqual('AaaHandler', topByClassName.className, 'Ascending class-name sort puts AaaHandler first');
		Assert.areEqual('Aaa earliest failure', topByShortMessage.shortMessage, 'Ascending message sort puts the Aaa message first');
		Assert.areEqual(Quiddity.BATCH_APEX.name(), topByExecutionEvent.executionEvent, 'Ascending context sort puts BATCH_APEX before QUEUEABLE');
		Assert.areEqual('AaaHandler', topByLogNumber.className, 'Ascending log-number sort puts the earlier-seeded problem first');
		Assert.areEqual(2, byLastSeen.records.size(), 'Sorting by last-seen returns both problems');
	}

	/**
	 * @description Tests that when the distinct candidate set exceeds the cap, the page is flagged capped
	 * and truncated to the cap, so the UI can prompt the administrator to narrow the filters.
	 */
	@IsTest
	private static void shouldFlagCappedWhenDistinctProblemsExceedCap()
	{
		seedProblem('NullPointer:AaaHandler.run', LOG_Engine.LEVEL_ERROR, 'AaaHandler.run', new List<Integer> {40});
		seedProblem('NullPointer:ZzzService.run', LOG_Engine.LEVEL_ERROR, 'ZzzService.run', new List<Integer> {5});
		CTRL_LogConsole.PROBLEM_CANDIDATE_CAP = 1;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		request.sortField = 'occurrenceCount';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.isTrue(result.resultsTruncated, 'Two distinct problems with a cap of one flags the page capped');
		Assert.areEqual(1, result.totalCount, 'Only one problem survives the candidate cap');
	}

	/**
	 * @description Tests that overflowing the rollup candidate cap flags the summary and the problems page
	 * totalsApproximate and folds only the most recent cap rows (the probe row is discarded, not folded):
	 * with the cap lowered to two, three seeded per-day rollup rows (10, 20, 30 occurrences, oldest first)
	 * fold the two newest counters (30 + 20 = 50). The distinct-base count stays far below the problem
	 * candidate cap, so resultsTruncated must stay false — the two signals are independent, and this
	 * multi-day single-problem window is exactly the shape the old bases-only signal missed.
	 */
	@IsTest
	private static void shouldFlagTotalsApproximateWhenRollupRowsOverflowCap()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {10, 20, 30});
		CTRL_LogConsole.ROLLUP_CANDIDATE_CAP = 2;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogProblemPage problems = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.isTrue(summary.totalsApproximate, 'Overflowing the rollup candidate cap must flag the summary totals best-effort');
		Assert.areEqual(50, summary.totalOccurrences, 'Only the two newest in-window counters fold at a cap of two; the probe row must not inflate the total');
		Assert.isTrue(problems.totalsApproximate, 'The problems page shares the best-effort signal when the rollup candidate set overflowed');
		Assert.isFalse(problems.resultsTruncated, 'One distinct base under the problem candidate cap must not flag the distinct list capped');
		Assert.areEqual(50, problems.records[0].occurrenceCount, 'The folded problem carries the same best-effort count the summary reports');
	}

	/**
	 * @description Tests that a window whose rollup rows exactly fill the candidate cap does not
	 * false-positive: both counters fold, the totals are exact, and no shape flags totalsApproximate.
	 */
	@IsTest
	private static void shouldNotFlagTotalsApproximateAtExactCap()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {10, 20});
		CTRL_LogConsole.ROLLUP_CANDIDATE_CAP = 2;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogProblemPage problems = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.isFalse(summary.totalsApproximate, 'A candidate set that exactly fills the rollup cap must not false-positive the best-effort flag');
		Assert.areEqual(30, summary.totalOccurrences, 'Both counters fold when the candidate set exactly fills the cap');
		Assert.isFalse(problems.totalsApproximate, 'The problems page must not flag best-effort totals when nothing overflowed');
	}

	/**
	 * @description Tests that getLogProblems sorts the Level column by severity (DEBUG < INFO < WARN < ERROR)
	 * ascending, not alphabetically, so the Problems view matches the picklist-ordered All-entries view.
	 */
	@IsTest
	private static void shouldSortProblemsByLevelSeverityAscending()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_WARN, CLASS_METHOD_OPPORTUNITY, new List<Integer> {5});
		seedProblem(BASE_NOTIFICATION, LOG_Engine.LEVEL_INFO, 'NotificationService.send', new List<Integer> {5});
		seedProblem('Debug:DiagnosticService.trace', LOG_Engine.LEVEL_DEBUG, 'DiagnosticService.trace', new List<Integer> {5});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN, LOG_Engine.LEVEL_INFO, LOG_Engine.LEVEL_DEBUG};
		request.sortField = 'level';
		request.sortAscending = true;
		request.pageSize = 50;
		request.pageNumber = 1;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage page = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		List<String> orderedLevels = new List<String>();
		for(CTRL_LogConsole.DTO_LogProblem problem : page.records)
		{
			orderedLevels.add(problem.level);
		}
		Assert.areEqual(
				new List<String> {LOG_Engine.LEVEL_DEBUG, LOG_Engine.LEVEL_INFO, LOG_Engine.LEVEL_WARN, LOG_Engine.LEVEL_ERROR},
				orderedLevels,
				'Ascending level sort must order by severity (DEBUG<INFO<WARN<ERROR), not alphabetically');
	}

	/**
	 * @description Tests that getLogProblems sorts the Level column by severity descending (ERROR first), so
	 * the loudest severities lead the Problems view exactly as the All-entries view orders them.
	 */
	@IsTest
	private static void shouldSortProblemsByLevelSeverityDescending()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_WARN, CLASS_METHOD_OPPORTUNITY, new List<Integer> {5});
		seedProblem(BASE_NOTIFICATION, LOG_Engine.LEVEL_INFO, 'NotificationService.send', new List<Integer> {5});
		seedProblem('Debug:DiagnosticService.trace', LOG_Engine.LEVEL_DEBUG, 'DiagnosticService.trace', new List<Integer> {5});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN, LOG_Engine.LEVEL_INFO, LOG_Engine.LEVEL_DEBUG};
		request.sortField = 'level';
		request.sortAscending = false;
		request.pageSize = 50;
		request.pageNumber = 1;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage page = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		List<String> orderedLevels = new List<String>();
		for(CTRL_LogConsole.DTO_LogProblem problem : page.records)
		{
			orderedLevels.add(problem.level);
		}
		Assert.areEqual(
				new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN, LOG_Engine.LEVEL_INFO, LOG_Engine.LEVEL_DEBUG},
				orderedLevels,
				'Descending level sort must order by severity (ERROR>WARN>INFO>DEBUG)');
	}

	/**
	 * @description Seeds one detail: sample row and one rollup: counter row per supplied count, each on a
	 * descending UTC day bucket (most-recent last), mirroring the production flood-control key shapes, and
	 * back-dates their CreatedDate so first-seen aggregation can be asserted. Returns the detail row.
	 *
	 * @param base The base fingerprint (without the detail:/rollup: prefix).
	 * @param level The log level for every row (DEBUG/INFO/WARN/ERROR).
	 * @param classMethod The Class.method whose first segment is the problem's source class.
	 * @param dayCounts The OccurrenceCount__c per rollup row, oldest first; one rollup per element on its own day.
	 *
	 * @return The inserted detail: sample row.
	 */
	private static LogEntry__c seedProblem(String base, String level, String classMethod, List<Integer> dayCounts)
	{
		LogEntry__c detailRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + base,
				LogEntry__c.LogLevel__c => level,
				LogEntry__c.ExceptionType__c => 'NullPointerException',
				LogEntry__c.ClassMethod__c => classMethod,
				LogEntry__c.LineNumber__c => 142,
				LogEntry__c.ShortMessage__c => 'Attempt to de-reference a null object',
				LogEntry__c.ExecutionEvent__c => Quiddity.BATCH_APEX.name()
		});
		Test.setCreatedDate(detailRow.Id, Datetime.now().addDays(-dayCounts.size()));
		Integer daysAgo = dayCounts.size();
		for(Integer dayCount : dayCounts)
		{
			LogEntry__c rollupRow = TST_Factory.seedLogRollup(base, UTIL_Date.toUtcDayBucket(Datetime.now().addDays(-daysAgo)), level, dayCount);
			Test.setCreatedDate(rollupRow.Id, Datetime.now().addDays(-daysAgo));
			daysAgo--;
		}
		return detailRow;
	}

	/**
	 * @description Seeds one forensic hop (OccurrenceCount__c null) for a correlated operation, carrying
	 * the given correlation id, a distinct fingerprint and execution context, and back-dates its
	 * CreatedDate so the ordered correlated trace can be asserted. Returns the inserted row.
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
	 * @description Finds the per-level summary entry for a given level, or null when absent.
	 *
	 * @param summary The folded scope summary.
	 * @param level The log level to find.
	 *
	 * @return The matching per-level summary, or null.
	 */
	private static CTRL_LogConsole.DTO_LevelSummary levelSummaryFor(CTRL_LogConsole.DTO_LogSummary summary, String level)
	{
		for(CTRL_LogConsole.DTO_LevelSummary levelSummary : summary.perLevel)
		{
			if(level.equals(levelSummary.level))
			{
				return levelSummary;
			}
		}
		return null;
	}

	/**
	 * @description Seeds a number of plain forensic rows (OccurrenceCount__c and Fingerprint__c left null) at
	 * one level and source, so the all-entries summary aggregate can be asserted over real rows.
	 *
	 * @param count The number of rows to seed.
	 * @param level The log level for every row.
	 * @param classMethod The Class.method whose first segment is the source class.
	 * @param shortMessage The ShortMessage__c the search leg matches against.
	 */
	private static void seedForensicEntries(Integer count, String level, String classMethod, String shortMessage)
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, level)
				.withOverride(LogEntry__c.ClassMethod__c, classMethod)
				.withOverride(LogEntry__c.ShortMessage__c, shortMessage)
				.withCount(count)
				.buildList();
	}

	/**
	 * @description Finds the forensic row count for a level in an all-entries summary, or null when the level
	 * is absent from the breakdown.
	 *
	 * @param summary The all-entries summary.
	 * @param level The log level to find.
	 *
	 * @return The level's forensic row count, or null when the level is absent.
	 */
	private static Integer entryLevelCountFor(CTRL_LogConsole.DTO_EntrySummary summary, String level)
	{
		for(CTRL_LogConsole.DTO_EntryLevelCount levelCount : summary.perLevel)
		{
			if(level.equals(levelCount.level))
			{
				return levelCount.rowCount;
			}
		}
		return null;
	}

	/**
	 * @description Formats an instant as an ISO 8601 string carrying an explicit +10:00 offset (Brisbane has
	 * no daylight saving), so a test can prove a non-GMT custom range is filtered by its absolute instant
	 * rather than its wall-clock read as GMT.
	 *
	 * @param instant The absolute instant to format.
	 *
	 * @return The instant as an ISO 8601 string with a +10:00 offset.
	 */
	private static String offsetIso(Datetime instant)
	{
		return instant.format('yyyy-MM-dd\'T\'HH:mm:ssXXX', 'Australia/Brisbane');
	}

	/**
	 * @description Finds the governor-limit bar with a given name on a detail, or null when absent.
	 *
	 * @param detail The entry detail carrying the parsed limit bars.
	 * @param barName The limit label to find.
	 *
	 * @return The matching limit bar, or null.
	 */
	private static CTRL_LogConsole.DTO_LimitBar limitBarNamed(CTRL_LogConsole.DTO_LogEntryDetail detail, String barName)
	{
		for(CTRL_LogConsole.DTO_LimitBar bar : detail.limitBars)
		{
			if(barName.equals(bar.name))
			{
				return bar;
			}
		}
		return null;
	}

	/**
	 * @description Seeds one detail: sample (carrying the given display overrides) and one rollup: counter
	 * row dated today for a base fingerprint, so the per-column sort can be asserted over distinct problems.
	 *
	 * @param base The base fingerprint (without the detail:/rollup: prefix).
	 * @param detailOverrides The display-field overrides for the sample; must include LogLevel__c.
	 * @param occurrenceCount The OccurrenceCount__c on the rollup row.
	 */
	private static void seedDistinctProblem(String base, Map<SObjectField, Object> detailOverrides, Integer occurrenceCount)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>(detailOverrides);
		overrides.put(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + base);
		TST_Factory.seedLogEntry(overrides);
		TST_Factory.seedLogRollup(base, UTIL_Date.toUtcDayBucket(Datetime.now()), (String)detailOverrides.get(LogEntry__c.LogLevel__c), occurrenceCount);
	}

	/**
	 * @description Requests the distinct problems sorted ascending by a given field over a seven-day
	 * window spanning the ERROR and WARN levels.
	 *
	 * @param sortField The DTO_LogProblem field name to sort by.
	 *
	 * @return The resulting problem page.
	 */
	private static CTRL_LogConsole.DTO_LogProblemPage problemsSortedAscendingBy(String sortField)
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};
		request.sortField = sortField;
		request.sortAscending = true;
		return CTRL_LogConsole.getLogProblems(JSON.serialize(request));
	}

	/**
	 * @description Returns the first problem when sorted ascending by a given field.
	 *
	 * @param sortField The DTO_LogProblem field name to sort by.
	 *
	 * @return The first problem on the ascending-sorted page.
	 */
	private static CTRL_LogConsole.DTO_LogProblem firstProblemSortedAscendingBy(String sortField)
	{
		return problemsSortedAscendingBy(sortField).records[0];
	}

	/**
	 * @description Seeds a detail: sample for the standard NullPointer signature, merging in any extra
	 * overrides, so the two detail-pane tests share the common forensic fields in one place.
	 *
	 * @param extraOverrides Additional field overrides to merge onto the standard NullPointer detail row.
	 *
	 * @return The inserted detail: sample row.
	 */
	private static LogEntry__c seedNpeDetail(Map<SObjectField, Object> extraOverrides)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.ShortMessage__c => 'Attempt to de-reference a null object'
		};
		overrides.putAll(extraOverrides);
		return TST_Factory.seedLogEntry(overrides);
	}
}