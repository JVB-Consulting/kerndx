// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs three details of the developer guide samples in an org where KernDX is installed with its kern
 * namespace: a DTO class of its own that declares getObjectType() public override, a background job processor that
 * casts each item it is given on every way the package can run it, and a log message saved with a secret masked.
 * Each test runs the sample as the guide prints it and checks what it really does.
 *
 * The other guide samples are tested in DocumentationSamplesGuides_TEST. This class is kept apart so that neither class
 * grows too long to read.
 *
 * The class does not run in parallel with other tests: one test delivers a platform event and reads the saved log row,
 * and log rows saved by other tests at the same time would get in the way.
 *
 * Tests that save accounts first switch off the org's own validation rules on accounts, so that a rule the release test
 * org adds cannot stop the save a sample makes. The scanner asks for each of those calls to be confirmed; the class
 * annotation confirms them.
 *
 * @see DTO_DocumentationInvoice
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.KernSecurityBypassCallSite')
@IsTest(seeAllData=false isParallel=false)
private class DocumentationSamplesGuideDetails_TEST
{
	/**
	 * @description The API name of the Account object, used to switch off the org's validation rules on accounts in
	 * these tests.
	 */
	private static final String ACCOUNT_OBJECT_NAME = 'Account';

	/**
	 * @description The text the background job sample puts at the start of each Description.
	 */
	private static final String PROCESSED_PREFIX = 'Processed: ';

	/**
	 * @description How many accounts the background job sample processes.
	 */
	private static final Integer NUMBER_OF_ACCOUNTS_TO_PROCESS = 3;

	/**
	 * @description The invoice number in the DTO sample.
	 */
	private static final String INVOICE_ID = 'INV-001';

	/**
	 * @description The invoice status in the DTO sample.
	 */
	private static final String INVOICE_STATUS = 'Paid';

	/**
	 * @description The log message in the data masking sample. It holds a secret under the api_key name.
	 */
	private static final String MESSAGE_WITH_SECRET = '{"user":"alice","api_key":"sk-live-9f8e7d6c5b4a"}';

	/**
	 * @description The secret in the data masking message. It must never be saved.
	 */
	private static final String SECRET_VALUE = 'sk-live-9f8e7d6c5b4a';

	/**
	 * @description The part of the saved log message where the marker stands in place of the secret. The Data Masking
	 * guide does not promise the order of the names in the saved message, so the test looks for this part and the plain
	 * part on their own.
	 */
	private static final String MASKED_PART = '"api_key":"***SECRET***"';

	/**
	 * @description A part of the data masking message that holds no secret, used to find the saved log row.
	 */
	private static final String PLAIN_PART = '"user":"alice"';

	/**
	 * @description The class and method name the data masking sample passes to at().
	 */
	private static final String MASKING_LOCATION = 'Demo.maskingQuickStart';

	/**
	 * @description Saves the accounts for a background job test, runs the guide's processor on them in the way given,
	 * and checks that the processor wrote its note on every account.
	 *
	 * @param strategy The way the package runs the job: as one Batch Apex job, as Queueable jobs that start one after
	 * the other, or as Queueable jobs that start at the same time.
	 */
	private static void assertProcessorRunsOnEveryAccount(kern.IF_Async.AsynchronousExecutionStrategy strategy)
	{
		kern.UTIL_ValidationRule.bypassObject(ACCOUNT_OBJECT_NAME);

		List<Account> accounts = kern.TST_Builder.of(Account.SObjectType)
				.withCount(NUMBER_OF_ACCOUNTS_TO_PROCESS)
				.buildList();

		kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(accounts)
				.withExecutionStrategy(strategy);

		Test.startTest();
		Id jobId = kern.UTIL_AsynchronousJobLauncher.process(request, new MyProcessor());
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
	 * @description The DTOs guide sample, written as a class of its own that declares getObjectType() public override,
	 * turns into JSON and reads back with the same values.
	 */
	@IsTest
	private static void dtoClassOfItsOwnTurnsIntoJsonAndBack()
	{
		Test.startTest();
		DTO_DocumentationInvoice invoice = new DTO_DocumentationInvoice();
		invoice.invoiceId = INVOICE_ID;
		invoice.status = INVOICE_STATUS;
		String serialized = invoice.serialize();

		DTO_DocumentationInvoice parsed = (DTO_DocumentationInvoice)new DTO_DocumentationInvoice().deserialize(serialized);
		Test.stopTest();

		Assert.isTrue(serialized.contains(INVOICE_ID), 'Expected the JSON to hold the invoice number; it was: ' + serialized);
		Assert.areEqual(INVOICE_ID, parsed.invoiceId, 'Expected the invoice number to come back from the JSON');
		Assert.areEqual(INVOICE_STATUS, parsed.status, 'Expected the status to come back from the JSON');
	}

	/**
	 * @description The Async Processing guide processor, which casts each item, runs on every account when the package
	 * runs it as Batch Apex.
	 */
	@IsTest
	private static void processorCastingEachItemRunsAsBatch()
	{
		assertProcessorRunsOnEveryAccount(kern.IF_Async.AsynchronousExecutionStrategy.BATCH);
	}

	/**
	 * @description The Async Processing guide processor, which casts each item, runs on every account when the package
	 * runs it as Queueable jobs that start one after the other.
	 */
	@IsTest
	private static void processorCastingEachItemRunsAsChainedQueueables()
	{
		assertProcessorRunsOnEveryAccount(kern.IF_Async.AsynchronousExecutionStrategy.CHAINABLE);
	}

	/**
	 * @description The Async Processing guide processor, which casts each item, runs on every account when the package
	 * runs it as Queueable jobs that start at the same time.
	 */
	@IsTest
	private static void processorCastingEachItemRunsAsParallelQueueables()
	{
		assertProcessorRunsOnEveryAccount(kern.IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES);
	}

	/**
	 * @description The Data Masking guide sample saves the log message with the plain part kept and the marker in place
	 * of the secret, in any order.
	 */
	@IsTest
	private static void dataMaskingSampleSavesBothPartsOfMessage()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		kern.LOG_Builder.build()
				.info(MESSAGE_WITH_SECRET)
				.at(MASKING_LOCATION)
				.emit();
		Test.getEventBus().deliver();
		Test.stopTest();

		List<kern__LogEntry__c> entries = kern.QRY_Builder.selectFrom(kern__LogEntry__c.SObjectType)
				.fields(new List<SObjectField> {kern__LogEntry__c.kern__Message__c})
				.toList();

		String savedMessage;

		for(kern__LogEntry__c entry : entries)
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
	 * @description The processor from the Async Processing guide samples. The package gives it its records as a plain
	 * list of objects, so it casts each item to an account, writes a note on it and saves the accounts.
	 */
	private with sharing class MyProcessor implements kern.IF_Async.Processable
	{
		/**
		 * @description Writes the processed note on each account, then saves the accounts.
		 *
		 * @param items The accounts to process, as a plain list of objects.
		 */
		public void execute(List<Object> items)
		{
			List<Account> accounts = new List<Account>();
			for(Object item : items)
			{
				Account account = (Account)item;
				account.Description = 'Processed: ' + DateTime.now();
				accounts.add(account);
			}
			kern.DML_Builder.newTransaction().doUpdate(accounts).execute();
		}
	}
}
