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
 * - `target` — object API name, identifier, or `ALL`
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
 * @date May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_BypassAudit.setBypassReason('Customer data migration 2026-04-19');
 * UTIL_BypassAudit.emit('query', UTIL_BypassAudit.ACTION_BYPASS, 'sharing', null);
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
	 * @description Audit target recorded when a builder switches between sharing-enforced
	 * and sharing-bypassed execution.
	 */
	private static final String TARGET_SHARING = 'sharing';

	/**
	 * @description Audit target recorded when a builder opts out of `USER_MODE` enforcement.
	 */
	private static final String TARGET_SYSTEM_MODE = 'system-mode';

	/**
	 * @description Audit target recorded when a builder resets every security mode flag.
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
	 *     UTIL_BypassAudit.SURFACE_QUERY,
	 *     UTIL_BypassAudit.ACTION_BYPASS,
	 *     'sharing',
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
		LOG_Builder.LogEntry entry = LOG_Builder.build()
				.warn('Bypass audit: ' + surface + ' ' + action + ' "' + target + '"')
				.at(UTIL_BypassAudit.class.getName() + '.emit')
				.withContext(CONTEXT_CATEGORY, LOG_CATEGORY)
				.withContext(CONTEXT_SURFACE, surface)
				.withContext(CONTEXT_ACTION, action)
				.withContext(CONTEXT_TARGET, target);
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
	 * target string here, and the first executing terminal calls `flush()` to emit one
	 * `BYPASS` audit entry per queued target.
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
		 * @description Records the intent to emit a `BYPASS` audit entry whose target is
		 * `TARGET_SHARING` (a `withSharing()`/`bypassSharing()` mutation) when `flush()` next
		 * runs. Duplicate calls within the same queue are silently de-duped.
		 */
		public void queueSharing()
		{
			targets.add(TARGET_SHARING);
		}

		/**
		 * @description Records the intent to emit a `BYPASS` audit entry whose target is
		 * `TARGET_SYSTEM_MODE` (a `withSystemMode()` opt-out from `USER_MODE` enforcement)
		 * when `flush()` next runs. Duplicate calls within the same queue are silently de-duped.
		 */
		public void queueSystemMode()
		{
			targets.add(TARGET_SYSTEM_MODE);
		}

		/**
		 * @description Records the intent to emit a `BYPASS` audit entry whose target is
		 * `TARGET_SECURITY_MODE` (a `withoutSecurity()` reset of every security mode flag)
		 * when `flush()` next runs. Duplicate calls within the same queue are silently de-duped.
		 */
		public void queueSecurityMode()
		{
			targets.add(TARGET_SECURITY_MODE);
		}

		/**
		 * @description Emits one `BYPASS` audit entry per queued target via `UTIL_BypassAudit.emit`,
		 * then latches the idempotent-flush flag so subsequent calls on this instance are no-ops.
		 * Empty queues land on the latch without emitting.
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
				UTIL_BypassAudit.emit(surface, ACTION_BYPASS, target, null);
			}
		}
	}
}