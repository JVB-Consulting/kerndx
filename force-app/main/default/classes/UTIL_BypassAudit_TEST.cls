// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for `UTIL_BypassAudit`. They check that the bypass audit helper writes
 * `LogEntry__c` rows with the expected context shape, includes the reason set for the transaction,
 * and handles null and extra context inputs without losing data.
 *
 * @see UTIL_BypassAudit
 *
 * @author Jason van Beukering
 *
 * @group Security
 *
 * @date May 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=true)
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
	 * @description Reason string used when checking that the transaction's reason is included in audit context.
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
	 * @description Checks that each `CONTEXT_*` and `LOG_CATEGORY` constant keeps the exact text that
	 * subscribers rely on when they read `kern__LogEntry__c.ContextData__c`. Tests across the bypass
	 * surfaces read the parsed context with `context.get(UTIL_BypassAudit.CONTEXT_X)`, which only
	 * proves the keys are used consistently. This test checks the literal value of each key, so a
	 * renamed key fails one test instead of quietly breaking subscriber code.
	 *
	 * @see UTIL_BypassAudit
	 */
	@IsTest
	private static void shouldPinAuditWireContractKeysAndCategoryToLiterals()
	{
		Assert.areEqual('category', UTIL_BypassAudit.CONTEXT_CATEGORY, 'CONTEXT_CATEGORY must keep the key subscribers read');
		Assert.areEqual('surface', UTIL_BypassAudit.CONTEXT_SURFACE, 'CONTEXT_SURFACE must keep the key subscribers read');
		Assert.areEqual('action', UTIL_BypassAudit.CONTEXT_ACTION, 'CONTEXT_ACTION must keep the key subscribers read');
		Assert.areEqual('target', UTIL_BypassAudit.CONTEXT_TARGET, 'CONTEXT_TARGET must keep the key subscribers read');
		Assert.areEqual('reason', UTIL_BypassAudit.CONTEXT_REASON, 'CONTEXT_REASON must keep the key subscribers read');
		Assert.areEqual('object', UTIL_BypassAudit.CONTEXT_OBJECT, 'CONTEXT_OBJECT must keep the key subscribers read');
		Assert.areEqual('operation', UTIL_BypassAudit.CONTEXT_OPERATION, 'CONTEXT_OPERATION must keep the key subscribers read');
		Assert.areEqual('rowCount', UTIL_BypassAudit.CONTEXT_ROW_COUNT, 'CONTEXT_ROW_COUNT must keep the key subscribers read');
		Assert.areEqual('BypassEvent', UTIL_BypassAudit.LOG_CATEGORY, 'LOG_CATEGORY must keep the category value subscribers read');
	}

	/**
	 * @description Tests that `getBypassReason` returns `null` when no reason has been set.
	 *
	 * @see UTIL_BypassAudit.getBypassReason
	 */
	@IsTest
	private static void shouldReturnNullWhenNoReasonLatched()
	{
		Assert.isNull(UTIL_BypassAudit.getBypassReason(), 'The bypass reason should default to null');
	}

	/**
	 * @description Tests that `setBypassReason` stores a reason that is returned by `getBypassReason`.
	 *
	 * @see UTIL_BypassAudit.setBypassReason
	 * @see UTIL_BypassAudit.getBypassReason
	 */
	@IsTest
	private static void shouldRoundTripReasonThroughLatch()
	{
		UTIL_BypassAudit.setBypassReason(REASON_TEXT);

		Assert.areEqual(REASON_TEXT, UTIL_BypassAudit.getBypassReason(), 'The stored reason should be returned');
	}

	/**
	 * @description Tests that passing `null` to `setBypassReason` clears a reason that was set before.
	 *
	 * @see UTIL_BypassAudit.setBypassReason
	 */
	@IsTest
	private static void shouldClearReasonWhenSetToNull()
	{
		UTIL_BypassAudit.setBypassReason(REASON_TEXT);
		UTIL_BypassAudit.setBypassReason(null);

		Assert.isNull(UTIL_BypassAudit.getBypassReason(), 'Null reason should clear the stored reason');
	}

	/**
	 * @description Tests that clearing a reason that was set, with `setBypassReason(null)`, emits
	 * a `CLEAR` audit entry on the `SURFACE_REASON_LATCH` surface whose `previousReason` extra
	 * holds the removed value. Setting and clearing a bypass are both audited, so clearing the
	 * reason is audited too. Otherwise the audit trail could not answer "who removed the migration
	 * reason?".
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
		Assert.isNotNull(entry, 'Expected clearing a stored reason to emit a CLEAR audit entry for the bypass reason');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
		Assert.areEqual(UTIL_BypassAudit.SURFACE_REASON_LATCH, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Expected the surface of the bypass reason');
		Assert.areEqual(UTIL_BypassAudit.ACTION_CLEAR, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Expected the action to be CLEAR');
		Assert.areEqual(REASON_TEXT, context.get('previousReason'), 'Expected the previousReason extra to hold the removed reason');
		String latchSummary = UTIL_BypassAudit.ACTION_CLEAR + ' ' + UTIL_BypassAudit.SURFACE_REASON_LATCH;
		Assert.areEqual(latchSummary, entry.ShortMessage__c, 'A target that IS the surface should not repeat itself as the qualifier');
	}

	/**
	 * @description Tests that calling `setBypassReason(null)` when no reason was set before
	 * does not emit a CLEAR audit entry. A CLEAR entry for a clear that changed nothing would fill
	 * audit queries with CLEAR entries that have no earlier BYPASS to match.
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
				'Clearing an already-empty reason should not emit an audit entry');
	}

	/**
	 * @description Tests that `emit` writes a `LogEntry__c` row with the canonical context keys
	 * (`category`, `surface`, `action`, `target`) at WARN level. With caller capture on (default),
	 * `ClassMethod__c` records the real caller (here, the test method) rather than the audit helper.
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
	 * @description Tests that `emit` sends audit log events to the separate
	 * `LOG_Engine.auditLogBuffer` and not to the application log buffer (`LOG_Engine.logBuffer`).
	 * `LOG_Builder.LogEntry.emitAsAudit()` exists to keep them apart. Without it, every
	 * framework-internal `withSystemMode()` call made while log saving is suspended for a batch
	 * would raise the application buffer count, and break subscriber and framework tests
	 * that count `LOG_Engine.getBufferSize()` (e.g. `LOG_Builder_TEST.bufferAutoFlushesWhenMaxSizeExceeded`).
	 *
	 * If a later change sends audit entries through `LOG_Engine.publishEvents` (the application
	 * path), this test fails, instead of every test that counts log entries quietly breaking.
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
	 * @description Tests that `emit` includes the transaction's reason in the audit context when set.
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
		Assert.areEqual(REASON_TEXT, context.get(UTIL_BypassAudit.CONTEXT_REASON), 'The stored reason should appear in context');
	}

	/**
	 * @description Tests that `emit` leaves out the reason context key when the stored reason is
	 * blank. Covers both an explicit empty-string clear and a reason that was never set: both must
	 * leave the reason key out of the audit context.
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
	 * @description Tests that `emit` does nothing, and writes no `LogEntry__c` row, when the
	 * `BypassAudit_Enabled` `FeatureFlag__mdt` resolves to `false`. Subscribers switch off audit
	 * entries in noisy environments with a `FeatureFlagStrategy__mdt` override. The test does the
	 * same by removing the flag from the `SEL_FeatureFlag.activeFlags` cache, so the lookup finds
	 * no flag and returns `false`.
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

		Assert.isNull(findFirstAuditEntry('killswitch-target'), 'emit should do nothing when the audit flag is switched off');
	}

	/**
	 * @description Tests that `emit` records the real caller (the first stack frame outside the
	 * framework) in `ClassMethod__c` and the `caller` context. Here the direct caller is the test
	 * method, so both must name `UTIL_BypassAudit_TEST` and not the audit helper, which is the
	 * fixed value the audit used to record.
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
	 * @description Tests that a bypass emitted through a framework surface (here `UTIL_ValidationRule`)
	 * records, as its caller, the subscriber code that called the surface, not the surface. This is
	 * the real-world path: unlike a direct `emit` call, it has a framework frame in between. In an
	 * unmanaged org the namespace check does not skip the surface frame, so the surface class must
	 * be in the audit's list of framework classes to skip for this to hold.
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
	 * `withSystemMode()` query) records, as its caller, the subscriber code that ran the query, past
	 * the builder and the queue. This is the longest chain of framework frames (`emit` called by
	 * `AuditQueue.flush`, called by `QRY_Builder`). Checks that `QRY_Builder` and the
	 * `UTIL_BypassAudit.AuditQueue` inner class are skipped in an unmanaged org.
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
	 * @description Tests that `emit` writes a short `action target (surface)` summary to `ShortMessage__c`,
	 * different from the longer `Message__c`, which keeps the quoted target and the caller. The two
	 * fields once held the same text.
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
		String expectedSummary = UTIL_BypassAudit.ACTION_BYPASS + ' short-message-target (' + SURFACE_QUERY + ')';
		Assert.isNotNull(entry, 'emit should write a LogEntry__c row for the short-message target');
		Assert.areEqual(expectedSummary, entry.ShortMessage__c, 'ShortMessage should be the concise surface-qualified summary');
		Assert.areNotEqual(entry.ShortMessage__c, entry.Message__c, 'Message should carry fuller detail than ShortMessage');
		Assert.isTrue(entry.Message__c.contains('short-message-target'), 'Message should include the target');
	}

	/**
	 * @description Tests that two surfaces auditing the same action and target carry summaries that
	 * tell them apart. `TRG_Base.clearAllBypasses()` produces this shape: one entry for the object
	 * bypass list and one for the action bypass list. If two grouped problems read the same, the
	 * grouping looks broken, when it is really the summary that hides the difference.
	 *
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldQualifySummaryBySurfaceSoSameActionOnTwoSurfacesReadsDistinct()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT, UTIL_BypassAudit.ACTION_CLEAR_ALL, UTIL_BypassAudit.TARGET_ALL, null);
		UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_TRIGGER_ACTION, UTIL_BypassAudit.ACTION_CLEAR_ALL, UTIL_BypassAudit.TARGET_ALL, null);
		Test.stopTest();

		Set<String> summaries = new Set<String>();
		for(LogEntry__c entry : findAuditEntries(UTIL_BypassAudit.TARGET_ALL))
		{
			summaries.add(entry.ShortMessage__c);
		}
		String clearAllOf = UTIL_BypassAudit.ACTION_CLEAR_ALL + ' ' + UTIL_BypassAudit.TARGET_ALL + ' (';
		Assert.areEqual(2, summaries.size(), 'The object-list and action-list clear-all entries should carry distinct summaries');
		Assert.isTrue(summaries.contains(clearAllOf + UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT + ')'), 'The object-list summary should name its surface');
		Assert.isTrue(summaries.contains(clearAllOf + UTIL_BypassAudit.SURFACE_TRIGGER_ACTION + ')'), 'The action-list summary should name its surface');
	}

	/**
	 * @description Tests that `AuditQueue.queueSharing` records the standard `TARGET_SHARING`
	 * value in the queue's target set, where each target is stored once. Asserts on the
	 * `@TestVisible` `targets` set, so the test checks the target's shape and not only that
	 * something was emitted.
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
	 * @description Tests that `AuditQueue.queueSystemMode` records the standard
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
	 * @description Tests that `AuditQueue.queueSecurityMode` records the standard
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
	 * @description Tests that repeated calls to the same `queue*` method are stored once by the underlying
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

		Assert.areEqual(1, queue.targets.size(), 'Repeated queueSharing calls should store one target');
	}

	/**
	 * @description Tests the older fallback of `AuditQueue.flush`, used when no operation was
	 * recorded: a queue flushed without any recorded operation (here, built by hand outside a builder
	 * terminal method) emits one bare-target `BYPASS` entry per distinct queued target. This is the
	 * shape audit entries had before they recorded operations. When a builder runs, the normal rule
	 * is one entry per pair of target and object, with object-qualified targets; that rule is tested
	 * by `shouldQualifyQueryBypassTargetWithObjectName` and the tests next to it.
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
	 * the constructor: `SURFACE_DML` queues emit DML-surface audits, and `SURFACE_QUERY` queues
	 * emit query-surface audits.
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
	 * @description Tests that a second `flush` call on the same `AuditQueue` instance does nothing.
	 * A query builder that runs `count()` and then `toList()` flushes twice. If the second flush
	 * wrote again, the audit trail would count every bypass twice.
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
		Assert.areEqual(1, detailRows, 'A repeated flush should produce exactly one detail audit row');
		Assert.areEqual(1, rollupTotal, 'A repeated flush counts exactly one occurrence: the second flush does nothing');
	}

	/**
	 * @description Tests that `flush` on an empty queue still marks the queue as flushed, without
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

		Assert.isTrue(queue.flushed, 'Empty queue flush should still mark the queue as flushed');
		Assert.isNull(findFirstAuditEntry('sharing'), 'Empty queue flush should emit nothing');
	}

	/**
	 * @description Tests that an `AuditQueue` whose `flush` is never called is not marked as flushed
	 * and keeps its queued targets. By design, entries are emitted when the builder runs, not when a
	 * bypass setter is called, so a builder dropped before it runs makes no `UTIL_BypassAudit.emit`
	 * calls from this queue. Asserts on the `@TestVisible` `flushed` and `targets` state and not on a
	 * query, because framework-internal `withSystemMode` calls during test setup can emit audits of
	 * their own. Those would fail a "no LogEntry__c rows" check without proving anything about this
	 * queue.
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

		Assert.isFalse(queue.flushed, 'A queue that was never flushed should not be marked as flushed');
		Assert.areEqual(3, queue.targets.size(), 'Queued targets should remain pending until flush is called');
	}

	/**
	 * @description Tests that emit stamps a fingerprint that starts with the bypass prefix, so the
	 * first emission of a new bypass identity (caller|surface|action|target|userId) is saved as a
	 * bypass detail row. That identity is what makes a new bypass show as its own row, while a known
	 * one only raises a count, when log entries are saved.
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
	 * @description Tests flood control end to end on the audit surface: two identical bypass
	 * emissions (same caller, surface, action, target and user) produce one detail row and a rollup
	 * that counts both. This is the case the feature exists for: subscriber code that bypasses in a
	 * tight loop.
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
	 * (`object` and `operation='query'`). With these, an admin can tell which query ran under the
	 * bypass, not only that "a query somewhere" did.
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
	 * @description Tests that two sharing-bypassed queries from the same caller against different
	 * objects are saved with different detail fingerprints, so a new object shows as a new detail
	 * row instead of quietly raising another object's rollup count. Both queries run in the same
	 * test method, so the caller part of the identity stays the same and the target is the only
	 * difference under test.
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
	 * count in the audit context, under the object-qualified `system-mode:<Object>` target. So 50
	 * occurrences of a bypass entry can be traced to a real write, instead of being 50 rows that
	 * all say "some DML somewhere".
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
	 * `bypassSharing()` call emits one BYPASS entry per distinct object, each with only its own
	 * operations, instead of one combined entry that hides which objects the bypass touched.
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
		// like Account. The release-testing harness deploys an active AccountValidation group (e.g.
		// PhoneOrWebsiteRequired), which would block a bare-Account insert under RunAllTestsInOrg, a failure
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
		Assert.areEqual('1', String.valueOf(apiCallContext.get(UTIL_BypassAudit.CONTEXT_ROW_COUNT)), 'Each object entry should count only its own rows');
	}

	/**
	 * @description Tests that the change which added the object to query and DML targets left the
	 * validation and trigger surfaces alone: their targets keep the original shape, without an
	 * object, and their saved detail fingerprints are still the SHA-256 of the same
	 * `caller|surface|action|target|userId` values. A change that rewrote these targets (or added
	 * values to the fingerprint) would replace every subscriber's existing detail and rollup rows
	 * for surfaces that already had one row per target.
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
	 * @description Checks the recorded caller in a way that depends on the namespace. In an
	 * unmanaged org the test frame is the first external frame, so the resolved caller names this
	 * test class. In a namespaced org (e.g. the packaging-build test run, where even test frames
	 * carry the package namespace) every frame is skipped by the namespace check, so the documented
	 * fallback (`EMIT_AT`) is the right answer. Asserting it still proves the namespace check works.
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
	 * @description Parses the saved `ContextData__c` JSON wrapper and returns the inner
	 * `contextData` map. Calls `SEL_LogEntry.parseContextDataForTest`, so the wrapper format
	 * can change in one place without breaking assertions in five or more test classes.
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
	 * @description Returns the newest saved bypass audit detail row whose context `target`
	 * matches the given value, leaving out rollup rows. Fingerprint assertions must compare detail
	 * rows only: a detail row and a rollup row for the same emission carry different fingerprint
	 * prefixes. A lookup that accepted either could make two equal fingerprints look different (or
	 * hide a real difference that should be caught).
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
	 * @description Asserts that the saved detail fingerprint equals the hash of the audit identity
	 * (`caller|surface|action|target|userId`). Reads the caller from the entry's own context, so the
	 * assertion holds in managed and unmanaged namespace contexts alike. A change to what goes into
	 * the fingerprint (the order of the values, or an added value) fails here.
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
	 * @description Returns the newest saved bypass audit `LogEntry__c` whose context `target`
	 * matches the given value. Filtering by target keeps assertions stable when `setupLoggerForTest`
	 * or other framework-internal `withSystemMode()` calls also emit audit entries during test
	 * setup. The filter on the reserved fingerprint prefix leaves out flood-controlled rows the org
	 * itself writes, which share the transaction's global context but are not bypass audit entries.
	 * Reads entries newest first by CreatedDate, so the first match is the latest emission.
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
	 * @description Returns the first (newest) match from `findAuditEntries`, or `null` when nothing
	 * matches. A one-row shortcut over the shared search.
	 *
	 * @param target The bypass audit `target` context value to find.
	 * @param detailOnly When `true`, only detail rows match; when `false`, rollup rows match too.
	 *
	 * @return The matching `LogEntry__c`, or `null` if none exists.
	 */
	private static LogEntry__c findFirstAuditEntry(String target, Boolean detailOnly)
	{
		List<LogEntry__c> matches = findAuditEntries(target, detailOnly);
		return matches.isEmpty() ? null : matches[0];
	}

	/**
	 * @description Returns every saved detail audit row (detail:bypass:*) whose `target` context
	 * equals the given target. There is one row per distinct fingerprint, so a target audited on two
	 * surfaces gives two rows.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The matching detail rows, newest first; empty when none exist.
	 */
	private static List<LogEntry__c> findAuditEntries(String target)
	{
		return findAuditEntries(target, true);
	}

	/**
	 * @description The one search that every audit-row lookup in this file uses. The parameter
	 * decides whether rollup rows count as matches.
	 *
	 * @param target The bypass audit `target` context value to find.
	 * @param detailOnly When `true`, only detail rows match; when `false`, rollup rows match too.
	 *
	 * @return The matching rows, newest first; empty when none exist.
	 */
	private static List<LogEntry__c> findAuditEntries(String target, Boolean detailOnly)
	{
		String detailPrefix = TRG_PersistLogEntry.PREFIX_DETAIL + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		String rollupPrefix = TRG_PersistLogEntry.PREFIX_ROLLUP + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		List<LogEntry__c> matches = new List<LogEntry__c>();
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			// Anchored on the canonical persisted audit shapes (detail:bypass:* / rollup:bypass:*).
			// A subscriber key can never START with the reserved prefix (normalizeFingerprintKey
			// hashes it), but it may legally CONTAIN 'bypass:' in the middle: contains() would match
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
				matches.add(entry);
			}
		}
		return matches;
	}
}