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
 * @date May 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
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
	 * @description Fallback caller (`Class.method` of the audit helper) recorded on a bypass audit
	 * entry when caller capture is disabled or no non-framework stack frame is found.
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
		Assert.areEqual('object', UTIL_BypassAudit.CONTEXT_OBJECT, 'CONTEXT_OBJECT pins the wire-contract key');
		Assert.areEqual('operation', UTIL_BypassAudit.CONTEXT_OPERATION, 'CONTEXT_OPERATION pins the wire-contract key');
		Assert.areEqual('rowCount', UTIL_BypassAudit.CONTEXT_ROW_COUNT, 'CONTEXT_ROW_COUNT pins the wire-contract key');
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
	 * (`category`, `surface`, `action`, `target`) at WARN level. With caller capture on (default),
	 * `ClassMethod__c` records the real caller — here the test method — rather than the audit helper.
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
		assertResolvedCaller(entry.ClassMethod__c, 'With caller capture on (default), ClassMethod records the real caller, not the audit helper');
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
	 * @description Tests that `emit` records the real caller — the first non-framework stack frame —
	 * in `ClassMethod__c` and the `caller` context. Here the direct caller is the test method, so
	 * both must name `UTIL_BypassAudit_TEST` rather than the audit helper, closing the
	 * hardcoded-origin gap.
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldRecordRealCallerInClassMethodAndContext()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, 'caller-capture-target', null);
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry('caller-capture-target');
		Assert.isNotNull(entry, 'emit should write a LogEntry__c row for the caller-capture target');
		assertResolvedCaller(entry.ClassMethod__c, 'ClassMethod should name the real caller');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.areEqual(entry.ClassMethod__c, context.get(UTIL_BypassAudit.CONTEXT_CALLER), 'caller context should mirror ClassMethod');
	}

	/**
	 * @description Tests that a bypass emitted THROUGH a framework surface (here `UTIL_ValidationRule`)
	 * resolves the caller past the surface to the subscriber that invoked it — the realistic path,
	 * which (unlike a direct `emit` call) has an intervening framework frame. In an unmanaged org
	 * the surface frame is not namespace-skipped, so the surface class must be in the audit
	 * framework-class skip set for this to hold.
	 *
	 * @see UTIL_BypassAudit.emit
	 * @see UTIL_ValidationRule.bypassObject
	 */
	@IsTest
	private static void shouldResolveCallerThroughValidationSurface()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_ValidationRule.bypassObject('SurfaceCallerObject');
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry(UTIL_BypassAudit.TARGET_PREFIX_OBJECT + 'SurfaceCallerObject');
		Assert.isNotNull(entry, 'bypassObject should emit a validation BYPASS audit entry');
		assertResolvedCaller(entry.ClassMethod__c, 'Caller through the validation surface should resolve to the subscriber test method, not the surface');
	}

	/**
	 * @description Tests that a bypass emitted through the query builder's `AuditQueue` (an explicit
	 * `withSystemMode()` query) resolves the caller past the builder/queue plumbing to the subscriber
	 * that ran the query — the longest framework chain (`emit` ← `AuditQueue.flush` ← `QRY_Builder`).
	 * Pins that `QRY_Builder` (and the `UTIL_BypassAudit.AuditQueue` inner class) are skipped in an
	 * unmanaged org.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 * @see QRY_Builder
	 */
	@IsTest
	private static void shouldResolveCallerThroughQueryBuilderSurface()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().count();
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry('system-mode:' + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(entry, 'A withSystemMode query should emit an object-qualified system-mode BYPASS audit entry');
		assertResolvedCaller(entry.ClassMethod__c, 'Caller through the query builder/AuditQueue should resolve to the subscriber test method');
	}

	/**
	 * @description Tests that `emit` writes a concise `action target` summary to `ShortMessage__c`
	 * distinct from the fuller `Message__c`, which retains the surface, quoted target, and caller.
	 * Closes the prior `Message == ShortMessage` duplication.
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitDistinctShortMessageFromMessage()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, 'short-message-target', null);
		Test.stopTest();

		LogEntry__c entry = findFirstAuditEntry('short-message-target');
		Assert.isNotNull(entry, 'emit should write a LogEntry__c row for the short-message target');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS + ' short-message-target', entry.ShortMessage__c, 'ShortMessage should be the concise action+target summary');
		Assert.areNotEqual(entry.ShortMessage__c, entry.Message__c, 'Message should carry fuller detail than ShortMessage');
		Assert.isTrue(entry.Message__c.contains('short-message-target'), 'Message should include the target');
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
	 * @description Pins the LEGACY no-footprint fallback of `AuditQueue.flush`: a queue flushed
	 * without any recorded operation footprint (here, hand-built outside a builder terminal)
	 * emits one bare-target `BYPASS` entry per distinct queued target — the pre-operation-context
	 * shape. The general builder-terminal contract is per-(target × object) emission with
	 * object-qualified targets, exercised by `shouldQualifyQueryBypassTargetWithObjectName`
	 * and its siblings.
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

		String detailBypassPrefix = TRG_PersistLogEntry.PREFIX_DETAIL + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		String rollupBypassPrefix = TRG_PersistLogEntry.PREFIX_ROLLUP + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		Integer detailRows = 0;
		Integer rollupTotal = 0;
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context == null || !'sharing'.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET)) || entry.Fingerprint__c == null)
			{
				continue;
			}
			if(entry.Fingerprint__c.startsWith(detailBypassPrefix))
			{
				detailRows++;
			}
			if(entry.Fingerprint__c.startsWith(rollupBypassPrefix))
			{
				rollupTotal += entry.OccurrenceCount__c?.intValue() ?? 0;
			}
		}
		Assert.areEqual(1, detailRows, 'Idempotent flush should produce exactly one detail audit row');
		Assert.areEqual(1, rollupTotal, 'Idempotent flush counts exactly one occurrence — the second flush is a no-op');
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
	 * @description Tests that emit stamps a bypass-namespaced fingerprint, so the first emission of
	 * a novel bypass identity (caller|surface|action|target|userId) persists as a bypass detail row
	 * — the identity that gives "novel = loud, known = counted" semantics at the persist layer.
	 */
	@IsTest
	private static void shouldStampBypassFingerprintOnAuditEntries()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, TARGET_SHARING, null);
		Test.stopTest();

		String detailBypassPrefix = TRG_PersistLogEntry.PREFIX_DETAIL + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		Boolean detailFound = false;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(row.Fingerprint__c == null || !row.Fingerprint__c.startsWith(detailBypassPrefix))
			{
				continue;
			}
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(row);
			if(context != null && TARGET_SHARING.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET)))
			{
				detailFound = true;
			}
		}
		Assert.isTrue(detailFound,
				'A novel bypass identity must persist as a bypass-namespaced detail row (' + detailBypassPrefix + ')');
	}

	/**
	 * @description Tests flood-control end-to-end on the audit surface: two identical bypass
	 * emissions (same caller/surface/action/target/user) produce ONE detail row and a rollup
	 * counting both — the subscriber hot-loop scenario the feature exists for.
	 */
	@IsTest
	private static void shouldCollapseRepeatedIdenticalBypassEmissions()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, TARGET_SHARING, null);
		UTIL_BypassAudit.emit(SURFACE_QUERY, UTIL_BypassAudit.ACTION_BYPASS, TARGET_SHARING, null);
		Test.stopTest();

		String detailBypassPrefix = TRG_PersistLogEntry.PREFIX_DETAIL + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		String rollupBypassPrefix = TRG_PersistLogEntry.PREFIX_ROLLUP + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		Integer detailRows = 0;
		Integer rollupTotal = 0;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(row.Fingerprint__c == null)
			{
				continue;
			}
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(row);
			if(context == null || !TARGET_SHARING.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET)))
			{
				continue;
			}
			if(row.Fingerprint__c.startsWith(detailBypassPrefix))
			{
				detailRows++;
			}
			if(row.Fingerprint__c.startsWith(rollupBypassPrefix))
			{
				rollupTotal += row.OccurrenceCount__c?.intValue() ?? 0;
			}
		}
		Assert.areEqual(1, detailRows, 'Identical bypass identity collapses to one detail row');
		Assert.areEqual(2, rollupTotal, 'Both emissions are counted in the rollup');
	}

	/**
	 * @description Tests that a sharing-bypassed query emits its audit entry with an
	 * object-qualified target (`sharing:<Object>`) and carries the operation context
	 * (`object` + `operation='query'`) — the forensic unit that lets an admin tell WHICH
	 * read ran under the bypass rather than only that "a query somewhere" did.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 * @see QRY_Builder
	 */
	@IsTest
	private static void shouldQualifyQueryBypassTargetWithObjectName()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String objectName = String.valueOf(Foobar__c.SObjectType);

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).bypassSharing().toList();
		Test.stopTest();

		LogEntry__c entry = findFirstDetailAuditEntry(TARGET_SHARING + ':' + objectName);
		Assert.isNotNull(entry, 'A sharing-bypassed query should emit an object-qualified BYPASS audit target');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.areEqual(objectName, context.get(UTIL_BypassAudit.CONTEXT_OBJECT), 'Audit context should record the queried object');
		Assert.areEqual(UTIL_BypassAudit.OPERATION_QUERY, context.get(UTIL_BypassAudit.CONTEXT_OPERATION), 'Audit context should record the query operation');
	}

	/**
	 * @description Tests that two sharing-bypassed queries from the same caller against DIFFERENT
	 * objects persist with distinct detail fingerprints, so a novel object surfaces as a fresh
	 * detail row instead of silently bumping another object's rollup count. Both queries run in
	 * the same test method, so the caller component of the identity tuple is held constant and
	 * the target is the only differentiator under test.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 */
	@IsTest
	private static void shouldGiveDistinctObjectsDistinctQueryFingerprints()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).bypassSharing().count();
		QRY_Builder.selectFrom(Account.SObjectType).bypassSharing().count();
		Test.stopTest();

		LogEntry__c foobarEntry = findFirstDetailAuditEntry(TARGET_SHARING + ':' + String.valueOf(Foobar__c.SObjectType));
		LogEntry__c accountEntry = findFirstDetailAuditEntry(TARGET_SHARING + ':' + String.valueOf(Account.SObjectType));
		Assert.isNotNull(foobarEntry, 'The Foobar query should emit its own object-qualified audit entry');
		Assert.isNotNull(accountEntry, 'The Account query should emit its own object-qualified audit entry');
		Assert.areNotEqual(foobarEntry.Fingerprint__c, accountEntry.Fingerprint__c,
				'Distinct objects on the same bypass call site must carry distinct fingerprints');
	}

	/**
	 * @description Tests that a system-mode DML transaction records the verb, object, and row
	 * count in the audit context, under the object-qualified `system-mode:<Object>` target —
	 * so 50 occurrences of a bypass entry are attributable to a concrete write rather than
	 * being 50 indistinguishable "some DML somewhere" rows.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 * @see DML_Builder
	 */
	@IsTest
	private static void shouldRecordDmlVerbObjectAndRowCount()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String objectName = String.valueOf(Foobar__c.SObjectType);
		List<Foobar__c> records = TST_Factory.newFoobars(2);

		Test.startTest();
		DML_Builder.newTransaction().doInsert(records).withSystemMode().execute();
		Test.stopTest();

		LogEntry__c entry = findFirstDetailAuditEntry('system-mode:' + objectName);
		Assert.isNotNull(entry, 'A system-mode DML transaction should emit an object-qualified BYPASS audit target');
		Map<String, Object> context = parseContextData(entry.ContextData__c);
		Assert.areEqual(objectName, context.get(UTIL_BypassAudit.CONTEXT_OBJECT), 'Audit context should record the affected object');
		Assert.areEqual('insert', context.get(UTIL_BypassAudit.CONTEXT_OPERATION), 'Audit context should record the DML verb');
		Assert.areEqual('2', String.valueOf(context.get(UTIL_BypassAudit.CONTEXT_ROW_COUNT)), 'Audit context should record the submitted row count');
	}

	/**
	 * @description Tests that one DML transaction touching two objects under a single
	 * `bypassSharing()` call emits one BYPASS entry per distinct object — each scoped to its
	 * own operation footprint — rather than a single conflated entry that hides which objects
	 * the bypass actually touched.
	 *
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 * @see DML_Builder
	 */
	@IsTest
	private static void shouldEmitPerDistinctObjectForMultiObjectDmlTransaction()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		// Two distinct FRAMEWORK objects so the per-object audit assertion holds in every install context.
		// A subscriber org (in any namespace) may enforce framework validation rules on a standard object
		// like Account — the release-testing harness deploys an active AccountValidation group (e.g.
		// PhoneOrWebsiteRequired) — which would block a bare-Account insert under RunAllTestsInOrg, a failure
		// the vanilla packaging-build validation org cannot surface. The framework's own objects carry no
		// subscriber validation rules, so this test stays portable across the package, subscriber, and
		// upgraded-org contexts.
		Foobar__c foobar = TST_Factory.newFoobar();
		ApiCall__c apiCall = TST_Factory.newInboundApiCall('MultiObjectAuditTest');

		// The managed package-validation user lacks FLS on the framework's own objects, and bypassSharing()
		// resolves to the flag-driven USER_MODE default. Disable the flag so the insert runs SYSTEM_MODE while
		// keeping bypassSharing() the sole audited bypass (withSystemMode() would add system-mode targets).
		SEL_FeatureFlag.activeFlags.remove('UserModeDml_Enabled');

		Test.startTest();
		DML_Builder.newTransaction().doInsert(foobar).doInsert(apiCall).bypassSharing().execute();
		Test.stopTest();

		LogEntry__c foobarEntry = findFirstDetailAuditEntry(TARGET_SHARING + ':' + String.valueOf(Foobar__c.SObjectType));
		LogEntry__c apiCallEntry = findFirstDetailAuditEntry(TARGET_SHARING + ':' + String.valueOf(ApiCall__c.SObjectType));
		Assert.isNotNull(foobarEntry, 'The transaction should emit a sharing BYPASS entry for the Foobar object');
		Assert.isNotNull(apiCallEntry, 'The transaction should emit a sharing BYPASS entry for the ApiCall object');
		Map<String, Object> apiCallContext = parseContextData(apiCallEntry.ContextData__c);
		Assert.areEqual('1', String.valueOf(apiCallContext.get(UTIL_BypassAudit.CONTEXT_ROW_COUNT)), 'Each object footprint should count only its own rows');
	}

	/**
	 * @description Pins that the validation and trigger surfaces are untouched by the query/DML
	 * target widening: their targets keep the original unqualified shape and their persisted
	 * detail fingerprints remain the SHA-256 of the unchanged `caller|surface|action|target|userId`
	 * tuple. A regression that rewrote these targets (or widened the tuple) would churn every
	 * subscriber's existing detail/rollup rows for surfaces that were already per-target.
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldLeaveValidationAndTriggerTargetsUnchanged()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_ValidationRule.bypassObject('PinValidationObject');
		TRG_Base.bypass('PinTriggerObject');
		Test.stopTest();

		LogEntry__c validationEntry = findFirstDetailAuditEntry(UTIL_BypassAudit.TARGET_PREFIX_OBJECT + 'PinValidationObject');
		LogEntry__c triggerEntry = findFirstDetailAuditEntry('PinTriggerObject');
		Assert.isNotNull(validationEntry, 'Validation bypass should keep its object-prefixed target shape');
		Assert.isNotNull(triggerEntry, 'Trigger bypass should keep its bare object-name target shape');
		assertFingerprintMatchesIdentityTuple(validationEntry, UTIL_BypassAudit.SURFACE_VALIDATION,
				UTIL_BypassAudit.TARGET_PREFIX_OBJECT + 'PinValidationObject');
		assertFingerprintMatchesIdentityTuple(triggerEntry, UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT, 'PinTriggerObject');
	}

	/**
	 * @description Asserts caller provenance branched on namespace context. In an unmanaged org the
	 * test frame is the first external frame, so the resolved caller names this test class. In a
	 * namespaced org (e.g. the packaging-build test run, where even test frames carry the package
	 * namespace) every frame is namespace-skipped, so the documented fallback (`EMIT_AT`) is the
	 * correct resolution — asserting it still proves the namespace skip works.
	 *
	 * @param actualCaller The `ClassMethod__c` / `caller` context value recorded on the audit entry.
	 * @param assertionMessage The failure message describing the expected unmanaged-org caller.
	 */
	private static void assertResolvedCaller(String actualCaller, String assertionMessage)
	{
		if(String.isBlank(UTIL_System.getManagedPackageNamespace()))
		{
			Assert.isTrue(actualCaller.startsWith('UTIL_BypassAudit_TEST'), assertionMessage + '. Actual: ' + actualCaller);
		}
		else
		{
			Assert.areEqual(EMIT_AT, actualCaller,
					'In a namespaced org every frame carries the package namespace, so the fallback caller applies. Actual: ' + actualCaller);
		}
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
	 * @description Returns the most-recent persisted bypass audit DETAIL row whose context `target`
	 * matches the supplied value, excluding rollup rows. Fingerprint assertions must compare detail
	 * rows specifically — a detail/rollup pair for the same emission carries different persisted
	 * fingerprint prefixes, so an entry-shape-agnostic lookup would let two logically-equal
	 * fingerprints read as distinct (or mask a real distinctness regression).
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The matching detail `LogEntry__c`, or `null` if none exists.
	 */
	private static LogEntry__c findFirstDetailAuditEntry(String target)
	{
		return findFirstAuditEntry(target, true);
	}

	/**
	 * @description Asserts the persisted detail fingerprint equals the audit identity tuple hash
	 * (`caller|surface|action|target|userId`), reading the caller from the entry's own context so
	 * the assertion holds in managed and unmanaged namespace contexts alike. Pins the fingerprint
	 * schema: a change to the tuple composition (component order, added components) fails here.
	 *
	 * @param entry The persisted detail audit entry to verify.
	 * @param surface The expected audit surface component.
	 * @param target The expected audit target component.
	 */
	private static void assertFingerprintMatchesIdentityTuple(LogEntry__c entry, String surface, String target)
	{
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
		String caller = (String)context.get(UTIL_BypassAudit.CONTEXT_CALLER);
		String expectedHash = UTIL_Crypto.generateSHA256Hash(String.join(
				new List<String> {caller, surface, UTIL_BypassAudit.ACTION_BYPASS, target, UserInfo.getUserId()}, UTIL_String.PIPE));
		Assert.areEqual(TRG_PersistLogEntry.PREFIX_DETAIL + LOG_Builder.RESERVED_FINGERPRINT_PREFIX + expectedHash, entry.Fingerprint__c,
				'The persisted fingerprint must remain the SHA-256 of the unchanged identity tuple');
	}

	/**
	 * @description Returns the most-recent persisted bypass audit `LogEntry__c` whose context `target`
	 * matches the supplied value. Filtering by target keeps assertions stable when `setupLoggerForTest`
	 * or other framework-internal `withSystemMode()` calls also emit audit entries during the test
	 * setup phase, and the reserved-fingerprint filter excludes org-local flood-controlled rows
	 * (e.g. a subscriber harness's trigger-action skip logs) that inherit the transaction's global
	 * context but are not bypass audit emissions. Iterates entries in CreatedDate-descending order so
	 * the first match is the latest emission.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The matching `LogEntry__c`, or `null` if none exists.
	 */
	private static LogEntry__c findFirstAuditEntry(String target)
	{
		return findFirstAuditEntry(target, false);
	}

	/**
	 * @description Shared scan behind `findFirstAuditEntry` / `findFirstDetailAuditEntry` —
	 * one loop, parameterised on whether rollup rows are admissible matches.
	 *
	 * @param target The bypass audit `target` context value to find.
	 * @param detailOnly When `true`, only detail rows match; when `false`, rollup rows match too.
	 *
	 * @return The matching `LogEntry__c`, or `null` if none exists.
	 */
	private static LogEntry__c findFirstAuditEntry(String target, Boolean detailOnly)
	{
		String detailPrefix = TRG_PersistLogEntry.PREFIX_DETAIL + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		String rollupPrefix = TRG_PersistLogEntry.PREFIX_ROLLUP + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			// Anchored on the canonical persisted audit shapes (detail:bypass:* / rollup:bypass:*).
			// A subscriber key can never START with the reserved prefix (normalizeFingerprintKey
			// hashes it), but it may legally CONTAIN 'bypass:' mid-string — contains() would match
			// such a row, an anchored startsWith cannot.
			if(entry.Fingerprint__c == null
					|| !(entry.Fingerprint__c.startsWith(detailPrefix)
					|| (!detailOnly && entry.Fingerprint__c.startsWith(rollupPrefix))))
			{
				continue;
			}
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null && target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET)))
			{
				return entry;
			}
		}
		return null;
	}
}