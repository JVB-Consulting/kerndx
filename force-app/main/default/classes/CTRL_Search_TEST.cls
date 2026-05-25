// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for Generic Search Controller
 *
 * @see CTRL_Search
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class CTRL_Search_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'CTRL_Search_TEST-admin';
	private static final Integer LIMIT_TO_ONE_RESULT = 1;

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
	 * @description Tests findSObjectBySearchTerm by giving it a search term and checking if a list of objects is returned
	 *
	 * @see CTRL_Search.findSObjectBySearchTerm
	 */
	@IsTest
	private static void findSObjectBySearchTermWithLimit()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c newFoobar1 = TST_Factory.insertFoobar();

			Foobar__c newFoobar2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, newFoobar1.Name + UTIL_Random.randomNumber())
					.build();

			Test.setFixedSearchResults(new List<String> {newFoobar1.Id, newFoobar2.Id});

			Test.startTest();

			Map<String, Object> params = new Map<String, Object>
			{
					CTRL_Search.PARAMETER_OBJECT_NAME => SEL_Foobar.OBJECT_NAME,
					CTRL_Search.PARAMETER_SELECT_FIELDS => getFoobarFields(),
					CTRL_Search.PARAMETER_MAXIMUM_NUMBER_OF_RESULTS => LIMIT_TO_ONE_RESULT
			};

			List<SObject> foundObjects = (List<SObject>)CTRL_Search.search(newFoobar1.Name, params);

			Test.stopTest();

			Assert.areEqual(LIMIT_TO_ONE_RESULT, foundObjects.size(), 'Incorrect number of objects found');

			Foobar__c foundFoobar = (Foobar__c)foundObjects.iterator().next();

			Assert.areEqual(newFoobar1.Id, foundFoobar.Id, 'Incorrect object found');
			Assert.isTrue(String.isNotBlank(foundFoobar.Text__c), 'Field was not retrieved');
		}
	}

	/**
	 * @description Will return the default foobar fields as a comma separated string
	 *
	 * @return The separated list of fields
	 */
	private static List<String> getFoobarFields()
	{
		return UTIL_Set.toList(UTIL_SObjectDescribe.getSObjectFieldNames(new Set<SObjectField>(new SEL_Foobar().fields)));
	}

	/**
	 * @description Tests that findById returns a record for a valid Id and a list of fields
	 */
	@IsTest
	private static void findByIdWithFieldsProvided()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c newFoobar = TST_Factory.insertFoobar();

			Test.startTest();

			Map<String, Object> params = new Map<String, Object>
			{
					CTRL_Search.PARAMETER_RECORD_ID => newFoobar.Id,
					CTRL_Search.PARAMETER_SELECT_FIELDS => getFoobarFields()
			};

			Foobar__c foundFoobar = (Foobar__c)CTRL_Search.search(UTIL_String.EMPTY, params);

			Test.stopTest();

			Assert.isNotNull(foundFoobar, 'Object not found');
			Assert.areEqual(newFoobar.Id, foundFoobar.Id, 'Incorrect object Id');
			Assert.isTrue(String.isNotBlank(foundFoobar.Text__c), 'Field was not retrieved');
		}
	}

	/**
	 * @description Tests that findById returns a record for a valid Id but without a list of fields
	 */
	@IsTest
	private static void findByIdWithNoFieldsProvided()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c newFoobar = TST_Factory.insertFoobar();

			Test.startTest();

			Map<String, Object> params = new Map<String, Object>
			{
					CTRL_Search.PARAMETER_RECORD_ID => newFoobar.Id
			};

			Foobar__c foundFoobar = (Foobar__c)CTRL_Search.search(UTIL_String.EMPTY, params);

			Test.stopTest();

			Assert.isNotNull(foundFoobar, 'Object not found');
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