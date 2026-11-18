// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs every code sample on the "From Plain Apex to KernDX" page in an org where KernDX is installed with
 * its kern namespace. Each test runs the page's sample as written and checks what it really returns, so the page can
 * only say what the package does.
 *
 * The tests check what count() returns, how a grouped total is read back by its name, and what a read returns when
 * no fields are chosen.
 *
 * The class does not run in parallel with other tests: the logging test delivers a platform event and reads the saved
 * log row, and log rows saved by other tests at the same time would get in the way.
 *
 * @see EnrichTechnologyAccountsStep
 * @see TRG_SetAccountDefaults
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date October 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.KernSecurityBypassCallSite')
@IsTest(seeAllData=false isParallel=false)
private class DocumentationSamples_TEST
{
	/**
	 * @description The API name of the Account object, used to switch off the org's validation rules on accounts in
	 * these tests.
	 */
	private static final String ACCOUNT_OBJECT_NAME = 'Account';

	/**
	 * @description The API name of the Contact object, used to switch off the org's validation rules on contacts in
	 * these tests.
	 */
	private static final String CONTACT_OBJECT_NAME = 'Contact';

	/**
	 * @description The industry the samples filter on.
	 */
	private static final String INDUSTRY_TECHNOLOGY = 'Technology';

	/**
	 * @description A second industry, so that a filter or a grouping has something to leave out.
	 */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/**
	 * @description The revenue limit in the WHERE sample.
	 */
	private static final Decimal REVENUE_LIMIT = 1000000;

	/**
	 * @description A yearly revenue above the limit.
	 */
	private static final Decimal HIGH_REVENUE = 2000000;

	/**
	 * @description A yearly revenue below the limit.
	 */
	private static final Decimal LOW_REVENUE = 500000;

	/**
	 * @description How many Technology accounts have a revenue above the limit.
	 */
	private static final Integer TECHNOLOGY_HIGH_REVENUE_COUNT = 2;

	/**
	 * @description How many Technology accounts have a revenue below the limit.
	 */
	private static final Integer TECHNOLOGY_LOW_REVENUE_COUNT = 1;

	/**
	 * @description How many Finance accounts there are. All of them have a revenue above the limit.
	 */
	private static final Integer FINANCE_COUNT = 2;

	/**
	 * @description The name of the alias the SUM sample reads the total back by.
	 */
	private static final String ALIAS_REVENUE = 'revenue';

	/**
	 * @description The name of the grouped field, which is also the name the grouped value is read back by.
	 */
	private static final String GROUPED_FIELD_NAME = 'Industry';

	/**
	 * @description The name of the background job in the sample.
	 */
	private static final String CHAIN_NAME = 'EnrichAccounts';

	/**
	 * @description The note EnrichTechnologyAccountsStep writes into each Technology account.
	 */
	private static final String ENRICHED_NOTE = 'Enriched in the background';

	/**
	 * @description The status a background job has when all its steps have run.
	 */
	private static final String STATUS_COMPLETED = 'Completed';

	/**
	 * @description The key of the status value in the map that kern.UTIL_AsyncChain.getStatus returns.
	 */
	private static final String STATUS_KEY = 'status';

	/**
	 * @description The message the logging sample writes.
	 */
	private static final String LOG_MESSAGE = 'Payment processed';

	/**
	 * @description The class and method name the logging sample passes to emitAt.
	 */
	private static final String LOG_LOCATION = 'SVC.charge';

	/**
	 * @description The log level of an info message.
	 */
	private static final String LOG_LEVEL_INFO = 'INFO';

	/**
	 * @description The description that TRG_SetAccountDefaults writes when a new account has none.
	 */
	private static final String DEFAULT_DESCRIPTION = 'Default';

	/**
	 * @description The account name the test data sample sets.
	 */
	private static final String ACCOUNT_NAME = 'Acme';

	/**
	 * @description The named credential the callout sample calls.
	 */
	private static final String SERVICE_NAME = 'OrderService';

	/**
	 * @description The path the callout sample calls.
	 */
	private static final String SERVICE_PATH = '/orders/42';

	/**
	 * @description How many times the callout sample retries a failed call.
	 */
	private static final Integer RETRY_COUNT = 3;

	/**
	 * @description The body of the pretend answer to the callout.
	 */
	private static final String RESPONSE_BODY = '{"id":42,"status":"Shipped"}';

	/**
	 * @description The HTTP status of a successful answer.
	 */
	private static final Integer HTTP_OK = 200;

	/**
	 * @description Saves the accounts the reading samples run against: two Technology accounts above the revenue limit,
	 * one Technology account below it, and two Finance accounts above it.
	 */
	private static void insertAccounts()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		insertAccounts(INDUSTRY_TECHNOLOGY, HIGH_REVENUE, TECHNOLOGY_HIGH_REVENUE_COUNT);
		insertAccounts(INDUSTRY_TECHNOLOGY, LOW_REVENUE, TECHNOLOGY_LOW_REVENUE_COUNT);
		insertAccounts(INDUSTRY_FINANCE, HIGH_REVENUE, FINANCE_COUNT);
	}

	/**
	 * @description Saves a number of accounts with the same industry and revenue.
	 *
	 * @param industry The industry of each account.
	 * @param revenue The yearly revenue of each account.
	 * @param numberOfAccounts How many accounts to save.
	 */
	private static void insertAccounts(String industry, Decimal revenue, Integer numberOfAccounts)
	{
		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, industry)
				.withOverride(Account.AnnualRevenue, revenue)
				.withCount(numberOfAccounts)
				.buildList();
	}

	/**
	 * @description The SELECT sample returns every account, with the fields it chose filled in.
	 */
	@IsTest
	private static void selectWithFieldsReturnsChosenFields()
	{
		insertAccounts();

		Test.startTest();
		List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry, Account.Phone})
				.toList();
		Test.stopTest();

		Assert.areEqual
				(
						TECHNOLOGY_HIGH_REVENUE_COUNT + TECHNOLOGY_LOW_REVENUE_COUNT + FINANCE_COUNT,
						accounts.size(),
						'Expected the SELECT sample to return every account'
				);
		Assert.isNotNull(accounts[0].Name, 'Expected the chosen Name field to be filled in');
		Assert.isNotNull(accounts[0].Industry, 'Expected the chosen Industry field to be filled in');
	}

	/**
	 * @description The WHERE sample returns only the Technology accounts above the revenue limit.
	 */
	@IsTest
	private static void whereFiltersRecords()
	{
		insertAccounts();

		Test.startTest();
		List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Industry).equals(INDUSTRY_TECHNOLOGY)
				.andCondition(Account.AnnualRevenue).greaterThan(REVENUE_LIMIT)
				.toList();
		Test.stopTest();

		Assert.areEqual
				(
						TECHNOLOGY_HIGH_REVENUE_COUNT,
						accounts.size(),
						'Expected only the Technology accounts above the revenue limit'
				);
	}

	/**
	 * @description The COUNT sample returns how many accounts match, as an Integer.
	 */
	@IsTest
	private static void countReturnsMatchingRecordTotal()
	{
		insertAccounts();

		Test.startTest();
		Integer total = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Industry).equals(INDUSTRY_TECHNOLOGY)
				.count();
		Test.stopTest();

		Assert.areEqual
				(
						TECHNOLOGY_HIGH_REVENUE_COUNT + TECHNOLOGY_LOW_REVENUE_COUNT,
						total,
						'Expected count() to return the number of Technology accounts'
				);
	}

	/**
	 * @description The SUM and GROUP BY sample returns one row per industry. The grouped value is read back by the
	 * field name, and the total by the alias the sample gave it.
	 */
	@IsTest
	private static void sumAndGroupByReadBackByAlias()
	{
		insertAccounts();

		Test.startTest();
		List<kern.QRY_Builder.AggregateRow> rows = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.sum(Account.AnnualRevenue, ALIAS_REVENUE)
				.groupBy(Account.Industry)
				.toAggregateList();
		Test.stopTest();

		Map<String, Decimal> revenueByIndustry = new Map<String, Decimal>();

		for(kern.QRY_Builder.AggregateRow row : rows)
		{
			String industry = row.getString(GROUPED_FIELD_NAME);
			Decimal revenue = row.getDecimal(ALIAS_REVENUE);
			revenueByIndustry.put(industry, revenue);
		}

		Assert.areEqual(2, rows.size(), 'Expected one row for each of the two industries');
		Assert.areEqual
				(
						HIGH_REVENUE * TECHNOLOGY_HIGH_REVENUE_COUNT + LOW_REVENUE * TECHNOLOGY_LOW_REVENUE_COUNT,
						revenueByIndustry.get(INDUSTRY_TECHNOLOGY),
						'Expected the Technology total to be read back by the alias'
				);
		Assert.areEqual
				(
						HIGH_REVENUE * FINANCE_COUNT,
						revenueByIndustry.get(INDUSTRY_FINANCE),
						'Expected the Finance total to be read back by the alias'
				);
	}

	/**
	 * @description A read that chooses no fields still runs. This test records which fields such a read fills in.
	 */
	@IsTest
	private static void noFieldsChosenReturnsDefaultBehaviour()
	{
		insertAccounts();

		Test.startTest();
		List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType).toList();
		Test.stopTest();

		Set<String> filledFields = accounts[0].getPopulatedFieldsAsMap().keySet();

		Assert.areEqual
				(
						TECHNOLOGY_HIGH_REVENUE_COUNT + TECHNOLOGY_LOW_REVENUE_COUNT + FINANCE_COUNT,
						accounts.size(),
						'Expected a read with no fields chosen to return every account'
				);
		Assert.areEqual
				(
						new Set<String> {'Id'},
						filledFields,
						'Expected a read with no fields chosen to fill in only the Id; it filled in ' + filledFields
				);
	}

	/**
	 * @description The DML sample saves the account and gives it an Id.
	 */
	@IsTest
	private static void insertThroughTransactionSaves()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, ACCOUNT_NAME)
				.withoutInsertion()
				.build();

		Test.startTest();
		kern.DML_Builder.newTransaction()
				.doInsert(account)
				.execute();
		Test.stopTest();

		Assert.isNotNull(account.Id, 'Expected the saved account to have an Id');
	}

	/**
	 * @description The unit of work sample saves a parent and a child together, and links the child to the parent's new
	 * Id.
	 */
	@IsTest
	private static void transactionSavesParentAndChildTogether()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);
		kern.UTIL_ValidationRule.bypassObject(CONTACT_OBJECT_NAME);

		Account newAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, ACCOUNT_NAME)
				.withoutInsertion()
				.build();
		Contact newContact = (Contact)kern.TST_Builder.of(Contact.SObjectType).withoutInsertion().build();

		Test.startTest();
		kern.DML_Builder.newTransaction()
				.doInsert(newAccount)
				.doInsert(newContact, Contact.AccountId, newAccount)
				.execute();
		Test.stopTest();

		Assert.isNotNull(newAccount.Id, 'Expected the parent account to be saved');
		Assert.isNotNull(newContact.Id, 'Expected the child contact to be saved');
		Assert.areEqual(newAccount.Id, newContact.AccountId, 'Expected the contact to point at the new account');
	}

	/**
	 * @description The logging sample saves an info log row that names the account and the place it was written from.
	 */
	@IsTest
	private static void logBuilderSavesInfoEntry()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);
		Id accountId = kern.TST_Builder.of(Account.SObjectType).build().Id;
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		kern.LOG_Builder.build()
				.info(LOG_MESSAGE)
				.forRecord(accountId)
				.emitAt(LOG_LOCATION);
		Test.getEventBus().deliver();
		Test.stopTest();

		List<kern__LogEntry__c> entries = kern.QRY_Builder.selectFrom(kern__LogEntry__c.SObjectType)
				.fields(new List<SObjectField> {kern__LogEntry__c.kern__Message__c, kern__LogEntry__c.kern__LogLevel__c})
				.condition(kern__LogEntry__c.kern__RecordId__c).equals(String.valueOf(accountId))
				.toList();

		Assert.areEqual(1, entries.size(), 'Expected one log row for the account');
		Assert.areEqual(LOG_MESSAGE, entries[0].kern__Message__c, 'Expected the log row to keep the message');
		Assert.areEqual(LOG_LEVEL_INFO, entries[0].kern__LogLevel__c, 'Expected the log row to be at info level');
	}

	/**
	 * @description The background job sample runs its step, which writes the note on the Technology accounts.
	 */
	@IsTest
	private static void chainWithStepRunsInOrder()
	{
		insertAccounts();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new EnrichTechnologyAccountsStep())
				.execute();
		Test.stopTest();

		Map<String, Object> status = kern.UTIL_AsyncChain.getStatus(executionId);

		Assert.areEqual
				(
						STATUS_COMPLETED,
						(String)status.get(STATUS_KEY),
						'Expected the job to complete. If the status is not Completed, check that the AsyncChain feature flag is on'
								+ ' in this org. Status: ' + status
				);

		List<Account> enriched = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Description})
				.condition(Account.Industry).equals(INDUSTRY_TECHNOLOGY)
				.toList();

		for(Account account : enriched)
		{
			Assert.areEqual(ENRICHED_NOTE, account.Description, 'Expected the step to write its note');
		}

		Assert.areEqual
				(
						TECHNOLOGY_HIGH_REVENUE_COUNT + TECHNOLOGY_LOW_REVENUE_COUNT,
						enriched.size(),
						'Expected the step to have changed every Technology account'
				);
	}

	/**
	 * @description The trigger sample's action writes a default description on a new account that has none.
	 */
	@IsTest
	private static void triggerActionSetsDefaultDescription()
	{
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Description, null)
				.withoutInsertion()
				.build();

		Test.startTest();
		new TRG_SetAccountDefaults().beforeInsert(new List<SObject> {account});
		Test.stopTest();

		Assert.areEqual(DEFAULT_DESCRIPTION, account.Description, 'Expected the action to write the default description');
	}

	/**
	 * @description The callout sample sends the request to the named credential and returns the answer.
	 */
	@IsTest
	private static void httpClientGetReturnsResponse()
	{
		kern.API_MockFactory.forService(SERVICE_NAME)
				.body(RESPONSE_BODY)
				.statusCode(HTTP_OK)
				.register();

		Test.startTest();
		HttpResponse response = kern.UTIL_HttpClient.get(SERVICE_NAME, SERVICE_PATH)
				.withRetry(RETRY_COUNT)
				.send();
		Test.stopTest();

		Assert.areEqual(HTTP_OK, response.getStatusCode(), 'Expected the call to succeed');
		Assert.areEqual(RESPONSE_BODY, response.getBody(), 'Expected the answer body to come back unchanged');
	}

	/**
	 * @description The test data sample saves an account with the chosen name and fills in the other required fields.
	 */
	@IsTest
	private static void testDataBuilderSavesRecord()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		Test.startTest();
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, ACCOUNT_NAME)
				.build();
		Test.stopTest();

		Assert.isNotNull(account.Id, 'Expected the test data builder to save the account');
		Assert.areEqual(ACCOUNT_NAME, account.Name, 'Expected the account to keep the chosen name');
	}
}
