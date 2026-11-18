// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs the KernDX samples of the Why KernDX page in an org where KernDX is installed with its kern
 * namespace. Each test is named after the block of the page it proves, and runs that block's sample as the page prints
 * it, with only the set-up the sample needs around it.
 *
 * The class does not run in parallel: one test schedules a job, and one test delivers log events and reads the saved
 * entries. Tests that save accounts first switch off the org's own validation rules on accounts, so that a rule the
 * release test org adds cannot stop the save a sample makes. The scanner asks for each of those calls to be confirmed;
 * the class annotation confirms them.
 *
 * @see API_GetOnePost
 * @see DTO_Customer
 * @see CaseArchiveJob
 * @see RateService
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.KernSecurityBypassCallSite')
@IsTest(seeAllData=false isParallel=false)
private class DocumentationSamplesFrontPage_TEST
{
	/**
	 * @description The API name of the Account object, used to switch off the org's validation rules on accounts.
	 */
	private static final String ACCOUNT_OBJECT_NAME = 'Account';

	/**
	 * @description The body the posts service returns for post 1.
	 */
	private static final String POST_BODY = '{"userId":1,"id":1,"title":"A title","body":"A body"}';

	/**
	 * @description The HTTP status code of a call that worked.
	 */
	private static final Integer HTTP_OK = 200;

	/**
	 * @description The name of the feature flag the samples check. No such flag exists in the org.
	 */
	private static final String FLAG_NAME = 'NewCheckout';

	/**
	 * @description The Flow name the Flow sample gives Start Flow Correlation.
	 */
	private static final String FLOW_NAME = 'Checkout';

	/**
	 * @description The message the Flow sample gives Log Flow Event.
	 */
	private static final String FLOW_MESSAGE = 'Post fetched';

	/**
	 * @description The JSON body the DTO sample reads.
	 */
	private static final String CUSTOMER_BODY = '{"email":"ada@example.com","address":{"city":"London"}}';

	/**
	 * @description The email address in the JSON body the DTO sample reads.
	 */
	private static final String CUSTOMER_EMAIL = 'ada@example.com';

	/**
	 * @description The city in the JSON body the DTO sample reads.
	 */
	private static final String CUSTOMER_CITY = 'London';

	/**
	 * @description The message the platform gives when the package cannot turn JSON into a class.
	 */
	private static final String TYPE_CANNOT_BE_DESERIALIZED = 'Type cannot be deserialized';

	/**
	 * @description The start of the message the store gives when it cannot write to a partition that does not exist.
	 */
	private static final String MISSING_PARTITION_MESSAGE = 'Write operation failed for ORG [local.Rates]: Invalid partition';

	/**
	 * @description The start of the grouping key of a bypass audit entry for one bypass. The daily summary entry of the
	 * same bypass has another key.
	 */
	private static final String BYPASS_DETAIL_FINGERPRINT = 'detail:bypass:';

	/**
	 * @description The industry the test data sample sets.
	 */
	private static final String INDUSTRY_TECHNOLOGY = 'Technology';

	/**
	 * @description How many accounts the test data sample saves.
	 */
	private static final Integer NUMBER_OF_ACCOUNTS = 200;

	/**
	 * @description How many pretend accounts the test data sample registers.
	 */
	private static final Integer NUMBER_OF_MOCK_ACCOUNTS = 3;

	/**
	 * @description The value the security sample encrypts.
	 */
	private static final String CARD_TOKEN = 'tok_4242424242424242';

	/**
	 * @description The subject of the open case the security and code scanning samples read.
	 */
	private static final String CASE_SUBJECT = 'Front page proof case';

	/**
	 * @description The start of the short message of the bypass audit entry a sharing bypass on cases writes.
	 */
	private static final String CASE_SHARING_AUDIT_SUMMARY = 'BYPASS sharing:Case';

	/**
	 * @description Every hour, on the hour.
	 */
	private static final String EVERY_HOUR = '0 0 * * * ?';

	/**
	 * @description The name of the Scheduled Job record the scheduled job test saves.
	 */
	private static final String SCHEDULED_JOB_NAME = 'Front page case archive';

	/**
	 * @description The number of days to keep that the scheduled job sample declares as its default.
	 */
	private static final Integer DEFAULT_DAYS_TO_KEEP = 90;

	/**
	 * @description A number of days to keep that an admin could save on the record instead of the default.
	 */
	private static final String ADMIN_DAYS_TO_KEEP = '30';

	/**
	 * @description The key the Platform Cache sample uses, with dashes in it.
	 */
	private static final String CACHE_KEY = 'usd-to-eur';

	/**
	 * @description The partition name the Platform Cache sample names for a partition of the reader's own. It does not
	 * exist in the org.
	 */
	private static final String MISSING_PARTITION = 'local.Rates';

	/**
	 * @description Set to true when the feature flag sample runs the code behind the flag.
	 */
	private static Boolean newCheckoutRan = false;

	/**
	 * @description The reader's own code that runs when the flag is on.
	 */
	private static void newCheckout()
	{
		newCheckoutRan = true;
	}

	/**
	 * @description Saves one open case, as the plain way, because the test data builder tries to save business hours
	 * for a case.
	 *
	 * @return The saved case.
	 */
	private static Case insertOpenCase()
	{
		Case openCase = new Case(Subject = CASE_SUBJECT, Status = 'New', Origin = 'Web');
		kern.DML_Builder.newTransaction().doInsert(openCase).execute();
		return openCase;
	}

	/**
	 * @description Outbound services: the handler class reads post 1 through its API Setting record, and the body of
	 * the one post comes back in the result as it was sent.
	 */
	@IsTest
	private static void outboundCalls()
	{
		kern.API_MockFactory.forService(API_GetOnePost.class.getName()).body(POST_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_GetOnePost.class).invoke();
		String post = handler.result.responseBody; // kept as an API Call record
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Expected the call to work; got: ' + handler.errorText);
		Assert.areEqual(POST_BODY, post, 'Expected the body of the one post, as it was sent');
	}

	/**
	 * @description Flow actions: the four actions of the Flow sample run in order, as Flow Builder runs them, with the
	 * same handler as the outbound services sample.
	 */
	@IsTest
	private static void flowActions()
	{
		kern.API_MockFactory.forService(API_GetOnePost.class.getName()).body(POST_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		Invocable.Action start = Invocable.Action.createCustomAction('apex', 'kern', 'FLOW_LoggerStart');
		start.setInvocationParameter('flowName', FLOW_NAME);
		List<Invocable.Action.Result> startResults = start.invoke();

		Invocable.Action flag = Invocable.Action.createCustomAction('apex', 'kern', 'FLOW_CheckFeatureFlag');
		flag.setInvocationParameter('flagNames', FLAG_NAME);
		List<Invocable.Action.Result> flagResults = flag.invoke();

		Invocable.Action callout = Invocable.Action.createCustomAction('apex', 'kern', 'FLOW_CallApi');
		callout.setInvocationParameter('apiName', API_GetOnePost.class.getName());
		List<Invocable.Action.Result> calloutResults = callout.invoke();

		Invocable.Action logEvent = Invocable.Action.createCustomAction('apex', 'kern', 'FLOW_LoggerLog');
		logEvent.setInvocationParameter('correlationId', startResults[0].getOutputParameters().get('correlationId'));
		logEvent.setInvocationParameter('message', FLOW_MESSAGE);
		List<Invocable.Action.Result> logResults = logEvent.invoke();
		Test.stopTest();

		Assert.isTrue(startResults[0].isSuccess(), 'Expected Start Flow Correlation to work; got: ' + startResults[0].getErrors());
		Assert.isNotNull(startResults[0].getOutputParameters().get('correlationId'), 'Expected a tracking ID for this run');
		Assert.isTrue(flagResults[0].isSuccess(), 'Expected Is Feature Flag Enabled to work; got: ' + flagResults[0].getErrors());
		Assert.areEqual(false, flagResults[0].getOutputParameters().get('output'), 'Expected false for a flag that does not exist');
		Assert.isTrue(calloutResults[0].isSuccess(), 'Expected Invoke Callout Synchronously to work; got: ' + calloutResults[0].getErrors());
		Map<String, Object> calloutOutputs = calloutResults[0].getOutputParameters();
		Assert.areEqual(POST_BODY, calloutOutputs.get('responseBody'), 'Expected the body of the one post; outputs: ' + calloutOutputs);
		Assert.areEqual(true, calloutOutputs.get('success'), 'Expected the success flag to be true; outputs: ' + calloutOutputs);
		Assert.isTrue(logResults[0].isSuccess(), 'Expected Log Flow Event to work; got: ' + logResults[0].getErrors());
	}

	/**
	 * @description Test data and mocking: the builder saves 200 accounts with the industry set, and a mock registration
	 * answers the next read of the reader's own selector with 3 pretend rows.
	 */
	@IsTest
	private static void testData()
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		Test.startTest();
		// 200 Accounts, required fields filled in, saved with one save
		List<SObject> accounts = kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withCount(200)
				.buildList();

		// Or no database at all: the next Account read in this test gets these
		kern.TST_Mock.of(Account.SObjectType).withCount(3).buildList();
		List<SObject> found = new SEL_Accounts().query.toList(); // the 3 mock rows
		Test.stopTest();

		Assert.areEqual(NUMBER_OF_ACCOUNTS, accounts.size(), 'Expected 200 accounts');
		for(SObject each : accounts)
		{
			Assert.isNotNull(each.Id, 'Expected every account to be saved');
			Assert.areEqual(INDUSTRY_TECHNOLOGY, ((Account)each).Industry, 'Expected the industry the sample sets');
		}
		Assert.areEqual(NUMBER_OF_MOCK_ACCOUNTS, found.size(), 'Expected the 3 mock rows, not the 200 saved accounts');
	}

	/**
	 * @description DTOs: the JSON body is read into the typed class, the nested address is filled, and the class turns
	 * itself back into JSON.
	 */
	@IsTest
	private static void dtos()
	{
		HttpResponse response = new HttpResponse();
		response.setBody(CUSTOMER_BODY);

		DTO_Customer customer = (DTO_Customer)new DTO_Customer().deserialize(response.getBody());
		String email = customer.email;        // a typo here will not compile
		String city = customer.address?.city; // the nested part is typed too
		String body = customer.serialize();   // and back to JSON

		Assert.areEqual(CUSTOMER_EMAIL, email, 'Expected the email address from the body');
		Assert.areEqual(CUSTOMER_CITY, city, 'Expected the city of the nested address');
		DTO_Customer again = (DTO_Customer)new DTO_Customer().deserialize(body);
		Assert.areEqual(CUSTOMER_EMAIL, again.email, 'Expected the JSON written back to hold the email address; JSON: ' + body);
		Assert.areEqual(CUSTOMER_CITY, again.address?.city, 'Expected the JSON written back to hold the city; JSON: ' + body);
	}

	/**
	 * @description DTOs: the same class with no JsonAccess annotation on the inner address class. The package cannot
	 * fill the nested address without it: reading the body throws. So the inner class needs its own annotation, as the
	 * sample gives it.
	 */
	@IsTest
	private static void dtosInnerClassWithoutJsonAccess()
	{
		try
		{
			new DTO_CustomerWithPlainAddress().deserialize(CUSTOMER_BODY);
			Assert.fail('Expected reading the body to throw when the inner class has no JsonAccess annotation');
		}
		catch(JSONException error)
		{
			Assert.isInstanceOfType(error, JSONException.class, 'Expected a JSON error');
			Assert.areEqual(TYPE_CANNOT_BE_DESERIALIZED, error.getMessage(), 'Expected the message the platform gives');
		}
	}

	/**
	 * @description Feature flags: a flag that does not exist returns false, so the code behind it does not run.
	 */
	@IsTest
	private static void featureFlags()
	{
		if(kern.UTIL_FeatureFlag.isEnabled('NewCheckout'))
		{
			newCheckout(); // on for a profile, permission set or group, set in records
		}

		Assert.isFalse(newCheckoutRan, 'Expected a flag that does not exist to return false');
	}

	/**
	 * @description Feature flags: with the flag switched on for the test, the same line runs the code behind it.
	 */
	@IsTest
	private static void featureFlagsWhenOn()
	{
		kern.TST_Factory.newFeatureFlag(FLAG_NAME);

		if(kern.UTIL_FeatureFlag.isEnabled('NewCheckout'))
		{
			newCheckout(); // on for a profile, permission set or group, set in records
		}

		Assert.isTrue(newCheckoutRan, 'Expected the code behind the flag to run when the flag is on');
	}

	/**
	 * @description Scheduled jobs: saving a Scheduled Job record schedules the class, and its run reads the default of
	 * the number of days to keep.
	 */
	@IsTest
	private static void scheduledJobs()
	{
		Test.startTest();
		kern__ScheduledJob__c job = (kern__ScheduledJob__c)kern.TST_Builder.of(kern__ScheduledJob__c.SObjectType)
				.withOverride(kern__ScheduledJob__c.kern__SchedulerName__c, SCHEDULED_JOB_NAME)
				.withOverride(kern__ScheduledJob__c.kern__ClassName__c, CaseArchiveJob.class.getName())
				.withOverride(kern__ScheduledJob__c.kern__CronExpression__c, EVERY_HOUR)
				.withOverride(kern__ScheduledJob__c.kern__IsActive__c, true)
				.build();
		Test.stopTest();

		kern__ScheduledJob__c saved = (kern__ScheduledJob__c)kern.QRY_Builder.selectFrom(kern__ScheduledJob__c.SObjectType)
				.fields(new List<SObjectField> {kern__ScheduledJob__c.kern__ScheduledJobId__c})
				.condition(kern__ScheduledJob__c.Id).equals(job.Id)
				.getFirst();
		Assert.isNotNull(saved.kern__ScheduledJobId__c, 'Expected the record to schedule the class');

		List<String> subjects = readTaskSubjects();
		Assert.areEqual(new List<String> {CaseArchiveService.SUBJECT_PREFIX + DEFAULT_DAYS_TO_KEEP}, subjects,
				'Expected one run that kept the default of 90 days');
	}

	/**
	 * @description Scheduled jobs: a value an admin saves for the number of days to keep reaches the job as a whole
	 * number.
	 */
	@IsTest
	private static void scheduledJobsAdminValue()
	{
		CaseArchiveJob job = new CaseArchiveJob();
		job.setParameterValues(new kern.DTO_NameValues(new Map<String, String> {'daysToKeep' => ADMIN_DAYS_TO_KEEP}));

		job.execute(null);

		Assert.areEqual(Integer.valueOf(ADMIN_DAYS_TO_KEEP), job.getNumericParameter('daysToKeep'), 'Expected the saved value as a whole number');
		Assert.areEqual(new List<String> {CaseArchiveService.SUBJECT_PREFIX + ADMIN_DAYS_TO_KEEP}, readTaskSubjects(),
				'Expected the run to keep the number of days the admin saved');
	}

	/**
	 * @description Sharing and security: a value is encrypted and decrypted again, and a read of the reader's own
	 * selector past sharing returns the open case and writes a bypass audit entry.
	 */
	@IsTest
	private static void security()
	{
		Case openCase = insertOpenCase();
		String cardToken = CARD_TOKEN;
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		Boolean available = kern.UTIL_SessionEncryption.isAvailable();
		String sealed = kern.UTIL_SessionEncryption.encrypt(cardToken);
		String plain = kern.UTIL_SessionEncryption.decrypt(sealed);

		List<SObject> openCases = new SEL_Cases().query
				.condition(Case.IsClosed).equals(false)
				.bypassSharing() // written to the bypass audit trail
				.toList();
		Test.getEventBus().deliver();
		Test.stopTest();
		Test.getEventBus().deliver();

		Assert.isTrue(available, 'Expected encryption to be available, which needs space in the package cache partition');
		Assert.areNotEqual(cardToken, sealed, 'Expected the sealed value to differ from the plain value');
		Assert.areEqual(cardToken, plain, 'Expected decrypt to give back the plain value');
		Assert.areEqual(1, openCases.size(), 'Expected the one open case');
		Assert.areEqual(openCase.Id, openCases[0].Id, 'Expected the open case that was saved');

		List<kern__LogEntry__c> auditEntries = (List<kern__LogEntry__c>)new SEL_LogEntries().query
				.condition(kern__LogEntry__c.kern__ShortMessage__c).startsWith(CASE_SHARING_AUDIT_SUMMARY)
				.andCondition(kern__LogEntry__c.kern__Fingerprint__c).startsWith(BYPASS_DETAIL_FINGERPRINT)
				.toList();
		Assert.areEqual(1, auditEntries.size(), 'Expected one bypass audit entry for the sharing bypass on cases');
	}

	/**
	 * @description Code scanning: the fix the scanner's message points to reads the open cases through the reader's own
	 * selector.
	 */
	@IsTest
	private static void codeScanning()
	{
		Case openCase = insertOpenCase();

		Test.startTest();
		List<Case> openCases = readOpenCases();
		Test.stopTest();

		Assert.areEqual(1, openCases.size(), 'Expected the one open case');
		Assert.areEqual(openCase.Id, openCases[0].Id, 'Expected the open case that was saved');
		Assert.areEqual(CASE_SUBJECT, openCases[0].Subject, 'Expected the subject, a default field of the selector');
	}

	/**
	 * @description The fixed method of the code scanning sample: open cases, read through a selector.
	 *
	 * @return The open cases.
	 */
	private static List<Case> readOpenCases()
	{
		return (List<Case>)new SEL_Cases().query
				.condition(Case.IsClosed).equals(false)
				.toList();
	}

	/**
	 * @description Platform Cache: the first read finds nothing, the slow service runs once and its value is stored
	 * under a key with dashes, and the next read gets it from the cache.
	 */
	@IsTest
	private static void cache()
	{
		Test.startTest();
		kern.UTIL_Cache.Store cache = kern.UTIL_Cache.auto(); // session cache, then org cache
		Object rates = cache.get('usd-to-eur');               // any key: a long or odd one is hashed
		if(rates == null)
		{
			rates = RateService.fetch();
			cache.put('usd-to-eur', rates, 3600);             // zipped when it is large
		}
		// No cache space? get returns null and put returns false; nothing throws.
		kern.UTIL_Cache.OperationResult result = cache.getLastOperationResult();
		Object again = kern.UTIL_Cache.auto().get(CACHE_KEY);
		Test.stopTest();

		Assert.areEqual(1, RateService.fetchCount, 'Expected the slow service to run once');
		Assert.isTrue(result.success, 'Expected the put to work; status: ' + result.status + ', error: ' + result.errorMessage);
		Assert.areEqual(RateService.USD_TO_EUR, again, 'Expected the next read to get the stored rate from the cache');
		Assert.isTrue(kern.UTIL_Cache.isAllocated(),'Expected the package partition to have space in this org');
	}

	/**
	 * @description Platform Cache: a partition name that does not exist throws nothing. The read gives null, the store
	 * gives false, and the last result says why.
	 */
	@IsTest
	private static void cacheMissingPartition()
	{
		kern.UTIL_Cache.Store cache = kern.UTIL_Cache.partition(MISSING_PARTITION);

		Object rates = cache.get(CACHE_KEY);
		Boolean stored = cache.put(CACHE_KEY, RateService.fetch(), 3600);
		kern.UTIL_Cache.OperationResult result = cache.getLastOperationResult();

		Assert.isNull(rates, 'Expected null from a partition that does not exist');
		Assert.isFalse(stored, 'Expected false from a store into a partition that does not exist');
		Assert.areEqual(kern.UTIL_Cache.Status.WRITE_FAILURE, result.status, 'Expected the status to say the write failed; error: '
				+ result.errorMessage);
		Assert.isTrue(result.errorMessage.startsWith(MISSING_PARTITION_MESSAGE), 'Expected a message that names the missing partition; got: '
				+ result.errorMessage);
	}

	/**
	 * @description Reads the subjects of the tasks the case archive stand-in saved.
	 *
	 * @return One subject for each run.
	 */
	private static List<String> readTaskSubjects()
	{
		List<String> subjects = new List<String>();

		for(Task each : (List<Task>)new SEL_Tasks().query.condition(Task.Subject).startsWith(CaseArchiveService.SUBJECT_PREFIX).toList())
		{
			subjects.add(each.Subject);
		}

		return subjects;
	}

	/**
	 * @description The reader's own selector for accounts, a with sharing class extending kern.SEL_Base.
	 */
	private with sharing class SEL_Accounts extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for accounts.
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
	 * @description The reader's own selector for cases, a with sharing class extending kern.SEL_Base.
	 */
	private with sharing class SEL_Cases extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for cases.
		 */
		public SEL_Cases()
		{
			super(Case.SObjectType);
		}

		/**
		 * @description The fields every read returns.
		 *
		 * @return Subject and status.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField> {Case.Subject, Case.Status};
		}
	}

	/**
	 * @description A selector for the tasks the case archive stand-in saves.
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
