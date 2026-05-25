// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_FormulaContext inner classes.
 * Tests ONLY that context classes correctly cast and assign old/new records.
 * Formula evaluation is tested separately in UTIL_FormulaFilter_TEST.
 *
 * Uses in-memory mocked records - NO DML to avoid subscriber org automation.
 *
 * @see UTIL_FormulaContext
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date January 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts')
private class UTIL_FormulaContext_TEST
{
	private static final String OLD_RECORD_KEY = 'oldRecord';
	private static final String NEW_RECORD_KEY = 'newRecord';

	/**
	 * @description Calls setContext and asserts context state matches input.
	 * If input is null, expects null in context; if input is not null, expects not null.
	 *
	 * @param context The context to test
	 * @param scenario Description for assert messages
	 * @param oldRecord The old record to set (null for insert)
	 * @param newRecord The new record to set (null for delete)
	 */
	private static void assertSetContext
			(
					UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext context,
					String scenario,
					SObject oldRecord,
					SObject newRecord
			)
	{
		context.setContext(oldRecord, newRecord);
		Map<String, Object> state = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(context));

		Assert.areEqual(oldRecord != null, state.get(OLD_RECORD_KEY) != null, scenario + ': old record state mismatch');
		Assert.areEqual(newRecord != null, state.get(NEW_RECORD_KEY) != null, scenario + ': new record state mismatch');
	}

	/**
	 * @description Tests all setContext scenarios for a given context class and SObjectType.
	 *
	 * @param contextType The Type of the context class to test
	 * @param objectType The SObjectType to create test records for
	 */
	private static void assertContextClassBehavior(Type contextType, SObjectType objectType)
	{
		String objectName = objectType.getDescribe().name;
		SObject oldRecord = TST_Builder.of(objectType).withoutInsertion().build();
		SObject newRecord = TST_Builder.of(objectType).withoutInsertion().build();
		UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext context =
				(UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext)contextType.newInstance();

		assertSetContext(context, objectName + ' update', oldRecord, newRecord);
		assertSetContext(context, objectName + ' insert', null, newRecord);
		assertSetContext(context, objectName + ' delete', oldRecord, null);
	}

	/**
	 * @description Tests AccountContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.AccountContext
	 */
	@IsTest
	private static void accountContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.AccountContext.class, Account.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests ContactContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.ContactContext
	 */
	@IsTest
	private static void contactContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.ContactContext.class, Contact.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests LeadContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.LeadContext
	 */
	@IsTest
	private static void leadContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.LeadContext.class, Lead.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests OpportunityContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.OpportunityContext
	 */
	@IsTest
	private static void opportunityContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.OpportunityContext.class, Opportunity.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests CaseContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.CaseContext
	 */
	@IsTest
	private static void caseContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.CaseContext.class, Case.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests CampaignContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.CampaignContext
	 */
	@IsTest
	private static void campaignContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.CampaignContext.class, Campaign.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests TaskContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.TaskContext
	 */
	@IsTest
	private static void taskContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.TaskContext.class, Task.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests EventContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.EventContext
	 */
	@IsTest
	private static void eventContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.EventContext.class, Event.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests UserContext correctly handles all setContext scenarios.
	 *
	 * @see UTIL_FormulaContext.UserContext
	 */
	@IsTest
	private static void userContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.UserContext.class, User.SObjectType);

		Test.stopTest();
	}

	/**
	 * @description Tests FoobarContext correctly handles all setContext scenarios.
	 * This enables comprehensive testing of formula evaluation with the package test object.
	 *
	 * @see UTIL_FormulaContext.FoobarContext
	 */
	@IsTest
	private static void foobarContextHandlesAllScenarios()
	{
		Test.startTest();

		assertContextClassBehavior(UTIL_FormulaContext.FoobarContext.class, Foobar__c.SObjectType);

		Test.stopTest();
	}
}