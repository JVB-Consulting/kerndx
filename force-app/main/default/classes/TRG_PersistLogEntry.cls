// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Owns persistence of log events to the `LogEntry__c` object. Wired as the trigger
 * action on the `LogEntryEvent__e` platform event (`afterInsert`), and also exposes `persist` as a
 * `public static` service so a second caller can write the same rows: `LOG_Engine` calls it directly
 * when a log is emitted while executing inside a platform-event (`__e`) or change-event
 * (`*ChangeEvent`) trigger, where publishing a `LogEntryEvent__e` would make the platform redeliver
 * the source event and loop. There the engine suppresses the publish and persists in-context
 * through this class instead. Both entry points produce identical rows.
 *
 * Events without a fingerprint persist unchanged (the original path); events carrying a
 * `Fingerprint__c` collapse into flood control: one forensic detail row per fingerprint
 * (presence-based, re-armed automatically after purges because the unique detail key no longer
 * exists) plus one rollup counter row per fingerprint per UTC day. Any aggregation failure falls
 * back to plain per-row inserts with a null fingerprint so no event is ever lost.
 *
 * Grouping keys are normalized where the stored keys are composed (`groupEvents` runs each one
 * through `LOG_Builder.normalizeStoredFingerprintKey` rather than trusting it), because this class
 * persists any delivered `LogEntryEvent__e`, including one published straight to the platform event,
 * which never passes through `LOG_Builder` and can therefore carry edge whitespace or a key too long
 * for the stored `detail:`/`rollup:` form.
 *
 * Flood control writes its own rows through row-level `Database` DML rather than `DML_Builder`,
 * because partial success is the whole point here: the detail key is a unique index, so a second
 * writer that raced the presence check has its row rejected, and an all-or-nothing transaction
 * would take the rest of the chunk, including the plain rows of unrelated events, down with it.
 * Rejected rows are recovered instead (folded into the row already stored, or kept as plain rows)
 * and one WARN breadcrumb records that it happened.
 * The plain rows are saved through `DML_Builder`, which empties the transaction's query cache like any other commit.
 * The flood-control rows written with raw `Database` DML deliberately do not empty it: a log can be persisted in the
 * middle of a transaction, so clearing there would empty every cache on each flush, and Kern caches no LogEntry__c read.
 * Originally adapted from [ApexLogger](https://github.com/mlockett/ApexLogger).
 *
 * @see TRG_PersistLogEntry_TEST
 * @see LOG_Builder
 * @see LOG_Engine
 * @see TRG_Base
 * @see IF_Trigger
 * @see SEL_LogEntry
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date January 2026, October 2026
 */
public inherited sharing class TRG_PersistLogEntry extends TRG_Base implements IF_Trigger.AfterInsert
{
	/**
	 * @description Key prefix marking the single forensic detail row kept per fingerprint (the full
	 * sample). This persist handler owns the persisted key shape (it stamps the prefix onto
	 * `Fingerprint__c` here), so the prefix is defined here as the single source of truth and the Log
	 * Console read layer references it to strip the key back to the base fingerprint.
	 */
	public static final String PREFIX_DETAIL = 'detail:';

	/**
	 * @description Key prefix marking the per-day windowed rollup counter rows, shaped
	 * `rollup:<base>:<yyyyMMdd>`. Defined here, where this handler stamps it onto `Fingerprint__c`, as
	 * the single source of truth the read layer references to fold the rows back to the base fingerprint.
	 */
	public static final String PREFIX_ROLLUP = 'rollup:';

	/**
	 * @description Character length of a rollup key's trailing day suffix (':' + the UTC day bucket).
	 * Derived from the same UTIL_String.COLON and UTIL_Date.toUtcDayBucket sources buildRollupKey
	 * composes with (any fixed instant yields the fixed-width `yyyyMMdd` bucket), so the decode width
	 * can never drift from the written key shape.
	 *
	 * @date July 2026
	 */
	private static final Integer ROLLUP_DAY_SUFFIX_LENGTH = UTIL_String.COLON.length() + UTIL_Date.toUtcDayBucket(Datetime.newInstanceGmt(2026, 1, 1)).length();

	/**
	 * @description Message shape of the breadcrumb persisted when flood control had to recover a
	 * rejected row: how many rows were kept as plain entries, how many folded into a row already
	 * stored, and the database's own text for the first rejection. Held as a constant here rather
	 * than a Custom Label because it is engine diagnostic text on a log row, the same treatment
	 * every other persisted framework log message gets, and the log-persist path must never take a
	 * dependency that could itself emit a log.
	 */
	private static final String FALLBACK_BREADCRUMB_FORMAT = 'flood-control fallback: {0} events stored plain, {1} folded into the row already stored, first error: {2}';

	/**
	 * @description Class/method stamp on the fallback breadcrumb, pointing an administrator at the
	 * exact framework entry point that recovered the rows.
	 */
	private static final String FALLBACK_BREADCRUMB_CLASS_METHOD = TRG_PersistLogEntry.class.getName() + '/persist';

	/**
	 * @description Composes the presence-based detail key ('detail:<base>') this handler stamps onto the
	 * single forensic sample row kept per fingerprint. Compose and decode live together here, in the layer
	 * that owns the persisted key shape, so a read layer never re-implements the format.
	 *
	 * @param baseFingerprint The base fingerprint (without any prefix).
	 *
	 * @return The full 'detail:<base>' key.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * String detailKey = TRG_PersistLogEntry.buildDetailKey('NullPointer:MyClass.method');
	 * ```
	 */
	public static String buildDetailKey(String baseFingerprint)
	{
		return PREFIX_DETAIL + baseFingerprint;
	}

	/**
	 * @description Composes the per-UTC-day rollup key ('rollup:<base>:<yyyyMMdd>') this handler stamps
	 * onto the windowed counter rows, bucketing the supplied occurrence instant to its GMT calendar day.
	 *
	 * @param baseFingerprint The base fingerprint (without any prefix).
	 * @param occurredAt The occurrence instant whose UTC day buckets the counter row.
	 *
	 * @return The full 'rollup:<base>:<yyyyMMdd>' key.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * String rollupKey = TRG_PersistLogEntry.buildRollupKey('NullPointer:MyClass.method', Datetime.now());
	 * ```
	 */
	public static String buildRollupKey(String baseFingerprint, Datetime occurredAt)
	{
		return PREFIX_ROLLUP + baseFingerprint + UTIL_String.COLON + UTIL_Date.toUtcDayBucket(occurredAt);
	}

	/**
	 * @description Strips the 'detail:' prefix from a detail key to recover the base fingerprint. It is the
	 * reverse of buildDetailKey, kept beside it so the key format is parsed only where it is written.
	 *
	 * @param detailKey The full 'detail:<base>' key.
	 *
	 * @return The base fingerprint.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * String base = TRG_PersistLogEntry.decodeBaseFromDetailKey('detail:NullPointer:MyClass.method');
	 * ```
	 */
	public static String decodeBaseFromDetailKey(String detailKey)
	{
		return detailKey.substring(PREFIX_DETAIL.length());
	}

	/**
	 * @description Strips the 'rollup:' prefix and the trailing ':yyyyMMdd' day suffix from a rollup key
	 * to recover the base fingerprint shared with its detail sample. It is the reverse of buildRollupKey.
	 * The suffix width derives from the same sources the compose side uses, so a bucket-format change can
	 * never leave the decode silently truncating the base.
	 *
	 * @param rollupKey The full 'rollup:<base>:<yyyyMMdd>' key.
	 *
	 * @return The base fingerprint.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * String base = TRG_PersistLogEntry.decodeBaseFromRollupKey('rollup:NullPointer:MyClass.method:20260626');
	 * ```
	 */
	public static String decodeBaseFromRollupKey(String rollupKey)
	{
		return rollupKey.substring(PREFIX_ROLLUP.length(), rollupKey.length() - ROLLUP_DAY_SUFFIX_LENGTH);
	}

	/**
	 * @description Will ensure that the events raised are logged to the LogEntry__c object:
	 * plain events persist unchanged, fingerprinted events collapse into detail + rollup rows.
	 *
	 * @param newRecords The platform events being inserted.
	 */
	public void afterInsert(List<SObject> newRecords)
	{
		List<LogEntryEvent__e> events = new List<LogEntryEvent__e>();
		for(SObject record : newRecords)
		{
			events.add((LogEntryEvent__e)record);
		}

		persist(events);
	}

	/**
	 * @description Persists a chunk of log events: plain events insert as today; fingerprinted
	 * events collapse into presence-based detail rows and per-day rollup counters via the
	 * insert/update split routed off one indexed selector query. If that aggregation throws (in practice, when the
	 * presence-check query fails under load), the fingerprinted events
	 * persist as plain null-fingerprint rows instead, so no log event is lost to the flood-control
	 * path.
	 *
	 * Every key is put into storable shape before a row is composed from it (see `groupEvents`), so
	 * the detail key, the rollup key, the presence check and the recovery re-read all name the one
	 * key the row is stored under. This boundary normalizes rather than trusting its caller because
	 * it receives any delivered `LogEntryEvent__e`, including one published straight to the platform
	 * event without ever passing through `LOG_Builder`, whose 216-character field accepts keys the
	 * stored `detail:`/`rollup:` form cannot hold.
	 *
	 * The two layers commit separately: plain rows keep their original all-or-nothing
	 * `DML_Builder` transaction, while the flood-control rows commit row by row so a rejection on
	 * the unique fingerprint index costs only the row the database refused (see
	 * `persistFloodControlRows`). No `EventBus.RetryableException` is thrown at any point, because running
	 * out of retries would suspend the subscription and stop persisting logs org-wide.
	 *
	 * `public static` because two callers share it: the `afterInsert` trigger callback (normal
	 * delivered-event path) and `LOG_Engine` (in-context path, when publishing would loop).
	 *
	 * @param events The platform-event chunk to persist.
	 *
	 * @date January 2026, August 2026
	 */
	public static void persist(List<LogEntryEvent__e> events)
	{
		List<LogEntry__c> plainRows = new List<LogEntry__c>();
		List<LogEntryEvent__e> fingerprinted = new List<LogEntryEvent__e>();

		for(LogEntryEvent__e event : events)
		{
			if(String.isBlank(event.Fingerprint__c))
			{
				plainRows.add(buildRow(event));
			}
			else
			{
				fingerprinted.add(event);
			}
		}

		List<LogEntry__c> floodControlInserts = new List<LogEntry__c>();
		List<LogEntry__c> floodControlUpdates = new List<LogEntry__c>();
		try
		{
			List<LogEntry__c> aggregatedInserts = new List<LogEntry__c>();
			List<LogEntry__c> aggregatedUpdates = new List<LogEntry__c>();
			aggregate(fingerprinted, aggregatedInserts, aggregatedUpdates);
			floodControlInserts = aggregatedInserts;
			floodControlUpdates = aggregatedUpdates;
		}
		catch(Exception error)
		{
			for(LogEntryEvent__e event : fingerprinted)
			{
				plainRows.add(buildRow(event));
			}
		}

		if(!plainRows.isEmpty())
		{
			DML_Builder.newTransaction().systemModeInternal().doInsert(plainRows).execute();
		}

		persistFloodControlRows(floodControlInserts, floodControlUpdates);
	}

	/**
	 * @description Commits the flood-control layer row by row, so one refused row costs only itself.
	 * Raw `Database` DML is deliberate here: `DML_Builder` is all-or-nothing by design, and
	 * all-or-nothing is exactly wrong for this layer. `Fingerprint__c` is a unique index, so a
	 * writer that raced another on a first-seen key has its row refused, and an all-or-nothing
	 * commit would discard the whole chunk (including rows for entirely unrelated fingerprints) to
	 * no purpose. Both statements therefore run with `allOrNone` false, in the same `SYSTEM_MODE`
	 * the plain path uses.
	 *
	 * Refused inserts are recovered, so the row is not lost. Refused updates are not: an update means
	 * the row is already stored (that is why it is an update), so only a counter increment is
	 * missed, and re-persisting the row would double-count the window. The breadcrumb records both.
	 *
	 * @param rowsToInsert The detail and new rollup rows to insert.
	 * @param rowsToUpdate The existing rollup rows whose counters were incremented.
	 */
	@SuppressWarnings('PMD.KernNoDirectDML')
	private static void persistFloodControlRows(List<LogEntry__c> rowsToInsert, List<LogEntry__c> rowsToUpdate)
	{
		List<String> failureMessages = new List<String>();
		List<LogEntry__c> refusedInserts = new List<LogEntry__c>();

		if(!rowsToInsert.isEmpty())
		{
			refusedInserts = collectRefusedRows(rowsToInsert, Database.insert(rowsToInsert, false, AccessLevel.SYSTEM_MODE), failureMessages);
		}

		if(!rowsToUpdate.isEmpty())
		{
			//The refused updates themselves need no recovery (see the method docstring); the call is here for its
			//error text, which the breadcrumb quotes so a missed counter increment is still diagnosable.
			collectRefusedRows(rowsToUpdate, Database.update(rowsToUpdate, false, AccessLevel.SYSTEM_MODE), failureMessages);
		}

		if(failureMessages.isEmpty())
		{
			return;
		}

		recoverRefusedRows(refusedInserts, failureMessages[0]);
	}

	/**
	 * @description Splits a partial-success DML result into the rows the database refused, gathering
	 * each refusal's text for the breadcrumb. Results are positional against the rows submitted,
	 * which is the platform's contract for `Database.insert`/`Database.update`.
	 *
	 * @param rows The rows submitted, in submission order.
	 * @param results The per-row outcomes, in the same order.
	 * @param failureMessages Output: the database's text for each refusal, appended in row order.
	 *
	 * @return The refused rows.
	 */
	private static List<LogEntry__c> collectRefusedRows(List<LogEntry__c> rows, List<Database.SaveResult> results, List<String> failureMessages)
	{
		List<LogEntry__c> refusedRows = new List<LogEntry__c>();
		for(Integer index = 0; index < results.size(); index++)
		{
			if(!results[index].isSuccess())
			{
				refusedRows.add(rows[index]);
				failureMessages.add(LOG_Engine.extractErrorMessage(results[index].getErrors()));
			}
		}
		return refusedRows;
	}

	/**
	 * @description Recovers the flood-control rows the database refused, then records the fallback.
	 * Each refused row is re-read under its own key. A row already stored under that key wins: the
	 * refused row's occurrences fold into it, which is what a genuine two-writer race on a first-seen
	 * key needs. The other writer committed between this transaction's presence check and its insert, and
	 * its counter would otherwise be short by the refused row's occurrences. With nothing stored under the key,
	 * the refusal was not a collision this transaction can reconcile, so the row persists plain,
	 * without a fingerprint, where it can neither collide again nor be lost.
	 *
	 * The fold adds the refused row's occurrences to the stored row's, and leaves the counter unset
	 * when neither row counts any: a refused detail row carries no count and folds into a detail
	 * row that carries none either. That keeps the two row shapes meaning what they mean: a stored
	 * row with a count is a rollup counter, one without is a forensic sample, and the Log Console
	 * reads them apart on exactly that.
	 *
	 * The recovery is one round by design: its own DML is partial too, and its outcome is not
	 * inspected, which bounds the fallback at one extra statement of each kind and keeps a failing
	 * persist from amplifying into a retry storm.
	 *
	 * @param refusedRows The flood-control rows the insert refused.
	 * @param firstFailureMessage The database's text for the first refusal, quoted in the breadcrumb.
	 */
	@SuppressWarnings('PMD.KernNoDirectDML')
	private static void recoverRefusedRows(List<LogEntry__c> refusedRows, String firstFailureMessage)
	{
		Set<String> storedKeys = new Set<String>();
		for(LogEntry__c refused : refusedRows)
		{
			storedKeys.add(refused.Fingerprint__c);
		}

		Map<String, LogEntry__c> storedByKey = findByKey(storedKeys);
		Map<Id, LogEntry__c> foldedRowsById = new Map<Id, LogEntry__c>();
		List<LogEntry__c> plainRows = new List<LogEntry__c>();

		for(LogEntry__c refused : refusedRows)
		{
			LogEntry__c stored = storedByKey.get(refused.Fingerprint__c);
			Decimal refusedCount = refused.OccurrenceCount__c;

			if(stored == null)
			{
				refused.Fingerprint__c = null;
				refused.OccurrenceCount__c = null;
				plainRows.add(refused);
			}
			else
			{
				stored.OccurrenceCount__c = stored.OccurrenceCount__c == null && refusedCount == null ? null : (stored.OccurrenceCount__c ?? 0) + (refusedCount ?? 0);
				foldedRowsById.put(stored.Id, stored);
			}
		}

		plainRows.add(buildBreadcrumbRow(plainRows.size(), foldedRowsById.size(), firstFailureMessage));

		if(!foldedRowsById.isEmpty())
		{
			Database.update(foldedRowsById.values(), false, AccessLevel.SYSTEM_MODE);
		}
		Database.insert(plainRows, false, AccessLevel.SYSTEM_MODE);
	}

	/**
	 * @description Builds the single WARN row that records a flood-control fallback, so a silent
	 * repeat is impossible: the counts say what became of the refused rows and the message quotes
	 * the database's own reason.
	 *
	 * The row is composed and written here, as an ordinary `LogEntry__c`, rather than emitted
	 * through `LOG_Builder`. That is the point: an emitted breadcrumb would publish a
	 * `LogEntryEvent__e`, the platform would deliver it straight back into this trigger, and inside
	 * an event-trigger context `LOG_Engine` calls `persist` directly. Either way the breadcrumb
	 * would re-enter the very path it is reporting on. Writing the row keeps the fallback flat. Its
	 * `Fingerprint__c` is left null for the same reason: a breadcrumb can never collide, so it can
	 * never be refused, so it can never provoke a breadcrumb of its own.
	 *
	 * @param plainRowCount How many refused rows were kept as plain rows.
	 * @param foldedRowCount How many refused rows folded into a row already stored.
	 * @param firstFailureMessage The database's text for the first refusal.
	 *
	 * @return The unsaved breadcrumb row.
	 */
	private static LogEntry__c buildBreadcrumbRow(Integer plainRowCount, Integer foldedRowCount, String firstFailureMessage)
	{
		String message = String.format(FALLBACK_BREADCRUMB_FORMAT, new List<Object> {plainRowCount, foldedRowCount, firstFailureMessage});

		LogEntry__c breadcrumb = new LogEntry__c();
		breadcrumb.ClassMethod__c = UTIL_String.abbreviate(FALLBACK_BREADCRUMB_CLASS_METHOD, LogEntry__c.ClassMethod__c);
		breadcrumb.LogLevel__c = LoggingLevel.WARN.name();
		breadcrumb.Message__c = UTIL_String.abbreviate(message, LogEntry__c.Message__c);
		breadcrumb.ShortMessage__c = UTIL_String.abbreviate(message, LogEntry__c.ShortMessage__c);

		return breadcrumb;
	}

	/**
	 * @description Groups fingerprinted events by detail key and per-UTC-day rollup window,
	 * presence-checks detail rows, and routes rollup rows through the insert/update split off one
	 * selector query. Each key maps to at most one SObject per list (a duplicate key in one insert
	 * list would violate the unique constraint) because the grouping maps collapse repeats.
	 *
	 * @param events The fingerprinted events of this chunk.
	 * @param rowsToInsert Output: detail rows and new rollup rows.
	 * @param rowsToUpdate Output: existing rollup rows with incremented counts.
	 *
	 * @date January 2026, July 2026
	 */
	private static void aggregate(List<LogEntryEvent__e> events, List<LogEntry__c> rowsToInsert, List<LogEntry__c> rowsToUpdate)
	{
		if(events.isEmpty())
		{
			return;
		}

		Map<String, LogEntryEvent__e> detailSampleByKey = new Map<String, LogEntryEvent__e>();
		Map<String, RollupWindow> windowByKey = new Map<String, RollupWindow>();
		groupEvents(events, detailSampleByKey, windowByKey);

		Set<String> keysToFind = new Set<String>(detailSampleByKey.keySet());
		keysToFind.addAll(windowByKey.keySet());
		Map<String, LogEntry__c> existingByKey = findByKey(keysToFind);

		addDetailInserts(detailSampleByKey, existingByKey, rowsToInsert);
		addRollupRows(windowByKey, existingByKey, rowsToInsert, rowsToUpdate);
	}

	/**
	 * @description First-pass grouping: records the first event seen per `detail:` key and
	 * accumulates the per-UTC-day rollup window (payload sample plus occurrence count) per
	 * `rollup:` key.
	 *
	 * Both keys are composed from the event's grouping key put into storable shape
	 * (`LOG_Builder.normalizeStoredFingerprintKey`) rather than from the key as it arrived: trimmed,
	 * and hashed when it is longer than the prefixed form can hold. Normalizing here, at the one
	 * place the keys are composed, is what lets the presence check find what the insert stored: the
	 * shape is fixed before any key exists, and the delivered event itself is never written to,
	 * because a platform event's record is read-only once the platform has delivered it.
	 *
	 * Window assignment uses `CreatedDate`, the event PUBLISH time, not the trigger
	 * persist time, so the delay between publish and persist never puts an event in the wrong day. This
	 * equals the original occurrence time only for immediately-published events; under log buffering
	 * (`suspendSaving`/`LogScope`) or the async DML-budget fallback, publish can lag the occurrence,
	 * so an occurrence near a UTC-midnight boundary may land in the adjacent day's rollup. Per-
	 * fingerprint TOTALS are unaffected, because the reporting recipe SUMs OccurrenceCount__c across all
	 * `rollup:` rows; only single-day attribution can shift by the buffer window.
	 *
	 * @param events The fingerprinted events of this chunk.
	 * @param detailSampleByKey Output: first event seen per `detail:` key.
	 * @param windowByKey Output: rollup window accumulator per `rollup:` key.
	 */
	private static void groupEvents(List<LogEntryEvent__e> events, Map<String, LogEntryEvent__e> detailSampleByKey, Map<String, RollupWindow> windowByKey)
	{
		for(LogEntryEvent__e event : events)
		{
			String baseKey = LOG_Builder.normalizeStoredFingerprintKey(event.Fingerprint__c);

			String detailKey = buildDetailKey(baseKey);
			if(!detailSampleByKey.containsKey(detailKey))
			{
				detailSampleByKey.put(detailKey, event);
			}

			String rollupKey = buildRollupKey(baseKey, event.CreatedDate ?? Datetime.now());
			RollupWindow window = windowByKey.get(rollupKey);
			if(window == null)
			{
				window = new RollupWindow(event);
				windowByKey.put(rollupKey, window);
			}
			window.count++;
		}
	}

	/**
	 * @description Looks up existing rows for the supplied detail and rollup keys, returned by key.
	 *
	 * @param keys The `detail:` and `rollup:` keys to look up.
	 *
	 * @return Existing LogEntry__c rows keyed by Fingerprint__c.
	 */
	private static Map<String, LogEntry__c> findByKey(Set<String> keys)
	{
		Map<String, LogEntry__c> existingByKey = new Map<String, LogEntry__c>();
		for(LogEntry__c row : new SEL_LogEntry().findByFingerprints(keys))
		{
			existingByKey.put(row.Fingerprint__c, row);
		}
		return existingByKey;
	}

	/**
	 * @description Adds a detail row insert for each fingerprint whose detail row is not already
	 * present. The check is by presence, so after a detail row is purged, the next occurrence saves a new one.
	 *
	 * @param detailSampleByKey First event seen per `detail:` key.
	 * @param existingByKey Existing rows keyed by Fingerprint__c.
	 * @param rowsToInsert Output: detail rows to insert.
	 */
	private static void addDetailInserts(Map<String, LogEntryEvent__e> detailSampleByKey, Map<String, LogEntry__c> existingByKey, List<LogEntry__c> rowsToInsert)
	{
		for(String detailKey : detailSampleByKey.keySet())
		{
			if(!existingByKey.containsKey(detailKey))
			{
				LogEntry__c detailRow = buildRow(detailSampleByKey.get(detailKey));
				detailRow.Fingerprint__c = detailKey;
				rowsToInsert.add(detailRow);
			}
		}
	}

	/**
	 * @description Routes each rollup window to an update (existing row, count incremented) or an
	 * insert (new row carrying the window's count).
	 *
	 * @param windowByKey Rollup window accumulator per `rollup:` key.
	 * @param existingByKey Existing rows keyed by Fingerprint__c.
	 * @param rowsToInsert Output: new rollup rows.
	 * @param rowsToUpdate Output: existing rollup rows with incremented counts.
	 */
	private static void addRollupRows(Map<String, RollupWindow> windowByKey, Map<String, LogEntry__c> existingByKey, List<LogEntry__c> rowsToInsert, List<LogEntry__c> rowsToUpdate)
	{
		for(String rollupKey : windowByKey.keySet())
		{
			RollupWindow window = windowByKey.get(rollupKey);
			LogEntry__c existingRollup = existingByKey.get(rollupKey);
			if(existingRollup != null)
			{
				existingRollup.OccurrenceCount__c = (existingRollup.OccurrenceCount__c ?? 0) + window.count;
				rowsToUpdate.add(existingRollup);
			}
			else
			{
				LogEntry__c rollupRow = buildRow(window.sample);
				rollupRow.Fingerprint__c = rollupKey;
				rollupRow.OccurrenceCount__c = window.count;
				rowsToInsert.add(rollupRow);
			}
		}
	}

	/**
	 * @description Maps a LogEntryEvent__e to a LogEntry__c row with length-safe abbreviation.
	 * Never sets Fingerprint__c (callers stamp prefixed keys; fallback rows stay null so they
	 * cannot trip uniqueness).
	 *
	 * @param event The platform event to map.
	 *
	 * @return The unsaved LogEntry__c row.
	 */
	private static LogEntry__c buildRow(LogEntryEvent__e event)
	{
		LogEntry__c logEntry = new LogEntry__c();

		logEntry.ClassMethod__c = UTIL_String.abbreviate(event.ClassMethod__c, LogEntry__c.ClassMethod__c);
		logEntry.ContextData__c = UTIL_String.abbreviate(event.ContextData__c, LogEntry__c.ContextData__c);
		logEntry.CorrelationId__c = UTIL_String.abbreviate(event.CorrelationId__c, LogEntry__c.CorrelationId__c);
		logEntry.RootCorrelationId__c = UTIL_String.abbreviate(event.RootCorrelationId__c, LogEntry__c.RootCorrelationId__c);
		logEntry.DurationMs__c = event.DurationMs__c;
		logEntry.ExceptionType__c = UTIL_String.abbreviate(event.ExceptionType__c, LogEntry__c.ExceptionType__c);
		logEntry.ExecutionEvent__c = event.ExecutionEvent__c;
		logEntry.Limits__c = UTIL_String.abbreviate(event.Limits__c, LogEntry__c.Limits__c);
		logEntry.LineNumber__c = event.LineNumber__c;
		logEntry.LogLevel__c = event.LogLevel__c;
		logEntry.Origin__c = event.Origin__c;
		logEntry.Source__c = UTIL_String.abbreviate(event.Source__c, LogEntry__c.Source__c);
		logEntry.Message__c = UTIL_String.abbreviate(event.Message__c, LogEntry__c.Message__c);
		logEntry.ParentTransactionId__c = UTIL_String.abbreviate(event.ParentTransactionId__c, LogEntry__c.ParentTransactionId__c);
		logEntry.RecordId__c = UTIL_String.abbreviate(event.RecordId__c, LogEntry__c.RecordId__c);
		logEntry.ShortMessage__c = UTIL_String.abbreviate(event.ShortMessage__c, LogEntry__c.ShortMessage__c);
		logEntry.StackTrace__c = UTIL_String.abbreviate(event.StackTrace__c, LogEntry__c.StackTrace__c);
		logEntry.TransactionId__c = UTIL_String.abbreviate(event.TransactionId__c, LogEntry__c.TransactionId__c);
		logEntry.UserId__c = UTIL_String.abbreviate(event.UserId__c, LogEntry__c.UserId__c);

		return logEntry;
	}

	/**
	 * @description Accumulates one fingerprint's occurrences within a single UTC-day window: the
	 * first event seen (the payload sample for a new rollup row) and the running occurrence count.
	 */
	private class RollupWindow
	{
		/**
		 * @description First event observed for this window: the rollup row's payload sample.
		 */
		private final LogEntryEvent__e sample;

		/**
		 * @description Occurrences accumulated for this window in the current chunk.
		 */
		private Integer count = 0;

		/**
		 * @description Constructs a window seeded with its first event.
		 *
		 * @param sample The first event observed for this window.
		 */
		private RollupWindow(LogEntryEvent__e sample)
		{
			this.sample = sample;
		}
	}
}