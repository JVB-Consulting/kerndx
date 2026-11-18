// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs samples from the Selectors, DML, DTOs, Async Processing and LWC guides in an org where KernDX is
 * installed with its kern namespace. Some tests run a sample as the guide used to print it and show what went wrong.
 * The other tests run the sample as the guide prints it now and check what it really does.
 *
 * Tests that save accounts first switch off the org's own validation rules on accounts, so that a rule the release
 * test org adds cannot stop the save a sample makes. The scanner asks for each of those calls to be confirmed; the
 * class annotation confirms them.
 *
 * @see CTRL_AccountCard
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.KernSecurityBypassCallSite')
@IsTest(seeAllData=false isParallel=true)
private class DocumentationSamplesGuidesA_TEST
{
	/**
	 * @description The API name of the Account object, used to switch off the org's validation rules on accounts.
	 */
	private static final String ACCOUNT_OBJECT_NAME = 'Account';

	/**
	 * @description The start of each mock account name in the Selectors guide sample.
	 */
	private static final String MOCK_ACCOUNT_PREFIX = 'Mock Account ';

	/**
	 * @description How many mock accounts the Selectors guide sample registers.
	 */
	private static final Integer NUMBER_OF_MOCK_ACCOUNTS = 5;

	/**
	 * @description The position of the mock account the Selectors guide sample asks for by its Id.
	 */
	private static final Integer REQUESTED_MOCK_POSITION = 2;

	/**
	 * @description The annual revenue step between one mock account and the next in the Selectors guide sample.
	 */
	private static final Integer REVENUE_STEP = 100000;

	/**
	 * @description The industry the samples set.
	 */
	private static final String INDUSTRY_TECHNOLOGY = 'Technology';

	/**
	 * @description A second industry, so that a condition has something to leave out.
	 */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/**
	 * @description The name the Selectors guide sample "Basic Query Mocking" gives its mock accounts.
	 */
	private static final String BASIC_MOCK_NAME = 'Mock Account 1';

	/**
	 * @description The order number in the DTOs guide sample.
	 */
	private static final String ORDER_ID = 'ORD-001';

	/**
	 * @description The order total in the DTOs guide sample.
	 */
	private static final Decimal TOTAL_AMOUNT = 250.00;

	/**
	 * @description An account name the DML guide sample can save.
	 */
	private static final String GOOD_ACCOUNT_NAME = 'Acme Corp';

	/**
	 * @description How many accounts the background job tests process.
	 */
	private static final Integer NUMBER_OF_ITEMS = 3;

	/**
	 * @description The start of the subject of the task that finish() saves; the count that finish() saw follows it.
	 */
	private static final String FINISHED_PREFIX = 'Finished after ';

	/**
	 * @description The search term the LWC guide's search controller is given.
	 */
	private static final String SEARCH_TERM = 'Acme';

	/**
	 * @description Saves one account with the name and industry given.
	 *
	 * @param name The account name.
	 * @param industry The account industry.
	 *
	 * @return The saved account.
	 */
	private static Account insertAccount(String name, String industry)
	{
		return (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, name)
				.withOverride(Account.Industry, industry)
				.build();
	}

	/**
	 * @description Builds one account in memory, not saved, with the name given.
	 *
	 * @param name The account name. A null name leaves the required Name field empty, so the account cannot be saved.
	 *
	 * @return The account, not saved.
	 */
	private static Account buildUnsavedAccount(String name)
	{
		return (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, name)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Reads the subjects of the tasks that finish() saved.
	 *
	 * @return One subject for each time finish() ran.
	 */
	private static List<String> readFinishSubjects()
	{
		List<String> subjects = new List<String>();

		for(Task each : (List<Task>)new SEL_Tasks().query.condition(Task.Subject).startsWith(FINISHED_PREFIX).toList())
		{
			subjects.add(each.Subject);
		}

		return subjects;
	}

	/**
	 * @description Builds mock accounts, not saved, one for each industry given, named after the industry.
	 *
	 * @param industries The industries, one for each mock account.
	 *
	 * @return The mock accounts, with mock Ids.
	 */
	private static List<Account> buildMockAccounts(List<String> industries)
	{
		List<Account> mockAccounts = new List<Account>();

		for(String industry : industries)
		{
			mockAccounts.add
					(
							(Account)kern.TST_Builder.of(Account.SObjectType)
									.withOverride(Account.Name, MOCK_ACCOUNT_PREFIX + industry)
									.withOverride(Account.Industry, industry)
									.withoutInsertion(true)
									.build()
					);
		}

		return mockAccounts;
	}

	/**
	 * @description The Selectors guide sample "Basic Query Mocking": two mock accounts in the Technology industry, read
	 * with a condition on the Technology industry. The mock checks the condition on the picklist field, and both accounts
	 * match, so both come back, as the guide says.
	 */
	@IsTest
	private static void selectorsBasicQueryMockingReturnsBothRecordsOfTheIndustry()
	{
		List<Account> mockAccounts = (List<Account>)kern.TST_Builder.of(Account.SObjectType)
				.withCount(2)
				.withOverride(Account.Name, BASIC_MOCK_NAME)
				.withOverride(Account.Industry, INDUSTRY_TECHNOLOGY)
				.withoutInsertion(true)
				.buildList();

		kern.QRY_Builder.setMock(Account.SObjectType, mockAccounts);

		Test.startTest();
		List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Industry).equals(INDUSTRY_TECHNOLOGY)
				.toList();
		Test.stopTest();

		kern.QRY_Builder.clearMocks();

		Assert.areEqual(2, results.size(), 'Expected both mocked records, because both are in the industry asked for; the mock industries were: '
				+ mockAccounts[0].Industry + ', ' + mockAccounts[1].Industry);
	}

	/**
	 * @description On a standard object a mock checks a condition on a text field in memory, checks a condition on a
	 * picklist field such as Industry too, and applies the row limit.
	 */
	@IsTest
	private static void selectorsMockChecksSomeConditionsOnAStandardObject()
	{
		kern.QRY_Builder.setMock(Account.SObjectType, buildMockAccounts(new List<String> {INDUSTRY_TECHNOLOGY, INDUSTRY_FINANCE, INDUSTRY_TECHNOLOGY}));

		Test.startTest();
		List<Account> byName = kern.QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Name).equals(MOCK_ACCOUNT_PREFIX + INDUSTRY_FINANCE).toList();
		List<Account> limited = kern.QRY_Builder.selectFrom(Account.SObjectType).withLimit(1).toList();
		List<Account> byIndustry = kern.QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Industry).equals(INDUSTRY_FINANCE).toList();
		List<Account> sorted = kern.QRY_Builder.selectFrom(Account.SObjectType).orderBy(Account.Name).ascending().toList();
		Test.stopTest();

		kern.QRY_Builder.clearMocks();

		Assert.areEqual(1, byName.size(), 'Expected only the mock account with that name');
		Assert.areEqual(1, limited.size(), 'Expected the row limit to apply to the mock records');
		Assert.areEqual(1, byIndustry.size(), 'Expected only the mock account in the Finance industry, got ' + byIndustry);
		Assert.areEqual(MOCK_ACCOUNT_PREFIX + INDUSTRY_FINANCE, sorted[0].Name, 'Expected the mock to sort by name; the order was: '
				+ sorted[0].Name + ', ' + sorted[1].Name + ', ' + sorted[2].Name);
	}

	/**
	 * @description The Selectors guide sample "Creating Mock Records" asks for the third mock account by its Id. On a
	 * standard object the mock checks that condition, so getFirst() returns the account asked for. The guide used to
	 * expect the first account instead.
	 */
	@IsTest
	private static void selectorsMockRecordsReturnTheRequestedRecord()
	{
		List<Account> mockAccounts = new List<Account>();

		for(Integer index = 0; index < NUMBER_OF_MOCK_ACCOUNTS; index++)
		{
			Account mockAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
					.withOverrides(new Map<SObjectField, Object>
					{
							Account.Name => MOCK_ACCOUNT_PREFIX + index,
							Account.Industry => INDUSTRY_TECHNOLOGY,
							Account.AnnualRevenue => REVENUE_STEP * index
					})
					.withoutInsertion(true)
					.build();
			mockAccounts.add(mockAccount);
		}

		kern.QRY_Builder.setMock(Account.SObjectType, mockAccounts);

		Test.startTest();
		Account result = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry, Account.AnnualRevenue})
				.condition(Account.Id).equals(mockAccounts[REQUESTED_MOCK_POSITION].Id)
				.getFirst();
		Test.stopTest();

		kern.QRY_Builder.clearMocks();

		Assert.isNotNull(result, 'Expected the mock to return a record');
		Assert.areEqual(MOCK_ACCOUNT_PREFIX + REQUESTED_MOCK_POSITION, result.Name, 'Expected the mock account asked for by its Id');
	}

	/**
	 * @description The DTOs guide Quick Start used to print a public DTO with no getObjectType() override. That form
	 * reads the JSON back only because this org registers a Type Resolver; without one the package cannot find the
	 * class by its name.
	 */
	@IsTest
	private static void dtoQuickStartWithoutOverrideReadsBackOnlyWithTheRegisteredResolver()
	{
		DTO_OrderSummaryWithoutOverride summary = new DTO_OrderSummaryWithoutOverride();
		summary.orderId = ORDER_ID;
		summary.totalAmount = TOTAL_AMOUNT;

		Test.startTest();
		DTO_OrderSummaryWithoutOverride parsed = (DTO_OrderSummaryWithoutOverride)new DTO_OrderSummaryWithoutOverride().deserialize(summary.serialize());
		Test.stopTest();

		Assert.areEqual(ORDER_ID, parsed.orderId, 'Expected the registered Type Resolver to find the class');
	}

	/**
	 * @description The DTOs guide Quick Start, with the getObjectType() override it prints now, turns the order summary
	 * into JSON and reads it back with the same values.
	 */
	@IsTest
	private static void dtoQuickStartWithOverrideReadsBack()
	{
		Test.startTest();
		DTO_OrderSummary summary = new DTO_OrderSummary();
		summary.orderId = ORDER_ID;
		summary.totalAmount = TOTAL_AMOUNT;
		String serialized = summary.serialize();

		DTO_OrderSummary parsed = (DTO_OrderSummary)new DTO_OrderSummary().deserialize(serialized);
		Test.stopTest();

		Assert.areEqual(ORDER_ID, parsed.orderId, 'Expected the order number to come back from the JSON');
		Assert.areEqual(TOTAL_AMOUNT, parsed.totalAmount, 'Expected the total to come back from the JSON');
	}

	/**
	 * @description The DML guide sample "Handle DML Errors Properly", as it prints now, keeps the result of a partial
	 * save and finds the refused row through isSuccess() and getErrors(), while the good row is saved.
	 */
	@IsTest
	private static void dmlHandleErrorsFindsTheRefusedRow()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		List<Account> accounts = new List<Account> {buildUnsavedAccount(GOOD_ACCOUNT_NAME), buildUnsavedAccount(null)};
		List<String> handledMessages = new List<String>();

		Test.startTest();
		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(accounts)
				.allowPartial()
				.execute();

		if(!result.isSuccess())
		{
			for(Database.Error error : result.getErrors())
			{
				handledMessages.add(error.getMessage());
			}
		}
		Test.stopTest();

		Assert.isFalse(result.isSuccess(), 'Expected isSuccess() to be false when one row is refused');
		Assert.areEqual(1, handledMessages.size(), 'Expected getErrors() to hold the one refused row');
		Assert.areEqual(1, result.getSuccessCount(), 'Expected the good row to be saved');
	}

	/**
	 * @description The Async Processing guide's IF_Async.Finishable sample counts records in a field during execute()
	 * and reports the count in finish(). Under the BATCH strategy finish() runs once and sees the count that execute()
	 * built.
	 */
	@IsTest
	private static void asyncFinishableUnderBatchSeesTheWholeCount()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);
		List<Account> accounts = kern.TST_Builder.of(Account.SObjectType).withCount(NUMBER_OF_ITEMS).buildList();

		kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(accounts)
				.withExecutionStrategy(kern.IF_Async.AsynchronousExecutionStrategy.BATCH);

		Test.startTest();
		kern.UTIL_AsynchronousJobLauncher.process(request, new CountingProcessor());
		Test.stopTest();

		Assert.areEqual(new List<String> {FINISHED_PREFIX + NUMBER_OF_ITEMS}, readFinishSubjects(), 'Expected finish() to run once and to see every record counted');
	}

	/**
	 * @description A request that forces the PARALLEL_QUEUEABLES strategy for a Finishable processor is refused, because
	 * each parallel job would call finish(). process() throws an IllegalArgumentException, and finish() never runs.
	 */
	@IsTest
	private static void asyncFinishableUnderParallelQueueablesIsRefused()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);
		List<Account> accounts = kern.TST_Builder.of(Account.SObjectType).withCount(NUMBER_OF_ITEMS).buildList();

		kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(accounts)
				.withExecutionStrategy(kern.IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES)
				.withQueueableJobSize(1);

		Test.startTest();
		try
		{
			kern.UTIL_AsynchronousJobLauncher.process(request, new CountingProcessor());
			Assert.fail('Expected a Finishable processor forced to PARALLEL_QUEUEABLES to be refused');
		}
		catch(IllegalArgumentException refused)
		{
			Assert.areEqual(System.Label.kern.AsyncProcessor_ParallelRefusedForFinishable, refused.getMessage(), 'Expected the refusal message');
		}
		Test.stopTest();

		Assert.isTrue(readFinishSubjects().isEmpty(), 'Expected no job to run, so finish() never ran');
	}

	/**
	 * @description The Async Processing guide's LoadDataStep, as it prints now, compiles against the global API of the
	 * installed package and against a selector of the reader's own named SEL_Accounts. The test only creates the step;
	 * it does not run it.
	 */
	@IsTest
	private static void asyncLoadDataStepCompilesAgainstTheGlobalApi()
	{
		Test.startTest();
		kern.UTIL_AsyncChain.ChainStep step = new LoadDataStep();
		Test.stopTest();

		Assert.isInstanceOfType(step, LoadDataStep.class, 'Expected the step to compile and be created');
	}

	/**
	 * @description The LWC guide's search controller, as it prints now, compiles and returns a list.
	 */
	@IsTest
	private static void lwcSearchControllerReturnsAList()
	{
		Test.startTest();
		Object results = new MySearchController().search(SEARCH_TERM, new Map<String, Object>());
		Test.stopTest();

		Assert.isInstanceOfType(results, List<Object>.class, 'Expected the search to return a list');
	}

	/**
	 * @description The LWC Fast Start controller, as it prints now, reads the Account through its selector with Name and
	 * Industry filled in.
	 */
	@IsTest
	private static void lwcAccountCardLoadsTheAccountThroughItsSelector()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);
		Account account = insertAccount(GOOD_ACCOUNT_NAME, INDUSTRY_TECHNOLOGY);

		Test.startTest();
		Account result = CTRL_AccountCard.getAccount(account.Id);
		Test.stopTest();

		Assert.areEqual(GOOD_ACCOUNT_NAME, result.Name, 'Expected the requested Account');
		Assert.areEqual(INDUSTRY_TECHNOLOGY, result.Industry, 'Expected Industry to be filled in');
	}

	/**
	 * @description The LWC Fast Start controller returns null when no Account has the Id, as the page says.
	 */
	@IsTest
	private static void lwcAccountCardReturnsNullForAnUnknownId()
	{
		Account notSaved = (Account)kern.TST_Builder.of(Account.SObjectType).withoutInsertion(true).build();

		Test.startTest();
		Account result = CTRL_AccountCard.getAccount(notSaved.Id);
		Test.stopTest();

		Assert.isNull(result, 'Expected null when no Account has that Id');
	}

	/**
	 * @description The order summary as the DTOs guide Quick Start used to print it: public, with no getObjectType()
	 * override.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public inherited sharing class DTO_OrderSummaryWithoutOverride extends kern.DTO_JsonBase
	{
		/**
		 * @description The order number.
		 */
		@AuraEnabled public String orderId;

		/**
		 * @description The order total.
		 */
		@AuraEnabled public Decimal totalAmount;
	}

	/**
	 * @description The order summary as the DTOs guide Quick Start prints it now, with the getObjectType() override.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public inherited sharing class DTO_OrderSummary extends kern.DTO_JsonBase
	{
		/**
		 * @description The order number.
		 */
		@AuraEnabled public String orderId;

		/**
		 * @description The order total.
		 */
		@AuraEnabled public Decimal totalAmount;

		/**
		 * @description Tells the package which class to build when it reads JSON.
		 *
		 * @return The type of this class.
		 */
		public override Type getObjectType()
		{
			return DTO_OrderSummary.class;
		}
	}

	/**
	 * @description The shape of the Async Processing guide's IF_Async.Finishable sample: it counts the records in a
	 * field during execute(), and finish() saves a task whose subject holds the count it sees.
	 */
	private with sharing class CountingProcessor implements kern.IF_Async.Processable, kern.IF_Async.Finishable
	{
		/**
		 * @description How many records execute() has counted.
		 */
		private Integer totalProcessed = 0;

		/**
		 * @description Counts the records of one chunk.
		 *
		 * @param items The records of the chunk.
		 */
		public void execute(List<Object> items)
		{
			totalProcessed += items.size();
		}

		/**
		 * @description Saves a task whose subject holds the count finish() sees.
		 *
		 * @param context The job the platform ran.
		 */
		public void finish(Database.BatchableContext context)
		{
			kern.TST_Builder.of(Task.SObjectType).withOverride(Task.Subject, FINISHED_PREFIX + totalProcessed).build();
		}
	}

	/**
	 * @description The first chain step of the Async Processing guide, as it prints now.
	 */
	public with sharing class LoadDataStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Reads the accounts and puts their count and Ids in the chain's shared data.
		 *
		 * @param context The chain's shared data.
		 *
		 * @return A result that says the step succeeded.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			List<Account> accounts = new SEL_Accounts().toList();
			context.put('accountCount', accounts.size());
			context.put('accountIds', new Map<Id, Account>(accounts).keySet());
			return kern.UTIL_AsyncChain.succeeded('Loaded ' + accounts.size() + ' accounts');
		}
	}

	/**
	 * @description The search controller of the LWC guide, as it prints now.
	 */
	public with sharing class MySearchController implements kern.IF_Search
	{
		/**
		 * @description Returns what the search finds.
		 *
		 * @param searchTerm The text to search for.
		 * @param searchParameters Extra search parameters.
		 *
		 * @return The results.
		 */
		public Object search(Object searchTerm, Map<String, Object> searchParameters)
		{
			List<Object> results = new List<Object>();
			// Add what your search finds to results
			return results;
		}
	}

	/**
	 * @description A selector of the reader's own for Accounts, as the guides assume.
	 */
	private with sharing class SEL_Accounts extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for Accounts.
		 */
		public SEL_Accounts()
		{
			super(Account.SObjectType);
		}

		/**
		 * @description The fields every read returns.
		 *
		 * @return Name and industry.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField> {Account.Name, Account.Industry};
		}
	}

	/**
	 * @description A selector for the tasks that finish() saves.
	 */
	private with sharing class SEL_Tasks extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for tasks.
		 */
		public SEL_Tasks()
		{
			super(Task.SObjectType);
		}

		/**
		 * @description The fields every read returns.
		 *
		 * @return The subject.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField> {Task.Subject};
		}
	}
}
