// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Writes an audit entry each time code turns a framework bypass on or off. A bypass switches off one
 * framework check: a trigger, query sharing or security, a DML security mode, or a validation rule. A trigger or
 * validation-rule bypass lasts until it is cleared. A query or DML bypass (sharing or a security mode) applies only
 * to the one builder that sets it. The parts of the framework that offer a bypass are called surfaces: trigger, query, DML and
 * validation. Every audit entry is a `LogEntryEvent__e` with the same shape, so an admin can answer "who bypassed
 * which framework check, when, and why?" by querying `SEL_LogEntry` for entries whose context has
 * `category = 'BypassEvent'`.
 *
 * Audit entries record:
 * - `category`: always `BypassEvent`
 * - `surface`: `query` / `dml` / `validation` / `trigger-object` / `trigger-action`
 * - `action`: `BYPASS` / `CLEAR` / `CLEAR_ALL`
 * - `target`: object API name, identifier, or `ALL`. Query and DML entries add the touched object to the bypassed
 *   mode (`sharing:Account`), and add `object`, `operation` and `rowCount` context that describes what ran under
 *   the bypass
 * - `reason`: an optional text for the whole transaction, set with `setBypassReason`
 *
 * Entries are written only while the `BypassAudit_Enabled` `FeatureFlag__mdt` record is on. It is on by default.
 * A subscriber can switch it off with a `FeatureFlagStrategy__mdt` override when an environment writes too many
 * audit entries.
 *
 * @see TRG_Base
 * @see QRY_Builder
 * @see DML_Builder
 * @see UTIL_ValidationRule
 * @see UTIL_BypassAudit_TEST
 *
 * @author Jason van Beukering
 *
 * @group Security
 *
 * @date May 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_BypassAudit.setBypassReason('Customer data migration 2026-04-19');
 * UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT, UTIL_BypassAudit.ACTION_BYPASS, 'Account', null);
 * ```
 */
public inherited sharing class UTIL_BypassAudit
{
	/**
	 * @description Context-key value identifying bypass audit entries in `SEL_LogEntry`.
	 */
	@TestVisible
	private static final String LOG_CATEGORY = 'BypassEvent';

	/**
	 * @description Context key recording the surface that emitted the audit entry.
	 */
	@TestVisible
	private static final String CONTEXT_SURFACE = 'surface';

	/**
	 * @description Context key recording the bypass action.
	 */
	@TestVisible
	private static final String CONTEXT_ACTION = 'action';

	/**
	 * @description Context key recording the bypass target identifier.
	 */
	@TestVisible
	private static final String CONTEXT_TARGET = 'target';

	/**
	 * @description Context key recording the optional reason set with `setBypassReason`.
	 */
	@TestVisible
	private static final String CONTEXT_REASON = 'reason';

	/**
	 * @description Context key recording the audit category, so audit entries can be filtered.
	 */
	@TestVisible
	private static final String CONTEXT_CATEGORY = 'category';

	/**
	 * @description Context key recording the resolved caller (`Class.method`) that performed the
	 * bypass. It holds the same value as `ClassMethod__c`, so a query that reads `ContextData__c`
	 * can find the caller without also reading that field.
	 */
	@TestVisible
	private static final String CONTEXT_CALLER = 'caller';

	/**
	 * @description Context key recording the SObject API name an operation-scoped bypass entry
	 * covers. Written by `AuditQueue.flush()` alongside the object-qualified target.
	 */
	@TestVisible
	private static final String CONTEXT_OBJECT = 'object';

	/**
	 * @description Context key recording the operation verbs (`query`, `insert`, `update`,
	 * `upsert`, `delete`, `undelete`; joined with commas when one builder ran several) performed
	 * under the bypass for the entry's object.
	 */
	@TestVisible
	private static final String CONTEXT_OPERATION = 'operation';

	/**
	 * @description Context key recording how many rows were submitted for the entry's object under the bypass. The
	 * count is taken when the builder runs, before the DML itself, so a transaction that fails in whole or in part
	 * still audits the rows it submitted. The query surface always records `0`: the audit does not record how many
	 * rows a query returned. The count is context only. It is never part of the fingerprint (the values that
	 * decide whether two log entries are the same problem), because a value that changes on every call would stop
	 * flood control from grouping repeats.
	 */
	@TestVisible
	private static final String CONTEXT_ROW_COUNT = 'rowCount';

	/**
	 * @description Context key flagging a trigger-action bypass audit entry whose target matched no registered
	 * `TriggerAction__mdt` row when the bypass was called. The call still compiles and is audited, but the bypass
	 * never takes effect (a typo, or the wrong namespace form). Writing the entry never throws and never blocks:
	 * bypassing an action that is not deployed yet, or cannot be found, is a legitimate way to stop an incident.
	 * The flag keeps the audit trail honest instead of claiming the action was switched off. Public (not
	 * `@TestVisible`) because `TRG_Base.logBypassEvent`, in another class, attaches it.
	 */
	public static final String CONTEXT_UNMATCHED_TARGET = 'unmatchedTarget';

	/**
	 * @description Operation verb recorded by the query surface when a query runs and writes its
	 * queued audit entries. The DML surface takes its verbs (`insert`, `update`, and so on) from
	 * its `DatabaseOperation` enum instead of constants here.
	 */
	public static final String OPERATION_QUERY = 'query';

	/**
	 * @description Audit action recorded when a bypass is set or added.
	 */
	public static final String ACTION_BYPASS = 'BYPASS';

	/**
	 * @description Audit action recorded when a single bypass is cleared.
	 */
	public static final String ACTION_CLEAR = 'CLEAR';

	/**
	 * @description Audit action recorded when every bypass for a surface is cleared.
	 */
	public static final String ACTION_CLEAR_ALL = 'CLEAR_ALL';

	/**
	 * @description Surface identifier used by the trigger object-name bypass surface.
	 */
	public static final String SURFACE_TRIGGER_OBJECT = 'trigger-object';

	/**
	 * @description Surface identifier used by the trigger action-class bypass surface.
	 */
	public static final String SURFACE_TRIGGER_ACTION = 'trigger-action';

	/**
	 * @description Surface identifier used by the query bypass surfaces (`QRY_Builder`).
	 */
	public static final String SURFACE_QUERY = 'query';

	/**
	 * @description Surface identifier used by the DML bypass surfaces (`DML_Builder`).
	 */
	public static final String SURFACE_DML = 'dml';

	/**
	 * @description Surface identifier used by the validation bypass surfaces (`UTIL_ValidationRule`).
	 */
	public static final String SURFACE_VALIDATION = 'validation';

	/**
	 * @description Surface identifier used when the bypass reason set for the transaction is cleared.
	 * Written by `setBypassReason(null)`, so the audit trail records who removed the reason and when,
	 * in the same `CLEAR` shape the other surfaces use.
	 */
	public static final String SURFACE_REASON_LATCH = 'reason-latch';

	/**
	 * @description Fixed target value recorded for `CLEAR_ALL` actions.
	 */
	public static final String TARGET_ALL = 'ALL';

	/**
	 * @description Mode part of the audit target recorded when a builder switches between
	 * sharing-enforced and sharing-bypassed execution. When the builder runs, the touched object is
	 * added to it (`sharing:Account`). It stands alone only in the older fallback shape, used when
	 * the builder recorded no operation.
	 */
	private static final String TARGET_SHARING = 'sharing';

	/**
	 * @description Mode part of the audit target recorded when a builder opts out of
	 * `USER_MODE` enforcement. When the builder runs, the touched object is added to it
	 * (`system-mode:Account`). It stands alone only in the older fallback shape, used when the
	 * builder recorded no operation.
	 */
	private static final String TARGET_SYSTEM_MODE = 'system-mode';

	/**
	 * @description Mode part of the audit target recorded when a builder resets every
	 * security mode flag. When the builder runs, the touched object is added to it
	 * (`security-mode:Account`). It stands alone only in the older fallback shape, used when the
	 * builder recorded no operation.
	 */
	private static final String TARGET_SECURITY_MODE = 'security-mode';

	/**
	 * @description Prefix recorded on validation-surface `BYPASS` audits whose target is
	 * an SObject API name (`bypassObject`). Concatenated with the API name to form the
	 * audit target string (e.g. `object:Account`).
	 */
	public static final String TARGET_PREFIX_OBJECT = 'object:';

	/**
	 * @description Prefix recorded on validation-surface `BYPASS` audits whose target is
	 * a `ValidationRuleGroup__mdt` DeveloperName (`bypassGroup`). Concatenated with the
	 * group DeveloperName to form the audit target string (e.g. `group:Sales_Account_Validations`).
	 */
	public static final String TARGET_PREFIX_GROUP = 'group:';

	/**
	 * @description Prefix recorded on validation-surface `BYPASS` audits whose target is
	 * a `ValidationRule__mdt` DeveloperName (`bypassRule`). Concatenated with the rule
	 * DeveloperName to form the audit target string (e.g. `rule:Account_Requires_Industry`).
	 */
	public static final String TARGET_PREFIX_RULE = 'rule:';

	/**
	 * @description Developer name of the framework feature flag that switches bypass audit entries
	 * on or off. It is on by default, so audit entries are written without any setup. A subscriber
	 * can switch it off in a noisy environment with a `FeatureFlagStrategy__mdt` override on the
	 * `BypassAudit_Enabled` `FeatureFlag__mdt` record.
	 */
	private static final String FLAG_BYPASS_AUDIT_ENABLED = 'BypassAudit_Enabled';

	/**
	 * @description Caller recorded when no stack frame outside the framework can be found for an
	 * audit entry. It names this class's own emit method, which is what `ClassMethod__c` held
	 * before the real caller was looked up, and stays as the fallback.
	 */
	private static final String DEFAULT_CALLER = UTIL_BypassAudit.class.getName() + '.emit';

	/**
	 * @description Names of the bypass audit classes and of the framework surfaces that call `emit`.
	 * `UTIL_System` skips these when it looks for the external caller, so the recorded caller is the
	 * subscriber code that used a surface, not the framework surface itself. This matters in an
	 * unmanaged org, where frames do not carry a namespace. In a managed install the namespace check
	 * already skips these frames. Built from `class.getName()`, so a renamed class stays correct.
	 * Direct-`emit` callers (`UTIL_ValidationRule`, `TRG_Base`) and the builders whose `AuditQueue`
	 * flush emits (`DML_Builder`, `QRY_Builder`) are listed; framework code that itself calls those
	 * builders (e.g. `UTIL_Sharing`) resolves to that intermediary in an unmanaged org, and to the
	 * true subscriber in a managed/namespaced install.
	 */
	private static final Set<String> BYPASS_AUDIT_FRAMEWORK_CLASSES = new Set<String>
	{
			UTIL_BypassAudit.class.getName(),
			UTIL_ValidationRule.class.getName(),
			TRG_Base.class.getName(),
			DML_Builder.class.getName(),
			QRY_Builder.class.getName()
	};

	/**
	 * @description Transaction-scoped reason string attached to every subsequent bypass audit
	 * log entry. Set via `setBypassReason(String)`. Cleared by passing null or empty.
	 */
	@TestVisible
	private static String bypassReason;

	/**
	 * @description Returns the bypass reason set for this transaction, or `null` when no reason
	 * has been set.
	 *
	 * @return The reason, or `null`.
	 */
	public static String getBypassReason()
	{
		return bypassReason;
	}

	/**
	 * @description Sets a reason for the rest of the transaction. The reason is attached to every
	 * bypass audit entry written after it. Pass `null` or empty to clear it. Clearing a reason that
	 * was set writes a `CLEAR` audit entry on the `SURFACE_REASON_LATCH` surface, so the audit
	 * trail records who removed it and when. Setting a new reason is not audited, because the
	 * reason already appears on every later bypass audit entry.
	 *
	 * @param reason The reason string to record, or `null` to clear.
	 *
	 * @example
	 * ```apex
	 * UTIL_BypassAudit.setBypassReason('Customer data migration 2026-04-19');
	 * TRG_Base.bypass(Account.SObjectType);
	 * UTIL_BypassAudit.setBypassReason(null);
	 * ```
	 */
	public static void setBypassReason(String reason)
	{
		String previousReason = bypassReason;
		bypassReason = reason;
		if(String.isBlank(reason) && String.isNotBlank(previousReason))
		{
			Map<String, Object> extras = new Map<String, Object> {'previousReason' => previousReason};
			emit(SURFACE_REASON_LATCH, ACTION_CLEAR, SURFACE_REASON_LATCH, extras);
		}
	}

	/**
	 * @description Emits a structured `LogEntryEvent__e` for a bypass state change. Every
	 * bypass call that changes state, anywhere in the framework, should call this helper, so admins
	 * can filter `SEL_LogEntry` by context `category = 'BypassEvent'` to review what happened.
	 *
	 * Returns without writing anything when the `BypassAudit_Enabled` `FeatureFlag__mdt` record
	 * is off. A subscriber can switch it off in a noisy environment with a `FeatureFlagStrategy__mdt`
	 * override, without deploying code.
	 *
	 * Records the resolved caller (the first stack frame outside the framework, found by `UTIL_System`)
	 * in both `ClassMethod__c` and the `caller` context key, so that column names the code that
	 * performed the bypass and not this helper. `ShortMessage__c` holds a short
	 * `action target (surface)` summary, and `Message__c` keeps the longer readable detail,
	 * including the caller. The surface is in the summary because it is part of the fingerprint
	 * (the values that decide whether two entries are the same problem). The same action on the
	 * same target, audited from two surfaces, is saved as two grouped problems: for example, a
	 * clear-all that empties both trigger bypass lists. Without the surface those two rows would
	 * read the same, and the grouping would look broken. The one surface whose target is the surface
	 * itself (the bypass reason, `SURFACE_REASON_LATCH`) leaves the surface out of the summary,
	 * because the summary would then name the same surface twice.
	 *
	 * Audit entries are emitted through `LOG_Builder.LogEntry.emitAsAudit()`, so they collect in
	 * `LOG_Engine.auditLogBuffer` and not in the application log buffer. Tests that count
	 * `LOG_Engine.getBufferSize()` or `LogEntry__c` rows therefore do not see audit entries. It also
	 * stops a loop: delivering and saving a log entry can never emit another audit entry that would
	 * then be delivered and saved in turn.
	 *
	 * @param surface The surface that was bypassed (use the `SURFACE_*` constants where possible).
	 * @param action The bypass action (`ACTION_BYPASS` / `ACTION_CLEAR` / `ACTION_CLEAR_ALL`).
	 * @param target Object API name, identifier, or `TARGET_ALL` for clear-all actions.
	 * @param contextExtras Optional additional context keys to attach. May be `null`.
	 *
	 * @example
	 * ```apex
	 * UTIL_BypassAudit.emit
	 * (
	 *     UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT,
	 *     UTIL_BypassAudit.ACTION_BYPASS,
	 *     'Account',
	 *     null
	 * );
	 * ```
	 */
	public static void emit(String surface, String action, String target, Map<String, Object> contextExtras)
	{
		if(!UTIL_FeatureFlag.isEnabled(FLAG_BYPASS_AUDIT_ENABLED))
		{
			return;
		}
		String caller = UTIL_System.resolveExternalCaller(BYPASS_AUDIT_FRAMEWORK_CLASSES, DEFAULT_CALLER);
		LOG_Builder.LogEntry entry = LOG_Builder.build()
				.warn('Bypass audit: ' + surface + UTIL_String.SPACE + action + ' "' + target + '" by ' + caller)
				.withSummary(surface == target ? action + UTIL_String.SPACE + target : action + UTIL_String.SPACE + target + UTIL_String.SPACE + '(' + surface + ')')
				.at(caller)
				.withContext(CONTEXT_CATEGORY, LOG_CATEGORY)
				.withContext(CONTEXT_SURFACE, surface)
				.withContext(CONTEXT_ACTION, action)
				.withContext(CONTEXT_TARGET, target)
				.withContext(CONTEXT_CALLER, caller);
		entry.withFingerprintInternal(LOG_Builder.RESERVED_FINGERPRINT_PREFIX + UTIL_Crypto.generateSHA256Hash(
				String.join(new List<String> {caller, surface, action, target, UserInfo.getUserId()}, UTIL_String.PIPE)));
		if(contextExtras != null)
		{
			for(String key : contextExtras.keySet())
			{
				entry.withContext(key, contextExtras.get(key));
			}
		}
		if(String.isNotBlank(bypassReason))
		{
			entry.withContext(CONTEXT_REASON, bypassReason);
		}
		entry.emitAsAudit();
	}

	/**
	 * @description Collects the bypass audit entries of the query and DML surfaces and writes them
	 * when the builder runs. Each builder holds one queue for its surface constant. A bypass setter
	 * (`bypassSharing` / `withSystemMode` / `withoutSecurity`) adds its target string here. A
	 * terminal method (the builder call that runs the query or the DML) calls `recordOperation` with
	 * the object, verb and row count of each operation submitted under the builder's bypasses. The
	 * first terminal method that runs calls `flush()`.
	 *
	 * `flush()` emits one `BYPASS` audit entry per queued target **per touched object**. The target
	 * names the object (`sharing:Account`), like the `object:` prefix of the validation surface. So
	 * different objects on the same bypass call site get different fingerprints, and a new object
	 * shows as a new detail row instead of only raising a count. Each entry's context records the
	 * object, the operation verbs, and (for DML) the submitted row count. When no operation was
	 * recorded by the time of the flush (a queue flushed outside a terminal method, or a terminal
	 * method with no records registered), the entry keeps the older bare-target shape.
	 *
	 * Safe to call more than once: later flushes on the same instance do nothing. A builder that runs
	 * `count()` and then `toList()` produces one audit entry per target, not two. A builder that is
	 * created and dropped without ever running writes nothing, because `flush()` is the only path
	 * that writes.
	 *
	 * Framework-internal: `public` (not `global`) so subscribers cannot bind to the type.
	 *
	 * @see QRY_Builder
	 * @see DML_Builder
	 */
	public inherited sharing class AuditQueue
	{
		/**
		 * @description The `UTIL_BypassAudit.SURFACE_*` constant identifying which surface
		 * this queue's audit entries are emitted under. Set in the constructor; never mutated.
		 */
		private final String surface;

		/**
		 * @description Set of audit target strings queued for emission, created on first use. Because
		 * it is a `Set<String>`, a bypass called twice in one builder's life is queued once.
		 */
		@TestVisible
		private final Set<String> targets
		{
			get
			{
				if(targets == null)
				{
					targets = new Set<String>();
				}
				return targets;
			}
			private set;
		}

		/**
		 * @description Operation footprints (object, verbs, row count) for each object, keyed by SObject
		 * API name and created on first use. Terminal methods fill it through `recordOperation`.
		 * `flush()` combines each queued target with each of these keys to build the object-qualified
		 * targets and the operation context.
		 */
		private final Map<String, OperationFootprint> footprintsByObject
		{
			get
			{
				if(footprintsByObject == null)
				{
					footprintsByObject = new Map<String, OperationFootprint>();
				}
				return footprintsByObject;
			}
			private set;
		}

		/**
		 * @description Set to `true` on the first `flush()` call, so later flushes from terminal methods
		 * on the same builder write nothing.
		 */
		@TestVisible
		private Boolean flushed = false;

		/**
		 * @description Constructs a queue keyed to the given audit surface constant.
		 *
		 * @param surface The `UTIL_BypassAudit.SURFACE_*` constant identifying which surface
		 *                this queue's audit entries should be emitted under (e.g. `SURFACE_QUERY`,
		 *                `SURFACE_DML`).
		 */
		public AuditQueue(String surface)
		{
			this.surface = surface;
		}

		/**
		 * @description Records that `BYPASS` audit entries must be written, with targets built from
		 * `TARGET_SHARING` (a `withSharing()` or `bypassSharing()` change), when `flush()` next runs:
		 * `sharing:Account` for each touched object, or a bare `sharing` in the older fallback shape used
		 * when no operation was recorded. A second call on the same queue is ignored.
		 */
		public void queueSharing()
		{
			targets.add(TARGET_SHARING);
		}

		/**
		 * @description Records that `BYPASS` audit entries must be written, with targets built from
		 * `TARGET_SYSTEM_MODE` (a `withSystemMode()` opt-out from `USER_MODE` enforcement), when
		 * `flush()` next runs: `system-mode:Account` for each touched object, or a bare target in the
		 * older fallback shape used when no operation was recorded. A second call on the same queue is
		 * ignored.
		 */
		public void queueSystemMode()
		{
			targets.add(TARGET_SYSTEM_MODE);
		}

		/**
		 * @description Records that `BYPASS` audit entries must be written, with targets built from
		 * `TARGET_SECURITY_MODE` (a `withoutSecurity()` reset of every security mode flag), when
		 * `flush()` next runs: `security-mode:Account` for each touched object, or a bare target in the
		 * older fallback shape used when no operation was recorded. A second call on the same queue is
		 * ignored.
		 */
		public void queueSecurityMode()
		{
			targets.add(TARGET_SECURITY_MODE);
		}

		/**
		 * @description Records the object, verb and row count of an operation that ran (or is about to
		 * run) under this builder's bypasses. Terminal methods call this just before `flush()`. A verb
		 * repeated for the same object is stored once; row counts add up. Does nothing when nothing can
		 * ever be written (no bypass target is queued, or the queue was already flushed), so code that
		 * uses no bypass pays no extra cost.
		 *
		 * @param objectApiName The SObject API name the operation touched.
		 * @param operation The operation verb (`OPERATION_QUERY`, or a DML verb such as `insert`).
		 * @param rows The number of rows submitted, or `null` on the query surface (counted as 0,
		 *             because the audit does not record how many rows a query returned).
		 */
		public void recordOperation(String objectApiName, String operation, Integer rows)
		{
			if(!hasPendingEmission())
			{
				return;
			}
			OperationFootprint footprint = footprintsByObject.get(objectApiName);
			if(footprint == null)
			{
				footprint = new OperationFootprint();
				footprintsByObject.put(objectApiName, footprint);
			}
			footprint.operations.add(operation);
			footprint.rowCount += rows ?? 0;
		}

		/**
		 * @description Whether a `flush()` on this queue can still write anything: at least one bypass
		 * target is queued and the queue has not been flushed yet. Terminal methods check this before
		 * they walk their registered operations, so code that uses no bypass skips that work.
		 *
		 * @return `true` when an unflushed queue holds at least one target.
		 */
		public Boolean hasPendingEmission()
		{
			return !flushed && !targets.isEmpty();
		}

		/**
		 * @description Writes the queued `BYPASS` audit entries through `UTIL_BypassAudit.emit`, then
		 * marks the queue as flushed so later calls on this instance do nothing. When operations were
		 * recorded, writes one entry for each pair of target and object, with the object-qualified target
		 * and the operation context. When none were recorded, falls back to one bare-target entry per
		 * queued target. An empty queue is marked as flushed without writing anything.
		 */
		public void flush()
		{
			if(flushed)
			{
				return;
			}
			flushed = true;
			for(String target : targets)
			{
				if(footprintsByObject.isEmpty())
				{
					UTIL_BypassAudit.emit(surface, ACTION_BYPASS, target, null);
					continue;
				}
				for(String objectApiName : footprintsByObject.keySet())
				{
					OperationFootprint footprint = footprintsByObject.get(objectApiName);
					UTIL_BypassAudit.emit(surface, ACTION_BYPASS, target + ':' + objectApiName, new Map<String, Object>
					{
							CONTEXT_OBJECT => objectApiName,
							CONTEXT_OPERATION => String.join(new List<String>(footprint.operations), ','),
							CONTEXT_ROW_COUNT => footprint.rowCount
					});
				}
			}
		}
	}

	/**
	 * @description Operation footprint for one object, built by `AuditQueue.recordOperation`:
	 * the distinct operation verbs and the total row count a builder submitted against one
	 * object under its bypasses (counted at terminal time, before the DML outcome is known).
	 * A sibling of `AuditQueue` (not nested) because Apex permits only one level of inner-class
	 * nesting.
	 */
	private class OperationFootprint
	{
		/**
		 * @description The distinct operation verbs recorded against the object (`query`, `insert`, and so on).
		 */
		private final Set<String> operations = new Set<String>();

		/**
		 * @description Total rows submitted against the object. Stays 0 on the query surface.
		 */
		private Integer rowCount = 0;
	}
}