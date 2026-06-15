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
 * @date February 2026, June 2026
 */
public inherited sharing class SEL_LogEntry extends SEL_Base
{
	/**
	 * @description Field set name used for testing purposes.
	 */
	@TestVisible
	private static final String FIELD_SET_TEST = UTIL_System.getManagedPackageNamespacePrefix() + 'Test';

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
}