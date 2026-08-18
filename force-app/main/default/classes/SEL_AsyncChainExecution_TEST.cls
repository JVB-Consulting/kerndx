// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for SEL_AsyncChainExecution selector.
 *
 * @see SEL_AsyncChainExecution
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, August 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_AsyncChainExecution_TEST
{
	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_AsyncChainExecution_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_AsyncChainExecution_TEST-low-privilege';

	/**
	 * @description Name used for the restart-projection witness's seeded chain.
	 */
	private static final String RESTART_PROJECTION_CHAIN_NAME = 'RestartProjectionChain';

	/**
	 * @description Snapshot document the restart-projection witness seeds and expects back through
	 * the restart-time read's extended projection.
	 */
	private static final String RESTART_PROJECTION_SNAPSHOT = '{"seedKey":"seed-value"}';

	/**
	 * @description Step-log document the operator-sweep projection witness seeds and expects back
	 * through the candidate read — the positive half of the projection proof.
	 */
	private static final String PROJECTION_GUARD_STEP_LOG = '[{"className":"ProjectionGuardStep"}]';

	/**
	 * @description How many of the rows shouldCountOnlyGenuineStallsAwaitingSweep seeds are still
	 * waiting for the operator sweep: the two stalled rows with no completion timestamp.
	 */
	private static final Integer STALLS_AWAITING_SWEEP = 2;

	/**
	 * @description Context document the operator-sweep projection witness seeds and must NOT get
	 * back through either sweep read — the negative half of the projection proof.
	 */
	private static final String PROJECTION_GUARD_CONTEXT = '{"seed":"value"}';

	/**
	 * @description Error message the operator-sweep projection witness seeds and must NOT get
	 * back through the candidate read — the second long-text payload the projection sheds.
	 */
	private static final String PROJECTION_GUARD_ERROR_MESSAGE = 'Seeded error message for the projection witness';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldFindByStatusForLowPrivilegeUser) can use System.runAs
	 * against either without triggering MIXED_DML_OPERATION. User is a Setup object, so User DML
	 * cannot mix with standard/custom-object DML in the same transaction; pre-provisioning here
	 * satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing SEL_AsyncChainExecution tests continue to
	 * run as the @IsTest running user without runAs.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests that getFields returns a non-empty list containing the expected default fields.
	 */
	@IsTest
	private static void shouldReturnAllDefaultFields()
	{
		SEL_AsyncChainExecution selector = new SEL_AsyncChainExecution();
		List<SObjectField> fields = selector.getFields();
		Assert.isFalse(fields.isEmpty(), 'Default fields should not be empty');
		Assert.isTrue
				(
						fields.contains(AsyncChainExecution__c.ActiveDeduplicationKey__c),
						'Should contain ActiveDeduplicationKey__c so deduplication lookups return the key on the matched run'
				);
		Assert.isTrue(fields.contains(AsyncChainExecution__c.ChainName__c), 'Should contain ChainName__c');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.CorrelationId__c), 'Should contain CorrelationId__c');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.CurrentJobId__c), 'Should contain CurrentJobId__c so the watchdog sweep row can probe executor liveness');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.FailureCategory__c), 'Should contain FailureCategory__c so the Chain Monitor can read the failure taxonomy');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.LastModifiedDate), 'Should contain LastModifiedDate so the watchdog can read stall age');
	}

	/**
	 * @description The default projection must carry the re-drive gating markers — AllowRestart__c,
	 * SourceExecution__c, and DeclaredDeduplicationKey__c are a checkbox, a lookup id, and a short
	 * text, negligible per row, and the retry re-claim reads the declared key off the monitoring row
	 * — but deliberately EXCLUDE InitialContextData__c: a third 131KB long-text would otherwise ride
	 * every executor hop and monitor detail read for restart-declared chains (the SUMMARY_FIELDS
	 * heap-guard precedent), so only a dedicated restart-time finder may project the snapshot.
	 */
	@IsTest
	private static void shouldProjectRestartMarkersWithoutInitialContextSnapshot()
	{
		List<SObjectField> fields = new SEL_AsyncChainExecution().getFields();
		Assert.isTrue(fields.contains(AsyncChainExecution__c.AllowRestart__c), 'Should contain AllowRestart__c so re-drive gates read the declaration off the monitoring row');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.SourceExecution__c), 'Should contain SourceExecution__c so restart lineage rides the monitoring row');
		Assert.isTrue
				(
						fields.contains(AsyncChainExecution__c.DeclaredDeduplicationKey__c),
						'Should contain DeclaredDeduplicationKey__c so the retry re-claim reads the declared key'
				);
		Assert.isFalse
				(
						fields.contains(AsyncChainExecution__c.InitialContextData__c),
						'Must exclude the InitialContextData__c snapshot: a third 131KB long-text on every default read is a heap risk'
				);
	}

	/**
	 * @description The restart-time read must project the InitialContextData__c snapshot the
	 * default projection deliberately excludes — it is the only query that ever pulls the 131KB
	 * snapshot, and the restart action reads the snapshot off exactly this row — while still
	 * carrying the default projection beside it.
	 *
	 * @see SEL_AsyncChainExecution.findByIdForRestart
	 */
	@IsTest
	private static void shouldProjectInitialContextSnapshotOnRestartRead()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, RESTART_PROJECTION_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.AllowRestart__c => true,
				AsyncChainExecution__c.InitialContextData__c => RESTART_PROJECTION_SNAPSHOT
		});

		Test.startTest();
		AsyncChainExecution__c restartRead = new SEL_AsyncChainExecution().findByIdForRestart(execution.Id);
		Test.stopTest();

		Assert.isNotNull(restartRead, 'The restart read should find the chain execution');
		Assert.areEqual(RESTART_PROJECTION_SNAPSHOT, restartRead.InitialContextData__c, 'The restart read must project the snapshot the default projection excludes');
		Assert.areEqual(true, restartRead.AllowRestart__c, 'The restart read must still carry the default projection fields');
	}

	/**
	 * @description Tests that the Chain Monitor detail read returns the record and — because the
	 * console must see all users' Private-OWD chains — emits no sharing BYPASS audit entry; the
	 * bypass is a framework-internal design choice, not a subscriber-facing opt-out.
	 *
	 * @see SEL_AsyncChainExecution.findByIdForMonitoring
	 * @see QRY_Builder.Builder.bypassSharingInternal
	 */
	@IsTest
	private static void shouldFindByIdForMonitoringWithoutBypassAudit()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'MonitoringChain');

		Test.startTest();
		AsyncChainExecution__c foundExecution = new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id);
		Test.stopTest();

		Assert.isNotNull(foundExecution, 'The monitoring read should find the chain execution');

		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			String target = (String)(context?.get(UTIL_BypassAudit.CONTEXT_TARGET));
			Assert.isFalse
					(
							target != null && target.startsWith('sharing'),
							'The monitoring read must not emit a sharing BYPASS audit entry'
					);
		}
	}

	/**
	 * @description Tests that findByStatus returns records matching the given status.
	 */
	@IsTest
	private static void shouldFindByStatus()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'TestChain');

		List<AsyncChainExecution__c> results = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
		Assert.isFalse(results.isEmpty(), 'Should find running chains');
	}

	/**
	 * @description Tests that findByCorrelationId returns the correct record for a known correlation ID.
	 */
	@IsTest
	private static void shouldFindByCorrelationId()
	{
		String correlationId = UTIL_Random.randomUUID();
		TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, 'TestChain')
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_COMPLETED)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, correlationId)
				.build();

		AsyncChainExecution__c result = new SEL_AsyncChainExecution().findByCorrelationId(correlationId);
		Assert.isNotNull(result, 'Should find by correlation ID');
		Assert.areEqual('TestChain', result.ChainName__c, 'Chain name should match');
	}

	/**
	 * @description Tests that findByChainName returns records with the given chain name.
	 */
	@IsTest
	private static void shouldFindByChainName()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'UniqueChainName');

		List<AsyncChainExecution__c> results = new SEL_AsyncChainExecution().findByChainName('UniqueChainName');
		Assert.isFalse(results.isEmpty(), 'Should find by chain name');
	}

	/**
	 * @description Tests that findByCorrelationId returns null when no record exists for the given ID.
	 */
	@IsTest
	private static void shouldReturnNullForMissingCorrelationId()
	{
		AsyncChainExecution__c result = new SEL_AsyncChainExecution().findByCorrelationId('nonexistent-id');
		Assert.isNull(result, 'Should return null for missing correlation ID');
	}

	/**
	 * @description findByActiveDeduplicationKey returns the run holding the key.
	 */
	@IsTest
	private static void shouldFindRunByActiveDeduplicationKey()
	{
		String deduplicationKey = UTIL_Random.randomUUID();
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'DeduplicationChain',
				new Map<SObjectField, Object> {AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey});

		AsyncChainExecution__c found = new SEL_AsyncChainExecution().findByActiveDeduplicationKey(deduplicationKey);
		Assert.isNotNull(found, 'The run holding the key should be found');
		Assert.areEqual(deduplicationKey, found.ActiveDeduplicationKey__c, 'The matched run should carry the key');
	}

	/**
	 * @description findByActiveDeduplicationKey returns null when no run holds the key.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoRunHoldsDeduplicationKey()
	{
		Assert.isNull(new SEL_AsyncChainExecution().findByActiveDeduplicationKey(UTIL_Random.randomUUID()),
				'A free key should resolve to no run');
	}

	/**
	 * @description Tests that findFiltered returns paginated, filtered, and sorted results.
	 */
	@IsTest
	private static void shouldFindFilteredByStatusAndName()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'AccountChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'AccountChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'DataSync');

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
				new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_COMPLETED},
				'Account', AsyncChainExecution__c.CreatedDate, true, 1, 10
		);

		Assert.areEqual(2, page.records.size(), 'Should match Running and Completed AccountChain');
		Assert.areEqual(2, page.totalRecords, 'Total should be 2');
	}

	/**
	 * @description Tests that findFiltered returns all records when no filters are applied.
	 */
	@IsTest
	private static void shouldFindFilteredWithNoFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'Chain1');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'Chain2');

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
				null, null, AsyncChainExecution__c.CreatedDate, false, 1, 10
		);

		Assert.areEqual(2, page.records.size(), 'Should return all records');
		Assert.areEqual(2, page.totalRecords, 'Total should be 2');
	}

	/**
	 * @description Tests that findFiltered projects only the summary fields the Chain Monitor list
	 * reads, excluding the long-text payload fields (ContextData__c, StepLog__c, ErrorMessage__c).
	 */
	@IsTest
	private static void shouldFindFilteredWithSummaryProjection()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'PayloadChain',
				new Map<SObjectField, Object>
				{
						AsyncChainExecution__c.ContextData__c => '{"key":"value"}',
						AsyncChainExecution__c.StepLog__c => '[]',
						AsyncChainExecution__c.ErrorMessage__c => 'Step failure detail'
				});

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
				null, null, AsyncChainExecution__c.CreatedDate, true, 1, 10
		);

		Assert.areEqual(1, page.records.size(), 'Should return the record');
		Map<String, Object> populated = page.records[0].getPopulatedFieldsAsMap();
		Assert.isTrue(populated.containsKey('Id'), 'Id should be projected');
		Assert.isTrue(
				populated.containsKey(AsyncChainExecution__c.ChainName__c.getDescribe().getName()),
				'ChainName__c should be projected');
		Assert.isTrue(
				populated.containsKey(AsyncChainExecution__c.Status__c.getDescribe().getName()),
				'Status__c should be projected');
		Assert.isFalse(
				populated.containsKey(AsyncChainExecution__c.ContextData__c.getDescribe().getName()),
				'ContextData__c must not be hauled by the summary projection');
		Assert.isFalse(
				populated.containsKey(AsyncChainExecution__c.StepLog__c.getDescribe().getName()),
				'StepLog__c must not be hauled by the summary projection');
		Assert.isFalse(
				populated.containsKey(AsyncChainExecution__c.ErrorMessage__c.getDescribe().getName()),
				'ErrorMessage__c must not be hauled by the summary projection');
	}

	/**
	 * @description Tests that findFiltered respects pagination boundaries.
	 */
	@IsTest
	private static void shouldFindFilteredWithPagination()
	{
		for(Integer index = 0; index < 5; index++)
		{
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'Chain' + index);
		}

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
				null, null, AsyncChainExecution__c.CreatedDate, true, 1, 2
		);

		Assert.areEqual(2, page.records.size(), 'Should return page size');
		Assert.areEqual(5, page.totalRecords, 'Total should be 5');
		Assert.isTrue(page.hasMorePages, 'Should have more pages');
		Assert.areEqual(3, page.totalPages, 'Should have 3 pages');
	}

	/**
	 * @description Tests that findStaleRunning returns Running and Stalled chains older than the
	 * threshold, excludes terminal statuses, and truncates to the requested batch size. A negative
	 * threshold places the cutoff one minute in the future, so every just-inserted row is
	 * deterministically past the threshold without back-dating audit fields.
	 *
	 * @see SEL_AsyncChainExecution.findStaleRunning
	 */
	@IsTest
	private static void shouldFindStaleRunningOnly()
	{
		AsyncChainExecution__c runningExecution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'WatchdogRunningChain');
		AsyncChainExecution__c stalledExecution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'WatchdogStalledChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'WatchdogCompletedChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'WatchdogFailedChain');

		List<AsyncChainExecution__c> staleExecutions = new SEL_AsyncChainExecution().findStaleRunning(-1, 50);

		Assert.areEqual(2, staleExecutions.size(), 'Only the Running and Stalled chains are stale candidates');

		Set<Id> staleExecutionIds = new Map<Id, AsyncChainExecution__c>(staleExecutions).keySet();
		Assert.isTrue(staleExecutionIds.contains(runningExecution.Id), 'The past-threshold Running chain is a stale candidate');
		Assert.isTrue(staleExecutionIds.contains(stalledExecution.Id), 'The past-threshold Stalled chain remains a stale candidate');

		for(AsyncChainExecution__c staleExecution : staleExecutions)
		{
			Assert.isNotNull(staleExecution.LastModifiedDate, 'Stale candidates carry LastModifiedDate so the watchdog can read stall age');
		}

		Assert.areEqual(1, new SEL_AsyncChainExecution().findStaleRunning(-1, 1).size(), 'A batch size below the match count truncates the result');
	}

	/**
	 * @description Tests that findStaleRunning excludes chains modified within the threshold
	 * window: with only just-inserted rows, a 30-minute threshold returns no candidates.
	 *
	 * @see SEL_AsyncChainExecution.findStaleRunning
	 */
	@IsTest
	private static void shouldExcludeFreshChainsFromStaleRunning()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'FreshRunningChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'FreshStalledChain');

		Assert.isTrue(new SEL_AsyncChainExecution().findStaleRunning(30, 50).isEmpty(),
				'Chains modified within the threshold window are not stale candidates');
	}

	/**
	 * @description A Stalled row carrying a completion timestamp is a clobbered terminal row, not a
	 * recovery candidate: the sweep must exclude it, and must still return a genuinely stalled row
	 * whose timestamp is null — the second half proves the predicate did not disable the sweep.
	 *
	 * @see SEL_AsyncChainExecution.findStaleRunning
	 */
	@IsTest
	private static void shouldExcludeCompletedTimestampRowsFromStaleRunning()
	{
		AsyncChainExecution__c genuineStall = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'GenuineStall');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'ClobberedTerminal',
				new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});

		List<AsyncChainExecution__c> candidates = new SEL_AsyncChainExecution().findStaleRunning(-1, 50);

		Assert.areEqual(1, candidates.size(), 'Only the null-timestamp stall is a candidate');
		Assert.areEqual(genuineStall.Id, candidates[0].Id, 'The genuine stall must still be swept');
	}

	/**
	 * @description Tests that findStalledForOperatorSweep returns only Stalled rows with no
	 * completion timestamp — Running rows are the watchdog's concern, and a Stalled row carrying
	 * CompletedAt__c is a clobbered terminal row — and applies no staleness threshold: the
	 * operator asked for a sweep NOW, so every genuine stall is a candidate regardless of age.
	 *
	 * @see SEL_AsyncChainExecution.findStalledForOperatorSweep
	 */
	@IsTest
	private static void shouldFindOnlyGenuineStallsForOperatorSweep()
	{
		AsyncChainExecution__c genuineStall = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'OperatorGenuineStall');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'OperatorRunningChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'OperatorFailedChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'OperatorClobberedTerminal',
				new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});

		List<AsyncChainExecution__c> candidates = new SEL_AsyncChainExecution().findStalledForOperatorSweep(50);

		Assert.areEqual(1, candidates.size(), 'Only the genuine stall is an operator-sweep candidate');
		Assert.areEqual(genuineStall.Id, candidates[0].Id, 'A just-stalled chain is a candidate immediately: the operator sweep applies no staleness threshold');
	}

	/**
	 * @description The clear-stalled dialog names how many chains are waiting before the operator
	 * commits, so the count has to match the population findStalledForOperatorSweep takes: stalled
	 * rows with no completion timestamp, and nothing else.
	 *
	 * @see SEL_AsyncChainExecution.countStalledAwaitingSweep
	 */
	@IsTest
	private static void shouldCountOnlyGenuineStallsAwaitingSweep()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'CountableStallOne');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'CountableStallTwo');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'CountableRunningChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'CountableClobberedTerminal',
				new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});

		Integer waiting = new SEL_AsyncChainExecution().countStalledAwaitingSweep();

		Assert.areEqual(STALLS_AWAITING_SWEEP, waiting, 'Only stalled rows with no completion timestamp are waiting for the sweep');
	}

	/**
	 * @description Tests that findStalledForOperatorSweep truncates to the batch size and returns
	 * an empty list without querying for a null or non-positive batch size.
	 *
	 * @see SEL_AsyncChainExecution.findStalledForOperatorSweep
	 */
	@IsTest
	private static void shouldBoundAndGuardOperatorSweepBatch()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'OperatorStallOne');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'OperatorStallTwo');

		Assert.areEqual(1, new SEL_AsyncChainExecution().findStalledForOperatorSweep(1).size(), 'A batch size below the match count truncates the result');
		Assert.isTrue(new SEL_AsyncChainExecution().findStalledForOperatorSweep(null).isEmpty(), 'A null batch size returns empty instead of querying unbounded');
		Assert.isTrue(new SEL_AsyncChainExecution().findStalledForOperatorSweep(0).isEmpty(), 'A non-positive batch size returns empty instead of querying unbounded');
	}

	/**
	 * @description Tier-A — proves findStalledForOperatorSweep returns a stalled chain the
	 * running user neither owns nor shares: the operator sweep is an org-wide recovery surface,
	 * and who may run it is decided by the Chain Monitor's permission gates, not by record
	 * ownership.
	 *
	 * Catches: a future refactor that drops the sharing bypass from findStalledForOperatorSweep
	 * would silently empty the operator sweep for every chain the operator does not own — with
	 * every other test still green, because they all seed and sweep as the same user.
	 *
	 * @see SEL_AsyncChainExecution.findStalledForOperatorSweep
	 */
	@IsTest
	private static void shouldFindForeignStalledChainsForOperatorSweep()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		Id foreignStalledId;
		System.runAs(getTestAdmin())
		{
			foreignStalledId = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'ForeignStalledChain').Id;
		}

		System.runAs(lowPrivilegeUser)
		{
			List<AsyncChainExecution__c> candidates = new SEL_AsyncChainExecution().findStalledForOperatorSweep(50);

			Assert.areEqual(1, candidates.size(), 'A stalled chain owned by another user must still be an operator-sweep candidate');
			Assert.areEqual(foreignStalledId, candidates[0].Id, 'The candidate must be the foreign-owned stall');
		}
	}

	/**
	 * @description Tests the operator sweep's two heap-guard projections. The candidate read
	 * carries everything the sweep's decision legs consult — StepLog__c included, for the
	 * detect-mark leg's handler resolution — but deliberately NEITHER ContextData__c (131KB) NOR
	 * ErrorMessage__c (32KB), the two long-text payloads no leg reads off a candidate row. The
	 * tally read projects Status__c alone. Field access on an unqueried field throws, which is
	 * exactly the witness.
	 *
	 * @see SEL_AsyncChainExecution.findStalledForOperatorSweep
	 * @see SEL_AsyncChainExecution.findByIdsForSweepTally
	 */
	@IsTest
	private static void shouldProjectOperatorSweepReadsWithoutLongTextPayloads()
	{
		AsyncChainExecution__c seeded = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'ProjectionGuardChain', new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StepLog__c => PROJECTION_GUARD_STEP_LOG,
				AsyncChainExecution__c.ContextData__c => PROJECTION_GUARD_CONTEXT,
				AsyncChainExecution__c.ErrorMessage__c => PROJECTION_GUARD_ERROR_MESSAGE
		});

		AsyncChainExecution__c candidate = new SEL_AsyncChainExecution().findStalledForOperatorSweep(50)[0];
		Assert.areEqual(PROJECTION_GUARD_STEP_LOG, candidate.StepLog__c, 'StepLog__c must stay on the candidate projection: the detect-mark leg reads it');
		try
		{
			String unprojected = candidate.ContextData__c;
			Assert.fail('Should throw SObjectException: ContextData__c must not ride the candidate projection, but read ' + unprojected);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
		try
		{
			String unprojected = candidate.ErrorMessage__c;
			Assert.fail('Should throw SObjectException: ErrorMessage__c must not ride the candidate projection, but read ' + unprojected);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}

		List<AsyncChainExecution__c> statuses = new SEL_AsyncChainExecution().findByIdsForSweepTally(new Set<Id> {seeded.Id});
		Assert.areEqual(1, statuses.size(), 'The tally read must return the requested row');
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, statuses[0].Status__c, 'The tally read must carry the status it classifies on');
		Assert.isTrue(new SEL_AsyncChainExecution().findByIdsForSweepTally(new Set<Id>()).isEmpty(), 'An empty id set returns empty instead of querying');
		try
		{
			String unprojected = statuses[0].StepLog__c;
			Assert.fail('Should throw SObjectException: the tally projection is Status__c only, but read ' + unprojected);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests the live-stream seed's correlation-only projection: the seed reads one
	 * field to key its correlated-trace read, so neither long-text payload may ride the row, and
	 * a missing id resolves null instead of throwing.
	 *
	 * @see SEL_AsyncChainExecution.findByIdForLogStreamSeed
	 */
	@IsTest
	private static void shouldProjectLogStreamSeedReadAsCorrelationOnly()
	{
		AsyncChainExecution__c seeded = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'StreamSeedChain', new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StepLog__c => PROJECTION_GUARD_STEP_LOG
		});

		AsyncChainExecution__c row = new SEL_AsyncChainExecution().findByIdForLogStreamSeed(seeded.Id);

		Assert.areEqual(seeded.CorrelationId__c, row.CorrelationId__c, 'The seed read must carry the correlation id it keys the trace on');
		try
		{
			String unprojected = row.StepLog__c;
			Assert.fail('Should throw SObjectException: the seed projection is CorrelationId__c only, but read ' + unprojected);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
		AsyncChainExecution__c missing = new SEL_AsyncChainExecution().findByIdForLogStreamSeed(UTIL_Random.randomId(AsyncChainExecution__c.SObjectType));
		Assert.isNull(missing, 'A missing row resolves null instead of throwing');
	}

	/**
	 * @description Tests that findStaleRunning returns an empty list without querying when the
	 * threshold or batch size is null, or the batch size is not positive.
	 *
	 * @see SEL_AsyncChainExecution.findStaleRunning
	 */
	@IsTest
	private static void shouldReturnEmptyForInvalidStaleRunningArguments()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'GuardedChain');

		SEL_AsyncChainExecution selector = new SEL_AsyncChainExecution();
		Assert.isTrue(selector.findStaleRunning(null, 50).isEmpty(), 'A null threshold returns no candidates');
		Assert.isTrue(selector.findStaleRunning(-1, null).isEmpty(), 'A null batch size returns no candidates');
		Assert.isTrue(selector.findStaleRunning(-1, 0).isEmpty(), 'A non-positive batch size returns no candidates');
	}

	/**
	 * @description Tier-A — proves SEL_AsyncChainExecution.findByStatus returns
	 * rows when invoked by a subscriber user on the Minimum Access - Salesforce profile who has no
	 * FLS on kern__AsyncChainExecution__c. The framework-owned selector declares
	 * `systemModeRequired() = true`, so its internal QRY_Builder must elevate to SYSTEM_MODE and
	 * the query must return the seeded rows regardless of the running user's FLS.
	 *
	 * Catches: a future refactor that demotes SEL_AsyncChainExecution.systemModeRequired() to
	 * false, or deletes the override entirely, would cause the low-privilege user's query to fail
	 * with "No such column" under USER_MODE — this test fails at 2GP validated-build time rather
	 * than at subscriber scratch-org time.
	 *
	 * AsyncChainExecution__c has OWD=Private, so the seeded record's OwnerId is set to the
	 * low-privilege user to satisfy sharing (SYSTEM_MODE elevates FLS but not sharing under
	 * `inherited sharing`). This mirrors the realistic subscriber-admin scenario where a
	 * subscriber user triggers a chain that records its own execution.
	 *
	 * @see SEL_AsyncChainExecution.findByStatus
	 * @see SEL_AsyncChainExecution.systemModeRequired
	 */
	@IsTest
	private static void shouldFindByStatusForLowPrivilegeUser()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();

		System.runAs(getTestAdmin())
		{
			TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.ChainName__c, 'LowPrivilegeChain')
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
					.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
					.withOverride(AsyncChainExecution__c.OwnerId, lowPrivilegeUser.Id)
					.build();
		}

		System.runAs(lowPrivilegeUser)
		{
			List<AsyncChainExecution__c> results = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);

			Assert.isFalse(results.isEmpty(), 'Should find the seeded AsyncChainExecution__c for low-privilege caller');
		}
	}

	/**
	 * @description Tier-A — proves SEL_AsyncChainExecution.existsByCorrelationId reports a registered chain
	 * as existing even when the running user neither owns nor shares the chain record. The chain is seeded
	 * owned by the admin (AsyncChainExecution__c is OWD=Private) and probed by a Minimum Access - Salesforce
	 * user; the probe bypasses sharing (as the console's log reads and the Chain Monitor's org-wide listing
	 * do), so it must still report the chain, otherwise Open in Chain Monitor would be hidden in exactly the
	 * multi-user org the console targets.
	 *
	 * Catches: a future refactor that drops the sharing bypass from existsByCorrelationId would hide the
	 * Chain Monitor entry point for chains the viewer does not own.
	 *
	 * @see SEL_AsyncChainExecution.existsByCorrelationId
	 */
	@IsTest
	private static void shouldReportChainExistenceRegardlessOfSharing()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		String foreignCorrelationId = UTIL_Random.randomUUID();

		seedForeignOwnedChain(foreignCorrelationId);

		System.runAs(lowPrivilegeUser)
		{
			Assert.isTrue(new SEL_AsyncChainExecution().existsByCorrelationId(foreignCorrelationId),
					'A registered chain owned by another user must still report as existing, so Open in Chain Monitor is offered consistently '
					+ 'with how the console reads logs and how the monitor lists chains org-wide');
			Assert.isFalse(new SEL_AsyncChainExecution().existsByCorrelationId(UTIL_Random.randomUUID()),
					'An unknown correlation reports no chain');
			Assert.isFalse(new SEL_AsyncChainExecution().existsByCorrelationId('   '),
					'A blank correlation reports no chain without querying');
		}
	}

	/**
	 * @description Tier-A — proves findByCorrelationIdForMonitoring resolves a chain the running
	 * user neither owns nor shares. The Log Console offers Open in Chain Monitor via the
	 * sharing-bypassing existsByCorrelationId, so the deep-link resolve on the receiving side must
	 * see the same record; a sharing-respecting read would silently land the deep link on the
	 * default selection for every non-owner without View All.
	 *
	 * Catches: a future refactor that drops the sharing bypass from findByCorrelationIdForMonitoring
	 * would break Open in Chain Monitor for exactly the multi-user orgs the console targets.
	 *
	 * @see SEL_AsyncChainExecution.findByCorrelationIdForMonitoring
	 */
	@IsTest
	private static void shouldResolveForeignChainByCorrelationForMonitoring()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		String foreignCorrelationId = UTIL_Random.randomUUID();
		Id seededExecutionId = seedForeignOwnedChain(foreignCorrelationId);

		System.runAs(lowPrivilegeUser)
		{
			AsyncChainExecution__c resolved = new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring(foreignCorrelationId);

			Assert.isNotNull(resolved, 'A chain owned by another user must resolve for the monitoring deep link');
			Assert.areEqual(seededExecutionId, resolved.Id, 'The resolved chain must be the one carrying the correlation id');
			Assert.isNull(new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring(UTIL_Random.randomUUID()),
					'An unknown correlation resolves to null');
			Assert.isNull(new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring('   '),
					'A blank correlation resolves to null without querying');
		}
	}

	/**
	 * @description Seeds a Running chain as the test admin, carrying the given correlation id.
	 * Used by the tier-A sharing tests so the low-privilege user queries a record it neither
	 * owns nor shares.
	 *
	 * @param correlationId The correlation id to stamp on the seeded chain.
	 *
	 * @return The seeded AsyncChainExecution__c Id.
	 */
	private static Id seedForeignOwnedChain(String correlationId)
	{
		Id seededExecutionId;
		System.runAs(getTestAdmin())
		{
			seededExecutionId = TST_Factory.newChainExecution(
					SEL_AsyncChainExecution.STATUS_RUNNING, 'ForeignOwnedChain',
					new Map<SObjectField, Object> {AsyncChainExecution__c.CorrelationId__c => correlationId}
			).Id;
		}
		return seededExecutionId;
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the AsyncChainExecution__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise
	 * SEL_AsyncChainExecution.findByStatus and prove the framework-owned selector elevates
	 * internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}