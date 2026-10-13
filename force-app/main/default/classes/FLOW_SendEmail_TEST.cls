// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit test class for the FLOW_SendEmail class, verifying email sending and activity logging functionality.
 * Tests email sending with various inputs (e.g., User Id, email address, valid/invalid target objects) and ensures merge fields are correctly replaced.
 *
 * @see FLOW_SendEmail
 *
 * @author Jason van Beukering
 *
 * @group Email
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class FLOW_SendEmail_TEST
{
	/**
	 * @description The expected replacement text used to verify merge field substitution.
	 */
	private static final String MERGE_FIELD_VALUE = 'This is the replacement text expected';

	/**
	 * @description The length of the random key stored in the query result memory cache.
	 */
	private static final Integer MEMORY_CACHE_KEY_LENGTH = 20;

	/**
	 * @description Inserts the shared base fixture (a Foobar record and a file) in a single DML transaction.
	 * Called at the start of each test method that needs the fixture.
	 */
	private static void buildBaseFixture()
	{
		DML_Builder.newTransaction()
				.withSystemMode()
				.doInsert(new List<SObject> {TST_Factory.newFoobar(), TST_Factory.newContentVersion()})
				.execute();
	}

	/**
	 * @description Inserts a Contact with an email address, for the tests that send to a record Id. Only a Contact,
	 * Lead or User can receive an email by Id, and a Task cannot name a User as the person it is about.
	 *
	 * @return The saved Contact.
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static Contact insertContactWithEmail()
	{
		Contact newContact = (Contact)TST_Builder.of(Contact.SObjectType).withDefaultedField(Contact.Email).withoutInsertion().build();
		DML_Builder.newTransaction().withSystemMode().doInsert(newContact).execute();
		return newContact;
	}

	/**
	 * @description Executes the email sending test with specified parameters, constructing a DTO_Request with merge fields and attachments.
	 *
	 * @param toAddress The recipient’s email address or Contact/Lead/User Id.
	 * @param whatId The Id of the related record (e.g., Foobar__c) for merge fields.
	 * @param templateName The unique name of the email template to use.
	 * @param useStandardActivityLogging If true, sets the useStandardLogActivity flag on the DTO.
	 *
	 * @return A list of DTO_Response objects indicating the success or failure of the email send.
	 */
	private static List<FLOW_SendEmail.DTO_Response> runTest(String toAddress, Id whatId, String templateName, Boolean useStandardActivityLogging)
	{
		return runTest(toAddress, whatId, templateName, useStandardActivityLogging, true);
	}

	/**
	 * @description Executes the email sending test with specified parameters, constructing a DTO_Request with merge fields and attachments.
	 * The full overload: every logging dial is explicit.
	 *
	 * @param toAddress The recipient’s email address or Contact/Lead/User Id.
	 * @param whatId The Id of the related record (e.g., Foobar__c) for merge fields.
	 * @param templateName The unique name of the email template to use.
	 * @param useStandardActivityLogging If true, sets the useStandardLogActivity flag on the DTO.
	 * @param saveAsActivity Whether an activity is wanted at all (the saveAsActivity flag on the DTO).
	 *
	 * @return A list of DTO_Response objects indicating the success or failure of the email send.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static List<FLOW_SendEmail.DTO_Response> runTest(String toAddress, Id whatId, String templateName, Boolean useStandardActivityLogging, Boolean saveAsActivity)
	{
		FLOW_SendEmail.DTO_Request dtoEmail = new FLOW_SendEmail.DTO_Request();

		dtoEmail.fileIds = new List<Id> {new SEL_ContentVersion().getAll().iterator().next().Id};
		dtoEmail.orgWideEmailAddress = ((OrgWideEmailAddress)new SEL_OrgWideEmailAddress().getRandomItem())?.Address;
		dtoEmail.saveAsActivity = saveAsActivity;
		dtoEmail.templateUniqueName = templateName;
		dtoEmail.toAddress = toAddress;
		dtoEmail.whatId = whatId;
		dtoEmail.useStandardLogActivity = useStandardActivityLogging;

		DTO_NameValue dtoMergeField = new DTO_NameValue();
		dtoMergeField.name = 'Custom Merge Field';
		dtoMergeField.value = MERGE_FIELD_VALUE;
		dtoEmail.mergeFields = new List<DTO_NameValue> {dtoMergeField};

		Test.startTest();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request> {dtoEmail});

		Test.stopTest();

		Assert.isFalse(dtoResponses.isEmpty(), 'No responses received');
		return dtoResponses;
	}

	/**
	 * @description Executes the email sending test with specified parameters, constructing a DTO_Request with merge fields and attachments.
	 * Overloaded method for existing tests, defaults useStandardLogActivity to false.
	 *
	 * @param toAddress The recipient’s email address or Contact/Lead/User Id.
	 * @param whatId The Id of the related record (e.g., Foobar__c) for merge fields.
	 * @param templateName The unique name of the email template to use.
	 *
	 * @return A list of DTO_Response objects indicating the success or failure of the email send.
	 */
	private static List<FLOW_SendEmail.DTO_Response> runTest(String toAddress, Id whatId, String templateName)
	{
		return runTest(toAddress, whatId, templateName, false);
	}

	/**
	 * @description Tests successful email sending using a Contact Id as the toAddress, verifying activity logging and merge field replacement (using custom logging).
	 */
	@IsTest
	private static void successfulUsingContactId()
	{
		buildBaseFixture();

		Contact newContact = insertContactWithEmail();
		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		assertSendSuccessful(runTest(newContact.Id, newFoobar.Id, SEL_EmailTemplate.CUSTOM_TEST_EMAIL_TEMPLATE));
	}

	/**
	 * @description Tests successful email sending using an email address as the toAddress, verifying merge field replacement (using custom logging).
	 */
	@IsTest
	private static void successfulUsingEmailAddress()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		assertSendSuccessful(runTest(UserInfo.getUserEmail(), newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE));
	}

	/**
	 * @description Tests successful email sending where OrgWideEmailAddress is explicitly provided (covering the isNotBlank check)
	 * and where valid construction is possible.
	 */
	@IsTest
	private static void successfulUsingExplicitButInvalidOrgWideEmail()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		FLOW_SendEmail.DTO_Request dtoEmail = new FLOW_SendEmail.DTO_Request();

		dtoEmail.orgWideEmailAddress = UTIL_Random.randomEmail();
		dtoEmail.templateUniqueName = SEL_EmailTemplate.TEST_EMAIL_TEMPLATE;
		dtoEmail.toAddress = UserInfo.getUserEmail();
		dtoEmail.whatId = newFoobar.Id;

		Test.startTest();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request> {dtoEmail});

		Test.stopTest();

		assertSendSuccessful(dtoResponses);
	}

	/**
	 * @description Tests that the code correctly catches exceptions during Email Construction.
	 * Uses a DELETED Record ID to force Messaging.renderStoredEmailTemplate to fail naturally.
	 */
	@IsTest
	private static void failedEmailConstructionBadId()
	{
		buildBaseFixture();

		Foobar__c record = TST_Factory.insertFoobar();
		DML_Builder.newTransaction().withSystemMode().doDelete(record).execute();

		FLOW_SendEmail.DTO_Response response = runTest(UTIL_Random.randomEmail(), record.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE).iterator().next();

		Assert.isFalse(response.success, 'Request should fail due to construction error.');
		Assert.isTrue(response.errors.contains('Email Construction Failed'), 'Should catch the render exception. Actual: ' + response.errors);
	}

	/**
	 * @description Tests that the logic handles restricted deliverability settings correctly.
	 * Forces the "Restricted" path using a test hook, as !Test.isRunningTest() cannot be naturally bypassed.
	 */
	@IsTest
	private static void failedDeliverabilityRestriction()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		// Force the check to fail
		FLOW_SendEmailInternal.simulateRestrictedDeliverability = true;

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UserInfo.getUserId(), newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE);

		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();
		Assert.isFalse(response.success, 'Request should fail due to simulated deliverability restriction.');
		Assert.isTrue(response.errors.contains('Email Deliverability is disabled'), 'Error message should match.');
	}

	/**
	 * @description Tests that an error is reported when an invalid targetObjectId (e.g., Foobar__c Id) is used in toAddress.
	 */
	@IsTest
	private static void failedInvalidTargetObjectId()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(newFoobar.Id, newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE);

		Assert.isFalse(dtoResponses.iterator().next().success, JSON.serializePretty(dtoResponses));
	}

	/**
	 * @description Tests successful email sending using a Contact Id with useStandardLogActivity=true, verifying the Task is created.
	 */
	@IsTest
	private static void successfulLogActivity()
	{
		buildBaseFixture();

		Contact newContact = insertContactWithEmail();
		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(newContact.Id, newFoobar.Id, SEL_EmailTemplate.CUSTOM_TEST_EMAIL_TEMPLATE, true);
		assertSendSuccessful(dtoResponses);

		// Verify Task was created only if external emails are allowed and send was successful
		if(dtoResponses.iterator().next().success)
		{
			Assert.isTrue(QRY_Builder.selectFrom(Task.SObjectType).toList().size() == 1, 'Task should have been created for standard logging');
		}
	}

	/**
	 * @description Tests that logging the activity with custom logging empties the query result memory cache, because
	 * the Task insert is a write outside DML_Transaction. Where the org cannot send external email, no activity is logged and the test returns.
	 */
	@IsTest
	private static void activityLoggingEmptiesTheMemoryCache()
	{
		if(UTIL_Email.getEmailDeliverabilityAccessLevel() != UTIL_Email.DeliverabilityAccessLevel.ALL_EMAIL)
		{
			return;
		}
		buildBaseFixture();
		Contact newContact = insertContactWithEmail();
		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);
		QRY_Engine.storeCopyInMemoryCache(key, new List<Foobar__c> {TST_Factory.newFoobar()}, QRY_Engine.CacheStatus.MEMORY_STORED);
		Assert.isNotNull(QRY_Engine.getCopyFromMemoryCache(key), 'The key should be stored before the send');

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(newContact.Id, newFoobar.Id, SEL_EmailTemplate.CUSTOM_TEST_EMAIL_TEMPLATE);

		Assert.isTrue(dtoResponses.iterator().next().success, JSON.serializePretty(dtoResponses));
		Assert.isNull(QRY_Engine.getCopyFromMemoryCache(key), 'Logging the activity should empty the memory cache');
	}

	/**
	 * @description Tests that the response correctly reports failure when the email sends but activity logging (Task DML) fails.
	 * Note: In orgs with restricted email deliverability, the Flow fails before activity logging is attempted.
	 */
	@IsTest
	private static void failedLogActivityDmlError()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		// Set the internal variable to force a DML failure by setting WhatId=null
		FLOW_SendEmailInternal.simulateFailedActivityLogging = true;

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UserInfo.getUserId(), newFoobar.Id, SEL_EmailTemplate.CUSTOM_TEST_EMAIL_TEMPLATE, false);

		// Assert that the request is marked as failed
		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();
		Assert.isFalse(response.success, 'Email send should be reported as failed.');

		// In orgs with restricted email deliverability, the Flow fails with "Single email is not enabled"
		// In orgs with full deliverability, the activity logging fails with "Activity Logging Failed"
		Boolean hasActivityLoggingError = response.errors.contains('Activity Logging Failed');
		Boolean hasFlowError = response.errors.contains('Flow Invocation Failed') || response.errors.contains('Single email is not enabled');

		Assert.isTrue(hasActivityLoggingError || hasFlowError,
				'Error message should contain either Activity Logging or Flow failure. Actual: ' + response.errors);

		Assert.isTrue(QRY_Builder.selectFrom(Task.SObjectType).toList().isEmpty(), 'No Task should have been created on failure path.');
	}

	/**
	 * @description Tests that the process correctly fails and logs an error when the internal Flow cannot be invoked.
	 */
	@IsTest
	private static void failedFlowInvocation()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		// Mock Flow invocation failure by changing the TestVisible flow API name
		FLOW_SendEmailInternal.simulateFailedFlowExecution = true;

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UserInfo.getUserId(), newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE, false);

		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();
		Assert.isFalse(response.success, 'Request should fail because the Flow invocation failed.');
		Assert.isTrue(response.errors.contains('Flow Invocation Failed'), 'Error message should report Flow failure.');
	}

	/**
	 * @description Tests that the pre-flight validation catches an invalid (non-existent) Email Template name.
	 */
	@IsTest
	private static void failedTemplateNotFound()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UserInfo.getUserId(), newFoobar.Id, 'Non_Existent_Template', false);

		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();
		Assert.isFalse(response.success, 'Request should fail because the template was not found.');
		Assert.isTrue(response.errors.contains('Email Template not found'), 'Error message should report template validation failure.');
	}

	/**
	 * @description Tests that the validation logic catches an Invalid ID Type (Custom Object) passed as the Recipient.
	 */
	@IsTest
	private static void failedInvalidRecipientIdType()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		// Pass a Custom Object ID (Foobar) into the 'toAddress' field.
		// This is valid for WhatId, but INVALID for the Recipient (toAddress).
		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(newFoobar.Id, newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE);

		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();
		Assert.isFalse(response.success, 'Request should fail due to Invalid Recipient ID type.');
		Assert.isTrue(response.errors.contains('Invalid To Address ID'), 'Error message should specify invalid ID type.');
	}

	/**
	 * @description Tests successful email sending using a User Id as the toAddress without saving as an activity.
	 */
	@IsTest
	private static void successfulUsingUserIdNoActivity()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		FLOW_SendEmail.DTO_Request dtoEmail = new FLOW_SendEmail.DTO_Request();

		dtoEmail.templateUniqueName = SEL_EmailTemplate.TEST_EMAIL_TEMPLATE;
		dtoEmail.toAddress = UserInfo.getUserId();
		dtoEmail.whatId = newFoobar.Id;

		Test.startTest();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request> {dtoEmail});

		Test.stopTest();

		assertSendSuccessful(dtoResponses);
	}

	/**
	 * @description Checks the recipient rule behind the reported fault by calling it directly. The platform checks
	 * the recipient only when the email is delivered, and a test never delivers an email. So a test cannot see the
	 * by-Id action refuse the send with "0 recipients" through the Flow; that refusal was reproduced in a real org.
	 * The record Id reaches the Flow only when standard logging AND an activity are both wanted. Every other case
	 * sends by address, and when no address is found the original value is passed on.
	 */
	@IsTest
	private static void resolvesFlowRecipientByAddressUnlessStandardLoggingLogsAnActivity()
	{
		String userId = UserInfo.getUserId();
		String userEmail = UserInfo.getUserEmail();
		Map<Id, String> emailById = new Map<Id, String> {(Id)userId => userEmail};

		FLOW_SendEmail.DTO_Request request = new FLOW_SendEmail.DTO_Request();
		request.toAddress = userId;

		request.useStandardLogActivity = true;
		request.saveAsActivity = false;
		Assert.areEqual(userEmail, FLOW_SendEmailInternal.resolveFlowRecipient(request, userId, emailById), 'Standard logging without an activity sends by address.');

		request.useStandardLogActivity = true;
		request.saveAsActivity = true;
		Assert.areEqual(userId, FLOW_SendEmailInternal.resolveFlowRecipient(request, userId, emailById), 'Standard logging with an activity hands the Id to the Flow.');

		request.useStandardLogActivity = false;
		request.saveAsActivity = true;
		Assert.areEqual(userEmail, FLOW_SendEmailInternal.resolveFlowRecipient(request, userId, emailById), 'Custom logging sends by address.');

		Assert.areEqual(userId, FLOW_SendEmailInternal.resolveFlowRecipient(request, userId, new Map<Id, String>()), 'Without an address the original value passes through.');
	}

	/**
	 * @description Standard logging chosen but no activity wanted, User target: the send goes by address instead of
	 * handing the User Id to the platform action, which ignores an Id unless it is logging ("0 recipients").
	 * A subscriber reported this combination as an unhandled flow fault. See the recipient rule test above for why
	 * this test alone cannot show the fault.
	 */
	@IsTest
	private static void successfulStandardLoggingWithoutActivityUsingUserId()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UserInfo.getUserId(), newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE, true, false);

		assertSendSuccessful(dtoResponses);
		Assert.isTrue(QRY_Builder.selectFrom(Task.SObjectType).toList().isEmpty(), 'No activity was wanted, so no Task may be logged.');
	}

	/**
	 * @description Standard logging chosen but no activity wanted, Contact target: the same by-address routing
	 * applies whatever the recipient's type, because the platform action's "0 recipients" refusal is about the
	 * missing activity, not the recipient.
	 */
	@IsTest
	private static void successfulStandardLoggingWithoutActivityUsingContactId()
	{
		buildBaseFixture();

		Contact newContact = insertContactWithEmail();
		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(newContact.Id, newFoobar.Id, SEL_EmailTemplate.CUSTOM_TEST_EMAIL_TEMPLATE, true, false);

		assertSendSuccessful(dtoResponses);
		Assert.isTrue(QRY_Builder.selectFrom(Task.SObjectType).toList().isEmpty(), 'No activity was wanted, so no Task may be logged.');
	}

	/**
	 * @description Standard logging with an activity wanted for a User target is refused before anything is sent,
	 * because the platform does not log an email sent to a User. The flow-failure simulation proves the flow was
	 * never reached: had it been, the response would carry the flow's failure text instead of the refusal.
	 */
	@IsTest
	private static void failedStandardLoggingActivityUsingUserId()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		FLOW_SendEmailInternal.simulateFailedFlowExecution = true;

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UserInfo.getUserId(), newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE, true, true);

		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();
		Assert.isFalse(response.success, 'Standard activity logging cannot target a User, so the request must be refused.');
		Assert.isTrue(response.errors.contains('cannot target a User'), 'The refusal must name the rule. Actual: ' + response.errors);
		Assert.isFalse(response.errors.contains('Flow Invocation Failed'), 'The refusal must happen before the flow is invoked. Actual: ' + response.errors);
	}

	/**
	 * @description Custom logging with an activity wanted for a User target: the email is sent by address and the
	 * Task is logged against the related record with no WhoId, because a Task cannot name a User as its WhoId.
	 * Before the fix the send succeeded and the Task insert then failed, so the response reported a failure for
	 * an email that was delivered.
	 */
	@IsTest
	private static void successfulCustomLoggingActivityUsingUserId()
	{
		buildBaseFixture();

		Foobar__c newFoobar = new SEL_Foobar().getAll().iterator().next();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UserInfo.getUserId(), newFoobar.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE, false, true);

		assertSendSuccessful(dtoResponses);

		// The Task is only logged after a successful send, which restricted deliverability prevents (see assertSendSuccessful).
		if(dtoResponses.iterator().next().success)
		{
			List<Task> loggedTasks = QRY_Builder.selectFrom(Task.SObjectType).fields(new List<SObjectField> {Task.WhoId, Task.WhatId}).toList();
			Assert.areEqual(1, loggedTasks.size(), 'One Task must be logged for the send.');
			Assert.areEqual(newFoobar.Id, loggedTasks.iterator().next().WhatId, 'The Task must be related to the whatId record.');
			Assert.isNull(loggedTasks.iterator().next().WhoId, 'A User cannot be a Task WhoId, so the Task must carry none.');
		}
	}

	/**
	 * @description Tests the edge case where a deleted record ID is used as toAddress with an email address,
	 * forcing the Flow to fail during execution.
	 */
	@IsTest
	private static void failedUsingDeletedRecordIdNoActivity()
	{
		buildBaseFixture();

		Foobar__c record = TST_Factory.insertFoobar();
		DML_Builder.newTransaction().withSystemMode().doDelete(record).execute();

		List<FLOW_SendEmail.DTO_Response> dtoResponses = runTest(UTIL_Random.randomEmail(), record.Id, SEL_EmailTemplate.TEST_EMAIL_TEMPLATE);

		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();

		Assert.isFalse(response.success, 'Should fail when whatId references a deleted record');
	}

	/**
	 * @description Verifies that an email was sent successfully and checks for merge field replacement in the email body.
	 *
	 * Accounts for orgs where external email delivery is restricted, ensuring tests pass in such environments.
	 *
	 * @param dtoResponses The list of DTO_Response objects from the email send operation.
	 */
	private static void assertSendSuccessful(List<FLOW_SendEmail.DTO_Response> dtoResponses)
	{
		FLOW_SendEmail.DTO_Response response = dtoResponses.iterator().next();
		Boolean externalEmailsAllowed = UTIL_Email.getEmailDeliverabilityAccessLevel() == UTIL_Email.DeliverabilityAccessLevel.ALL_EMAIL;
		Boolean isDomainNotVerified = String.isNotBlank(response.errors) && response.errors.containsIgnoreCase('domain') && response.errors.containsIgnoreCase('verified');
		Assert.isTrue(response.success || !externalEmailsAllowed || isDomainNotVerified, JSON.serializePretty(dtoResponses));
		if(response.success)
		{
			List<SObjectField> bodyFields = new List<SObjectField> {EmailMessage.TextBody, EmailMessage.HtmlBody};
			List<EmailMessage> foundMessages = QRY_Builder.selectFrom(EmailMessage.SObjectType).fields(bodyFields).toList();
			if(!foundMessages.isEmpty())
			{
				EmailMessage foundMessage = foundMessages.iterator().next();
				Assert.isTrue(foundMessage.TextBody?.contains(MERGE_FIELD_VALUE) == true, 'Merge field not replaced in Text Body');
				if(String.isNotBlank(foundMessage.HtmlBody))
				{
					Assert.isTrue(foundMessage.HtmlBody?.contains(MERGE_FIELD_VALUE) == true, 'Merge field not replaced in Html Body');
				}
			}
		}
	}
}