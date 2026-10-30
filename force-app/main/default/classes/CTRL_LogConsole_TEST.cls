// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for the CTRL_LogConsole console controller: the distinct-problems fold,
 * the flat entries page, the scope summary, and the single-entry detail (with governor-limit bars). The class also
 * measures the Chain Monitor's page scoped to a two-thousand-run action against the same query and CPU ceilings.
 *
 * @see CTRL_LogConsole
 * @see CTRL_ChainMonitor
 * @see UTIL_Limits
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date June 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
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
	 * @description The three writers both Source-column sort tests seed, already in name order, so the ascending expectation
	 * is this list itself and the descending one is its reverse.
	 */
	private static final List<String> SORTED_WRITER_NAMES = new List<String> {'AlphaService', 'MidService', 'ZuluService'};

	/**
	 * @description The class that holds each of those three writers, in the same positions but in the opposite name order, so
	 * a view still sorting the Source column by the class method returns the three rows backwards and fails.
	 */
	private static final List<String> WRITER_HOLDER_CLASS_NAMES = new List<String> {'ZzzHolder', 'MmmHolder', 'AaaHolder'};

	/**
	 * @description The positions the Source-column sort tests seed those three writers in: neither the expected ascending
	 * order nor its reverse, so a view that had fallen back to the order the rows were written in fails both ways.
	 */
	private static final List<Integer> SEEDING_ORDER = new List<Integer> {1, 2, 0};

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
	 * @description The name of the Flow the class-name tests log from, as the entry stores it for the writer.
	 */
	private static final String FLOW_NAME = 'Order Intake';

	/**
	 * @description The class method the Flow bridges record for that Flow: the Flow marker, then the Flow's name.
	 */
	private static final String CLASS_METHOD_FLOW = LOG_Engine.FLOW_SOURCE_PREFIX + FLOW_NAME;

	/**
	 * @description The class name the console read from a Flow's class method before entries stored their writer: the text
	 * before the slash, the same for every Flow.
	 */
	private static final String FLOW_CLASS_NAME_BEFORE_STORED_WRITER = 'Flow';

	/**
	 * @description Base fingerprint for the Flow problem the class-name tests seed as a tagged problem.
	 */
	private static final String BASE_FLOW = 'FlowFault:' + CLASS_METHOD_FLOW;

	/**
	 * @description The class the other-namespace test logs from, as the entry stores it for the writer.
	 */
	private static final String OTHER_NAMESPACE_WRITER = 'OrderService';

	/**
	 * @description A class method recorded in an org with a namespace of its own: the namespace, then the class and method.
	 */
	private static final String CLASS_METHOD_OTHER_NAMESPACE = 'acme' + UTIL_String.DOT + OTHER_NAMESPACE_WRITER + UTIL_String.DOT + 'submit';

	/**
	 * @description The exception type every class-name test row carries, so the rows of one writer fold into one problem.
	 */
	private static final String CLASS_NAME_TEST_EXCEPTION = 'System.FlowException';

	/**
	 * @description A search term of brackets alone: text the body search cannot read once its brackets are escaped.
	 */
	private static final String SEARCH_TERM_BRACKETS_ONLY = '()';

	/**
	 * @description A search term of two double quotes alone: text the body search cannot read once its quotes are escaped.
	 */
	private static final String SEARCH_TERM_QUOTES_ONLY = '""';

	/**
	 * @description The message of the entry that holds the brackets-only term as literal text.
	 */
	private static final String MESSAGE_WITH_BRACKETS = 'Callout returned () from the gateway';

	/**
	 * @description The message of the entry that holds the quotes-only term as literal text.
	 */
	private static final String MESSAGE_WITH_QUOTES = 'Payload arrived as "" from the gateway';

	/**
	 * @description A plain word both punctuation entries hold, so a normal search is shown to find each of them as before.
	 */
	private static final String SEARCH_TERM_PLAIN_WORD = 'gateway';

	/**
	 * @description Window covering seven days, so the back-dated rollup rows fall inside the scope.
	 */
	private static final Integer WINDOW_SEVEN_DAYS = 10080;

	/**
	 * @description The tracking id of an action that launched a chain: the root every entry of the action carries.
	 */
	private static final String ACTION_CORRELATION_ID = 'action-root-4471';

	/**
	 * @description The tracking id of a run the action launched, which its own entries carry beside the action's root.
	 */
	private static final String RUN_CORRELATION_ID = 'run-under-action-4471';

	/**
	 * @description The tracking id of the seeded whole action, in the shape the framework mints (a UUID), so the resolver's
	 * shape check accepts it.
	 */
	private static final String WHOLE_ACTION_ID = UTIL_Random.randomUUID();

	/**
	 * @description The tracking id of a run the whole action launched from its own transaction.
	 */
	private static final String FIRST_RUN_ID = UTIL_Random.randomUUID();

	/**
	 * @description The tracking id of a run a step of the first run launched, so the chip names its launcher.
	 */
	private static final String NESTED_RUN_ID = UTIL_Random.randomUUID();

	/**
	 * @description The tracking id of an action recorded before roots were written: its entries and its one run carry it as
	 * their correlation and no root.
	 */
	private static final String LEGACY_ACTION_ID = UTIL_Random.randomUUID();

	/**
	 * @description A tracking id in the right shape that no entry and no run carries.
	 */
	private static final String UNKNOWN_TRACKING_ID = UTIL_Random.randomUUID();

	/**
	 * @description The chain name of every run seeded under the whole action.
	 */
	private static final String ACTION_CHAIN_NAME = 'CheckoutReserve';

	/**
	 * @description What the controller puts between a run's chain name and its chain number when it labels the run.
	 */
	private static final String CHAIN_LABEL_SEPARATOR = ' · ';

	/**
	 * @description How many runs the large-fixture measurements seed under one action: one thousand, then two thousand.
	 */
	private static final Integer THOUSAND_RUNS = 1000;

	/**
	 * @description The most queries each of the three governed reads may spend on any fixture size: getActionSummary,
	 * the Chain Monitor's getChainExecutions and getLogEntries. Twelve is getActionSummary's plan (the six reads of the
	 * query plan, the launcher and source reads for the chips, and the engine's guard count before each of the two
	 * cursor pages); the other two reads are held to the same number.
	 */
	private static final Integer ACTION_SUMMARY_QUERY_CEILING = 12;

	/**
	 * @description The most CPU time, in milliseconds, each of the three governed reads (getActionSummary, the Chain
	 * Monitor's getChainExecutions and getLogEntries) may spend on the two-thousand-run fixtures.
	 */
	private static final Integer ACTION_SUMMARY_CPU_CEILING_MS = 2000;

	/**
	 * @description How many chain chips the action banner shows, whatever the action's size.
	 */
	private static final Integer ACTION_CHIPS_SHOWN = 5;

	/**
	 * @description The Chain Monitor's start-time sort key, as its request names it.
	 */
	private static final String CHAIN_MONITOR_SORT_STARTED_AT = 'StartedAt';

	/**
	 * @description The page size the scoped Chain Monitor measurement asks for.
	 */
	private static final Integer CHAIN_MONITOR_PAGE_SIZE = 20;

	/**
	 * @description The stride through the nested fixture's runs at which the Chain column measurement picks a run for
	 * each entry, so the fifty entries fall on runs of more than one depth and chain name.
	 */
	private static final Integer CHAIN_COLUMN_RUN_STRIDE = 3;

	/**
	 * @description Seconds in a minute, for the nested fixture's start-time arithmetic: each level starts a minute of
	 * simulated time after the level above it.
	 */
	private static final Integer SECONDS_PER_MINUTE = 60;

	/**
	 * @description What a measurement read before its `stop()` call says: the caller stops it right after the governed
	 * call, before `Test.stopTest()`.
	 */
	private static final String UNSTOPPED_MEASUREMENT = 'The measurement was read before stop() was called; stop it right after the governed call';

	/**
	 * @description Roots of the nested fixture: thirteen roots of 156 runs each make the two-thousand-run action the
	 * volume proof drives on screen.
	 */
	private static final Integer NESTED_ROOTS = 13;

	/**
	 * @description How many levels the nested fixture launches below a root: 5, then 25, then 125, a fan-out of five
	 * at each of three levels.
	 */
	private static final Integer NESTED_DEPTH = 3;

	/**
	 * @description How many children the nested fixture launches under each parent at every level, and how many
	 * siblings share a tied start second.
	 */
	private static final Integer NESTED_FAN_OUT = 5;

	/**
	 * @description Every how many leaves the nested fixture fails one: every eighth of 125 makes 16 failed leaves a root.
	 */
	private static final Integer NESTED_FAILED_LEAF_INTERVAL = 8;

	/**
	 * @description Every how many failed leaves the nested fixture marks RetriesExhausted rather than StepException.
	 */
	private static final Integer NESTED_EXHAUSTED_INTERVAL = 3;

	/**
	 * @description Attempts recorded on a RetriesExhausted leaf's last step.
	 */
	private static final Integer NESTED_EXHAUSTED_ATTEMPTS = 3;

	/**
	 * @description Total and completed steps of a run in the nested fixture: five for a run that finished, one short
	 * for a failed leaf.
	 */
	private static final Integer NESTED_STEP_COUNT = 5;

	/**
	 * @description The durations, in milliseconds, of the nested fixture's five steps.
	 */
	private static final List<Integer> NESTED_STEP_DURATIONS_MS = new List<Integer> {420, 1500, 380, 1500, 260};

	/**
	 * @description How many minutes apart the nested fixture starts each root, so a root's own runs never overlap
	 * another root's.
	 */
	private static final Integer NESTED_ROOT_SPACING_MINUTES = 10;

	/**
	 * @description How many hours before now the nested fixture's earliest root starts.
	 */
	private static final Integer NESTED_BASE_HOURS_AGO = 3;

	/**
	 * @description How many minutes after its source run a restart clone in the nested fixture starts.
	 */
	private static final Integer NESTED_CLONE_OFFSET_MINUTES = 30;

	/**
	 * @description Failed leaves per root in the nested fixture: every eighth of 125.
	 */
	private static final Integer NESTED_FAILED_PER_ROOT = 16;

	/**
	 * @description Restart clones the nested fixture adds, launched under no correlation with a source run.
	 */
	private static final Integer NESTED_RESTART_CLONES = 20;

	/**
	 * @description The Chain column measurement's page.
	 */
	private static final Integer CHAIN_COLUMN_PAGE = 50;

	/**
	 * @description The offset, in minutes from now and negative for the past, at which the Chain column measurement
	 * writes its first entry; each further entry sits a further minute back, so every one of the fifty stays inside the
	 * default window.
	 */
	private static final Integer CHAIN_COLUMN_ENTRY_OFFSET_MINUTES = -1;

	/**
	 * @description The chain names of the nested fixture by depth.
	 */
	private static final List<String> NESTED_CHAIN_NAMES = new List<String> {'Reconciliation', 'RegionReconcile', 'LedgerReconcile', 'AccountReconcile'};

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
			LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
			LogEntry__c.Source__c => 'AlphaService',
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
			LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
			LogEntry__c.Source__c => 'BravoService',
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
	 * non-selective (injected through the test hook that fails only aggregate queries, so the rollup leg's row queries still run),
	 * the rollup problems survive on the page with derivedStatus SKIPPED_NON_SELECTIVE: rollup-only, never
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
	 * does: only forensic rows carrying the linked CorrelationId__c fold into derived problems, so a
	 * correlation-scoped Problems view never lists unrelated derived problems.
	 */
	@IsTest
	private static void shouldScopeDerivedLegToCorrelationDeepLink()
	{
		String filteredCorrelationId = UTIL_Random.randomUUID();
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.CalloutException')
				.withOverride(LogEntry__c.ClassMethod__c, 'ChainStep.execute')
				.withOverride(LogEntry__c.ShortMessage__c, 'Chain step failed')
				.withOverride(LogEntry__c.CorrelationId__c, filteredCorrelationId)
				.withCount(2)
				.buildList();
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		request.correlationId = filteredCorrelationId;

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
	 * Also checks that the two source values differ on a row that carries a line number: methodLine is the display
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
		DML_Builder.newTransaction().withSystemMode().doDelete(purgeable) // NOPMD: test purge of framework-owned rows: a user-mode delete FLS-fails in managed validation
				.execute();

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
	 * scope filter) each return exactly that one signature. This guards the one shared list of search fields:
	 * dropping any field from it fails the search term seeded for that field.
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
	 * @description Tests that a source filter narrows the distinct-problems view as well as the entries
	 * view, because the filter is one the reader can see and clear, and it survives a view switch. For the
	 * rollup, counter rows carry no source at all, so the filter can only be applied against the detail
	 * samples in memory. A signature whose sample was logged from another class is dropped there.
	 */
	@IsTest
	private static void shouldFilterDistinctProblemsBySourceFilter()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {9});
		seedProblem(BASE_OTHER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_OPPORTUNITY, new List<Integer> {4});

		CTRL_LogConsole.DTO_Request filteredRequest = new CTRL_LogConsole.DTO_Request();
		filteredRequest.windowMinutes = WINDOW_SEVEN_DAYS;
		filteredRequest.classMethod = CLASS_METHOD_ACCOUNT;

		CTRL_LogConsole.DTO_Request unfilteredRequest = new CTRL_LogConsole.DTO_Request();
		unfilteredRequest.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage filteredPage = CTRL_LogConsole.getLogProblems(JSON.serialize(filteredRequest));
		CTRL_LogConsole.DTO_LogProblemPage unfilteredPage = CTRL_LogConsole.getLogProblems(JSON.serialize(unfilteredRequest));
		Test.stopTest();

		Assert.areEqual(1, filteredPage.totalCount, 'Expected only the problem logged from the filtered source to fold into the page');
		Assert.areEqual(CLASS_METHOD_ACCOUNT, filteredPage.records[0].classMethod, 'Expected the folded problem to carry the filtered source');
		Assert.areEqual(2, unfilteredPage.totalCount, 'Expected both seeded problems to fold without a source filter, so the filter is what narrowed the page');
	}

	/**
	 * @description Tests that the source filter narrows the DERIVED problems the same way it narrows the
	 * rollup ones: the read-time fold of plain forensic rows applies the source filter in its own query, so
	 * a problems page under an active source pill never lists a derived problem from another source beside
	 * the pill that claims to filter it.
	 */
	@IsTest
	private static void shouldFilterDerivedProblemsBySourceFilter()
	{
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Unhandled shipping error');

		CTRL_LogConsole.DTO_Request filteredRequest = new CTRL_LogConsole.DTO_Request();
		filteredRequest.windowMinutes = WINDOW_SEVEN_DAYS;
		filteredRequest.classMethod = CLASS_METHOD_PRICING;

		CTRL_LogConsole.DTO_Request unfilteredRequest = new CTRL_LogConsole.DTO_Request();
		unfilteredRequest.windowMinutes = WINDOW_SEVEN_DAYS;

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage filteredPage = CTRL_LogConsole.getLogProblems(JSON.serialize(filteredRequest));
		CTRL_LogConsole.DTO_LogProblemPage unfilteredPage = CTRL_LogConsole.getLogProblems(JSON.serialize(unfilteredRequest));
		Test.stopTest();

		Assert.areEqual('COMPLETE', filteredPage.derivedStatus, 'Expected the derived leg to still run under a source filter');
		Assert.areEqual(1, filteredPage.totalCount, 'Expected only the derived problem from the filtered source to fold into the page');
		Assert.areEqual(CLASS_METHOD_PRICING, filteredPage.records[0].classMethod, 'Expected the folded derived problem to carry the filtered source');
		Assert.areEqual(3, filteredPage.records[0].occurrenceCount, 'Expected the filtered fold to count only the rows of the filtered source');
		Assert.areEqual(2, unfilteredPage.totalCount, 'Expected both derived signatures to fold without a source filter, so the filter is what narrowed the page');
	}

	/**
	 * @description Tests that getLogSummary scopes BOTH of its legs to the source filter, so the ribbon over
	 * a filtered problems view counts only that source: the rollup leg drops its out-of-source sample and
	 * the derived fold applies the source filter in its own query.
	 */
	@IsTest
	private static void shouldScopeSummaryToSourceFilterAcrossBothLegs()
	{
		seedProblem(BASE_NULL_POINTER, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_ACCOUNT, new List<Integer> {5});
		seedForensicEntries(3, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_PRICING, 'Unhandled pricing error');
		seedForensicEntries(2, LOG_Engine.LEVEL_ERROR, CLASS_METHOD_SHIPPING, 'Unhandled shipping error');

		CTRL_LogConsole.DTO_Request filteredRequest = new CTRL_LogConsole.DTO_Request();
		filteredRequest.windowMinutes = WINDOW_SEVEN_DAYS;
		filteredRequest.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};
		filteredRequest.classMethod = CLASS_METHOD_PRICING;

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(filteredRequest));
		Test.stopTest();

		Assert.areEqual(3, summary.totalOccurrences, 'Expected the ribbon to count only the filtered source: the derived rows, not the out-of-source rollup');
		Assert.areEqual(1, summary.distinctCount, 'Expected only the filtered source\'s derived problem to count as distinct');
		CTRL_LogConsole.DTO_LevelSummary errorLevel = levelSummaryFor(summary, LOG_Engine.LEVEL_ERROR);
		Assert.isNotNull(errorLevel, 'Expected an ERROR level summary for the filtered source');
		Assert.areEqual(3, errorLevel.occurrences, 'Expected the ERROR occurrences to cover only the filtered source');
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
	 * ascending. This checks the direction of the tie-break through real behaviour: a flipped tie-break would fail here.
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
	 * @description Tests that a forensic row with no writer name (no class-method at all, so no stored source)
	 * still counts in the ribbon total and per-level breakdown but produces no blank source bucket: the tally
	 * skips a nameless row instead of ranking it as a bucket the drill could not filter on.
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
		// guard that ran AFTER the scans (the order this test exists to check) throws here and fails the test
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
	 * @description Under the action scope the entries page lists the action's own entry and its runs' entries; each row says
	 * which chain it came from (name and number) or that the action wrote it itself, and carries the root.
	 */
	@IsTest
	private static void shouldListTheWholeActionAndNameEachRowsChain()
	{
		AsyncChainExecution__c firstRun = seedActionRun(FIRST_RUN_ID, WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED, -9);
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -10);
		seedActionEntry(FIRST_RUN_ID, WHOLE_ACTION_ID, 'a step of the run', -8);
		seedActionEntry(UTIL_Random.randomUUID(), UTIL_Random.randomUUID(), 'another action', -1);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_ONE_DAY;
		request.rootCorrelationId = WHOLE_ACTION_ID;
		request.sortField = 'createdDate';
		request.sortAscending = true;

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, page.totalCount, 'The scope holds the action\'s own entry and its run\'s entry');
		CTRL_LogConsole.DTO_LogEntrySummary ownRow = page.records[0];
		CTRL_LogConsole.DTO_LogEntrySummary runRow = page.records[1];
		Assert.isTrue(ownRow.isActionOwn, 'The entry the action wrote itself is marked as the action\'s own');
		Assert.isNull(ownRow.chainName, 'The action\'s own entry names no chain');
		Assert.areEqual(WHOLE_ACTION_ID, ownRow.rootCorrelationId, 'Every row carries the root');
		Assert.isFalse(runRow.isActionOwn, 'A run\'s entry is not the action\'s own');
		Assert.areEqual(ACTION_CHAIN_NAME, runRow.chainName, 'A run\'s entry names its chain');
		Assert.areEqual(firstRun.Name, runRow.chainNumber, 'A run\'s entry carries the chain number');
		Assert.areEqual(firstRun.Id, runRow.chainExecutionId, 'A run\'s entry carries the run record id');
	}

	/**
	 * @description Naming the chains of a page costs one query on the run records, and the same one query when none of the
	 * page's correlations is a run's; a page with no correlation ids costs nothing extra. The three reads are filtered by
	 * source alone, so they share every other cost and differ only in the chain-naming read.
	 */
	@IsTest
	private static void shouldNameAPagesChainsInOneQuery()
	{
		seedActionRun(FIRST_RUN_ID, WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED, -9);
		String runsSource = 'RunsHold.page';
		String noRunsSource = 'NoRunHolds.page';
		String noCorrelationSource = 'NoCorrelation.page';
		for(Integer index = 0; index < 20; index++)
		{
			seedActionEntryFrom(runsSource, FIRST_RUN_ID, WHOLE_ACTION_ID, 'a step ' + index, -8);
			seedActionEntryFrom(noRunsSource, UTIL_Random.randomUUID(), UTIL_Random.randomUUID(), 'no run holds this ' + index, -8);
		}
		seedForensicEntries(20, LOG_Engine.LEVEL_INFO, noCorrelationSource, 'no correlation at all');

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_ONE_DAY;

		Test.startTest();
		request.classMethod = noCorrelationSource;
		Integer before = UTIL_Limits.soqlQueries().used();
		CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Integer noCorrelationCost = UTIL_Limits.soqlQueries().used() - before;
		request.classMethod = noRunsSource;
		before = UTIL_Limits.soqlQueries().used();
		CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Integer noRunsCost = UTIL_Limits.soqlQueries().used() - before;
		request.classMethod = runsSource;
		before = UTIL_Limits.soqlQueries().used();
		CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		Integer runsCost = UTIL_Limits.soqlQueries().used() - before;
		Test.stopTest();

		Assert.areEqual(noCorrelationCost + 1, noRunsCost, 'A page whose correlations are no run\'s costs the page read plus one query');
		Assert.areEqual(noCorrelationCost + 1, runsCost, 'A page of runs\' entries costs the page read plus the same one query');
	}

	/**
	 * @description The banner is built from the six reads in order: the first and last entry (outside the list's window),
	 * the failed page whose total is the failed count, the all-chains page whose total is the chain count and whose rows
	 * fill the chips after the failed ones, the unfinished-run existence, and the launchers of the chips. Seven runs, three
	 * failed: three failed chips first, then the two earliest of the rest, and "two more".
	 */
	@IsTest
	private static void shouldSummariseAnActionFromTheSixReads()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -30);
		List<Id> failedRuns = new List<Id>();
		List<Id> otherRuns = new List<Id>();
		for(Integer index = 0; index < 7; index++)
		{
			Boolean failed = index < 3;
			String status = failed ? SEL_AsyncChainExecution.STATUS_FAILED : SEL_AsyncChainExecution.STATUS_COMPLETED;
			Id runId = seedActionRun(UTIL_Random.randomUUID(), WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, status, -20 + index).Id;
			(failed ? failedRuns : otherRuns).add(runId);
		}
		LogEntry__c lastEntry = seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the last word', -5);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;
		request.windowMinutes = 1;

		Test.startTest();
		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(7, summary.chainCount, 'The chain count is the all-chains page\'s exact total');
		Assert.areEqual(3, summary.failedCount, 'The failed count is the failed page\'s exact total');
		Assert.isFalse(summary.stillRunning, 'No run is unfinished');
		Assert.isFalse(summary.recordedBeforeRoots, 'The action carries roots');
		Assert.areEqual(5, summary.chains.size(), 'At most five chips');
		Assert.areEqual(2, summary.moreChainCount, 'The rest is a number');
		for(Integer index = 0; index < 3; index++)
		{
			Assert.areEqual(failedRuns[index], summary.chains[index].executionId, 'Chip ' + index + ' is a failed run, by start time');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, summary.chains[index].status, 'A failed chip carries its status');
		}
		Assert.areEqual(otherRuns[0], summary.chains[3].executionId, 'The fill skips the failed runs already shown and takes the earliest of the rest');
		Assert.areEqual(otherRuns[1], summary.chains[4].executionId, 'The fill continues by start time');
		Assert.isTrue(summary.startedAt < Datetime.now().addMinutes(-29), 'The start is the first entry, outside the one-minute window');
		Assert.areEqual(lastEntry.CreatedDate, summary.endedAt, 'The end is the last entry');
		Assert.isTrue(String.isNotBlank(summary.durationLabel), 'The duration is formatted for the sentence');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.ACTION.name(), summary.chains[0].launchKind, 'A run launched from the action\'s own transaction is the action\'s launch');
	}

	/**
	 * @description A stalled run is not a failure: the failed count leaves it out, but it keeps the action still running,
	 * so the end is open.
	 */
	@IsTest
	private static void shouldExcludeStalledRunsFromTheFailedCountAndKeepTheActionRunning()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -30);
		seedActionRun(UTIL_Random.randomUUID(), WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_FAILED, -20);
		seedActionRun(UTIL_Random.randomUUID(), WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_STALLED, -19);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;

		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));

		Assert.areEqual(1, summary.failedCount, 'Stalled is not counted as failed');
		Assert.areEqual(2, summary.chainCount, 'Both runs count as chains');
		Assert.isTrue(summary.stillRunning, 'A stalled run keeps the action unfinished');
		Assert.isNull(summary.endedAt, 'An unfinished action has no end');
	}

	/**
	 * @description Five failed runs fill every chip; a sixth run still going is not among them, and the banner still says
	 * the action is running, because that answer comes from the existence read and not from the chips.
	 */
	@IsTest
	private static void shouldSayStillRunningWhenNoRunningChipIsAmongTheFive()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -30);
		for(Integer index = 0; index < 5; index++)
		{
			seedActionRun(UTIL_Random.randomUUID(), WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_FAILED, -20 + index);
		}
		seedActionRun(UTIL_Random.randomUUID(), WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_RUNNING, -2);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;

		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));

		Assert.areEqual(5, summary.chains.size(), 'Five failed chips fill the slots');
		for(CTRL_LogConsole.DTO_ActionChain chip : summary.chains)
		{
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, chip.status, 'Every chip is a failed run');
		}
		Assert.isTrue(summary.stillRunning, 'The running run is found by the existence read, not by the chips');
		Assert.areEqual(1, summary.moreChainCount, 'The sixth run is the "more" count');
	}

	/**
	 * @description An action that launched no chains says so with exact zeros, is not legacy, and has ended.
	 */
	@IsTest
	private static void shouldSummariseAnActionWithNoChains()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -3);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;

		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));

		Assert.areEqual(0, summary.chainCount, 'No chains ran under it');
		Assert.areEqual(0, summary.failedCount, 'Nothing failed');
		Assert.isTrue(summary.chains.isEmpty(), 'No chips');
		Assert.areEqual(0, summary.moreChainCount, 'Nothing more');
		Assert.isFalse(summary.recordedBeforeRoots, 'The action carries roots');
		Assert.isFalse(summary.stillRunning, 'Nothing is unfinished');
	}

	/**
	 * @description A legacy action (entries with no root) is described by the legacy flag and by the one run that adopted its
	 * id, never as an action that launched no chains.
	 */
	@IsTest
	private static void shouldDescribeALegacyActionByTheRunThatAdoptedItsId()
	{
		seedActionEntry(LEGACY_ACTION_ID, null, 'recorded before roots', -30);
		AsyncChainExecution__c adopter = seedActionRun(LEGACY_ACTION_ID, null, null, null, SEL_AsyncChainExecution.STATUS_FAILED, -20);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = LEGACY_ACTION_ID;

		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));

		Assert.isTrue(summary.recordedBeforeRoots, 'Entries with no root mark the action as recorded before roots');
		Assert.areEqual(1, summary.chains.size(), 'The run that adopted the id is the one chip');
		Assert.areEqual(adopter.Id, summary.chains[0].executionId, 'The chip is the adopting run');
		Assert.areEqual(adopter.Name, summary.chains[0].chainNumber, 'The chip carries the chain number');
		Assert.areEqual(1, summary.chainCount, 'The adopting run counts as the action\'s one chain');
		Assert.areEqual(1, summary.failedCount, 'A failed adopting run counts as failed');
	}

	/**
	 * @description An action nobody logged, or a blank request, summarises to nothing.
	 */
	@IsTest
	private static void shouldReturnNoSummaryForAnUnknownOrBlankAction()
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = UNKNOWN_TRACKING_ID;

		Assert.isNull(CTRL_LogConsole.getActionSummary(JSON.serialize(request)), 'An action with no entries has no summary');
		Assert.isNull(CTRL_LogConsole.getActionSummary(null), 'A blank request has no summary');
	}

	/**
	 * @description Each chip says how its run entered the action, by the four launched-under cases: launched by a named
	 * chain (a step launched it), the action's own launch, a restart of a named run, or the run that started the action.
	 */
	@IsTest
	private static void shouldNameHowEachChipEnteredTheAction()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -30);
		AsyncChainExecution__c firstRun = seedActionRun(FIRST_RUN_ID, WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED, -20);
		seedActionRun(NESTED_RUN_ID, WHOLE_ACTION_ID, FIRST_RUN_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED, -19);
		seedActionRun(UTIL_Random.randomUUID(), WHOLE_ACTION_ID, null, firstRun.Id, SEL_AsyncChainExecution.STATUS_COMPLETED, -18);
		seedActionRun(UTIL_Random.randomUUID(), WHOLE_ACTION_ID, null, null, SEL_AsyncChainExecution.STATUS_COMPLETED, -17);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;

		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));

		String firstRunLabel = ACTION_CHAIN_NAME + CHAIN_LABEL_SEPARATOR + firstRun.Name;
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.ACTION.name(), summary.chains[0].launchKind, 'The first run was launched by the action itself');
		Assert.isNull(summary.chains[0].launcherName, 'The action\'s own launch names no launcher');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.CHAIN.name(), summary.chains[1].launchKind, 'The nested run was launched by a step of the first run');
		Assert.areEqual(firstRunLabel, summary.chains[1].launcherName, 'The launcher is named by chain name and number');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.RESTART.name(), summary.chains[2].launchKind, 'The clone is a restart');
		Assert.areEqual(firstRunLabel, summary.chains[2].launcherName, 'The restart names its source run');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.ORIGIN.name(), summary.chains[3].launchKind, 'A run with no launch id and no source started its own action');
	}

	/**
	 * @description The search resolver never treats a chain run's id as an action: an action's root is the action, a rootless
	 * correlation is a legacy action, a run's correlation is the chain (named), and an unknown id or plain text resolves to
	 * nothing so the free-text search runs.
	 */
	@IsTest
	private static void shouldResolveWhatATrackingIdNamesBeforeSearching()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -30);
		seedActionEntry(FIRST_RUN_ID, WHOLE_ACTION_ID, 'a step of the run', -20);
		AsyncChainExecution__c firstRun = seedActionRun(FIRST_RUN_ID, WHOLE_ACTION_ID, WHOLE_ACTION_ID, null, SEL_AsyncChainExecution.STATUS_FAILED, -20);
		seedActionEntry(LEGACY_ACTION_ID, null, 'recorded before roots', -10);

		Test.startTest();
		CTRL_LogConsole.DTO_ResolvedSearchId action = CTRL_LogConsole.resolveSearchId(WHOLE_ACTION_ID);
		CTRL_LogConsole.DTO_ResolvedSearchId chain = CTRL_LogConsole.resolveSearchId(FIRST_RUN_ID);
		CTRL_LogConsole.DTO_ResolvedSearchId legacy = CTRL_LogConsole.resolveSearchId(LEGACY_ACTION_ID);
		CTRL_LogConsole.DTO_ResolvedSearchId unknown = CTRL_LogConsole.resolveSearchId(UNKNOWN_TRACKING_ID);
		CTRL_LogConsole.DTO_ResolvedSearchId text = CTRL_LogConsole.resolveSearchId('timeout');
		Test.stopTest();

		Assert.areEqual(CTRL_LogConsole.SearchIdKind.ACTION.name(), action.kind, 'A root is an action');
		Assert.areEqual(WHOLE_ACTION_ID, action.id, 'The action carries its id');
		Assert.areEqual(CTRL_LogConsole.SearchIdKind.CHAIN.name(), chain.kind, 'A run\'s correlation is the chain, never an action');
		Assert.areEqual(ACTION_CHAIN_NAME, chain.chainName, 'The chain is named for the pill');
		Assert.areEqual(firstRun.Name, chain.chainNumber, 'The chain carries its number for the pill');
		Assert.areEqual(CTRL_LogConsole.SearchIdKind.LEGACY_ACTION.name(), legacy.kind, 'A rootless correlation is a legacy action');
		Assert.areEqual(CTRL_LogConsole.SearchIdKind.NONE.name(), unknown.kind, 'An id nothing carries searches as text');
		Assert.areEqual(CTRL_LogConsole.SearchIdKind.NONE.name(), text.kind, 'Plain text is not resolved');
	}

	/**
	 * @description An entry with no root and a correlation no run holds is its own action: the drawer's action id is its
	 * correlation and it is the action's own entry.
	 */
	@IsTest
	private static void shouldTreatARootlessEntryNoRunHoldsAsItsOwnAction()
	{
		LogEntry__c entry = seedActionEntry(LEGACY_ACTION_ID, null, 'recorded before roots', -10);

		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(entry.Id);

		Assert.areEqual(LEGACY_ACTION_ID, detail.actionCorrelationId, 'With no root the correlation is the action');
		Assert.isTrue(detail.isActionOwn, 'No run holds the id, so the action wrote the entry itself');
		Assert.isFalse(detail.chainExists, 'No chain to open');
		Assert.isNull(detail.chainName, 'No chain to name');
	}

	/**
	 * @description A legacy entry whose id the first chain adopted offers both links: its correlation is its action, and a run
	 * holds the id, so it is not the action's own and the Correlation row names that chain.
	 */
	@IsTest
	private static void shouldOfferBothLinksOnALegacyEntryWhoseIdAChainAdopted()
	{
		LogEntry__c entry = seedActionEntry(LEGACY_ACTION_ID, null, 'recorded before roots', -10);
		AsyncChainExecution__c adopter = seedActionRun(LEGACY_ACTION_ID, null, null, null, SEL_AsyncChainExecution.STATUS_COMPLETED, -9);

		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(entry.Id);

		Assert.areEqual(LEGACY_ACTION_ID, detail.actionCorrelationId, 'The correlation is the action');
		Assert.isFalse(detail.isActionOwn, 'A run holds the id, so this is the run\'s entry');
		Assert.isTrue(detail.chainExists, 'The adopting run can be opened');
		Assert.areEqual(ACTION_CHAIN_NAME, detail.chainName, 'The Correlation row names the chain');
		Assert.areEqual(adopter.Name, detail.chainNumber, 'The Correlation row carries the chain number');
	}

	/**
	 * @description The ribbon, the entries count and the problems fold all read the action scope: a tagged problem whose
	 * sample belongs to another action is folded out, and the entries total counts the action's rows alone.
	 */
	@IsTest
	private static void shouldScopeTheRibbonAndTheProblemsFoldToTheAction()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the click itself', -30);
		seedActionEntry(FIRST_RUN_ID, WHOLE_ACTION_ID, 'a step of the run', -20);
		seedActionEntry(UTIL_Random.randomUUID(), UTIL_Random.randomUUID(), 'another action', -10);
		seedDistinctProblem(BASE_NULL_POINTER, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.CorrelationId__c => WHOLE_ACTION_ID,
				LogEntry__c.RootCorrelationId__c => WHOLE_ACTION_ID
		}, 4);
		seedDistinctProblem(BASE_OTHER, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_OPPORTUNITY,
				LogEntry__c.CorrelationId__c => UTIL_Random.randomUUID(),
				LogEntry__c.RootCorrelationId__c => UTIL_Random.randomUUID()
		}, 4);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_ONE_DAY;
		request.rootCorrelationId = WHOLE_ACTION_ID;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN, LOG_Engine.LEVEL_INFO};

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary entries = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		CTRL_LogConsole.DTO_LogProblemPage problems = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(3, entries.totalRows, 'The entries ribbon counts the action\'s three rows (two forensic, one tagged sample)');
		Assert.areEqual(1, problems.totalCount, 'The problems fold keeps the tagged problem inside the action and drops the other');
		Assert.areEqual(CLASS_METHOD_ACCOUNT.substringBefore('.'), problems.records[0].className, 'The kept problem is the action\'s');
	}

	/**
	 * @description On a thousand runs the banner spends the same handful of queries as on seven: the counts come from
	 * cursor totals, not from reading the runs. The CPU ceiling is asserted by the two-thousand-run test.
	 */
	@IsTest
	private static void shouldSummariseAThousandRunsWithinTheQueryCeiling()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the nightly job started', -60);
		seedActionRuns(THOUSAND_RUNS, WHOLE_ACTION_ID);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;

		Test.startTest();
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));
		Integer queriesSpent = UTIL_Limits.soqlQueries().used() - queriesBefore;
		Test.stopTest();

		Assert.areEqual(THOUSAND_RUNS, summary.chainCount, 'The chain count is exact at a thousand runs');
		Assert.areEqual(ACTION_CHIPS_SHOWN, summary.chains.size(), 'Five chips whatever the size');
		Assert.areEqual(THOUSAND_RUNS - ACTION_CHIPS_SHOWN, summary.moreChainCount, 'The rest is a number');
		Assert.isTrue(queriesSpent <= ACTION_SUMMARY_QUERY_CEILING, 'The banner spends at most ' + ACTION_SUMMARY_QUERY_CEILING + ' queries, spent ' + queriesSpent);
	}

	/**
	 * @description Two thousand runs cost the same queries as a thousand and stay under the CPU ceiling.
	 */
	@IsTest
	private static void shouldSummariseTwoThousandRunsWithinTheCeilings()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the nightly job started', -60);
		seedActionRuns(THOUSAND_RUNS * 2, WHOLE_ACTION_ID);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;

		Test.startTest();
		ResourceMeasurement measurement = new ResourceMeasurement();
		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));
		measurement.stop();
		Test.stopTest();

		Assert.areEqual(THOUSAND_RUNS * 2, summary.chainCount, 'The chain count is exact at two thousand runs');
		assertWithinTheCeilings(measurement, 'The banner');
	}

	/**
	 * @description The two-thousand-run banner measurement on runs the way the engine writes them: nested three deep,
	 * five steps each with durations, a mix of statuses, restart clones and tied start times. Same ceilings.
	 */
	@IsTest
	private static void shouldSummariseTwoThousandNestedRunsWithinTheCeilings()
	{
		seedActionEntry(WHOLE_ACTION_ID, WHOLE_ACTION_ID, 'the reconciliation started', -60);
		List<AsyncChainExecution__c> runs = seedNestedActionRuns(NESTED_ROOTS, WHOLE_ACTION_ID);

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;

		Test.startTest();
		ResourceMeasurement measurement = new ResourceMeasurement();
		CTRL_LogConsole.DTO_ActionSummary summary = CTRL_LogConsole.getActionSummary(JSON.serialize(request));
		measurement.stop();
		Test.stopTest();

		Assert.areEqual(runs.size(), summary.chainCount, 'The chain count is exact over the nested runs');
		Assert.areEqual(NESTED_ROOTS * NESTED_FAILED_PER_ROOT + NESTED_RESTART_CLONES, summary.failedCount, 'The failed count is exact, restart clones included');
		Assert.areEqual(ACTION_CHIPS_SHOWN, summary.chains.size(), 'Five chips whatever the shape');
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, summary.chains[0].status, 'Failed chips come first');
		assertWithinTheCeilings(measurement, 'The banner');
	}

	/**
	 * @description The Chain Monitor's first page scoped to the nested action, sorted by start time with ties, under
	 * the same ceilings; the launchers of the page's rows are off the page, so Launched under takes its two reads.
	 */
	@IsTest
	private static void shouldListTheScopedPageOfTwoThousandNestedRunsWithinTheCeilings()
	{
		List<AsyncChainExecution__c> runs = seedNestedActionRuns(NESTED_ROOTS, WHOLE_ACTION_ID);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;
		request.sortField = CHAIN_MONITOR_SORT_STARTED_AT;
		request.sortAscending = false;
		request.pageSize = CHAIN_MONITOR_PAGE_SIZE;
		request.pageNumber = 1;

		Test.startTest();
		ResourceMeasurement measurement = new ResourceMeasurement();
		CTRL_ChainMonitorTypes.DTO_ChainPage page = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));
		measurement.stop();
		Test.stopTest();

		Assert.areEqual(runs.size(), page.totalCount, 'The scoped total counts every run of the action');
		Assert.areEqual(CHAIN_MONITOR_PAGE_SIZE, page.records.size(), 'A full first page');
		for(CTRL_ChainMonitorTypes.DTO_ChainSummary row : page.records)
		{
			Assert.isNotNull(row.launchedUnderLabel, 'Every row on the scoped page names what launched it: ' + row.chainName);
		}
		assertWithinTheCeilings(measurement, 'The scoped page');
	}

	/**
	 * @description A fifty-row page of entries drawn from fifty different runs of the nested action resolves the Chain
	 * column for every row under the same ceilings.
	 */
	@IsTest
	private static void shouldResolveTheChainColumnOverAPageDrawnFromManyRunsWithinTheCeilings()
	{
		List<AsyncChainExecution__c> runs = seedNestedActionRuns(NESTED_ROOTS, WHOLE_ACTION_ID);
		for(Integer index = 0; index < CHAIN_COLUMN_PAGE; index++)
		{
			seedActionEntry(runs[index * CHAIN_COLUMN_RUN_STRIDE].CorrelationId__c, WHOLE_ACTION_ID, 'step ' + index + ' ran', CHAIN_COLUMN_ENTRY_OFFSET_MINUTES - index);
		}

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.rootCorrelationId = WHOLE_ACTION_ID;
		request.levels = new List<String> {LOG_Engine.LEVEL_INFO};
		request.pageSize = CHAIN_COLUMN_PAGE;
		request.pageNumber = 1;

		Test.startTest();
		ResourceMeasurement measurement = new ResourceMeasurement();
		CTRL_LogConsole.DTO_LogEntryPage page = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		measurement.stop();
		Test.stopTest();

		Assert.areEqual(CHAIN_COLUMN_PAGE, page.records.size(), 'A full page of fifty');
		Set<String> chainNames = new Set<String>();
		for(CTRL_LogConsole.DTO_LogEntrySummary row : page.records)
		{
			Assert.isTrue(String.isNotBlank(row.chainName), 'Every entry names its run\'s chain: ' + row.correlationId);
			chainNames.add(row.chainName);
		}
		Assert.isTrue(chainNames.size() > 1, 'The page draws on runs of more than one chain name');
		assertWithinTheCeilings(measurement, 'The entries page');
	}

	/**
	 * @description Captures the queries and CPU time spent by one governed call. The caller stops the measurement
	 * immediately after the call, and always before `Test.stopTest()`: stopping later would fold in whatever
	 * `Test.stopTest()` itself flushes (queued asynchronous work runs synchronously there, against this same test
	 * method's limits), crediting the call with cost it never spent.
	 */
	private class ResourceMeasurement
	{
		/**
		 * @description Queries already spent when this measurement started.
		 */
		private final Integer queriesAtStart;

		/**
		 * @description CPU time, in milliseconds, already spent when this measurement started.
		 */
		private final Integer cpuAtStart;

		/**
		 * @description Queries spent between the start and the `stop()` call, null until stopped.
		 */
		private Integer queriesSpentAtStop;

		/**
		 * @description CPU time, in milliseconds, spent between the start and the `stop()` call, null until stopped.
		 */
		private Integer cpuSpentAtStop;

		/**
		 * @description Starts a measurement from the governor limits as they stand right now.
		 */
		private ResourceMeasurement()
		{
			queriesAtStart = UTIL_Limits.soqlQueries().used();
			cpuAtStart = UTIL_Limits.cpuTime().used();
		}

		/**
		 * @description Freezes the queries and CPU time spent since this measurement started. The caller stops the
		 * measurement right after the governed call, before `Test.stopTest()`.
		 */
		private void stop()
		{
			queriesSpentAtStop = UTIL_Limits.soqlQueries().used() - queriesAtStart;
			cpuSpentAtStop = UTIL_Limits.cpuTime().used() - cpuAtStart;
		}

		/**
		 * @description How many queries were spent between this measurement's start and its `stop()` call; fails the
		 * test with a message saying so when `stop()` was never called.
		 *
		 * @return The queries spent.
		 */
		private Integer queriesSpent()
		{
			assertStopped();
			return queriesSpentAtStop;
		}

		/**
		 * @description How much CPU time, in milliseconds, was spent between this measurement's start and its `stop()`
		 * call; fails the test with a message saying so when `stop()` was never called.
		 *
		 * @return The CPU time spent.
		 */
		private Integer cpuSpent()
		{
			assertStopped();
			return cpuSpentAtStop;
		}

		/**
		 * @description Fails the test, naming the cause, when the measurement is read before `stop()` froze it.
		 */
		private void assertStopped()
		{
			Assert.isNotNull(queriesSpentAtStop, UNSTOPPED_MEASUREMENT);
		}
	}

	/**
	 * @description Asserts that a measurement's queries and CPU time both fall within the class's shared large-fixture
	 * ceilings.
	 *
	 * @param measurement The measurement to check.
	 * @param subject What the measurement is of, named in the assertion messages.
	 */
	private static void assertWithinTheCeilings(ResourceMeasurement measurement, String subject)
	{
		Integer queriesSpent = measurement.queriesSpent();
		Integer cpuSpent = measurement.cpuSpent();
		Assert.isTrue(queriesSpent <= ACTION_SUMMARY_QUERY_CEILING, subject + ' spends at most ' + ACTION_SUMMARY_QUERY_CEILING + ' queries, spent ' + queriesSpent);
		Assert.isTrue(cpuSpent <= ACTION_SUMMARY_CPU_CEILING_MS, subject + ' spends at most ' + ACTION_SUMMARY_CPU_CEILING_MS + ' ms of CPU, spent ' + cpuSpent);
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
	 * correlation (the trace always holds at least the opened entry), and returns an empty list for both a null Id and
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

		Assert.areEqual(1, selfOnly.size(), 'Expected a row with no correlation to give a trace that holds only itself');
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
	 * @description Tests that searching an action's root correlation id returns the action's own entry and the entries
	 * of the runs it launched, while searching a run's id returns that run alone.
	 */
	@IsTest
	private static void shouldFindEveryEntryOfAnActionBySearchingItsRootCorrelation()
	{
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.LineNumber__c => 17,
				LogEntry__c.ShortMessage__c => 'the action itself failed',
				LogEntry__c.CorrelationId__c => ACTION_CORRELATION_ID,
				LogEntry__c.RootCorrelationId__c => ACTION_CORRELATION_ID
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_NULL_POINTER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_OPPORTUNITY,
				LogEntry__c.LineNumber__c => 42,
				LogEntry__c.ShortMessage__c => 'a step of the launched run failed',
				LogEntry__c.CorrelationId__c => RUN_CORRELATION_ID,
				LogEntry__c.RootCorrelationId__c => ACTION_CORRELATION_ID
		});

		CTRL_LogConsole.DTO_Request byRoot = new CTRL_LogConsole.DTO_Request();
		byRoot.windowMinutes = WINDOW_SEVEN_DAYS;
		byRoot.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		byRoot.searchTerm = ACTION_CORRELATION_ID;
		CTRL_LogConsole.DTO_Request byRun = new CTRL_LogConsole.DTO_Request();
		byRun.windowMinutes = WINDOW_SEVEN_DAYS;
		byRun.levels = new List<String> {LOG_Engine.LEVEL_ERROR};
		byRun.searchTerm = RUN_CORRELATION_ID;

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage actionPage = CTRL_LogConsole.getLogEntries(JSON.serialize(byRoot));
		CTRL_LogConsole.DTO_LogEntryPage runPage = CTRL_LogConsole.getLogEntries(JSON.serialize(byRun));
		Test.stopTest();

		Set<String> actionCorrelations = new Set<String>();
		for(CTRL_LogConsole.DTO_LogEntrySummary entry : actionPage.records)
		{
			actionCorrelations.add(entry.correlationId);
		}
		Assert.areEqual(new Set<String> {ACTION_CORRELATION_ID, RUN_CORRELATION_ID}, actionCorrelations, 'The root search returns the action\'s own entry and its run\'s entry');
		Assert.areEqual(1, runPage.records.size(), 'The run search returns the run alone');
		Assert.areEqual(RUN_CORRELATION_ID, runPage.records[0].correlationId, 'The run search returns the run\'s entry');
	}

	/**
	 * @description Tests that the entry detail carries the root correlation id beside the correlation id, so the drawer
	 * can name the action an entry belongs to.
	 */
	@IsTest
	private static void shouldCarryTheRootOnTheEntryDetail()
	{
		LogEntry__c row = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.Fingerprint__c => TRG_PersistLogEntry.PREFIX_DETAIL + BASE_OTHER,
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.LineNumber__c => 17,
				LogEntry__c.ShortMessage__c => 'a step entry',
				LogEntry__c.CorrelationId__c => RUN_CORRELATION_ID,
				LogEntry__c.RootCorrelationId__c => ACTION_CORRELATION_ID
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(row.Id);
		Test.stopTest();

		Assert.areEqual(RUN_CORRELATION_ID, detail.correlationId, 'The detail carries the run\'s id');
		Assert.areEqual(ACTION_CORRELATION_ID, detail.rootCorrelationId, 'The detail carries the action\'s root');
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
	 * writer name, duration, short message, execution context and correlation id, so an ascending sort by any of
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
				.withOverride(LogEntry__c.Origin__c, LOG_Engine.Origin.APEX.name())
				.withOverride(LogEntry__c.Source__c, 'AlphaService')
				.withOverride(LogEntry__c.DurationMs__c, 10)
				.withOverride(LogEntry__c.ShortMessage__c, 'aaa earliest failure')
				.withOverride(LogEntry__c.ExecutionEvent__c, Quiddity.BATCH_APEX.name())
				.withOverride(LogEntry__c.CorrelationId__c, 'corr-aaa')
				.build();
		LogEntry__c zuluRow = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.Fingerprint__c, TRG_PersistLogEntry.PREFIX_DETAIL + 'NullPointer:ZuluService.run')
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ClassMethod__c, 'ZuluService.run')
				.withOverride(LogEntry__c.Origin__c, LOG_Engine.Origin.APEX.name())
				.withOverride(LogEntry__c.Source__c, 'ZuluService')
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
				'writerName' => alphaRow.Id,
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
	 * writer name, short message, execution context and log number each put the expected problem first,
	 * and the last-seen sort returns the full set.
	 */
	@IsTest
	private static void shouldSortProblemsByEachSortField()
	{
		seedDistinctProblem('NullPointer:AaaHandler.run', new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'AaaHandler.run',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'AaaHandler',
				LogEntry__c.ShortMessage__c => 'Aaa earliest failure',
				LogEntry__c.ExecutionEvent__c => Quiddity.BATCH_APEX.name()
		}, 40);
		seedDistinctProblem('NullPointer:ZzzService.run', new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_WARN,
				LogEntry__c.ClassMethod__c => 'ZzzService.run',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'ZzzService',
				LogEntry__c.ShortMessage__c => 'Zzz latest failure',
				LogEntry__c.ExecutionEvent__c => Quiddity.QUEUEABLE.name()
		}, 5);

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblem topByLevel = firstProblemSortedAscendingBy('level');
		CTRL_LogConsole.DTO_LogProblem topByWriterName = firstProblemSortedAscendingBy('writerName');
		CTRL_LogConsole.DTO_LogProblem topByShortMessage = firstProblemSortedAscendingBy('shortMessage');
		CTRL_LogConsole.DTO_LogProblem topByExecutionEvent = firstProblemSortedAscendingBy('executionEvent');
		CTRL_LogConsole.DTO_LogProblem topByLogNumber = firstProblemSortedAscendingBy('logNumber');
		CTRL_LogConsole.DTO_LogProblemPage byLastSeen = problemsSortedAscendingBy('lastSeen');
		Test.stopTest();

		Assert.areEqual(LOG_Engine.LEVEL_WARN, topByLevel.level, 'Ascending level sort orders by severity, putting WARN before ERROR');
		Assert.areEqual('AaaHandler', topByWriterName.writerName, 'Ascending writer-name sort puts AaaHandler first');
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
	 * @description The entries ribbon ranks writers by their stored source, carries each one's origin, and leaves
	 * rows written before attribution out of the card while counting them in the total, whether the row is missing
	 * its name, its origin, or both.
	 */
	@IsTest
	private static void shouldRankEntrySourcesByStoredSourceWithOrigin()
	{
		for(Integer i = 0; i < 3; i++)
		{
			TST_Factory.seedLogEntry(new Map<SObjectField, Object>
			{
					LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
					LogEntry__c.ClassMethod__c => 'kern.UTIL_AsyncChain.ChainExecutor.execute',
					LogEntry__c.Origin__c => LOG_Engine.Origin.FRAMEWORK.name(),
					LogEntry__c.Source__c => 'UTIL_AsyncChain'
			});
		}
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'AccountTriggerHandler'
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'Legacy.row'
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name()
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'Backfilled.row',
				LogEntry__c.Source__c => 'Backfilled'
		});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(7, summary.totalRows, 'The unattributed rows and the nameless row still count');
		Assert.areEqual(2, summary.topSources.size(), 'Only named, attributed writers are ranked: no missing name and no missing origin');
		Assert.areEqual('UTIL_AsyncChain', summary.topSources[0].name, 'The card names the writer, never the namespace');
		Assert.areEqual(LOG_Engine.Origin.FRAMEWORK.name(), summary.topSources[0].origin, 'The card carries the origin');
		Assert.areEqual(3, summary.topSources[0].count, 'Three rows');
	}

	/**
	 * @description The request's origins and source reach the entries read as the exact criteria, so the list a
	 * drilled card opens holds exactly the rows the card counted.
	 */
	@IsTest
	private static void shouldListExactlyTheRowsOfAFilteredWriter()
	{
		LogEntry__c filteredWriterEntry = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'Flow/Order Intake',
				LogEntry__c.Origin__c => LOG_Engine.Origin.FLOW.name(),
				LogEntry__c.Source__c => 'Order Intake'
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'AccountTriggerHandler',
				LogEntry__c.ShortMessage__c => 'Mentions Order Intake in the message'
		});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.origins = new List<String> {LOG_Engine.Origin.FLOW.name()};
		request.source = 'Order Intake';

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage result = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, result.totalCount, 'Expected only the filtered writer\'s row to be listed');
		Assert.areEqual(filteredWriterEntry.Id, result.records[0].id, 'Expected the listed row to be the filtered writer\'s');
		Assert.areEqual(1, summary.totalRows, 'The ribbon counts the same one row');
	}

	/**
	 * @description The origins and the source on the request each narrow the entries read on their own, so neither
	 * rides on the other: one origin covers two writers and one writer name covers two origins.
	 */
	@IsTest
	private static void shouldNarrowTheEntriesByTheOriginAloneAndBySourceAlone()
	{
		String sharedSource = 'Order Intake';
		String otherSource = 'AccountTriggerHandler';
		LogEntry__c componentRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => LOG_Engine.COMPONENT_SOURCE_PREFIX + sharedSource + UTIL_String.DOT + 'submit',
				LogEntry__c.Origin__c => LOG_Engine.Origin.COMPONENT.name(),
				LogEntry__c.Source__c => sharedSource
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => sharedSource + UTIL_String.DOT + 'submit',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => sharedSource
		});
		LogEntry__c otherWriterRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => otherSource
		});

		CTRL_LogConsole.DTO_Request originOnly = new CTRL_LogConsole.DTO_Request();
		originOnly.windowMinutes = WINDOW_SEVEN_DAYS;
		originOnly.origins = new List<String> {LOG_Engine.Origin.COMPONENT.name()};

		CTRL_LogConsole.DTO_Request sourceOnly = new CTRL_LogConsole.DTO_Request();
		sourceOnly.windowMinutes = WINDOW_SEVEN_DAYS;
		sourceOnly.source = otherSource;

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage byOrigin = CTRL_LogConsole.getLogEntries(JSON.serialize(originOnly));
		CTRL_LogConsole.DTO_LogEntryPage bySource = CTRL_LogConsole.getLogEntries(JSON.serialize(sourceOnly));
		Test.stopTest();

		Assert.areEqual(1, byOrigin.totalCount, 'The origin on its own lists only the row a component wrote');
		Assert.areEqual(componentRow.Id, byOrigin.records[0].id, 'The origin-only list holds the component row');
		Assert.areEqual(1, bySource.totalCount, 'The source on its own lists only the row that writer wrote');
		Assert.areEqual(otherWriterRow.Id, bySource.records[0].id, 'The source-only list holds that writer\'s row');
	}

	/**
	 * @description The problems ribbon carries each problem's origin, and a problem spanning origins ranks as Mixed.
	 */
	@IsTest
	private static void shouldCarryOriginOnProblemSourcesAndRankMixedAsMixed()
	{
		for(String origin : new List<String> {LOG_Engine.Origin.APEX.name(), LOG_Engine.Origin.FLOW.name()})
		{
			TST_Factory.seedLogEntry(new Map<SObjectField, Object>
			{
					LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
					LogEntry__c.ExceptionType__c => 'System.NullPointerException',
					LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
					LogEntry__c.Origin__c => origin,
					LogEntry__c.Source__c => 'AccountTriggerHandler',
					LogEntry__c.ShortMessage__c => 'npe'
			});
		}

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual('AccountTriggerHandler', summary.topSources[0].name, 'The problem names its writer');
		Assert.areEqual(SEL_LogEntry.ORIGIN_MIXED, summary.topSources[0].origin, 'A problem written under two origins says Mixed');
	}

	/**
	 * @description One writer name written under two origins ranks as two cards, and on the count tie the origin
	 * orders them ascending, so the ribbon never leaves two identically named cards in an arbitrary order.
	 */
	@IsTest
	private static void shouldBreakAWriterNameTieByOriginAscending()
	{
		String writerName = 'OrderService';
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => LOG_Engine.FLOW_SOURCE_PREFIX + writerName,
				LogEntry__c.Origin__c => LOG_Engine.Origin.FLOW.name(),
				LogEntry__c.Source__c => writerName
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => writerName + UTIL_String.DOT + 'submit',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => writerName
		});

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(2, summary.topSources.size(), 'The one writer name written under two origins ranks as two cards');
		Assert.areEqual(writerName, summary.topSources[0].name, 'The first card names the writer');
		Assert.areEqual(writerName, summary.topSources[1].name, 'The second card names the same writer');
		Assert.areEqual(LOG_Engine.Origin.APEX.name(), summary.topSources[0].origin, 'On a name tie the origin orders ascending, so Apex leads');
		Assert.areEqual(LOG_Engine.Origin.FLOW.name(), summary.topSources[1].origin, 'Flow ranks after Apex on the origin tie-break');
	}

	/**
	 * @description The drawer's detail carries the entry's origin and source.
	 */
	@IsTest
	private static void shouldCarryOriginAndSourceOnTheDetail()
	{
		LogEntry__c row = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_INFO,
				LogEntry__c.ClassMethod__c => 'LWC/orderPanel.submitOrder',
				LogEntry__c.Origin__c => LOG_Engine.Origin.COMPONENT.name(),
				LogEntry__c.Source__c => 'orderPanel'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(row.Id);
		Test.stopTest();

		Assert.areEqual(LOG_Engine.Origin.COMPONENT.name(), detail.origin, 'The detail says who wrote the entry');
		Assert.areEqual('orderPanel', detail.source, 'The detail names the writer');
	}

	/**
	 * @description Every row of the entries list carries the writer the entry stored: the writer's name, who the writer is, and
	 * the Source column's text. The three rows cover the three shapes a stored writer arrives in: an Apex class with a method and
	 * a line, a Flow whose class method holds no method at all, and a component whose class method carries the bridge prefix.
	 */
	@IsTest
	private static void shouldCarryTheStoredWriterOnEveryEntryRow()
	{
		LogEntry__c apexRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'OrderService' + UTIL_String.DOT + 'submit',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'OrderService',
				LogEntry__c.LineNumber__c => 88
		});
		LogEntry__c flowRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => LOG_Engine.FLOW_SOURCE_PREFIX + 'Order Intake',
				LogEntry__c.Origin__c => LOG_Engine.Origin.FLOW.name(),
				LogEntry__c.Source__c => 'Order Intake',
				LogEntry__c.LineNumber__c => 1
		});
		LogEntry__c componentRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => LOG_Engine.COMPONENT_SOURCE_PREFIX + 'orderPanel' + UTIL_String.DOT + 'submitOrder',
				LogEntry__c.Origin__c => LOG_Engine.Origin.COMPONENT.name(),
				LogEntry__c.Source__c => 'orderPanel',
				LogEntry__c.LineNumber__c => 1
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = entriesInWindow();
		Test.stopTest();

		CTRL_LogConsole.DTO_LogEntrySummary apexSummary = entrySummaryById(page, apexRow.Id);
		CTRL_LogConsole.DTO_LogEntrySummary flowSummary = entrySummaryById(page, flowRow.Id);
		CTRL_LogConsole.DTO_LogEntrySummary componentSummary = entrySummaryById(page, componentRow.Id);
		Assert.areEqual('OrderService', apexSummary.writerName, 'The Apex row names the class that wrote it');
		Assert.areEqual(LOG_Engine.Origin.APEX.name(), apexSummary.writerOrigin, 'The Apex row says an Apex class wrote it');
		Assert.areEqual('OrderService.submit:88', apexSummary.writerLocation, 'The Apex row reads as the class, the method and the line');
		Assert.areEqual('Order Intake', flowSummary.writerName, 'The Flow row names the Flow that wrote it');
		Assert.areEqual(LOG_Engine.Origin.FLOW.name(), flowSummary.writerOrigin, 'The Flow row says a Flow wrote it');
		Assert.areEqual('Order Intake:1', flowSummary.writerLocation, 'A row with no method reads as the writer and the line, joined by a colon');
		Assert.areEqual('orderPanel', componentSummary.writerName, 'The component row names the component that wrote it');
		Assert.areEqual(LOG_Engine.Origin.COMPONENT.name(), componentSummary.writerOrigin, 'The component row says a component wrote it');
		Assert.areEqual('orderPanel.submitOrder:1', componentSummary.writerLocation, 'The component row reads as the component, the method and the line');
	}

	/**
	 * @description A managed install records the namespace in front of the class, so the method text the console already shows
	 * repeats the writer's name. The Source column shows that text as it stands rather than naming the writer twice.
	 */
	@IsTest
	private static void shouldDropTheRepeatedWriterNameFromANamespacedClassMethod()
	{
		String namespacePrefix = UTIL_Random.randomAlphabetic(4);
		LogEntry__c namespacedRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => namespacePrefix + UTIL_String.DOT + 'UTIL_AsyncChain' + UTIL_String.DOT + 'run',
				LogEntry__c.Origin__c => LOG_Engine.Origin.FRAMEWORK.name(),
				LogEntry__c.Source__c => 'UTIL_AsyncChain',
				LogEntry__c.LineNumber__c => 214
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = entriesInWindow();
		Test.stopTest();

		Assert.areEqual('UTIL_AsyncChain.run:214', entrySummaryById(page, namespacedRow.Id).writerLocation, 'The writer is named once, not twice');
	}

	/**
	 * @description A row that stored no writer carries no writer on the wire either, and its class name and method line read
	 * exactly as they always have, so the list falls back to what it showed before entries recorded who wrote them.
	 */
	@IsTest
	private static void shouldLeaveTheWriterBlankOnARowThatStoredNone()
	{
		LogEntry__c unattributedRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'Legacy' + UTIL_String.DOT + 'row',
				LogEntry__c.LineNumber__c => 7
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = entriesInWindow();
		Test.stopTest();

		CTRL_LogConsole.DTO_LogEntrySummary summary = entrySummaryById(page, unattributedRow.Id);
		Assert.isNull(summary.writerName, 'A row written before entries recorded their writer names none');
		Assert.isNull(summary.writerOrigin, 'A row that names no writer says nothing about who the writer is');
		Assert.isNull(summary.writerLocation, 'Expected no Source column text with no writer, so the list shows the class name as it always has');
		Assert.areEqual('Legacy', summary.className, 'The class name is unchanged');
		Assert.areEqual('row:7', summary.methodLine, 'The method line is unchanged');
	}

	/**
	 * @description The logger records an origin for every entry and a writer's name only when it knew the class and method behind it, so a row
	 * can store an origin with no name to show it beside. Neither an entry nor the sample a tagged problem kept says who wrote it in that case,
	 * because the list names the writer only beside a name; the class name and method line each row did record read exactly as they always have.
	 */
	@IsTest
	private static void shouldLeaveTheOriginBlankWhereNoWriterNameWasStored()
	{
		LogEntry__c originOnlyRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.LineNumber__c => 31
		});
		seedDistinctProblem(BASE_NULL_POINTER, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.LineNumber__c => 142
		}, 18);

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage entryPage = entriesInWindow();
		CTRL_LogConsole.DTO_LogProblemPage problemPage = problemsSortedAscendingBy('lastSeen');
		Test.stopTest();

		CTRL_LogConsole.DTO_LogEntrySummary summary = entrySummaryById(entryPage, originOnlyRow.Id);
		Assert.isNull(summary.writerName, 'A row logged with no class and method to name the writer by names none');
		Assert.isNull(summary.writerOrigin, 'With no writer name to show it beside, the row says nothing about who the writer is');
		Assert.isNull(summary.writerLocation, 'Expected no Source column text with no writer, so the list shows the class name as it always has');
		Assert.isNull(summary.className, 'The class name is unchanged');
		Assert.areEqual('31', summary.methodLine, 'The line number the row did record is unchanged');

		CTRL_LogConsole.DTO_LogProblem tagged = problemBySource(problemPage, 'rollup');
		Assert.isNotNull(tagged, 'The tagged problem is on the page');
		Assert.isNull(tagged.writerName, 'A problem whose kept sample stored no writer name names none either');
		Assert.isNull(tagged.writerOrigin, 'A problem with no writer name to show it beside says nothing about who the writer is');
		Assert.isNull(tagged.writerLocation, 'Expected no Source column text on the problem either when there is no writer');
		Assert.areEqual(CLASS_METHOD_ACCOUNT, tagged.classMethod, 'The class method the problem was grouped under is unchanged');
	}

	/**
	 * @description A tagged problem carries the writer its sample entry stored; a problem grouped at read time carries the
	 * writer folded across its entries, saying Mixed when they were written under more than one origin, and its Source column
	 * text carries no line number because the line is not part of what the grouping matched on.
	 */
	@IsTest
	private static void shouldCarryTheStoredWriterOnATaggedProblemAndTheFoldedWriterOnAGroupedOne()
	{
		seedDistinctProblem(BASE_NULL_POINTER, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_ACCOUNT,
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'AccountTriggerHandler',
				LogEntry__c.LineNumber__c => 142
		}, 40);
		for(String origin : new List<String> {LOG_Engine.Origin.APEX.name(), LOG_Engine.Origin.FLOW.name()})
		{
			TST_Builder.of(LogEntry__c.SObjectType)
					.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
					.withOverride(LogEntry__c.ExceptionType__c, 'System.CalloutException')
					.withOverride(LogEntry__c.ClassMethod__c, 'PaymentGateway' + UTIL_String.DOT + 'capture')
					.withOverride(LogEntry__c.ShortMessage__c, 'Read timed out')
					.withOverride(LogEntry__c.Origin__c, origin)
					.withOverride(LogEntry__c.Source__c, 'PaymentGateway')
					.withCount(2)
					.buildList();
		}

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage page = problemsSortedAscendingBy('lastSeen');
		Test.stopTest();

		CTRL_LogConsole.DTO_LogProblem tagged = problemBySource(page, 'rollup');
		CTRL_LogConsole.DTO_LogProblem grouped = problemBySource(page, 'derived');
		Assert.isNotNull(tagged, 'The tagged problem is on the page');
		Assert.isNotNull(grouped, 'The grouped problem is on the page');
		Assert.areEqual('AccountTriggerHandler', tagged.writerName, 'The tagged problem names the writer its sample stored');
		Assert.areEqual(LOG_Engine.Origin.APEX.name(), tagged.writerOrigin, 'The tagged problem takes the origin of its sample');
		Assert.areEqual('AccountTriggerHandler.handleAfterUpdate:142', tagged.writerLocation, 'The tagged problem reads as the writer, the method and the line');
		Assert.areEqual('PaymentGateway', grouped.writerName, 'The grouped problem names the writer folded across its entries');
		Assert.areEqual(SEL_LogEntry.ORIGIN_MIXED, grouped.writerOrigin, 'Entries written under two origins fold to Mixed');
		Assert.areEqual('PaymentGateway.capture', grouped.writerLocation, 'The grouped problem reads as the writer and the method, with no line');
	}

	/**
	 * @description The entries list orders the Source column by the writer each entry stored, in both directions, rather than
	 * by the class method text the column used to show. Each writer sits in a class whose name runs the other way, so a sort
	 * still reading the class method returns the three rows backwards and fails; and the rows are seeded out of name order,
	 * so a sort that had quietly fallen back to when the rows were written could not produce the expected order either.
	 */
	@IsTest
	private static void shouldSortEntriesByTheStoredWriter()
	{
		for(Integer position : SEEDING_ORDER)
		{
			TST_Factory.seedLogEntry(new Map<SObjectField, Object>
			{
					LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
					LogEntry__c.ClassMethod__c => WRITER_HOLDER_CLASS_NAMES[position] + UTIL_String.DOT + 'run',
					LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
					LogEntry__c.Source__c => SORTED_WRITER_NAMES[position]
			});
		}

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage ascendingPage = entriesSortedBy('writerName', true);
		CTRL_LogConsole.DTO_LogEntryPage descendingPage = entriesSortedBy('writerName', false);
		Test.stopTest();

		Assert.areEqual(SORTED_WRITER_NAMES.size(), ascendingPage.records.size(), 'Every seeded row is listed, so the order under test is the whole page');
		assertWritersRunByName(entryWriterNames(ascendingPage), entryWriterNames(descendingPage));
	}

	/**
	 * @description The problems list orders the Source column by the writer each problem stored, in both directions. Each
	 * writer sits in a class whose name runs the other way, carries an occurrence count in a third order, and is seeded in a
	 * fourth, so neither the class name the column used to show nor the default count sort can produce the expected order.
	 */
	@IsTest
	private static void shouldSortProblemsByTheStoredWriter()
	{
		List<Integer> occurrenceCounts = new List<Integer> {5, 40, 12};
		for(Integer position : SEEDING_ORDER)
		{
			seedDistinctProblem('NullPointer:' + WRITER_HOLDER_CLASS_NAMES[position] + UTIL_String.DOT + 'run', new Map<SObjectField, Object>
			{
					LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
					LogEntry__c.ClassMethod__c => WRITER_HOLDER_CLASS_NAMES[position] + UTIL_String.DOT + 'run',
					LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
					LogEntry__c.Source__c => SORTED_WRITER_NAMES[position]
			}, occurrenceCounts[position]);
		}

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage ascendingPage = problemsSortedAscendingBy('writerName');
		CTRL_LogConsole.DTO_LogProblemPage descendingPage = problemsSortedBy('writerName', false);
		Test.stopTest();

		Assert.areEqual(SORTED_WRITER_NAMES.size(), ascendingPage.records.size(), 'Every seeded problem is listed, so the order under test is the whole page');
		assertWritersRunByName(problemWriterNames(ascendingPage), problemWriterNames(descendingPage));
	}

	/**
	 * @description A sort key the console no longer sends falls back to each view's own default order: the entries list by
	 * when the entry was written, newest first, and the problems list by how often the problem occurred, most first. Both
	 * fixtures are anti-aligned on the retired key, so a view still honouring it would return the other row first. The two
	 * problem samples are back-dated a day, so the pair of entries under test leads the entries list on its own merits.
	 */
	@IsTest
	private static void shouldFallBackToTheDefaultSortForAKeyTheConsoleNoLongerSends()
	{
		LogEntry__c newerRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'AaaService' + UTIL_String.DOT + 'run',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'AaaService'
		});
		LogEntry__c olderRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'ZzzService' + UTIL_String.DOT + 'run',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'ZzzService'
		});
		Test.setCreatedDate(newerRow.Id, Datetime.now().addHours(-1));
		Test.setCreatedDate(olderRow.Id, Datetime.now().addHours(-2));
		seedProblem('NullPointer:AaaHandler.run', LOG_Engine.LEVEL_ERROR, 'AaaHandler' + UTIL_String.DOT + 'run', new List<Integer> {40});
		seedProblem('NullPointer:ZzzHandler.run', LOG_Engine.LEVEL_ERROR, 'ZzzHandler' + UTIL_String.DOT + 'run', new List<Integer> {5});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage entriesPage = entriesSortedBy('className', false);
		CTRL_LogConsole.DTO_LogProblemPage problemsPage = problemsSortedBy('className', false);
		Test.stopTest();

		Assert.areEqual(newerRow.Id, entriesPage.records[0].id, 'The retired key leaves the entries list on its own default, the newest entry first');
		Assert.areEqual('AaaHandler', problemsPage.records[0].writerName, 'The retired key leaves the problems list on its own default, the most frequent problem first');
	}

	/**
	 * @description The Flow and API bridges record the writer's name and then a slash before the method, so a managed
	 * install's class method reads as the namespace, the writer and the bridge form. The Source column keeps that bridge form
	 * whole rather than putting the writer's name in front of itself.
	 */
	@IsTest
	private static void shouldKeepTheBridgeFormLocationWhenTheMethodTextAlreadyNamesTheWriter()
	{
		String namespacePrefix = UTIL_Random.randomAlphabetic(4);
		String bridgeClassMethod = namespacePrefix + UTIL_String.DOT + 'FLOW_WriteLog' + LOG_Engine.SOURCE_PREFIX_DELIMITER + 'writeLog';
		LogEntry__c bridgeRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => bridgeClassMethod,
				LogEntry__c.Origin__c => LOG_Engine.Origin.FLOW.name(),
				LogEntry__c.Source__c => 'FLOW_WriteLog'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = entriesInWindow();
		Test.stopTest();

		Assert.areEqual('FLOW_WriteLog/writeLog', entrySummaryById(page, bridgeRow.Id).writerLocation, 'The bridge form is the whole location and is shown as it stands');
	}

	/**
	 * @description A namespaced class that recorded no method leaves the namespace stripped text as the writer's own name and
	 * the line. The Source column shows that as it stands rather than naming the writer twice.
	 */
	@IsTest
	private static void shouldNotRepeatTheWriterNameForAClassMethodThatRecordsNoMethod()
	{
		String namespacePrefix = UTIL_Random.randomAlphabetic(4);
		LogEntry__c namespacedRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => namespacePrefix + UTIL_String.DOT + 'UTIL_Cache',
				LogEntry__c.Origin__c => LOG_Engine.Origin.FRAMEWORK.name(),
				LogEntry__c.Source__c => 'UTIL_Cache',
				LogEntry__c.LineNumber__c => 12
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = entriesInWindow();
		Test.stopTest();

		Assert.areEqual('UTIL_Cache:12', entrySummaryById(page, namespacedRow.Id).writerLocation, 'The writer and its line are shown once, not twice');
	}

	/**
	 * @description A method whose text merely begins with the writer's name, with no separator after it, is a different name
	 * and not a repeat, so the writer's name still goes in front of it.
	 */
	@IsTest
	private static void shouldKeepTheWriterNameWhenTheMethodOnlyBeginsWithIt()
	{
		LogEntry__c overlappingRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => 'Payment' + UTIL_String.DOT + 'PaymentRetry',
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => 'Payment',
				LogEntry__c.LineNumber__c => 5
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = entriesInWindow();
		Test.stopTest();

		Assert.areEqual('Payment.PaymentRetry:5', entrySummaryById(page, overlappingRow.Id).writerLocation, 'A method that merely starts with the writer name still follows it');
	}

	/**
	 * @description A row that recorded neither a method nor a line has nothing to add to the writer's name, so the Source column
	 * is the name on its own. The two rows cover the two ways that happens: a namespaced class whose remaining text is the
	 * writer's own name, and a Flow whose class method holds no method at all.
	 */
	@IsTest
	private static void shouldShowTheWriterNameAloneWhenNoMethodOrLineIsRecorded()
	{
		String namespacePrefix = UTIL_Random.randomAlphabetic(4);
		LogEntry__c namespacedRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => namespacePrefix + UTIL_String.DOT + 'UTIL_Cache',
				LogEntry__c.Origin__c => LOG_Engine.Origin.FRAMEWORK.name(),
				LogEntry__c.Source__c => 'UTIL_Cache'
		});
		LogEntry__c flowRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => LOG_Engine.FLOW_SOURCE_PREFIX + 'Order Intake',
				LogEntry__c.Origin__c => LOG_Engine.Origin.FLOW.name(),
				LogEntry__c.Source__c => 'Order Intake'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage page = entriesInWindow();
		Test.stopTest();

		Assert.areEqual('UTIL_Cache', entrySummaryById(page, namespacedRow.Id).writerLocation, 'A class whose remaining text is its own name reads as that name alone');
		Assert.areEqual('Order Intake', entrySummaryById(page, flowRow.Id).writerLocation, 'A row with no method and no line reads as the writer name alone');
	}

	/**
	 * @description A Flow whose own name holds a dot. The Flow bridges record the Flow's name after the Flow marker and
	 * never a method after it, so a dot there belongs to the name: the Source column shows the whole name and adds no
	 * method text of its own. The entry row and a problem grouped from rows like it must read the same name.
	 */
	@IsTest
	private static void shouldKeepAWholeFlowNameThatHoldsADot()
	{
		String dottedFlowName = 'Order v1' + UTIL_String.DOT + '2';
		List<LogEntry__c> flowRows = TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_WARN)
				.withOverride(LogEntry__c.ExceptionType__c, 'System.CalloutException')
				.withOverride(LogEntry__c.ClassMethod__c, LOG_Engine.FLOW_SOURCE_PREFIX + dottedFlowName)
				.withOverride(LogEntry__c.ShortMessage__c, 'Read timed out')
				.withOverride(LogEntry__c.Origin__c, LOG_Engine.Origin.FLOW.name())
				.withOverride(LogEntry__c.Source__c, dottedFlowName)
				.withCount(2)
				.buildList();

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage entriesPage = entriesInWindow();
		CTRL_LogConsole.DTO_LogProblemPage problemsPage = problemsSortedAscendingBy('lastSeen');
		Test.stopTest();

		Assert.areEqual(dottedFlowName, entrySummaryById(entriesPage, flowRows[0].Id).writerLocation,
				'A dot inside a Flow name belongs to the name, so the entry row shows the whole name and no method after it');
		Assert.areEqual(dottedFlowName, problemBySource(problemsPage, 'derived').writerLocation,
				'A problem grouped from those rows reads the same whole name');
	}

	/**
	 * @description A Flow's entries name the Flow as their class on every read the console makes: a tagged problem, a problem
	 * grouped at read time, a row of the entries list, the drawer's detail and every node of the correlated trace. The class
	 * method holds only the Flow marker before the slash, so the class name comes from the writer the entry stored.
	 */
	@IsTest
	private static void shouldNameAFlowByItsStoredSourceOnEveryReadPath()
	{
		List<LogEntry__c> flowRows = seedClassNameRows(CLASS_METHOD_FLOW, LOG_Engine.Origin.FLOW.name(), FLOW_NAME);
		seedDistinctProblem(BASE_FLOW, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_FLOW,
				LogEntry__c.Origin__c => LOG_Engine.Origin.FLOW.name(),
				LogEntry__c.Source__c => FLOW_NAME
		}, 3);

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage problemsPage = problemsSortedAscendingBy('lastSeen');
		CTRL_LogConsole.DTO_LogEntryPage entriesPage = entriesInWindow();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(flowRows[0].Id);
		CTRL_LogConsole.DTO_TracePage trace = CTRL_LogConsole.getCorrelatedTrace(flowRows[0].Id);
		Test.stopTest();

		Assert.areEqual(FLOW_NAME, problemBySource(problemsPage, 'rollup').className, 'A tagged Flow problem names the Flow');
		Assert.areEqual(FLOW_NAME, problemBySource(problemsPage, 'derived').className, 'A Flow problem grouped at read time names the Flow');
		Assert.areEqual(FLOW_NAME, entrySummaryById(entriesPage, flowRows[0].Id).className, 'A Flow entry in the list names the Flow');
		Assert.areEqual(FLOW_NAME, detail.className, 'The drawer names the Flow');
		Assert.areEqual(flowRows.size(), trace.entries.size(), 'The trace holds every entry of the correlated Flow run');
		for(CTRL_LogConsole.DTO_TraceEntry node : trace.entries)
		{
			Assert.areEqual(FLOW_NAME, node.className, 'Every node of the trace names the Flow');
		}
	}

	/**
	 * @description A Flow problem grouped at read time whose every entry was purged before it was opened still names the
	 * Flow in the drawer, because the signature the list hands the drawer carries the writer the entries stored.
	 */
	@IsTest
	private static void shouldNameAPurgedFlowProblemByItsStoredSource()
	{
		List<LogEntry__c> flowRows = seedClassNameRows(CLASS_METHOD_FLOW, LOG_Engine.Origin.FLOW.name(), FLOW_NAME);
		CTRL_LogConsole.DTO_LogProblem derived = problemBySource(problemsSortedAscendingBy('lastSeen'), 'derived');
		Assert.isNotNull(derived, 'The Flow entries fold into the problem whose signature is opened after the purge');
		DML_Builder.newTransaction().withSystemMode().doDelete(flowRows) // NOPMD: test purge of framework-owned rows: a user-mode delete FLS-fails in managed validation
				.execute();

		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR};

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getDerivedProblemDetail(derived.signature, JSON.serialize(request));
		Test.stopTest();

		Assert.isNull(detail.id, 'Every entry was purged, so the drawer shows the signature alone');
		Assert.areEqual(FLOW_NAME, detail.className, 'The purged problem still names the Flow');
	}

	/**
	 * @description An entry written before entries stored their writer carries none, so every read names its class the way
	 * the console always has, from the text of the class method: for a Flow, the Flow marker before the slash.
	 */
	@IsTest
	private static void shouldNameAnEntryThatStoredNoWriterFromItsClassMethodAsBefore()
	{
		List<LogEntry__c> flowRows = seedClassNameRows(CLASS_METHOD_FLOW, null, null);
		seedDistinctProblem(BASE_FLOW, new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ClassMethod__c => CLASS_METHOD_FLOW
		}, 3);

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage problemsPage = problemsSortedAscendingBy('lastSeen');
		CTRL_LogConsole.DTO_LogEntryPage entriesPage = entriesInWindow();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(flowRows[0].Id);
		CTRL_LogConsole.DTO_TracePage trace = CTRL_LogConsole.getCorrelatedTrace(flowRows[0].Id);
		Test.stopTest();

		Assert.areEqual(FLOW_CLASS_NAME_BEFORE_STORED_WRITER, problemBySource(problemsPage, 'rollup').className, 'A tagged problem with no writer reads as before');
		Assert.areEqual(FLOW_CLASS_NAME_BEFORE_STORED_WRITER, problemBySource(problemsPage, 'derived').className, 'A grouped problem with no writer reads as before');
		Assert.areEqual(FLOW_CLASS_NAME_BEFORE_STORED_WRITER, entrySummaryById(entriesPage, flowRows[0].Id).className, 'A list row with no writer reads as before');
		Assert.areEqual(FLOW_CLASS_NAME_BEFORE_STORED_WRITER, detail.className, 'The drawer of an entry with no writer reads as before');
		Assert.areEqual(FLOW_CLASS_NAME_BEFORE_STORED_WRITER, trace.entries[0].className, 'A trace node with no writer reads as before');
	}

	/**
	 * @description A class logged in an org with a namespace of its own records that namespace in front of the class, and the
	 * console names the class the entry stored as its writer, never the namespace.
	 */
	@IsTest
	private static void shouldNameAClassLoggedUnderAnotherNamespaceByItsStoredSource()
	{
		List<LogEntry__c> namespacedRows = seedClassNameRows(CLASS_METHOD_OTHER_NAMESPACE, LOG_Engine.Origin.APEX.name(), OTHER_NAMESPACE_WRITER);

		Test.startTest();
		CTRL_LogConsole.DTO_LogProblemPage problemsPage = problemsSortedAscendingBy('lastSeen');
		CTRL_LogConsole.DTO_LogEntryPage entriesPage = entriesInWindow();
		CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(namespacedRows[0].Id);
		Test.stopTest();

		Assert.areEqual(OTHER_NAMESPACE_WRITER, problemBySource(problemsPage, 'derived').className, 'The grouped problem names the class, not the namespace');
		Assert.areEqual(OTHER_NAMESPACE_WRITER, entrySummaryById(entriesPage, namespacedRows[0].Id).className, 'The list row names the class, not the namespace');
		Assert.areEqual(OTHER_NAMESPACE_WRITER, detail.className, 'The drawer names the class, not the namespace');
	}

	/**
	 * @description For a search term of brackets or quotes alone, the message match answers and the ribbon agrees with the list:
	 * each term finds only the entry whose message holds it literally, and a plain word still finds every entry that holds it.
	 * The search exception such a term raises in a live org is proven there, not here: a test's body search never reads the term.
	 */
	@IsTest
	private static void shouldAnswerAPunctuationOnlySearchFromTheMessageMatch()
	{
		LogEntry__c bracketsRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ShortMessage__c => MESSAGE_WITH_BRACKETS
		});
		LogEntry__c quotesRow = TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ShortMessage__c => MESSAGE_WITH_QUOTES
		});
		TST_Factory.seedLogEntry(new Map<SObjectField, Object>
		{
				LogEntry__c.LogLevel__c => LOG_Engine.LEVEL_ERROR,
				LogEntry__c.ShortMessage__c => 'An entry holding neither term'
		});

		Test.startTest();
		CTRL_LogConsole.DTO_LogEntryPage bracketsPage = entriesMatching(SEARCH_TERM_BRACKETS_ONLY);
		CTRL_LogConsole.DTO_EntrySummary bracketsSummary = entrySummaryMatching(SEARCH_TERM_BRACKETS_ONLY);
		CTRL_LogConsole.DTO_LogEntryPage quotesPage = entriesMatching(SEARCH_TERM_QUOTES_ONLY);
		CTRL_LogConsole.DTO_EntrySummary quotesSummary = entrySummaryMatching(SEARCH_TERM_QUOTES_ONLY);
		CTRL_LogConsole.DTO_LogEntryPage plainPage = entriesMatching(SEARCH_TERM_PLAIN_WORD);
		CTRL_LogConsole.DTO_EntrySummary plainSummary = entrySummaryMatching(SEARCH_TERM_PLAIN_WORD);
		Test.stopTest();

		Assert.areEqual(1, bracketsPage.records.size(), 'The brackets search lists only the entry that holds the brackets');
		Assert.areEqual(bracketsRow.Id, bracketsPage.records[0].id, 'The brackets search finds the entry that holds them literally');
		Assert.areEqual(1, bracketsSummary.totalRows, 'The ribbon counts what the brackets search lists');
		Assert.areEqual(1, quotesPage.records.size(), 'The quotes search lists only the entry that holds the quotes');
		Assert.areEqual(quotesRow.Id, quotesPage.records[0].id, 'The quotes search finds the entry that holds them literally');
		Assert.areEqual(1, quotesSummary.totalRows, 'The ribbon counts what the quotes search lists');
		Assert.areEqual(2, plainPage.records.size(), 'A plain word still finds every entry that holds it');
		Assert.areEqual(2, plainSummary.totalRows, 'The ribbon counts what the plain search lists');
	}

	/**
	 * @description Seeds one detail: sample row and one rollup: counter row per supplied count, each on a
	 * descending UTC day bucket (most-recent last), mirroring the production flood-control key shapes, and
	 * back-dates their CreatedDate so first-seen aggregation can be asserted. Returns the detail row.
	 *
	 * @param base The base fingerprint (without the detail:/rollup: prefix).
	 * @param level The log level for every row (DEBUG/INFO/WARN/ERROR).
	 * @param classMethod The Class.method whose first segment is the problem's writer name.
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
				LogEntry__c.Origin__c => LOG_Engine.Origin.APEX.name(),
				LogEntry__c.Source__c => classMethod?.substringBefore('.'),
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
	 * one level and source, so the all-entries summary aggregate can be asserted over real rows. Each row
	 * carries the attribution the logging engine stamps on a row written from Apex: an APEX origin, and the
	 * writer name the engine stores, which for a Class.method is the text before the first dot. A row seeded
	 * with no class-method carries no writer name, exactly as a row written with no class-method does.
	 *
	 * @param count The number of rows to seed.
	 * @param level The log level for every row.
	 * @param classMethod The Class.method whose first segment is the writer name.
	 * @param shortMessage The ShortMessage__c the search leg matches against.
	 */
	private static void seedForensicEntries(Integer count, String level, String classMethod, String shortMessage)
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, level)
				.withOverride(LogEntry__c.ClassMethod__c, classMethod)
				.withOverride(LogEntry__c.Origin__c, LOG_Engine.Origin.APEX.name())
				.withOverride(LogEntry__c.Source__c, classMethod?.substringBefore('.'))
				.withOverride(LogEntry__c.ShortMessage__c, shortMessage)
				.withCount(count)
				.buildList();
	}

	/**
	 * @description Seeds the two plain ERROR entries of one writer the class-name tests read: the same class method, origin,
	 * stored writer and exception type, so the pair folds into one problem, and one correlation, so the pair is one trace.
	 *
	 * @param classMethod The class method the entries record.
	 * @param origin The origin the entries store, or null for an entry written before entries stored one.
	 * @param source The writer the entries store, or null for an entry written before entries stored one.
	 *
	 * @return The two inserted entries.
	 */
	private static List<LogEntry__c> seedClassNameRows(String classMethod, String origin, String source)
	{
		return TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_ERROR)
				.withOverride(LogEntry__c.ExceptionType__c, CLASS_NAME_TEST_EXCEPTION)
				.withOverride(LogEntry__c.ClassMethod__c, classMethod)
				.withOverride(LogEntry__c.Origin__c, origin)
				.withOverride(LogEntry__c.Source__c, source)
				.withOverride(LogEntry__c.ShortMessage__c, 'Fault in ' + classMethod)
				.withOverride(LogEntry__c.CorrelationId__c, TRACE_CORRELATION_ID)
				.withCount(2)
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
		return problemsSortedBy(sortField, true);
	}

	/**
	 * @description Requests the distinct problems sorted by a given field over a seven-day window spanning the ERROR and WARN
	 * levels, in the given direction, so a test proving both directions states only the field and the direction.
	 *
	 * @param sortField The DTO_LogProblem field name to sort by.
	 * @param ascending Whether to sort ascending; false sorts descending.
	 *
	 * @return The resulting problem page.
	 */
	private static CTRL_LogConsole.DTO_LogProblemPage problemsSortedBy(String sortField, Boolean ascending)
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.levels = new List<String> {LOG_Engine.LEVEL_ERROR, LOG_Engine.LEVEL_WARN};
		request.sortField = sortField;
		request.sortAscending = ascending;
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
	 * @description Requests the entries ribbon for a free-text search term over the same seven-day window entriesMatching
	 * lists, so a test can hold the ribbon's count against the list it summarises.
	 *
	 * @param searchTerm The free-text term to search for.
	 *
	 * @return The resulting entries ribbon.
	 */
	private static CTRL_LogConsole.DTO_EntrySummary entrySummaryMatching(String searchTerm)
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.searchTerm = searchTerm;
		return CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
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
		return entriesSortedBy('logNumber', ascending);
	}

	/**
	 * @description Requests the flat entries page sorted by a given column over a seven-day window, in the given direction,
	 * so every per-column sort test states only the column and the direction it is proving.
	 *
	 * @param sortField The DTO_LogEntrySummary field name to sort by.
	 * @param ascending Whether to sort ascending; false sorts descending.
	 *
	 * @return The resulting entries page.
	 */
	private static CTRL_LogConsole.DTO_LogEntryPage entriesSortedBy(String sortField, Boolean ascending)
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		request.sortField = sortField;
		request.sortAscending = ascending;
		return CTRL_LogConsole.getLogEntries(JSON.serialize(request));
	}

	/**
	 * @description Requests the flat entries page over a seven-day window with no sort key and no filters, so a test that
	 * cares only about what each row carries states nothing about ordering.
	 *
	 * @return The resulting entries page.
	 */
	private static CTRL_LogConsole.DTO_LogEntryPage entriesInWindow()
	{
		CTRL_LogConsole.DTO_Request request = new CTRL_LogConsole.DTO_Request();
		request.windowMinutes = WINDOW_SEVEN_DAYS;
		return CTRL_LogConsole.getLogEntries(JSON.serialize(request));
	}

	/**
	 * @description The writer each row of an entries page names, in the page's own order, so a sort can be asserted as one
	 * whole ordering rather than row by row.
	 *
	 * @param page The entries page.
	 *
	 * @return The writer names in page order.
	 */
	private static List<String> entryWriterNames(CTRL_LogConsole.DTO_LogEntryPage page)
	{
		List<String> writerNames = new List<String>();
		for(CTRL_LogConsole.DTO_LogEntrySummary summary : page.records)
		{
			writerNames.add(summary.writerName);
		}
		return writerNames;
	}

	/**
	 * @description The writer each row of a problems page names, in the page's own order, so a sort can be asserted as one
	 * whole ordering rather than row by row.
	 *
	 * @param page The problems page.
	 *
	 * @return The writer names in page order.
	 */
	private static List<String> problemWriterNames(CTRL_LogConsole.DTO_LogProblemPage page)
	{
		List<String> writerNames = new List<String>();
		for(CTRL_LogConsole.DTO_LogProblem problem : page.records)
		{
			writerNames.add(problem.writerName);
		}
		return writerNames;
	}

	/**
	 * @description Asserts that a view returned the seeded writers in name order one way and in the reverse order the other,
	 * so both views state the same expectation of the Source column in one place.
	 *
	 * @param ascendingWriterNames The writer names the ascending request returned, in page order.
	 * @param descendingWriterNames The writer names the descending request returned, in page order.
	 */
	private static void assertWritersRunByName(List<String> ascendingWriterNames, List<String> descendingWriterNames)
	{
		List<String> expectedDescending = new List<String>();
		for(Integer position = SORTED_WRITER_NAMES.size() - 1; position >= 0; position--)
		{
			expectedDescending.add(SORTED_WRITER_NAMES[position]);
		}
		Assert.areEqual(SORTED_WRITER_NAMES, ascendingWriterNames, 'The ascending list runs from the first writer by name to the last');
		Assert.areEqual(expectedDescending, descendingWriterNames, 'The descending list runs from the last writer by name to the first');
	}

	/**
	 * @description Finds the summary row for a seeded entry on a page, so a row assertion never depends on where the page's
	 * default ordering happened to put the row. A page that holds no such row fails the test where it stands, saying which
	 * entry is missing, rather than handing back a null the caller trips over.
	 *
	 * @param page The entries page.
	 * @param entryId The seeded entry's record Id.
	 *
	 * @return The matching summary row.
	 */
	private static CTRL_LogConsole.DTO_LogEntrySummary entrySummaryById(CTRL_LogConsole.DTO_LogEntryPage page, Id entryId)
	{
		CTRL_LogConsole.DTO_LogEntrySummary match;
		for(CTRL_LogConsole.DTO_LogEntrySummary summary : page.records)
		{
			if(entryId == summary.id)
			{
				match = summary;
				break;
			}
		}
		Assert.isNotNull(match, 'The page holds a row for the seeded entry ' + entryId);
		return match;
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

	/**
	 * @description Seeds one forensic entry of an action, back-dated by the given minutes.
	 *
	 * @param correlationId The entry's own tracking id.
	 * @param rootCorrelationId The action's id, or null for an entry persisted before roots.
	 * @param shortMessage The short message.
	 * @param minutesAgo How many minutes before now the entry was written (negative for the past).
	 *
	 * @return The inserted row, re-read so CreatedDate is populated.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static LogEntry__c seedActionEntry(String correlationId, String rootCorrelationId, String shortMessage, Integer minutesAgo)
	{
		return seedActionEntryFrom(CLASS_METHOD_ACCOUNT, correlationId, rootCorrelationId, shortMessage, minutesAgo);
	}

	/**
	 * @description Seeds one forensic entry from a named source, carrying a correlation id and a root, back-dated by minutes.
	 * The query-count test seeds each of its groups from its own source, so a source filter reads one group alone.
	 *
	 * @param classMethod The source the entry is logged from.
	 * @param correlationId The entry's own tracking id.
	 * @param rootCorrelationId The action's id, or null for an entry recorded before roots.
	 * @param shortMessage The short message.
	 * @param minutesAgo How many minutes before now the entry was written (negative for the past).
	 *
	 * @return The row as the console reads it.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static LogEntry__c seedActionEntryFrom(String classMethod, String correlationId, String rootCorrelationId, String shortMessage, Integer minutesAgo)
	{
		LogEntry__c row = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, LOG_Engine.LEVEL_INFO)
				.withOverride(LogEntry__c.ClassMethod__c, classMethod)
				.withOverride(LogEntry__c.ShortMessage__c, shortMessage)
				.withOverride(LogEntry__c.CorrelationId__c, correlationId)
				.withOverride(LogEntry__c.RootCorrelationId__c, rootCorrelationId)
				.build();
		Test.setCreatedDate(row.Id, Datetime.now().addMinutes(minutesAgo));
		return new SEL_LogEntry().findByIdForConsole(row.Id);
	}

	/**
	 * @description Seeds one run record with the tracking fields the banner and the column read.
	 *
	 * @param correlationId The run's own tracking id.
	 * @param rootCorrelationId The action's id, or null for a run recorded before roots.
	 * @param launchCorrelationId The id the run was launched under, or null.
	 * @param sourceExecutionId The run this one was restarted from, or null.
	 * @param status The run's status.
	 * @param startedMinutesAgo How many minutes before now the run started (negative for the past).
	 *
	 * @return The inserted run with its chain number populated.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static AsyncChainExecution__c seedActionRun
			(
					String correlationId,
					String rootCorrelationId,
					String launchCorrelationId,
					Id sourceExecutionId,
					String status,
					Integer startedMinutesAgo
			)
	{
		AsyncChainExecution__c run = TST_Factory.newChainExecution(status, ACTION_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.CorrelationId__c => correlationId,
				AsyncChainExecution__c.RootCorrelationId__c => rootCorrelationId,
				AsyncChainExecution__c.LaunchCorrelationId__c => launchCorrelationId,
				AsyncChainExecution__c.SourceExecution__c => sourceExecutionId,
				AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(startedMinutesAgo)
		});
		return new SEL_AsyncChainExecution().findByIdsForSummary(new Set<Id> {run.Id})[0];
	}

	/**
	 * @description Seeds many completed runs under one action in one insert, for the large-fixture measurements.
	 *
	 * @param count How many runs.
	 * @param rootCorrelationId The action's id.
	 */
	private static void seedActionRuns(Integer count, String rootCorrelationId)
	{
		List<Object> correlationIds = new List<Object>();
		for(Integer index = 0; index < count; index++)
		{
			correlationIds.add(UTIL_Random.randomUUID());
		}
		TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, ACTION_CHAIN_NAME)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_COMPLETED)
				.withOverride(AsyncChainExecution__c.RootCorrelationId__c, rootCorrelationId)
				.withOverride(AsyncChainExecution__c.LaunchCorrelationId__c, rootCorrelationId)
				.withOverride(AsyncChainExecution__c.StartedAt__c, Datetime.now().addMinutes(-30))
				.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
				.withOverride(AsyncChainExecution__c.TotalSteps__c, 1)
				.withOverride(AsyncChainExecution__c.CompletedSteps__c, 1)
				.withCycle(AsyncChainExecution__c.CorrelationId__c, correlationIds)
				.withCount(count)
				.buildList();
	}

	/**
	 * @description Seeds runs the way the engine writes a nested action: thirteen roots launched under the action,
	 * each with five children, twenty-five grandchildren and 125 leaves launched under their parents' correlations;
	 * five-step logs with durations; every eighth leaf Failed, every third of those RetriesExhausted; twenty restart
	 * clones of failed leaves; siblings sharing a start second; the roots started first so their children's
	 * launchers fall off a first page sorted by start time.
	 *
	 * @param roots How many roots.
	 * @param rootCorrelationId The action's id.
	 *
	 * @return Every inserted run, roots first, in launch order.
	 */
	private static List<AsyncChainExecution__c> seedNestedActionRuns(Integer roots, String rootCorrelationId)
	{
		List<NestedRunSeed> seeds = new List<NestedRunSeed>();
		Datetime base = Datetime.now().addHours(-NESTED_BASE_HOURS_AGO);
		for(Integer root = 0; root < roots; root++)
		{
			Datetime levelStart = base.addMinutes(root * NESTED_ROOT_SPACING_MINUTES);
			seeds.addAll(buildRootAndDescendants(levelStart, rootCorrelationId));
		}
		List<AsyncChainExecution__c> inserted = insertNestedRuns(seeds, rootCorrelationId);
		inserted.addAll(cloneFailedRuns(inserted, rootCorrelationId));
		return inserted;
	}

	/**
	 * @description Builds one root and the three levels of children, grandchildren and leaves launched under it.
	 *
	 * @param levelStart When the root starts; each level below starts a further minute of simulated time after it.
	 * @param rootCorrelationId The action's id, launching the root.
	 *
	 * @return The root's own seed, followed by every descendant's, in launch order.
	 */
	private static List<NestedRunSeed> buildRootAndDescendants(Datetime levelStart, String rootCorrelationId)
	{
		List<NestedRunSeed> seeds = new List<NestedRunSeed>();
		String rootId = UTIL_Random.randomUUID();
		NestedRunSeed rootSeed = new NestedRunSeed();
		rootSeed.correlationId = rootId;
		rootSeed.launchCorrelationId = rootCorrelationId;
		rootSeed.chainName = NESTED_CHAIN_NAMES[0];
		rootSeed.status = SEL_AsyncChainExecution.STATUS_COMPLETED;
		rootSeed.failureCategory = null;
		rootSeed.startedAt = levelStart;
		rootSeed.stepLog = nestedStepLog(false, 1);
		rootSeed.completedSteps = NESTED_STEP_COUNT;
		seeds.add(rootSeed);

		List<String> level = new List<String> {rootId};
		for(Integer depth = 1; depth <= NESTED_DEPTH; depth++)
		{
			List<NestedRunSeed> levelSeeds = buildLevelSeeds(level, depth, levelStart);
			seeds.addAll(levelSeeds);
			level = new List<String>();
			for(NestedRunSeed levelSeed : levelSeeds)
			{
				level.add(levelSeed.correlationId);
			}
		}
		return seeds;
	}

	/**
	 * @description Builds one level's seeds: every parent's five children, the leaves among them decided a status and
	 * a failure category.
	 *
	 * @param parents The correlation ids launching this level.
	 * @param depth How deep this level is below the root; the deepest level's runs are leaves.
	 * @param levelStart The root's own start time, which every level offsets from.
	 *
	 * @return This level's seeds, in launch order; their correlation ids launch the level below.
	 */
	private static List<NestedRunSeed> buildLevelSeeds(List<String> parents, Integer depth, Datetime levelStart)
	{
		List<NestedRunSeed> seeds = new List<NestedRunSeed>();
		Boolean leafLevel = depth == NESTED_DEPTH;
		Integer ordinal = 0;
		for(String parent : parents)
		{
			for(Integer child = 0; child < NESTED_FAN_OUT; child++)
			{
				String childId = UTIL_Random.randomUUID();
				LeafOutcome outcome = leafLevel ? decideLeafOutcome(ordinal) : new LeafOutcome();
				seeds.add(toRunSeed(childId, parent, depth, outcome, levelStart, ordinal));
				ordinal++;
			}
		}
		return seeds;
	}

	/**
	 * @description Decides one leaf's status and failure category: every eighth leaf fails, and every third of those
	 * fails as RetriesExhausted rather than StepException.
	 *
	 * @param ordinal The leaf's position among its level's leaves.
	 *
	 * @return The leaf's status and failure category.
	 */
	private static LeafOutcome decideLeafOutcome(Integer ordinal)
	{
		Boolean failed = Math.mod(ordinal, NESTED_FAILED_LEAF_INTERVAL) == 0;
		Boolean exhausted = failed && Math.mod(ordinal / NESTED_FAILED_LEAF_INTERVAL, NESTED_EXHAUSTED_INTERVAL) == NESTED_EXHAUSTED_INTERVAL - 1;
		LeafOutcome outcome = new LeafOutcome();
		outcome.status = failed ? SEL_AsyncChainExecution.STATUS_FAILED : SEL_AsyncChainExecution.STATUS_COMPLETED;
		String failedCategory = exhausted ? SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED : SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
		outcome.failureCategory = failed ? failedCategory : null;
		return outcome;
	}

	/**
	 * @description Builds one run's seed from its outcome: the chain name for its depth, its tied start second, its
	 * step log and its completed-step count.
	 *
	 * @param correlationId The run's own tracking id.
	 * @param launchCorrelationId The id the run was launched under.
	 * @param depth How deep this run is below the root, naming its chain.
	 * @param outcome The run's status and failure category.
	 * @param levelStart The root's own start time.
	 * @param ordinal The run's position among its level's runs, tying every NESTED_FAN_OUT of them to one second.
	 *
	 * @return The run's seed.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static NestedRunSeed toRunSeed(String correlationId, String launchCorrelationId, Integer depth, LeafOutcome outcome, Datetime levelStart, Integer ordinal)
	{
		Boolean failed = outcome.status == SEL_AsyncChainExecution.STATUS_FAILED;
		Boolean exhausted = outcome.failureCategory == SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED;
		NestedRunSeed seed = new NestedRunSeed();
		seed.correlationId = correlationId;
		seed.launchCorrelationId = launchCorrelationId;
		seed.chainName = NESTED_CHAIN_NAMES[depth];
		seed.status = outcome.status;
		seed.failureCategory = outcome.failureCategory;
		seed.startedAt = levelStart.addSeconds(depth * SECONDS_PER_MINUTE + (ordinal / NESTED_FAN_OUT));
		seed.stepLog = nestedStepLog(failed, exhausted ? NESTED_EXHAUSTED_ATTEMPTS : 1);
		seed.completedSteps = failed ? NESTED_STEP_COUNT - 1 : NESTED_STEP_COUNT;
		return seed;
	}

	/**
	 * @description Inserts every seed's run in one bulk call, bypassing the object's trigger action while it does:
	 * `TriggerSetting.AsyncChainExecution.ApplyMasking__c` fires data masking on every insert (`MaskingTarget` records
	 * scan every field, StepLog__c included, for card and secret patterns), which is cheap on `seedActionRuns`' blank
	 * step logs but scans this fixture's real, per-record step-log JSON over two thousand rows in one statement, and
	 * exceeds the CPU limit before the measurement it is meant to support even starts. The synthetic step logs never
	 * carry a masked pattern, so bypassing changes nothing the assertions read.
	 *
	 * @param seeds The runs to insert.
	 * @param rootCorrelationId The action's id, applied to every run.
	 *
	 * @return The inserted runs, in seed order.
	 */
	private static List<AsyncChainExecution__c> insertNestedRuns(List<NestedRunSeed> seeds, String rootCorrelationId)
	{
		List<Object> correlationIds = new List<Object>();
		List<Object> launchIds = new List<Object>();
		List<Object> chainNames = new List<Object>();
		List<Object> statuses = new List<Object>();
		List<Object> categories = new List<Object>();
		List<Object> startedAts = new List<Object>();
		List<Object> stepLogs = new List<Object>();
		List<Object> completedSteps = new List<Object>();
		for(NestedRunSeed seed : seeds)
		{
			correlationIds.add(seed.correlationId);
			launchIds.add(seed.launchCorrelationId);
			chainNames.add(seed.chainName);
			statuses.add(seed.status);
			categories.add(seed.failureCategory);
			startedAts.add(seed.startedAt);
			stepLogs.add(seed.stepLog);
			completedSteps.add(seed.completedSteps);
		}
		TRG_Base.bypass(AsyncChainExecution__c.SObjectType);
		try
		{
			return TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.RootCorrelationId__c, rootCorrelationId)
					.withOverride(AsyncChainExecution__c.TotalSteps__c, NESTED_STEP_COUNT)
					.withOverride(AsyncChainExecution__c.AllowRestart__c, true)
					.withCycle(AsyncChainExecution__c.CorrelationId__c, correlationIds)
					.withCycle(AsyncChainExecution__c.LaunchCorrelationId__c, launchIds)
					.withCycle(AsyncChainExecution__c.ChainName__c, chainNames)
					.withCycle(AsyncChainExecution__c.Status__c, statuses)
					.withCycle(AsyncChainExecution__c.FailureCategory__c, categories)
					.withCycle(AsyncChainExecution__c.StartedAt__c, startedAts)
					.withCycle(AsyncChainExecution__c.StepLog__c, stepLogs)
					.withCycle(AsyncChainExecution__c.CompletedSteps__c, completedSteps)
					.withCount(seeds.size())
					.buildList();
		}
		finally
		{
			TRG_Base.clearBypass(AsyncChainExecution__c.SObjectType);
		}
	}

	/**
	 * @description Clones the fixture's first NESTED_RESTART_CLONES failed runs as restarts: launched under nothing,
	 * carrying the source run's id and starting thirty minutes after it.
	 *
	 * @param runs The inserted runs to clone from.
	 * @param rootCorrelationId The action's id, applied to every clone.
	 *
	 * @return The inserted clones.
	 */
	private static List<AsyncChainExecution__c> cloneFailedRuns(List<AsyncChainExecution__c> runs, String rootCorrelationId)
	{
		List<AsyncChainExecution__c> clones = new List<AsyncChainExecution__c>();
		for(AsyncChainExecution__c run : runs)
		{
			if(clones.size() == NESTED_RESTART_CLONES)
			{
				break;
			}
			if(run.Status__c != SEL_AsyncChainExecution.STATUS_FAILED)
			{
				continue;
			}
			clones.add(TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, run.ChainName__c, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CorrelationId__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.RootCorrelationId__c => rootCorrelationId,
					AsyncChainExecution__c.LaunchCorrelationId__c => null,
					AsyncChainExecution__c.SourceExecution__c => run.Id,
					AsyncChainExecution__c.StartedAt__c => run.StartedAt__c.addMinutes(NESTED_CLONE_OFFSET_MINUTES)
			}));
		}
		return clones;
	}

	/**
	 * @description A five-step log with durations, the last step failed when asked, with its attempts.
	 *
	 * @param failed True when the last step of the log failed.
	 * @param attempts How many attempts the last step recorded.
	 *
	 * @return The serialized step log.
	 */
	private static String nestedStepLog(Boolean failed, Integer attempts)
	{
		List<Map<String, Object>> steps = new List<Map<String, Object>>();
		for(Integer index = 0; index < NESTED_STEP_COUNT; index++)
		{
			Boolean last = index == NESTED_STEP_COUNT - 1;
			steps.add(new Map<String, Object>
			{
					'className' => 'SubscriberChainSteps.' + (last ? 'OutcomeStep' : 'NarratingStep'), 'stepName' => last ? 'Outcome' : 'Narrating',
					'success' => !(last && failed), 'durationMs' => NESTED_STEP_DURATIONS_MS[index], 'attempt' => last ? attempts : 1, 'isIdempotent' => false
			});
		}
		return JSON.serialize(steps);
	}

	/**
	 * @description One nested run's field values, built up before the fixture's single bulk insert.
	 */
	private class NestedRunSeed
	{
		/**
		 * @description The run's own tracking id.
		 */
		private String correlationId;

		/**
		 * @description The id the run was launched under.
		 */
		private String launchCorrelationId;

		/**
		 * @description The chain name for the run's depth.
		 */
		private String chainName;

		/**
		 * @description The run's status.
		 */
		private String status;

		/**
		 * @description The run's failure category, null unless it failed.
		 */
		private String failureCategory;

		/**
		 * @description When the run started.
		 */
		private Datetime startedAt;

		/**
		 * @description The run's serialized step log.
		 */
		private String stepLog;

		/**
		 * @description How many of the run's steps completed.
		 */
		private Integer completedSteps;
	}

	/**
	 * @description The status and failure category a leaf resolves to.
	 */
	private class LeafOutcome
	{
		/**
		 * @description The leaf's status.
		 */
		private String status;

		/**
		 * @description The leaf's failure category, null unless it failed.
		 */
		private String failureCategory;

		/**
		 * @description Defaults to a completed outcome with no failure category, for a run that is not a leaf or a
		 * leaf that did not fail; `decideLeafOutcome` overwrites both fields for a failed leaf.
		 */
		private LeafOutcome()
		{
			status = SEL_AsyncChainExecution.STATUS_COMPLETED;
			failureCategory = null;
		}
	}
}