// SPDX-License-Identifier: Apache-2.0
/**
 * @description Will Test the behaviour of the associated trigger action to ensure framework is operating as expected
 *
 * @see TRG_SetFoobarDefaults
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class TRG_SetFoobarDefaults_TEST
{
	/**
	 * @description Company name of the admin user created in the test setup. Each test finds that user by this name and
	 * runs as them.
	 */
	private static final String TEST_ADMIN_COMPANY = 'TRG_SetFoobarDefaults_TEST-admin';

	/**
	 * @description Name of the class that gives an entry criteria formula its "newRecord" and "oldRecord" values for
	 * Foobar__c. One test names it on the trigger action; another leaves the name blank to check that the framework picks a
	 * class for Foobar__c by itself.
	 */
	private static final String FOOBAR_CONTEXT_CLASS = UTIL_FormulaContext.FoobarContext.class.getName();

	/**
	 * @description How many records the entry criteria tests run through the trigger action. Half of them have their
	 * checkbox ticked, so the formula admits ten and holds ten back.
	 */
	private static final Integer FILTERED_RECORD_COUNT = 20;

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

	/**
	 * @description Runs the trigger action over twenty new Foobar__c records, every other one with its checkbox ticked, with
	 * an entry criteria formula that admits only the records whose checkbox is ticked. It then checks each record on its
	 * own: every ticked record carries the text the action writes, and every record left unticked keeps the text it was
	 * built with. A filter that let the wrong records through, or that changed only some of the admitted ones, fails here.
	 *
	 * @param contextClassName Name of the class the formula reads its record from, or null to let the framework choose it
	 * from the object.
	 */
	private static void assertEntryCriteriaFiltering(String contextClassName)
	{
		List<Foobar__c> originalFoobars = TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Text__c, UTIL_Random.randomUUID())
				.withCycle(Foobar__c.Checkbox__c, new List<Object> {true, false})
				.withCount(FILTERED_RECORD_COUNT)
				.withoutInsertion()
				.buildList();
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

		Assert.areEqual(FILTERED_RECORD_COUNT, actionFoobars.size(),
				'Fixture guard, so the loop below cannot pass on an empty list: expected ' + FILTERED_RECORD_COUNT + ' records, got ' + actionFoobars.size());

		for(Integer index = 0; index < actionFoobars.size(); index++)
		{
			Foobar__c originalFoobar = originalFoobars[index];
			Assert.areNotEqual(TRG_SetFoobarDefaults.DUMMY_TEXT_VALUE, originalFoobar.Text__c,
					'Expected record ' + index + ' to start without the text the action writes, got ' + originalFoobar.Text__c);

			String expectedText = originalFoobar.Checkbox__c ? TRG_SetFoobarDefaults.DUMMY_TEXT_VALUE : originalFoobar.Text__c;
			Assert.areEqual(expectedText, actionFoobars[index].Text__c,
					'Expected record ' + index + ' (checkbox ' + originalFoobar.Checkbox__c + ') to have text ' + expectedText + ', got ' + actionFoobars[index].Text__c);
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