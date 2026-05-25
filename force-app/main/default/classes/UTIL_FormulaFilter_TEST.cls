// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behavior of the UTIL_FormulaFilter class, which filters SObject records based on a formula expression.
 *
 * @see UTIL_FormulaFilter
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date April 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_FormulaFilter_TEST
{
	private static final Integer LARGE_RECORD_COUNT = 10;
	private static final Integer NEW_RECORD_COUNT = 2;
	private static final Integer OLD_RECORD_COUNT = 3;
	private static final String CONTEXT_CLASS_NAME = UTIL_FormulaContext.FoobarContext.class.getName();
	private static final String ERROR_EXPECTED_FAILURE = 'Expected method to throw an exception';
	private static final String ERROR_INVALID_EXCEPTION = 'Invalid exception type thrown';
	private static final String ERROR_NO_RECORDS_FILTERED = 'Records were not filtered correctly';
	private static final String ERROR_RECORD_COUNT_MISMATCH = 'Number of filtered old and new records should match';
	private static final String ERROR_SOME_RECORDS_EXPECTED = 'Some records should have been matched';
	private static final String ERROR_UNEXPECTED_FILTERING = 'Some records should have been excluded';
	private static final String ERROR_UNEXPECTED_RECORDS = 'No records should be matched';
	private static final String ERROR_WRONG_OLD_RECORDS = 'Old records should be empty';
	private static final String INVALID_CLASS_NAME = 'InvalidTypeName';
	private static final String INVALID_FORMULA = SEL_Foobar.FIELD_CHECK_BOX + ' = TRUE';
	private static final String VALID_FORMULA_ALL = 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' > 0';
	private static final String VALID_FORMULA_SOME = 'newRecord.' + SEL_Foobar.FIELD_CHECK_BOX + ' = TRUE && oldRecord.' + SEL_Foobar.FIELD_INTEGER + ' > 0';

	/**
	 * @description Tests that an invalid formula throws a FormulaValidationException.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void invalidFormula()
	{
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, CONTEXT_CLASS_NAME, INVALID_FORMULA);

		Test.startTest();

		try
		{
			filter.filter(null, null);
			Assert.fail(ERROR_EXPECTED_FAILURE);
		}
		catch(Exception error)
		{
			Assert.isTrue(error instanceof FormulaValidationException, ERROR_INVALID_EXCEPTION);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that a context class that doesn't implement INT_SObjectFormulaEvaluationContext throws a TypeException.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void invalidTypeFound()
	{
		// UTIL_String exists but doesn't implement INT_SObjectFormulaEvaluationContext
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, UTIL_String.class.getName(), VALID_FORMULA_SOME);

		Test.startTest();

		try
		{
			filter.filter(null, null);
			Assert.fail(ERROR_EXPECTED_FAILURE);
		}
		catch(Exception error)
		{
			Assert.isTrue(error instanceof TypeException, ERROR_INVALID_EXCEPTION);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that records are not filtered when no context class or formula is provided.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void noContextClassOrFormula()
	{
		List<Foobar__c> oldRecords = TST_Factory.newFoobars(OLD_RECORD_COUNT);
		List<Foobar__c> newRecords = TST_Factory.newFoobars(NEW_RECORD_COUNT);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, null, null);

		Test.startTest();

		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(oldRecords, newRecords);

		Test.stopTest();

		Assert.areEqual(OLD_RECORD_COUNT, results.oldRecords.size(), ERROR_NO_RECORDS_FILTERED);
		Assert.areEqual(NEW_RECORD_COUNT, results.newRecords.size(), ERROR_NO_RECORDS_FILTERED);
	}

	/**
	 * @description Tests that an invalid context class name throws an IllegalArgumentException.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void typeNotFound()
	{
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, INVALID_CLASS_NAME, VALID_FORMULA_SOME);

		Test.startTest();

		try
		{
			filter.filter(null, null);
			Assert.fail(ERROR_EXPECTED_FAILURE);
		}
		catch(Exception error)
		{
			Assert.isTrue(error instanceof IllegalArgumentException, ERROR_INVALID_EXCEPTION);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that all records are matched with a valid formula.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void validFormulaAllMatched()
	{
		List<Foobar__c> newRecords = TST_Factory.newFoobars(NEW_RECORD_COUNT);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, CONTEXT_CLASS_NAME, VALID_FORMULA_ALL);

		Test.startTest();

		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(null, newRecords);

		Test.stopTest();

		Assert.areEqual(NEW_RECORD_COUNT, results.newRecords.size(), ERROR_NO_RECORDS_FILTERED);
		Assert.isTrue(results.oldRecords.isEmpty(), ERROR_WRONG_OLD_RECORDS);
	}

	/**
	 * @description Tests that no records are matched with a valid formula.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void validFormulaNoneMatched()
	{
		List<Foobar__c> oldRecords = TST_Factory.newFoobars(1);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, CONTEXT_CLASS_NAME, VALID_FORMULA_ALL);

		Test.startTest();

		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(oldRecords, null);

		Test.stopTest();

		Assert.isTrue(results.oldRecords.isEmpty(), ERROR_UNEXPECTED_RECORDS);
	}

	/**
	 * @description Tests that some records are matched with a valid formula.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void validFormulaSomeMatched()
	{
		List<Foobar__c> newRecords = TST_Factory.newFoobars(LARGE_RECORD_COUNT);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, CONTEXT_CLASS_NAME, VALID_FORMULA_SOME);

		Test.startTest();

		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(newRecords, newRecords);

		Test.stopTest();

		Assert.isTrue(results.newRecords.size() < LARGE_RECORD_COUNT, ERROR_UNEXPECTED_FILTERING);
		Assert.isFalse(results.newRecords.isEmpty(), ERROR_SOME_RECORDS_EXPECTED);
		Assert.areEqual(results.oldRecords.size(), results.newRecords.size(), ERROR_RECORD_COUNT_MISMATCH);
	}

	/**
	 * @description Tests that resolveContextClass auto-detects AccountContext for Account object.
	 * Uses Type.getName() for expected value to ensure proper namespace handling in managed packages.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsAccount()
	{
		String expected = UTIL_FormulaContext.AccountContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Account.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect AccountContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects ContactContext for Contact object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsContact()
	{
		String expected = UTIL_FormulaContext.ContactContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Contact.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect ContactContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects LeadContext for Lead object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsLead()
	{
		String expected = UTIL_FormulaContext.LeadContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Lead.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect LeadContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects OpportunityContext for Opportunity object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsOpportunity()
	{
		String expected = UTIL_FormulaContext.OpportunityContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Opportunity.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect OpportunityContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects CaseContext for Case object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsCase()
	{
		String expected = UTIL_FormulaContext.CaseContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Case.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect CaseContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects CampaignContext for Campaign object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsCampaign()
	{
		String expected = UTIL_FormulaContext.CampaignContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Campaign.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect CampaignContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects TaskContext for Task object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsTask()
	{
		String expected = UTIL_FormulaContext.TaskContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Task.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect TaskContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects EventContext for Event object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsEvent()
	{
		String expected = UTIL_FormulaContext.EventContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Event.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect EventContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects UserContext for User object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsUser()
	{
		String expected = UTIL_FormulaContext.UserContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(User.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect UserContext');
	}

	/**
	 * @description Tests that resolveContextClass auto-detects context class for Foobar__c test object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 * @see UTIL_FormulaContext.FoobarContext
	 */
	@IsTest
	private static void resolveContextClassAutoDetectsFoobar()
	{
		String expected = UTIL_FormulaContext.FoobarContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Foobar__c.SObjectType, null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'Should auto-detect FoobarContext');
	}

	/**
	 * @description Tests that resolveContextClass returns null for custom objects without a pre-built context class.
	 * Uses the String overload to test with a custom object API name not in the auto-detection map.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassReturnsNullForUnmappedObject()
	{
		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass('UnmappedCustomObject__c', null);

		Test.stopTest();

		Assert.isNull(result, 'Should return null for custom objects without a pre-built context class');
	}

	/**
	 * @description Tests that resolveContextClass uses explicit context class when provided, overriding auto-detection.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassUsesExplicitOverride()
	{
		String explicitClass = 'MyNamespace.CustomAccountContext';

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Account.SObjectType, explicitClass);

		Test.stopTest();

		Assert.areEqual(explicitClass, result, 'Should use explicit context class over auto-detection');
	}

	/**
	 * @description Tests that resolveContextClass handles blank string as null (triggers auto-detection).
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassHandlesBlankStringAsNull()
	{
		String expected = UTIL_FormulaContext.AccountContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass(Account.SObjectType, '   ');

		Test.stopTest();

		Assert.areEqual(expected, result, 'Blank string should trigger auto-detection');
	}

	/**
	 * @description Tests resolveContextClass with String object API name overload for Account.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassWithStringApiNameAccount()
	{
		String expected = UTIL_FormulaContext.AccountContext.class.getName();

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass('Account', null);

		Test.stopTest();

		Assert.areEqual(expected, result, 'String API name should resolve to AccountContext');
	}

	/**
	 * @description Tests resolveContextClass with String object API name overload returns null for unknown object.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassWithStringApiNameUnknown()
	{
		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass('NonExistentObject__c', null);

		Test.stopTest();

		Assert.isNull(result, 'Should return null for unknown objects');
	}

	/**
	 * @description Tests resolveContextClass with String overload uses explicit context class when provided.
	 *
	 * @see UTIL_FormulaFilter.resolveContextClass
	 */
	@IsTest
	private static void resolveContextClassWithStringApiNameExplicit()
	{
		String explicitClass = 'MyNamespace.CustomContext';

		Test.startTest();

		String result = UTIL_FormulaFilter.resolveContextClass('Account', explicitClass);

		Test.stopTest();

		Assert.areEqual(explicitClass, result, 'String overload should use explicit context class');
	}

	/**
	 * @description Tests that buildBooleanFormula creates a valid formula instance.
	 *
	 * @see UTIL_FormulaFilter.buildBooleanFormula
	 */
	@IsTest
	private static void buildBooleanFormulaCreatesValidInstance()
	{
		String formula = 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' > 0';
		Type contextType = UTIL_FormulaContext.FoobarContext.class;
		UTIL_FormulaContext.FoobarContext context = new UTIL_FormulaContext.FoobarContext();
		Foobar__c foobar = TST_Factory.newFoobars(1)[0];
		context.setContext(null, foobar);

		Test.startTest();

		FormulaEval.FormulaInstance formulaInstance = UTIL_FormulaFilter.buildBooleanFormula(formula, contextType, 'TestProcess');
		Boolean result = (Boolean)formulaInstance.evaluate(context);

		Test.stopTest();

		Assert.isTrue(result, 'Formula should evaluate to true for positive integer');
	}

	/**
	 * @description Tests that buildBooleanFormula throws exception for invalid formula.
	 *
	 * @see UTIL_FormulaFilter.buildBooleanFormula
	 */
	@IsTest
	private static void buildBooleanFormulaThrowsForInvalidFormula()
	{
		LOG_Builder.ignoreTestMode = true;
		String invalidFormula = SEL_Foobar.FIELD_CHECK_BOX + ' = TRUE';
		Type contextType = UTIL_FormulaContext.FoobarContext.class;

		Test.startTest();

		try
		{
			UTIL_FormulaFilter.buildBooleanFormula(invalidFormula, contextType, 'TestProcess');
			Assert.fail(ERROR_EXPECTED_FAILURE);
		}
		catch(Exception error)
		{
			Assert.isTrue(error instanceof FormulaValidationException, ERROR_INVALID_EXCEPTION);
			Assert.isTrue(error.getMessage().contains('TestProcess'), 'Error should contain process name');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that buildBooleanFormula handles null process name gracefully.
	 *
	 * @see UTIL_FormulaFilter.buildBooleanFormula
	 */
	@IsTest
	private static void buildBooleanFormulaHandlesNullProcessName()
	{
		LOG_Builder.ignoreTestMode = true;
		String invalidFormula = SEL_Foobar.FIELD_CHECK_BOX + ' = TRUE';
		Type contextType = UTIL_FormulaContext.FoobarContext.class;

		Test.startTest();

		try
		{
			UTIL_FormulaFilter.buildBooleanFormula(invalidFormula, contextType, null);
			Assert.fail(ERROR_EXPECTED_FAILURE);
		}
		catch(Exception error)
		{
			Assert.isTrue(error.getMessage().contains('not defined'), 'Error should contain "not defined" for null process name');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that newContextInstance creates a valid context instance.
	 *
	 * @see UTIL_FormulaFilter.newContextInstance
	 */
	@IsTest
	private static void newContextInstanceCreatesValidInstance()
	{
		Test.startTest();

		UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext context =
				UTIL_FormulaFilter.newContextInstance(CONTEXT_CLASS_NAME);

		Test.stopTest();

		Assert.isNotNull(context, 'Should create a valid context instance');
		Assert.isTrue(context instanceof UTIL_FormulaContext.FoobarContext, 'Should be correct context type');
	}

	/**
	 * @description Tests that newContextInstance throws exception for invalid class name.
	 *
	 * @see UTIL_FormulaFilter.newContextInstance
	 */
	@IsTest
	private static void newContextInstanceThrowsForInvalidClassName()
	{
		Test.startTest();

		try
		{
			UTIL_FormulaFilter.newContextInstance(INVALID_CLASS_NAME);
			Assert.fail(ERROR_EXPECTED_FAILURE);
		}
		catch(Exception error)
		{
			Assert.isTrue(error instanceof IllegalArgumentException, ERROR_INVALID_EXCEPTION);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that newContextInstance throws exception for class that doesn't implement interface.
	 *
	 * @see UTIL_FormulaFilter.newContextInstance
	 */
	@IsTest
	private static void newContextInstanceThrowsForNonImplementingClass()
	{
		Test.startTest();

		try
		{
			UTIL_FormulaFilter.newContextInstance(UTIL_String.class.getName());
			Assert.fail(ERROR_EXPECTED_FAILURE);
		}
		catch(Exception error)
		{
			Assert.isTrue(error instanceof TypeException, ERROR_INVALID_EXCEPTION);
		}

		Test.stopTest();
	}
}