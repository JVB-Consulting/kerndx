// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Framework-wide bypass audit emission helper. Centralises the structured
 * `LogEntryEvent__e` write that records every state-changing bypass call across the
 * trigger, query, DML, and validation surfaces into a single shape so admins can
 * forensically answer "who bypassed which framework mechanism, when, and why?" by
 * querying `SEL_LogEntry` for entries with context `category = 'BypassEvent'`.
 *
 * Audit entries record:
 * - `category` — always `BypassEvent`
 * - `surface` — `query` / `dml` / `validation` / `trigger-object` / `trigger-action`
 * - `action` — `BYPASS` / `CLEAR` / `CLEAR_ALL`
 * - `target` — object API name, identifier, or `ALL`; query/DML entries qualify the bypassed
 *   mode with the touched object (`sharing:Account`) and add `object`/`operation`/`rowCount`
 *   context describing what ran under the bypass
 * - `reason` — optional transaction-scoped string set via `setBypassReason`
 *
 * Emission is gated on the `BypassAudit_Enabled` `FeatureFlag__mdt` record, which is
 * default-on. Subscribers can disable via a `FeatureFlagStrategy__mdt` override when
 * the audit volume is too noisy for an environment.
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
 * @date May 2026, June 2026
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
	 * @description Context key recording the optional reason latched via `setBypassReason`.
	 */
	@TestVisible
	private static final String CONTEXT_REASON = 'reason';

	/**
	 * @description Context key recording the audit category for forensic filtering.
	 */
	@TestVisible
	private static final String CONTEXT_CATEGORY = 'category';

	/**
	 * @description Context key recording the resolved caller (`Class.method`) that performed the
	 * bypass. Mirrors the value written to `ClassMethod__c` so forensic queries that parse
	 * `ContextData__c` can read the caller without a separate field projection.
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
	 * `upsert`, `delete`, `undelete` — comma-joined when one builder ran several) performed
	 * under the bypass for the entry's object.
	 */
	@TestVisible
	private static final String CONTEXT_OPERATION = 'operation';

	/**
	 * @description Context key recording how many rows were submitted for the entry's object
	 * under the bypass — counted at terminal time, before the DML runs, so a failed or partially
	 * failed transaction still audits its submitted count. Always `0` on the query surface —
	 * result-set sizes are deliberately not threaded into the audit. Context-only: per-occurrence
	 * data such as row counts never joins the fingerprint identity tuple, or flood control would
	 * stop collapsing repeats.
	 */
	@TestVisible
	private static final String CONTEXT_ROW_COUNT = 'rowCount';

	/**
	 * @description Operation verb recorded by the query surface when a terminal flushes its
	 * audit queue. The DML surface derives its verbs (`insert`, `update`, …) from its
	 * `DatabaseOperation` enum instead of constants here.
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
	 * @description Surface identifier used when a transaction-scoped bypass reason latch is cleared.
	 * Emitted from `setBypassReason(null)` so the forensic trail records who dropped a latched
	 * reason and when, mirroring the CLEAR audit shape used by the other surfaces.
	 */
	public static final String SURFACE_REASON_LATCH = 'reason-latch';

	/**
	 * @description Sentinel target recorded for `CLEAR_ALL` actions.
	 */
	public static final String TARGET_ALL = 'ALL';

	/**
	 * @description Mode component of the audit target recorded when a builder switches between
	 * sharing-enforced and sharing-bypassed execution. Builder terminals qualify it with the
	 * touched object (`sharing:Account`); it is the full target only in the legacy no-footprint
	 * fallback.
	 */
	private static final String TARGET_SHARING = 'sharing';

	/**
	 * @description Mode component of the audit target recorded when a builder opts out of
	 * `USER_MODE` enforcement. Qualified with the touched object at builder terminals
	 * (`system-mode:Account`); bare only in the legacy no-footprint fallback.
	 */
	private static final String TARGET_SYSTEM_MODE = 'system-mode';

	/**
	 * @description Mode component of the audit target recorded when a builder resets every
	 * security mode flag. Qualified with the touched object at builder terminals
	 * (`security-mode:Account`); bare only in the legacy no-footprint fallback.
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
	 * @description Developer name of the framework feature flag that gates bypass audit
	 * emission. Default-on so audit entries flow without configuration; subscribers can
	 * disable in noisy environments via a `FeatureFlagStrategy__mdt` override on the
	 * `BypassAudit_Enabled` `FeatureFlag__mdt` record.
	 */
	private static final String FLAG_BYPASS_AUDIT_ENABLED = 'BypassAudit_Enabled';

	/**
	 * @description Caller recorded when no non-framework stack frame can be identified for an audit
	 * entry. Mirrors the audit helper's own emit method, preserving the pre-enrichment
	 * `ClassMethod__c` value as a fallback.
	 */
	private static final String DEFAULT_CALLER = UTIL_BypassAudit.class.getName() + '.emit';

	/**
	 * @description Names of the bypass-audit plumbing and the framework surfaces that call `emit` —
	 * skipped by `UTIL_System` when resolving the external caller so the resolved caller is the
	 * subscriber that invoked a surface, not the framework surface itself. This matters in an
	 * unmanaged org (where frames are not namespace-qualified); in a managed install the namespace
	 * skip covers these frames already. Derived from `class.getName()` so renames stay correct.
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
	 * @description Returns the latched transaction-scoped bypass reason, or `null` when
	 * no reason has been set.
	 *
	 * @return The latched reason, or `null`.
	 */
	public static String getBypassReason()
	{
		return bypassReason;
	}

	/**
	 * @description Latches a transaction-scoped reason that is attached to every subsequent
	 * bypass audit log entry. Pass `null` or empty to clear. When clearing a previously-latched
	 * reason, emits a `reason-latch` `CLEAR` audit entry so the forensic trail records who
	 * dropped the latch and when. Setting a new reason is unaudited because the reason flows
	 * into every downstream bypass audit emission already.
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
	 * mutating bypass call across the framework should invoke this helper so admins can
	 * filter `SEL_LogEntry` by context `category = 'BypassEvent'` for forensic review.
	 *
	 * Returns silently without emitting when the `BypassAudit_Enabled` `FeatureFlag__mdt` record
	 * resolves to `false`. Subscribers can disable runtime emission in noisy environments via
	 * `FeatureFlagStrategy__mdt` without redeploying source.
	 *
	 * Records the resolved caller (the first non-framework stack frame, via `UTIL_System`) in both
	 * `ClassMethod__c` and the `caller` context key, so the provenance column names the code that
	 * performed the bypass rather than this helper. `ShortMessage__c` carries a concise
	 * `action target` summary while `Message__c` keeps the fuller human-readable detail including
	 * the caller.
	 *
	 * Audit entries are emitted through `LOG_Builder.LogEntry.emitAsAudit()` so they accumulate
	 * in `LOG_Engine.auditLogBuffer` rather than the application log buffer — test assertions
	 * that count `LOG_Engine.getBufferSize()` or `LogEntry__c` rows are not contaminated by
	 * audit emissions and the `emit→deliver→persist→emit` cascade has no fixpoint to land in.
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
				.withSummary(action + UTIL_String.SPACE + target)
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
	 * @description Setter-time queue + terminal-time flush helper for the query and DML
	 * bypass surfaces. Each builder instance holds one queue keyed to its surface constant;
	 * setter calls (`bypassSharing` / `withSystemMode` / `withoutSecurity`) enqueue their
	 * target string here, terminals call `recordOperation` with the object/verb/row-count
	 * footprint of the operations submitted under the builder's bypasses, and the first
	 * executing terminal calls `flush()`.
	 *
	 * `flush()` emits one `BYPASS` audit entry per queued target **per touched object**, with
	 * the object-qualified target (`sharing:Account`) mirroring the validation surface's
	 * `object:` prefix pattern — so distinct objects on the same bypass call site carry
	 * distinct fingerprints and a novel object surfaces as a fresh detail row instead of a
	 * silent count bump. Each entry's context records the object, the operation verbs, and
	 * (for DML) the submitted row count. When no operation footprint was recorded by flush
	 * time — a queue flushed outside a builder terminal, or a terminal with no concrete
	 * records registered — the entry keeps the legacy bare-target shape.
	 *
	 * Idempotent — subsequent flushes on the same instance are no-ops, so a builder that runs
	 * `count()` followed by `toList()` produces a single audit entry per target rather than
	 * two. A builder that is created and dropped without ever executing emits nothing because
	 * `flush()` is the only emission path.
	 *
	 * Framework-internal — `public` (not `global`) so subscribers cannot bind to the type.
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
		 * @description Lazily-allocated set of audit target strings queued for emission. The
		 * `Set<String>` shape de-dupes repeated bypass calls within a single builder lifecycle.
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
		 * @description Lazily-allocated per-object operation footprints, keyed by SObject API
		 * name. Terminals feed this via `recordOperation`; `flush()` fans each queued target
		 * out across these keys to form the object-qualified targets and operation context.
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
		 * @description Idempotent-flush latch. Set to `true` on the first `flush()` call so
		 * subsequent flushes from terminals running on the same builder skip emission.
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
		 * @description Records the intent to emit `BYPASS` audit entries whose targets are
		 * qualified from `TARGET_SHARING` (a `withSharing()`/`bypassSharing()` mutation) when
		 * `flush()` next runs — `sharing:Account` per touched object, or bare `sharing` in the
		 * legacy no-footprint fallback. Duplicate calls within the same queue are silently
		 * de-duped.
		 */
		public void queueSharing()
		{
			targets.add(TARGET_SHARING);
		}

		/**
		 * @description Records the intent to emit `BYPASS` audit entries whose targets are
		 * qualified from `TARGET_SYSTEM_MODE` (a `withSystemMode()` opt-out from `USER_MODE`
		 * enforcement) when `flush()` next runs — `system-mode:Account` per touched object, or
		 * bare in the legacy no-footprint fallback. Duplicate calls within the same queue are
		 * silently de-duped.
		 */
		public void queueSystemMode()
		{
			targets.add(TARGET_SYSTEM_MODE);
		}

		/**
		 * @description Records the intent to emit `BYPASS` audit entries whose targets are
		 * qualified from `TARGET_SECURITY_MODE` (a `withoutSecurity()` reset of every security
		 * mode flag) when `flush()` next runs — `security-mode:Account` per touched object, or
		 * bare in the legacy no-footprint fallback. Duplicate calls within the same queue are
		 * silently de-duped.
		 */
		public void queueSecurityMode()
		{
			targets.add(TARGET_SECURITY_MODE);
		}

		/**
		 * @description Records the object/verb/row-count footprint of an operation that ran (or
		 * is about to run) under this builder's bypasses. Terminals call this immediately before
		 * `flush()`; repeated verbs for the same object de-dupe, row counts accumulate. No-ops
		 * when nothing can ever emit — no bypass target queued, or the flush latch already fired
		 * — so the no-bypass hot path pays no accumulation cost.
		 *
		 * @param objectApiName The SObject API name the operation touched.
		 * @param operation The operation verb (`OPERATION_QUERY`, or a DML verb such as `insert`).
		 * @param rows The number of rows submitted, or `null` on the query surface (counts as 0 —
		 *             result-set sizes are deliberately not threaded into the audit).
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
		 * @description Whether a `flush()` on this queue can still emit: at least one bypass
		 * target is queued and the idempotent-flush latch has not fired. Builder terminals
		 * consult this before walking their registered operations so the no-bypass hot path
		 * skips footprint accumulation entirely.
		 *
		 * @return `true` when an unflushed queue holds at least one target.
		 */
		public Boolean hasPendingEmission()
		{
			return !flushed && !targets.isEmpty();
		}

		/**
		 * @description Emits the queued `BYPASS` audit entries via `UTIL_BypassAudit.emit`, then
		 * latches the idempotent-flush flag so subsequent calls on this instance are no-ops.
		 * With recorded operation footprints, emits one entry per (target × object) with the
		 * object-qualified target and the operation context; without any, falls back to one
		 * legacy bare-target entry per queued target. Empty queues land on the latch without
		 * emitting.
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
	 * @description Per-object operation footprint accumulated by `AuditQueue.recordOperation`:
	 * the de-duped operation verbs and the total row count a builder submitted against one
	 * object under its bypasses (counted at terminal time, before the DML outcome is known).
	 * A sibling of `AuditQueue` (not nested) because Apex permits only one level of inner-class
	 * nesting.
	 */
	private class OperationFootprint
	{
		/**
		 * @description De-duped operation verbs recorded against the object (`query`, `insert`, …).
		 */
		private final Set<String> operations = new Set<String>();

		/**
		 * @description Total rows submitted against the object. Stays 0 on the query surface.
		 */
		private Integer rowCount = 0;
	}
}