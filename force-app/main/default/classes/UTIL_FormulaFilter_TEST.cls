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
 * @date April 2025, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_FormulaFilter_TEST
{
	/**
	 * @description How many records the test with a formula that matches only some records starts from. It is large
	 * enough for the test to expect some records to match and some to be left out.
	 */
	private static final Integer LARGE_RECORD_COUNT = 10;

	/**
	 * @description How many new records the tests pass to the filter. The tests expect the same number back when nothing
	 * should be left out.
	 */
	private static final Integer NEW_RECORD_COUNT = 2;

	/**
	 * @description How many old records the test with no formula passes to the filter. It differs from NEW_RECORD_COUNT,
	 * so the test can tell the old list and the new list apart in the result.
	 */
	private static final Integer OLD_RECORD_COUNT = 3;

	/**
	 * @description Name of the context class for Foobar__c records. A context class holds the old and new record a
	 * formula is checked against. The tests pass this name to the filter when they filter Foobar__c records.
	 */
	private static final String CONTEXT_CLASS_NAME = UTIL_FormulaContext.FoobarContext.class.getName();

	/**
	 * @description Failure message used when a call the test expected to throw an exception finished normally.
	 */
	private static final String ERROR_EXPECTED_FAILURE = 'Expected method to throw an exception';

	/**
	 * @description Failure message used when a call threw an exception of a different type from the one the test expects.
	 */
	private static final String ERROR_INVALID_EXCEPTION = 'Invalid exception type thrown';

	/**
	 * @description Failure message used when the filter did not give back the number of records the test expects.
	 */
	private static final String ERROR_NO_RECORDS_FILTERED = 'Records were not filtered correctly';

	/**
	 * @description Failure message used when the filter gave back a different number of old records than new records,
	 * although each old record is paired with a new one.
	 */
	private static final String ERROR_RECORD_COUNT_MISMATCH = 'Number of filtered old and new records should match';

	/**
	 * @description Failure message used when the filter gave back no records although some of them match the formula.
	 */
	private static final String ERROR_SOME_RECORDS_EXPECTED = 'Some records should have been matched';

	/**
	 * @description Failure message used when the filter gave back every record although some of them do not match the
	 * formula.
	 */
	private static final String ERROR_UNEXPECTED_FILTERING = 'Some records should have been excluded';

	/**
	 * @description Failure message used when the filter gave back records although none can match the formula.
	 */
	private static final String ERROR_UNEXPECTED_RECORDS = 'No records should be matched';

	/**
	 * @description Failure message used when the filter gave back old records although the test passed in none.
	 */
	private static final String ERROR_WRONG_OLD_RECORDS = 'Old records should be empty';

	/**
	 * @description A class name that does not exist, used to prove the filter refuses a context class it cannot find.
	 */
	private static final String INVALID_CLASS_NAME = 'InvalidTypeName';

	/**
	 * @description A formula the tests expect to fail validation. It names the checkbox field on its own, without the
	 * newRecord. or oldRecord. prefix the valid formulas use.
	 */
	private static final String INVALID_FORMULA = SEL_Foobar.FIELD_CHECK_BOX + ' = TRUE';

	/**
	 * @description A valid formula that looks only at the new record and is true when its number field is above zero. The
	 * tests expect it to match every new record the test factory makes, and to match nothing when no new record is given.
	 */
	private static final String VALID_FORMULA_ALL = 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' > 0';

	/**
	 * @description A valid formula that looks at both versions of the record: the checkbox on the new record must be
	 * ticked and the number field on the old record must be above zero. The tests expect it to match some of the records
	 * the test factory makes, but not all of them.
	 */
	private static final String VALID_FORMULA_SOME = 'newRecord.' + SEL_Foobar.FIELD_CHECK_BOX + ' = TRUE && oldRecord.' + SEL_Foobar.FIELD_INTEGER + ' > 0';

	/**
	 * @description Name of the test context class that also loads data for the whole batch in its preLoad method. Only
	 * preLoad fills the values its formulas read, so a formula on it tells the test whether, how often and with what
	 * preLoad ran.
	 */
	private static final String BULK_CONTEXT_CLASS_NAME = UTIL_FormulaContext.FoobarBulkContext.class.getName();

	/**
	 * @description The fewest records a batch test passes to the filter. It is more than one, so a test can tell one
	 * preLoad call per batch from one per record.
	 */
	private static final Integer MINIMUM_BATCH_SIZE = 2;

	/**
	 * @description The number of queries the test context class runs in its preLoad method, and so the number a whole
	 * batch may use.
	 */
	private static final Integer QUERIES_PER_BATCH = 1;

	/**
	 * @description The number of queries a call may use when preLoad must not run.
	 */
	private static final Integer NO_QUERIES = 0;

	/**
	 * @description The API name of the Name field on Foobar__c. The formulas compare it with the name preLoad saw on the
	 * first record of its first list.
	 */
	private static final String FIELD_NAME = String.valueOf(Foobar__c.Name);

	/**
	 * @description The formula name of the record after the save.
	 */
	private static final String NEW_RECORD_VARIABLE = 'newRecord';

	/**
	 * @description The formula name of the record before the save.
	 */
	private static final String OLD_RECORD_VARIABLE = 'oldRecord';

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
			Assert.isInstanceOfType(error, FormulaValidationException.class, ERROR_INVALID_EXCEPTION);
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
			Assert.isInstanceOfType(error, TypeException.class, ERROR_INVALID_EXCEPTION);
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
			Assert.isInstanceOfType(error, IllegalArgumentException.class, ERROR_INVALID_EXCEPTION);
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
			Assert.isInstanceOfType(error, FormulaValidationException.class, ERROR_INVALID_EXCEPTION);
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
		Assert.isInstanceOfType(context, UTIL_FormulaContext.FoobarContext.class, 'Should be correct context type');
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
			Assert.isInstanceOfType(error, IllegalArgumentException.class, ERROR_INVALID_EXCEPTION);
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
			Assert.isInstanceOfType(error, TypeException.class, ERROR_INVALID_EXCEPTION);
		}

		Test.stopTest();
	}

	/**
	 * @description Builds a formula on the bulk test context class that is true only when preLoad ran exactly once, got a
	 * first list of the given size whose first record has the same name as the record the formula checks, and got a null
	 * second list or not, as given.
	 *
	 * @param batchSize The number of records preLoad must have found in its first list.
	 * @param recordVariable The record whose name the first record of the first list must share: newRecord or oldRecord.
	 * @param secondListWasNull True when preLoad must have been given null as its second list.
	 *
	 * @return The formula text.
	 */
	private static String buildPreLoadFormula(Integer batchSize, String recordVariable, Boolean secondListWasNull)
	{
		return 'preLoadRunCount = 1 && firstListSize = ' + batchSize + ' && firstRecordName = ' + recordVariable + '.' + FIELD_NAME
				+ ' && secondListWasNull = ' + (secondListWasNull ? 'TRUE' : 'FALSE');
	}

	/**
	 * @description Makes new Foobar__c records in memory that all share one random name, so a formula can tell which list
	 * preLoad got first.
	 *
	 * @param numberOfRecords How many records to make.
	 *
	 * @return The records, not saved.
	 */
	private static List<Foobar__c> newFoobarsWithOneName(Integer numberOfRecords)
	{
		List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);
		String sharedName = UTIL_Random.randomUUID();

		for(Foobar__c foobar : foobars)
		{
			foobar.Name = sharedName;
		}

		return foobars;
	}

	/**
	 * @description Tests that on an update the filter calls preLoad once for the whole batch, new records first, so a
	 * formula that reads the values preLoad fills keeps every record.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void bulkContextPreLoadRunsOnceOnUpdate()
	{
		Integer batchSize = UTIL_Random.nextInteger(MINIMUM_BATCH_SIZE, LARGE_RECORD_COUNT);
		List<Foobar__c> oldRecords = newFoobarsWithOneName(batchSize);
		List<Foobar__c> newRecords = newFoobarsWithOneName(batchSize);
		String formula = buildPreLoadFormula(batchSize, NEW_RECORD_VARIABLE, false);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, BULK_CONTEXT_CLASS_NAME, formula);

		Test.startTest();

		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(oldRecords, newRecords);

		Test.stopTest();

		Assert.areEqual(batchSize, results.newRecords.size(), 'Expected every new record to pass: preLoad should run once, new records first');
		Assert.areEqual(batchSize, results.oldRecords.size(), 'Expected every old record to pass: preLoad should run once, new records first');
	}

	/**
	 * @description Tests that on an insert, when there are no old records, the filter calls preLoad once with the new
	 * records first and null second, so a formula that reads the values preLoad fills keeps every record.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void bulkContextPreLoadRunsOnceOnInsert()
	{
		Integer batchSize = UTIL_Random.nextInteger(MINIMUM_BATCH_SIZE, LARGE_RECORD_COUNT);
		List<Foobar__c> newRecords = newFoobarsWithOneName(batchSize);
		String formula = buildPreLoadFormula(batchSize, NEW_RECORD_VARIABLE, true);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, BULK_CONTEXT_CLASS_NAME, formula);

		Test.startTest();

		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(null, newRecords);

		Test.stopTest();

		Assert.areEqual(batchSize, results.newRecords.size(), 'Expected every new record to pass: preLoad should run once, with no old records');
	}

	/**
	 * @description Tests that on a delete, when there are no new records, the filter calls preLoad once with the deleted
	 * records first and null second, as validation rules do, so a formula that reads the values preLoad fills keeps every
	 * record.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void bulkContextPreLoadGetsDeletedRecordsFirstOnDelete()
	{
		Integer batchSize = UTIL_Random.nextInteger(MINIMUM_BATCH_SIZE, LARGE_RECORD_COUNT);
		List<Foobar__c> deletedRecords = newFoobarsWithOneName(batchSize);
		String formula = buildPreLoadFormula(batchSize, OLD_RECORD_VARIABLE, true);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, BULK_CONTEXT_CLASS_NAME, formula);

		Test.startTest();

		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(deletedRecords, null);

		Test.stopTest();

		Assert.areEqual(batchSize, results.oldRecords.size(), 'Expected every deleted record to pass: preLoad should get them first, null second');
	}

	/**
	 * @description Tests that the filter does not call preLoad when there are no records to check, so the call runs no
	 * query.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void bulkContextPreLoadSkippedForEmptyBatch()
	{
		String formula = buildPreLoadFormula(0, NEW_RECORD_VARIABLE, false);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, BULK_CONTEXT_CLASS_NAME, formula);

		Test.startTest();

		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(new List<Foobar__c>(), new List<Foobar__c>());
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;

		Test.stopTest();

		Assert.isTrue(results.newRecords.isEmpty(), 'Expected no records back from an empty batch');
		Assert.areEqual(NO_QUERIES, queriesUsed, 'Expected no query, because preLoad should not run when there are no records');
	}

	/**
	 * @description Tests that a batch of several records uses the queries of one preLoad call, not one per record.
	 *
	 * @see UTIL_FormulaFilter.filter
	 */
	@IsTest
	private static void bulkContextPreLoadQueriesOncePerBatch()
	{
		Integer batchSize = UTIL_Random.nextInteger(MINIMUM_BATCH_SIZE, LARGE_RECORD_COUNT);
		List<Foobar__c> oldRecords = newFoobarsWithOneName(batchSize);
		List<Foobar__c> newRecords = newFoobarsWithOneName(batchSize);
		String formula = buildPreLoadFormula(batchSize, NEW_RECORD_VARIABLE, false);
		UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, BULK_CONTEXT_CLASS_NAME, formula);

		Test.startTest();

		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(oldRecords, newRecords);
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;

		Test.stopTest();

		Assert.areEqual(batchSize, results.newRecords.size(), 'Expected every new record to pass: preLoad should run once for the batch');
		Assert.areEqual(QUERIES_PER_BATCH, queriesUsed, 'Expected the batch to use the queries of one preLoad call, not one per record');
	}
}