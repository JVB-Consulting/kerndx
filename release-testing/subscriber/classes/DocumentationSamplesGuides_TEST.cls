// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs the "Copy this first" sample at the top of each developer guide in an org where KernDX is installed
 * with its kern namespace. Each test runs the sample as the guide prints it and checks what it really does, so a guide
 * can only say what the package does.
 *
 * The samples of the "From Plain Apex to KernDX" page have their own test class, DocumentationSamples_TEST. This class
 * is kept apart so that neither class grows too long to read.
 *
 * The class does not run in parallel with other tests: some tests deliver a platform event and read the saved log
 * row, and log rows saved by other tests at the same time would get in the way.
 *
 * Tests that save accounts first switch off the org's own validation rules on accounts, so that a rule the release
 * test org adds cannot stop the save a sample makes. The scanner asks for each of those calls to be confirmed; the
 * class annotation confirms them.
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.KernSecurityBypassCallSite')
@IsTest(seeAllData=false isParallel=false)
private class DocumentationSamplesGuides_TEST
{
	/**
	 * @description The API name of the Account object, used to switch off the org's validation rules on accounts in
	 * these tests.
	 */
	private static final String ACCOUNT_OBJECT_NAME = 'Account';

	/**
	 * @description The industry the samples set or filter on.
	 */
	private static final String INDUSTRY_TECHNOLOGY = 'Technology';

	/**
	 * @description A second industry, so that a filter has something to leave out.
	 */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/**
	 * @description The industry the trigger sample writes when an account has none.
	 */
	private static final String INDUSTRY_OTHER = 'Other';

	/**
	 * @description The first account name in the DML sample.
	 */
	private static final String FIRST_ACCOUNT_NAME = 'Acme Corp';

	/**
	 * @description The second account name in the DML sample.
	 */
	private static final String SECOND_ACCOUNT_NAME = 'Global Industries';

	/**
	 * @description Three account names in an order that is not sorted, so that a sorted read has work to do.
	 */
	private static final List<String> UNSORTED_TECHNOLOGY_NAMES = new List<String> {'Charlie', 'Alpha', 'Bravo'};

	/**
	 * @description The name of the Name field, used by the security sample that names its fields as text.
	 */
	private static final String NAME_FIELD = 'Name';

	/**
	 * @description The name of the Industry field, used by the security sample that names its fields as text.
	 */
	private static final String INDUSTRY_FIELD = 'Industry';

	/**
	 * @description The text the background job sample puts at the start of each Description.
	 */
	private static final String PROCESSED_PREFIX = 'Processed: ';

	/**
	 * @description How many accounts the background job sample processes.
	 */
	private static final Integer NUMBER_OF_ACCOUNTS_TO_PROCESS = 3;

	/**
	 * @description The order number in the DTO sample.
	 */
	private static final String ORDER_ID = 'ORD-001';

	/**
	 * @description The order total in the DTO sample.
	 */
	private static final Decimal TOTAL_AMOUNT = 250.00;

	/**
	 * @description The log message in the data masking sample. It holds a secret under the api_key name.
	 */
	private static final String MESSAGE_WITH_SECRET = '{"user":"alice","api_key":"sk-live-9f8e7d6c5b4a"}';

	/**
	 * @description The part of the data masking message that holds no secret, which is saved as it was written.
	 */
	private static final String PLAIN_PART = '"user":"alice"';

	/**
	 * @description The part of the saved data masking message that shows the marker in place of the secret.
	 */
	private static final String MASKED_PART = '"api_key":"***SECRET***"';

	/**
	 * @description The secret value in the data masking sample, which must never be saved.
	 */
	private static final String SECRET_VALUE = 'sk-live-9f8e7d6c5b4a';

	/**
	 * @description The class and method name the data masking sample passes to at().
	 */
	private static final String MASKING_LOCATION = 'Demo.maskingQuickStart';

	/**
	 * @description The name of the feature flag in the feature flag sample. The test org has no flag of that name.
	 */
	private static final String FLAG_NAME = 'New_Pricing_Engine';

	/**
	 * @description The class and method name the logging samples pass to emitAt.
	 */
	private static final String LOG_LOCATION = 'MyClass.myMethod';

	/**
	 * @description The message of the exception the logging test throws.
	 */
	private static final String FAILURE_MESSAGE = 'The payment could not be taken';

	/**
	 * @description The log level of an error message.
	 */
	private static final String LOG_LEVEL_ERROR = 'ERROR';

	/**
	 * @description The name the scheduled job sample gives its job.
	 */
	private static final String SCHEDULER_NAME = 'Nightly Log Purge';

	/**
	 * @description The name of the clean-up class the scheduled job sample runs.
	 */
	private static final String PURGE_CLASS_NAME = 'SCHED_PurgeRecords';

	/**
	 * @description The time pattern of the scheduled job sample: every day at 2 in the morning.
	 */
	private static final String NIGHTLY_CRON_EXPRESSION = '0 0 2 * * ?';

	/**
	 * @description The object whose old rows the scheduled job sample deletes.
	 */
	private static final String PURGE_OBJECT_NAME = 'kern__LogEntry__c';

	/**
	 * @description How old, in days, a row must be before the scheduled job sample deletes it.
	 */
	private static final String PURGE_MINIMUM_DAYS = '90';

	/**
	 * @description The name of the circuit breaker in the resilience sample.
	 */
	private static final String CIRCUIT_NAME = 'PaymentGateway';

	/**
	 * @description How many calls the resilience test makes at most while it waits for the breaker to open.
	 */
	private static final Integer MAXIMUM_ATTEMPTS = 20;

	/**
	 * @description The date the business day sample starts from: Friday 5 September 2025.
	 */
	private static final Date FRIDAY = Date.newInstance(2025, 9, 5);

	/**
	 * @description The date three business days after the Friday: Wednesday 10 September 2025.
	 */
	private static final Date WEDNESDAY_AFTER = Date.newInstance(2025, 9, 10);

	/**
	 * @description A Saturday, the day after the Friday.
	 */
	private static final Date SATURDAY = Date.newInstance(2025, 9, 6);

	/**
	 * @description How many business days the sample adds.
	 */
	private static final Integer BUSINESS_DAYS_TO_ADD = 3;

	/**
	 * @description The chunk size in the list sample.
	 */
	private static final Integer CHUNK_SIZE = 200;

	/**
	 * @description How many items the list test splits: two full chunks and part of a third.
	 */
	private static final Integer NUMBER_OF_ITEMS = 450;

	/**
	 * @description The error message of the org's rule that requires an Industry on an account.
	 */
	private static final String INDUSTRY_REQUIRED_MESSAGE = 'Industry is required';

	/**
	 * @description A phone number, so that the org's rule that needs a phone or a website passes.
	 */
	private static final String PHONE_NUMBER = '555-0100';

	/**
	 * @description A website, so that the org's rules that need a website pass.
	 */
	private static final String WEBSITE = 'https://www.example.com';

	/**
	 * @description The named credential the callout sample calls.
	 */
	private static final String SERVICE_NAME = 'CRM';

	/**
	 * @description The body of the pretend answer to the callout.
	 */
	private static final String RESPONSE_BODY = '{"id":"001","name":"Acme Corp"}';

	/**
	 * @description The HTTP status of a successful answer.
	 */
	private static final Integer HTTP_OK = 200;

	/**
	 * @description A negative yearly revenue, which the trigger sample refuses.
	 */
	private static final Decimal NEGATIVE_REVENUE = -100;

	/**
	 * @description The error the trigger sample adds when the revenue is negative.
	 */
	private static final String NEGATIVE_REVENUE_MESSAGE = 'Annual Revenue must be positive';

	/**
	 * @description How many times the resilience sample's action has run in this test.
	 */
	private static Integer chargeRunCount = 0;

	/**
	 * @description True when the pretend payment service is down, so that each run of the resilience sample's action
	 * fails.
	 */
	private static Boolean isPaymentServiceDown = false;

	/**
	 * @description Saves one account with the name and industry given.
	 *
	 * @param name The account name.
	 * @param industry The account industry.
	 */
	private static void insertAccount(String name, String industry)
	{
		kern.TST_Builder.of(Account.SObjectType)
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
	 * @description Reads every saved log row with its message, its level and the place in the code it was written from.
	 *
	 * @return The saved log rows.
	 */
	private static List<kern__LogEntry__c> readLogEntries()
	{
		return kern.QRY_Builder.selectFrom(kern__LogEntry__c.SObjectType)
				.fields
				(
						new List<SObjectField>
						{
								kern__LogEntry__c.kern__Message__c,
								kern__LogEntry__c.kern__LogLevel__c,
								kern__LogEntry__c.kern__ClassMethod__c
						}
				)
				.toList();
	}

	/**
	 * @description The Selectors guide sample returns only the Technology accounts, with the chosen fields filled in,
	 * sorted by name.
	 */
	@IsTest
	private static void selectorsSampleReturnsSortedTechnologyAccounts()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		for(String name : UNSORTED_TECHNOLOGY_NAMES)
		{
			insertAccount(name, INDUSTRY_TECHNOLOGY);
		}

		insertAccount(FIRST_ACCOUNT_NAME, INDUSTRY_FINANCE);

		Test.startTest();
		List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Industry).equals(INDUSTRY_TECHNOLOGY)
				.orderBy(Account.Name).ascending()
				.toList();
		Test.stopTest();

		List<String> expectedNames = UNSORTED_TECHNOLOGY_NAMES.clone();
		expectedNames.sort();

		List<String> returnedNames = new List<String>();

		for(Account account : accounts)
		{
			returnedNames.add(account.Name);
			Assert.areEqual(INDUSTRY_TECHNOLOGY, account.Industry, 'Expected only Technology accounts, with Industry filled in');
		}

		Assert.areEqual(expectedNames, returnedNames, 'Expected the Technology accounts sorted by name');
	}

	/**
	 * @description The DML guide sample saves both accounts in one step.
	 */
	@IsTest
	private static void dmlSampleSavesBothAccounts()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		List<Account> accounts = new List<Account> {buildUnsavedAccount(FIRST_ACCOUNT_NAME), buildUnsavedAccount(SECOND_ACCOUNT_NAME)};

		Test.startTest();
		kern.DML_Builder.newTransaction().doInsert(accounts).execute();
		Test.stopTest();

		Assert.isNotNull(accounts[0].Id, 'Expected the first account to be saved');
		Assert.isNotNull(accounts[1].Id, 'Expected the second account to be saved');
	}

	/**
	 * @description The DML guide sample is all or nothing: when one account cannot be saved, the save fails and the
	 * other account is not saved either.
	 */
	@IsTest
	private static void dmlSampleSavesNothingWhenOneAccountFails()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		List<Account> accounts = new List<Account> {buildUnsavedAccount(FIRST_ACCOUNT_NAME), buildUnsavedAccount(null)};

		Test.startTest();
		try
		{
			kern.DML_Builder.newTransaction().doInsert(accounts).execute();
			Assert.fail('Expected the save to fail, because the second account has no name');
		}
		catch(DmlException error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected the save to fail with a DML error');
		}
		Test.stopTest();

		Integer savedAccounts = kern.QRY_Builder.selectFrom(Account.SObjectType).count();

		Assert.areEqual(0, savedAccounts, 'Expected no account to be saved when one of them fails');
	}

	/**
	 * @description The Security guide sample returns the accounts with the two fields it named filled in.
	 */
	@IsTest
	private static void securitySampleReadsInUserMode()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);
		insertAccount(FIRST_ACCOUNT_NAME, INDUSTRY_TECHNOLOGY);

		Test.startTest();
		List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<String> {NAME_FIELD, INDUSTRY_FIELD})
				.withUserMode()
				.toList();
		Test.stopTest();

		Assert.areEqual(1, accounts.size(), 'Expected the saved account to be returned');
		Assert.areEqual(FIRST_ACCOUNT_NAME, accounts[0].Name, 'Expected the Name field to be filled in');
		Assert.areEqual(INDUSTRY_TECHNOLOGY, accounts[0].Industry, 'Expected the Industry field to be filled in');
	}

	/**
	 * @description The Async Processing guide sample runs the processor in the background on every account.
	 */
	@IsTest
	private static void asyncSampleProcessesEveryAccount()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		List<Account> accounts = kern.TST_Builder.of(Account.SObjectType)
				.withCount(NUMBER_OF_ACCOUNTS_TO_PROCESS)
				.buildList();

		Test.startTest();
		Id jobId = kern.UTIL_AsynchronousJobLauncher.process(accounts, new MyProcessor());
		Test.stopTest();

		Assert.isNotNull(jobId, 'Expected the launcher to return the Id of the job it started');

		List<Account> processed = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Description})
				.toList();

		Assert.areEqual(NUMBER_OF_ACCOUNTS_TO_PROCESS, processed.size(), 'Expected every account to still be there');

		for(Account account : processed)
		{
			Assert.isTrue
					(
							account.Description?.startsWith(PROCESSED_PREFIX) == true,
							'Expected the processor to write its note on every account; found: ' + account.Description
					);
		}
	}

	/**
	 * @description The DTOs guide sample turns the order summary into JSON and reads it back with the same values.
	 */
	@IsTest
	private static void dtoSampleTurnsIntoJsonAndBack()
	{
		Test.startTest();
		DTO_OrderSummary summary = new DTO_OrderSummary();
		summary.orderId = ORDER_ID;
		summary.totalAmount = TOTAL_AMOUNT;
		String serialized = summary.serialize();

		DTO_OrderSummary parsed = (DTO_OrderSummary)new DTO_OrderSummary().deserialize(serialized);
		Test.stopTest();

		Assert.isTrue(serialized.contains(ORDER_ID), 'Expected the JSON to hold the order number; it was: ' + serialized);
		Assert.areEqual(ORDER_ID, parsed.orderId, 'Expected the order number to come back from the JSON');
		Assert.areEqual(TOTAL_AMOUNT, parsed.totalAmount, 'Expected the total to come back from the JSON');
	}

	/**
	 * @description The Data Masking guide sample saves the log message with the secret value replaced.
	 */
	@IsTest
	private static void dataMaskingSampleSavesMaskedMessage()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		kern.LOG_Builder.build()
				.info(MESSAGE_WITH_SECRET)
				.at(MASKING_LOCATION)
				.emit();
		Test.getEventBus().deliver();
		Test.stopTest();

		String savedMessage;

		for(kern__LogEntry__c entry : readLogEntries())
		{
			if(entry.kern__Message__c?.contains(PLAIN_PART) == true)
			{
				savedMessage = entry.kern__Message__c;
			}
		}

		Assert.isNotNull(savedMessage, 'Expected the log row to be saved with its plain part unchanged');
		Assert.isFalse(savedMessage.contains(SECRET_VALUE), 'Expected the secret value never to be saved');
		Assert.isTrue(savedMessage.contains(MASKED_PART), 'Expected the marker in place of the secret; the saved message was: ' + savedMessage);
	}

	/**
	 * @description The Feature Flags guide sample takes the existing path when the flag does not exist.
	 */
	@IsTest
	private static void featureFlagSampleIsOffWhenFlagIsMissing()
	{
		Test.startTest();
		Boolean isNewBehaviour = false;

		if(kern.UTIL_FeatureFlag.isEnabled(FLAG_NAME))
		{
			isNewBehaviour = true;
		}
		Test.stopTest();

		Assert.isFalse(isNewBehaviour, 'Expected the existing behaviour to run when the flag does not exist');
	}

	/**
	 * @description The Feature Flags guide sample takes the new path when the flag is active.
	 */
	@IsTest
	private static void featureFlagSampleIsOnWhenFlagIsActive()
	{
		kern.TST_Factory.newFeatureFlag(FLAG_NAME);

		Test.startTest();
		Boolean isNewBehaviour = false;

		if(kern.UTIL_FeatureFlag.isEnabled(FLAG_NAME))
		{
			isNewBehaviour = true;
		}
		Test.stopTest();

		Assert.isTrue(isNewBehaviour, 'Expected the new behaviour to run when the flag is active');
	}

	/**
	 * @description The Logging guide sample saves an error log row for the exception, and the exception still reaches
	 * the caller.
	 */
	@IsTest
	private static void loggingSampleSavesErrorAndThrowsAgain()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		try
		{
			try
			{
				throw new PaymentException(FAILURE_MESSAGE);
			}
			catch(Exception e)
			{
				kern.LOG_Builder.build().error(e).emitAt(LOG_LOCATION);
				throw e;
			}
		}
		catch(PaymentException error)
		{
			Assert.isInstanceOfType(error, PaymentException.class, 'Expected the sample to throw the exception again');
		}
		Test.getEventBus().deliver();
		Test.stopTest();

		kern__LogEntry__c errorEntry;

		for(kern__LogEntry__c entry : readLogEntries())
		{
			if(entry.kern__Message__c?.contains(FAILURE_MESSAGE) == true)
			{
				errorEntry = entry;
			}
		}

		Assert.isNotNull(errorEntry, 'Expected a log row that holds the exception message');
		Assert.areEqual(LOG_LEVEL_ERROR, errorEntry.kern__LogLevel__c, 'Expected the log row to be at error level');
		Assert.areEqual(LOG_LOCATION, errorEntry.kern__ClassMethod__c, 'Expected the log row to name the place it was written from');
	}

	/**
	 * @description The Objects and Metadata guide sample saves an active scheduled job, and the package schedules it.
	 */
	@IsTest
	private static void scheduledJobSampleSchedulesTheJob()
	{
		Test.startTest();
		kern__ScheduledJob__c job = new kern__ScheduledJob__c();
		job.kern__SchedulerName__c = SCHEDULER_NAME;
		job.kern__ClassName__c = PURGE_CLASS_NAME;
		job.kern__CronExpression__c = NIGHTLY_CRON_EXPRESSION;
		job.kern__Parameters__c = new kern.DTO_NameValues
				(
						new Map<String, String> {'objectName' => PURGE_OBJECT_NAME, 'minimumNumberOfDays' => PURGE_MINIMUM_DAYS}
				).serialize();
		job.kern__IsActive__c = true;
		kern.DML_Builder.newTransaction().doInsert(job).execute();
		Test.stopTest();

		kern__ScheduledJob__c saved = (kern__ScheduledJob__c)kern.QRY_Builder.selectFrom(kern__ScheduledJob__c.SObjectType)
				.fields(new List<SObjectField> {kern__ScheduledJob__c.kern__ScheduledJobId__c, kern__ScheduledJob__c.kern__IsActive__c})
				.condition(kern__ScheduledJob__c.Id).equals(job.Id)
				.getFirst();

		Assert.isTrue(saved.kern__IsActive__c, 'Expected the job to be saved as active');
		Assert.isTrue(String.isNotBlank(saved.kern__ScheduledJobId__c), 'Expected the package to schedule the job and keep its Id');
	}

	/**
	 * @description The Resilience guide sample runs the action through the breaker when the service works, and the
	 * breaker stays closed.
	 */
	@IsTest
	private static void resilienceSampleRunsActionWhenServiceWorks()
	{
		chargeRunCount = 0;
		isPaymentServiceDown = false;

		Test.startTest();
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_NAME);
		breaker.execute(new ChargeCardAction(null));
		Test.stopTest();

		Assert.areEqual(1, chargeRunCount, 'Expected the action to run once');
		Assert.areEqual(kern.UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Expected the breaker to stay closed');
	}

	/**
	 * @description The Resilience guide sample: while the service keeps failing, each failure reaches the caller. After
	 * enough failures the breaker opens, and the next call throws OpenException without running the action.
	 */
	@IsTest
	private static void resilienceSampleOpensAfterRepeatedFailures()
	{
		chargeRunCount = 0;
		isPaymentServiceDown = true;
		Integer attempts = 0;

		Test.startTest();
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_NAME);

		while(breaker.getState() != kern.UTIL_CircuitBreaker.State.OPEN && attempts < MAXIMUM_ATTEMPTS)
		{
			attempts++;
			try
			{
				breaker.execute(new ChargeCardAction(null));
				Assert.fail('Expected the failing action to throw its own exception');
			}
			catch(PaymentException failure)
			{
				Assert.isInstanceOfType(failure, PaymentException.class, 'Expected the action\'s own exception to reach the caller');
			}
		}

		try
		{
			breaker.execute(new ChargeCardAction(null));
			Assert.fail('Expected the open breaker to throw OpenException');
		}
		catch(kern.UTIL_CircuitBreaker.OpenException openError)
		{
			Assert.isInstanceOfType(openError, kern.UTIL_CircuitBreaker.OpenException.class, 'Expected the open breaker to refuse the call');
		}
		Test.stopTest();

		Assert.areEqual(kern.UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Expected the breaker to open after repeated failures');
		Assert.areEqual(attempts, chargeRunCount, 'Expected the open breaker not to run the action');
	}

	/**
	 * @description The Test Data guide sample saves an account with the chosen industry and fills in the required name.
	 */
	@IsTest
	private static void testDataSampleSavesAccount()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		Test.startTest();
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_TECHNOLOGY)
				.build();
		Test.stopTest();

		Assert.isNotNull(account.Id, 'Expected the account to be saved');
		Assert.areEqual(INDUSTRY_TECHNOLOGY, account.Industry, 'Expected the account to keep the chosen industry');
		Assert.isTrue(String.isNotBlank(account.Name), 'Expected the required Name field to be filled in');
	}

	/**
	 * @description The Triggers guide sample gives a blank industry the value Other, and refuses a negative revenue.
	 */
	@IsTest
	private static void triggerSampleSetsIndustryAndRefusesNegativeRevenue()
	{
		Account blankIndustry = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, null)
				.withoutInsertion()
				.build();
		Account negativeRevenue = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_TECHNOLOGY)
				.withOverride(Account.AnnualRevenue, NEGATIVE_REVENUE)
				.withoutInsertion()
				.build();

		Test.startTest();
		new TRG_ValidateAccount().beforeInsert(new List<Account> {blankIndustry, negativeRevenue});
		Test.stopTest();

		Assert.areEqual(INDUSTRY_OTHER, blankIndustry.Industry, 'Expected a blank industry to become Other');
		Assert.isFalse(blankIndustry.hasErrors(), 'Expected no error on the account with a blank industry');
		Assert.isTrue(negativeRevenue.hasErrors(), 'Expected an error on the account with a negative revenue');
		Assert.areEqual
				(
						NEGATIVE_REVENUE_MESSAGE,
						negativeRevenue.getErrors()[0].getMessage(),
						'Expected the error to say the revenue must be positive'
				);
	}

	/**
	 * @description The Utilities guide sample skips the weekend when it adds business days, and finds a Saturday.
	 */
	@IsTest
	private static void utilitiesSampleAddsBusinessDays()
	{
		Test.startTest();
		Date result = kern.UTIL_Date.addBusinessDays(FRIDAY, BUSINESS_DAYS_TO_ADD);
		Boolean isWeekend = kern.UTIL_Date.isWeekend(SATURDAY);
		Test.stopTest();

		Assert.areEqual(WEDNESDAY_AFTER, result, 'Expected three business days after a Friday to be the Wednesday');
		Assert.isTrue(isWeekend, 'Expected a Saturday to count as a weekend day');
	}

	/**
	 * @description The Utilities guide sample splits a list into chunks of at most 200 items, in order.
	 */
	@IsTest
	private static void utilitiesSampleSplitsListIntoChunks()
	{
		List<Object> records = new List<Object>();

		for(Integer index = 0; index < NUMBER_OF_ITEMS; index++)
		{
			records.add(index);
		}

		Test.startTest();
		List<List<Object>> batches = kern.UTIL_List.partition(records, CHUNK_SIZE);
		Test.stopTest();

		Assert.areEqual(3, batches.size(), 'Expected two full chunks and one part chunk');
		Assert.areEqual(CHUNK_SIZE, batches[0].size(), 'Expected the first chunk to be full');
		Assert.areEqual(NUMBER_OF_ITEMS - (2 * CHUNK_SIZE), batches[2].size(), 'Expected the last chunk to hold the rest');
		Assert.areEqual(CHUNK_SIZE, batches[1][0], 'Expected the items to stay in order');
	}

	/**
	 * @description The Validation guide sample runs the org's rules without saving the account, finds the missing
	 * industry, and logs the error.
	 */
	@IsTest
	private static void validationSampleFindsMissingIndustry()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, FIRST_ACCOUNT_NAME)
				.withOverride(Account.Industry, null)
				.withOverride(Account.Phone, PHONE_NUMBER)
				.withOverride(Account.Website, WEBSITE)
				.withoutInsertion()
				.build();
		List<Account> accounts = new List<Account> {account};

		Test.startTest();
		List<kern.UTIL_ValidationRule.ValidationResult> results =
				kern.UTIL_ValidationRule.validate(accounts, null, TriggerOperation.BEFORE_INSERT);

		for(kern.UTIL_ValidationRule.ValidationResult result : results)
		{
			if(!result.isValid)
			{
				for(kern.UTIL_ValidationRule.ValidationError error : result.errors)
				{
					kern.LOG_Builder.build().error(error.message).emitAt(LOG_LOCATION);
				}
			}
		}
		Test.getEventBus().deliver();
		Test.stopTest();

		List<String> messages = new List<String>();

		for(kern.UTIL_ValidationRule.ValidationError error : results[0].errors)
		{
			messages.add(error.message);
		}

		Boolean isLogged = false;

		for(kern__LogEntry__c entry : readLogEntries())
		{
			isLogged = isLogged || (entry.kern__Message__c?.contains(INDUSTRY_REQUIRED_MESSAGE) == true && entry.kern__LogLevel__c == LOG_LEVEL_ERROR);
		}

		Assert.areEqual(1, results.size(), 'Expected one result for the one account');
		Assert.isFalse(results[0].isValid, 'Expected the account without an industry to break a rule');
		Assert.isTrue(messages.contains(INDUSTRY_REQUIRED_MESSAGE), 'Expected the missing industry to be reported; errors: ' + messages);
		Assert.isTrue(isLogged, 'Expected the error to be saved as an error log row');
		Assert.isNull(account.Id, 'Expected the account not to be saved');
	}

	/**
	 * @description The Web Services guide sample sends the request to the named credential and returns the answer.
	 */
	@IsTest
	private static void webServicesSampleReturnsResponse()
	{
		Id accountId = kern.UTIL_Random.randomId(Account.SObjectType);

		kern.API_MockFactory.forService(SERVICE_NAME)
				.body(RESPONSE_BODY)
				.statusCode(HTTP_OK)
				.register();

		Test.startTest();
		HttpResponse response = kern.UTIL_HttpClient.get(SERVICE_NAME, '/accounts/{id}')
				.pathParam('id', accountId)
				.send();
		Test.stopTest();

		Assert.areEqual(HTTP_OK, response.getStatusCode(), 'Expected the call to succeed');
		Assert.areEqual(RESPONSE_BODY, response.getBody(), 'Expected the answer body to come back unchanged');
	}

	/**
	 * @description The processor from the Async Processing guide sample. It writes a note on each account and saves the
	 * accounts.
	 */
	private with sharing class MyProcessor implements kern.IF_Async.Processable
	{
		/**
		 * @description Writes the processed note on each account, then saves the accounts.
		 *
		 * @param items The accounts to process.
		 */
		public void execute(List<Object> items)
		{
			List<Account> accounts = new List<Account>();
			for(Object item : items)
			{
				Account account = (Account)item;
				account.Description = 'Processed: ' + Datetime.now();
				accounts.add(account);
			}
			kern.DML_Builder.newTransaction().doUpdate(accounts).execute();
		}
	}

	/**
	 * @description The order summary from the DTOs guide sample: two fields that the package turns into JSON and back.
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
		 * @description Tells the package which class to build when it reads JSON back.
		 *
		 * @return The type of this class.
		 */
		public override Type getObjectType()
		{
			return DTO_OrderSummary.class;
		}
	}

	/**
	 * @description The action from the Resilience guide sample. The guide leaves the work as a comment; here the work
	 * counts each run, and throws when the test says the service is down.
	 */
	private with sharing class ChargeCardAction implements kern.UTIL_CircuitBreaker.ProtectedAction
	{
		/**
		 * @description The order to charge.
		 */
		private Id orderId;

		/**
		 * @description Keeps the order to charge.
		 *
		 * @param orderId The order to charge.
		 */
		public ChargeCardAction(Id orderId)
		{
			this.orderId = orderId;
		}

		/**
		 * @description Counts the run, and throws when the pretend service is down.
		 */
		public void execute()
		{
			chargeRunCount++;

			if(isPaymentServiceDown)
			{
				throw new PaymentException(FAILURE_MESSAGE);
			}
		}
	}

	/**
	 * @description The trigger action from the Triggers guide sample: it refuses a negative revenue and gives a blank
	 * industry the value Other.
	 */
	private inherited sharing class TRG_ValidateAccount extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
	{
		/**
		 * @description Checks the revenue and fills in a blank industry on each new account.
		 *
		 * @param newAccounts The accounts being inserted.
		 */
		public void beforeInsert(List<Account> newAccounts)
		{
			for(Account account : newAccounts)
			{
				// Validate: Annual revenue must be positive
				if(account.AnnualRevenue != null && account.AnnualRevenue < 0)
				{
					account.AnnualRevenue.addError('Annual Revenue must be positive');
				}

				// Default: Set industry if blank
				if(String.isBlank(account.Industry))
				{
					account.Industry = 'Other';
				}
			}
		}
	}

	/**
	 * @description The error a failed payment throws in these tests.
	 */
	private class PaymentException extends Exception
	{
	}
}
