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
 * @date June 2026, July 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength')
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
	 * fields. Long-text bodies are never sortable, so they are deliberately absent; an unrecognised key
	 * falls back to CreatedDate.
	 *
	 * @date July 2026
	 */
	private static final Map<String, SObjectField> ENTRY_SORT_FIELDS = new Map<String, SObjectField>
	{
			'createdDate' => LogEntry__c.CreatedDate,
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
	 * best-effort rather than silently under-reported.
	 *
	 * @param requestJson The serialised DTO_Request; blank yields a default request.
	 *
	 * @return A DTO_LogProblemPage of folded problems with pagination metadata.
	 *
	 * @date June 2026, July 2026
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

		ScopedRollups scoped = resolveScopedRollups(selector, request);

		List<String> allBases = new List<String>(scoped.foldByBase.keySet());
		Boolean resultsTruncated = allBases.size() > PROBLEM_CANDIDATE_CAP;
		List<String> shownBases = new List<String>();
		for(Integer i = 0; i < Math.min(allBases.size(), PROBLEM_CANDIDATE_CAP); i++)
		{
			shownBases.add(allBases[i]);
		}

		Map<String, LogEntry__c> sampleByBase = findSamplesForBases(selector, shownBases);

		List<DTO_LogProblem> problems = new List<DTO_LogProblem>();
		for(String base : shownBases)
		{
			LogEntry__c sample = sampleByBase.get(base);
			if(sample != null && sampleInScope(sample, request))
			{
				problems.add(toProblem(sample, scoped.foldByBase.get(base)));
			}
		}

		ProblemSortField sortField = PROBLEM_SORT_FIELDS.containsKey(request.sortField) ? PROBLEM_SORT_FIELDS.get(request.sortField) : ProblemSortField.OCCURRENCE_COUNT;
		problems.sort(new ProblemComparator(sortField, request.sortAscending != true));
		DTO_LogProblemPage page = new DTO_LogProblemPage().paginate(problems, request, resultsTruncated);
		page.totalsApproximate = scoped.totalsApproximate;
		return page;
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
	 * best-effort rather than silently under-reported.
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

		ScopedRollups scoped = resolveScopedRollups(selector, request);
		Map<String, LogEntry__c> sampleByBase = findSamplesForBases(selector, scoped.foldByBase.keySet());

		Integer totalOccurrences = 0;
		Integer distinctCount = 0;
		Map<String, DTO_LevelSummary> summaryByLevel = new Map<String, DTO_LevelSummary>();
		Map<String, Integer> occurrencesBySource = new Map<String, Integer>();

		for(String base : scoped.foldByBase.keySet())
		{
			LogEntry__c sample = sampleByBase.get(base);
			if(sample == null || !sampleInScope(sample, request))
			{
				continue;
			}
			Integer occurrences = (scoped.foldByBase.get(base).occurrenceTotal ?? 0).intValue();
			totalOccurrences += occurrences;
			distinctCount++;

			DTO_LevelSummary levelSummary = summaryByLevel.get(sample.LogLevel__c);
			if(levelSummary == null)
			{
				levelSummary = new DTO_LevelSummary();
				levelSummary.level = sample.LogLevel__c;
				levelSummary.occurrences = 0;
				levelSummary.distinctCount = 0;
				summaryByLevel.put(sample.LogLevel__c, levelSummary);
			}
			levelSummary.occurrences += occurrences;
			levelSummary.distinctCount++;

			addToCount(occurrencesBySource, LOG_Engine.extractClassName(sample.ClassMethod__c), occurrences);
		}

		DTO_LogSummary summary = new DTO_LogSummary();
		summary.totalOccurrences = totalOccurrences;
		summary.distinctCount = distinctCount;
		summary.totalsApproximate = scoped.totalsApproximate;
		summary.perLevel = summaryByLevel.values();
		summary.topSources = rankTopSources(occurrencesBySource, totalOccurrences, TOP_SOURCE_LIMIT);
		return summary;
	}

	/**
	 * @description Returns the all-entries ribbon summary: the total forensic row count in the window, a
	 * per-level row-count breakdown (so the total always equals the sum of the per-level cards), and the top
	 * three source classes ranked by forensic row count. With no search term it folds a bind-only aggregate over
	 * the forensic rows (OccurrenceCount__c null) across the whole window, so the ribbon spans the window even
	 * though the entries list loads incrementally by infinite scroll. When a free-text search is active it
	 * aggregates over the same matched-id set the entries table pages (SOQL short-message/correlation ∪ SOSL
	 * body, both correlation-scoped), so the ribbon totals equal the table for every term, including body-only
	 * matches.
	 *
	 * @param requestJson The serialised DTO_Request; blank yields a default request.
	 *
	 * @return A DTO_EntrySummary over the requested scope.
	 *
	 * @date July 2026
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
		if(row == null)
		{
			return null;
		}

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
	 * @description Whether a distinct-view detail sample satisfies the request's free-text search and
	 * correlation deep-link. The rollup: counters carry no message text or correlation id, so the distinct
	 * view applies both here against the sample's own fields. A blank term and a blank correlation id
	 * each impose no constraint. The term is matched case-insensitively across the single-sourced
	 * SAMPLE_SEARCH_FIELDS list, which reconciles this in-memory matcher's coverage with the All-entries
	 * search legs.
	 *
	 * @param sample The detail sample row.
	 * @param request The wire request carrying searchTerm and correlationId.
	 *
	 * @return True when the sample is in scope for the current search and deep-link.
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
	 * never drift between the two endpoints. The rollup: counters carry no message text or correlation id,
	 * so the free-text search and the correlation deep-link must NOT filter the rollup fold (that would
	 * zero out every signature); both are applied later, in-memory, against the detail samples where the
	 * text and correlation live. The selector fetches one probe row beyond ROLLUP_CANDIDATE_CAP: when it
	 * arrives, the window overflowed the cap, the probe row is discarded (only cap rows fold) and the
	 * result flags totalsApproximate so no shape built on the fold reports best-effort totals as exact.
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
		problem.id = sample.Id;
		problem.logNumber = sample.Name;
		problem.level = sample.LogLevel__c;
		problem.shortMessage = sample.ShortMessage__c;
		problem.exceptionType = sample.ExceptionType__c;
		problem.className = LOG_Engine.extractClassName(sample.ClassMethod__c);
		problem.methodLine = buildMethodLine(sample);
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
		 * occurrence count.
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
					comparison = compareIntegers(LOG_Engine.levelSeverityRank(first.level), LOG_Engine.levelSeverityRank(second.level));
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
		 * occurrence count is best-effort and low-recency problems may be missing — distinct from
		 * resultsTruncated, which flags the distinct list itself capped.
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
		 * @description True when the in-window rollup rows overflowed the candidate cap, so the totals are
		 * best-effort (folded from the most recent counters only) and the console flags them approximate.
		 *
		 * @date July 2026
		 */
		@AuraEnabled
		public Boolean totalsApproximate;

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
	 * breakdown, and the top three source classes ranked by forensic row count.
	 *
	 * @date July 2026
	 */
	public class DTO_EntrySummary
	{
		/**
		 * @description The total forensic rows in the scope (the sum of the per-level counts).
		 */
		@AuraEnabled
		public Integer totalRows;

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
	 * @date June 2026
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
