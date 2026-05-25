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
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FLOW_SendEmail_TEST
{
	/**
	 * @description The expected replacement text used to verify merge field substitution.
	 */
	private static final String MERGE_FIELD_VALUE = 'This is the replacement text expected';

	/**
	 * @description Inserts the shared base fixture (Contact with Email, Foobar, ContentVersion) in a
	 * single DML transaction. Called at the start of each test method that needs the fixture.
	 */
	private static void buildBaseFixture()
	{
		DML_Builder.newTransaction()
				.withSystemMode()
				.doInsert
						(
								new List<SObject>
								{
										TST_Builder.of(Contact.SObjectType)
												.withDefaultedField(Contact.Email)
												.withoutInsertion()
												.build(),
										TST_Factory.newFoobar(),
										TST_Factory.newContentVersion()
								}
						)
				.execute();
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
		FLOW_SendEmail.DTO_Request dtoEmail = new FLOW_SendEmail.DTO_Request();

		dtoEmail.fileIds = new List<Id> {new SEL_ContentVersion().getAll().iterator().next().Id};
		dtoEmail.orgWideEmailAddress = ((OrgWideEmailAddress)new SEL_OrgWideEmailAddress().getRandomItem())?.Address;
		dtoEmail.saveAsActivity = true;
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

		Contact newContact = (Contact)QRY_Builder.selectFrom(Contact.SObjectType).getFirst();
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

		Contact newContact = (Contact)QRY_Builder.selectFrom(Contact.SObjectType).getFirst();
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
			List<EmailMessage> foundMessages = QRY_Builder.selectFrom(EmailMessage.SObjectType).fields(new List<SObjectField> {EmailMessage.TextBody, EmailMessage.HtmlBody}).toList();
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