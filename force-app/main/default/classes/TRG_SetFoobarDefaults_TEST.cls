// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Will Test the behaviour of the associated trigger action to ensure framework is operating as expected
 *
 * @see TRG_SetFoobarDefaults
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class TRG_SetFoobarDefaults_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'TRG_SetFoobarDefaults_TEST-admin';
	private static final String FOOBAR_CONTEXT_CLASS = UTIL_FormulaContext.FoobarContext.class.getName();

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
	 * @description Checks that action executed as per expected
	 */
	@IsTest
	private static void successfulExecution()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c beforeInsertFoobar = TST_Factory.newFoobar();

			Test.startTest();

			DML_Builder.newTransaction().doInsert(beforeInsertFoobar).execute();

			Test.stopTest();

			List<Foobar__c> afterInsertFoobars = new SEL_Foobar().getAll();

			Assert.areEqual(1, afterInsertFoobars.size(), 'Incorrect number of Foobars inserted');
			Assert.areNotEqual(beforeInsertFoobar.Text__c, afterInsertFoobars.iterator().next().Text__c, 'Action did not update object as expected');
		}
	}

	/**
	 * @description Checks that action executed as per expected
	 */
	@IsTest
	private static void successfulExecutionWithEntryCriteria()
	{
		System.runAs(getTestAdmin())
		{
			assertEntryCriteriaFiltering(FOOBAR_CONTEXT_CLASS);
		}
	}

	/**
	 * @description Checks that trigger action entry criteria filtering works correctly
	 * using the pre-built FoobarContext class from UTIL_FormulaContext.
	 *
	 * This test validates the production context class (FoobarContext) which uses
	 * standardized property names (`newRecord`, `oldRecord`) consistent with all other
	 * pre-built context classes for standard objects.
	 *
	 * @see UTIL_FormulaContext.FoobarContext
	 */
	@IsTest
	private static void successfulExecutionWithFoobarContext()
	{
		System.runAs(getTestAdmin())
		{
			assertEntryCriteriaFiltering(FOOBAR_CONTEXT_CLASS);
		}
	}

	/**
	 * @description Tests that the trigger action framework auto-detects FoobarContext
	 * when EntryCriteriaContextClassName__c is left blank.
	 *
	 * This validates that Foobar__c is correctly mapped in STANDARD_OBJECT_CONTEXT_TYPES
	 * and the framework resolves the context class automatically based on the object type.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 * @see UTIL_FormulaContext.FoobarContext
	 */
	@IsTest
	private static void autoDetectsFoobarContextWhenContextClassBlank()
	{
		System.runAs(getTestAdmin())
		{
			assertEntryCriteriaFiltering(null);
		}
	}

	/**
	 * @description Checks that action executed as per expected
	 */
	@IsTest
	private static void noRecursion()
	{
		System.runAs(getTestAdmin())
		{
			TRG_SetFoobarDefaults.insertNewFoo = true;

			Foobar__c beforeInsertFoobar = TST_Factory.newFoobar();

			Test.startTest();

			DML_Builder.newTransaction().doInsert(beforeInsertFoobar).execute();

			Test.stopTest();

			List<Foobar__c> afterInsertFoobars = new SEL_Foobar().getAll();

			Assert.areEqual(2, afterInsertFoobars.size(), 'Incorrect number of Foobars inserted');
		}
	}

	private static void assertEntryCriteriaFiltering(String contextClassName)
	{
		List<Foobar__c> originalFoobars = TST_Factory.newFoobars(20);
		List<Foobar__c> actionFoobars = originalFoobars.deepClone(true);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(TRG_SetFoobarDefaults.class.getName(), triggerSetting, TriggerOperation.BEFORE_INSERT);
		triggerAction.EntryCriteriaContextClassName__c = contextClassName;
		triggerAction.EntryCriteriaFormula__c = 'newRecord.' + SEL_Foobar.FIELD_CHECK_BOX + ' = TRUE';

		TRG_Dispatcher factory = new TRG_Dispatcher();

		factory.triggerNew = actionFoobars;
		factory.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>> {TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}};
		factory.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		factory.run();

		Test.stopTest();

		Integer itemsAltered = 0;

		for(Foobar__c afterInsertFoobar : actionFoobars)
		{
			if(afterInsertFoobar.Text__c == TRG_SetFoobarDefaults.DUMMY_TEXT_VALUE)
			{
				itemsAltered++;
			}
		}

		Assert.areNotEqual(0, itemsAltered, 'A few records should have been processed');
		Assert.areNotEqual(originalFoobars.size(), itemsAltered, 'Some records should not have been processed due to configured entry criteria');
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