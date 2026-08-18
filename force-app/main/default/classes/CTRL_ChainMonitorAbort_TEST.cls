// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Abort-capability tests for CTRL_ChainMonitor — availability-reason resolution and the
 * abortChain gate — separated from CTRL_ChainMonitor_TEST because these need @TestSetup users and
 * IsParallel=false (User DML is not permitted in parallel tests), while the read-path suite stays
 * parallel.
 *
 * @see CTRL_ChainMonitor
 * @see CTRL_ChainMonitor_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026, August 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
private class CTRL_ChainMonitorAbort_TEST
{
	private static final String GRANTEE_COMPANY = 'CTRL_ChainMonitorAbort_TEST-grantee';
	private static final String BYSTANDER_COMPANY = 'CTRL_ChainMonitorAbort_TEST-bystander';
	private static final String TEST_CHAIN = 'AbortControllerChain';

	@TestSetup
	private static void setupTestUsers()
	{
		// Package installs write the AbortAsyncChain custom permission INTO profiles: the System
		// Administrator profile on an admins-only install (the default), every profile on an all-users
		// install. Both witness users therefore live on the Standard User profile, which the default
		// install leaves grant-free, so grantee and bystander differ only by the AsyncChainAbort assignment —
		// and nothing here touches an org-level setup row: the profile grants are shared state that
		// every parallel test class can see, and deleting them collides on the row lock. The Kern
		// Administrator permission set on both users is for the post-refusal row re-reads: view-all-
		// records visibility over the privately-owned execution rows through the sharing-enforced
		// selector, not for the refusal path itself.
		User grantee = TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, GRANTEE_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		TST_Factory.createPermissionSetAssignments(new List<User> {grantee}, UTIL_AsyncChain.ABORT_PERMISSION_SET_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, BYSTANDER_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
	}

	private static User getGrantee()
	{
		return new SEL_User().findByCompanyName(GRANTEE_COMPANY);
	}

	/**
	 * @description The bystander, asserted to be one: on an all-users install the profile grant makes
	 * every user a permission holder, and a refusal test run there is not testing a bystander — it says
	 * so instead of editing the org's setup rows to manufacture one.
	 *
	 * @return The bystander user, guaranteed to lack the abort custom permission.
	 */
	private static User getBystander()
	{
		User bystander = new SEL_User().findByCompanyName(BYSTANDER_COMPANY);
		Assert.isFalse(SEL_CustomPermission.hasPackagePermission(bystander.Id, UTIL_AsyncChain.ABORT_CUSTOM_PERMISSION_NAME), 'This org grants ' + UTIL_AsyncChain.ABORT_CUSTOM_PERMISSION_NAME + ' to the Standard User profile (an all-users package install), so no bystander exists to prove the refusal against; run this suite in an org installed for admins only');
		return bystander;
	}

	/**
	 * @description Re-reads an execution row through the selector to verify committed state.
	 *
	 * @param executionId The AsyncChainExecution__c record ID.
	 *
	 * @return The re-read AsyncChainExecution__c record.
	 */
	private static AsyncChainExecution__c queryExecution(Id executionId)
	{
		return (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
	}

	/**
	 * @description Calls abortChain for the given record and asserts it refuses with an
	 * AuraHandledException. The house expect-throw shape (Assert.fail then a typed catch), shared so
	 * the four refusal tests do not each inline it.
	 *
	 * @param executionId The chain record the abort is attempted on.
	 */
	private static void assertAbortRefused(Id executionId)
	{
		try
		{
			CTRL_ChainMonitor.abortChain(executionId);
			Assert.fail('Should throw AuraHandledException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description A holder of the abort custom permission sees a Running chain as abortable,
	 * resolved through the real deployed gate records (feature flag, strategy, permission set).
	 */
	@IsTest
	private static void shouldReportAvailableForGrantee()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		System.runAs(getGrantee())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
			Test.stopTest();

			Assert.areEqual(CTRL_ChainMonitor.OPERATOR_AVAILABLE, detail.abortAvailability, 'A Running chain is abortable for a holder of the abort permission');
		}
	}

	/**
	 * @description A user without the abort custom permission sees the permission-missing reason:
	 * the flag is live with an active strategy, so only the permission separates the two users.
	 */
	@IsTest
	private static void shouldReportPermissionMissingForBystander()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		System.runAs(getBystander())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
			Test.stopTest();

			Assert.areEqual(CTRL_ChainMonitor.OPERATOR_PERMISSION_MISSING, detail.abortAvailability, 'Without the custom permission the reason is the missing permission');
		}
	}

	/**
	 * @description A finished chain reports not-abortable even for a permission holder: the status
	 * check wins over every other consideration.
	 */
	@IsTest
	private static void shouldReportChainNotAbortableForCompletedRow()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		System.runAs(getGrantee())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
			Test.stopTest();

			Assert.areEqual(CTRL_ChainMonitor.ABORT_CHAIN_NOT_ABORTABLE, detail.abortAvailability, 'A Completed chain is not abortable, permission or not');
		}
	}

	/**
	 * @description With the feature flag out of the active set the reason is the org-wide off
	 * state, even for a permission holder. Removing the cache entry models an admin deactivating
	 * the flag record.
	 */
	@IsTest
	private static void shouldReportCapabilityDisabledWhenFlagInactive()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		System.runAs(getGrantee())
		{
			SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.ABORT_FEATURE_FLAG_NAME);

			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
			Test.stopTest();

			Assert.areEqual(CTRL_ChainMonitor.OPERATOR_CAPABILITY_DISABLED, detail.abortAvailability, 'An inactive flag reads as the org-wide off state');
		}
	}

	/**
	 * @description A permission holder aborts a Running chain through the controller: the row
	 * commits as Aborted with the operator-abort category, and the returned detail reflects the
	 * terminal state without a second round trip.
	 */
	@IsTest
	private static void shouldAbortChainForGrantee()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		System.runAs(getGrantee())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ChainDetail result = CTRL_ChainMonitor.abortChain(execution.Id);
			Test.stopTest();

			AsyncChainExecution__c row = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, row.Status__c, 'The abort must commit on the row');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT, row.FailureCategory__c, 'An operator abort carries its own failure category');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.status, 'The returned detail reflects the committed abort');
			Assert.areEqual(CTRL_ChainMonitor.ABORT_CHAIN_NOT_ABORTABLE, result.abortAvailability, 'An aborted chain is no longer abortable');
		}
	}

	/**
	 * @description A user without the abort custom permission is refused with a throw and the row
	 * stays untouched: Apex is the enforcement point, the button state is only a hint.
	 */
	@IsTest
	private static void shouldRefuseAbortForBystander()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		System.runAs(getBystander())
		{
			Test.startTest();
			assertAbortRefused(execution.Id);
			Test.stopTest();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, queryExecution(execution.Id).Status__c, 'A refused abort must not touch the row');
		}
	}

	/**
	 * @description A permission holder is refused on a finished chain with a throw and the row
	 * stays untouched: the status check holds on the mutating path exactly as on the read path.
	 */
	@IsTest
	private static void shouldRefuseAbortOfCompletedChainForGrantee()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		System.runAs(getGrantee())
		{
			Test.startTest();
			assertAbortRefused(execution.Id);
			Test.stopTest();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(execution.Id).Status__c, 'A refused abort must not touch the row');
		}
	}

	/**
	 * @description A permission holder aborting a non-existent chain is refused with a throw: the
	 * monitoring read returns null, so the mutating path stops before any write. Proves the
	 * missing-row guard on the abort path, not just the read path.
	 */
	@IsTest
	private static void shouldRefuseAbortOfMissingChainForGrantee()
	{
		Id missingId = UTIL_Random.randomId(AsyncChainExecution__c.SObjectType);

		System.runAs(getGrantee())
		{
			Test.startTest();
			assertAbortRefused(missingId);
			Test.stopTest();

			Assert.isNull(queryExecution(missingId), 'No row is written for a missing chain');
		}
	}

	/**
	 * @description With the feature flag out of the active set a permission holder is refused on the
	 * mutating path with a throw and the row stays Running: the capability-disabled reason blocks the
	 * abort exactly as it blocks availability, proving Apex is the enforcement point even for a
	 * permission holder when the org-wide capability is off.
	 */
	@IsTest
	private static void shouldRefuseAbortWhenCapabilityDisabledForGrantee()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		System.runAs(getGrantee())
		{
			SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.ABORT_FEATURE_FLAG_NAME);

			Test.startTest();
			assertAbortRefused(execution.Id);
			Test.stopTest();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, queryExecution(execution.Id).Status__c, 'A capability-disabled refusal must not touch the row');
		}
	}
}