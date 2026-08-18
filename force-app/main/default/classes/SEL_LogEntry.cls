// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the LogEntry__c SObject. Provides query methods for
 * retrieving log records by class method, logging level, and other criteria,
 * supporting traceability and error analysis.
 *
 * @see SEL_Base
 * @see SEL_LogEntry_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date February 2026, August 2026
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.CognitiveComplexity,PMD.ExcessiveClassLength')
public inherited sharing class SEL_LogEntry extends SEL_Base
{
	/**
	 * @description Field set name used for testing purposes.
	 */
	@TestVisible
	private static final String FIELD_SET_TEST = UTIL_System.getManagedPackageNamespacePrefix() + 'Test';

	/**
	 * @description The default HAVING floor when the caller passes a non-positive minOccurrences — keeps
	 * one-off errors out of the derived problems view.
	 */
	private static final Integer DEFAULT_MINIMUM_OCCURRENCES = 2;

	/**
	 * @description The default LIMIT on derived signatures when the caller passes a non-positive groupCap.
	 */
	private static final Integer DERIVED_GROUP_CAP = 2000;

	/**
	 * @description Ceiling on the rows one batched representative read may return. A problems page holds at
	 * most its page-size derived signatures and each pinned newest instant usually holds one row, so this
	 * only bites when many rows share one newest second. The rows order newest instant first, so an
	 * overflow crowds out the signatures whose newest instants are oldest — their problems keep the fold's
	 * own label, never an error.
	 */
	private static final Integer DERIVED_REPRESENTATIVE_ROW_CEILING = 500;

	/**
	 * @description Ceiling on the signatures one batched representative read pins. Every signature
	 * contributes one OR branch to the query, so an unbounded list could grow the statement itself past
	 * the platform's query-length limit; a signature beyond the ceiling is simply not resolved and its
	 * problem keeps the fold's own label. Far above any page the console requests (its pages hold 50
	 * problems), so this bites only a hand-crafted oversized page request.
	 */
	private static final Integer DERIVED_REPRESENTATIVE_SIGNATURE_CEILING = 200;

	/**
	 * @description The default LIMIT on the per-source aggregate when the caller passes a non-positive
	 * sourceCap — bounds how many class-method groups are ranked into the all-entries top sources. The
	 * per-level total is a separate, unbounded aggregate, so this cap never affects the total or per-level counts.
	 */
	private static final Integer DEFAULT_SOURCE_CAP = 200;

	/**
	 * @description The maximum number of forensic rows a single correlated trace returns. The trace is
	 * bounded so a pathological correlation cannot return an unbounded result set; the query fetches one row
	 * beyond this cap so the controller can tell an exactly-filled trace from an overflowed one. Paired with
	 * the lean CORRELATION_TRACE_FIELDS projection (no long-text bodies), the bounded read stays heap-safe
	 * even at the cap, which comfortably exceeds a realistic correlation.
	 */
	public static final Integer CORRELATION_TRACE_ROW_CAP = 300;

	/**
	 * @description The lean field projection for the correlated trace — the fields the trace mapper reads
	 * (identity, level, short message, source, execution context, timestamp, and the transaction-tree
	 * linkage) plus the OccurrenceCount__c filter discriminator (forensic vs rollup: counter). It
	 * deliberately omits the long-text bodies (Message__c, StackTrace__c, ContextData__c, Limits__c) the
	 * timeline never shows, so a capped trace of up to a few hundred rows stays well within the heap; the
	 * full bodies are loaded per hop, on demand, when a single entry is focused.
	 */
	private static final List<SObjectField> CORRELATION_TRACE_FIELDS = new List<SObjectField>
	{
			LogEntry__c.Name,
			LogEntry__c.LogLevel__c,
			LogEntry__c.ShortMessage__c,
			LogEntry__c.ClassMethod__c,
			LogEntry__c.LineNumber__c,
			LogEntry__c.ExecutionEvent__c,
			LogEntry__c.CreatedDate,
			LogEntry__c.OccurrenceCount__c,
			LogEntry__c.TransactionId__c,
			LogEntry__c.ParentTransactionId__c,
			LogEntry__c.DurationMs__c
	};

	/**
	 * @description AggregateResult alias for COUNT(Id) — sig-prefixed to avoid any SOQL keyword collision.
	 */
	private static final String ALIAS_OCCURRENCE_COUNT = 'sigCount';

	/**
	 * @description AggregateResult alias for MIN(CreatedDate) — the signature's first-seen timestamp.
	 */
	private static final String ALIAS_FIRST_SEEN = 'sigFirstSeen';

	/**
	 * @description AggregateResult alias for MAX(CreatedDate) — the signature's last-seen timestamp.
	 */
	private static final String ALIAS_LAST_SEEN = 'sigLastSeen';

	/**
	 * @description AggregateResult alias for MAX(ShortMessage__c) — the signature's display label.
	 */
	private static final String ALIAS_LABEL = 'sigLabel';

	/**
	 * @description Constructs a Log Entry selector.
	 *
	 * @example
	 * ```apex
	 * SEL_LogEntry instance = new SEL_LogEntry();
	 * ```
	 */
	public SEL_LogEntry()
	{
		super(LogEntry__c.SObjectType);
	}

	/**
	 * @description Returns the core fields for LogEntry__c queries.
	 *
	 * @return List of LogEntry__c SObjectField tokens
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> result = instance.getFields();
	 * ```
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				LogEntry__c.ClassMethod__c,
				LogEntry__c.ContextData__c,
				LogEntry__c.CorrelationId__c,
				LogEntry__c.DurationMs__c,
				LogEntry__c.ExceptionType__c,
				LogEntry__c.ExecutionEvent__c,
				LogEntry__c.Fingerprint__c,
				LogEntry__c.Limits__c,
				LogEntry__c.LineNumber__c,
				LogEntry__c.LogLevel__c,
				LogEntry__c.Message__c,
				LogEntry__c.Name,
				LogEntry__c.OccurrenceCount__c,
				LogEntry__c.ParentTransactionId__c,
				LogEntry__c.RecordId__c,
				LogEntry__c.RecordLink__c,
				LogEntry__c.ShortMessage__c,
				LogEntry__c.StackTrace__c,
				LogEntry__c.TransactionId__c,
				LogEntry__c.UserId__c,
				LogEntry__c.UserLink__c
		};
	}

	/**
	 * @description Framework-owned sObject selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on framework-owned log records (the framework owns their lifecycle), so USER_MODE
	 * reads would return empty and log observability would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves all LogEntry__c records. Only executes in test context to prevent
	 * full-table scans in production.
	 *
	 * @return List of all LogEntry__c records in test context, empty list in production
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> result = instance.getAll();
	 * ```
	 */
	public List<LogEntry__c> getAll()
	{
		return !Test.isRunningTest() ? new List<LogEntry__c>() : query.toList();
	}

	/**
	 * @description Retrieves all LogEntry__c records ordered by CreatedDate descending. Only executes
	 * in test context to prevent full-table scans in production. Tests that scan for "most-recent"
	 * audit entries (bypass audit, performance logs) iterate this list and `return` on the first
	 * match — explicit DESC ordering makes that semantically correct.
	 *
	 * @return List of all LogEntry__c records ordered most-recent-first in test context, empty list in production
	 *
	 * @example
	 * ```apex
	 * for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
	 * {
	 *     // first match is the most-recent
	 * }
	 * ```
	 */
	public List<LogEntry__c> findAllOrderedByCreatedDateDesc()
	{
		return !Test.isRunningTest() ? new List<LogEntry__c>() : query.addField(LogEntry__c.CreatedDate).orderBy(LogEntry__c.CreatedDate).descending().toList();
	}

	/**
	 * @description Parses the persisted `ContextData__c` JSON envelope and returns the inner
	 * `contextData` map. `LOG_Builder` writes a wrapping `{"contextData": {...}}` shape; tests
	 * call this helper so the wrapper format can evolve without breaking every test that asserts
	 * on the inner context. Returns `null` when the envelope is blank or unparseable.
	 *
	 * @param entry The LogEntry__c row whose `ContextData__c` should be parsed.
	 *
	 * @return The unwrapped inner context map, or `null` when the envelope is blank or unparseable.
	 *
	 * @example
	 * ```apex
	 * Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
	 * Assert.areEqual('BypassEvent', context.get('category'));
	 * ```
	 */
	@TestVisible
	private static Map<String, Object> parseContextDataForTest(LogEntry__c entry)
	{
		if(entry == null || String.isBlank(entry.ContextData__c))
		{
			return null;
		}
		Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(entry.ContextData__c);
		return (Map<String, Object>)envelope.get('contextData');
	}

	/**
	 * @description Retrieves a single LogEntry__c record matching the specified class method name.
	 *
	 * @param classMethodName The class method name to filter by (e.g., 'MyClass.myMethod')
	 *
	 * @return The matching LogEntry__c record, or null if not found
	 *
	 * @example
	 * ```apex
	 * LogEntry__c log = new SEL_LogEntry().findByMethod('MyClass.myMethod');
	 * ```
	 */
	public LogEntry__c findByMethod(String classMethodName)
	{
		return (LogEntry__c)findFirstByField(LogEntry__c.ClassMethod__c, classMethodName?.trim());
	}

	/**
	 * @description Retrieves all LogEntry__c records matching the specified class method name.
	 *
	 * @param classMethodName The class method name to filter by
	 *
	 * @return List of matching LogEntry__c records
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod('MyClass.myMethod');
	 * ```
	 */
	public List<LogEntry__c> findAllByMethod(String classMethodName)
	{
		return findByField(LogEntry__c.ClassMethod__c, classMethodName?.trim());
	}

	/**
	 * @description Retrieves the first LogEntry__c for a class method whose ShortMessage or
	 * Message contains the `UTIL_PerformanceTimer` needle (`'completed in'`). Intended for
	 * tests that need to assert a performance log was emitted for a specific method.
	 *
	 * @param classMethodName The class method name to filter by (e.g., `'MyClass.myMethod'`)
	 *
	 * @return The first matching performance LogEntry__c, or null if none found
	 *
	 * @example
	 * ```apex
	 * LogEntry__c log = new SEL_LogEntry().findPerformanceLogByMethod('MyClass.myMethod');
	 * ```
	 */
	public LogEntry__c findPerformanceLogByMethod(String classMethodName)
	{
		for(LogEntry__c log : findAllByMethod(classMethodName))
		{
			if((log.ShortMessage__c != null && log.ShortMessage__c.contains('completed in')) ||
					(log.Message__c != null && log.Message__c.contains('completed in')))
			{
				return log;
			}
		}
		return null;
	}

	/**
	 * @description Retrieves all LogEntry__c records matching a specified logging level.
	 *
	 * @param loggingLevel The logging level to filter by (e.g., 'Error', 'Warning', 'Info')
	 *
	 * @return List of matching LogEntry__c records
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> errorLogs = new SEL_LogEntry().findByLogLevel('Error');
	 * ```
	 */
	public List<LogEntry__c> findByLogLevel(String loggingLevel)
	{
		return findByField(LogEntry__c.LogLevel__c, loggingLevel);
	}

	/**
	 * @description Returns the count of LogEntry__c records.
	 *
	 * @return Total count of LogEntry__c records
	 *
	 * @example
	 * ```apex
	 * Integer result = instance.getRecordCount();
	 * ```
	 */
	public Integer getRecordCount()
	{
		return count();
	}

	/**
	 * @description Returns log entries whose `Fingerprint__c` exactly matches one of the supplied
	 * keys (`detail:` and/or `rollup:` prefixed). Equality IN on the unique external-ID index —
	 * selective by construction, safe on the production hot path (used at log persist time for
	 * fingerprint presence checks and rollup-count reads).
	 *
	 * @param fingerprints The exact fingerprint key values to find.
	 *
	 * @return Matching LogEntry__c rows, or an empty list for blank input.
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> rows = new SEL_LogEntry().findByFingerprints(new Set<String> {'detail:my-key'});
	 * ```
	 */
	public List<LogEntry__c> findByFingerprints(Set<String> fingerprints)
	{
		return fingerprints?.isEmpty() == false
				? query.condition(LogEntry__c.Fingerprint__c).isIn(new List<String>(fingerprints)).toList()
				: new List<LogEntry__c>();
	}

	/**
	 * @description Returns a paged, filtered list of forensic log entries (detail: samples and plain
	 * rows), excluding the rollup: counter rows (which carry OccurrenceCount__c). Sharing is bypassed and
	 * the selector runs in SYSTEM_MODE so the read spans every user's framework-owned log rows regardless
	 * of the caller's sharing.
	 *
	 * @param criteria The browse filters (level, context, user, search, correlation, date window).
	 * @param sortField The field to order by.
	 * @param sortDescending True to order descending.
	 * @param page The 1-based page number.
	 * @param pageSize The number of rows per page.
	 *
	 * @return A QRY_Builder.QueryPage of LogEntry__c rows with pagination metadata.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.QueryPage page = new SEL_LogEntry().findEntriesFiltered(criteria, LogEntry__c.CreatedDate, true, 1, 50);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters')
	public QRY_Builder.QueryPage findEntriesFiltered(BrowseCriteria criteria, SObjectField sortField, Boolean sortDescending, Integer page, Integer pageSize)
	{
		QRY_Builder.Builder filteredQuery = query.bypassSharingInternal().condition(LogEntry__c.OccurrenceCount__c).isNull();
		filteredQuery = applyCriteria(filteredQuery, criteria);
		return filteredQuery.orderBy(sortField, sortDescending, sortDescending).getPage(page, pageSize);
	}

	/**
	 * @description Fetches the detail: sample rows for an exact set of full detail keys
	 * ('detail:<base>'). Window-free by design: the distinct list is scoped by in-window rollup
	 * activity, then the samples are fetched by key, so a long-lived problem still firing in the
	 * window is never hidden by its frozen first-seen CreatedDate. Exact-equality IN on the unique
	 * Fingerprint__c index — selective and fast.
	 *
	 * @param detailKeys The full 'detail:<base>' keys to fetch.
	 *
	 * @return The matching sample rows (CreatedDate selected for display), or an empty list for blank input.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> sampleRows = new SEL_LogEntry().findSamplesByBaseFingerprints(new Set<String> {'detail:my-key'});
	 * ```
	 */
	public List<LogEntry__c> findSamplesByBaseFingerprints(Set<String> detailKeys)
	{
		return detailKeys?.isEmpty() == false
				? query.bypassSharingInternal()
						.addField(LogEntry__c.CreatedDate)
						.condition(LogEntry__c.Fingerprint__c).isIn(new List<String>(detailKeys))
						.toList()
				: new List<LogEntry__c>();
	}

	/**
	 * @description Returns the rollup: counter rows (Fingerprint__c LIKE 'rollup:%') in the window, each
	 * carrying OccurrenceCount__c. Each key has the shape 'rollup:<base>:<yyyyMMdd>', so a caller can strip
	 * it to the base fingerprint and fold SUM(OccurrenceCount__c) / MIN(CreatedDate) / MAX(LastModifiedDate)
	 * per signature. CreatedDate and LastModifiedDate are selected for the first-seen / last-seen fold.
	 * The read is bounded at maximumRows plus one probe row (mirroring the correlated-trace cap probe), so
	 * a caller can tell an exactly-filled candidate set from an overflowed one by the one extra row and
	 * flag its folded totals best-effort instead of silently under-reporting.
	 *
	 * @param criteria The browse filters.
	 * @param maximumRows The maximum number of candidate rows to fold; one extra probe row is fetched.
	 *
	 * @return Up to maximumRows plus one rollup: rows (newest first), with CreatedDate and LastModifiedDate selected.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> rollupRows = new SEL_LogEntry().findRollupRowsInWindow(criteria, 5000);
	 * ```
	 */
	public List<LogEntry__c> findRollupRowsInWindow(BrowseCriteria criteria, Integer maximumRows)
	{
		QRY_Builder.Builder filteredQuery = query.bypassSharingInternal()
				.condition(LogEntry__c.Fingerprint__c).startsWith(TRG_PersistLogEntry.PREFIX_ROLLUP)
				.addField(LogEntry__c.LastModifiedDate);
		filteredQuery = applyCriteria(filteredQuery, criteria);
		return filteredQuery.orderBy(LogEntry__c.CreatedDate, true, true).withLimit(maximumRows + 1).toList();
	}

	/**
	 * @description Returns a single LogEntry__c by Id with CreatedDate and LastModifiedDate selected and
	 * sharing bypassed so the read returns the row regardless of its owner.
	 *
	 * @param entryId The LogEntry__c Id.
	 *
	 * @return The row, or null when not found.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * LogEntry__c row = new SEL_LogEntry().findByIdForConsole(entryId);
	 * ```
	 */
	public LogEntry__c findByIdForConsole(Id entryId)
	{
		return (LogEntry__c)query.bypassSharingInternal()
				.addField(LogEntry__c.CreatedDate)
				.addField(LogEntry__c.LastModifiedDate)
				.condition(LogEntry__c.Id).equals(entryId)
				.getFirst();
	}

	/**
	 * @description Returns the forensic log rows (OccurrenceCount__c null) sharing one CorrelationId__c,
	 * ordered by CreatedDate ascending so the rows are returned in the order they occurred. The rollup:
	 * counter rows are excluded by the OccurrenceCount__c is-null condition. Sharing is bypassed and the
	 * selector runs in SYSTEM_MODE so the read spans every user's framework-owned log rows regardless of
	 * the caller's sharing; a lean projection (CORRELATION_TRACE_FIELDS — no long-text bodies) is selected so
	 * a capped trace stays heap-safe. The result is bounded at CORRELATION_TRACE_ROW_CAP plus one row, so a
	 * pathological correlation cannot return an unbounded result set and the caller can detect the overflow
	 * by the one extra row.
	 *
	 * @param correlationId The CorrelationId__c tying the rows to one logical operation.
	 *
	 * @return The correlated forensic rows ordered first-to-last, bounded at the row cap plus one, or an
	 * empty list for blank input.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> trace = new SEL_LogEntry().findByCorrelationIdOrdered('a1b2c3d4');
	 * ```
	 */
	public List<LogEntry__c> findByCorrelationIdOrdered(String correlationId)
	{
		return String.isNotBlank(correlationId)
				? query.onlyFields(CORRELATION_TRACE_FIELDS)
						.systemModeInternal()
						.bypassSharingInternal()
						.condition(LogEntry__c.OccurrenceCount__c).isNull()
						.andCondition(LogEntry__c.CorrelationId__c).equals(correlationId)
						.orderBy(LogEntry__c.CreatedDate, false, false)
						.withLimit(CORRELATION_TRACE_ROW_CAP + 1)
						.toList()
				: new List<LogEntry__c>();
	}

	/**
	 * @description The NEWEST forensic rows referencing a chain execution — by its correlation id,
	 * by a direct record reference, or both. This is the stream seed's read: a chain launched from
	 * a transaction with no active log correlation still logs with its record id stamped, so the
	 * record leg keeps those runs' entries seedable while the correlation leg spans the full trace.
	 * The OR is not expressible as one grouped fluent query, so this follows the selector's two-leg
	 * pattern (findIdsBySearch): each leg collects its newest candidate ids, and one bounded fetch
	 * orders the union newest-first — ties broken by Id, a deterministic tiebreak that makes
	 * "newest" witnessable for same-timestamp rows. Same posture as the correlated-trace read:
	 * system mode with sharing bypassed (the Log Console pairing — the trace must span every
	 * user's framework-owned rows, and through the record leg that includes subscriber-authored
	 * entries that reference the chain execution), the lean trace projection, forensic rows only.
	 *
	 * @param correlationId The chain's correlation id; blank skips the correlation leg.
	 * @param recordId The chain execution record id; null skips the record leg.
	 * @param rowLimit The per-leg and final row cap.
	 *
	 * @return The newest matching rows, NEWEST FIRST, capped at rowLimit; empty when both legs skip.
	 *
	 * @date August 2026
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> rows = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(correlationId, executionId, 20);
	 * ```
	 */
	public List<LogEntry__c> findNewestByCorrelationIdOrRecordId(String correlationId, Id recordId, Integer rowLimit)
	{
		Set<Object> candidateIds = new Set<Object>();
		if(String.isNotBlank(correlationId))
		{
			candidateIds.addAll(findNewestReferencingEntryIds(LogEntry__c.CorrelationId__c, correlationId, rowLimit));
		}
		if(recordId != null)
		{
			candidateIds.addAll(findNewestReferencingEntryIds(LogEntry__c.RecordId__c, recordId, rowLimit));
		}
		return candidateIds.isEmpty()
				? new List<LogEntry__c>()
				: query.onlyFields(CORRELATION_TRACE_FIELDS)
						.systemModeInternal()
						.bypassSharingInternal()
						.condition(LogEntry__c.Id).isIn(candidateIds)
						.orderBy(LogEntry__c.CreatedDate, true, false)
						.orderBy(LogEntry__c.Id, true, false)
						.withLimit(rowLimit)
						.toList();
	}

	/**
	 * @description One leg of findNewestByCorrelationIdOrRecordId's two-leg union read: the Ids of
	 * the NEWEST forensic rows (OccurrenceCount__c null) whose reference field equals the given
	 * value. The projection is Id-only because the caller re-fetches the union with the trace
	 * projection; ordering (CreatedDate descending, Id tiebreak) and the row cap match the caller's
	 * final fetch so each leg contributes exactly its own newest rows.
	 *
	 * @param referenceField The LogEntry__c field tying an entry to the chain (CorrelationId__c or RecordId__c).
	 * @param referenceValue The value the reference field must equal.
	 * @param rowLimit The per-leg row cap.
	 *
	 * @return The leg's entry Ids, newest first, capped at the row limit.
	 *
	 * @example
	 * ```apex
	 * List<Object> entryIds = findNewestReferencingEntryIds(LogEntry__c.CorrelationId__c, correlationId, 20);
	 * ```
	 */
	private List<Object> findNewestReferencingEntryIds(SObjectField referenceField, Object referenceValue, Integer rowLimit)
	{
		List<Object> entryIds = new List<Object>();
		for(SObject row : query.onlyFields(new List<SObjectField> {LogEntry__c.Id})
				.systemModeInternal()
				.bypassSharingInternal()
				.condition(LogEntry__c.OccurrenceCount__c).isNull()
				.andCondition(referenceField).equals(referenceValue)
				.orderBy(LogEntry__c.CreatedDate, true, false)
				.orderBy(LogEntry__c.Id, true, false)
				.withLimit(rowLimit)
				.toList())
		{
			entryIds.add(row.Id);
		}
		return entryIds;
	}

	/**
	 * @description SOQL search leg — the Ids of forensic rows (OccurrenceCount__c null) whose
	 * ShortMessage__c OR CorrelationId__c contains the free-text term, within the given window and
	 * filters. Both fields are matched with SOQL, so a just-written short message or correlation id is
	 * matched immediately with no search-index lag. The term came from a person, so it is matched
	 * character for character (QRY_Condition.FieldCondition.containsLiteral): a term holding % or _ finds
	 * that text rather than standing in for any run of characters or any single one. Runs as two filtered
	 * queries combined by Id; the field fetch stays in findSortedPageByIds so the legs only ever return Ids.
	 *
	 * @param term The free-text search term; blank returns an empty set.
	 * @param criteria The browse filters (level, context, user, correlation, window); its own searchTerm is
	 * ignored (the term parameter defines the text scope), but the correlation id is honoured, so a
	 * Chain-Monitor deep-link keeps its scope when a search term is added.
	 * @param maximumRows The per-leg row cap.
	 *
	 * @return The matching forensic-row Ids (short-message ∪ correlation-id matches).
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * Set<Id> ids = new SEL_LogEntry().findIdsBySearch('timeout', criteria, 2000);
	 * ```
	 */
	public Set<Id> findIdsBySearch(String term, BrowseCriteria criteria, Integer maximumRows)
	{
		Set<Id> ids = new Set<Id>();
		if(String.isBlank(term))
		{
			return ids;
		}
		BrowseCriteria scope = searchScope(criteria);
		List<LogEntry__c> shortMessageRows = applyCriteria(query.bypassSharingInternal().condition(LogEntry__c.OccurrenceCount__c).isNull(), scope)
				.addCondition(new QRY_Condition.FieldCondition(LogEntry__c.ShortMessage__c).containsLiteral(term)).withLimit(maximumRows).toList();
		for(LogEntry__c row : shortMessageRows)
		{
			ids.add(row.Id);
		}
		List<LogEntry__c> correlationRows = applyCriteria(query.bypassSharingInternal().condition(LogEntry__c.OccurrenceCount__c).isNull(), scope)
				.addCondition(new QRY_Condition.FieldCondition(LogEntry__c.CorrelationId__c).containsLiteral(term)).withLimit(maximumRows).toList();
		for(LogEntry__c row : correlationRows)
		{
			ids.add(row.Id);
		}
		return ids;
	}

	/**
	 * @description SOSL search leg — the Ids of forensic rows (OccurrenceCount__c null) whose body
	 * (Message__c, StackTrace__c, any text field) matches the term via a full-text IN ALL FIELDS search.
	 * Complements findIdsBySearch: SOQL LIKE on the long-text Message__c/StackTrace__c is not
	 * indexed, so the body search goes through the search index here. The filters are conditional, so the
	 * SOSL is assembled dynamically (the free-text term binds as `:term`, so it is injection-safe without
	 * manual escaping) and run with `Search.query` in `AccessLevel.SYSTEM_MODE` from a `without sharing`
	 * runner. `AccessLevel.SYSTEM_MODE` governs field-level security but leaves record sharing to the
	 * executing class, so the dedicated `without sharing` runner is what makes the body leg span every user's
	 * rows, matching the SOQL search legs (which bypass sharing via QRY_Builder) — consistent with this
	 * selector's system-mode contract. Namespace-robust: object and field API names come from the describe cache.
	 *
	 * @param term The free-text term; blank or under two characters returns an empty set (SOSL minimum).
	 * @param criteria The browse filters applied inside the RETURNING clause.
	 * @param maximumRows The RETURNING row cap.
	 *
	 * @return The matching forensic-row Ids from the body search.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * Set<Id> ids = new SEL_LogEntry().findIdsByBodySosl('NullPointer', criteria, 2000);
	 * ```
	 */
	@SuppressWarnings('ApexMethodCanBeStatic')
	public Set<Id> findIdsByBodySosl(String term, BrowseCriteria criteria, Integer maximumRows)
	{
		if(String.isBlank(term) || term.trim().length() < 2)
		{
			return new Set<Id>();
		}
		return new BodySearchRunner().findMatchingIds(term, criteria, maximumRows);
	}

	/**
	 * @description Runs the raw dynamic body-search SOSL without sharing, so the body leg spans every user's
	 * framework-owned log rows exactly as the SOQL search legs do. `AccessLevel.SYSTEM_MODE` on `Search.query`
	 * governs field-level security only and leaves record sharing to the executing class, so this dedicated
	 * `without sharing` runner is what bypasses sharing for the body search — without it, an org-wide default
	 * more restrictive than Public would silently return a smaller Id set from the body leg than from the
	 * SOQL legs for the same term.
	 *
	 * @date July 2026
	 */
	private without sharing class BodySearchRunner
	{
		/**
		 * @description Executes the body-search SOSL and returns the matching forensic-row Ids. The term is
		 * bound as `:term` (injection-safe); the caller has already applied the blank/length guard.
		 *
		 * @param term The free-text term, bound as `:term`.
		 * @param criteria The browse filters applied inside the RETURNING WHERE clause.
		 * @param maximumRows The RETURNING row cap.
		 *
		 * @return The matching forensic-row Ids from the body search.
		 *
		 * @date July 2026
		 */
		private Set<Id> findMatchingIds(String term, BrowseCriteria criteria, Integer maximumRows)
		{
			Set<Id> ids = new Set<Id>();
			String sosl = 'FIND :term IN ALL FIELDS RETURNING ' + String.valueOf(LogEntry__c.SObjectType)
					+ '(' + fieldName(LogEntry__c.Id) + ' WHERE ' + buildSoslWhere(criteria)
					+ ' ORDER BY ' + fieldName(LogEntry__c.CreatedDate) + ' DESC LIMIT ' + maximumRows + ')';
			List<List<SObject>> results = Search.query(sosl, AccessLevel.SYSTEM_MODE);
			if(!results.isEmpty())
			{
				for(SObject row : results[0])
				{
					ids.add(row.Id);
				}
			}
			return ids;
		}
	}

	/**
	 * @description Returns one sorted, server-side-paged QRY_Builder.QueryPage of the rows matching an
	 * exact set of Ids, with CreatedDate selected. Keeps the heavy field projection in one place so callers
	 * that resolved a candidate id set elsewhere only fetch the requested page. Sharing is bypassed so the
	 * read spans rows regardless of owner. An empty or null id set yields an empty page, never an unbounded
	 * query.
	 *
	 * @param recordIds The Ids to fetch.
	 * @param sortField The field to order by.
	 * @param sortDescending True to order descending.
	 * @param page The 1-based page number.
	 * @param pageSize The number of rows per page.
	 *
	 * @return A sorted, paged QueryPage of the matching rows.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.QueryPage page = new SEL_LogEntry().findSortedPageByIds(ids, LogEntry__c.CreatedDate, true, 1, 50);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters')
	public QRY_Builder.QueryPage findSortedPageByIds(Set<Id> recordIds, SObjectField sortField, Boolean sortDescending, Integer page, Integer pageSize)
	{
		QRY_Builder.Builder builder = query.bypassSharingInternal().addField(LogEntry__c.CreatedDate);
		builder = recordIds == null || recordIds.isEmpty()
				? builder.condition(LogEntry__c.Id).isNull()
				: builder.condition(LogEntry__c.Id).isIn(new List<Id>(recordIds));
		return builder.orderBy(sortField, sortDescending, sortDescending).getPage(page, pageSize);
	}

	/**
	 * @description Folds the plain forensic rows (OccurrenceCount__c null, Fingerprint__c null) in the
	 * window into derived problem signatures: a read-time GROUP BY on (ExceptionType__c, ClassMethod__c,
	 * LogLevel__c) that gives an org an immediate "this error x N" Problems view with no
	 * fingerprinting. Only rows carrying an ExceptionType__c or a ClassMethod__c are folded, so structureless
	 * logs never collapse into one unattributed mega-group. The throw-site line number is not part of the key
	 * (Number fields are not groupable in SOQL, and line numbers shift across deploys), so same-signature rows
	 * at different lines fold together while the COUNT stays exact server-side at any volume. The fold is one
	 * builder query — aliased aggregates (COUNT + MIN/MAX CreatedDate + a ShortMessage label) ranked by
	 * orderByCount — running under bypassSharingInternal(), the single OWD-independent posture every console
	 * read shares, so a console admin still reads every user's framework-owned rows regardless of the
	 * org-wide default.
	 *
	 * @param criteria The browse filters; the CreatedDate window and the shared execution-context, user,
	 * correlation and source scopes are applied (the level scope is the dedicated levels parameter, and a
	 * free-text search suppresses this leg upstream).
	 * @param groupCap The maximum number of signatures to return (LIMIT); a non-positive value falls back to the default cap.
	 * @param minOccurrences The HAVING floor; a signature with fewer occurrences is excluded. A non-positive value falls back to the default floor.
	 * @param levels The log levels to fold; null or empty applies no level scope.
	 *
	 * @return The folded signatures ordered by occurrence count descending, capped at groupCap.
	 *
	 * @date June 2026, August 2026
	 *
	 * @example
	 * ```apex
	 * List<SEL_LogEntry.DerivedSignature> problems = new SEL_LogEntry().foldDerivedSignaturesInWindow(criteria, 2000, 2, new List<String> {'ERROR', 'WARN'});
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public List<DerivedSignature> foldDerivedSignaturesInWindow(BrowseCriteria criteria, Integer groupCap, Integer minOccurrences, List<String> levels)
	{
		Integer minimumOccurrences = minOccurrences != null && minOccurrences > 0 ? minOccurrences : DEFAULT_MINIMUM_OCCURRENCES;
		Integer cap = groupCap != null && groupCap > 0 ? groupCap : DERIVED_GROUP_CAP;
		QRY_Builder.Builder builder = applyDerivedFoldPredicate(query.bypassSharingInternal()
				.count(LogEntry__c.Id, ALIAS_OCCURRENCE_COUNT)
				.min(LogEntry__c.CreatedDate, ALIAS_FIRST_SEEN)
				.max(LogEntry__c.CreatedDate, ALIAS_LAST_SEEN)
				.max(LogEntry__c.ShortMessage__c, ALIAS_LABEL), criteria, levels);

		List<DerivedSignature> signatures = new List<DerivedSignature>();
		for(QRY_Builder.AggregateRow row : builder
				.groupBy(LogEntry__c.ExceptionType__c)
				.groupBy(LogEntry__c.ClassMethod__c)
				.groupBy(LogEntry__c.LogLevel__c)
				.havingCountOf(LogEntry__c.Id).greaterThanOrEquals(minimumOccurrences)
				.orderByCount(LogEntry__c.Id, true)
				.withLimit(cap)
				.toAggregateList())
		{
			signatures.add(decodeDerivedSignature(row));
		}
		return signatures;
	}

	/**
	 * @description Counts the rows a derived fold over the same window would have to scan, so a caller can
	 * decline the fold before issuing it rather than discovering the cost by failing. A GROUP BY consumes
	 * query rows equal to the rows SCANNED, not the groups returned, and exhausting that governor raises a
	 * limit exception — which Apex cannot catch, so the fold's own degrade path cannot absorb it. This count
	 * is a COUNT() query and so costs a constant handful of query rows however wide the window is. Its
	 * predicate is the fold's own, applied through the same helper, so the number can never describe a
	 * different population than the fold would scan.
	 *
	 * @param criteria The browse filters; the CreatedDate window and the shared execution-context, user,
	 * correlation and source scopes are applied. Null applies no window or scope.
	 * @param levels The level scope; null or empty counts every level.
	 *
	 * @return The number of foldable rows the window holds.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * Integer scanSize = new SEL_LogEntry().countFoldableRowsInWindow(criteria, new List<String> {'ERROR'});
	 * ```
	 */
	public Integer countFoldableRowsInWindow(BrowseCriteria criteria, List<String> levels)
	{
		return applyDerivedFoldPredicate(query.bypassSharingInternal(), criteria, levels).count();
	}

	/**
	 * @description Applies the derived fold's row predicate to a builder: plain forensic rows only
	 * (OccurrenceCount__c and Fingerprint__c null), the attribution guard that keeps structureless rows out
	 * of the fold, the level scope, the CreatedDate window, and the shared execution-context, user,
	 * correlation and source scopes. Single-sourced so the fold and the pre-flight count that guards it cannot drift
	 * apart — a count taken over a different population than the fold scans would be worse than no guard,
	 * because it would read as a safety check while sizing the wrong query.
	 *
	 * @param builder The builder to extend; the caller applies any aggregate selection first.
	 * @param criteria The browse filters. Null applies no window or scope.
	 * @param levels The level scope; null or empty applies no level filter.
	 *
	 * @return The builder with the fold's predicate applied.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.Builder scoped = applyDerivedFoldPredicate(query.bypassSharingInternal(), criteria, levels);
	 * ```
	 */
	private static QRY_Builder.Builder applyDerivedFoldPredicate(QRY_Builder.Builder builder, BrowseCriteria criteria, List<String> levels)
	{
		QRY_Builder.Builder scoped = builder
				.condition(LogEntry__c.OccurrenceCount__c).isNull()
				.andCondition(LogEntry__c.Fingerprint__c).isNull()
				.addCondition(new QRY_Condition.OrCondition()
						.add(new QRY_Condition.FieldCondition(LogEntry__c.ExceptionType__c).notEquals(null))
						.add(new QRY_Condition.FieldCondition(LogEntry__c.ClassMethod__c).notEquals(null)));
		if(levels?.isEmpty() == false)
		{
			scoped = scoped.andCondition(LogEntry__c.LogLevel__c).isIn(levels);
		}
		if(criteria?.windowStart != null)
		{
			scoped = scoped.andCondition(LogEntry__c.CreatedDate).greaterThanOrEquals(criteria.windowStart);
		}
		if(criteria?.windowEnd != null)
		{
			scoped = scoped.andCondition(LogEntry__c.CreatedDate).lessThanOrEquals(criteria.windowEnd);
		}
		return applyDerivedScope(scoped, criteria);
	}

	/**
	 * @description Fetches one openable forensic row representing a derived signature: the most-recent
	 * occurrence (CreatedDate descending, newest row Id breaking a same-second tie) matching the
	 * signature's exception type, class method and log level (a null identity field matches IS NULL),
	 * within the criteria's window and its shared execution-context, user, correlation and source
	 * scopes — the same scope the fold that built the problem covered, so the opened row is always one
	 * the subscriber's filtered view actually counted. Returns null when every occurrence has been purged
	 * between the fold and the click, so the caller can fall back to the signature's label text. Like the
	 * fold and every other console read, the lookup bypasses sharing so it spans every user's
	 * framework-owned rows regardless of the org-wide default.
	 *
	 * @param signature The derived signature whose identity fields key the lookup; null returns null.
	 * @param criteria The browse filters; the CreatedDate window and the shared execution-context, user,
	 * correlation and source scopes are applied. Null applies no scope.
	 *
	 * @return The representative row with CreatedDate selected, or null when none matches.
	 *
	 * @date June 2026, August 2026
	 *
	 * @example
	 * ```apex
	 * LogEntry__c representative = new SEL_LogEntry().findDerivedRepresentative(signature, criteria);
	 * ```
	 */
	public LogEntry__c findDerivedRepresentative(DerivedSignature signature, BrowseCriteria criteria)
	{
		if(signature == null)
		{
			return null;
		}
		QRY_Builder.Builder builder = query.bypassSharingInternal()
				.addField(LogEntry__c.CreatedDate)
				.condition(LogEntry__c.OccurrenceCount__c).isNull()
				.andCondition(LogEntry__c.Fingerprint__c).isNull();
		builder = applyDerivedIdentity(builder, LogEntry__c.ExceptionType__c, signature.exceptionType);
		builder = applyDerivedIdentity(builder, LogEntry__c.ClassMethod__c, signature.classMethod);
		builder = applyDerivedIdentity(builder, LogEntry__c.LogLevel__c, signature.logLevel);
		if(criteria?.windowStart != null)
		{
			builder = builder.andCondition(LogEntry__c.CreatedDate).greaterThanOrEquals(criteria.windowStart);
		}
		if(criteria?.windowEnd != null)
		{
			builder = builder.andCondition(LogEntry__c.CreatedDate).lessThanOrEquals(criteria.windowEnd);
		}
		builder = applyDerivedScope(builder, criteria);
		return (LogEntry__c)builder.orderBy(LogEntry__c.CreatedDate, true, true).orderBy(LogEntry__c.Id, true, true).getFirst();
	}

	/**
	 * @description Fetches the newest-instant forensic rows for a whole page of derived signatures in one
	 * query, so the problems list can label every derived row with the message of the same member the drawer
	 * resolves — the newest occurrence — instead of the fold's alphabetical MAX(ShortMessage__c). Each
	 * signature contributes one OR branch pinning its three identity fields (a null identity matches only
	 * null) AND its folded MAX(CreatedDate) instant, so the read returns roughly one row per signature
	 * however wide the window is. Rows tied on an instant order newest Id first — the tie-break
	 * findDerivedRepresentative applies — so a caller keeping the first row matching each signature lands
	 * on the same member the drawer opens. The window bounds are deliberately not re-applied: a signature's
	 * lastSeen lies inside the fold's window by construction and every same-instant row shares it, so the
	 * pin is already the tighter bound. The shared execution-context, user, correlation and source scopes
	 * are applied through the same helper the fold uses, and the read runs under bypassSharingInternal(),
	 * the single OWD-independent posture every console read shares. The read bounds itself on both axes:
	 * at most DERIVED_REPRESENTATIVE_SIGNATURE_CEILING signatures are pinned (the branch list is what
	 * sizes the query statement) and at most DERIVED_REPRESENTATIVE_ROW_CEILING rows return; past either
	 * ceiling a problem keeps the fold's own label rather than erroring.
	 *
	 * @param signatures The folded signatures to resolve, each carrying the lastSeen instant the fold
	 * projected; null or empty returns an empty list.
	 * @param criteria The browse filters; the shared execution-context, user, correlation and source scopes
	 * are applied. Null applies no scope.
	 *
	 * @return The newest-instant rows, newest first (CreatedDate then Id, both descending), capped at
	 * DERIVED_REPRESENTATIVE_ROW_CEILING; empty when none match.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * List<LogEntry__c> representatives = new SEL_LogEntry().findDerivedRepresentatives(signatures, criteria);
	 * ```
	 */
	public List<LogEntry__c> findDerivedRepresentatives(List<DerivedSignature> signatures, BrowseCriteria criteria)
	{
		if(signatures == null || signatures.isEmpty())
		{
			return new List<LogEntry__c>();
		}
		QRY_Condition.OrCondition newestInstantPerSignature = new QRY_Condition.OrCondition();
		for(Integer position = 0; position < Math.min(signatures.size(), DERIVED_REPRESENTATIVE_SIGNATURE_CEILING); position++)
		{
			DerivedSignature signature = signatures[position];
			newestInstantPerSignature.add(new QRY_Condition.AndCondition()
					.add(new QRY_Condition.FieldCondition(LogEntry__c.ExceptionType__c).equals(signature.exceptionType))
					.add(new QRY_Condition.FieldCondition(LogEntry__c.ClassMethod__c).equals(signature.classMethod))
					.add(new QRY_Condition.FieldCondition(LogEntry__c.LogLevel__c).equals(signature.logLevel))
					.add(new QRY_Condition.FieldCondition(LogEntry__c.CreatedDate).equals(signature.lastSeen)));
		}
		return applyDerivedScope(query.bypassSharingInternal()
				.addField(LogEntry__c.CreatedDate)
				.condition(LogEntry__c.OccurrenceCount__c).isNull()
				.andCondition(LogEntry__c.Fingerprint__c).isNull()
				.addCondition(newestInstantPerSignature), criteria)
				.orderBy(LogEntry__c.CreatedDate, true, true)
				.orderBy(LogEntry__c.Id, true, true)
				.withLimit(DERIVED_REPRESENTATIVE_ROW_CEILING)
				.toList();
	}

	/**
	 * @description Applies the browse scopes the derived-problem reads share — the execution-context,
	 * user, correlation and source filters — so the fold that builds a derived problem and the
	 * representative lookup that opens it always cover the same rows, and a problems view under an active
	 * source pill folds only that source rather than rendering a filter chip its own list ignores. The
	 * free-text search is deliberately absent (it suppresses the derived leg upstream — a long-text body
	 * cannot traverse a GROUP BY), and the level scope travels separately (the fold takes a levels list;
	 * the representative matches the signature's own level).
	 *
	 * @param builder The derived-read builder under construction.
	 * @param criteria The browse filters, or null for no scope.
	 *
	 * @return The builder with the shared scope applied.
	 */
	private static QRY_Builder.Builder applyDerivedScope(QRY_Builder.Builder builder, BrowseCriteria criteria)
	{
		QRY_Builder.Builder scoped = builder;
		if(criteria?.executionEvents?.isEmpty() == false)
		{
			scoped = scoped.andCondition(LogEntry__c.ExecutionEvent__c).isIn(criteria.executionEvents);
		}
		if(String.isNotBlank(criteria?.userId))
		{
			scoped = scoped.andCondition(LogEntry__c.UserId__c).equals(criteria.userId);
		}
		if(String.isNotBlank(criteria?.correlationId))
		{
			scoped = scoped.andCondition(LogEntry__c.CorrelationId__c).equals(criteria.correlationId);
		}
		if(String.isNotBlank(criteria?.classMethod))
		{
			scoped = scoped.andCondition(LogEntry__c.ClassMethod__c).equals(criteria.classMethod);
		}
		return scoped;
	}

	/**
	 * @description Folds the forensic rows (OccurrenceCount__c null) in the window into the all-entries ribbon
	 * aggregate: the per-level row counts and the per-source row counts. Two builder aggregate queries run
	 * under bypassSharingInternal() — the single OWD-independent posture every console read shares — so the
	 * counts span every user's rows regardless of the org-wide default and the non-search ribbon can never
	 * undercount against the sharing-bypassed entries table beneath it. The per-level leg is unbounded (a
	 * handful of levels) so the total is exact; the per-source leg is ranked by orderByCount descending and
	 * capped at sourceCap so the caller reads the top sources. The free-text search is matched against
	 * ShortMessage__c or CorrelationId__c (the immediate, index-lag-free SOQL leg); body-only matches surfaced
	 * by the entries SOSL leg are not reflected in this aggregate.
	 *
	 * @param criteria The browse filters (level, context, user, correlation, search, date window).
	 * @param sourceCap The LIMIT on the per-source aggregate; a non-positive value falls back to the default cap.
	 *
	 * @return The per-level and per-source forensic row counts.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesInWindow(criteria, 200);
	 * ```
	 */
	public EntryAggregate summariseEntriesInWindow(BrowseCriteria criteria, Integer sourceCap)
	{
		Integer cap = sourceCap != null && sourceCap > 0 ? sourceCap : DEFAULT_SOURCE_CAP;
		return decodeEntryAggregate(foldLevelCounts(buildWindowScope(criteria)), foldSourceCounts(buildWindowScope(criteria), cap));
	}

	/**
	 * @description The all-entries ribbon aggregate over an exact set of forensic-row Ids: the per-level and
	 * per-source row counts folded over `Id IN :recordIds`, so the ribbon can be computed over the SAME matched
	 * set the entries table pages under a search term (SOQL short-message/correlation ∪ SOSL body). That keeps
	 * the ribbon totals equal to the table for every term, including body-only matches the LIKE-only aggregate
	 * misses. An empty or null id set yields an empty aggregate, never an unbounded query. Runs under
	 * bypassSharingInternal() so the counts span every user's rows exactly as the id set was gathered.
	 *
	 * @param recordIds The forensic-row Ids to aggregate over.
	 * @param sourceCap The LIMIT on the per-source aggregate; a non-positive value falls back to the default cap.
	 *
	 * @return The per-level and per-source forensic row counts over the id set.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * SEL_LogEntry.EntryAggregate aggregate = new SEL_LogEntry().summariseEntriesByIds(ids, 200);
	 * ```
	 */
	public EntryAggregate summariseEntriesByIds(Set<Id> recordIds, Integer sourceCap)
	{
		if(recordIds == null || recordIds.isEmpty())
		{
			EntryAggregate empty = new EntryAggregate();
			empty.levelCounts = new List<LevelRowCount>();
			empty.sourceCounts = new List<SourceRowCount>();
			return empty;
		}
		Integer cap = sourceCap != null && sourceCap > 0 ? sourceCap : DEFAULT_SOURCE_CAP;
		return decodeEntryAggregate(foldLevelCounts(buildIdScope(recordIds)), foldSourceCounts(buildIdScope(recordIds), cap));
	}

	/**
	 * @description Counts the forensic rows the windowed ribbon aggregate would have to scan, so a caller can
	 * decline the two-legged summary before issuing it rather than discovering the cost by failing. A GROUP BY
	 * consumes query rows equal to the rows SCANNED, not the groups returned, the ribbon folds two of them over
	 * the same scope, and exhausting the row governor raises a limit exception Apex cannot catch. This count is
	 * a COUNT() query and so costs a constant handful of query rows however wide the window is — and its answer
	 * doubles as the scope's exact total row count, so a declined ribbon can still state how many rows the range
	 * holds. Its predicate is the ribbon's own windowed scope, applied through the same builder helper, so the
	 * number can never describe a different population than the aggregates would scan.
	 *
	 * @param criteria The browse filters (level, context, user, correlation, search, date window).
	 *
	 * @return The number of forensic rows the windowed ribbon scope holds.
	 *
	 * @date August 2026
	 *
	 * @example
	 * ```apex
	 * Integer scanSize = new SEL_LogEntry().countEntriesInWindow(criteria);
	 * ```
	 */
	public Integer countEntriesInWindow(BrowseCriteria criteria)
	{
		return buildWindowScope(criteria).count();
	}

	/**
	 * @description Starts the windowed ribbon-aggregate scope: the forensic-row guard plus every browse
	 * filter, with the free-text term applied as the two-field OR (ShortMessage__c or CorrelationId__c)
	 * that the entries table's SOQL search leg matches — applyCriteria's single-field text match would
	 * silently drop correlation matches from the ribbon. The term is matched character for character, the
	 * same way findIdsBySearch matches it, so the ribbon and the table can never disagree over a term
	 * holding % or _. Runs under bypassSharingInternal() so the counts span every user's rows exactly as
	 * the reads beneath them do.
	 *
	 * @param criteria The browse filters; null applies only the forensic-row guard.
	 *
	 * @return The scoped builder, ready for an aggregate leg.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * List<QRY_Builder.AggregateRow> rows = foldLevelCounts(buildWindowScope(criteria));
	 * ```
	 */
	private QRY_Builder.Builder buildWindowScope(BrowseCriteria criteria)
	{
		QRY_Builder.Builder builder = applyCriteria(query.bypassSharingInternal().condition(LogEntry__c.OccurrenceCount__c).isNull(), searchScope(criteria));
		if(String.isNotBlank(criteria?.searchTerm))
		{
			builder = builder.addCondition(new QRY_Condition.OrCondition()
					.add(new QRY_Condition.FieldCondition(LogEntry__c.ShortMessage__c).containsLiteral(criteria.searchTerm))
					.add(new QRY_Condition.FieldCondition(LogEntry__c.CorrelationId__c).containsLiteral(criteria.searchTerm)));
		}
		return builder;
	}

	/**
	 * @description Starts the by-id ribbon-aggregate scope over an exact matched set: Id IN the set, with no
	 * further filters (the id set already encodes them). Runs under bypassSharingInternal() so the counts
	 * span every user's rows exactly as the id set was gathered.
	 *
	 * @param recordIds The forensic-row Ids to aggregate over.
	 *
	 * @return The scoped builder, ready for an aggregate leg.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * List<QRY_Builder.AggregateRow> rows = foldLevelCounts(buildIdScope(recordIds));
	 * ```
	 */
	private QRY_Builder.Builder buildIdScope(Set<Id> recordIds)
	{
		return query.bypassSharingInternal().condition(LogEntry__c.Id).isIn(new List<Id>(recordIds));
	}

	/**
	 * @description Folds the per-level forensic row counts over a scoped builder — the shared per-level leg
	 * of the windowed and by-id ribbon aggregates, single-sourced so the two legs can never drift apart.
	 * Unbounded: a handful of levels keeps the leg small and the total exact.
	 *
	 * @param scope The scoped builder (window or id scope).
	 *
	 * @return The per-level aggregate rows.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * List<QRY_Builder.AggregateRow> rows = foldLevelCounts(buildWindowScope(criteria));
	 * ```
	 */
	private static List<QRY_Builder.AggregateRow> foldLevelCounts(QRY_Builder.Builder scope)
	{
		return scope.count(LogEntry__c.Id, ALIAS_OCCURRENCE_COUNT)
				.groupBy(LogEntry__c.LogLevel__c)
				.toAggregateList();
	}

	/**
	 * @description Folds the per-source forensic row counts over a scoped builder — the shared per-source
	 * leg of the windowed and by-id ribbon aggregates, ranked largest-first via orderByCount and capped so
	 * the caller reads the top sources.
	 *
	 * @param scope The scoped builder (window or id scope).
	 * @param cap The LIMIT on the ranked sources.
	 *
	 * @return The per-source aggregate rows, largest first.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * List<QRY_Builder.AggregateRow> rows = foldSourceCounts(buildWindowScope(criteria), 200);
	 * ```
	 */
	private static List<QRY_Builder.AggregateRow> foldSourceCounts(QRY_Builder.Builder scope, Integer cap)
	{
		return scope.count(LogEntry__c.Id, ALIAS_OCCURRENCE_COUNT)
				.groupBy(LogEntry__c.ClassMethod__c)
				.orderByCount(LogEntry__c.Id, true)
				.withLimit(cap)
				.toAggregateList();
	}

	/**
	 * @description Decodes the two ribbon aggregate result sets into a populated EntryAggregate — the shared
	 * decode of the windowed and by-id legs, single-sourced so an alias or field rename can never diverge
	 * the two ribbons' decode paths.
	 *
	 * @param levelRows The per-level aggregate rows.
	 * @param sourceRows The per-source aggregate rows.
	 *
	 * @return The populated per-level and per-source row counts.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * EntryAggregate aggregate = decodeEntryAggregate(levelRows, sourceRows);
	 * ```
	 */
	private static EntryAggregate decodeEntryAggregate(List<QRY_Builder.AggregateRow> levelRows, List<QRY_Builder.AggregateRow> sourceRows)
	{
		EntryAggregate aggregate = new EntryAggregate();
		aggregate.levelCounts = new List<LevelRowCount>();
		for(QRY_Builder.AggregateRow row : levelRows)
		{
			LevelRowCount levelCount = new LevelRowCount();
			levelCount.logLevel = row.getString(fieldName(LogEntry__c.LogLevel__c));
			levelCount.rowCount = row.getInteger(ALIAS_OCCURRENCE_COUNT);
			aggregate.levelCounts.add(levelCount);
		}
		aggregate.sourceCounts = new List<SourceRowCount>();
		for(QRY_Builder.AggregateRow row : sourceRows)
		{
			SourceRowCount sourceCount = new SourceRowCount();
			sourceCount.classMethod = row.getString(fieldName(LogEntry__c.ClassMethod__c));
			sourceCount.rowCount = row.getInteger(ALIAS_OCCURRENCE_COUNT);
			aggregate.sourceCounts.add(sourceCount);
		}
		return aggregate;
	}

	/**
	 * @description Clones the browse criteria for a search leg, carrying the level/context/user/correlation/
	 * source/window filters but dropping searchTerm — the free-text term itself defines the text scope, so
	 * the leg adds its own field condition instead. The correlation id and the source (classMethod) are
	 * scope filters, not text, so they are kept: a Chain-Monitor deep-link and a problem's own source must
	 * survive an active search term (otherwise the leg silently spans every correlation and every source
	 * once a term is typed).
	 *
	 * @param criteria The source criteria; null yields an empty criteria.
	 *
	 * @return A criteria with the free-text term removed but the correlation scope kept.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * BrowseCriteria scope = searchScope(criteria);
	 * ```
	 */
	private static BrowseCriteria searchScope(BrowseCriteria criteria)
	{
		BrowseCriteria scope = new BrowseCriteria();
		if(criteria != null)
		{
			scope.levels = criteria.levels;
			scope.executionEvents = criteria.executionEvents;
			scope.userId = criteria.userId;
			scope.correlationId = criteria.correlationId;
			scope.classMethod = criteria.classMethod;
			scope.windowStart = criteria.windowStart;
			scope.windowEnd = criteria.windowEnd;
		}
		return scope;
	}

	/**
	 * @description Assembles the SOSL RETURNING WHERE clause for the body search: the forensic-row guard
	 * (OccurrenceCount__c = null) plus the present level/context/user/correlation/window filters, all with
	 * namespace-robust field names and escaped values. The correlation clause keeps a body search scoped to a
	 * Chain-Monitor deep-link, matching the SOQL search leg.
	 *
	 * @param criteria The browse filters; null yields the forensic-row guard only.
	 *
	 * @return The AND-joined WHERE clause.
	 *
	 * @date June 2026, July 2026
	 *
	 * @example
	 * ```apex
	 * String where = buildSoslWhere(criteria);
	 * ```
	 */
	private static String buildSoslWhere(BrowseCriteria criteria)
	{
		List<String> clauses = new List<String> {fieldName(LogEntry__c.OccurrenceCount__c) + ' = null'};
		if(criteria != null)
		{
			if(criteria.levels?.isEmpty() == false)
			{
				clauses.add(fieldName(LogEntry__c.LogLevel__c) + ' IN (' + quoteAll(criteria.levels) + ')');
			}
			if(criteria.executionEvents?.isEmpty() == false)
			{
				clauses.add(fieldName(LogEntry__c.ExecutionEvent__c) + ' IN (' + quoteAll(criteria.executionEvents) + ')');
			}
			if(String.isNotBlank(criteria.userId))
			{
				clauses.add(fieldName(LogEntry__c.UserId__c) + ' = \'' + String.escapeSingleQuotes(criteria.userId) + '\'');
			}
			if(String.isNotBlank(criteria.correlationId))
			{
				clauses.add(fieldName(LogEntry__c.CorrelationId__c) + ' = \'' + String.escapeSingleQuotes(criteria.correlationId) + '\'');
			}
			if(criteria.windowStart != null)
			{
				clauses.add(fieldName(LogEntry__c.CreatedDate) + ' >= ' + criteria.windowStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
			}
			if(criteria.windowEnd != null)
			{
				clauses.add(fieldName(LogEntry__c.CreatedDate) + ' <= ' + criteria.windowEnd.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
			}
		}
		return String.join(clauses, ' AND ');
	}

	/**
	 * @description Returns the namespace-qualified API name of a LogEntry__c field for dynamic SOSL.
	 *
	 * @param field The field token.
	 *
	 * @return The API name (namespaced in a managed context).
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * String apiName = fieldName(LogEntry__c.CreatedDate);
	 * ```
	 */
	private static String fieldName(SObjectField field)
	{
		return UTIL_SObjectDescribe.getCachedFieldName(field);
	}

	/**
	 * @description Single-quotes and escapes each value for a dynamic SOSL IN (...) list.
	 *
	 * @param values The raw values.
	 *
	 * @return The comma-joined quoted-and-escaped list.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * String inList = quoteAll(new List<String> {'ERROR', 'WARN'});
	 * ```
	 */
	private static String quoteAll(List<String> values)
	{
		List<String> quoted = new List<String>();
		for(String value : values)
		{
			quoted.add('\'' + String.escapeSingleQuotes(value) + '\'');
		}
		return String.join(quoted, ', ');
	}

	/**
	 * @description Decodes one aggregate row from the derived fold into a typed DerivedSignature, reading the
	 * GROUP BY fields by their namespace-robust API name and the aggregates by their stable alias.
	 *
	 * @param row The aggregate row from foldDerivedSignaturesInWindow.
	 *
	 * @return The typed signature.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * DerivedSignature signature = decodeDerivedSignature(aggregateRow);
	 * ```
	 */
	private static DerivedSignature decodeDerivedSignature(QRY_Builder.AggregateRow row)
	{
		DerivedSignature signature = new DerivedSignature(
				row.getString(fieldName(LogEntry__c.ExceptionType__c)),
				row.getString(fieldName(LogEntry__c.ClassMethod__c)),
				row.getString(fieldName(LogEntry__c.LogLevel__c))
		);
		signature.occurrenceCount = row.getInteger(ALIAS_OCCURRENCE_COUNT);
		signature.firstSeen = (Datetime)row.get(ALIAS_FIRST_SEEN);
		signature.lastSeen = (Datetime)row.get(ALIAS_LAST_SEEN);
		signature.label = row.getString(ALIAS_LABEL);
		return signature;
	}

	/**
	 * @description Adds an identity predicate to the representative-lookup builder: IS NULL when the
	 * signature value is null, otherwise an equality match. Keeps the null-identity handling in one place.
	 *
	 * @param builder The query builder.
	 * @param field The identity field token.
	 * @param value The signature value, or null.
	 *
	 * @return The builder with the predicate applied.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * builder = applyDerivedIdentity(builder, LogEntry__c.ExceptionType__c, signature.exceptionType);
	 * ```
	 */
	private static QRY_Builder.Builder applyDerivedIdentity(QRY_Builder.Builder builder, SObjectField field, String value)
	{
		return value == null
				? builder.andCondition(field).isNull()
				: builder.andCondition(field).equals(value);
	}

	/**
	 * @description Applies the shared browse filters (level, execution context, user, search, correlation,
	 * source, date window) to a builder that already carries at least one condition, so every filter is added
	 * with andCondition, and selects CreatedDate so it is readable and sortable (it is absent from getFields()).
	 * The search term is matched character for character against ShortMessage__c, so a term holding % or _
	 * finds that text instead of behaving as a wildcard. Callers reading the rollup: counter rows must clear
	 * searchTerm, correlationId and classMethod first: a counter row carries none of those three values, so
	 * filtering on them there would return nothing at all.
	 *
	 * @param builder The query builder, already started with a base condition.
	 * @param criteria The filter criteria; null applies no filters.
	 *
	 * @return The builder with the criteria conditions and CreatedDate applied.
	 *
	 * @date June 2026
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.Builder filteredQuery = applyCriteria(query.condition(LogEntry__c.OccurrenceCount__c).isNull(), criteria);
	 * ```
	 */
	private static QRY_Builder.Builder applyCriteria(QRY_Builder.Builder builder, BrowseCriteria criteria)
	{
		QRY_Builder.Builder filteredQuery = builder.addField(LogEntry__c.CreatedDate);
		if(criteria == null)
		{
			return filteredQuery;
		}
		if(criteria.levels?.isEmpty() == false)
		{
			filteredQuery = filteredQuery.andCondition(LogEntry__c.LogLevel__c).isIn(criteria.levels);
		}
		if(criteria.executionEvents?.isEmpty() == false)
		{
			filteredQuery = filteredQuery.andCondition(LogEntry__c.ExecutionEvent__c).isIn(criteria.executionEvents);
		}
		if(String.isNotBlank(criteria.userId))
		{
			filteredQuery = filteredQuery.andCondition(LogEntry__c.UserId__c).equals(criteria.userId);
		}
		if(String.isNotBlank(criteria.searchTerm))
		{
			filteredQuery = filteredQuery.addCondition(new QRY_Condition.FieldCondition(LogEntry__c.ShortMessage__c).containsLiteral(criteria.searchTerm));
		}
		if(String.isNotBlank(criteria.correlationId))
		{
			filteredQuery = filteredQuery.andCondition(LogEntry__c.CorrelationId__c).equals(criteria.correlationId);
		}
		if(String.isNotBlank(criteria.classMethod))
		{
			filteredQuery = filteredQuery.andCondition(LogEntry__c.ClassMethod__c).equals(criteria.classMethod);
		}
		if(criteria.windowStart != null)
		{
			filteredQuery = filteredQuery.andCondition(LogEntry__c.CreatedDate).greaterThanOrEquals(criteria.windowStart);
		}
		if(criteria.windowEnd != null)
		{
			filteredQuery = filteredQuery.andCondition(LogEntry__c.CreatedDate).lessThanOrEquals(criteria.windowEnd);
		}
		return filteredQuery;
	}

	/**
	 * @description The all-entries ribbon aggregate: the per-level and per-source forensic row counts folded
	 * over the window. The controller sums the level counts for the total (so total always equals the sum of
	 * the per-level breakdown) and folds the source counts by class name for the ranked top sources.
	 *
	 * @date July 2026
	 */
	public class EntryAggregate
	{
		/**
		 * @description The forensic row count per log level.
		 */
		public List<LevelRowCount> levelCounts;

		/**
		 * @description The forensic row count per Class.method source, ordered by count descending and capped.
		 */
		public List<SourceRowCount> sourceCounts;
	}

	/**
	 * @description One log level and its forensic row count within the window.
	 *
	 * @date July 2026
	 */
	public class LevelRowCount
	{
		/**
		 * @description The log level (DEBUG/INFO/WARN/ERROR).
		 */
		public String logLevel;

		/**
		 * @description The number of forensic rows at this level.
		 */
		public Integer rowCount;
	}

	/**
	 * @description One Class.method source and its forensic row count within the window.
	 *
	 * @date July 2026
	 */
	public class SourceRowCount
	{
		/**
		 * @description The Class.method the forensic rows were recorded in.
		 */
		public String classMethod;

		/**
		 * @description The number of forensic rows recorded in this Class.method.
		 */
		public Integer rowCount;
	}

	/**
	 * @description A derived problem signature folded from plain forensic rows — the GROUP BY key
	 * (exception type, class method, log level) plus the folded aggregates (occurrence count, first-seen,
	 * last-seen and a ShortMessage label). Also serves as the identity key passed to
	 * findDerivedRepresentative when a subscriber opens the problem. The throw-site line number is not part
	 * of the key (Number fields are not groupable in SOQL, and line numbers shift across deploys); the
	 * representative row carries the actual line when the problem is opened.
	 *
	 * @date June 2026
	 */
	public class DerivedSignature
	{
		/**
		 * @description The exception type folded on (System.NullPointerException, ...); may be null when keyed on class method alone.
		 */
		public String exceptionType;

		/**
		 * @description The Class.method folded on; may be null when keyed on exception type alone.
		 */
		public String classMethod;

		/**
		 * @description The log level folded on (ERROR/WARN/...).
		 */
		public String logLevel;

		/**
		 * @description The number of forensic occurrences in the window (COUNT). Null on a bare identity key.
		 */
		public Integer occurrenceCount;

		/**
		 * @description The earliest occurrence in the window (MIN CreatedDate). Null on a bare identity key.
		 */
		public Datetime firstSeen;

		/**
		 * @description The latest occurrence in the window (MAX CreatedDate). Null on a bare identity key.
		 */
		public Datetime lastSeen;

		/**
		 * @description A representative ShortMessage for display (MAX ShortMessage). Null on a bare identity key.
		 */
		public String label;

		/**
		 * @description Constructs a bare identity key (the three groupable signature fields) for a
		 * representative lookup; the decode path sets the aggregate fields after construction.
		 *
		 * @param exceptionType The exception type, or null.
		 * @param classMethod The Class.method, or null.
		 * @param logLevel The log level.
		 *
		 * @example
		 * ```apex
		 * SEL_LogEntry.DerivedSignature key = new SEL_LogEntry.DerivedSignature('System.NullPointerException', 'AccountTriggerHandler.handleAfterUpdate', 'ERROR');
		 * ```
		 */
		public DerivedSignature(String exceptionType, String classMethod, String logLevel)
		{
			this.exceptionType = exceptionType;
			this.classMethod = classMethod;
			this.logLevel = logLevel;
		}
	}

	/**
	 * @description Filter criteria for the browse and aggregate reads — a plain holder so the caller passes
	 * one object instead of a long parameter list.
	 *
	 * @date June 2026
	 */
	public class BrowseCriteria
	{
		/**
		 * @description Log levels to include (DEBUG/INFO/WARN/ERROR). Null or empty includes all levels.
		 */
		public List<String> levels;

		/**
		 * @description Execution contexts (quiddity) to include. Null or empty includes all contexts.
		 */
		public List<String> executionEvents;

		/**
		 * @description Originating user Id to filter on (UserId__c, not CreatedById). Blank includes all users.
		 */
		public String userId;

		/**
		 * @description Free-text term matched against ShortMessage__c, character for character, so % and _
		 * are ordinary characters rather than wildcards. Blank applies no text filter.
		 */
		public String searchTerm;

		/**
		 * @description Exact CorrelationId__c to filter on (the Chain Monitor deep-link). Blank applies no filter.
		 */
		public String correlationId;

		/**
		 * @description Exact ClassMethod__c to filter on — the source a problem was grouped under, so the
		 * entries behind that problem can be listed without searching for its class name as free text.
		 * Blank applies no filter.
		 */
		public String classMethod;

		/**
		 * @description Inclusive lower bound on CreatedDate. Null applies no lower bound.
		 */
		public Datetime windowStart;

		/**
		 * @description Inclusive upper bound on CreatedDate. Null applies no upper bound.
		 */
		public Datetime windowEnd;
	}
}