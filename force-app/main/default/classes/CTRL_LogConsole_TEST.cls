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
 * @date June 2026, August 2026
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
	 * @description Class.method for the plain forensic rows the derived fold groups, distinct from the
	 * fingerprinted signatures above so a merged page can be told apart source by source.
	 */
	private static final String CLASS_METHOD_PRICING = 'PricingService.calculate';

	/**
	 * @description A second derived-fold Class.method, so a level scope or occurrence floor can be proven to
	 * admit one signature while leaving another out.
	 */
	private static final String CLASS_METHOD_SHIPPING = 'ShippingService.quote';

	/**
	 * @description A third derived-fold Class.method, carried by the INFO rows that prove a level scope keeps
	 * the fold off the levels it was not given.
	 */
	private static final String CLASS_METHOD_CATALOGUE = 'CatalogueService.refresh';

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
	 * @description A search term ending in a percent sign — the character a SOQL LIKE pattern reads as
	 * "any run of characters" — so the term proves the console searches for the text a person typed.
	 */
	private static final String SEARCH_TERM_LITERAL_PERCENT = '100%';

	/**
	 * @description A search term containing an underscore — the character a SOQL LIKE pattern reads as
	 * "any single character" — so the term proves a class name is not matched against near-misses.
	 */
	private static final String SEARCH_TERM_LITERAL_UNDERSCORE = 'UTIL_HttpClient';

	/**
	 * @description Occurrence count for the high-volume INFO problem that must not outrank an error in the
	 * problems view's opening order.
	 */
	private static final Integer CHATTY_OCCURRENCE_COUNT = 776;

	/**
	 * @description Occurrence count for the leading ERROR problem — deliberately far below the chatty INFO
	 * count, so severity alone can decide the head of the list.
	 */
	private static final Integer RARE_OCCURRENCE_COUNT = 12;

	/**
	 * @description Field values for the row whose SHORT MESSAGE carries the ribbon search term — the LIKE-leg
	 * match. Held once because the ribbon-counts-body-matches test and the ribbon-equals-table test seed the
	 * identical fixture, and the pair only proves the two entry points agree while it stays identical. The
	 * correlation-scope-under-search test also derives both of its rows from this map, so the short message
	 * must keep the search needle term, and the level and class values here are what those tests assert on.
	 */
	private static final Map<SObjectField, Object> SHORT_MESSAGE_SEARCH_MATCH_FIELDS = new Map<SObjectField, Object>
	{
			LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
			LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
			LogEntry__c.ClassMethod__c => 'AlphaService.run',
			LogEntry__c.ShortMessage__c => 'searchneedle in the short message'
	};

	/**
	 * @description Field values for the row whose LONG BODY carries the ribbon search term while its short
	 * message does not — the SOSL-only match, seeded identically by the same two tests as its LIKE-leg
	 * counterpart above.
	 */
	private static final Map<SObjectField, Object> BODY_SEARCH_MATCH_FIELDS = new Map<SObjectField, Object>
	{
			LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
			LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
			LogEntry__c.ClassMethod__c => 'BravoService.run',
			LogEntry__c.ShortMessage__c => 'plain short message',
			LogEntry__c.Message__c => 'searchneedle hidden in the long body'
	};

	/**
	 * @description Field values shared by the chatty correlated hops the two trace row-cap tests seed in bulk;
	 * only the row count differs between them, so the boundary pair cannot drift on anything else.
	 */
	private static final Map<SObjectField, Object> CHATTY_HOP_FIELDS = new Map<SObjectField, Object>
	{
			LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_INFO,
			LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
			LogEntry__c.ShortMessage__c => 'chatty hop',
			LogEntry__c.CorrelationId__c => TRACE_CORRELATION_ID
	};

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
	 * @description Tests that getLogProblems merges the read-time derived fold (plain forensic rows grouped
	 * by signature) with the fingerprinted rollup fold when the kill-switch is unchecked and no search term
	 * suppresses the leg: a fingerprinted problem and a derived problem both appear, with no double-count, the
	 * derived one carrying no id but a signature for the detail lookup.
	 */
	@IsTest
	private static void shouldMergeDerivedProblemsWhenEnabled()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};
		request.sortField = 'occurrenceCount';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'The derived leg runs when enabled with no search term');
		Assert.areEqual(2, result.totalCount, 'The rollup problem and the derived problem both appear, no double-count');

		CTRL_LogConsole.DTO_LogProblem derived = problemBySource(result, 'derived');
		Assert.isNotNull(derived, 'A derived problem is merged from the plain forensic rows');
		Assert.areEqual(3, derived.occurrenceCount, 'The derived problem counts the three forensic rows');
		Assert.isNull(derived.id, 'A derived problem has no record id (opened through its signature)');
		Assert.isNotNull(derived.signature, 'A derived problem carries its signature for the detail lookup');

		CTRL_LogConsole.DTO_LogProblem rollup = problemBySource(result, 'rollup');
		Assert.isNotNull(rollup, 'The fingerprinted rollup problem still appears');
		Assert.isNotNull(rollup.id, 'A rollup problem is openable by its record id');
	}

	/**
	 * @description Tests that a derived problem's list label is its NEWEST occurrence's message — the same
	 * member the drawer heading resolves — rather than the fold's own MAX(ShortMessage__c), which names the
	 * alphabetically-last message in the group. A group holding an older 'Zulu…' row and a newer 'Alpha…'
	 * row must read the 'Alpha…' text in the list row, in the signature label the row carries for the
	 * drawer's purge fallback, and in the drawer detail itself, so the label a reader triages by and the
	 * heading they open are one message.
	 */
	@IsTest
	private static void shouldLabelDerivedProblemWithItsNewestOccurrenceMessage()
	{
		String oldestMessage = 'Zulu pricing failure, the alphabetical maximum';
		String newestMessage = 'Alpha pricing failure, the newest occurrence';
		LogEntry__c older = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, CLASS_METHOD_PRICING)
				.withOverride(LogEntry__c.ShortMessage__c, oldestMessage)
				.build();
		Test.setCreatedDate(older.Id, Datetime.now().addHours(-6));
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, CLASS_METHOD_PRICING)
				.withOverride(LogEntry__c.ShortMessage__c, newestMessage)
				.build();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage page = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getDerivedProblemDetail(page.records[0].signature, JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, page.totalCount, 'The two same-signature rows fold into one derived problem');
		Assert.areEqual(newestMessage, page.records[0].shortMessage, 'The list label is the newest occurrence\'s message, not the alphabetical maximum');
		Map<String, Object> signature = (Map<String, Object>)JSON.deserializeUntyped(page.records[0].signature);
		Assert.areEqual(newestMessage, signature.get('label'), 'The signature label matches the list, so a purge fallback still shows the text that was clicked');
		Assert.areEqual(newestMessage, detail.shortMessage, 'The drawer heading names the same member as the list row');
	}

	/**
	 * @description Tests that the page relabel resolves every derived problem to its OWN newest occurrence
	 * in one pass — two signatures each holding a 'Zulu…' first insert and an 'Alpha…' second insert must
	 * each read their own 'Alpha…' text — and that rows sharing one CreatedDate second resolve to the
	 * latest-inserted row (the Id tie-break findDerivedRepresentative applies too), so the list and the
	 * drawer stay one message even inside a same-second burst.
	 */
	@IsTest
	private static void shouldRelabelEveryDerivedProblemWithItsOwnNewestMessage()
	{
		seedForensicEntries(1, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Zulu pricing failure');
		seedForensicEntries(1, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Alpha pricing failure');
		seedForensicEntries(1, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Zulu shipping failure');
		seedForensicEntries(1, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Alpha shipping failure');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage page = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, page.totalCount, 'Each source folds into its own derived problem');
		for(CTRL_LogConsole.DTO_LogProblem problem : page.records)
		{
			String expectedMessage = problem.classMethod == CLASS_METHOD_PRICING ? 'Alpha pricing failure' : 'Alpha shipping failure';
			Assert.areEqual(expectedMessage, problem.shortMessage, 'Each derived problem is relabelled with its own newest (latest-inserted) message');
		}
	}

	/**
	 * @description Tests that ProblemGroupingDisabled__c = true (the operational kill-switch) leaves the derived
	 * leg unrun: plain forensic rows that would otherwise fold into a derived problem do not appear, and the
	 * status reports DISABLED.
	 */
	@IsTest
	private static void shouldDisableDerivedLegWhenKillSwitchChecked()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.ProblemGroupingDisabled__c, true)
				.withoutInsertion(true)
				.build();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('DISABLED', result.derivedStatus, 'The checked kill-switch leaves the derived leg unrun');
		Assert.isNull(problemBySource(result, 'derived'), 'No derived problems appear when the kill-switch is checked');
		Assert.areEqual(0, result.totalCount, 'With only forensic rows and the kill-switch checked, the problems page is empty');
	}

	/**
	 * @description Tests that a LogSetting__c record that predates the ProblemGroupingDisabled__c field (the
	 * upgraded-org shape: the record is configured, but the checkbox was never saved so it reads false) leaves
	 * the derived leg ON — the negative-polarity kill-switch delivers default-on through upgrades with no
	 * record backfill.
	 */
	@IsTest
	private static void shouldKeepDerivedLegOnForSettingRecordPredatingTheKillSwitch()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.LogLevelThreshold__c, LOG_Engine.LEVEL_ERROR)
				.withoutInsertion(true)
				.build();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'A configured setting record with the kill-switch never saved keeps the derived leg on');
		Assert.isNotNull(problemBySource(result, 'derived'), 'The derived problem appears for an upgraded org with a pre-existing setting record');
	}

	/**
	 * @description Tests that ProblemGroupingMinimumOccurrences__c raises the floor the fold groups above: with
	 * the floor set to four, a signature seen four times is grouped and one seen three times is not, so a
	 * subscriber can tune out the noise the shipped floor of two still admits.
	 */
	@IsTest
	private static void shouldHonourConfiguredDerivedMinimumOccurrences()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.ProblemGroupingMinimumOccurrences__c, 4)
				.withoutInsertion(true)
				.build();
		seedForensicEntries(4, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Unhandled shipping error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'The derived leg runs under a configured occurrence floor');
		Assert.areEqual(1, result.totalCount, 'Only the signature meeting the configured floor of four is grouped');
		Assert.areEqual('PricingService', result.records[0].className, 'The four-occurrence signature is the one that survives the floor');
	}

	/**
	 * @description Tests that a LogSetting__c record predating both derived-problem fields (the upgraded-org
	 * shape: the record is configured, but neither field was ever saved so both read null) gets the shipped
	 * defaults — a floor of two and an ERROR;WARN level scope. A null read on an upgraded record is the normal
	 * case for a Number or Text field added to an existing custom setting, so the defaults have to live at the
	 * read site rather than in record data a package cannot ship.
	 */
	@IsTest
	private static void shouldApplyShippedDerivedDefaultsWhenTheSettingRecordPredatesTheFields()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.LogLevelThreshold__c, LOG_Engine.LEVEL_ERROR)
				.withoutInsertion(true)
				.build();
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(1, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Unhandled shipping error');
		seedForensicEntries(2, LOG_Engine.LEVEL_INFO, CLASS_METHOD_CATALOGUE, 'Catalogue refreshed');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'The derived leg runs on the shipped defaults');
		Assert.areEqual(1, result.totalCount, 'The default floor of two drops the single occurrence and the default scope drops the INFO signature');
		Assert.areEqual('PricingService', result.records[0].className, 'The twice-seen ERROR signature is the only one inside both shipped defaults');
	}

	/**
	 * @description Tests that ProblemGroupingLogLevels__c bounds which levels the fold may group: configured to
	 * ERROR alone, a WARN signature the console did not filter out is still left ungrouped. The setting is a
	 * cost ceiling on the scan, not just a display filter.
	 */
	@IsTest
	private static void shouldHonourConfiguredDerivedLevelScope()
	{
		seedLevelScopeSignatures(LOG_Engine.LEVEL_ERROR);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'The derived leg runs inside the configured level scope');
		Assert.areEqual(1, result.totalCount, 'Only the ERROR signature is grouped when the scope is configured to ERROR alone');
		Assert.areEqual('PricingService', result.records[0].className, 'The WARN and INFO signatures stay outside the configured scope');
		Assert.areEqual(new List<String> {LOG_Engine.LEVEL_ERROR}, result.derivedLevelScope,
				'The page reports the scope as configured, not the shipped default: a page that always echoed ERROR;WARN would look right everywhere else');
	}

	/**
	 * @description Tests that the console's own level filter and the configured scope intersect in BOTH
	 * directions, against a window holding a signature at each level. With the scope at ERROR;WARN and the
	 * console asking for ERROR and INFO: the INFO signature stays ungrouped because the setting never admitted
	 * INFO to the scan (the filter cannot widen the scope), and the WARN signature stays ungrouped because the
	 * console filtered it out (the filter does narrow the scope). Seeding the WARN row is what makes the
	 * narrowing direction observable — without it, handing the fold the full configured list instead of the
	 * intersection would produce an identical page and this test would pass over a console that lists problems
	 * at a level the user has switched off.
	 */
	@IsTest
	private static void shouldNarrowTheConfiguredDerivedLevelScopeToTheConsoleLevelFilter()
	{
		seedLevelScopeSignatures('ERROR;WARN');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_INFO};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'An overlapping filter still runs the derived leg');
		Assert.areEqual(1, result.totalCount, 'Only the level both the setting and the console admit is grouped');
		Assert.areEqual('PricingService', result.records[0].className, 'The INFO signature the console asked for is outside the configured scope');
		Assert.isNull
				(
						problemByClassName(result, 'ShippingService'),
						'The WARN signature the setting permits is removed by the console filter — the intersection narrows, not only refuses to widen'
				);
		Assert.areEqual(new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN}, result.derivedLevelScope,
				'The page reports the CONFIGURED scope, not the intersection the fold ran on: echoing the reader\'s own filter back at them explains nothing');
	}

	/**
	 * @description Tests that a console level filter sharing no level with the configured scope reports its own
	 * status rather than a silently empty grouping: the derived leg is skipped, the fingerprinted rollup
	 * problems still render, and the status names the level scope as the reason so the console can explain the
	 * empty list.
	 */
	@IsTest
	private static void shouldSkipTheDerivedLegWhenTheLevelScopeAndConsoleFilterShareNoLevel()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.ProblemGroupingLogLevels__c, 'ERROR;WARN')
				.withoutInsertion(true)
				.build();
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_INFO, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_INFO, CLASS_METHOD_CATALOGUE, 'Catalogue refreshed');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_INFO};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('SKIPPED_LEVEL_SCOPE', result.derivedStatus, 'An empty level intersection reports its own status');
		Assert.isNull(problemBySource(result, 'derived'), 'No derived problems are grouped outside the configured level scope');
		Assert.isNotNull(problemBySource(result, 'rollup'), 'The fingerprinted rollup problem still renders while the derived leg is skipped');
	}

	/**
	 * @description Tests that the page reports the configured level scope even when the derived leg never ran.
	 * The console states the scope to whoever is reading the list on every outcome, not only the one that
	 * skipped for a level mismatch, so a page that folded nothing still knows the levels grouping covers.
	 */
	@IsTest
	private static void shouldReportTheConfiguredLevelScopeWhenGroupingIsSwitchedOff()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.ProblemGroupingDisabled__c, true)
				.withOverride(LogSetting__c.ProblemGroupingLogLevels__c, 'ERROR;WARN')
				.withoutInsertion(true)
				.build();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('DISABLED', result.derivedStatus, 'Grouping switched off reports its own status');
		Assert.areEqual(new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN}, result.derivedLevelScope,
				'The configured scope is captured before the early return, so a status that never reached the fold still carries it');
	}

	/**
	 * @description Tests that a declined derived scan reports its cause as a leg that never ran rather than a
	 * trimmed one. Both raise totalsApproximate, but the shipped approximate-totals help describes truncation
	 * only — "the most recent groups" is simply false when a whole leg is missing — so the flag alone cannot
	 * drive honest copy.
	 */
	@IsTest
	private static void shouldReportAnAbsentLegAsThePartialTotalsCause()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		CTRL_LogConsole.DERIVED_SCAN_ROW_CEILING = 2;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.isTrue(summary.totalsApproximate, 'A declined derived scan leaves the totals best-effort');
		Assert.areEqual('PARTIAL', summary.totalsApproximateCause, 'A leg that never ran is absent, not trimmed, and the two need different copy');
	}

	/**
	 * @description Tests that the console receives the Apex-form namespace prefix for its copy-to-compile
	 * snippet. The console generates Apex a subscriber pastes into their own code, so the prefix has to be the
	 * dot form: the double-underscore metadata form names metadata correctly and does not compile in Apex.
	 * Asserted against the org's own namespace rather than a literal, because a no-namespace development deploy
	 * and a managed subscriber org have to be satisfied by the same test.
	 */
	@IsTest
	private static void shouldExposeTheApexFormNamespacePrefixForTheGeneratedSnippet()
	{
		Test.startTest();
		String prefix = CTRL_LogConsole.getApexNamespacePrefix();
		Test.stopTest();

		String namespace = UTIL_System.getManagedPackageNamespace();
		// In the no-namespace development org both forms are '', so these assertions only bite in the namespaced
		// package-validation run — which is the run that matters, being the one a subscriber's snippet mirrors.
		Assert.isNotNull(prefix, 'An unmanaged deploy receives an empty prefix, never null, so the snippet still renders');
		Assert.areEqual(String.isBlank(namespace) ? '' : namespace + '.', prefix,
				'A managed org receives its namespace and a dot; an unmanaged deploy receives nothing to prepend');
		Assert.isFalse(prefix.contains('__'), 'The metadata form does not compile in Apex, so it must never reach the generated snippet');
	}

	/**
	 * @description Tests that the console's Log Settings action resolves the setting's own manage page — the
	 * page listing the configured values — rather than the Custom Settings index, which lists every custom
	 * setting in the org and leaves the reader to find this one and press Manage. Setup keys that page by the
	 * object's key prefix (an EntityDefinition DurableId in its place renders "Invalid Custom Setting id"),
	 * and carries the whole Classic address as one encoded parameter — a partially-encoded address lands on
	 * a Setup error page — so both are asserted. The expected prefix is read through UTIL_SObjectDescribe,
	 * the request-cached describe wrapper every describe in this framework goes through.
	 */
	@IsTest
	private static void shouldResolveTheLogSettingsManagePageUrl()
	{
		Test.startTest();
		String settingsUrl = CTRL_LogConsole.getLogSettingsSetupUrl();
		Test.stopTest();

		String keyPrefix = UTIL_SObjectDescribe.getDescribe(LogSetting__c.SObjectType).getDescribe().getKeyPrefix();
		Assert.areEqual('/lightning/setup/CustomSettings/page?address=%2Fsetup%2Fui%2FlistCustomSettingsData.apexp%3Fid%3D' + keyPrefix, settingsUrl,
				'The action must land on the Log Settings manage page, keyed by the object key prefix');
		Assert.isFalse(settingsUrl.substringAfter('address=').contains('/'), 'An address encoded only in part is read as Setup parameters and lands on an error page');
	}

	/**
	 * @description Tests that the level scope accepts a comma-separated value as well as the semicolon the
	 * shipped default uses. The two sibling multi-value settings on this object (ClassFilter__c and
	 * SuppressClassMethod__c) are comma-separated, so a subscriber carrying that habit across would otherwise
	 * configure a scope that silently matched nothing.
	 *
	 * The value under test is deliberately ERROR, INFO rather than the shipped ERROR;WARN pair: if comma
	 * support were dropped, the whole value would parse as one unrecognised token and fall back to the shipped
	 * ERROR;WARN default — so a comma test written against ERROR, WARN would pass either way and prove
	 * nothing. A scope the fallback can never produce is what makes parsing observable.
	 */
	@IsTest
	private static void shouldAcceptACommaSeparatedDerivedLevelScope()
	{
		seedLevelScopeSignatures('ERROR, INFO');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'A comma-separated scope is parsed rather than rejected');
		Assert.areEqual(2, result.totalCount, 'Both comma-separated levels are in scope');
		Assert.isNotNull(problemByClassName(result, 'CatalogueService'), 'The comma-separated INFO level was parsed into the scope');
		Assert.isNull(problemByClassName(result, 'ShippingService'), 'WARN is absent, so the value was parsed rather than silently replaced by the shipped ERROR;WARN default');
	}

	/**
	 * @description Tests that a value that is not one of the four log levels is dropped from the scope while the
	 * recognised levels beside it still apply — a typo narrows nothing it was not meant to narrow, and never
	 * widens the scan.
	 */
	@IsTest
	private static void shouldIgnoreUnrecognisedDerivedLevelTokens()
	{
		seedLevelScopeSignatures('ERROR;NOTALEVEL');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'An unrecognised token beside a real level still runs the leg');
		Assert.areEqual(1, result.totalCount, 'The recognised level still applies and the unrecognised one adds nothing');
		Assert.areEqual('PricingService', result.records[0].className, 'Only the ERROR signature the recognised level admits is grouped');
	}

	/**
	 * @description Tests that a scope holding no recognisable level at all falls back to the shipped
	 * ERROR;WARN default rather than grouping nothing: a single typo should degrade to the default behaviour,
	 * not switch the feature off until somebody notices an always-empty Problems list.
	 */
	@IsTest
	private static void shouldFallBackToTheShippedLevelScopeWhenNoConfiguredLevelIsRecognised()
	{
		seedLevelScopeSignatures('ERRORS;WARNINGS');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'An unrecognisable scope degrades to the shipped default rather than skipping the leg');
		Assert.areEqual(2, result.totalCount, 'The shipped ERROR;WARN default applies and the INFO signature stays out of scope');
	}

	/**
	 * @description Tests that the pre-flight scan guard sizes the SAME population the fold will read — the
	 * effective level scope, not every level in the window. With the scope at ERROR and the ceiling at three,
	 * three ERROR rows fold while five out-of-scope INFO rows sit in the same window; sizing the unscoped
	 * window would count eight, decline the fold, and strip the derived leg from an org that was never at risk.
	 */
	@IsTest
	private static void shouldSizeTheDerivedScanAgainstTheEffectiveLevelScope()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.ProblemGroupingLogLevels__c, LOG_Engine.LEVEL_ERROR)
				.withoutInsertion(true)
				.build();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(5, LOG_Engine.LEVEL_INFO, CLASS_METHOD_CATALOGUE, 'Catalogue refreshed');
		CTRL_LogConsole.DERIVED_SCAN_ROW_CEILING = 3;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'The out-of-scope rows are not counted against the scan ceiling');
		Assert.areEqual(1, result.totalCount, 'The in-scope signature folds at a ceiling the unscoped window would have breached');
	}

	/**
	 * @description Tests that the ribbon observes the configured level scope exactly as the list does — both
	 * entry points share one derived leg, so an out-of-scope signature must be absent from the summary totals
	 * as well, or the two views would disagree about the same window.
	 */
	@IsTest
	private static void shouldApplyTheConfiguredDerivedLevelScopeToTheSummaryAsWell()
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.ProblemGroupingLogLevels__c, LOG_Engine.LEVEL_ERROR)
				.withoutInsertion(true)
				.build();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(4, LOG_Engine.LEVEL_WARN, CLASS_METHOD_SHIPPING, 'Shipping quote degraded');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, summary.distinctCount, 'The ribbon counts only the in-scope derived signature');
		Assert.areEqual(3, summary.totalOccurrences, 'The out-of-scope WARN occurrences are absent from the ribbon totals');
	}

	/**
	 * @description Tests that a free-text search term suppresses the derived leg (a long-text body
	 * cannot traverse a GROUP BY, so both legs stay filtered by the same rules): the status reports
	 * SKIPPED_SEARCH and no derived problem appears even though foldable forensic rows exist.
	 */
	@IsTest
	private static void shouldSuppressDerivedLegUnderSearch()
	{
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};
		request.searchTerm = 'pricing';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('SKIPPED_SEARCH', result.derivedStatus, 'A search term suppresses the derived leg');
		Assert.isNull(problemBySource(result, 'derived'), 'No derived problems appear under a search term');
	}

	/**
	 * @description Tests that getLogProblems degrades gracefully when the aggregate scan is non-selective at
	 * high volume: rather than erroring the whole view, the page returns empty and the derived leg reports
	 * SKIPPED_NON_SELECTIVE. Injecting a QueryException into the query framework stands in for the table volume
	 * the unit context cannot seed.
	 */
	@IsTest
	private static void shouldDegradeProblemsGracefullyWhenScanNonSelective()
	{
		QRY_Builder.setMockException(LogEntry__c.SObjectType, new QueryException('non-selective query against large object'));

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('SKIPPED_NON_SELECTIVE', result.derivedStatus, 'A non-selective scan degrades the derived leg rather than erroring');
		Assert.areEqual(0, result.totalCount, 'The problems page degrades to empty rather than throwing');
		Assert.isTrue(result.records.isEmpty(), 'No problems are returned when the scan is non-selective');
		Assert.isTrue(result.capped, 'A degraded rollup scan marks the page capped (the list is incomplete)');
		Assert.isTrue(result.totalsApproximate, 'A degraded rollup scan marks the totals best-effort');
	}

	/**
	 * @description Tests that getLogSummary degrades gracefully to a zero summary when the aggregate scan is
	 * non-selective, so the ribbon does not error the view either.
	 */
	@IsTest
	private static void shouldDegradeSummaryGracefullyWhenScanNonSelective()
	{
		QRY_Builder.setMockException(LogEntry__c.SObjectType, new QueryException('non-selective query against large object'));

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(0, summary.totalOccurrences, 'The summary degrades to zero rather than throwing on a non-selective scan');
		Assert.areEqual(0, summary.distinctCount, 'No distinct problems are summarised when the scan is non-selective');
		Assert.isTrue(summary.totalsApproximate, 'A degraded rollup marks the summary totals best-effort');
		Assert.areEqual('PARTIAL', summary.totalsApproximateCause, 'Both legs are absent rather than trimmed, so the console must not explain the zero as truncation');
	}

	/**
	 * @description Tests the headline graceful-degrade shape: when only the derived aggregate scan is
	 * non-selective (injected through the aggregate-scoped seam, so the rollup leg's row queries still run),
	 * the rollup problems survive on the page with derivedStatus SKIPPED_NON_SELECTIVE — rollup-only, never
	 * empty.
	 */
	@IsTest
	private static void shouldKeepRollupProblemsWhenOnlyDerivedLegDegrades()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		QRY_Engine.setMockAggregateException(LogEntry__c.SObjectType, new QueryException('non-selective query against large object'));

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('SKIPPED_NON_SELECTIVE', result.derivedStatus, 'The non-selective derived scan degrades the leg rather than erroring');
		Assert.areEqual(1, result.totalCount, 'The rollup problem survives a derived-only degrade — rollup-only, never empty');
		Assert.isNotNull(problemBySource(result, 'rollup'), 'The fingerprinted rollup problem still renders');
		Assert.isNull(problemBySource(result, 'derived'), 'No derived problems render while the derived leg is degraded');
		Assert.isFalse(result.totalsApproximate, 'The healthy rollup totals stay exact; the missing derived leg is signalled by its status');
	}

	/**
	 * @description Tests that the derived leg is declined BEFORE the fold is issued when the window holds
	 * more foldable rows than the fold may scan. This is the branch that keeps the view alive at volume: a
	 * GROUP BY spends query rows on every row it scans, so a wide enough window raises a query-row limit
	 * exception, and Apex cannot catch that — the leg's QueryException degrade would never run and the whole
	 * page would fail. Declining in advance produces the same rollup-only shape as a caught non-selective
	 * scan, so the subscriber sees a degraded leg rather than a broken console.
	 */
	@IsTest
	private static void shouldDeclineDerivedFoldWhenWindowExceedsScanCeiling()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		CTRL_LogConsole.DERIVED_SCAN_ROW_CEILING = 2;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('SKIPPED_NON_SELECTIVE', result.derivedStatus,
				'A window holding more foldable rows than the fold may scan degrades the leg rather than erroring');
		Assert.areEqual(1, result.totalCount, 'The rollup problem survives the declined derived scan — rollup-only, never empty');
		Assert.isNotNull(problemBySource(result, 'rollup'), 'The fingerprinted rollup problem still renders');
		Assert.isNull(problemBySource(result, 'derived'), 'No derived problems render while the derived scan is declined');
	}

	/**
	 * @description Tests the ceiling boundary: a window holding exactly as many foldable rows as the fold may
	 * scan still folds. The ceiling is the largest scan permitted, not the first one refused, so an
	 * off-by-one here would silently strip the derived leg from orgs sitting on the limit.
	 */
	@IsTest
	private static void shouldFoldDerivedSignaturesAtExactlyTheScanCeiling()
	{
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		CTRL_LogConsole.DERIVED_SCAN_ROW_CEILING = 3;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'A scan exactly at the ceiling is permitted, not declined');
		Assert.isNotNull(problemBySource(result, 'derived'), 'The derived problem folded from the three forensic rows still renders');
	}

	/**
	 * @description Tests that getLogSummary keeps the rollup totals and flags them best-effort when only the
	 * derived leg degrades, so the ribbon never asserts exact totals while the problems page reports
	 * SKIPPED_NON_SELECTIVE for the identical request.
	 */
	@IsTest
	private static void shouldFlagSummaryBestEffortWhenOnlyDerivedLegDegrades()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		QRY_Engine.setMockAggregateException(LogEntry__c.SObjectType, new QueryException('non-selective query against large object'));

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(5, summary.totalOccurrences, 'The surviving rollup contribution still counts');
		Assert.areEqual(1, summary.distinctCount, 'Only the rollup problem is summarised while the derived leg is degraded');
		Assert.isTrue(summary.totalsApproximate, 'A derived-only degrade marks the ribbon totals best-effort to match the page status');
	}

	/**
	 * @description Tests that the derived leg honors the execution-context filter the rollup leg honors: with
	 * forensic rows from two contexts, filtering to one folds only that context's rows into a derived problem
	 * and the ribbon counts only those occurrences — both legs stay filtered by the same rules.
	 */
	@IsTest
	private static void shouldScopeDerivedLegToExecutionContextFilter()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.CalloutException')
				.withOverride(LogEntry__c.ClassMethod__c, 'PaymentGateway.capture')
				.withOverride(LogEntry__c.ShortMessage__c, 'Read timed out')
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.AURA.name())
				.withCount(2)
				.buildList();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.LimitException')
				.withOverride(LogEntry__c.ClassMethod__c, 'NightlyRollup.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'Too many queries')
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.BATCH_APEX.name())
				.withCount(3)
				.buildList();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		request.executionEvents = new List<String> {Quiddity.AURA.name()};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('COMPLETE', result.derivedStatus, 'The derived leg still runs under a context filter');
		Assert.areEqual(1, result.totalCount, 'Only the filtered context folds into a derived problem');
		CTRL_LogConsole.DTO_LogProblem derived = problemBySource(result, 'derived');
		Assert.isNotNull(derived, 'The in-context derived problem appears');
		Assert.areEqual('System.CalloutException', derived.exceptionType, 'The derived problem is the in-context signature');
		Assert.areEqual(2, derived.occurrenceCount, 'Only the in-context rows are counted');
		Assert.areEqual(2, summary.totalOccurrences, 'The ribbon counts only the in-context derived occurrences');
	}

	/**
	 * @description Tests that the derived leg honors an active correlation deep-link the way the rollup leg
	 * does: only forensic rows carrying the pinned CorrelationId__c fold into derived problems, so a
	 * correlation-scoped Problems view never lists unrelated derived problems.
	 */
	@IsTest
	private static void shouldScopeDerivedLegToCorrelationDeepLink()
	{
		String pinnedCorrelation = UTIL_Random.randomUUID();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.CalloutException')
				.withOverride(LogEntry__c.ClassMethod__c, 'ChainStep.execute')
				.withOverride(LogEntry__c.ShortMessage__c, 'Chain step failed')
				.withOverride(LogEntry__c.CorrelationId__c, pinnedCorrelation)
				.withCount(2)
				.buildList();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		request.correlationId = pinnedCorrelation;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, result.totalCount, 'Only the correlated rows fold into a derived problem');
		CTRL_LogConsole.DTO_LogProblem derived = problemBySource(result, 'derived');
		Assert.isNotNull(derived, 'The correlated derived problem appears');
		Assert.areEqual('ChainStep', derived.className, 'The derived problem is the correlated signature');
		Assert.areEqual(2, derived.occurrenceCount, 'Only the correlated rows are counted');
		Assert.areEqual(2, summary.totalOccurrences, 'The ribbon counts only the correlated derived occurrences');
	}

	/**
	 * @description Tests that a derived problem maps the signature to display fields: level, the
	 * MAX(ShortMessage__c) label, the exception type, and the source split into class name and method with no
	 * line number (the line is not part of the key).
	 */
	@IsTest
	private static void shouldMapDerivedProblemDisplayFields()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.CalloutException')
				.withOverride(LogEntry__c.ClassMethod__c, 'PaymentGateway.capture')
				.withOverride(LogEntry__c.ShortMessage__c, 'Read timed out')
				.withCount(4)
				.buildList();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		CTRL_LogConsole.DTO_LogProblem derived = problemBySource(result, 'derived');
		Assert.isNotNull(derived, 'The forensic rows fold into a derived problem');
		Assert.areEqual(LOG_Engine.LEVEL_WARN, derived.level, 'Level comes from the signature');
		Assert.areEqual('Read timed out', derived.shortMessage, 'The label is the MAX(ShortMessage__c)');
		Assert.areEqual('System.CalloutException', derived.exceptionType, 'The exception type comes from the signature');
		Assert.areEqual('PaymentGateway', derived.className, 'The class name is the first segment of ClassMethod__c');
		Assert.areEqual('capture', derived.methodLine, 'The method line is the method with no line number');
		Assert.areEqual(4, derived.occurrenceCount, 'The count is the number of forensic rows');
	}

	/**
	 * @description Tests that getLogSummary folds the derived signatures into the ribbon totals the same way
	 * getLogProblems folds them into the list, so the ribbon and the list agree: total occurrences, distinct
	 * count, and the per-level breakdown all include both the rollup and the derived legs.
	 */
	@IsTest
	private static void shouldFoldDerivedSignaturesIntoSummary()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(8, summary.totalOccurrences, 'Total occurrences fold the rollup (5) and derived (3) legs so the ribbon matches the list');
		Assert.areEqual(2, summary.distinctCount, 'Both the rollup problem and the derived problem count as distinct');
		CTRL_LogConsole.DTO_LevelSummary errorLevel = levelSummaryFor(summary, LOG_Engine.LEVEL_ERROR);
		Assert.isNotNull(errorLevel, 'The ERROR level summary is present');
		Assert.areEqual(8, errorLevel.occurrences, 'The ERROR per-level occurrences fold both legs');
		Assert.areEqual(2, errorLevel.distinctCount, 'The ERROR per-level distinct count folds both legs');
	}

	/**
	 * @description Tests that getLogSummary creates a per-level summary entry from the derived leg alone when a
	 * derived signature sits at a level with no rollup problem — a WARN derived problem alongside an ERROR-only
	 * rollup problem must still surface a WARN ribbon card.
	 */
	@IsTest
	private static void shouldCreatePerLevelSummaryForADerivedOnlyLevel()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(2, LOG_Engine.LEVEL_WARN, 'BravoService.run', 'a warning row');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		CTRL_LogConsole.DTO_LevelSummary warnLevel = levelSummaryFor(summary, LOG_Engine.LEVEL_WARN);
		Assert.isNotNull(warnLevel, 'The WARN per-level summary is created from the derived leg alone');
		Assert.areEqual(2, warnLevel.occurrences, 'The WARN occurrences come from the derived signature');
		Assert.areEqual(1, warnLevel.distinctCount, 'One distinct WARN derived problem');
	}

	/**
	 * @description Tests that getDerivedProblemDetail opens a derived problem to its most-recent representative
	 * forensic row, so a derived problem (which has no record id) renders the same detail drawer as a
	 * fingerprinted one.
	 *
	 * Also pins the two source values apart on a row that carries a line number: methodLine is the display
	 * string and keeps the line, classMethod is the raw source the entry recorded and must not. The drawer's
	 * generated tagging snippet passes the raw source to emitAt, so a line number reaching it there would be
	 * baked into the subscriber's own code and mis-attribute every entry tagged with it afterwards.
	 */
	@IsTest
	private static void shouldOpenDerivedProblemToRepresentativeRow()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.CalloutException')
				.withOverride(LogEntry__c.ClassMethod__c, 'PaymentGateway.capture')
				.withOverride(LogEntry__c.LineNumber__c, 64)
				.withOverride(LogEntry__c.ShortMessage__c, 'Read timed out')
				.withOverride(LogEntry__c.Message__c, 'Read timed out after 10000ms')
				.withCount(3)
				.buildList();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		CTRL_LogConsole.DTO_LogProblemPage problems = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogProblem derived = problemBySource(problems, 'derived');
		Assert.isNotNull(derived, 'The forensic rows fold into a derived problem to open');

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getDerivedProblemDetail(derived.signature, JSON.serialize(request));
		Test.stopTest();

		Assert.isNotNull(detail, 'A derived problem opens to a representative forensic row');
		Assert.isNotNull(detail.id, 'The representative is a real row with an id');
		Assert.areEqual('System.CalloutException', detail.exceptionType, 'The representative matches the signature exception type');
		Assert.areEqual('Read timed out', detail.shortMessage, 'The representative carries the short message');
		Assert.areEqual('Read timed out after 10000ms', detail.message, 'The full message renders from the representative');
		Assert.areEqual('capture:64', detail.methodLine, 'The display location folds the line number into the method segment');
		Assert.areEqual('PaymentGateway.capture', detail.classMethod,
				'The raw source is the value the entry recorded, with no line number: it is what the generated snippet hands to emitAt');
	}

	/**
	 * @description Tests that getDerivedProblemDetail falls back to a label-only detail when every occurrence
	 * of the signature has been purged between the fold and the click, so the drawer still renders rather than
	 * erroring or returning nothing. Runs the real path end to end — fold the seeded rows, capture the encoded
	 * signature off the page, delete the rows, then open — so the signature the encoder writes (including the
	 * label key the fallback reads) is proven against the fallback decoder, not restated by the test.
	 */
	@IsTest
	private static void shouldFallBackToLabelWhenRepresentativePurged()
	{
		List<LogEntry__c> purgeable = TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.NullPointerException')
				.withOverride(LogEntry__c.ClassMethod__c, 'GhostService.run')
				.withOverride(LogEntry__c.ShortMessage__c, 'Attempt to de-reference a null object')
				.withCount(2)
				.buildList();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		CTRL_LogConsole.DTO_LogProblem derived = problemBySource(CTRL_LogConsole.getLogProblems(JSON.serialize(request)), 'derived');
		Assert.isNotNull(derived, 'The seeded rows fold into the derived problem whose captured signature is opened after the purge');
		DML_Builder.newTransaction().withSystemMode().doDelete(purgeable).execute(); // NOPMD: test purge of framework-owned rows — a user-mode delete FLS-fails in managed validation

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getDerivedProblemDetail(derived.signature, JSON.serialize(request));
		Test.stopTest();

		Assert.isNotNull(detail, 'A purged derived problem still returns a fallback detail');
		Assert.isNull(detail.id, 'The fallback has no record id');
		Assert.areEqual('Attempt to de-reference a null object', detail.shortMessage, 'The fallback carries the signature label through the encoded signature');
		Assert.areEqual('System.NullPointerException', detail.exceptionType, 'The fallback carries the exception type');
		Assert.areEqual('GhostService', detail.className, 'The fallback carries the source class');
		Assert.areEqual('GhostService.run', detail.classMethod, 'The fallback carries the raw source the generated snippet tags against');
		Assert.isNotNull(detail.limitBars, 'The fallback carries an empty limit list, never null: a null takes the whole detail pane down when the console reads it');
		Assert.isTrue(detail.limitBars.isEmpty(), 'A purged problem has no row left to report limits from');
	}

	/**
	 * @description Tests that getDerivedProblemDetail returns null for a blank or null signature rather than
	 * throwing.
	 */
	@IsTest
	private static void shouldReturnNullDetailForBlankSignature()
	{
		Assert.isNull(CTRL_LogConsole.getDerivedProblemDetail('', null), 'A blank signature returns null');
		Assert.isNull(CTRL_LogConsole.getDerivedProblemDetail(null, null), 'A null signature returns null');
	}

	/**
	 * @description Tests that a signature the console did not encode is answered the same way a blank one is.
	 * The value crosses the wire under the client's control, so text that is not JSON at all, a JSON array and
	 * a bare JSON scalar each return null instead of surfacing a raw platform error on a click the console
	 * itself offered, and so does a signature object with no log level — a field every signature the fold writes
	 * is keyed on. A well-formed signature object carrying a non-string member is a different case: it is still
	 * the shape the drawer can render, so its members are read as text rather than thrown on.
	 */
	@IsTest
	private static void shouldReturnNullDetailForAMalformedSignature()
	{
		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail fromMalformedJson = CTRL_LogConsole.getDerivedProblemDetail('{not json', null);
		CTRL_LogConsole.DTO_LogEntryDetail fromJsonArray = CTRL_LogConsole.getDerivedProblemDetail('[1,2]', null);
		CTRL_LogConsole.DTO_LogEntryDetail fromJsonScalar = CTRL_LogConsole.getDerivedProblemDetail('"x"', null);
		CTRL_LogConsole.DTO_LogEntryDetail fromNumericExceptionType =
				CTRL_LogConsole.getDerivedProblemDetail('{"exceptionType":5,"classMethod":"A.b","logLevel":"ERROR","label":"x"}', null);
		CTRL_LogConsole.DTO_LogEntryDetail withoutLevel =
				CTRL_LogConsole.getDerivedProblemDetail('{"exceptionType":"System.NullPointerException","classMethod":"A.b","label":"x"}', null);
		Test.stopTest();

		Assert.isNull(fromMalformedJson, 'Text that is not JSON returns null rather than surfacing the deserialise failure');
		Assert.isNull(fromJsonArray, 'A JSON array is not the signature object the console encodes, so it returns null');
		Assert.isNull(fromJsonScalar, 'A bare JSON scalar is not the signature object either, so it returns null');
		Assert.isNotNull(fromNumericExceptionType, 'A signature object whose member is a number still renders the fallback drawer');
		Assert.areEqual('5', fromNumericExceptionType.exceptionType, 'A non-string member is read as text rather than cast to String and thrown on');
		Assert.isNull(withoutLevel, 'A signature with no log level was not written by the fold, and a level-less fallback would hand the drawer a detail it cannot render');
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
	 * @description Tests that a pinned source narrows the distinct-problems view as well as the entries
	 * view, because the pin is a filter the reader can see and clear and it survives a view switch. The
	 * rollup: counter rows carry no source at all, so the pin can only be applied against the detail
	 * samples in memory; a signature whose sample was logged from another class is dropped there.
	 */
	@IsTest
	private static void shouldFilterDistinctProblemsByPinnedSource()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {9});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_OPPORTUNITY, new List<Integer> {4});

		CTRL_LogConsole.DTO_Request pinned = new CTRL_LogConsole.DTO_Request();
		pinned.windowMinutes = WINDOW_SEVEN_DAYS;
		pinned.classMethod = CLASS_METHOD_ACCOUNT;

		CTRL_LogConsole.DTO_Request unpinned = new CTRL_LogConsole.DTO_Request();
		unpinned.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage pinnedPage = CTRL_LogConsole.getLogProblems(JSON.serialize(pinned));
		CTRL_LogConsole.DTO_LogProblemPage unpinnedPage = CTRL_LogConsole.getLogProblems(JSON.serialize(unpinned));
		Test.stopTest();

		Assert.areEqual(1, pinnedPage.totalCount, 'Only the problem logged from the pinned source should fold into the page');
		Assert.areEqual(CLASS_METHOD_ACCOUNT, pinnedPage.records[0].classMethod, 'The folded problem should carry the pinned source');
		Assert.areEqual(2, unpinnedPage.totalCount, 'Without a pin both seeded problems should fold, so the pin is what narrowed the page');
	}

	/**
	 * @description Tests that the pinned source narrows the DERIVED problems the same way it narrows the
	 * rollup ones: the read-time fold of plain forensic rows applies the source filter in its own query, so
	 * a problems page under an active source pill never lists a derived problem from another source beside
	 * the pill that claims to filter it.
	 */
	@IsTest
	private static void shouldFilterDerivedProblemsByPinnedSource()
	{
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Unhandled shipping error');

		CTRL_LogConsole.DTO_Request pinned = new CTRL_LogConsole.DTO_Request();
		pinned.windowMinutes = WINDOW_SEVEN_DAYS;
		pinned.classMethod = CLASS_METHOD_PRICING;

		CTRL_LogConsole.DTO_Request unpinned = new CTRL_LogConsole.DTO_Request();
		unpinned.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage pinnedPage = CTRL_LogConsole.getLogProblems(JSON.serialize(pinned));
		CTRL_LogConsole.DTO_LogProblemPage unpinnedPage = CTRL_LogConsole.getLogProblems(JSON.serialize(unpinned));
		Test.stopTest();

		Assert.areEqual('COMPLETE', pinnedPage.derivedStatus, 'The derived leg still runs under a source pin');
		Assert.areEqual(1, pinnedPage.totalCount, 'Only the derived problem from the pinned source should fold into the page');
		Assert.areEqual(CLASS_METHOD_PRICING, pinnedPage.records[0].classMethod, 'The folded derived problem should carry the pinned source');
		Assert.areEqual(3, pinnedPage.records[0].occurrenceCount, 'The pinned fold should count only the pinned source rows');
		Assert.areEqual(2, unpinnedPage.totalCount, 'Without a pin both derived signatures should fold, so the pin is what narrowed the page');
	}

	/**
	 * @description Tests that getLogSummary scopes BOTH of its legs to the pinned source, so the ribbon over
	 * a pinned problems view counts only the pinned source: the rollup leg drops its out-of-source sample and
	 * the derived fold applies the source filter in its own query.
	 */
	@IsTest
	private static void shouldScopeSummaryToPinnedSourceAcrossBothLegs()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Unhandled shipping error');

		CTRL_LogConsole.DTO_Request pinned = new CTRL_LogConsole.DTO_Request();
		pinned.windowMinutes = WINDOW_SEVEN_DAYS;
		pinned.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};
		pinned.classMethod = CLASS_METHOD_PRICING;

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(pinned));
		Test.stopTest();

		Assert.areEqual(3, summary.totalOccurrences, 'The ribbon should count only the pinned source: the derived rows, not the out-of-source rollup');
		Assert.areEqual(1, summary.distinctCount, 'Only the pinned source\'s derived problem should count as distinct');
		CTRL_LogConsole.DTO_LevelSummary errorLevel = levelSummaryFor(summary, LOG_Engine.LEVEL_ERROR);
		Assert.isNotNull(errorLevel, 'The ERROR level summary is present for the pinned source');
		Assert.areEqual(3, errorLevel.occurrences, 'The ERROR occurrences should cover only the pinned source');
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
	 * @description Tests that a search term is matched character for character, so the two characters that
	 * carry wildcard meaning inside a SOQL LIKE pattern do not widen the search. Each term is seeded
	 * alongside a decoy that differs only at the metacharacter, and the decoy is the row an unescaped
	 * pattern would wrongly return: '%' would stand for any run of characters, and '_' for any single one.
	 */
	@IsTest
	private static void shouldMatchSearchTermCharacterForCharacter()
	{
		LogEntry__c percentMatch = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ShortMessage__c => 'Discount applied: ' + SEARCH_TERM_LITERAL_PERCENT + ' off'
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ShortMessage__c => 'Discount applied: 100 off'
		});
		LogEntry__c underscoreMatch = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NOTIFICATION,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
				LogEntry__c.ShortMessage__c => 'Timeout calling ' + SEARCH_TERM_LITERAL_UNDERSCORE
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
				LogEntry__c.ShortMessage__c => 'Timeout calling UTILxHttpClient'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage percentPage = entriesMatching(SEARCH_TERM_LITERAL_PERCENT);
		CTRL_LogConsole.DTO_LogEntryPage underscorePage = entriesMatching(SEARCH_TERM_LITERAL_UNDERSCORE);
		Test.stopTest();

		Assert.areEqual(1, percentPage.totalCount, 'A percent sign in the term should match only the entry that literally contains it');
		Assert.areEqual(percentMatch.Id, percentPage.records[0].id, 'The entry carrying the literal percent sign should be the only match');
		Assert.areEqual(1, underscorePage.totalCount, 'An underscore in the term should match only the entry that literally contains it');
		Assert.areEqual(underscoreMatch.Id, underscorePage.records[0].id, 'The entry carrying the literal underscore should be the only match');
	}

	/**
	 * @description Tests that the source filter behind "View occurrences" lists the entries a problem was
	 * grouped from and nothing else. The decoy row is logged from a different class but names the drilled
	 * class in its own message, which is exactly the row a free-text search on the class name returns.
	 */
	@IsTest
	private static void shouldListOnlyTheEntriesLoggedFromTheDrilledSource()
	{
		LogEntry__c fromSource = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_PRICING,
				LogEntry__c.ShortMessage__c => 'List has no rows for assignment to SObject'
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_SHIPPING,
				LogEntry__c.ShortMessage__c => 'Callout to ' + CLASS_METHOD_PRICING + ' timed out'
		});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.classMethod = CLASS_METHOD_PRICING;

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage result = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, result.totalCount, 'Only the entry logged from the drilled source should be listed');
		Assert.areEqual(fromSource.Id, result.records[0].id, 'The listed entry should be the one logged from the drilled source');
		Assert.areEqual(1, summary.totalRows, 'The ribbon should count the same entries the table lists');
	}

	/**
	 * @description Tests that the problems view's opening order puts the most severe problem first and
	 * ranks equally severe problems by how often each occurred, so a chatty INFO message cannot head a
	 * list of problems above an error that occurred less often.
	 */
	@IsTest
	private static void shouldRankProblemsBySeverityThenOccurrenceCount()
	{
		seedDistinctProblem(BASE_NULL_POINTER, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_INFO,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_CATALOGUE,
				LogEntry__c.ShortMessage__c => 'Checkout completed'
		}, CHATTY_OCCURRENCE_COUNT);
		seedDistinctProblem(BASE_OTHER, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_PRICING,
				LogEntry__c.ShortMessage__c => 'List has no rows for assignment to SObject'
		}, RARE_OCCURRENCE_COUNT);
		seedDistinctProblem(BASE_NOTIFICATION, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_SHIPPING,
				LogEntry__c.ShortMessage__c => 'Read timed out'
		}, RARE_OCCURRENCE_COUNT - 1);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_INFO};
		request.sortField = 'level';

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage result = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(3, result.totalCount, 'All three seeded problems should fold into the page');
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, result.records[0].level, 'The most severe problem should head the list');
		Assert.areEqual(RARE_OCCURRENCE_COUNT, result.records[0].occurrenceCount, 'The more frequent of the two errors should come first');
		Assert.areEqual(RARE_OCCURRENCE_COUNT - 1, result.records[1].occurrenceCount, 'The less frequent error should follow its more frequent sibling');
		Assert.areEqual(LOG_Engine.LEVEL_INFO, result.records[2].level, 'The chatty INFO message should rank below both errors');
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
		TST_Factory.seedLogEntry(SHORT_MESSAGE_SEARCH_MATCH_FIELDS);
		LogEntry__c bodyMatch = TST_Factory.seedLogEntry(BODY_SEARCH_MATCH_FIELDS);
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
		Map<SObjectField, Object> matchedCorrelationFields = new Map<SObjectField, Object>(SHORT_MESSAGE_SEARCH_MATCH_FIELDS);
		matchedCorrelationFields.put(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID);
		TST_Factory.seedLogEntry(matchedCorrelationFields);
		Map<SObjectField, Object> otherCorrelationFields = new Map<SObjectField, Object>(SHORT_MESSAGE_SEARCH_MATCH_FIELDS);
		otherCorrelationFields.put(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER);
		otherCorrelationFields.put(LogEntry__c.ClassMethod__c, 'BravoService.run');
		otherCorrelationFields.put(LogEntry__c.CorrelationId__c, 'a-different-correlation');
		TST_Factory.seedLogEntry(otherCorrelationFields);

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
		TST_Factory.seedLogEntry(SHORT_MESSAGE_SEARCH_MATCH_FIELDS);
		LogEntry__c bodyMatch = TST_Factory.seedLogEntry(BODY_SEARCH_MATCH_FIELDS);
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
	 * @description Tests that getEntrySummary declines the per-level and per-source breakdown past the scan
	 * ceiling: the two windowed aggregates spend query rows on every row they scan, so past the ceiling the
	 * ribbon answers with the exact total from the pre-flight count, empty breakdown lists (never null), and
	 * the declined flag — instead of an uncatchable row-limit exception taking the whole request down.
	 */
	@IsTest
	private static void shouldDeclineTheEntriesRibbonBreakdownPastTheScanCeiling()
	{
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		CTRL_LogConsole.ENTRY_SUMMARY_SCAN_ROW_CEILING = 1;
		// Armed for any aggregate leg, and only aggregate legs: the pre-flight COUNT() passes it untouched, so a
		// guard that ran AFTER the scans — the ordering this test exists to pin — throws here and fails the test
		// (getEntrySummary carries no catch, exactly because the real overrun is uncatchable).
		QRY_Engine.setMockAggregateException(LogEntry__c.SObjectType, new QueryException('the breakdown must be declined before it is scanned'));

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.isTrue(summary.declined, 'Two rows over a ceiling of one must decline the breakdown');
		Assert.areEqual(2, summary.totalRows, 'The declined ribbon still carries the exact total the pre-flight count measured');
		Assert.isNotNull(summary.perLevel, 'The declined per-level list is empty, never null: the console reads it');
		Assert.isTrue(summary.perLevel.isEmpty(), 'No per-level breakdown may render when the scan was declined');
		Assert.isNotNull(summary.topSources, 'The declined top-source list is empty, never null: the console reads it');
		Assert.isTrue(summary.topSources.isEmpty(), 'No top-source ranking may render when the scan was declined');
	}

	/**
	 * @description Tests the ceiling boundary: a window holding exactly the ceiling still folds (the guard is
	 * strictly greater-than), so the worst admitted scan is the ceiling itself and the ribbon never declines a
	 * request early.
	 */
	@IsTest
	private static void shouldFoldTheEntriesRibbonAtExactlyTheScanCeiling()
	{
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		CTRL_LogConsole.ENTRY_SUMMARY_SCAN_ROW_CEILING = 2;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.isFalse(summary.declined, 'A window holding exactly the ceiling still folds: the guard is strictly greater-than');
		Assert.areEqual(2, summary.totalRows, 'The breakdown ran, so the total comes from the per-level aggregate');
		Assert.areEqual(2, entryLevelCountFor(summary, LOG_Engine.LEVEL_ERROR), 'The per-level breakdown renders at the boundary');
	}

	/**
	 * @description Tests that the ribbon guard counts the requested scope, not the whole table: rows outside
	 * the requested levels must not count against the ceiling, or a busy INFO stream would decline the
	 * breakdown of a quiet ERROR view.
	 */
	@IsTest
	private static void shouldCountOnlyTheRequestedScopeAgainstTheRibbonCeiling()
	{
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(3, LOG_Engine.LEVEL_INFO, CLASS_METHOD_CATALOGUE, 'Catalogue refreshed');
		CTRL_LogConsole.ENTRY_SUMMARY_SCAN_ROW_CEILING = 2;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.isFalse(summary.declined, 'Only the two ERROR rows are in scope, so a ceiling of two admits the scan');
		Assert.areEqual(2, summary.totalRows, 'The INFO rows outside the requested levels are neither counted nor summarised');
	}

	/**
	 * @description Tests that a searched ribbon is exempt from the scan ceiling: it aggregates over the bounded
	 * matched-id set rather than the window, so the guard must not decline it however low the ceiling sits.
	 */
	@IsTest
	private static void shouldKeepTheSearchedRibbonExemptFromTheScanCeiling()
	{
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'searchneedle timed out');
		CTRL_LogConsole.ENTRY_SUMMARY_SCAN_ROW_CEILING = 1;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = 'searchneedle';

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.isFalse(summary.declined, 'The searched ribbon aggregates the matched ids, not the window, so the ceiling does not apply');
		Assert.areEqual(2, summary.totalRows, 'Both matching rows count through the matched-id aggregate');
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
		List<LogEntry__c> rows = TST_Builder.of(LogEntry__c.SObjectType).withOverrides(CHATTY_HOP_FIELDS).withCount(SEL_LogEntry.CORRELATION_TRACE_ROW_CAP + 1).buildList();

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
		List<LogEntry__c> rows = TST_Builder.of(LogEntry__c.SObjectType).withOverrides(CHATTY_HOP_FIELDS).withCount(SEL_LogEntry.CORRELATION_TRACE_ROW_CAP).buildList();

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
	 * the NEWER row but is inserted first (so it takes the lower Log Number auto-number) and is lower on level,
	 * class name, duration, short message, execution context and correlation id, so an ascending sort by any of
	 * those seven must return the alpha row first, while an ascending sort by createdDate returns the zulu row
	 * first. A broken sort-field mapping that degraded to CreatedDate would flip the result and fail. The level
	 * field uses INFO vs ERROR so it also proves the picklist-severity ordering (INFO precedes ERROR in the
	 * picklist even though it follows it alphabetically); BATCH_APEX precedes QUEUEABLE in both alphabetical
	 * and picklist-definition order, so the execution-context axis is stable regardless of which rule the
	 * platform applies. The server re-sorts each request statelessly.
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
				'logNumber' => alphaRow.Id,
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
	 * @description Tests that the flat-entries view orders by the Log Number column in both directions. The
	 * table advertises that column as sortable and sends the logNumber key, which must resolve to the
	 * LogEntry__c auto-number rather than silently degrading to the CreatedDate fallback while the sort
	 * arrow sits on Log Number. The fixture is ANTI-aligned on those two axes: the row inserted first takes
	 * the lower zero-padded auto-number but is given the NEWER CreatedDate, so an ascending Log Number sort
	 * must return it first while an ascending CreatedDate sort returns the other row first — and the
	 * descending pair mirrors that. Both directions are asserted against the auto-numbers read back through
	 * the selector, so a controller whose sort allow-list omits the Log Number key fails on both.
	 */
	@IsTest
	private static void shouldSortEntriesByLogNumber()
	{
		LogEntry__c lowerNumberedRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.ShortMessage__c => 'The lower-numbered, newer entry'
		});
		LogEntry__c higherNumberedRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_OPPORTUNITY,
				LogEntry__c.ShortMessage__c => 'The higher-numbered, older entry'
		});
		Test.setCreatedDate(lowerNumberedRow.Id, Datetime.now().addHours(-1));
		Test.setCreatedDate(higherNumberedRow.Id, Datetime.now().addHours(-2));

		SEL_LogEntry selector = new SEL_LogEntry();
		String lowerLogNumber = selector.findByIdForConsole(lowerNumberedRow.Id).Name;
		String higherLogNumber = selector.findByIdForConsole(higherNumberedRow.Id).Name;

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage ascendingPage = entriesSortedByLogNumber(true);
		CTRL_LogConsole.DTO_LogEntryPage descendingPage = entriesSortedByLogNumber(false);
		Test.stopTest();

		Assert.isTrue(lowerLogNumber.compareTo(higherLogNumber) < 0, 'The row inserted first takes the lower auto-number, reversing the seeded CreatedDate order');
		Assert.areEqual(2, ascendingPage.records.size(), 'Both seeded rows fall inside the window');
		Assert.areEqual(lowerLogNumber, ascendingPage.records[0].logNumber, 'Ascending Log Number sort puts the lower auto-number first, not the CreatedDate fallback row');
		Assert.areEqual(higherLogNumber, descendingPage.records[0].logNumber, 'Descending Log Number sort puts the higher auto-number first, not the CreatedDate fallback row');
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
		Assert.areEqual('BatchRecalc/execute', detail.classMethod, 'The raw source crosses the wire exactly as the entry recorded it, slash form and all');
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
		Assert.areEqual('TRUNCATED', summary.totalsApproximateCause, 'An overflowing candidate set trims the totals, which is what the shipped help text describes');
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
		Assert.isNull(summary.totalsApproximateCause, 'Exact totals carry no cause, so the console has nothing to explain away');
		Assert.areEqual(30, summary.totalOccurrences, 'Both counters fold when the candidate set exactly fills the cap');
		Assert.isFalse(problems.totalsApproximate, 'The problems page must not flag best-effort totals when nothing overflowed');
	}

	/**
	 * @description Tests the derived half of the TRUNCATED cause: with the group cap lowered to one and two
	 * distinct signatures in the window, the fold comes back full, the page reports its list incomplete, and the
	 * ribbon flags the totals best-effort as trimmed. Every other TRUNCATED test drives the ROLLUP cap, so a
	 * derived fold that hit its cap and reported the wrong cause — or none — would otherwise go unnoticed, and
	 * the console would explain a real gap with copy written for a different one.
	 */
	@IsTest
	private static void shouldReportACappedDerivedFoldAsTheTruncatedTotalsCause()
	{
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Shipping quote failed');
		CTRL_LogConsole.PROBLEM_CANDIDATE_CAP = 1;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage page = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.isTrue(page.capped, 'A derived fold returning a full cap leaves the distinct problem list incomplete');
		Assert.areEqual(1, page.totalCount, 'Only one of the two signatures survives a group cap of one');
		Assert.isTrue(summary.totalsApproximate, 'A capped derived fold leaves the ribbon totals best-effort');
		Assert.areEqual('TRUNCATED', summary.totalsApproximateCause, 'A capped candidate set trims the totals rather than leaving a leg absent');
	}

	/**
	 * @description Tests that PARTIAL wins when both kinds of gap apply to one request: the rollup counters
	 * overflow their cap (the totals are trimmed) while the derived scan is declined before it runs (its
	 * contribution is absent). An absent leg is the larger gap and the shipped truncation copy is plainly false
	 * about it, so the cause the console explains has to be the absent one. The folded total is asserted too,
	 * because it is what proves the rollup really did overflow — without it the precedence assertion would pass
	 * over a request where only one gap ever applied.
	 */
	@IsTest
	private static void shouldPreferThePartialTotalsCauseWhenBothGapsApply()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {10, 20, 30});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		CTRL_LogConsole.ROLLUP_CANDIDATE_CAP = 2;
		CTRL_LogConsole.DERIVED_SCAN_ROW_CEILING = 2;

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.isTrue(summary.totalsApproximate, 'Either gap alone leaves the totals best-effort, and both of them apply here');
		Assert.areEqual(50, summary.totalOccurrences, 'Only the two newest counters fold at a cap of two, so the rollup candidate set genuinely overflowed');
		Assert.areEqual('PARTIAL', summary.totalsApproximateCause, 'A leg that never ran outranks a trimmed candidate set: PARTIAL wins when both apply');
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
	 * @description Configures ProblemGroupingLogLevels__c and seeds one foldable ERROR, WARN and INFO signature
	 * behind it, so every level-scope test reads the same three-level window and differs only in the value
	 * under test and the levels it expects to survive. Holding the fixture in one place is what makes the
	 * scope assertions comparable — a level that quietly stopped being seeded would otherwise read as a scope
	 * correctly excluding it.
	 *
	 * @param configuredLevels The ProblemGroupingLogLevels__c value to configure.
	 */
	private static void seedLevelScopeSignatures(String configuredLevels)
	{
		LOG_Engine.logSettingOverride = (LogSetting__c)TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.ProblemGroupingLogLevels__c, configuredLevels)
				.withoutInsertion(true)
				.build();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(3, LOG_Engine.LEVEL_WARN, CLASS_METHOD_SHIPPING, 'Shipping quote degraded');
		seedForensicEntries(3, LOG_Engine.LEVEL_INFO, CLASS_METHOD_CATALOGUE, 'Catalogue refreshed');
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
	 * @description Finds the first problem on a page with the given provenance ('rollup' or 'derived'), or
	 * null when none matches, so the merge tests can assert on each leg independently.
	 *
	 * @param page The problem page.
	 * @param source The provenance to find.
	 *
	 * @return The first matching problem, or null.
	 */
	private static CTRL_LogConsole.DTO_LogProblem problemBySource(CTRL_LogConsole.DTO_LogProblemPage page, String source)
	{
		for(CTRL_LogConsole.DTO_LogProblem problem : page.records)
		{
			if(source.equals(problem.source))
			{
				return problem;
			}
		}
		return null;
	}

	/**
	 * @description Finds the problem folded from a given source class on a page, or null when that class
	 * contributed none. The level-scope tests seed one signature per level under a distinct source class, so
	 * naming the class is how they assert which levels survived the scope — an absence assertion a bare page
	 * count cannot express.
	 *
	 * @param page The problems page.
	 * @param className The source class name to find.
	 *
	 * @return The problem for that source class, or null when it is absent.
	 */
	private static CTRL_LogConsole.DTO_LogProblem problemByClassName(CTRL_LogConsole.DTO_LogProblemPage page, String className)
	{
		for(CTRL_LogConsole.DTO_LogProblem problem : page.records)
		{
			if(className.equals(problem.className))
			{
				return problem;
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
	 * @description Requests the flat entries page for a free-text search term over a seven-day window, so
	 * the searches that differ only in the term being typed are built in one place.
	 *
	 * @param searchTerm The free-text term to search for.
	 *
	 * @return The resulting entries page.
	 */
	private static CTRL_LogConsole.DTO_LogEntryPage entriesMatching(String searchTerm)
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = searchTerm;
		return CTRL_LogConsole.getLogEntries(JSON.serialize(request));
	}

	/**
	 * @description Requests the flat entries page sorted by the Log Number column over a seven-day window,
	 * in the given direction, so both directions of that sort are built in one place.
	 *
	 * @param ascending Whether to sort ascending; false sorts descending.
	 *
	 * @return The resulting entries page.
	 */
	private static CTRL_LogConsole.DTO_LogEntryPage entriesSortedByLogNumber(Boolean ascending)
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.sortField = 'logNumber';
		request.sortAscending = ascending;
		return CTRL_LogConsole.getLogEntries(JSON.serialize(request));
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