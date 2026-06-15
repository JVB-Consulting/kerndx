// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Owns persistence of log events to the `LogEntry__c` object. Wired as the trigger
 * action on the `LogEntryEvent__e` platform event (`afterInsert`), and also exposes `persist` as a
 * `public static` service so a second caller can write the same rows: `LOG_Engine` calls it directly
 * when a log is emitted while executing inside a platform-event (`__e`) or change-event
 * (`*ChangeEvent`) trigger, where publishing a `LogEntryEvent__e` would make the platform redeliver
 * the source event and loop — there the engine suppresses the publish and persists in-context
 * through this class instead. Both entry points produce identical rows.
 *
 * Events without a fingerprint persist unchanged (the original path); events carrying a
 * `Fingerprint__c` collapse into flood control — one forensic detail row per fingerprint
 * (presence-based, re-armed automatically after purges because the unique detail key no longer
 * exists) plus one rollup counter row per fingerprint per UTC day. Any aggregation failure falls
 * back to plain per-row inserts with a null fingerprint so no event is ever lost.
 * Originally adapted from [ApexLogger](https://github.com/mlockett/ApexLogger).
 *
 * @see TRG_PersistLogEntry_TEST
 * @see LOG_Engine
 * @see TRG_Base
 * @see IF_Trigger
 * @see SEL_LogEntry
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date January 2026, June 2026
 */
public inherited sharing class TRG_PersistLogEntry extends TRG_Base implements IF_Trigger.AfterInsert
{
	/**
	 * @description Key prefix marking the single forensic detail row per fingerprint.
	 */
	@TestVisible
	private static final String PREFIX_DETAIL = 'detail:';

	/**
	 * @description Key prefix marking windowed rollup counter rows.
	 */
	@TestVisible
	private static final String PREFIX_ROLLUP = 'rollup:';

	/**
	 * @description Test seam forcing the aggregation-compute path to throw, exercising the
	 * plain-row fallback without depending on a real defect.
	 */
	@TestVisible
	private static Boolean simulateComputeFailure = false;

	/**
	 * @description Will ensure that the events raised are logged to the LogEntry__c object —
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
	 * insert/update split routed off one indexed selector query. DML-layer failures are
	 * deliberately NOT wrapped (no fallback-on-failed-DML amplification) and no
	 * EventBus.RetryableException is thrown (retry exhaustion would suspend the subscription).
	 *
	 * `public static` because two callers share it: the `afterInsert` trigger callback (normal
	 * delivered-event path) and `LOG_Engine` (in-context path, when publishing would loop).
	 *
	 * @param events The platform-event chunk to persist.
	 */
	public static void persist(List<LogEntryEvent__e> events)
	{
		List<LogEntry__c> rowsToInsert = new List<LogEntry__c>();
		List<LogEntry__c> rowsToUpdate = new List<LogEntry__c>();
		List<LogEntryEvent__e> fingerprinted = new List<LogEntryEvent__e>();

		for(LogEntryEvent__e event : events)
		{
			if(String.isBlank(event.Fingerprint__c))
			{
				rowsToInsert.add(buildRow(event));
			}
			else
			{
				fingerprinted.add(event);
			}
		}

		List<LogEntry__c> aggregatedInserts = new List<LogEntry__c>();
		List<LogEntry__c> aggregatedUpdates = new List<LogEntry__c>();
		Boolean aggregated = true;
		try
		{
			aggregate(fingerprinted, aggregatedInserts, aggregatedUpdates);
		}
		catch(Exception error)
		{
			aggregated = false;
		}

		if(aggregated)
		{
			rowsToInsert.addAll(aggregatedInserts);
			rowsToUpdate.addAll(aggregatedUpdates);
		}
		else
		{
			for(LogEntryEvent__e event : fingerprinted)
			{
				rowsToInsert.add(buildRow(event));
			}
		}

		if(rowsToInsert.isEmpty() && rowsToUpdate.isEmpty())
		{
			return;
		}

		DML_Builder.newTransaction().systemModeInternal().doInsert(rowsToInsert).doUpdate(rowsToUpdate).execute();
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
	 */
	private static void aggregate(List<LogEntryEvent__e> events, List<LogEntry__c> rowsToInsert, List<LogEntry__c> rowsToUpdate)
	{
		if(events.isEmpty())
		{
			return;
		}
		if(simulateComputeFailure)
		{
			throw new IllegalArgumentException('Simulated aggregation failure for testing');
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
	 * `rollup:` key. Window assignment uses `CreatedDate` — the event PUBLISH time, not the trigger
	 * persist time — so the publish-to-persist delivery lag never mis-buckets (spec §4.3). This
	 * equals the original occurrence time only for immediately-published events; under log buffering
	 * (`suspendSaving`/`LogScope`) or the async DML-budget fallback, publish can lag the occurrence,
	 * so an occurrence near a UTC-midnight boundary may land in the adjacent day's rollup. Per-
	 * fingerprint TOTALS are unaffected — the reporting recipe SUMs OccurrenceCount__c across all
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
			String detailKey = PREFIX_DETAIL + event.Fingerprint__c;
			if(!detailSampleByKey.containsKey(detailKey))
			{
				detailSampleByKey.put(detailKey, event);
			}

			String dayBucket = UTIL_Date.toUtcDayBucket(event.CreatedDate ?? Datetime.now());
			String rollupKey = PREFIX_ROLLUP + event.Fingerprint__c + UTIL_String.COLON + dayBucket;
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
	 * present — presence-based, so a purged detail row re-arms on the next occurrence.
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
		logEntry.DurationMs__c = event.DurationMs__c;
		logEntry.ExceptionType__c = UTIL_String.abbreviate(event.ExceptionType__c, LogEntry__c.ExceptionType__c);
		logEntry.ExecutionEvent__c = event.ExecutionEvent__c;
		logEntry.Limits__c = UTIL_String.abbreviate(event.Limits__c, LogEntry__c.Limits__c);
		logEntry.LineNumber__c = event.LineNumber__c;
		logEntry.LogLevel__c = event.LogLevel__c;
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
		 * @description First event observed for this window — the rollup row's payload sample.
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
