// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Will Test the behaviour of the associated trigger action to ensure framework is operating as expected
 *
 * @see TRG_DeleteApiCallDocuments
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class TRG_DeleteApiCallDocuments_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'TRG_DeleteApiCallDocuments_TEST-admin';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Checks that the content documents are deleted as expected
	 *
	 * @see TRG_DeleteApiCallDocuments.beforeDelete
	 */
	@IsTest
	private static void beforeDelete()
	{
		System.runAs(getTestAdmin())
		{
			ApiCall__c newApiCall = TST_Factory.newInboundApiCall(API_Echo.class.getName());
			DML_Builder.newTransaction().doInsert(newApiCall).execute();

			ContentVersion newVersion = TST_Factory.newContentVersion(null);
			newVersion.FirstPublishLocationId = newApiCall.Id;
			DML_Builder.newTransaction().doInsert(newVersion).execute();

			Test.startTest();

			DML_Builder.newTransaction().doDelete(newApiCall).execute();

			Test.stopTest();

			Assert.isTrue(new SEL_ContentVersion().getAll().isEmpty(), 'Content Version not deleted');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}