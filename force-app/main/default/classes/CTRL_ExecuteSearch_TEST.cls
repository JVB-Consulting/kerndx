// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test Class for CTRL_ExecuteSearch
 *
 * @see CTRL_ExecuteSearch
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class CTRL_ExecuteSearch_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'CTRL_ExecuteSearch_TEST-admin';

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
	 * @description Will check that search is executed successfully
	 *
	 * @see CTRL_ExecuteSearch.executeSearchController
	 */
	@IsTest
	private static void executeSearchController()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c newFoobar = TST_Factory.insertFoobar();

			Map<String, Object> searchParameters = new Map<String, Object>
			{
					CTRL_Search.PARAMETER_RECORD_ID => newFoobar.Id,
					CTRL_Search.PARAMETER_SELECT_FIELDS => UTIL_Set.toList(UTIL_SObjectDescribe.getSObjectFieldNames(new Set<SObjectField>(new SEL_Foobar().fields)))
			};

			Test.startTest();

			Object result = CTRL_ExecuteSearch.executeSearchController(CTRL_Search.class.getName(), UTIL_String.EMPTY, searchParameters);

			Test.stopTest();

			Assert.isNotNull(result, 'Object not found');
			Assert.isInstanceOfType(result, Foobar__c.class, 'Incorrect Object Type Returned');
		}
	}

	/**
	 * @description Will check that search fails to not being provided with a controller name
	 *
	 * @see CTRL_ExecuteSearch.executeSearchController
	 */
	@IsTest
	private static void nullControllerName()
	{
		System.runAs(getTestAdmin())
		{
			assertExceptionThrown(null, IllegalArgumentException.class);
		}
	}

	/**
	 * @description Will check that call to controller fails correctly
	 *
	 * @param controllerName The name of the search controller class
	 * @param exceptionType The expected exception to be thrown
	 */
	private static void assertExceptionThrown(String controllerName, Type exceptionType)
	{
		Test.startTest();

		try
		{
			CTRL_ExecuteSearch.executeSearchController(controllerName, UTIL_String.EMPTY, null);
			Assert.fail('Expected Error to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, exceptionType, 'Incorrect exception thrown:' + error.getTypeName());
		}

		Test.stopTest();
	}

	/**
	 * @description Will check that search fails to not being provided with a controller name
	 *
	 * @see CTRL_ExecuteSearch.executeSearchController
	 */
	@IsTest
	private static void blankControllerName()
	{
		System.runAs(getTestAdmin())
		{
			assertExceptionThrown(UTIL_String.EMPTY, IllegalArgumentException.class);
		}
	}

	/**
	 * @description Will check that search fails to not being provided with a visible class name
	 *
	 * @see CTRL_ExecuteSearch.executeSearchController
	 */
	@IsTest
	private static void invalidControllerName()
	{
		System.runAs(getTestAdmin())
		{
			assertExceptionThrown(CTRL_ExecuteSearch_TEST.class.getName(), IllegalArgumentException.class);
		}
	}

	/**
	 * @description Will check that search fails to not being provided a class that supports the search interface
	 *
	 * @see CTRL_ExecuteSearch.executeSearchController
	 */
	@IsTest
	private static void interfaceNotSupported()
	{
		System.runAs(getTestAdmin())
		{
			assertExceptionThrown(CTRL_ExecuteSearch.class.getName(), TypeException.class);
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