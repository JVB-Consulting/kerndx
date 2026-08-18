// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Console controller for the Log Console — turns the flood-controlled LogEntry__c table
 * into a place to find problems (a distinct "this error x N occurrences" fold) and inspect them (a
 * flat forensic view, a scope summary, and a single-entry detail with governor-limit bars). Every
 * request crosses the wire as one JSON string; the controller deserialises it with a blank guard,
 * resolves sort fields through an allow-list, and returns pre-computed display-ready DTOs so the LWC
 * never parses JSON. Reads route through SEL_LogEntry, which bypasses sharing and runs in SYSTEM_MODE
 * so an administrator reads every user's framework-owned log rows.
 *
 * @see SEL_LogEntry
 * @see CTRL_LogConsole_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date June 2026, August 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount')
public with sharing class CTRL_LogConsole
{
	/**
	 * @description The default look back window in minutes (24 hours) when the request omits one.
	 */
	private static final Integer DEFAULT_WINDOW_MINUTES = 1440;

	/**
	 * @description Rows per page used when a request omits a page size or supplies a non-positive value.
	 * Owned in this layer — the request normalises against it (DTO_Request.resolvedPageSize) — so the
	 * selector stays a pure query layer and never re-implements pagination policy.
	 */
	private static final Integer DEFAULT_PAGE_SIZE = 50;

	/**
	 * @description Hard cap on the number of distinct problems folded into the problems page. Mutable
	 * and @TestVisible so a test can lower it to drive the capped branch without seeding thousands of rows.
	 */
	@TestVisible
	@SuppressWarnings('PMD.FieldNamingConventions')
	private static Integer PROBLEM_CANDIDATE_CAP = 2000;

	/**
	 * @description Provenance of a fingerprinted problem folded from rollup: counter rows (openable by id).
	 */
	private static final String SOURCE_ROLLUP = 'rollup';

	/**
	 * @description Provenance of a problem read-time-grouped from plain forensic rows (opened by signature).
	 */
	private static final String SOURCE_DERIVED = 'derived';

	/**
	 * @description Derived-leg outcome: folded and merged into the problems page.
	 */
	private static final String DERIVED_STATUS_COMPLETE = 'COMPLETE';

	/**
	 * @description Derived-leg outcome: ProblemGroupingDisabled__c is checked, so the leg did not run.
	 */
	private static final String DERIVED_STATUS_DISABLED = 'DISABLED';

	/**
	 * @description Derived-leg outcome: a free-text search term suppresses the leg (a long-text body
	 * cannot traverse a GROUP BY, so both legs stay filtered by the same rules).
	 */
	private static final String DERIVED_STATUS_SKIPPED_SEARCH = 'SKIPPED_SEARCH';

	/**
	 * @description Derived-leg outcome: the aggregate scan was non-selective, so the leg degraded to
	 * rollup-only rather than breaking the view.
	 */
	private static final String DERIVED_STATUS_SKIPPED_NON_SELECTIVE = 'SKIPPED_NON_SELECTIVE';

	/**
	 * @description Derived-leg outcome: the console's level filter and the configured ProblemGroupingLogLevels__c
	 * scope share no level, so there is nothing the leg is permitted to group. Its own status rather than an
	 * empty COMPLETE, because the two say different things to a subscriber: COMPLETE means the fold ran and
	 * found nothing recurring, this means the fold was never allowed to look at the level being viewed.
	 *
	 * @date August 2026
	 */
	private static final String DERIVED_STATUS_SKIPPED_LEVEL_SCOPE = 'SKIPPED_LEVEL_SCOPE';

	/**
	 * @description totalsApproximateCause when a candidate set overflowed its cap: the totals are folded from a
	 * capped candidate set, so they are real but low. The two caps keep different groups — the rollup cap keeps
	 * the newest counters, the derived cap keeps the most frequent signatures. The released help text this cause
	 * drives (LogConsole_TotalsApproximateHelp) describes the rollup case, "the most recent activity groups", which
	 * is imprecise for the derived cap; a released label value is left as it is, and the imprecision is recorded.
	 */
	private static final String TOTALS_CAUSE_TRUNCATED = 'TRUNCATED';

	/**
	 * @description totalsApproximateCause when a whole leg never ran, so its contribution is absent rather than
	 * trimmed. Either leg can reach this — the rollup scan degrading on a QueryException, or the derived fold
	 * declining a scan it cannot afford — so the copy this drives must not blame problem grouping.
	 */
	private static final String TOTALS_CAUSE_PARTIAL = 'PARTIAL';

	/**
	 * @description Hard cap on the rollup: counter rows fetched as the distinct-problem candidate set.
	 * Above the cap the fold is best-effort (the oldest in-window counters drop) and the summary and
	 * problems shapes flag totalsApproximate. Mutable and @TestVisible so a test can lower it to drive
	 * the overflow branch without seeding thousands of rows.
	 *
	 * @date July 2026
	 */
	@TestVisible
	@SuppressWarnings('PMD.FieldNamingConventions')
	private static Integer ROLLUP_CANDIDATE_CAP = 5000;

	/**
	 * @description Ceiling on the rows the derived fold may scan in one request. A GROUP BY spends query
	 * rows on every row it SCANS, not on the groups it returns, so a wide enough window exhausts the
	 * governor and raises a limit exception — which Apex cannot catch, so the leg's QueryException degrade
	 * cannot absorb it and the whole view would fail. The fold is therefore declined in advance when the
	 * window holds more than this, and the leg reports SKIPPED_NON_SELECTIVE exactly as it does for a
	 * genuinely non-selective scan.
	 *
	 * Sized against the WORST of the two entry points rather than the average. getLogSummary spends more
	 * before the fold than getLogProblems does: it fetches a sample per distinct rollup base over the full
	 * candidate set (up to ROLLUP_CANDIDATE_CAP bases), where getLogProblems bounds the same fetch at
	 * PROBLEM_CANDIDATE_CAP. Worst case ahead of the fold is therefore the rollup probe fetch plus one
	 * sample per base — about 10,000 rows — so the ceiling leaves 15,000 rows of headroom rather than
	 * spending it. A deliberate constant, NOT a budget derived from Limits.getQueryRows() at call time: the
	 * two entry points are separate transactions with different prior spend, so a live budget would let the
	 * same window fold for the list and decline for the ribbon, breaking the invariant that the two agree.
	 * Mutable and @TestVisible so a test can lower it to drive the declined branch without seeding tens of
	 * thousands of rows.
	 *
	 * @date August 2026
	 */
	@TestVisible
	@SuppressWarnings('PMD.FieldNamingConventions')
	private static Integer DERIVED_SCAN_ROW_CEILING = 35000;

	/**
	 * @description Ceiling on the rows the all-entries ribbon may scan in one request. The ribbon folds TWO
	 * aggregate queries over the same windowed scope — rows per level, rows per source — and a GROUP BY spends
	 * query rows on every row it SCANS, so the worst request costs twice the window plus the pre-flight count:
	 * 2 × 22,000 + 1 = 44,001 of the 50,000-row governor, and the exception past that governor cannot be
	 * caught. Above the ceiling the breakdown is declined in advance and the ribbon answers with the exact
	 * total the count measured, which is honest where two zero-filled aggregate legs would not be. The ~6,000
	 * rows left under the governor absorb the count-to-scan gap: a row committing in the same clock second
	 * floor-truncates into a just-counted window (and a future-ended custom range holds the window open), every
	 * such row is scanned by BOTH legs, and one platform-event trigger batch can commit 2,000 at once — at the
	 * ceiling the spend stays under the governor until 3,000 rows land in that gap, a full batch and half
	 * again. The searched ribbon needs no ceiling: it aggregates over the bounded matched-id set instead of
	 * the window. A deliberate constant, the fold ceiling's sibling (see DERIVED_SCAN_ROW_CEILING for why a
	 * constant beats a live budget). Mutable and @TestVisible so a test can lower it to drive the declined
	 * branch without seeding tens of thousands of rows.
	 *
	 * @date August 2026
	 */
	@TestVisible
	@SuppressWarnings('PMD.FieldNamingConventions')
	private static Integer ENTRY_SUMMARY_SCAN_ROW_CEILING = 22000;

	/**
	 * @description Splits ProblemGroupingLogLevels__c on either separator. The shipped default and the platform's
	 * own multi-value convention use a semicolon, but the two sibling multi-value settings on this object
	 * (ClassFilter__c and SuppressClassMethod__c) are documented as comma-separated, so a subscriber carrying
	 * that habit across configures a working scope rather than one that silently matches nothing.
	 *
	 * @date August 2026
	 */
	private static final String DERIVED_LEVEL_SEPARATOR = '[;,]';

	/**
	 * @description The level scope the derived fold applies when ProblemGroupingLogLevels__c holds no level the
	 * framework recognises — the shipped default, and what a Text field added to an existing custom-setting
	 * record reads as on upgrade, since custom-setting data cannot ship in a package. Recurring problems worth
	 * grouping live at ERROR and WARN, and confining the scan to them is what keeps it cheap on a busy org.
	 *
	 * @date August 2026
	 */
	private static final List<String> DEFAULT_DERIVED_LEVELS = new List<String> {LoggingLevel.ERROR.name(), LoggingLevel.WARN.name()};

	/**
	 * @description The sample fields the distinct-view in-memory matcher tests a free-text term against.
	 * The first two mirror the All-entries SOQL search leg (SEL_LogEntry.findIdsBySearch: short message and
	 * correlation id); the remaining three approximate its SOSL body leg over the fields a detail sample
	 * actually carries. Single-sourced so the two views' text coverage is reconciled in one reviewable
	 * place — a SOSL IN ALL FIELDS search can never be reproduced exactly by a fixed in-memory list, so the
	 * lists are aligned by intent, not byte-identical.
	 *
	 * @date July 2026
	 */
	private static final List<SObjectField> SAMPLE_SEARCH_FIELDS = new List<SObjectField>
	{
			LogEntry__c.ShortMessage__c,
			LogEntry__c.CorrelationId__c,
			LogEntry__c.Message__c,
			LogEntry__c.StackTrace__c,
			LogEntry__c.ClassMethod__c
	};

	/**
	 * @description Setup URL of a custom setting's manage page — the page that lists the setting's configured
	 * values, which is what an administrator following "Open Log Settings" came to see. `{0}` takes the
	 * URL-encoded Classic address of the setting's data page.
	 */
	private static final String LOG_SETTINGS_MANAGE_PAGE_URL_TEMPLATE = '/lightning/setup/CustomSettings/page?address={0}';

	/**
	 * @description Classic address of a custom setting's data page, keyed (`{0}`) by the object's KEY PREFIX —
	 * the three characters its record ids begin with — and not by any record or entity id. Setup's own Manage
	 * link carries exactly this; an EntityDefinition DurableId in its place renders "Invalid Custom Setting
	 * id" (verified in the development org). Setup still routes its custom-setting pages through this Classic
	 * address, so the Lightning URL above carries it as an encoded parameter rather than replacing it.
	 */
	private static final String LIST_CUSTOM_SETTINGS_DATA_ADDRESS_TEMPLATE = '/setup/ui/listCustomSettingsData.apexp?id={0}';

	/**
	 * @description The number of source classes ranked into a summary's top-sources list — the ribbon shows a
	 * ranked, click-to-drill top three.
	 */
	private static final Integer TOP_SOURCE_LIMIT = 3;

	/**
	 * @description The number of Class.method groups the all-entries aggregate ranks for its top sources — a
	 * generous cap so the top three source classes stay accurate after the methods fold to their class name.
	 */
	private static final Integer ENTRY_SOURCE_CANDIDATE_CAP = 200;

	/**
	 * @description Allow-list mapping the flat-entries sort keys the LWC sends (the DTO_LogEntrySummary
	 * field names, and the executionEvent alias the context column resolves to) to real, sortable scalar
	 * fields. The logNumber key resolves to Name, the zero-padded auto-number the Log Number column renders
	 * as its record link. Long-text bodies are never sortable, so they are deliberately absent; an
	 * unrecognised key falls back to CreatedDate.
	 *
	 * @date July 2026
	 */
	private static final Map<String, SObjectField> ENTRY_SORT_FIELDS = new Map<String, SObjectField>
	{
			'createdDate' => LogEntry__c.CreatedDate,
			'logNumber' => LogEntry__c.Name,
			'level' => LogEntry__c.LogLevel__c,
			'className' => LogEntry__c.ClassMethod__c,
			'durationMs' => LogEntry__c.DurationMs__c,
			'shortMessage' => LogEntry__c.ShortMessage__c,
			'executionEvent' => LogEntry__c.ExecutionEvent__c,
			'correlationId' => LogEntry__c.CorrelationId__c
	};

	/**
	 * @description Maps the distinct-problems sort key the LWC sends (a DTO_LogProblem field name) to a
	 * typed ProblemSortField. An unrecognised key falls back to the default occurrence-count sort.
	 */
	private static final Map<String, ProblemSortField> PROBLEM_SORT_FIELDS = new Map<String, ProblemSortField>
	{
			'occurrenceCount' => ProblemSortField.OCCURRENCE_COUNT,
			'lastSeen' => ProblemSortField.LAST_SEEN,
			'level' => ProblemSortField.LEVEL,
			'logNumber' => ProblemSortField.LOG_NUMBER,
			'className' => ProblemSortField.CLASS_NAME,
			'shortMessage' => ProblemSortField.SHORT_MESSAGE,
			'executionEvent' => ProblemSortField.EXECUTION_EVENT
	};

	/**
	 * @description The sortable columns of the distinct-problems view. The wire request carries the
	 * matching DTO_LogProblem field name (resolved through PROBLEM_SORT_FIELDS); the default is
	 * OCCURRENCE_COUNT.
	 */
	private enum ProblemSortField
	{
		OCCURRENCE_COUNT,
		LAST_SEEN,
		LEVEL,
		LOG_NUMBER,
		CLASS_NAME,
		SHORT_MESSAGE,
		EXECUTION_EVENT
	}

	/**
	 * @description Returns a page of distinct problems — the flood-control fold of the LogEntry__c table.
	 * The distinct list is driven off in-window rollup: activity (so a problem first seen days ago but
	 * still firing in the window appears), each base fingerprint folding SUM(OccurrenceCount__c),
	 * MIN(CreatedDate) first-seen and MAX(LastModifiedDate) last-seen; the matching detail: samples are
	 * then fetched by key to carry the display fields. Sorted in Apex, paged in Apex. When the in-window
	 * rollup rows overflow the candidate cap the page flags totalsApproximate — the occurrence counts are
	 * best-effort rather than silently under-reported. Merged in beside them are the read-time derived
	 * problems — plain forensic rows grouped by signature — so the page also reports how that leg fared
	 * (derivedStatus), whether either leg's list is incomplete (capped), and the levels problem grouping is
	 * configured to cover (derivedLevelScope). The derived rows on the returned page are then relabelled
	 * with their newest occurrence's message, so the list names the same member the drawer resolves.
	 *
	 * @param requestJson The serialised DTO_Request; blank yields a default request.
	 *
	 * @return A DTO_LogProblemPage of folded problems with pagination metadata.
	 *
	 * @date June 2026, August 2026
	 *
	 * @example
	 * ```apex
	 * CTRL_LogConsole.DTO_LogProblemPage page = CTRL_LogConsole.getLogProblems(JSON.serialize(request));
	 * ```
	 */
	@AuraEnabled
	public static DTO_LogProblemPage getLogProblems(String requestJson)
	{
		DTO_Request request = parseRequest(requestJson);
		SEL_LogEntry selector = new SEL_LogEntry();

		RollupLeg rollupLeg = resolveRollupProblems(selector, request);
		List<DTO_LogProblem> problems = rollupLeg.problems;

		DerivedLeg derivedLeg = resolveDerivedSignatures(selector, request);
		for(SEL_LogEntry.DerivedSignature signature : derivedLeg.signatures)
		{
			problems.add(toDerivedProblem(signature));
		}

		ProblemSortField sortField = PROBLEM_SORT_FIELDS.containsKey(request.sortField) ? PROBLEM_SORT_FIELDS.get(request.sortField) : ProblemSortField.OCCURRENCE_COUNT;
		problems.sort(new ProblemComparator(sortField, request.sortAscending != true));
		DTO_LogProblemPage page = new DTO_LogProblemPage().paginate(problems, request, rollupLeg.resultsTruncated);
		relabelDerivedProblems(selector, page.records, toCriteria(request));
		page.totalsApproximate = rollupLeg.totalsApproximate || rollupLeg.degraded;
		page.derivedStatus = derivedLeg.status;
		page.capped = rollupLeg.resultsTruncated || rollupLeg.degraded || derivedLeg.capped;
		page.derivedLevelScope = derivedLeg.configuredLevels;
		return page;
	}

	/**
	 * @description Folds the fingerprinted rollup problems for the page, degrading gracefully when the rollup
	 * scan is non-selective at high volume: a QueryException yields an empty problem list rather than erroring
	 * the whole view, so the page still renders (rollup-only when only the derived leg is non-selective, empty
	 * when both are, always paired with the derived leg's own status).
	 *
	 * @param selector The shared selector.
	 * @param request The console request.
	 *
	 * @return The rollup problems with the truncation and best-effort flags.
	 *
	 * @example
	 * ```apex
	 * RollupLeg leg = resolveRollupProblems(selector, request);
	 * ```
	 */
	private static RollupLeg resolveRollupProblems(SEL_LogEntry selector, DTO_Request request)
	{
		RollupLeg leg = new RollupLeg();
		try
		{
			ScopedRollups scoped = resolveScopedRollups(selector, request);
			leg.totalsApproximate = scoped.totalsApproximate;

			List<String> allBases = new List<String>(scoped.foldByBase.keySet());
			leg.resultsTruncated = allBases.size() > PROBLEM_CANDIDATE_CAP;
			List<String> shownBases = new List<String>();
			for(Integer i = 0; i < Math.min(allBases.size(), PROBLEM_CANDIDATE_CAP); i++)
			{
				shownBases.add(allBases[i]);
			}

			Map<String, LogEntry__c> sampleByBase = findSamplesForBases(selector, shownBases);
			for(String base : shownBases)
			{
				LogEntry__c sample = sampleByBase.get(base);
				if(sample != null && sampleInScope(sample, request))
				{
					leg.problems.add(toProblem(sample, scoped.foldByBase.get(base)));
				}
			}
		}
		catch(QueryException degrade)
		{
			// A non-selective rollup scan at high volume degrades to an empty problem list rather than
			// erroring the view; the derived leg reports its own SKIPPED_NON_SELECTIVE status alongside.
			leg.degraded = true;
		}
		return leg;
	}

	/**
	 * @description Runs the read-time derived fold and returns its signatures, outcome and cap flag — the
	 * single-sourced derived leg shared by getLogProblems (which maps the signatures to problems) and
	 * getLogSummary (which folds them into the ribbon totals), so the list and the ribbon always agree. The
	 * leg is gated on ProblemGroupingDisabled__c (checked → DISABLED), suppressed by a free-text search term
	 * (→ SKIPPED_SEARCH), bounded by the ProblemGroupingLogLevels__c level scope (sharing no level with the
	 * console's own level filter → SKIPPED_LEVEL_SCOPE), floored by ProblemGroupingMinimumOccurrences__c, and
	 * degrades to rollup-only rather than breaking the page in two ways: the scan is sized first and declined
	 * when the window holds more rows than the fold may scan, and a non-selective scan is caught. Both report
	 * SKIPPED_NON_SELECTIVE. The pre-flight size check is what makes the leg safe at volume — the fold's
	 * failure there is a query-row limit exception, which Apex cannot catch, so catching alone would leave the
	 * view breaking on a wide enough window; the count is taken over the same effective level scope the fold
	 * reads, so the guard can never size a population the query it guards does not. The fold applies the
	 * request's window plus the shared execution-context, user, correlation and source scopes, so both legs
	 * stay filtered by the same rules. Its input — Fingerprint__c-null forensic rows — is disjoint from the rollup: counter
	 * rows, so the merge never double-counts. The fold runs SYSTEM_MODE with sharing bypassed, the shared
	 * posture of every console read.
	 *
	 * @param selector The shared selector.
	 * @param request The console request.
	 *
	 * @return The derived leg's signatures, status and cap flag.
	 *
	 * @example
	 * ```apex
	 * DerivedLeg leg = resolveDerivedSignatures(selector, request);
	 * ```
	 */
	private static DerivedLeg resolveDerivedSignatures(SEL_LogEntry selector, DTO_Request request)
	{
		DerivedLeg leg = new DerivedLeg();
		LogSetting__c setting = LOG_Engine.getLogSetting();
		// Parsed before any early return below: the page reports the configured scope on every status, not only
		// the one that skipped for a level mismatch, because the console names the scope to the reader whether
		// the fold ran, was switched off, or was suppressed by a search.
		leg.configuredLevels = parseDerivedLevelScope(setting.ProblemGroupingLogLevels__c);
		if(setting.ProblemGroupingDisabled__c == true)
		{
			leg.status = DERIVED_STATUS_DISABLED;
			return leg;
		}
		if(String.isNotBlank(request.searchTerm))
		{
			leg.status = DERIVED_STATUS_SKIPPED_SEARCH;
			return leg;
		}

		List<String> levels = resolveDerivedLevelScope(leg.configuredLevels, request.levels);
		if(levels.isEmpty())
		{
			leg.status = DERIVED_STATUS_SKIPPED_LEVEL_SCOPE;
			return leg;
		}
		Decimal configuredMinimum = setting.ProblemGroupingMinimumOccurrences__c;

		try
		{
			SEL_LogEntry.BrowseCriteria criteria = toCriteria(request);
			// Sized before it is issued: the fold's failure at volume is a query-row limit exception, which
			// no catch below can absorb, so the only protection is to decline the scan in advance. The count
			// takes the effective level scope the fold will read, never the request's own levels, so the two
			// always size the same population.
			if(selector.countFoldableRowsInWindow(criteria, levels) > DERIVED_SCAN_ROW_CEILING)
			{
				leg.status = DERIVED_STATUS_SKIPPED_NON_SELECTIVE;
				return leg;
			}
			leg.signatures = selector.foldDerivedSignaturesInWindow(criteria, PROBLEM_CANDIDATE_CAP, configuredMinimum?.intValue(), levels);
			leg.capped = leg.signatures.size() >= PROBLEM_CANDIDATE_CAP;
			leg.status = DERIVED_STATUS_COMPLETE;
		}
		catch(QueryException degrade)
		{
			leg.status = DERIVED_STATUS_SKIPPED_NON_SELECTIVE;
		}
		return leg;
	}

	/**
	 * @description Resolves the levels the derived fold is permitted to group: the configured
	 * ProblemGroupingLogLevels__c scope, narrowed to the levels the console asked for. The setting is a cost
	 * ceiling on the scan and not merely a display filter, so the console's level filter narrows WITHIN it and
	 * never widens it — asking the console for a level the setting withheld yields an empty scope, which the
	 * caller reports as its own status rather than an unexplained empty list. An empty or absent console filter
	 * means every level, so the configured scope stands unnarrowed.
	 *
	 * @param configured The already-parsed ProblemGroupingLogLevels__c scope, fallen back to the shipped default.
	 * @param requestedLevels The console's level filter; null or empty applies no narrowing.
	 *
	 * @return The levels the fold may group; empty when the two scopes share none.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * List<String> levels = resolveDerivedLevelScope(leg.configuredLevels, request.levels);
	 * ```
	 */
	private static List<String> resolveDerivedLevelScope(List<String> configured, List<String> requestedLevels)
	{
		if(requestedLevels == null || requestedLevels.isEmpty())
		{
			return configured;
		}

		Set<String> requested = new Set<String>();
		for(String level : requestedLevels)
		{
			requested.add(level?.trim()?.toUpperCase());
		}

		List<String> scope = new List<String>();
		for(String level : configured)
		{
			if(requested.contains(level))
			{
				scope.add(level);
			}
		}
		return scope;
	}

	/**
	 * @description Parses the configured ProblemGroupingLogLevels__c value into the levels the fold may scan,
	 * accepting either separator and normalising case and spacing. A value the framework does not recognise as
	 * a log level is dropped rather than passed through, so a typo narrows the scan instead of widening it; a
	 * value holding no recognisable level at all — including the null an upgraded setting record reads, since
	 * custom-setting data cannot ship in a package — falls back to the shipped default rather than grouping
	 * nothing, so one mistyped level degrades to the default behaviour instead of switching the feature off
	 * until somebody notices a permanently empty Problems list.
	 *
	 * @param configuredLevels The raw setting value.
	 *
	 * @return The recognised levels, or the shipped default when none are.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * List<String> configured = parseDerivedLevelScope('ERROR;WARN');
	 * ```
	 */
	private static List<String> parseDerivedLevelScope(String configuredLevels)
	{
		List<String> levels = new List<String>();
		for(String token : (configuredLevels ?? '').split(DERIVED_LEVEL_SEPARATOR))
		{
			String level = token.trim().toUpperCase();
			if(LOG_Engine.levelSeverityRank(level) >= 0 && !levels.contains(level))
			{
				levels.add(level);
			}
		}
		return levels.isEmpty() ? new List<String>(DEFAULT_DERIVED_LEVELS) : levels;
	}

	/**
	 * @description Maps a derived signature to a display-ready problem: no record id (opened through its
	 * JSON-encoded signature), the fold's occurrence count and first/last-seen, and the source split into
	 * class name and method (no line — the line is not part of the key). The label set here is the fold's
	 * own MAX(ShortMessage__c) projection — an aggregate cannot project the newest member's text — and is
	 * provisional: relabelDerivedProblems replaces it on the returned page with the newest occurrence's
	 * message, and it stands only for a problem whose rows vanished before that read.
	 *
	 * @param signature The folded derived signature.
	 *
	 * @return The derived DTO_LogProblem.
	 *
	 * @date June 2026, August 2026
	 *
	 * @example
	 * ```apex
	 * DTO_LogProblem problem = toDerivedProblem(signature);
	 * ```
	 */
	private static DTO_LogProblem toDerivedProblem(SEL_LogEntry.DerivedSignature signature)
	{
		DTO_LogProblem problem = new DTO_LogProblem();
		problem.source = SOURCE_DERIVED;
		problem.signature = serialiseDerivedSignature(signature, signature.label);
		problem.level = signature.logLevel;
		problem.shortMessage = signature.label;
		problem.exceptionType = signature.exceptionType;
		problem.className = LOG_Engine.extractClassName(signature.classMethod);
		problem.methodLine = buildDerivedMethodLine(signature.classMethod);
		problem.classMethod = signature.classMethod;
		problem.occurrenceCount = signature.occurrenceCount;
		problem.firstSeen = signature.firstSeen;
		problem.lastSeen = signature.lastSeen;
		return problem;
	}

	/**
	 * @description Rewrites each derived problem on the returned page with its newest occurrence's message —
	 * the member the drawer heading resolves — replacing the fold's MAX(ShortMessage__c) projection, which
	 * names the alphabetically-last message in the group and so can label a row with a member neither newest
	 * nor commonest. One batched selector read pins every page signature's newest instant; each problem takes
	 * the first returned row matching its identity (rows arrive newest first, so a same-second tie resolves
	 * to the same row the drawer opens), and its signature JSON is re-serialised with the final label so the
	 * drawer's purge fallback shows the text that was clicked. A problem whose rows vanished between the fold
	 * and this read is simply not matched and keeps the fold's label. Page-scoped on purpose: the fold can
	 * return up to PROBLEM_CANDIDATE_CAP signatures, far too many to pin into one query, so the sort ran on
	 * the fold's own projection and only the rows a reader actually sees are resolved to their newest text.
	 *
	 * @param selector The shared selector.
	 * @param pageRecords The page's problems; only derived rows are touched.
	 * @param criteria The browse criteria scoping the read to the same rows the fold covered.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * relabelDerivedProblems(selector, page.records, toCriteria(request));
	 * ```
	 */
	private static void relabelDerivedProblems(SEL_LogEntry selector, List<DTO_LogProblem> pageRecords, SEL_LogEntry.BrowseCriteria criteria)
	{
		List<DTO_LogProblem> derivedProblems = new List<DTO_LogProblem>();
		List<SEL_LogEntry.DerivedSignature> signatures = new List<SEL_LogEntry.DerivedSignature>();
		for(DTO_LogProblem problem : pageRecords)
		{
			if(problem.source == SOURCE_DERIVED && problem.lastSeen != null)
			{
				derivedProblems.add(problem);
				SEL_LogEntry.DerivedSignature signature = new SEL_LogEntry.DerivedSignature(problem.exceptionType, problem.classMethod, problem.level);
				signature.lastSeen = problem.lastSeen;
				signatures.add(signature);
			}
		}
		if(derivedProblems.isEmpty())
		{
			return;
		}
		List<LogEntry__c> representatives = selector.findDerivedRepresentatives(signatures, criteria);
		for(Integer position = 0; position < derivedProblems.size(); position++)
		{
			DTO_LogProblem problem = derivedProblems[position];
			for(LogEntry__c representative : representatives)
			{
				if(representative.ExceptionType__c == problem.exceptionType && representative.ClassMethod__c == problem.classMethod && representative.LogLevel__c == problem.level)
				{
					problem.shortMessage = representative.ShortMessage__c;
					break;
				}
			}
			problem.signature = serialiseDerivedSignature(signatures[position], problem.shortMessage);
		}
	}

	/**
	 * @description Serialises the signature a derived problem is opened through — its three identity fields
	 * plus the display label the drawer falls back to when every occurrence has been purged. Single-sourced
	 * by toDerivedProblem and relabelDerivedProblems so the JSON the drawer decodes always carries the label
	 * the list actually showed.
	 *
	 * @param signature The derived signature whose identity fields key the group.
	 * @param label The display label to carry for the purge fallback.
	 *
	 * @return The JSON-encoded signature.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * problem.signature = serialiseDerivedSignature(signature, problem.shortMessage);
	 * ```
	 */
	private static String serialiseDerivedSignature(SEL_LogEntry.DerivedSignature signature, String label)
	{
		return JSON.serialize(new Map<String, Object>
		{
				'exceptionType' => signature.exceptionType,
				'classMethod' => signature.classMethod,
				'logLevel' => signature.logLevel,
				'label' => label
		});
	}

	/**
	 * @description Returns a page of flat forensic log entries (detail: samples and plain rows),
	 * excluding the rollup: counter rows. Mirrors the canonical paginated-list shape: blank-guard
	 * deserialise, resolve the sort field through the allow-list (CreatedDate fallback), default the
	 * page size and number, then map the selector page to display-ready DTOs.
	 *
	 * @param requestJson The serialised DTO_Request; blank yields a default request.
	 *
	 * @return A DTO_LogEntryPage of forensic rows with pagination metadata.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * CTRL_LogConsole.DTO_LogEntryPage page = CTRL_LogConsole.getLogEntries(JSON.serialize(request));
	 * ```
	 */
	@AuraEnabled
	public static DTO_LogEntryPage getLogEntries(String requestJson)
	{
		DTO_Request request = parseRequest(requestJson);
		SEL_LogEntry.BrowseCriteria criteria = toCriteria(request);
		SEL_LogEntry selector = new SEL_LogEntry();

		SObjectField sortField = ENTRY_SORT_FIELDS.containsKey(request.sortField) ? ENTRY_SORT_FIELDS.get(request.sortField) : LogEntry__c.CreatedDate;
		Boolean descending = request.sortAscending != true;

		Boolean resultsTruncated = false;
		QRY_Builder.QueryPage page;
		if(String.isNotBlank(request.searchTerm))
		{
			Set<Id> matchedIds = resolveSearchMatchedIds(selector, request, criteria);
			resultsTruncated = matchedIds.size() >= PROBLEM_CANDIDATE_CAP;
			page = selector.findSortedPageByIds(matchedIds, sortField, descending, request.resolvedPageNumber(), request.resolvedPageSize());
		}
		else
		{
			page = selector.findEntriesFiltered(criteria, sortField, descending, request.resolvedPageNumber(), request.resolvedPageSize());
		}

		List<DTO_LogEntrySummary> records = new List<DTO_LogEntrySummary>();
		for(SObject record : page.records)
		{
			records.add(toEntrySummary((LogEntry__c)record));
		}

		DTO_LogEntryPage result = new DTO_LogEntryPage();
		result.records = records;
		result.totalCount = page.totalRecords;
		result.pageNumber = page.pageNumber;
		result.totalPages = page.totalPages;
		result.hasMorePages = page.hasMorePages;
		result.resultsTruncated = resultsTruncated;
		return result;
	}

	/**
	 * @description Returns a scope summary that folds the in-window rollup activity (and the matching
	 * samples, for the source class) into total occurrences, a per-level breakdown, and the top source
	 * class with its share of occurrences. Folds the same rollup scope as getLogProblems (via the shared
	 * resolveScopedRollups), so the summary spans the whole scope regardless of the current problems page,
	 * and flags totalsApproximate when the rollup candidate set overflowed its cap — the headline total is
	 * best-effort rather than silently under-reported. The read-time derived leg folds into the same running
	 * totals over the identical scope getLogProblems merges it into, so the ribbon and the list always agree,
	 * and totalsApproximateCause names which kind of gap left the totals best-effort.
	 *
	 * @param requestJson The serialised DTO_Request; blank yields a default request.
	 *
	 * @return A DTO_LogSummary over the requested scope.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * CTRL_LogConsole.DTO_LogSummary summary = CTRL_LogConsole.getLogSummary(JSON.serialize(request));
	 * ```
	 */
	@AuraEnabled
	public static DTO_LogSummary getLogSummary(String requestJson)
	{
		DTO_Request request = parseRequest(requestJson);
		SEL_LogEntry selector = new SEL_LogEntry();

		// The running totals live on the DTO from the start rather than in locals copied across at the end, so
		// both legs add to one place and the derived leg's identical accumulation can be a single call.
		DTO_LogSummary summary = new DTO_LogSummary();
		summary.totalOccurrences = 0;
		summary.distinctCount = 0;
		Boolean rollupTruncated = false;
		Boolean legAbsent = false;
		SummaryTallies tallies = new SummaryTallies();

		try
		{
			ScopedRollups scoped = resolveScopedRollups(selector, request);
			rollupTruncated = scoped.totalsApproximate;
			Map<String, LogEntry__c> sampleByBase = findSamplesForBases(selector, scoped.foldByBase.keySet());
			for(String base : scoped.foldByBase.keySet())
			{
				LogEntry__c sample = sampleByBase.get(base);
				if(sample == null || !sampleInScope(sample, request))
				{
					continue;
				}
				Integer occurrences = (scoped.foldByBase.get(base).occurrenceTotal ?? 0).intValue();
				summary.totalOccurrences += occurrences;
				summary.distinctCount++;
				accumulateLevel(tallies.byLevel, sample.LogLevel__c, occurrences);
				addToCount(tallies.bySource, LOG_Engine.extractClassName(sample.ClassMethod__c), occurrences);
			}
		}
		catch(QueryException degrade)
		{
			// A non-selective rollup scan degrades the summary to the derived leg only rather than erroring;
			// the totals are then best-effort — and the rollup contribution is absent rather than trimmed, which
			// is what makes this PARTIAL and not TRUNCATED.
			legAbsent = true;
		}

		DerivedLeg derivedLeg = resolveDerivedSignatures(selector, request);
		// Four causes feed one flag, and they are not the same kind of gap: a capped candidate set trims the
		// totals to the most recent groups, while a leg that never ran drops its contribution entirely. The
		// console has to tell them apart to say anything true about the number, so the cause travels with it.
		legAbsent = legAbsent || DERIVED_STATUS_SKIPPED_NON_SELECTIVE.equals(derivedLeg.status);
		Boolean truncated = rollupTruncated || derivedLeg.capped;
		accumulateDerivedSignatures(derivedLeg, summary, tallies);

		summary.totalsApproximate = legAbsent || truncated;
		summary.totalsApproximateCause = legAbsent ? TOTALS_CAUSE_PARTIAL : (truncated ? TOTALS_CAUSE_TRUNCATED : null);
		summary.perLevel = tallies.byLevel.values();
		summary.topSources = rankTopSources(tallies.bySource, summary.totalOccurrences, TOP_SOURCE_LIMIT);
		return summary;
	}

	/**
	 * @description Adds the derived fold's signatures to a running summary: one distinct problem per signature,
	 * its occurrences into the totals, and its level and source into the per-level and top-source tallies. The
	 * rollup leg above accumulates identically from its own rows; this is the derived half of the same sum.
	 *
	 * @param derivedLeg The resolved derived leg, whose signatures are empty when the fold did not run.
	 * @param summary The summary being built, whose running totals this adds to.
	 * @param tallies The per-level and per-source tallies this adds to.
	 *
	 * @example
	 * ```apex
	 * accumulateDerivedSignatures(derivedLeg, summary, tallies);
	 * ```
	 */
	private static void accumulateDerivedSignatures(DerivedLeg derivedLeg, DTO_LogSummary summary, SummaryTallies tallies)
	{
		for(SEL_LogEntry.DerivedSignature signature : derivedLeg.signatures)
		{
			Integer occurrences = signature.occurrenceCount ?? 0;
			summary.totalOccurrences += occurrences;
			summary.distinctCount++;
			accumulateLevel(tallies.byLevel, signature.logLevel, occurrences);
			addToCount(tallies.bySource, LOG_Engine.extractClassName(signature.classMethod), occurrences);
		}
	}

	/**
	 * @description Returns the namespace prefix an Apex snippet must carry to compile in this org: whichever
	 * namespace this class itself resolves to, with a dot after it. That is the package namespace in a managed
	 * subscriber org, and the ORG's own namespace when the source is deployed unmanaged into a namespaced org —
	 * which is the prefix that compiles there, so "unmanaged" is not the dividing line. Only an org with no
	 * namespace at all yields an empty string. The console generates copy-to-compile Apex for tagging a problem,
	 * so a hardcoded prefix would hand half the audience a snippet that fails on paste — and the failure is
	 * invisible in a no-namespace development org, where both forms compile identically. Cacheable because a
	 * namespace cannot change for the life of an org. This is the DOT form deliberately: the zero-argument
	 * overload on UTIL_System returns the double-underscore metadata form, which is correct for metadata names
	 * and does not compile in Apex.
	 *
	 * @return The Apex-form namespace prefix, or an empty string when this class resolves to no namespace at all
	 * (a no-namespace deploy of the source).
	 *
	 * @example
	 * ```apex
	 * String prefix = CTRL_LogConsole.getApexNamespacePrefix();
	 * ```
	 */
	@AuraEnabled(Cacheable=true)
	public static String getApexNamespacePrefix()
	{
		return UTIL_System.getManagedPackageNamespacePrefix('.');
	}

	/**
	 * @description Returns the Setup URL of the Log Settings page — the custom setting's own manage page,
	 * which shows the values an administrator came to read and change, rather than the Custom Settings index
	 * that lists every setting in the org and leaves them to find this one. Setup keys that page by the
	 * object's key prefix, which no client can know, so it is resolved here through the request-cached
	 * describe: the key prefix is assigned when the object is created and cannot change afterwards, which is
	 * also why this is cacheable. Namespace-safe by construction — a describe of the compiled SObjectType
	 * answers for `LogSetting__c` and `kern__LogSetting__c` alike, where a hardcoded prefix would be wrong in
	 * one of the two orgs and, being a URL, would fail silently.
	 *
	 * @return The Setup URL of the Log Settings manage page.
	 *
	 * @example
	 * ```apex
	 * String settingsUrl = CTRL_LogConsole.getLogSettingsSetupUrl();
	 * ```
	 */
	@AuraEnabled(Cacheable=true)
	public static String getLogSettingsSetupUrl()
	{
		String dataPageAddress = String.format(LIST_CUSTOM_SETTINGS_DATA_ADDRESS_TEMPLATE,
				new List<String> {UTIL_SObjectDescribe.getDescribe(LogSetting__c.SObjectType).getDescribe().getKeyPrefix()});

		return String.format(LOG_SETTINGS_MANAGE_PAGE_URL_TEMPLATE, new List<String> {EncodingUtil.urlEncode(dataPageAddress, 'UTF-8')});
	}

	/**
	 * @description Returns the all-entries ribbon summary: the total forensic row count in the window, a
	 * per-level row-count breakdown (so the total always equals the sum of the per-level cards), and the top
	 * three source classes ranked by forensic row count. With no search term it folds a bind-only aggregate over
	 * the forensic rows (OccurrenceCount__c null) across the whole window, so the ribbon spans the window even
	 * though the entries list loads incrementally by infinite scroll. When a free-text search is active it
	 * aggregates over the same matched-id set the entries table pages (SOQL short-message/correlation ∪ SOSL
	 * body, both correlation-scoped), so the ribbon totals equal the table for every term, including body-only
	 * matches. A window holding more rows than ENTRY_SUMMARY_SCAN_ROW_CEILING declines the breakdown before the
	 * aggregates run — they spend query rows on every row they scan, and the exception past the governor cannot
	 * be caught — and answers with the declined flag and the exact total the pre-flight count measured.
	 *
	 * @param requestJson The serialised DTO_Request; blank yields a default request.
	 *
	 * @return A DTO_EntrySummary over the requested scope; over a too-large window, the declined summary
	 * carrying the exact total alone.
	 *
	 * @date July 2026, August 2026
	 *
	 * @example
	 * ```apex
	 * CTRL_LogConsole.DTO_EntrySummary summary = CTRL_LogConsole.getEntrySummary(JSON.serialize(request));
	 * ```
	 */
	@AuraEnabled
	public static DTO_EntrySummary getEntrySummary(String requestJson)
	{
		DTO_Request request = parseRequest(requestJson);
		SEL_LogEntry.BrowseCriteria criteria = toCriteria(request);
		SEL_LogEntry selector = new SEL_LogEntry();

		SEL_LogEntry.EntryAggregate aggregate;
		if(String.isNotBlank(request.searchTerm))
		{
			// Aggregate over the SAME matched-id set the entries table pages, so the ribbon totals equal the
			// table for every term — including body-only matches the short-message/correlation LIKE aggregate
			// would miss.
			aggregate = selector.summariseEntriesByIds(resolveSearchMatchedIds(selector, request, criteria), ENTRY_SOURCE_CANDIDATE_CAP);
		}
		else
		{
			// Counted before it is scanned: the two windowed aggregates spend query rows on every row they scan,
			// so past the ceiling the breakdown is declined up front — and the count that declines it measured
			// the exact total, so the ribbon still states how many entries the range holds. The searched branch
			// above needs no guard: its aggregates run over the bounded matched-id set.
			Integer scanSize = selector.countEntriesInWindow(criteria);
			if(scanSize > ENTRY_SUMMARY_SCAN_ROW_CEILING)
			{
				return buildDeclinedEntrySummary(scanSize);
			}
			aggregate = selector.summariseEntriesInWindow(criteria, ENTRY_SOURCE_CANDIDATE_CAP);
		}

		Integer totalRows = 0;
		List<DTO_EntryLevelCount> perLevel = new List<DTO_EntryLevelCount>();
		for(SEL_LogEntry.LevelRowCount levelCount : aggregate.levelCounts)
		{
			DTO_EntryLevelCount entryLevel = new DTO_EntryLevelCount();
			entryLevel.level = levelCount.logLevel;
			entryLevel.rowCount = levelCount.rowCount ?? 0;
			perLevel.add(entryLevel);
			totalRows += entryLevel.rowCount;
		}

		Map<String, Integer> rowsBySource = new Map<String, Integer>();
		for(SEL_LogEntry.SourceRowCount sourceCount : aggregate.sourceCounts)
		{
			addToCount(rowsBySource, LOG_Engine.extractClassName(sourceCount.classMethod), sourceCount.rowCount ?? 0);
		}

		DTO_EntrySummary summary = new DTO_EntrySummary();
		summary.totalRows = totalRows;
		summary.perLevel = perLevel;
		summary.topSources = rankTopSources(rowsBySource, totalRows, TOP_SOURCE_LIMIT);
		return summary;
	}

	/**
	 * @description Builds the ribbon summary for a window whose breakdown was declined: the exact total the
	 * pre-flight count measured, empty per-level and top-source lists (empty, never null — the console reads
	 * both collections), and the declined flag the console renders the withheld breakdown from.
	 *
	 * @param totalRows The exact forensic row count the pre-flight count measured.
	 *
	 * @return The declined DTO_EntrySummary.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * DTO_EntrySummary declined = buildDeclinedEntrySummary(48000);
	 * ```
	 */
	private static DTO_EntrySummary buildDeclinedEntrySummary(Integer totalRows)
	{
		DTO_EntrySummary summary = new DTO_EntrySummary();
		summary.totalRows = totalRows;
		summary.perLevel = new List<DTO_EntryLevelCount>();
		summary.topSources = new List<DTO_SourceCount>();
		summary.declined = true;
		return summary;
	}

	/**
	 * @description Returns the heavy forensic detail for a single log entry: the full message, stack
	 * trace, unwrapped context JSON, the metadata grid fields (including the originating user's resolved
	 * display name), the parsed governor-limit bars, and whether a registered async chain shares the
	 * entry's correlation. Returns null for a null Id or a row that no longer exists.
	 *
	 * @param entryId The LogEntry__c Id to load.
	 *
	 * @return A DTO_LogEntryDetail, or null when the Id is null or the row is not found.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getLogEntryDetail(entryId);
	 * ```
	 */
	@AuraEnabled
	public static DTO_LogEntryDetail getLogEntryDetail(Id entryId)
	{
		if(entryId == null)
		{
			return null;
		}
		LogEntry__c row = new SEL_LogEntry().findByIdForConsole(entryId);
		return row == null ? null : toDetail(row);
	}

	/**
	 * @description Builds the full detail DTO from a forensic row — message, stack, unwrapped context,
	 * two-line source, resolved user, correlation/transaction lineage, chain existence, and the parsed
	 * governor-limit bars. Single-sourced so the by-id lookup (getLogEntryDetail) and the derived-signature
	 * lookup (getDerivedProblemDetail) render an identical drawer.
	 *
	 * @param row The forensic row, selected with the console field set.
	 *
	 * @return The display-ready DTO_LogEntryDetail.
	 *
	 * @example
	 * ```apex
	 * DTO_LogEntryDetail detail = toDetail(row);
	 * ```
	 */
	private static DTO_LogEntryDetail toDetail(LogEntry__c row)
	{
		DTO_LogEntryDetail detail = new DTO_LogEntryDetail();
		detail.id = row.Id;
		detail.logNumber = row.Name;
		detail.level = row.LogLevel__c;
		detail.shortMessage = row.ShortMessage__c;
		detail.exceptionType = row.ExceptionType__c;
		detail.message = row.Message__c;
		detail.stackTrace = row.StackTrace__c;
		detail.contextJson = unwrapContext(row.ContextData__c);
		detail.className = LOG_Engine.extractClassName(row.ClassMethod__c);
		detail.methodLine = buildMethodLine(row);
		detail.classMethod = row.ClassMethod__c;
		detail.executionEvent = row.ExecutionEvent__c;
		detail.userId = row.UserId__c;
		detail.userName = resolveUserName(row.UserId__c);
		detail.correlationId = row.CorrelationId__c;
		detail.transactionId = row.TransactionId__c;
		detail.parentTransactionId = row.ParentTransactionId__c;
		detail.chainExists = new SEL_AsyncChainExecution().existsByCorrelationId(row.CorrelationId__c);
		detail.recordId = row.RecordId__c;
		detail.firstSeen = row.CreatedDate;
		detail.lastSeen = row.LastModifiedDate;
		detail.durationMs = row.DurationMs__c;
		detail.limitBars = parseLimitBars(row.Limits__c);
		return detail;
	}

	/**
	 * @description Opens a derived problem: resolves the most-recent forensic row matching the JSON-encoded
	 * signature within the request window and returns its full detail, so a derived problem (which has no
	 * record id) opens the same drawer as a fingerprinted one. When every occurrence has been purged between
	 * the fold and the click, falls back to a detail carrying just what the signature knows (label, level,
	 * exception type, source) so the drawer still renders rather than erroring. The signature is client-supplied
	 * and therefore never trusted to be the object the console encoded: anything that is not a JSON object —
	 * malformed text, an array, a bare scalar — or that carries no log level (a field every signature the fold
	 * writes is keyed on) returns null exactly as a blank signature does, and a member that is not a string is
	 * read as text rather than throwing on a cast.
	 *
	 * @param signatureJson The JSON-encoded derived signature (exceptionType, classMethod, logLevel) from the
	 * problem's `signature` field; blank, not a JSON object, or without a logLevel returns null.
	 * @param requestJson The serialised DTO_Request, consulted for the window bounds and the shared
	 * execution-context, user, correlation and source scopes; blank yields a default.
	 *
	 * @return The representative row's detail, a label-only fallback on purge, or null for a blank or
	 * malformed signature.
	 *
	 * @example
	 * ```apex
	 * CTRL_LogConsole.DTO_LogEntryDetail detail = CTRL_LogConsole.getDerivedProblemDetail(signatureJson, requestJson);
	 * ```
	 */
	@AuraEnabled
	public static DTO_LogEntryDetail getDerivedProblemDetail(String signatureJson, String requestJson)
	{
		if(String.isBlank(signatureJson))
		{
			return null;
		}
		Object parsed;
		try
		{
			parsed = JSON.deserializeUntyped(signatureJson);
		}
		catch(JSONException malformed)
		{
			// Text that is not JSON at all is answered the same way a blank signature is: the drawer already
			// handles a null, and an uncaught deserialise would surface a raw platform error on a click the
			// console itself offered.
			return null;
		}
		if(!(parsed instanceof Map<String, Object>))
		{
			return null;
		}
		Map<String, Object> decoded = (Map<String, Object>)parsed;
		String logLevel = readSignatureText(decoded, 'logLevel');
		if(String.isBlank(logLevel))
		{
			// Every signature the fold emits carries its level — it is one of the three fields the group is keyed on,
			// and the drawer builds the tagging snippet from it — so one without a level was not written by the fold,
			// and answering it with a level-less fallback would hand the drawer a detail it cannot render.
			return null;
		}
		SEL_LogEntry.DerivedSignature signature = new SEL_LogEntry.DerivedSignature(
				readSignatureText(decoded, 'exceptionType'),
				readSignatureText(decoded, 'classMethod'),
				logLevel
		);
		SEL_LogEntry.BrowseCriteria criteria = toCriteria(parseRequest(requestJson));
		SEL_LogEntry selector = new SEL_LogEntry();
		LogEntry__c representative = selector.findDerivedRepresentative(signature, criteria);
		// findDerivedRepresentative locates the row on its identity fields (CreatedDate only); re-fetch it
		// through the full console field set so the drawer renders identically to the by-id path.
		LogEntry__c full = representative == null ? null : selector.findByIdForConsole(representative.Id);
		return full != null ? toDetail(full) : buildDerivedFallbackDetail(decoded);
	}

	/**
	 * @description Reads one text member of a decoded derived signature. The signature crosses the wire under
	 * the client's control, so a member that is not a string is rendered as text rather than thrown on: an
	 * absent or null member reads as null, and any other value reads as its String.valueOf form, which is what
	 * keeps a hand-edited signature a rendered detail — the representative's, or the label-only fallback — instead
	 * of a raw platform error in the drawer.
	 *
	 * @param decoded The decoded signature map.
	 * @param key The member to read.
	 *
	 * @return The member as text, or null when it is absent or null.
	 *
	 * @example
	 * ```apex
	 * String logLevel = readSignatureText(decoded, 'logLevel');
	 * ```
	 */
	private static String readSignatureText(Map<String, Object> decoded, String key)
	{
		Object value = decoded.get(key);
		return value == null ? null : String.valueOf(value);
	}

	/**
	 * @description Builds a label-only detail for a derived problem whose every occurrence was purged between
	 * the fold and the click: the drawer still renders the signature's label, level, exception type and
	 * source, just without the forensic body of a live row.
	 *
	 * @param decoded The decoded signature map (exceptionType, classMethod, logLevel, label).
	 *
	 * @return The fallback detail.
	 *
	 * @example
	 * ```apex
	 * DTO_LogEntryDetail detail = buildDerivedFallbackDetail(decoded);
	 * ```
	 */
	private static DTO_LogEntryDetail buildDerivedFallbackDetail(Map<String, Object> decoded)
	{
		String classMethod = readSignatureText(decoded, 'classMethod');
		DTO_LogEntryDetail detail = new DTO_LogEntryDetail();
		// An empty list, never left null: the drawer reads this collection to decide whether to draw the limit
		// section, and a null reaches the client as an absent field that takes the whole pane down on a click
		// the console itself offered. The by-id path always sends a list, so this one must too.
		detail.limitBars = new List<DTO_LimitBar>();
		detail.level = readSignatureText(decoded, 'logLevel');
		detail.shortMessage = readSignatureText(decoded, 'label');
		detail.exceptionType = readSignatureText(decoded, 'exceptionType');
		detail.className = LOG_Engine.extractClassName(classMethod);
		detail.methodLine = buildDerivedMethodLine(classMethod);
		detail.classMethod = classMethod;
		return detail;
	}

	/**
	 * @description The derived-problem method location: the method segment of a Class.method source with no
	 * line number (the line is not part of the derived key). Null when the source has no method segment.
	 *
	 * @param classMethod The Class.method source, or null.
	 *
	 * @return The method segment, or null.
	 *
	 * @example
	 * ```apex
	 * String methodLine = buildDerivedMethodLine('PaymentGateway.capture');
	 * ```
	 */
	private static String buildDerivedMethodLine(String classMethod)
	{
		return String.isNotBlank(classMethod) && classMethod.contains('.') ? classMethod.substringAfter('.') : null;
	}

	/**
	 * @description Returns the correlated execution trace for an entry: the forensic rows sharing the
	 * entry's CorrelationId__c, ordered first-to-last, each marked with whether it is the opened entry.
	 * When the entry carries no correlation the trace is the single opened entry, so the chain is always
	 * present. Each node carries the raw execution context and CreatedDate so the LWC renders the hop
	 * label and the relative offset in the viewer's own locale and timezone.
	 *
	 * @param entryId The opened LogEntry__c Id.
	 *
	 * @return A trace page: the ordered trace nodes (a single-self node when uncorrelated, empty when the
	 * Id is null or resolves to no row) and whether the trace was truncated at the row cap.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * CTRL_LogConsole.DTO_TracePage page = CTRL_LogConsole.getCorrelatedTrace(entryId);
	 * ```
	 */
	@AuraEnabled
	public static DTO_TracePage getCorrelatedTrace(Id entryId)
	{
		DTO_TracePage page = new DTO_TracePage();
		page.entries = new List<DTO_TraceEntry>();
		page.truncated = false;
		if(entryId == null)
		{
			return page;
		}
		LogEntry__c opened = new SEL_LogEntry().findByIdForConsole(entryId);
		if(opened == null)
		{
			return page;
		}
		if(String.isBlank(opened.CorrelationId__c))
		{
			page.entries.add(toTraceEntry(opened, entryId));
			return page;
		}
		List<LogEntry__c> hops = new SEL_LogEntry().findByCorrelationIdOrdered(opened.CorrelationId__c);
		page.truncated = hops.size() > SEL_LogEntry.CORRELATION_TRACE_ROW_CAP;
		Integer boundedCount = page.truncated ? SEL_LogEntry.CORRELATION_TRACE_ROW_CAP : hops.size();
		for(Integer index = 0; index < boundedCount; index++)
		{
			page.entries.add(toTraceEntry(hops[index], entryId));
		}
		return page;
	}

	/**
	 * @description Deserialises the request JSON with a blank guard, so a null or empty payload yields a
	 * default request rather than throwing.
	 *
	 * @param requestJson The serialised DTO_Request, or null/blank.
	 *
	 * @return The deserialised DTO_Request, or a new default DTO_Request for blank input.
	 *
	 * @example
	 * ```apex
	 * DTO_Request request = parseRequest(requestJson);
	 * ```
	 */
	private static DTO_Request parseRequest(String requestJson)
	{
		return String.isBlank(requestJson) ? new DTO_Request() : (DTO_Request)JSON.deserialize(requestJson, DTO_Request.class);
	}

	/**
	 * @description Maps the wire request to a selector BrowseCriteria, resolving the date window: an
	 * explicit custom ISO-8601 range overrides the preset; otherwise the preset windowMinutes (default
	 * 24 hours) is subtracted from now.
	 *
	 * @param request The wire request.
	 *
	 * @return The selector filter criteria.
	 *
	 * @example
	 * ```apex
	 * SEL_LogEntry.BrowseCriteria criteria = toCriteria(request);
	 * ```
	 */
	private static SEL_LogEntry.BrowseCriteria toCriteria(DTO_Request request)
	{
		SEL_LogEntry.BrowseCriteria criteria = new SEL_LogEntry.BrowseCriteria();
		criteria.levels = request.levels;
		criteria.executionEvents = request.executionEvents;
		criteria.userId = request.userId;
		criteria.searchTerm = request.searchTerm;
		criteria.correlationId = request.correlationId;
		criteria.classMethod = request.classMethod;
		if(String.isNotBlank(request.customStart) && String.isNotBlank(request.customEnd))
		{
			criteria.windowStart = UTIL_Date.dateTimeFromIso8601(request.customStart);
			criteria.windowEnd = UTIL_Date.dateTimeFromIso8601(request.customEnd);
		}
		else
		{
			Integer windowMinutes = request.windowMinutes != null && request.windowMinutes > 0 ? request.windowMinutes : DEFAULT_WINDOW_MINUTES;
			criteria.windowStart = Datetime.now().addMinutes(-windowMinutes);
			criteria.windowEnd = Datetime.now();
		}
		return criteria;
	}

	/**
	 * @description Whether a distinct-view detail sample satisfies the request's free-text search, its
	 * correlation deep-link and its source filter. The rollup: counters carry none of those three values,
	 * so the distinct view applies all of them here against the sample's own fields. A blank term, a blank
	 * correlation id and a blank source each impose no constraint. The term is matched case-insensitively
	 * across the single-sourced SAMPLE_SEARCH_FIELDS list, which reconciles this in-memory matcher's
	 * coverage with the All-entries search legs.
	 *
	 * @param sample The detail sample row.
	 * @param request The wire request carrying searchTerm, correlationId and classMethod.
	 *
	 * @return True when the sample is in scope for the current search, deep-link and source filter.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * Boolean shown = sampleInScope(sample, request);
	 * ```
	 */
	private static Boolean sampleInScope(LogEntry__c sample, DTO_Request request)
	{
		if(String.isNotBlank(request.correlationId) && sample.CorrelationId__c != request.correlationId)
		{
			return false;
		}
		if(String.isNotBlank(request.classMethod) && sample.ClassMethod__c != request.classMethod)
		{
			return false;
		}
		if(String.isBlank(request.searchTerm))
		{
			return true;
		}
		String needle = request.searchTerm.toLowerCase();
		for(SObjectField field : SAMPLE_SEARCH_FIELDS)
		{
			String haystack = (String)sample.get(field);
			if(haystack != null && haystack.toLowerCase().contains(needle))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Resolves the in-window rollup fold for a request — the shared opening move of
	 * getLogProblems and getLogSummary, single-sourced so the scoping rule and the overflow signal can
	 * never drift between the two endpoints. The rollup: counters carry no message text, correlation id or
	 * source, so the free-text search, the correlation deep-link and the source filter must NOT filter the
	 * rollup fold (that would zero out every signature); all three are applied later, in-memory, against
	 * the detail samples where the text, correlation and source live. The selector fetches one probe row
	 * beyond ROLLUP_CANDIDATE_CAP: when it arrives, the window overflowed the cap, the probe row is
	 * discarded (only cap rows fold) and the result flags totalsApproximate so no shape built on the fold
	 * reports best-effort totals as exact.
	 *
	 * @param selector The log-entry selector.
	 * @param request The wire request whose window and filters scope the fold.
	 *
	 * @return The per-base fold and the best-effort flag.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * ScopedRollups scoped = resolveScopedRollups(selector, request);
	 * ```
	 */
	private static ScopedRollups resolveScopedRollups(SEL_LogEntry selector, DTO_Request request)
	{
		SEL_LogEntry.BrowseCriteria rollupCriteria = toCriteria(request);
		rollupCriteria.searchTerm = null;
		rollupCriteria.correlationId = null;
		rollupCriteria.classMethod = null;

		List<LogEntry__c> rollupRows = selector.findRollupRowsInWindow(rollupCriteria, ROLLUP_CANDIDATE_CAP);

		ScopedRollups scoped = new ScopedRollups();
		scoped.totalsApproximate = rollupRows.size() > ROLLUP_CANDIDATE_CAP;
		if(scoped.totalsApproximate)
		{
			rollupRows.remove(ROLLUP_CANDIDATE_CAP);
		}
		scoped.foldByBase = foldRollups(rollupRows);
		return scoped;
	}

	/**
	 * @description Fetches the detail: samples for a set of base fingerprints and keys them back by base —
	 * the shared sample-map move of getLogProblems (capped bases) and getLogSummary (every folded base).
	 * Key composition and decoding go through the TRG_PersistLogEntry codec, so this layer never parses
	 * the persisted key format.
	 *
	 * @param selector The log-entry selector.
	 * @param bases The base fingerprints whose detail samples to fetch.
	 *
	 * @return The detail sample per base fingerprint.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * Map<String, LogEntry__c> sampleByBase = findSamplesForBases(selector, shownBases);
	 * ```
	 */
	private static Map<String, LogEntry__c> findSamplesForBases(SEL_LogEntry selector, Iterable<String> bases)
	{
		Set<String> detailKeys = new Set<String>();
		for(String base : bases)
		{
			detailKeys.add(TRG_PersistLogEntry.buildDetailKey(base));
		}
		Map<String, LogEntry__c> sampleByBase = new Map<String, LogEntry__c>();
		for(LogEntry__c sample : selector.findSamplesByBaseFingerprints(detailKeys))
		{
			sampleByBase.put(TRG_PersistLogEntry.decodeBaseFromDetailKey(sample.Fingerprint__c), sample);
		}
		return sampleByBase;
	}

	/**
	 * @description Resolves the dual-leg free-text match: the SOQL leg (short message ∪ correlation id,
	 * immediate, no search-index lag) merged with the SOSL body leg (message/stack, via the search index),
	 * both correlation-scoped and bounded at the single PROBLEM_CANDIDATE_CAP. Single-sourced so
	 * getLogEntries and getEntrySummary can never diverge on which rows a term matches — the
	 * ribbon-equals-table invariant under search depends on both reading the same id set.
	 *
	 * @param selector The log-entry selector.
	 * @param request The wire request carrying the search term.
	 * @param criteria The resolved browse criteria both legs scope by.
	 *
	 * @return The matched forensic-row Ids (SOQL ∪ SOSL legs).
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * Set<Id> matchedIds = resolveSearchMatchedIds(selector, request, criteria);
	 * ```
	 */
	private static Set<Id> resolveSearchMatchedIds(SEL_LogEntry selector, DTO_Request request, SEL_LogEntry.BrowseCriteria criteria)
	{
		Set<Id> matchedIds = selector.findIdsBySearch(request.searchTerm, criteria, PROBLEM_CANDIDATE_CAP);
		matchedIds.addAll(selector.findIdsByBodySosl(request.searchTerm, criteria, PROBLEM_CANDIDATE_CAP));
		return matchedIds;
	}

	/**
	 * @description Adds a delta into a per-key count map, null-safe on the existing value and skipping
	 * blank keys — the shared accumulation idiom of the two ribbon source folds.
	 *
	 * @param counts The count map to accumulate into.
	 * @param key The count key; a blank key is skipped.
	 * @param delta The amount to add.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * addToCount(occurrencesBySource, source, occurrences);
	 * ```
	 */
	private static void addToCount(Map<String, Integer> counts, String key, Integer delta)
	{
		if(String.isBlank(key))
		{
			return;
		}
		counts.put(key, (counts.get(key) ?? 0) + delta);
	}

	/**
	 * @description Folds one problem's occurrences into the per-level summary for a scope summary: creates the
	 * level's entry on first sight, then adds the occurrences and one to its distinct count. Shared by the
	 * rollup and derived folds so both legs accumulate the per-level breakdown the same way.
	 *
	 * @param summaryByLevel The per-level summary map, accumulated in place.
	 * @param level The problem's log level.
	 * @param occurrences The problem's occurrence count.
	 *
	 * @example
	 * ```apex
	 * accumulateLevel(summaryByLevel, sample.LogLevel__c, occurrences);
	 * ```
	 */
	private static void accumulateLevel(Map<String, DTO_LevelSummary> summaryByLevel, String level, Integer occurrences)
	{
		DTO_LevelSummary levelSummary = summaryByLevel.get(level);
		if(levelSummary == null)
		{
			levelSummary = new DTO_LevelSummary();
			levelSummary.level = level;
			levelSummary.occurrences = 0;
			levelSummary.distinctCount = 0;
			summaryByLevel.put(level, levelSummary);
		}
		levelSummary.occurrences += occurrences;
		levelSummary.distinctCount++;
	}

	/**
	 * @description Folds a set of rollup: counter rows into per-base aggregates, summing
	 * OccurrenceCount__c and taking the MIN(CreatedDate) first-seen and MAX(LastModifiedDate) last-seen.
	 * Keys are decoded through the TRG_PersistLogEntry codec, so this layer never parses the persisted
	 * key format.
	 *
	 * @param rollupRows The rollup: counter rows to fold.
	 *
	 * @return A map of base fingerprint to its folded aggregate.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * Map<String, RollupFold> foldByBase = foldRollups(rollupRows);
	 * ```
	 */
	private static Map<String, RollupFold> foldRollups(List<LogEntry__c> rollupRows)
	{
		Map<String, RollupFold> foldByBase = new Map<String, RollupFold>();
		for(LogEntry__c rollupRow : rollupRows)
		{
			String base = TRG_PersistLogEntry.decodeBaseFromRollupKey(rollupRow.Fingerprint__c);
			RollupFold fold = foldByBase.get(base);
			if(fold == null)
			{
				fold = new RollupFold();
				foldByBase.put(base, fold);
			}
			fold.occurrenceTotal += rollupRow.OccurrenceCount__c ?? 0;
			if(fold.firstSeen == null || rollupRow.CreatedDate < fold.firstSeen)
			{
				fold.firstSeen = rollupRow.CreatedDate;
			}
			if(fold.lastSeen == null || rollupRow.LastModifiedDate > fold.lastSeen)
			{
				fold.lastSeen = rollupRow.LastModifiedDate;
			}
		}
		return foldByBase;
	}

	/**
	 * @description Builds a distinct-problem DTO from a detail sample (the display fields) and its
	 * folded rollup aggregate (the count and the first/last-seen times).
	 *
	 * @param sample The detail: sample carrying the display fields.
	 * @param fold The folded rollup aggregate for the same base fingerprint.
	 *
	 * @return The display-ready DTO_LogProblem.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * DTO_LogProblem problem = toProblem(sample, fold);
	 * ```
	 */
	private static DTO_LogProblem toProblem(LogEntry__c sample, RollupFold fold)
	{
		DTO_LogProblem problem = new DTO_LogProblem();
		problem.source = SOURCE_ROLLUP;
		problem.id = sample.Id;
		problem.logNumber = sample.Name;
		problem.level = sample.LogLevel__c;
		problem.shortMessage = sample.ShortMessage__c;
		problem.exceptionType = sample.ExceptionType__c;
		problem.className = LOG_Engine.extractClassName(sample.ClassMethod__c);
		problem.methodLine = buildMethodLine(sample);
		problem.classMethod = sample.ClassMethod__c;
		problem.executionEvent = sample.ExecutionEvent__c;
		problem.correlationId = sample.CorrelationId__c;
		problem.occurrenceCount = (fold.occurrenceTotal ?? 0).intValue();
		problem.firstSeen = fold.firstSeen;
		problem.lastSeen = fold.lastSeen;
		return problem;
	}

	/**
	 * @description Builds a flat-entry summary DTO from a forensic log row, pre-computing the two-line
	 * source (class name and method:line) and carrying the raw CreatedDate for locale-aware rendering.
	 *
	 * @param row The forensic log row.
	 *
	 * @return The display-ready DTO_LogEntrySummary.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * DTO_LogEntrySummary summary = toEntrySummary(row);
	 * ```
	 */
	private static DTO_LogEntrySummary toEntrySummary(LogEntry__c row)
	{
		DTO_LogEntrySummary summary = new DTO_LogEntrySummary();
		summary.id = row.Id;
		summary.logNumber = row.Name;
		summary.level = row.LogLevel__c;
		summary.shortMessage = row.ShortMessage__c;
		summary.exceptionType = row.ExceptionType__c;
		summary.className = LOG_Engine.extractClassName(row.ClassMethod__c);
		summary.methodLine = buildMethodLine(row);
		summary.executionEvent = row.ExecutionEvent__c;
		summary.correlationId = row.CorrelationId__c;
		summary.createdDate = row.CreatedDate;
		return summary;
	}

	/**
	 * @description Builds a correlated-trace node DTO from a forensic row, pre-computing the source class
	 * and method:line, marking whether it is the opened entry, and carrying the raw execution context and
	 * CreatedDate so the LWC renders the hop label and the relative offset.
	 *
	 * @param row The forensic log row.
	 * @param selfEntryId The Id of the opened entry, so the matching node is marked isSelf.
	 *
	 * @return The display-ready DTO_TraceEntry.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * DTO_TraceEntry node = toTraceEntry(row, openedEntryId);
	 * ```
	 */
	private static DTO_TraceEntry toTraceEntry(LogEntry__c row, Id selfEntryId)
	{
		DTO_TraceEntry entry = new DTO_TraceEntry();
		entry.id = row.Id;
		entry.logNumber = row.Name;
		entry.level = row.LogLevel__c;
		entry.shortMessage = row.ShortMessage__c;
		entry.className = LOG_Engine.extractClassName(row.ClassMethod__c);
		entry.methodLine = buildMethodLine(row);
		entry.executionEvent = row.ExecutionEvent__c;
		entry.createdDate = row.CreatedDate;
		entry.isSelf = row.Id == selfEntryId;
		entry.transactionId = row.TransactionId__c;
		entry.parentTransactionId = row.ParentTransactionId__c;
		entry.durationMs = row.DurationMs__c;
		return entry;
	}

	/**
	 * @description Unwraps the persisted '{"contextData":{...}}' envelope and returns the inner context
	 * object as a JSON string for the LWC JSON viewer. Returns the input verbatim when it is blank or
	 * cannot be parsed.
	 *
	 * @param contextData The persisted ContextData__c envelope.
	 *
	 * @return The inner context object as a JSON string, or the input verbatim on blank/parse failure.
	 *
	 * @example
	 * ```apex
	 * String contextJson = unwrapContext(row.ContextData__c);
	 * ```
	 */
	private static String unwrapContext(String contextData)
	{
		if(String.isBlank(contextData))
		{
			return contextData;
		}
		try
		{
			Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(contextData);
			Object innerContext = envelope.get('contextData');
			return innerContext == null ? contextData : JSON.serialize(innerContext);
		}
		catch(Exception parseError)
		{
			return contextData;
		}
	}

	/**
	 * @description Parses the newline-delimited governor-limit text produced by the framework limits
	 * snapshot ('<label>: <used> of <maximum>' lines) into display-ready bars, dropping limits with a
	 * zero or non-numeric used value and pre-computing the percentage and the colour band (red at 90%+,
	 * amber at 80%+, otherwise green).
	 *
	 * @param limitsText The persisted Limits__c text; blank yields an empty list.
	 *
	 * @return The parsed governor-limit bars.
	 *
	 * @example
	 * ```apex
	 * List<DTO_LimitBar> bars = parseLimitBars(row.Limits__c);
	 * ```
	 */
	private static List<DTO_LimitBar> parseLimitBars(String limitsText)
	{
		List<DTO_LimitBar> bars = new List<DTO_LimitBar>();
		if(String.isBlank(limitsText))
		{
			return bars;
		}
		for(String line : limitsText.split('\n'))
		{
			String trimmed = line.trim();
			if(String.isBlank(trimmed) || !trimmed.contains(': ') || !trimmed.contains(' of '))
			{
				continue;
			}
			String label = trimmed.substringBefore(': ');
			String pair = trimmed.substringAfter(': ');
			Decimal used = safeDecimal(pair.substringBefore(' of '));
			Decimal maximum = safeDecimal(pair.substringAfter(' of '));
			if(used == null || maximum == null || maximum <= 0 || used <= 0)
			{
				continue;
			}
			DTO_LimitBar bar = new DTO_LimitBar();
			bar.name = label;
			bar.used = used.longValue();
			bar.maximum = maximum.longValue();
			bar.percentage = (Integer)(used / maximum * 100).round();
			bar.level = bar.percentage >= 90 ? 'red' : bar.percentage >= 80 ? 'amber' : 'green';
			bars.add(bar);
		}
		return bars;
	}

	/**
	 * @description Parses a numeric token to a Decimal, returning null on a non-numeric token rather
	 * than throwing.
	 *
	 * @param token The token to parse.
	 *
	 * @return The parsed Decimal, or null when the token is not numeric.
	 *
	 * @example
	 * ```apex
	 * Decimal value = safeDecimal('47');
	 * ```
	 */
	private static Decimal safeDecimal(String token)
	{
		try
		{
			return Decimal.valueOf(token.trim());
		}
		catch(Exception conversionError)
		{
			return null;
		}
	}

	/**
	 * @description Composes the 'method:line' display string from a row's ClassMethod__c remainder and
	 * its LineNumber__c.
	 *
	 * @param row The log row.
	 *
	 * @return The 'method:line' string, the method alone, the line alone, or null when neither is present.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * String methodLine = buildMethodLine(row);
	 * ```
	 */
	private static String buildMethodLine(LogEntry__c row)
	{
		String classMethod = row.ClassMethod__c;
		String method = String.isNotBlank(classMethod) && classMethod.contains('.') ? classMethod.substringAfter('.') : null;
		String line = row.LineNumber__c != null ? String.valueOf(row.LineNumber__c.intValue()) : null;
		if(method == null && line == null)
		{
			return null;
		}
		if(method == null)
		{
			return line;
		}
		return line == null ? method : method + ':' + line;
	}

	/**
	 * @description Resolves the display name of the user who produced a log entry. `UserId__c` is a
	 * plain text field, so the value is validated via `UTIL_SObject.validateId`; an invalid or
	 * unresolvable Id yields null and the drawer falls back to showing the raw value.
	 *
	 * @param userId The originating user Id text captured on the entry.
	 *
	 * @return The user's name, or null when the value is blank, malformed, or matches no user.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * String userName = resolveUserName(row.UserId__c);
	 * ```
	 */
	private static String resolveUserName(String userId)
	{
		Id userIdValue = UTIL_SObject.validateId(userId);

		if(userIdValue == null)
		{
			return null;
		}

		User originatingUser = (User)new SEL_User().findById(userIdValue);

		return originatingUser?.Name;
	}

	/**
	 * @description Ranks a source-class metric map into the top-N sources for a summary ribbon, ordered by
	 * metric descending (ties broken by source name ascending for a stable order), each carrying its raw
	 * count and its whole-number share of the scope total. Shared by the grouped-problems ribbon (folded
	 * occurrences) and the all-entries ribbon (forensic row counts).
	 *
	 * @param countBySource The source class name to its metric (occurrences or row count).
	 * @param total The scope total the share percentage is computed against.
	 * @param topN The number of sources to return.
	 *
	 * @return Up to topN ranked DTO_SourceCount, highest metric first.
	 *
	 * @example
	 * ```apex
	 * List<DTO_SourceCount> topSources = rankTopSources(occurrencesBySource, totalOccurrences, TOP_SOURCE_LIMIT);
	 * ```
	 */
	private static List<DTO_SourceCount> rankTopSources(Map<String, Integer> countBySource, Integer total, Integer topN)
	{
		List<DTO_SourceCount> ranked = new List<DTO_SourceCount>();
		for(String source : countBySource.keySet())
		{
			DTO_SourceCount sourceCount = new DTO_SourceCount();
			sourceCount.name = source;
			sourceCount.count = countBySource.get(source);
			sourceCount.percent = total != null && total > 0 ? (Integer)((Decimal)sourceCount.count / total * 100).round() : 0;
			ranked.add(sourceCount);
		}
		ranked.sort(new SourceCountComparator());
		List<DTO_SourceCount> topSources = new List<DTO_SourceCount>();
		for(Integer i = 0; i < Math.min(topN, ranked.size()); i++)
		{
			topSources.add(ranked[i]);
		}
		return topSources;
	}

	/**
	 * @description Null-safe ascending comparison of two Integers, treating null as zero.
	 *
	 * @param first The first value.
	 * @param second The second value.
	 *
	 * @return -1, 0 or 1.
	 *
	 * @example
	 * ```apex
	 * Integer order = compareIntegers(firstCount, secondCount);
	 * ```
	 */
	private static Integer compareIntegers(Integer first, Integer second)
	{
		Integer left = first == null ? 0 : first;
		Integer right = second == null ? 0 : second;
		return left == right ? 0 : (left > right ? 1 : -1);
	}

	/**
	 * @description Null-safe ascending comparison of two Datetime, ordering null first.
	 *
	 * @param first The first value.
	 * @param second The second value.
	 *
	 * @return -1, 0 or 1.
	 *
	 * @example
	 * ```apex
	 * Integer order = compareDatetime(firstSeen, secondSeen);
	 * ```
	 */
	private static Integer compareDatetime(Datetime first, Datetime second)
	{
		return first == second ? 0 : first == null ? -1 : second == null ? 1 : (first > second ? 1 : -1);
	}

	/**
	 * @description Null-safe ascending comparison of two Strings, treating null as empty.
	 *
	 * @param first The first value.
	 * @param second The second value.
	 *
	 * @return The lexical ordering of the two values.
	 *
	 * @example
	 * ```apex
	 * Integer order = compareStrings(firstName, secondName);
	 * ```
	 */
	private static Integer compareStrings(String first, String second)
	{
		return (first == null ? '' : first).compareTo(second == null ? '' : second);
	}

	/**
	 * @description A per-base fold of the rollup counter rows: the summed occurrence count and the
	 * first-seen / last-seen extremes. Named for the rollup fold it holds, distinct from the selector's
	 * SEL_LogEntry.EntryAggregate (the all-entries ribbon shape).
	 *
	 * @date June 2026, July 2026
	 */
	private class RollupFold
	{
		/**
		 * @description The summed OccurrenceCount__c across the base's in-window rollup rows.
		 */
		private Decimal occurrenceTotal = 0;

		/**
		 * @description The earliest CreatedDate across the base's in-window rollup rows (first-seen).
		 */
		private Datetime firstSeen;

		/**
		 * @description The latest LastModifiedDate across the base's in-window rollup rows (last-seen).
		 */
		private Datetime lastSeen;
	}

	/**
	 * @description The outcome of the derived-problems leg: its status (COMPLETE/DISABLED/SKIPPED_SEARCH/
	 * SKIPPED_LEVEL_SCOPE/SKIPPED_NON_SELECTIVE), whether the fold hit its group cap, and the configured
	 * ProblemGroupingLogLevels__c scope, which is captured on every outcome — including the ones that return
	 * before the fold — because the console states the scope to the reader whatever the leg did.
	 *
	 * @date August 2026
	 */
	private class DerivedLeg
	{
		/**
		 * @description The folded derived signatures (empty when the leg did not run).
		 */
		private List<SEL_LogEntry.DerivedSignature> signatures = new List<SEL_LogEntry.DerivedSignature>();

		/**
		 * @description The leg's outcome, one of the DERIVED_STATUS_* values.
		 */
		private String status;

		/**
		 * @description True when the derived fold returned a full cap of signatures, so the list is incomplete.
		 */
		private Boolean capped = false;

		/**
		 * @description The configured ProblemGroupingLogLevels__c scope, captured before the console's own level
		 * filter narrows it, and set on every outcome including the ones that return before the fold is reached.
		 * The console states the scope to whoever is reading the list whatever the leg did, so a page that never
		 * folded still has to know the levels grouping is set up for.
		 */
		private List<String> configuredLevels = new List<String>();
	}

	/**
	 * @description The rollup-problems leg: the fingerprinted problems folded from rollup: counter rows, plus
	 * whether the candidate set was capped and whether the counts are best-effort. An empty list with degraded
	 * true is the graceful-degrade result when the rollup scan is non-selective (the cap flags are then still at
	 * their false defaults, because the scan throws before they are set).
	 *
	 * @date August 2026
	 */
	private class RollupLeg
	{
		/**
		 * @description The fingerprinted problems folded from the in-window rollup: counter rows.
		 */
		private final List<DTO_LogProblem> problems = new List<DTO_LogProblem>();

		/**
		 * @description True when the distinct rollup candidate set overflowed PROBLEM_CANDIDATE_CAP.
		 */
		private Boolean resultsTruncated = false;

		/**
		 * @description True when the in-window rollup rows overflowed their cap, so the counts are best-effort.
		 */
		private Boolean totalsApproximate = false;

		/**
		 * @description True when the rollup scan was non-selective and degraded, so the problem list is
		 * incomplete (the page reports capped) and the totals are best-effort.
		 */
		private Boolean degraded = false;
	}

	/**
	 * @description The two running tallies the ribbon is built from, which are always filled together and read
	 * together: occurrences per log level, and occurrences per source class. Held as one value so both legs of
	 * the summary can add to them through a single argument.
	 *
	 * @author Jason van Beukering
	 *
	 * @date August 2026
	 *
	 * @since 1.7
	 */
	private class SummaryTallies
	{
		/**
		 * @description Occurrences and distinct counts per log level, keyed by level.
		 */
		private final Map<String, DTO_LevelSummary> byLevel = new Map<String, DTO_LevelSummary>();

		/**
		 * @description Occurrences per originating class, keyed by class name.
		 */
		private final Map<String, Integer> bySource = new Map<String, Integer>();
	}

	/**
	 * @description The resolved in-window rollup scope shared by the problems fold and the scope summary:
	 * the per-base fold and whether the candidate set overflowed the rollup cap (totals best-effort).
	 *
	 * @date July 2026
	 */
	private class ScopedRollups
	{
		/**
		 * @description The folded rollup aggregate per base fingerprint.
		 */
		private Map<String, RollupFold> foldByBase;

		/**
		 * @description True when the in-window rollup rows overflowed ROLLUP_CANDIDATE_CAP, so every total
		 * folded from them is best-effort (the oldest in-window counters dropped).
		 */
		private Boolean totalsApproximate = false;
	}

	/**
	 * @description Sorts distinct problems by one of the ProblemSortField columns, defaulting to the
	 * occurrence count, in the requested direction.
	 *
	 * @date June 2026
	 */
	private class ProblemComparator implements System.Comparator<DTO_LogProblem>
	{
		/**
		 * @description The column to sort by.
		 */
		private final ProblemSortField sortField;

		/**
		 * @description True to sort descending.
		 */
		private final Boolean descending;

		/**
		 * @description Constructs a comparator for a sort column and direction.
		 *
		 * @param sortField The column to sort by.
		 * @param descending True to sort descending.
		 */
		private ProblemComparator(ProblemSortField sortField, Boolean descending)
		{
			this.sortField = sortField;
			this.descending = descending;
		}

		/**
		 * @description Compares two problems by the configured column, applying the configured direction.
		 *
		 * @param first The first problem.
		 * @param second The second problem.
		 *
		 * @return -1, 0 or 1 after applying the sort direction.
		 */
		public Integer compare(DTO_LogProblem first, DTO_LogProblem second)
		{
			Integer comparison = compareByField(first, second);
			return descending ? -comparison : comparison;
		}

		/**
		 * @description Compares two problems ascending by the configured column, defaulting to the
		 * occurrence count. The level column ranks by severity and then, within one severity, by how
		 * often the problem occurred: this is the console's opening order, so the worst thing in the
		 * window heads the list and a chatty INFO message can never outrank an error.
		 *
		 * @param first The first problem.
		 * @param second The second problem.
		 *
		 * @return -1, 0 or 1.
		 */
		private Integer compareByField(DTO_LogProblem first, DTO_LogProblem second)
		{
			Integer comparison;
			switch on sortField
			{
				when LAST_SEEN
				{
					comparison = compareDatetime(first.lastSeen, second.lastSeen);
				}
				when LEVEL
				{
					Integer bySeverity = compareIntegers(LOG_Engine.levelSeverityRank(first.level), LOG_Engine.levelSeverityRank(second.level));
					comparison = bySeverity != 0 ? bySeverity : compareIntegers(first.occurrenceCount, second.occurrenceCount);
				}
				when LOG_NUMBER
				{
					comparison = compareStrings(first.logNumber, second.logNumber);
				}
				when CLASS_NAME
				{
					comparison = compareStrings(first.className, second.className);
				}
				when SHORT_MESSAGE
				{
					comparison = compareStrings(first.shortMessage, second.shortMessage);
				}
				when EXECUTION_EVENT
				{
					comparison = compareStrings(first.executionEvent, second.executionEvent);
				}
				when else
				{
					comparison = compareIntegers(first.occurrenceCount, second.occurrenceCount);
				}
			}
			return comparison;
		}
	}

	/**
	 * @description Ranks summary sources by their metric descending, breaking ties by source name ascending so
	 * equal-metric sources have a stable, deterministic order.
	 *
	 * @date July 2026
	 */
	private class SourceCountComparator implements System.Comparator<DTO_SourceCount>
	{
		/**
		 * @description Compares two ranked sources: higher count first, then source name ascending on a tie.
		 *
		 * @param first The first source.
		 * @param second The second source.
		 *
		 * @return -1, 0 or 1.
		 */
		public Integer compare(DTO_SourceCount first, DTO_SourceCount second)
		{
			Integer byCount = compareIntegers(second.count, first.count);
			return byCount != 0 ? byCount : compareStrings(first.name, second.name);
		}
	}

	/**
	 * @description The wire request for every Log Console read. Crosses as one JSON string under the
	 * single requestJson parameter.
	 *
	 * @date June 2026
	 */
	public class DTO_Request
	{
		/**
		 * @description Log levels to include (DEBUG/INFO/WARN/ERROR). Null or empty includes all levels.
		 */
		@AuraEnabled
		public List<String> levels;

		/**
		 * @description Execution contexts (quiddity) to include. Null or empty includes all contexts.
		 */
		@AuraEnabled
		public List<String> executionEvents;

		/**
		 * @description Originating user Id to filter on (UserId__c, not CreatedById). Blank includes all users.
		 */
		@AuraEnabled
		public String userId;

		/**
		 * @description Free-text term matched against ShortMessage__c. Blank applies no text filter.
		 */
		@AuraEnabled
		public String searchTerm;

		/**
		 * @description Preset look back window in minutes (15, 60, 1440, 10080). Null defaults to 24 hours.
		 */
		@AuraEnabled
		public Integer windowMinutes;

		/**
		 * @description ISO-8601 lower bound of a custom range. Set with customEnd to override windowMinutes.
		 */
		@AuraEnabled
		public String customStart;

		/**
		 * @description ISO-8601 upper bound of a custom range. Set with customStart to override windowMinutes.
		 */
		@AuraEnabled
		public String customEnd;

		/**
		 * @description The sort key — a DTO_LogProblem field name for the problems view, or a
		 * DTO_LogEntrySummary field name for the entries view; an unrecognised value falls back to the
		 * default sort.
		 */
		@AuraEnabled
		public String sortField;

		/**
		 * @description True to sort ascending. Null or false sorts descending.
		 */
		@AuraEnabled
		public Boolean sortAscending;

		/**
		 * @description Rows per page. Null or non-positive defaults to 50.
		 */
		@AuraEnabled
		public Integer pageSize;

		/**
		 * @description The 1-based page number. Null or non-positive defaults to 1.
		 */
		@AuraEnabled
		public Integer pageNumber;

		/**
		 * @description Exact CorrelationId__c to filter on (the Chain Monitor deep-link). Blank applies no filter.
		 */
		@AuraEnabled
		public String correlationId;

		/**
		 * @description Exact ClassMethod__c to filter on — the source of the problem whose occurrences are
		 * being listed. Set by the console's "View occurrences" drill so the entries behind a problem are
		 * the entries that problem was grouped from, rather than every row mentioning its class name
		 * anywhere. Blank applies no filter.
		 */
		@AuraEnabled
		public String classMethod;

		/**
		 * @description Resolves the requested page number to a safe 1-based value: null or a non-positive
		 * value falls back to the first page. The request normalises its own paging input, so neither the
		 * controller nor the selector re-implements the policy.
		 *
		 * @return A page number of at least one.
		 *
		 * @example
		 * ```apex
		 * Integer pageNumber = request.resolvedPageNumber();
		 * ```
		 */
		public Integer resolvedPageNumber()
		{
			return pageNumber != null && pageNumber > 0 ? pageNumber : 1;
		}

		/**
		 * @description Resolves the requested page size to a safe positive value: null or a non-positive
		 * value falls back to DEFAULT_PAGE_SIZE.
		 *
		 * @return A positive page size.
		 *
		 * @example
		 * ```apex
		 * Integer pageSize = request.resolvedPageSize();
		 * ```
		 */
		public Integer resolvedPageSize()
		{
			return pageSize != null && pageSize > 0 ? pageSize : DEFAULT_PAGE_SIZE;
		}
	}

	/**
	 * @description A page of distinct problems with pagination metadata.
	 *
	 * @date June 2026
	 */
	public class DTO_LogProblemPage
	{
		/**
		 * @description The problems on this page.
		 */
		@AuraEnabled
		public List<DTO_LogProblem> records;

		/**
		 * @description The total number of distinct problems across all pages.
		 */
		@AuraEnabled
		public Integer totalCount;

		/**
		 * @description True when the distinct candidate set was capped — narrow the filters to see the rest.
		 */
		@AuraEnabled
		public Boolean resultsTruncated;

		/**
		 * @description True when the in-window rollup rows overflowed the candidate cap, so each problem's
		 * occurrence count is best-effort and low-recency problems may be missing, or when the rollup scan degraded
		 * on a non-selective query and its contribution is absent — distinct from resultsTruncated, which flags
		 * the distinct list itself capped.
		 *
		 * @date July 2026
		 */
		@AuraEnabled
		public Boolean totalsApproximate;

		/**
		 * @description The 1-based page number of this page.
		 */
		@AuraEnabled
		public Integer pageNumber;

		/**
		 * @description The total number of pages.
		 */
		@AuraEnabled
		public Integer totalPages;

		/**
		 * @description True when a further page exists after this one.
		 */
		@AuraEnabled
		public Boolean hasMorePages;

		/**
		 * @description The outcome of the derived-problems leg for this page: COMPLETE (folded and merged),
		 * DISABLED (ProblemGroupingDisabled__c checked), SKIPPED_SEARCH (a free-text term suppresses the leg),
		 * SKIPPED_LEVEL_SCOPE (the levels being viewed sit outside the ProblemGroupingLogLevels__c scope, so the
		 * leg was never permitted to look), or SKIPPED_NON_SELECTIVE (the aggregate scan was non-selective and
		 * the leg degraded to rollup-only).
		 */
		@AuraEnabled
		public String derivedStatus;

		/**
		 * @description True when either leg hit its group cap, or the rollup scan degraded and its problems are
		 * absent, so the distinct problem list is incomplete — narrow the window or levels to see the rest.
		 * Distinct from totalsApproximate (rollup counts best-effort) and resultsTruncated (the rollup candidate
		 * set capped).
		 */
		@AuraEnabled
		public Boolean capped;

		/**
		 * @description The log levels problem grouping is configured to cover (ProblemGroupingLogLevels__c), as
		 * configured and before the console's own level filter narrows it. Present on every derivedStatus, not
		 * only SKIPPED_LEVEL_SCOPE: the console states the scope permanently and quietly, which is what explains
		 * a PARTIAL level mismatch — viewing a level inside the scope alongside one outside it leaves the status
		 * COMPLETE and fires no message, while the entries view plainly lists the rows that produced no problems.
		 * Reporting the intersection instead would only echo the reader's own filter back at them.
		 */
		@AuraEnabled
		public List<String> derivedLevelScope;

		/**
		 * @description Populates this page from the full, already-sorted problem list and the request's
		 * resolved paging — total count, total pages, current page, has-more flag, and the sliced records.
		 * The page owns its own pagination so the controller only asks for it; bad paging input is normalised
		 * by the request (resolvedPageNumber / resolvedPageSize), so a null or non-positive page number or
		 * size degrades to page one / the default size and a page beyond the end yields an empty slice rather
		 * than throwing.
		 *
		 * @param all The full, already-sorted problem list.
		 * @param request The originating request, consulted for its resolved page number and size.
		 * @param resultsTruncated True when the distinct candidate set was capped upstream.
		 *
		 * @return This page, populated.
		 *
		 * @example
		 * ```apex
		 * DTO_LogProblemPage page = new DTO_LogProblemPage().paginate(problems, request, resultsTruncated);
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		public DTO_LogProblemPage paginate(List<DTO_LogProblem> all, DTO_Request request, Boolean resultsTruncated)
		{
			Integer size = request.resolvedPageSize();
			Integer page = request.resolvedPageNumber();
			this.totalCount = all.size();
			this.resultsTruncated = resultsTruncated;
			this.pageNumber = page;
			this.totalPages = all.isEmpty() ? 1 : (Integer)Math.ceil((Decimal)all.size() / size);
			this.hasMorePages = page < this.totalPages;
			Integer start = (page - 1) * size;
			List<DTO_LogProblem> pageRecords = new List<DTO_LogProblem>();
			for(Integer i = start; i < Math.min(start + size, all.size()); i++)
			{
				pageRecords.add(all[i]);
			}
			this.records = pageRecords;
			return this;
		}
	}

	/**
	 * @description One distinct, flood-collapsed problem: the sample's display fields plus the folded
	 * occurrence count and first/last-seen times.
	 *
	 * @date June 2026
	 */
	public class DTO_LogProblem
	{
		/**
		 * @description The detail sample's record Id.
		 */
		@AuraEnabled
		public Id id;

		/**
		 * @description The sample's auto-number Log Number (Name).
		 */
		@AuraEnabled
		public String logNumber;

		/**
		 * @description The log level (DEBUG/INFO/WARN/ERROR).
		 */
		@AuraEnabled
		public String level;

		/**
		 * @description The short, SOQL-safe message.
		 */
		@AuraEnabled
		public String shortMessage;

		/**
		 * @description The exception type, when the entry recorded one.
		 */
		@AuraEnabled
		public String exceptionType;

		/**
		 * @description The source class name (first dotted segment of ClassMethod__c).
		 */
		@AuraEnabled
		public String className;

		/**
		 * @description The 'method:line' location within the source class.
		 */
		@AuraEnabled
		public String methodLine;

		/**
		 * @description The whole ClassMethod__c value this problem was grouped under — the exact handle the
		 * console sends back as DTO_Request.classMethod to list the entries behind the problem. Sent as one
		 * value rather than rebuilt from className and methodLine, because methodLine carries a line number
		 * for a fingerprinted problem and none for a grouped one. Null when the problem records no source.
		 */
		@AuraEnabled
		public String classMethod;

		/**
		 * @description The execution context (quiddity) the entry was captured in.
		 */
		@AuraEnabled
		public String executionEvent;

		/**
		 * @description The correlation Id that ties the entry to one logical operation.
		 */
		@AuraEnabled
		public String correlationId;

		/**
		 * @description The summed occurrence count over the in-window rollup rows.
		 */
		@AuraEnabled
		public Integer occurrenceCount;

		/**
		 * @description The earliest in-window occurrence (MIN CreatedDate over the rollup rows).
		 */
		@AuraEnabled
		public Datetime firstSeen;

		/**
		 * @description The latest in-window occurrence (MAX LastModifiedDate over the rollup rows).
		 */
		@AuraEnabled
		public Datetime lastSeen;

		/**
		 * @description The provenance of this problem: 'rollup' for a fingerprinted problem folded from
		 * rollup: counter rows (openable by id), or 'derived' for one read-time-grouped from plain forensic
		 * rows (no id — opened through its signature via getDerivedProblemDetail).
		 */
		@AuraEnabled
		public String source;

		/**
		 * @description For a derived problem, the JSON-encoded identity key (exception type, class method, log
		 * level) the client passes back to getDerivedProblemDetail to open a representative row. Null for a
		 * rollup problem, which is opened by its id.
		 */
		@AuraEnabled
		public String signature;
	}

	/**
	 * @description A page of flat forensic entries with pagination metadata.
	 *
	 * @date June 2026
	 */
	public class DTO_LogEntryPage
	{
		/**
		 * @description The entries on this page.
		 */
		@AuraEnabled
		public List<DTO_LogEntrySummary> records;

		/**
		 * @description The total number of forensic entries across all pages.
		 */
		@AuraEnabled
		public Integer totalCount;

		/**
		 * @description The 1-based page number of this page.
		 */
		@AuraEnabled
		public Integer pageNumber;

		/**
		 * @description The total number of pages.
		 */
		@AuraEnabled
		public Integer totalPages;

		/**
		 * @description True when a further page exists after this one.
		 */
		@AuraEnabled
		public Boolean hasMorePages;

		/**
		 * @description True when the search matched the candidate cap — narrow the window or filters to see the rest.
		 */
		@AuraEnabled
		public Boolean resultsTruncated;
	}

	/**
	 * @description One flat forensic entry in the All-entries view.
	 *
	 * @date June 2026
	 */
	public class DTO_LogEntrySummary
	{
		/**
		 * @description The record Id.
		 */
		@AuraEnabled
		public Id id;

		/**
		 * @description The auto-number Log Number (Name).
		 */
		@AuraEnabled
		public String logNumber;

		/**
		 * @description The log level (DEBUG/INFO/WARN/ERROR).
		 */
		@AuraEnabled
		public String level;

		/**
		 * @description The short, SOQL-safe message.
		 */
		@AuraEnabled
		public String shortMessage;

		/**
		 * @description The exception type, when the entry recorded one.
		 */
		@AuraEnabled
		public String exceptionType;

		/**
		 * @description The source class name (first dotted segment of ClassMethod__c).
		 */
		@AuraEnabled
		public String className;

		/**
		 * @description The 'method:line' location within the source class.
		 */
		@AuraEnabled
		public String methodLine;

		/**
		 * @description The execution context (quiddity) the entry was captured in.
		 */
		@AuraEnabled
		public String executionEvent;

		/**
		 * @description The correlation Id that ties the entry to one logical operation.
		 */
		@AuraEnabled
		public String correlationId;

		/**
		 * @description The raw creation timestamp, for locale-aware rendering in the LWC.
		 */
		@AuraEnabled
		public Datetime createdDate;
	}

	/**
	 * @description One node of a correlated execution trace: its display fields, the raw execution context
	 * and creation timestamp (so the LWC derives the hop label and the relative offset), and whether it is
	 * the opened entry.
	 *
	 * @date June 2026
	 */
	public class DTO_TraceEntry
	{
		/**
		 * @description The record Id.
		 */
		@AuraEnabled
		public Id id;

		/**
		 * @description The auto-number Log Number (Name).
		 */
		@AuraEnabled
		public String logNumber;

		/**
		 * @description The log level (DEBUG/INFO/WARN/ERROR), driving the node's severity dot.
		 */
		@AuraEnabled
		public String level;

		/**
		 * @description The short, SOQL-safe message, shown in the ordered correlated-entries list.
		 */
		@AuraEnabled
		public String shortMessage;

		/**
		 * @description The source class name (first dotted segment of ClassMethod__c).
		 */
		@AuraEnabled
		public String className;

		/**
		 * @description The 'method:line' location within the source class.
		 */
		@AuraEnabled
		public String methodLine;

		/**
		 * @description The raw execution context (quiddity), from which the LWC derives the hop label.
		 */
		@AuraEnabled
		public String executionEvent;

		/**
		 * @description The raw creation timestamp, from which the LWC computes the node's relative offset.
		 */
		@AuraEnabled
		public Datetime createdDate;

		/**
		 * @description True when this node is the opened entry, so the strip marks it non-clickable.
		 */
		@AuraEnabled
		public Boolean isSelf;

		/**
		 * @description The transaction Id of this hop's execution context, so the LWC groups the entries into
		 * transactions and builds the correlation tree.
		 */
		@AuraEnabled
		public String transactionId;

		/**
		 * @description The parent transaction Id (the enqueuer's), so the LWC links each async hop to the
		 * transaction that spawned it.
		 */
		@AuraEnabled
		public String parentTransactionId;

		/**
		 * @description The captured duration in milliseconds, so the LWC shows each transaction's elapsed span.
		 */
		@AuraEnabled
		public Decimal durationMs;
	}

	/**
	 * @description A bounded page of correlated trace nodes: the ordered entries and whether the correlation
	 * held more rows than the trace row cap, so the console shows the first transactions and points the user
	 * to the Chain Monitor for the rest.
	 *
	 * @date July 2026
	 */
	public class DTO_TracePage
	{
		/**
		 * @description The ordered trace nodes, trimmed to the row cap when the correlation overflowed.
		 */
		@AuraEnabled
		public List<DTO_TraceEntry> entries;

		/**
		 * @description True when the correlation held more rows than the cap, so the entries are the first
		 * cap rows and the console flags that the full chain is available in the Chain Monitor.
		 */
		@AuraEnabled
		public Boolean truncated;
	}

	/**
	 * @description A scope summary: total occurrences, a per-level breakdown, and the top source class.
	 *
	 * @date June 2026
	 */
	public class DTO_LogSummary
	{
		/**
		 * @description The total occurrences folded over the scope.
		 */
		@AuraEnabled
		public Integer totalOccurrences;

		/**
		 * @description The number of distinct problems in the scope.
		 */
		@AuraEnabled
		public Integer distinctCount;

		/**
		 * @description True when the totals are best-effort rather than exact, which any of four causes sets: the
		 * in-window rollup rows overflowing their candidate cap, the rollup scan degrading on a non-selective
		 * query, the derived fold hitting its group cap, or the derived leg reporting SKIPPED_NON_SELECTIVE (declined
		 * in advance, or failed as non-selective). The flag says only that the number is low; totalsApproximateCause
		 * says which kind of gap produced it.
		 *
		 * @date July 2026
		 */
		@AuraEnabled
		public Boolean totalsApproximate;

		/**
		 * @description Why totalsApproximate is set, so the console can explain it honestly: TRUNCATED when a
		 * candidate set overflowed its cap and the totals count a capped set only — the newest rollup counters,
		 * the most frequent grouped signatures — or PARTIAL when a whole leg never ran and its contribution is
		 * simply absent. Null when the totals are exact. The flag alone cannot tell the two apart, and the
		 * shipped help text describes truncation only — which is false for a leg that never ran. PARTIAL wins
		 * when both apply, an absent leg being the larger gap. The rollup leg can degrade this way too, so copy
		 * written for PARTIAL must not name problem grouping as the cause.
		 */
		@AuraEnabled
		public String totalsApproximateCause;

		/**
		 * @description The per-level occurrence and distinct-count breakdown.
		 */
		@AuraEnabled
		public List<DTO_LevelSummary> perLevel;

		/**
		 * @description The top three source classes ranked by folded occurrence count, each carrying its raw
		 * count and its whole-number share of the total, so the ribbon renders a ranked, click-to-drill list.
		 */
		@AuraEnabled
		public List<DTO_SourceCount> topSources;
	}

	/**
	 * @description One ranked source class in a summary's top-sources list: the source name, its raw metric
	 * (folded occurrences for the grouped-problems ribbon, or forensic row count for the all-entries ribbon),
	 * and its whole-number share of the scope total.
	 *
	 * @date July 2026
	 */
	public class DTO_SourceCount
	{
		/**
		 * @description The source class name (first dotted segment of ClassMethod__c).
		 */
		@AuraEnabled
		public String name;

		/**
		 * @description The raw metric for this source — folded occurrences (grouped view) or forensic row count (all-entries view).
		 */
		@AuraEnabled
		public Integer count;

		/**
		 * @description This source's share of the scope total, as a whole-number percentage.
		 */
		@AuraEnabled
		public Integer percent;
	}

	/**
	 * @description The occurrence total and distinct count for one log level within the scope.
	 *
	 * @date June 2026
	 */
	public class DTO_LevelSummary
	{
		/**
		 * @description The log level (DEBUG/INFO/WARN/ERROR).
		 */
		@AuraEnabled
		public String level;

		/**
		 * @description The summed occurrences at this level.
		 */
		@AuraEnabled
		public Integer occurrences;

		/**
		 * @description The number of distinct problems at this level.
		 */
		@AuraEnabled
		public Integer distinctCount;
	}

	/**
	 * @description The all-entries ribbon summary: the total forensic row count, a per-level row-count
	 * breakdown, and the top three source classes ranked by forensic row count — or, over a window too large
	 * to scan, the exact total alone with the breakdown declined.
	 *
	 * @date July 2026, August 2026
	 */
	public class DTO_EntrySummary
	{
		/**
		 * @description The total forensic rows in the scope: the sum of the per-level counts when the breakdown
		 * ran, or the pre-flight count's exact answer when it was declined.
		 */
		@AuraEnabled
		public Integer totalRows;

		/**
		 * @description True when the window held more rows than the ribbon may scan
		 * (ENTRY_SUMMARY_SCAN_ROW_CEILING), so the breakdown was declined before the aggregates ran: totalRows
		 * still carries the exact count and both lists are empty. False when the aggregates ran.
		 *
		 * @date August 2026
		 */
		@AuraEnabled
		public Boolean declined = false;

		/**
		 * @description The per-level forensic row-count breakdown.
		 */
		@AuraEnabled
		public List<DTO_EntryLevelCount> perLevel;

		/**
		 * @description The top three source classes ranked by forensic row count, each carrying its row count
		 * and its whole-number share of the total.
		 */
		@AuraEnabled
		public List<DTO_SourceCount> topSources;
	}

	/**
	 * @description The forensic row count for one log level within the all-entries scope.
	 *
	 * @date July 2026
	 */
	public class DTO_EntryLevelCount
	{
		/**
		 * @description The log level (DEBUG/INFO/WARN/ERROR).
		 */
		@AuraEnabled
		public String level;

		/**
		 * @description The number of forensic rows at this level.
		 */
		@AuraEnabled
		public Integer rowCount;
	}

	/**
	 * @description The heavy forensic detail for a single log entry.
	 *
	 * @date June 2026, August 2026
	 */
	public class DTO_LogEntryDetail
	{
		/**
		 * @description The record Id.
		 */
		@AuraEnabled
		public Id id;

		/**
		 * @description The auto-number Log Number (Name).
		 */
		@AuraEnabled
		public String logNumber;

		/**
		 * @description The log level (DEBUG/INFO/WARN/ERROR).
		 */
		@AuraEnabled
		public String level;

		/**
		 * @description The short, SOQL-safe message.
		 */
		@AuraEnabled
		public String shortMessage;

		/**
		 * @description The exception type, when the entry recorded one.
		 */
		@AuraEnabled
		public String exceptionType;

		/**
		 * @description The full message body.
		 */
		@AuraEnabled
		public String message;

		/**
		 * @description The full stack trace, when present.
		 */
		@AuraEnabled
		public String stackTrace;

		/**
		 * @description The unwrapped inner context object as a JSON string, for the LWC JSON viewer.
		 */
		@AuraEnabled
		public String contextJson;

		/**
		 * @description The source class name (first dotted segment of ClassMethod__c).
		 */
		@AuraEnabled
		public String className;

		/**
		 * @description The 'method:line' location within the source class.
		 */
		@AuraEnabled
		public String methodLine;

		/**
		 * @description The Class.method source exactly as the entry recorded it (ClassMethod__c), kept apart from
		 * the display pair className + methodLine, which folds the line number into the method segment. The
		 * console's generated tagging snippet passes this value to emitAt, so it has to be the value the logging
		 * framework itself stores: a line number baked into the snippet would mis-attribute every future entry the
		 * subscriber tags with it.
		 */
		@AuraEnabled
		public String classMethod;

		/**
		 * @description The execution context (quiddity) the entry was captured in.
		 */
		@AuraEnabled
		public String executionEvent;

		/**
		 * @description The originating user Id.
		 */
		@AuraEnabled
		public String userId;

		/**
		 * @description The originating user's display name, when the Id resolves to a user.
		 */
		@AuraEnabled
		public String userName;

		/**
		 * @description The correlation Id that ties the entry to one logical operation.
		 */
		@AuraEnabled
		public String correlationId;

		/**
		 * @description The transaction Id of the entry's execution context.
		 */
		@AuraEnabled
		public String transactionId;

		/**
		 * @description The parent transaction Id, when the operation spanned an async hop.
		 */
		@AuraEnabled
		public String parentTransactionId;

		/**
		 * @description True when a registered async chain (AsyncChainExecution__c) shares this entry's
		 * correlation, so the drawer offers Open in Chain Monitor only when there is a chain to open.
		 */
		@AuraEnabled
		public Boolean chainExists;

		/**
		 * @description The Id of the record the entry refers to, when one was captured.
		 */
		@AuraEnabled
		public String recordId;

		/**
		 * @description The entry's creation timestamp.
		 */
		@AuraEnabled
		public Datetime firstSeen;

		/**
		 * @description The entry's last-modified timestamp.
		 */
		@AuraEnabled
		public Datetime lastSeen;

		/**
		 * @description The captured duration in milliseconds, when present.
		 */
		@AuraEnabled
		public Decimal durationMs;

		/**
		 * @description The parsed governor-limit bars.
		 */
		@AuraEnabled
		public List<DTO_LimitBar> limitBars;
	}

	/**
	 * @description One parsed governor-limit bar: the used and maximum values, the percentage, and the
	 * pre-computed colour band.
	 *
	 * @date June 2026
	 */
	public class DTO_LimitBar
	{
		/**
		 * @description The limit's label (e.g. 'Queries', 'Cpu Time').
		 */
		@AuraEnabled
		public String name;

		/**
		 * @description The amount of the limit used.
		 */
		@AuraEnabled
		public Long used;

		/**
		 * @description The limit's maximum.
		 */
		@AuraEnabled
		public Long maximum;

		/**
		 * @description The used percentage of the maximum, as a whole number.
		 */
		@AuraEnabled
		public Integer percentage;

		/**
		 * @description The colour band: 'red' at 90%+, 'amber' at 80%+, otherwise 'green'.
		 */
		@AuraEnabled
		public String level;
	}
}