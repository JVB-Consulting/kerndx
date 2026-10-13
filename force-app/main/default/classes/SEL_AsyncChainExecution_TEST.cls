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
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class SEL_AsyncChainExecution_TEST
{
	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_AsyncChainExecution_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup. The tests that run as a different, low-privilege user use it.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_AsyncChainExecution_TEST-low-privilege';

	/**
	 * @description Chain name of the run that shouldReturnInitialContextSnapshotOnRestartRead seeds, to check that the
	 * restart read returns the snapshot field.
	 */
	private static final String RESTART_READ_CHAIN_NAME = 'RestartReadChain';

	/**
	 * @description Snapshot document that shouldReturnInitialContextSnapshotOnRestartRead seeds. The test expects it
	 * back from the restart read, which adds the snapshot field to the default field list.
	 */
	private static final String RESTART_READ_SNAPSHOT = '{"seedKey":"seed-value"}';

	/**
	 * @description Step-log document that shouldLeaveLongTextPayloadsOutOfOperatorSweepReads seeds. The test expects
	 * it back from the sweep's candidate read, which proves the read keeps the fields it needs.
	 */
	private static final String SWEEP_FIELD_GUARD_STEP_LOG = '[{"className":"SweepFieldGuardStep"}]';

	/**
	 * @description How many of the rows shouldCountOnlyGenuineStallsAwaitingSweep seeds are still
	 * waiting for the operator sweep: the two stalled rows with no completion timestamp.
	 */
	private static final Integer STALLS_AWAITING_SWEEP = 2;

	/**
	 * @description Context document that shouldLeaveLongTextPayloadsOutOfOperatorSweepReads seeds. The test must NOT
	 * get it back from either sweep read, which proves the reads leave this long-text field out.
	 */
	private static final String SWEEP_FIELD_GUARD_CONTEXT = '{"seed":"value"}';

	/**
	 * @description The chain name of the run whose tracking ids the selector must read back.
	 */
	private static final String TRACKED_CHAIN_NAME = 'TrackedChain';

	/**
	 * @description Error message that shouldLeaveLongTextPayloadsOutOfOperatorSweepReads seeds. The test must NOT
	 * get it back from the candidate read. It is the second long-text field that read leaves out.
	 */
	private static final String SWEEP_FIELD_GUARD_ERROR_MESSAGE = 'Seeded error message for the sweep field check';

	/**
	 * @description Saves a test admin and a low-privilege user in @TestSetup's own transaction. Then the tests that run
	 * as another user (such as shouldFindByStatusForLowPrivilegeUser) can call System.runAs with either user without a
	 * MIXED_DML_OPERATION error. User is a Setup object, so a User save cannot share a transaction with a save of a
	 * standard or custom object. Creating the users here keeps the two apart.
	 *
	 * Only the tests that run as another user use these users. The other tests run as the default test user, without
	 * runAs.
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
		Assert.isTrue(fields.contains(AsyncChainExecution__c.CurrentJobId__c), 'Should contain CurrentJobId__c so the watchdog can check whether the chain\'s job is still alive');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.FailureCategory__c), 'Should contain FailureCategory__c so the Chain Monitor can show why the chain failed');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.LastModifiedDate), 'Should contain LastModifiedDate so the watchdog can see how long the chain has not moved');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.LastManualRetryAt__c), 'Should contain LastManualRetryAt__c so the monitor shows the last manual retry');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.ElapsedMs__c), 'Should contain ElapsedMs__c so the Chain Monitor sorts by the value it shows');
	}

	/**
	 * @description The default field list must hold the fields that decide whether a chain may be started again:
	 * AllowRestart__c, SourceExecution__c and DeclaredDeduplicationKey__c. They are a checkbox, a lookup id and a short
	 * text, so they cost little per row. A retry reads the declared key from the monitoring row to find the child chain
	 * it already launched. The list must leave out InitialContextData__c on purpose. That field is a copy of the
	 * chain's starting data and a third 131KB long-text field. In the default list it would load on every step of a
	 * chain that allows a restart and on every monitor detail read (SUMMARY_FIELDS leaves out long text for the same
	 * heap reason). So only the read made for a restart may read that copy.
	 */
	@IsTest
	private static void shouldReturnRestartMarkersWithoutInitialContextSnapshot()
	{
		List<SObjectField> fields = new SEL_AsyncChainExecution().getFields();
		Assert.isTrue(fields.contains(AsyncChainExecution__c.AllowRestart__c), 'Should contain AllowRestart__c so the restart checks can read it from the monitoring row');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.SourceExecution__c), 'Should contain SourceExecution__c so the monitoring row shows which run it was restarted from');
		Assert.isTrue
				(
						fields.contains(AsyncChainExecution__c.DeclaredDeduplicationKey__c),
						'Should contain DeclaredDeduplicationKey__c so a retry can find the child chain it already launched'
				);
		Assert.isFalse
				(
						fields.contains(AsyncChainExecution__c.InitialContextData__c),
						'Must exclude the InitialContextData__c snapshot: a third 131KB long-text on every default read is a heap risk'
				);
	}

	/**
	 * @description The read made for a restart must return InitialContextData__c, the copy of the chain's starting
	 * data that the default field list leaves out on purpose. It is the only query that reads this 131KB field, and
	 * the restart action takes the copy from exactly this row. The read must still return the default fields as well.
	 *
	 * @see SEL_AsyncChainExecution.findByIdForRestart
	 */
	@IsTest
	private static void shouldReturnInitialContextSnapshotOnRestartRead()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, RESTART_READ_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.AllowRestart__c => true,
				AsyncChainExecution__c.InitialContextData__c => RESTART_READ_SNAPSHOT
		});

		Test.startTest();
		AsyncChainExecution__c restartRead = new SEL_AsyncChainExecution().findByIdForRestart(execution.Id);
		Test.stopTest();

		Assert.isNotNull(restartRead, 'The restart read should find the chain execution');
		Assert.areEqual(RESTART_READ_SNAPSHOT, restartRead.InitialContextData__c, 'Expected the restart read to return the snapshot that the default field list leaves out');
		Assert.areEqual(true, restartRead.AllowRestart__c, 'Expected the restart read to still carry the default fields');
	}

	/**
	 * @description Tests that the Chain Monitor detail read returns the record and writes no sharing BYPASS audit
	 * entry. The read ignores sharing because the console must see every user's private chains. That is a choice made
	 * inside the framework, not an option a subscriber turns on, so it is not audited.
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
				.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
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
	 * @description findByDeclaredDeduplicationKey returns the run declared under the key even after it finished and
	 * released its active key.
	 */
	@IsTest
	private static void shouldFindTheRunDeclaredUnderADeduplicationKeyAfterItFinished()
	{
		String deduplicationKey = UTIL_Random.randomUUID();
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'DeduplicationChain',
				new Map<SObjectField, Object> {AsyncChainExecution__c.DeclaredDeduplicationKey__c => deduplicationKey});

		AsyncChainExecution__c found = new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(deduplicationKey);
		Assert.isNotNull(found, 'A finished run declared under the key is still found');
		Assert.areEqual(deduplicationKey, found.DeclaredDeduplicationKey__c, 'The matched run carries the declared key');
		Assert.isNull(found.ActiveDeduplicationKey__c, 'The finished run holds no active key');
	}

	/**
	 * @description findByDeclaredDeduplicationKey returns null when no run was declared under the key.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoRunDeclaredTheDeduplicationKey()
	{
		Assert.isNull(new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(UTIL_Random.randomUUID()), 'A key nobody declared resolves to no run');
	}

	/**
	 * @description Runs as a low-privilege user. Proves that findByDeclaredDeduplicationKey finds a run the user
	 * neither owns nor has shared with them. A step that runs again may run as an operator who cannot see the child
	 * chain the step launched before. A read that kept sharing would then launch a second child.
	 *
	 * Catches: a later change that makes findByDeclaredDeduplicationKey keep sharing.
	 *
	 * @see SEL_AsyncChainExecution.findByDeclaredDeduplicationKey
	 */
	@IsTest
	private static void shouldFindTheDeclaredKeysRunRegardlessOfSharing()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		String deduplicationKey = UTIL_Random.randomUUID();
		Id seededExecutionId;
		System.runAs(getTestAdmin())
		{
			seededExecutionId = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'ForeignOwnedChain',
					new Map<SObjectField, Object> {AsyncChainExecution__c.DeclaredDeduplicationKey__c => deduplicationKey}).Id;
		}

		System.runAs(lowPrivilegeUser)
		{
			AsyncChainExecution__c found = new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(deduplicationKey);
			Assert.isNotNull(found, 'A run declared under the key by another user must still be found, so a step that runs again gets its child back');
			Assert.areEqual(seededExecutionId, found.Id, 'The found run is the one declared under the key');
		}
	}

	/**
	 * @description Runs as a low-privilege user. Checks that findByIdForTransition finds a run the user neither owns
	 * nor has shared with them, while the default read of the same run returns nothing for that user. The read must
	 * ignore sharing for two reasons. Every save after it runs in system mode. And the watchdog must be able to mark as
	 * Stalled a run that its own user does not own.
	 *
	 * Catches: a later change that makes findByIdForTransition keep sharing.
	 *
	 * @see SEL_AsyncChainExecution.findByIdForTransition
	 */
	@IsTest
	private static void shouldReadARowAnotherUserOwnsForATransition()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		Id seededExecutionId;
		System.runAs(getTestAdmin())
		{
			seededExecutionId = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'ForeignOwnedTransitionChain').Id;
		}

		System.runAs(lowPrivilegeUser)
		{
			AsyncChainExecution__c found = new SEL_AsyncChainExecution().findByIdForTransition(seededExecutionId);

			Assert.isNotNull(found, 'Expected a run owned by another user to be readable for a transition');
			Assert.areEqual(seededExecutionId, found.Id, 'Expected the read to return the run asked for, got ' + found.Id);
			Assert.isNull(new SEL_AsyncChainExecution().findById(seededExecutionId), 'Expected the default read to keep sharing, so the same user cannot see the run');
			Assert.isNull(new SEL_AsyncChainExecution().findByIdForTransition(UTIL_Random.randomId(AsyncChainExecution__c.SObjectType)), 'Expected a missing run to read null');
		}
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
				listCriteria(new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_COMPLETED}, 'Account', true, 10));

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

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(listCriteria(null, null, false, 10));

		Assert.areEqual(2, page.records.size(), 'Should return all records');
		Assert.areEqual(2, page.totalRecords, 'Total should be 2');
	}

	/**
	 * @description Tests that findFiltered reads only the summary fields that the Chain Monitor list and the Log
	 * Console's banner for one action show. It leaves out the long-text fields (ContextData__c, StepLog__c,
	 * ErrorMessage__c).
	 */
	@IsTest
	private static void shouldFindFilteredWithSummaryFields()
	{
		AsyncChainExecution__c sourceRun = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'SourceChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'PayloadChain',
				new Map<SObjectField, Object>
				{
						AsyncChainExecution__c.ContextData__c => '{"key":"value"}',
						AsyncChainExecution__c.StepLog__c => '[]',
						AsyncChainExecution__c.ErrorMessage__c => 'Step failure detail',
						AsyncChainExecution__c.LaunchCorrelationId__c => UTIL_Random.randomUUID(),
						AsyncChainExecution__c.RootCorrelationId__c => UTIL_Random.randomUUID(),
						AsyncChainExecution__c.SourceExecution__c => sourceRun.Id
				});

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(listCriteria(null, 'PayloadChain', true, 10));

		Assert.areEqual(1, page.records.size(), 'Should return the record');
		Map<String, Object> populated = page.records[0].getPopulatedFieldsAsMap();
		Assert.isTrue(populated.containsKey('Id'), 'Expected the summary read to return Id');
		Assert.isTrue(
				populated.containsKey(AsyncChainExecution__c.ChainName__c.getDescribe().getName()),
				'Expected the summary read to return ChainName__c');
		Assert.isTrue(
				populated.containsKey(AsyncChainExecution__c.Status__c.getDescribe().getName()),
				'Expected the summary read to return Status__c');
		Assert.isTrue(populated.containsKey(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.Name)),
				'Expected the summary read to return the chain number, because the consoles name a chain by it');
		Assert.isTrue(populated.containsKey(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.CorrelationId__c)),
				'Expected the summary read to return the correlation id, because a page matches against it to find the run that launched each run');
		Assert.isTrue(populated.containsKey(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.LaunchCorrelationId__c)),
				'Expected the summary read to return the launch id, because the Launched-under column reads it');
		Assert.isTrue(populated.containsKey(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.RootCorrelationId__c)),
				'Expected the summary read to return the root correlation id, because the filter by action reads it');
		Assert.isTrue(populated.containsKey(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.SourceExecution__c)),
				'Expected the summary read to return the source run, because a restarted run names the run it was copied from');
		Assert.isFalse(
				populated.containsKey(AsyncChainExecution__c.ContextData__c.getDescribe().getName()),
				'Expected the summary read to leave out ContextData__c');
		Assert.isFalse(
				populated.containsKey(AsyncChainExecution__c.StepLog__c.getDescribe().getName()),
				'Expected the summary read to leave out StepLog__c');
		Assert.isFalse(
				populated.containsKey(AsyncChainExecution__c.ErrorMessage__c.getDescribe().getName()),
				'Expected the summary read to leave out ErrorMessage__c');
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

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(listCriteria(null, null, true, 2));

		Assert.areEqual(2, page.records.size(), 'Should return page size');
		Assert.areEqual(5, page.totalRecords, 'Total should be 5');
		Assert.isTrue(page.hasMorePages, 'Should have more pages');
		Assert.areEqual(3, page.totalPages, 'Should have 3 pages');
	}

	/**
	 * @description When the list read is filtered by an action, it returns the runs launched under that action and no
	 * other. This filter works together with the status and name filters.
	 */
	@IsTest
	private static void shouldFindFilteredByTheActionRoot()
	{
		String actionRoot = UTIL_Random.randomUUID();
		AsyncChainExecution__c inside = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'ActionChain',
				new Map<SObjectField, Object> {AsyncChainExecution__c.RootCorrelationId__c => actionRoot});
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'ActionChain',
				new Map<SObjectField, Object> {AsyncChainExecution__c.RootCorrelationId__c => UTIL_Random.randomUUID()});

		SEL_AsyncChainExecution.ListCriteria criteria = listCriteria(null, null, true, 10);
		criteria.rootCorrelationId = actionRoot;
		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(criteria);

		Assert.areEqual(1, page.totalRecords, 'Only the run launched under the action is listed');
		Assert.areEqual(inside.Id, page.records[0].Id, 'The listed run is the action\'s');
	}

	/**
	 * @description Checks the page of an action's runs that the Log Console's banner reads. The runs are ordered by
	 * start time, oldest first. The total is exact, even when it is larger than the page. A status list narrows the
	 * page. A blank action id reads an empty page.
	 */
	@IsTest
	private static void shouldPageAnActionsRunsByStartWithAnExactTotal()
	{
		String actionRoot = UTIL_Random.randomUUID();
		List<Id> expectedOrder = new List<Id>();
		for(Integer index = 0; index < 7; index++)
		{
			String status = index < 3 ? SEL_AsyncChainExecution.STATUS_FAILED : SEL_AsyncChainExecution.STATUS_COMPLETED;
			expectedOrder.add(TST_Factory.newChainExecution(status, 'PagedChain', new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RootCorrelationId__c => actionRoot,
					AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-60 + index)
			}).Id);
		}

		Test.startTest();
		QRY_Builder.QueryPage allRuns = new SEL_AsyncChainExecution().findByRootPage(actionRoot, null, 5);
		QRY_Builder.QueryPage failedRuns = new SEL_AsyncChainExecution().findByRootPage(actionRoot, new List<String> {SEL_AsyncChainExecution.STATUS_FAILED}, 5);
		QRY_Builder.QueryPage blank = new SEL_AsyncChainExecution().findByRootPage(' ', null, 5);
		Test.stopTest();

		Assert.areEqual(7, allRuns.totalRecords, 'The total is exact, beyond the five-row page');
		Assert.areEqual(5, allRuns.records.size(), 'The page holds five rows');
		for(Integer index = 0; index < 5; index++)
		{
			Assert.areEqual(expectedOrder[index], allRuns.records[index].Id, 'Row ' + index + ' is the run that started ' + index + ' minutes after the first');
		}
		Assert.areEqual(3, failedRuns.totalRecords, 'The failed page counts the failed runs alone');
		Assert.areEqual(0, blank.totalRecords, 'A blank action reads an empty page');
		Assert.isTrue(blank.records.isEmpty(), 'A blank action reads no rows');
	}

	/**
	 * @description Checks the read that asks whether an action still has unfinished runs. It answers true while a
	 * Running or Stalled run exists under the action, and false once every run has ended. A blank action id or an
	 * empty status list answers false without a query.
	 */
	@IsTest
	private static void shouldTellWhetherAnActionStillHasUnfinishedRuns()
	{
		String runningAction = UTIL_Random.randomUUID();
		String finishedAction = UTIL_Random.randomUUID();
		List<String> unfinished = new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED};
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'StillGoing',
				new Map<SObjectField, Object> {AsyncChainExecution__c.RootCorrelationId__c => runningAction});
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'Ended',
				new Map<SObjectField, Object> {AsyncChainExecution__c.RootCorrelationId__c => finishedAction});

		Assert.isTrue(new SEL_AsyncChainExecution().existsByRootAndStatuses(runningAction, unfinished), 'A stalled run counts as unfinished');
		Assert.isFalse(new SEL_AsyncChainExecution().existsByRootAndStatuses(finishedAction, unfinished), 'A failed run has finished');
		Integer queriesBeforeGuards = UTIL_Limits.soqlQueries().used();
		Assert.isFalse(new SEL_AsyncChainExecution().existsByRootAndStatuses(' ', unfinished), 'A blank action answers false');
		Assert.isFalse(new SEL_AsyncChainExecution().existsByRootAndStatuses(runningAction, new List<String>()), 'An empty status list answers false');
		Assert.areEqual(queriesBeforeGuards, UTIL_Limits.soqlQueries().used(), 'The blank action and the empty status list answer without querying');
	}

	/**
	 * @description Checks the two summary reads, by correlation id and by run id. Each returns the runs asked for, with
	 * the summary fields. An empty or null set reads nothing, without a query.
	 */
	@IsTest
	private static void shouldFindRunsByCorrelationIdsAndByIdsWithTheSummaryFields()
	{
		AsyncChainExecution__c first = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'FirstChain');
		AsyncChainExecution__c second = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'SecondChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'ThirdChain');

		Test.startTest();
		List<AsyncChainExecution__c> byCorrelation = new SEL_AsyncChainExecution().findByCorrelationIds(new Set<String> {first.CorrelationId__c, second.CorrelationId__c});
		List<AsyncChainExecution__c> byId = new SEL_AsyncChainExecution().findByIdsForSummary(new Set<Id> {second.Id});
		Test.stopTest();

		Assert.areEqual(2, byCorrelation.size(), 'Both runs named by correlation are returned');
		Assert.areEqual(1, byId.size(), 'The run named by id is returned');
		Assert.areEqual(second.Id, byId[0].Id, 'The by-id read returns the run asked for');
		Assert.isNotNull(byId[0].Name, 'Expected the summary read to carry the chain number');
		Integer queriesBeforeGuards = UTIL_Limits.soqlQueries().used();
		Assert.isTrue(new SEL_AsyncChainExecution().findByCorrelationIds(new Set<String>()).isEmpty(), 'An empty correlation set reads nothing');
		Assert.isTrue(new SEL_AsyncChainExecution().findByCorrelationIds(null).isEmpty(), 'A null correlation set reads nothing');
		Assert.isTrue(new SEL_AsyncChainExecution().findByIdsForSummary(null).isEmpty(), 'A null id set reads nothing');
		Assert.areEqual(queriesBeforeGuards, UTIL_Limits.soqlQueries().used(), 'The empty and null sets read nothing without querying');
	}

	/**
	 * @description Tests that findStaleRunning returns Running and Stalled chains older than the threshold. It leaves
	 * out finished statuses and stops at the requested batch size. A negative threshold puts the cutoff one minute in
	 * the future. So every row the test just inserted is always past the threshold, and the test does not need to set
	 * the audit fields to an earlier date.
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
			Assert.isNotNull(staleExecution.LastModifiedDate, 'Stale candidates carry LastModifiedDate so the watchdog can see how long the chain has not moved');
		}

		Assert.areEqual(1, new SEL_AsyncChainExecution().findStaleRunning(-1, 1).size(), 'A batch size below the match count truncates the result');
	}

	/**
	 * @description Tests that findStaleRunning leaves out chains changed within the threshold. When every row was just
	 * inserted, a 30-minute threshold returns no candidates.
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
	 * @description A Stalled row with an end time (CompletedAt__c) is a finished run whose status was overwritten by
	 * mistake. It is not a candidate for recovery, so the sweep must leave it out. The sweep must still return a real
	 * stalled row with no end time. That second check proves the end-time filter did not turn the sweep off.
	 *
	 * @see SEL_AsyncChainExecution.findStaleRunning
	 */
	@IsTest
	private static void shouldExcludeCompletedTimestampRowsFromStaleRunning()
	{
		AsyncChainExecution__c genuineStall = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'GenuineStall');
		insertStalledRunWithEndTime('ClobberedTerminal');

		List<AsyncChainExecution__c> candidates = new SEL_AsyncChainExecution().findStaleRunning(-1, 50);

		Assert.areEqual(1, candidates.size(), 'Only the stalled row with no end time is a candidate');
		Assert.areEqual(genuineStall.Id, candidates[0].Id, 'The genuine stall must still be swept');
	}

	/**
	 * @description Tests that findStalledForOperatorSweep returns only Stalled rows with no end time. Running rows are
	 * left to the scheduled watchdog. A Stalled row with an end time (CompletedAt__c) is a finished run whose status
	 * was overwritten by mistake. The read also uses no age threshold: the operator asked for a sweep now, so every
	 * real stall is a candidate, however recent.
	 *
	 * @see SEL_AsyncChainExecution.findStalledForOperatorSweep
	 */
	@IsTest
	private static void shouldFindOnlyGenuineStallsForOperatorSweep()
	{
		AsyncChainExecution__c genuineStall = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'OperatorGenuineStall');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'OperatorRunningChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'OperatorFailedChain');
		insertStalledRunWithEndTime('OperatorClobberedTerminal');

		List<AsyncChainExecution__c> candidates = new SEL_AsyncChainExecution().findStalledForOperatorSweep(50);

		Assert.areEqual(1, candidates.size(), 'Only the real stall is a candidate for the operator sweep');
		Assert.areEqual(genuineStall.Id, candidates[0].Id, 'A chain that just stalled is a candidate at once: the operator sweep uses no age threshold');
	}

	/**
	 * @description The Clear Stalled dialog shows how many chains are waiting before the operator confirms. So the
	 * count must match the rows findStalledForOperatorSweep reads: stalled rows with no end time, and nothing else.
	 *
	 * @see SEL_AsyncChainExecution.countStalledAwaitingSweep
	 */
	@IsTest
	private static void shouldCountOnlyGenuineStallsAwaitingSweep()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'CountableStallOne');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'CountableStallTwo');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'CountableRunningChain');
		insertStalledRunWithEndTime('CountableClobberedTerminal');

		Integer waiting = new SEL_AsyncChainExecution().countStalledAwaitingSweep();

		Assert.areEqual(STALLS_AWAITING_SWEEP, waiting, 'Only stalled rows with no completion timestamp are waiting for the sweep');
	}

	/**
	 * @description Tests that findStalledForOperatorSweep stops at the batch size. For a null batch size, or one that
	 * is zero or less, it returns an empty list without a query.
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
	 * @description Runs as a low-privilege user. Proves that findStalledForOperatorSweep returns a stalled chain the
	 * user neither owns nor has shared with them. The operator sweep recovers chains from the whole org. The Chain
	 * Monitor's permission checks decide who may run it, not who owns the record.
	 *
	 * Catches: a later change that makes findStalledForOperatorSweep keep sharing. The operator sweep would then find
	 * nothing, with no warning, for every chain the operator does not own. Every other test would still pass, because
	 * they all create and sweep chains as the same user.
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

			Assert.areEqual(1, candidates.size(), 'A stalled chain owned by another user must still be a candidate for the operator sweep');
			Assert.areEqual(foreignStalledId, candidates[0].Id, 'The candidate must be the stalled chain another user owns');
		}
	}

	/**
	 * @description Tests the field lists of the operator sweep's two reads, which keep the heap small. The candidate
	 * read holds every field the sweep's decisions use. That includes StepLog__c, which the step that finds and marks a
	 * stalled run reads to find the notification handler. It leaves out, on purpose, ContextData__c (131KB) and
	 * ErrorMessage__c (32KB): no step of the sweep reads these two long-text fields from a candidate row. The read that
	 * counts the results returns Status__c alone. Reading a field the query did not ask for throws an error, and that
	 * error is what the test checks.
	 *
	 * @see SEL_AsyncChainExecution.findStalledForOperatorSweep
	 * @see SEL_AsyncChainExecution.findByIdsForSweepTally
	 */
	@IsTest
	private static void shouldLeaveLongTextPayloadsOutOfOperatorSweepReads()
	{
		AsyncChainExecution__c seeded = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, 'SweepFieldGuardChain', new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StepLog__c => SWEEP_FIELD_GUARD_STEP_LOG,
				AsyncChainExecution__c.ContextData__c => SWEEP_FIELD_GUARD_CONTEXT,
				AsyncChainExecution__c.ErrorMessage__c => SWEEP_FIELD_GUARD_ERROR_MESSAGE
		});

		AsyncChainExecution__c candidate = new SEL_AsyncChainExecution().findStalledForOperatorSweep(50)[0];
		Assert.areEqual(SWEEP_FIELD_GUARD_STEP_LOG, candidate.StepLog__c, 'Expected the candidate read to keep StepLog__c, because the step that marks a stalled run reads it');
		try
		{
			String valueLeftOut = candidate.ContextData__c;
			Assert.fail('Expected an SObjectException, because the candidate read leaves out ContextData__c, but read ' + valueLeftOut);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
		try
		{
			String valueLeftOut = candidate.ErrorMessage__c;
			Assert.fail('Expected an SObjectException, because the candidate read leaves out ErrorMessage__c, but read ' + valueLeftOut);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}

		List<AsyncChainExecution__c> statuses = new SEL_AsyncChainExecution().findByIdsForSweepTally(new Set<Id> {seeded.Id});
		Assert.areEqual(1, statuses.size(), 'The read that counts the results must return the requested row');
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, statuses[0].Status__c, 'The read that counts the results must return the status it sorts by');
		Assert.isTrue(new SEL_AsyncChainExecution().findByIdsForSweepTally(new Set<Id>()).isEmpty(), 'An empty id set returns empty instead of querying');
		try
		{
			String valueLeftOut = statuses[0].StepLog__c;
			Assert.fail('Expected an SObjectException, because the read that counts the results returns Status__c only, but read ' + valueLeftOut);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that the read for the live log stream's first load returns the correlation id only. The
	 * stream needs that one field to read the log entries that carry it, so no long-text field may come with the row.
	 * A missing id returns null instead of throwing.
	 *
	 * @see SEL_AsyncChainExecution.findByIdForLogStreamSeed
	 */
	@IsTest
	private static void shouldReadOnlyTheCorrelationIdForLogStreamSeed()
	{
		AsyncChainExecution__c seeded = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'StreamSeedChain', new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StepLog__c => SWEEP_FIELD_GUARD_STEP_LOG
		});

		AsyncChainExecution__c row = new SEL_AsyncChainExecution().findByIdForLogStreamSeed(seeded.Id);

		Assert.areEqual(seeded.CorrelationId__c, row.CorrelationId__c, 'The first-load read must return the correlation id that the stream reads the log entries by');
		try
		{
			String valueLeftOut = row.StepLog__c;
			Assert.fail('Expected an SObjectException, because the first-load read returns CorrelationId__c only, but read ' + valueLeftOut);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
		AsyncChainExecution__c missing = new SEL_AsyncChainExecution().findByIdForLogStreamSeed(UTIL_Random.randomId(AsyncChainExecution__c.SObjectType));
		Assert.isNull(missing, 'A missing row resolves null instead of throwing');
	}

	/**
	 * @description Tests that findStaleRunning returns an empty list without a query when the threshold or the batch
	 * size is null, or when the batch size is zero or less.
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
	 * @description Runs as a low-privilege user. Proves that SEL_AsyncChainExecution.findByStatus returns rows when a
	 * subscriber user on the Minimum Access - Salesforce profile calls it. That user has no field-level access (FLS)
	 * on AsyncChainExecution__c. The selector reads a framework-owned object and declares
	 * `systemModeRequired() = true`. So its QRY_Builder must switch to SYSTEM_MODE, and the query must return the
	 * seeded rows whatever the running user's FLS.
	 *
	 * Catches: a later change that makes SEL_AsyncChainExecution.systemModeRequired() return false, or removes the
	 * override. The low-privilege user's query would then fail with "No such column" in USER_MODE. This test fails
	 * when the managed package version is built and validated, not later in a subscriber's scratch org.
	 *
	 * AsyncChainExecution__c records are private (the org-wide default is Private). So the seeded record's OwnerId is
	 * set to the low-privilege user, to give that user sharing access. SYSTEM_MODE lifts the field checks but not
	 * sharing in an `inherited sharing` class. This matches a real subscriber org, where a user starts a chain and
	 * the chain records its own run.
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
	 * @description Runs as a low-privilege user. Proves that SEL_AsyncChainExecution.findByCorrelationIds still finds a
	 * chain when the user neither owns the chain record nor has it shared with them. The Log Console uses this read to
	 * decide whether to offer Open in Chain Monitor. The admin owns the seeded chain (AsyncChainExecution__c records
	 * are private by default), and a Minimum Access - Salesforce user reads it. The read ignores sharing, as the
	 * console's log reads and the Chain Monitor's list do. So it must still return the chain. If it did not, Open in
	 * Chain Monitor would be hidden in exactly the orgs with many users that the console is built for.
	 *
	 * Catches: a later change that makes findByCorrelationIds keep sharing. That would hide the way into the Chain
	 * Monitor for chains the viewer does not own.
	 *
	 * @see SEL_AsyncChainExecution.findByCorrelationIds
	 */
	@IsTest
	private static void shouldFindRunsByCorrelationIdsRegardlessOfSharing()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		String foreignCorrelationId = UTIL_Random.randomUUID();

		Id seededExecutionId = seedForeignOwnedChain(foreignCorrelationId);

		System.runAs(lowPrivilegeUser)
		{
			List<AsyncChainExecution__c> found = new SEL_AsyncChainExecution().findByCorrelationIds(new Set<String> {foreignCorrelationId});

			Assert.areEqual(1, found.size(),
					'A registered chain owned by another user is still found, so Open in Chain Monitor is offered consistently '
					+ 'with how the console reads logs and how the monitor lists chains org-wide');
			Assert.areEqual(seededExecutionId, found[0].Id, 'The found chain is the one carrying the correlation id');
			Assert.isTrue(new SEL_AsyncChainExecution().findByCorrelationIds(new Set<String> {UTIL_Random.randomUUID()}).isEmpty(),
					'An unknown correlation finds no chain');
		}
	}

	/**
	 * @description Runs as a low-privilege user. Proves that findByCorrelationIdForMonitoring finds a chain the user
	 * neither owns nor has shared with them. The Log Console decides to offer Open in Chain Monitor through
	 * findByCorrelationIds, which ignores sharing. So when the Chain Monitor opens from that link, its read must see
	 * the same record. A read that kept sharing would open the monitor on its default selection instead, with no
	 * warning, for every user who does not own the chain and has no View All access.
	 *
	 * Catches: a later change that makes findByCorrelationIdForMonitoring keep sharing. That would break Open in Chain
	 * Monitor in exactly the orgs with many users that the console is built for.
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

			Assert.isNotNull(resolved, 'A chain owned by another user must be found for the Open in Chain Monitor link');
			Assert.areEqual(seededExecutionId, resolved.Id, 'The resolved chain must be the one carrying the correlation id');
			Assert.isNull(new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring(UTIL_Random.randomUUID()),
					'An unknown correlation resolves to null');
			Assert.isNull(new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring('   '),
					'A blank correlation resolves to null without querying');
		}
	}

	/**
	 * @description Tests that the selector reads a run's launched-under id and root correlation id, so every reader of
	 * the run record sees which action it belongs to and what it was launched under.
	 *
	 * @see SEL_AsyncChainExecution.getFields
	 */
	@IsTest
	private static void shouldReadTheLaunchAndRootIdsOfARun()
	{
		String launchCorrelationId = UTIL_Random.randomUUID();
		String rootCorrelationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c seeded = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TRACKED_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.LaunchCorrelationId__c => launchCorrelationId,
				AsyncChainExecution__c.RootCorrelationId__c => rootCorrelationId
		});

		Test.startTest();
		AsyncChainExecution__c read = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(seeded.Id);
		AsyncChainExecution__c restartRead = new SEL_AsyncChainExecution().findByIdForRestart(seeded.Id);
		Test.stopTest();

		Assert.areEqual(launchCorrelationId, read.LaunchCorrelationId__c, 'The default read carries the launched-under id');
		Assert.areEqual(rootCorrelationId, read.RootCorrelationId__c, 'The default read carries the root correlation id');
		Assert.areEqual(rootCorrelationId, restartRead.RootCorrelationId__c, 'Expected the restart read to carry the root correlation id, which the restarted copy keeps');
	}

	/**
	 * @description Seeds a Running chain as the test admin, carrying the given correlation id.
	 * The sharing tests use it, so the low-privilege user reads a record it neither owns nor has shared with it.
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
	 * @description Saves a broken record: a Stalled record that also has an end time. It is a finished run whose status
	 * was overwritten by mistake. Records like this were saved before the package began to block them, and orgs still
	 * have them. A stand-in (mocked) record cannot be used here, because a mocked read ignores the selector's filter.
	 * So this helper turns off the blocking trigger action, saves the record, and turns the action back on.
	 *
	 * @param chainName The chain name the row carries.
	 */
	private static void insertStalledRunWithEndTime(String chainName)
	{
		String actionClassName = TST_Factory.getRunTransitionActionClassName();
		TRG_Base.bypassAction(actionClassName);
		try
		{
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, chainName,
					new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});
		}
		finally
		{
			TRG_Base.clearActionBypass(actionClassName);
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. The tests that run as another user
	 * use it to seed the AsyncChainExecution__c row before the low-privilege user reads it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. The tests that run as another user read as this user. One of them calls
	 * SEL_AsyncChainExecution.findByStatus to prove the selector switches to system mode by itself, through
	 * systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Builds the list criteria the Chain Monitor's list read takes, ordered by creation date, page one, so
	 * the filter tests differ only in the values under test.
	 *
	 * @param statuses The statuses to keep, or null for every status.
	 * @param name The chain name search text, or null.
	 * @param sortDescending True to order newest first.
	 * @param pageSize The rows per page.
	 *
	 * @return The criteria.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters,PMD.ExcessiveParameterList')
	private static SEL_AsyncChainExecution.ListCriteria listCriteria(List<String> statuses, String name, Boolean sortDescending, Integer pageSize)
	{
		SEL_AsyncChainExecution.ListCriteria criteria = new SEL_AsyncChainExecution.ListCriteria();
		criteria.statuses = statuses;
		criteria.name = name;
		criteria.sortField = AsyncChainExecution__c.CreatedDate;
		criteria.sortDescending = sortDescending;
		criteria.page = 1;
		criteria.pageSize = pageSize;
		return criteria;
	}
}