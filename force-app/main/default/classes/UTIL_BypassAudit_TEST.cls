// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for `UTIL_BypassAudit` — verifies the framework-wide bypass audit
 * emission helper writes structured `LogEntry__c` rows with the expected context shape, honours
 * the transaction-scoped reason latch, and tolerates null / extras inputs without losing data.
 *
 * @see UTIL_BypassAudit
 *
 * @author Jason van Beukering
 *
 * @group Security
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_BypassAudit_TEST
{
	/**
	 * @description Surface label used by the canonical-shape test.
	 */
	private static final String SURFACE_QUERY = UTIL_BypassAudit.SURFACE_QUERY;

	/**
	 * @description Surface label used by the trigger-object emission test.
	 */
	private static final String SURFACE_TRIGGER_OBJECT = UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT;

	/**
	 * @description Reason string used when verifying the latch is included in audit context.
	 */
	private static final String REASON_TEXT = 'Customer data migration';

	/**
	 * @description Target identifier used by the tests for sharing-mode emission.
	 */
	private static final String TARGET_SHARING = 'sharing';

	/**
	 * @description Class+method label appended to log entries by `UTIL_BypassAudit.emit`.
	 */
	private static final String EMIT_AT = UTIL_BypassAudit.class.getName() + '.emit';

	/**
	 * @description Pins each `CONTEXT_*` and `LOG_CATEGORY` constant to the exact wire-contract
	 * literal that subscribers reading `kern__LogEntry__c.ContextData__c` rely on. Tests across
	 * the bypass surfaces navigate the parsed context via `context.get(UTIL_BypassAudit.CONTEXT_X)`,
	 * which validates the keys are CONSISTENT — this test pins the keys to their LITERAL values
	 * so a rename here breaks one test rather than silently leaving subscriber code stranded.
	 *
	 * @see UTIL_BypassAudit
	 */
	@IsTest
	private static void shouldPinAuditWireContractKeysAndCategoryToLiterals()
	{
		Assert.areEqual('category', UTIL_BypassAudit.CONTEXT_CATEGORY, 'CONTEXT_CATEGORY pins the wire-contract key');
		Assert.areEqual('surface', UTIL_BypassAudit.CONTEXT_SURFACE, 'CONTEXT_SURFACE pins the wire-contract key');
		Assert.areEqual('action', UTIL_BypassAudit.CONTEXT_ACTION, 'CONTEXT_ACTION pins the wire-contract key');
		Assert.areEqual('target', UTIL_BypassAudit.CONTEXT_TARGET, 'CONTEXT_TARGET pins the wire-contract key');
		Assert.areEqual('reason', UTIL_BypassAudit.CONTEXT_REASON, 'CONTEXT_REASON pins the wire-contract key');
		Assert.areEqual('BypassEvent', UTIL_BypassAudit.LOG_CATEGORY, 'LOG_CATEGORY pins the wire-contract category value');
	}

	/**
	 * @description Tests that `getBypassReason` returns `null` when no reason has been latched.
	 *
	 * @see UTIL_BypassAudit.getBypassReason
	 */
	@IsTest
	private static void shouldReturnNullWhenNoReasonLatched()
	{
		Assert.isNull(UTIL_BypassAudit.getBypassReason(), 'Reason latch should default to null');
	}

	/**
	 * @description Tests that `setBypassReason` latches a reason returned by `getBypassReason`.
	 *
	 * @see UTIL_BypassAudit.setBypassReason
	 * @see UTIL_BypassAudit.getBypassReason
	 */
	@IsTest
	private static void shouldRoundTripReasonThroughLatch()
	{
		UTIL_BypassAudit.setBypassReason(REASON_TEXT);

		Assert.areEqual(REASON_TEXT, UTIL_BypassAudit.getBypassReason(), 'Latch should hold the reason');
	}

	/**
	 * @description Tests that passing `null` to `setBypassReason` clears a previously latched reason.
	 *
	 * @see UTIL_BypassAudit.setBypassReason
	 */
	@IsTest
	private static void shouldClearReasonWhenSetToNull()
	{
		UTIL_BypassAudit.setBypassReason(REASON_TEXT);
		UTIL_BypassAudit.setBypassReason(null);

		Assert.isNull(UTIL_BypassAudit.getBypassReason(), 'Null reason should clear the latch');
	}

	/**
	 * @description Tests that clearing a previously-latched reason via `setBypassReason(null)` emits
	 * a `reason-latch` `CLEAR` audit entry whose `previousReason` extra captures the dropped value.
	 * Closes the asymmetry where bypass-set / clear surfaces emit but reason-latch clear does not,
	 * which would otherwise leave a forensic gap in "who dropped the migration reason?".
	 *
	 * @see UTIL_BypassAudit.setBypassReason
	 */
	@IsTest
	private static void shouldEmitClearAuditWhenReasonCleared()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.setBypassReason(REASON_TEXT);

		Test.startTest();
		UTIL_BypassAudit.setBypassReason(null);
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry(UTIL_BypassAudit.SURFACE_REASON_LATCH);
		Assert.isNotNull(entry, 'Clearing a latched reason should emit a reason-latch CLEAR audit entry');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
		Assert.areEqual(UTIL_BypassAudit.SURFACE_REASON_LATCH, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be reason-latch');
		Assert.areEqual(UTIL_BypassAudit.ACTION_CLEAR, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be CLEAR');
		Assert.areEqual(REASON_TEXT, context.get('previousReason'), 'previousReason extra should capture the dropped value');
	}

	/**
	 * @description Tests that calling `setBypassReason(null)` when no reason was previously latched
	 * does not emit a CLEAR audit entry — emitting on a no-op clear would pollute forensic queries
	 * with empty CLEARs that have no preceding BYPASS to match.
	 *
	 * @see UTIL_BypassAudit.setBypassReason
	 */
	@IsTest
	private static void shouldNotEmitClearAuditWhenReasonNeverLatched()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_BypassAudit.setBypassReason(null);
		Test.stopTest();

		Assert.isNull(findFirstAuditEntry(UTIL_BypassAudit.SURFACE_REASON_LATCH),
				'Clearing an already-empty latch should not emit an audit entry');
	}

	/**
	 * @description Tests that `emit` writes a `LogEntry__c` row with the canonical context keys
	 * (`category`, `surface`, `action`, `target`) at WARN level pointing at `UTIL_BypassAudit.emit`.
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitAuditEntryWithCanonicalContext()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, TARGET_SHARING, null);
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry(TARGET_SHARING);
		Assert.isNotNull(entry, 'emit should write a LogEntry__c row matching the target');
		Assert.areEqual(LoggingLevel.WARN.name(), entry.LogLevel__c, 'Audit entries must be WARN level');
		Assert.areEqual(EMIT_AT, entry.ClassMethod__c, 'Audit entries should record the helper method');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.areEqual(UTIL_BypassAudit.LOG_CATEGORY, context.get(UTIL_BypassAudit.CONTEXT_CATEGORY), 'Audit entry should record category');
		Assert.areEqual(SURFACE_QUERY, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Audit entry should record surface');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Audit entry should record action');
		Assert.areEqual(TARGET_SHARING, context.get(UTIL_BypassAudit.CONTEXT_TARGET), 'Audit entry should record target');
	}

	/**
	 * @description Tests that `emit` routes audit log events through the dedicated
	 * `LOG_Engine.auditLogBuffer` rather than the application log buffer (`LOG_Engine.logBuffer`)
	 * — the contract that `LOG_Builder.LogEntry.emitAsAudit()` is built to enforce. Without this
	 * contract, every framework-internal `withSystemMode()` call emitted during a suspended-saving
	 * batch would inflate the application buffer count, breaking subscriber and framework tests
	 * that count `LOG_Engine.getBufferSize()` (e.g. `LOG_Builder_TEST.bufferAutoFlushesWhenMaxSizeExceeded`).
	 *
	 * Pins the regression so a future refactor that re-routes audit emission through
	 * `LOG_Engine.publishEvents` (the application path) fails this test rather than silently
	 * regressing every log-counting test in the suite.
	 *
	 * @see UTIL_BypassAudit.emit
	 * @see LOG_Engine.publishAuditEvents
	 * @see LOG_Builder.LogEntry.emitAsAudit
	 */
	@IsTest
	private static void shouldRouteAuditToAuditBufferNotApplicationBuffer()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		LOG_Builder.suspendSaving();

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, 'buffer-target', null);
		Integer applicationBufferAfterAuditEmit = LOG_Engine.getBufferSize();
		Integer auditBufferAfterAuditEmit = LOG_Engine.getAuditBufferSize();
		LOG_Builder.resumeSaving();
		Test.stopTest();

		Assert.areEqual(0, applicationBufferAfterAuditEmit, 'Audit emission must not pollute the application log buffer');
		Assert.areEqual(1, auditBufferAfterAuditEmit, 'Audit emission must accumulate in the dedicated audit log buffer');
	}

	/**
	 * @description Tests that `emit` includes the latched reason in the audit context when set.
	 *
	 * @see UTIL_BypassAudit.emit
	 * @see UTIL_BypassAudit.setBypassReason
	 */
	@IsTest
	private static void shouldIncludeLatchedReasonInAuditContext()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.setBypassReason(REASON_TEXT);

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_TRIGGER_OBJECT, UTIL_BypassAudit.ACTION_BYPASS, 'Account', null);
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry('Account');
		Assert.isNotNull(entry, 'emit should write a LogEntry__c row for the trigger-object surface');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.areEqual(REASON_TEXT, context.get(UTIL_BypassAudit.CONTEXT_REASON), 'Latched reason should appear in context');
	}

	/**
	 * @description Tests that `emit` omits the reason context key when the latch is blank.
	 * Distinguishes between explicit empty-string clears and never-set reasons — both must
	 * suppress the reason key in the audit context.
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldOmitReasonContextKeyWhenLatchIsBlank()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.setBypassReason('');

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_CLEAR_ALL, UTIL_BypassAudit.TARGET_ALL, null);
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry(UTIL_BypassAudit.TARGET_ALL);
		Assert.isNotNull(entry, 'emit should write a LogEntry__c row for the clear-all action');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.isFalse(context.containsKey('reason'), 'Blank reason should be omitted from context');
	}

	/**
	 * @description Tests that `emit` merges caller-supplied context extras into the audit entry
	 * alongside the canonical keys, so callers can attach surface-specific metadata (e.g., the
	 * caller's class or correlation Id) without redefining the audit shape.
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldMergeContextExtrasIntoAuditEntry()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Map<String, Object> extras = new Map<String, Object>
		{
				'callerClass' => 'CTRL_Foo',
				'attemptCount' => 3
		};

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, 'system-mode', extras);
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry('system-mode');
		Assert.isNotNull(entry, 'emit should write a LogEntry__c row for the system-mode bypass');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.areEqual('CTRL_Foo', context.get('callerClass'), 'Extras should attach string values');
		Assert.areEqual('3', String.valueOf(context.get('attemptCount')), 'Extras should attach non-string values');
	}

	/**
	 * @description Tests that `emit` no-ops without writing a `LogEntry__c` row when the
	 * `BypassAudit_Enabled` `FeatureFlag__mdt` resolves to `false`. Subscribers disable the
	 * audit channel in noisy environments via a `FeatureFlagStrategy__mdt` override; the
	 * test simulates this by removing the flag from the `SEL_FeatureFlag.activeFlags` cache
	 * so the no-match path resolves to `false` (flag is null → returns false).
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldNoOpWhenKillSwitchDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		// Simulate the FeatureFlagStrategy__mdt override that subscribers use to disable
		// emission in noisy environments. Removing the flag from the active-flag cache makes
		// `UTIL_FeatureFlag.isEnabled('BypassAudit_Enabled')` return false (no-match path).
		SEL_FeatureFlag.activeFlags.remove('BypassAudit_Enabled');

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, 'killswitch-target', null);
		Test.stopTest();

		Assert.isNull(findFirstAuditEntry('killswitch-target'), 'emit should no-op when kill-switch is disabled');
	}

	/**
	 * @description Tests that `AuditQueue.queueSharing` records the canonical `TARGET_SHARING`
	 * value in the queue's de-duped target set. Asserts via the `@TestVisible` `targets` set
	 * so the contract (target shape, not just emission) is pinned at the queue boundary.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.queueSharing
	 */
	@IsTest
	private static void shouldEnqueueSharingTargetWhenQueueSharingCalled()
	{
		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);

		queue.queueSharing();

		Assert.areEqual(1, queue.targets.size(), 'queueSharing should add exactly one target');
		Assert.isTrue(queue.targets.contains('sharing'), 'queueSharing should enqueue TARGET_SHARING');
	}

	/**
	 * @description Tests that `AuditQueue.queueSystemMode` records the canonical
	 * `TARGET_SYSTEM_MODE` value in the queue's target set.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.queueSystemMode
	 */
	@IsTest
	private static void shouldEnqueueSystemModeTargetWhenQueueSystemModeCalled()
	{
		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);

		queue.queueSystemMode();

		Assert.areEqual(1, queue.targets.size(), 'queueSystemMode should add exactly one target');
		Assert.isTrue(queue.targets.contains('system-mode'), 'queueSystemMode should enqueue TARGET_SYSTEM_MODE');
	}

	/**
	 * @description Tests that `AuditQueue.queueSecurityMode` records the canonical
	 * `TARGET_SECURITY_MODE` value in the queue's target set.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.queueSecurityMode
	 */
	@IsTest
	private static void shouldEnqueueSecurityModeTargetWhenQueueSecurityModeCalled()
	{
		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);

		queue.queueSecurityMode();

		Assert.areEqual(1, queue.targets.size(), 'queueSecurityMode should add exactly one target');
		Assert.isTrue(queue.targets.contains('security-mode'), 'queueSecurityMode should enqueue TARGET_SECURITY_MODE');
	}

	/**
	 * @description Tests that repeated calls to the same `queue*` method de-dupe via the underlying
	 * `Set<String>`. A builder that chains `bypassSharing().bypassSharing()` should emit a single
	 * audit entry per surface, not one per setter invocation.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.queueSharing
	 */
	@IsTest
	private static void shouldDedupeRepeatedTargetsViaSet()
	{
		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);

		queue.queueSharing();
		queue.queueSharing();
		queue.queueSharing();

		Assert.areEqual(1, queue.targets.size(), 'Repeated queueSharing calls should de-dupe to one target');
	}

	/**
	 * @description Tests that `AuditQueue.flush` emits one `BYPASS` audit entry per distinct
	 * queued target. Queues all three known query-surface targets and asserts every one persists
	 * as a `LogEntry__c` row with the canonical context shape.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 */
	@IsTest
	private static void shouldEmitOneAuditPerTargetOnFlush()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);
		queue.queueSharing();
		queue.queueSystemMode();
		queue.queueSecurityMode();

		Test.startTest();
		queue.flush();
		Test.stopTest();

		Assert.isNotNull(findFirstAuditEntry('sharing'), 'flush should emit TARGET_SHARING audit entry');
		Assert.isNotNull(findFirstAuditEntry('system-mode'), 'flush should emit TARGET_SYSTEM_MODE audit entry');
		Assert.isNotNull(findFirstAuditEntry('security-mode'), 'flush should emit TARGET_SECURITY_MODE audit entry');
	}

	/**
	 * @description Tests that `AuditQueue.flush` emits audit entries on the surface passed to
	 * the constructor — `SURFACE_DML` queues emit DML-surface audits, `SURFACE_QUERY` queues
	 * emit query-surface audits. Pins the constructor-surface contract.
	 *
	 * @see UTIL_BypassAudit.AuditQueue
	 */
	@IsTest
	private static void shouldUseSurfaceFromConstructor()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.AuditQueue dmlQueue = new UTIL_BypassAudit.AuditQueue(UTIL_BypassAudit.SURFACE_DML);
		dmlQueue.queueSharing();

		Test.startTest();
		dmlQueue.flush();
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry('sharing');
		Assert.isNotNull(entry, 'flush should emit an audit entry for queueSharing');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.areEqual(UTIL_BypassAudit.SURFACE_DML, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Audit surface should mirror constructor argument');
	}

	/**
	 * @description Tests that a second `flush` call on the same `AuditQueue` instance is a no-op.
	 * A query builder that runs `count()` followed by `toList()` flushes twice; without idempotence
	 * the audit trail would double-count every bypass.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 */
	@IsTest
	private static void shouldNoOpOnSecondFlushSameInstance()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);
		queue.queueSharing();

		Test.startTest();
		queue.flush();
		queue.flush();
		Test.stopTest();

		Integer matchCount = 0;
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null && 'sharing'.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET)))
			{
				matchCount++;
			}
		}
		Assert.areEqual(1, matchCount, 'Idempotent flush should produce exactly one audit entry across repeated calls');
	}

	/**
	 * @description Tests that `flush` on an empty queue latches the idempotent flag without
	 * writing any `LogEntry__c` rows. A builder created and dropped without ever calling a
	 * bypass setter must produce no audit entries.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 */
	@IsTest
	private static void shouldFlushEmptyQueueWithoutEmissionButLatched()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);

		Test.startTest();
		queue.flush();
		Test.stopTest();

		Assert.isTrue(queue.flushed, 'Empty queue flush should still latch the idempotent flag');
		Assert.isNull(findFirstAuditEntry('sharing'), 'Empty queue flush should emit nothing');
	}

	/**
	 * @description Tests that an `AuditQueue` whose `flush` is never called leaves the
	 * idempotent-flush latch clear and retains its queued targets. Pins the design contract
	 * that emission happens at terminal time, not setter time, so a builder dropped before
	 * execution produces no `UTIL_BypassAudit.emit` calls from this queue. Asserts via the
	 * `@TestVisible` `flushed` / `targets` state rather than SOQL because framework-internal
	 * `withSystemMode` calls during test setup can independently emit audits, which would
	 * fail a global "no LogEntry__c rows" assertion without proving anything about THIS queue.
	 *
	 * @see UTIL_BypassAudit.AuditQueue
	 */
	@IsTest
	private static void shouldNotEmitWhenNeverFlushed()
	{
		UTIL_BypassAudit.AuditQueue queue = new UTIL_BypassAudit.AuditQueue(SURFACE_QUERY);

		queue.queueSharing();
		queue.queueSystemMode();
		queue.queueSecurityMode();

		Assert.isFalse(queue.flushed, 'Never-flushed queue should leave the latch clear');
		Assert.areEqual(3, queue.targets.size(), 'Queued targets should remain pending until flush is called');
	}

	/**
	 * @description Parses the persisted `ContextData__c` JSON envelope and returns the inner
	 * `contextData` map. Delegates to `SEL_LogEntry.parseContextDataForTest` so the wrapper format
	 * can evolve in one place without breaking assertions in 5+ test classes.
	 *
	 * @param contextDataJson The raw `ContextData__c` value from the persisted log entry.
	 *
	 * @return The unwrapped context map.
	 */
	private static Map<String, Object> parseContextData(String contextDataJson)
	{
		LogEntry__c entry = new LogEntry__c(ContextData__c = contextDataJson);
		return SEL_LogEntry.parseContextDataForTest(entry);
	}

	/**
	 * @description Returns the most-recent persisted bypass audit `LogEntry__c` whose context `target`
	 * matches the supplied value. Filtering by target keeps assertions stable when `setupLoggerForTest`
	 * or other framework-internal `withSystemMode()` calls also emit audit entries during the test
	 * setup phase. Iterates entries in CreatedDate-descending order so the first match is the latest
	 * emission.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The matching `LogEntry__c`, or `null` if none exists.
	 */
	private static LogEntry__c findFirstAuditEntry(String target)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null && target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET)))
			{
				return entry;
			}
		}
		return null;
	}
}