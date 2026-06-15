// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Internal logic handler for the `FLOW_SendEmail` Invocable Method.
 * Orchestrates the email sending process including:
 * 1. Validation of inputs and Organization Email Deliverability.
 * 2. Construction of the email body (rendering templates + custom merge fields).
 * 3. Invocation of a decoupling Flow to handle the actual send.
 * 4. Logging of Tasks (Activities) if configured.
 *
 * @see FLOW_SendEmail
 * @see FLOW_SendEmail_TEST
 *
 * @author Jason van Beukering
 *
 * @group Email
 *
 * @date November 2025, June 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class FLOW_SendEmailInternal
{
	/**
	 * @description Test-only flag to simulate a DML exception during Task creation.
	 */
	@TestVisible
	private static Boolean simulateFailedActivityLogging = false;

	/**
	 * @description Test-only flag to simulate an exception during Flow Invocation.
	 */
	@TestVisible
	private static Boolean simulateFailedFlowExecution = false;

	/**
	 * @description Test-only flag to simulate restricted email deliverability.
	 * Required to cover the error handling block that is normally bypassed in tests.
	 */
	@TestVisible
	private static Boolean simulateRestrictedDeliverability = false;

	/**
	 * @description Set of SObject API Names that qualify as "Who" objects (Human recipients).
	 * Used to correctly assign `TargetObjectId` vs `WhatId`.
	 */
	@TestVisible
	private static final Set<String> PERSON_OBJECT_NAMES = new Set<String>
	{
			'Contact',
			'Lead',
			'User'
	};

	/**
	 * @description The API Name of the Autolaunched Flow used to physically send the email.
	 * This decoupling allows for complex administration (e.g., pausing, rerouting) without code changes.
	 */
	private static final String FLOW_EMAIL_SENDER_API_NAME = 'SendEmailService';

	/**
	 * @description The first closed Task status value in the org. Lazily queried once per transaction
	 * to support orgs with customised Task status picklists.
	 */
	private static final String closedTaskStatus
	{
		get
		{
			if(closedTaskStatus == null)
			{
				TaskStatus status = (TaskStatus)QRY_Builder.selectFrom(TaskStatus.SObjectType)
						.systemModeInternal()
						.addField(TaskStatus.MasterLabel)
						.condition(TaskStatus.IsClosed).equals(true)
						.getFirst();

				closedTaskStatus = status?.MasterLabel ?? 'Completed';
			}

			return closedTaskStatus;
		}
		set;
	}

	/**
	 * @description Main entry point for processing a batch of email requests.
	 * Iterates through requests, performs validation, constructs emails, and invokes the sender Flow.
	 *
	 * @param emailRequests List of request DTOs passed from the `FLOW_SendEmail` class.
	 *
	 * @return List of response DTOs mapping 1-to-1 with the input requests.
	 */
	public static List<FLOW_SendEmail.DTO_Response> processEmailRequests(List<FLOW_SendEmail.DTO_Request> emailRequests)
	{
		Set<String> orgWideEmailAddresses = new Set<String>();
		Set<String> templateUniqueNames = new Set<String>();
		Set<Id> recipientIds = new Set<Id>();

		// Bulkify: Collect all required external references
		for(FLOW_SendEmail.DTO_Request emailRequest : emailRequests)
		{
			if(String.isNotBlank(emailRequest.orgWideEmailAddress))
			{
				orgWideEmailAddresses.add(emailRequest.orgWideEmailAddress);
			}
			if(String.isNotBlank(emailRequest.templateUniqueName))
			{
				templateUniqueNames.add(emailRequest.templateUniqueName);
			}
			Id toId = UTIL_SObject.validateId(emailRequest.toAddress);
			if(toId != null)
			{
				recipientIds.add(toId);
			}
		}

		// Query configuration data
		List<OrgWideEmailAddress> orgWideAddresses = new SEL_OrgWideEmailAddress().findByName(orgWideEmailAddresses);
		Map<String, SObject> orgWideEmailMap = UTIL_SObject.indexByStringKey(orgWideAddresses, OrgWideEmailAddress.Address);

		List<EmailTemplate> emailTemplates = new SEL_EmailTemplate().findByName(templateUniqueNames);
		Map<String, SObject> templateMap = UTIL_SObject.indexByStringKey(emailTemplates, EmailTemplate.DeveloperName);

		//Map IDs to Email Addresses (Used when standard logging is False)
		Map<Id, String> recipientEmailMap = getRecipientEmails(recipientIds);

		List<FLOW_SendEmail.DTO_Response> dtoResponses = new List<FLOW_SendEmail.DTO_Response>();
		Map<Integer, Task> requestIndexToFlowTask = new Map<Integer, Task>();

		// Process each request
		for(Integer requestIndex = 0; requestIndex < emailRequests.size(); requestIndex++)
		{
			FLOW_SendEmail.DTO_Request dtoRequest = emailRequests[requestIndex];
			FLOW_SendEmail.DTO_Response dtoResponse = new FLOW_SendEmail.DTO_Response();
			dtoResponse.success = true;

			// Compute recipient identity once per request
			Id recipientId = UTIL_SObject.validateId(dtoRequest.toAddress);
			String recipientObjectName = recipientId != null ? UTIL_SObjectDescribe.getObjectNameFromId(recipientId) : null;

			String validationErrorMessage = validateRequest(dtoRequest, templateMap, recipientId, recipientObjectName);
			if(String.isNotBlank(validationErrorMessage))
			{
				dtoResponse.success = false;
				dtoResponse.errors = validationErrorMessage;
				dtoResponses.add(dtoResponse);
				continue;
			}

			Messaging.SingleEmailMessage mergedEmail;
			try
			{
				mergedEmail = constructEmail(dtoRequest, templateMap, recipientId, recipientObjectName);
			}
			catch(Exception error)
			{
				dtoResponse.success = false;
				dtoResponse.errors = 'Email Construction Failed: ' + error.getMessage();
				dtoResponses.add(dtoResponse);
				LOG_Builder.build().error(dtoResponse.errors).at(FLOW_SendEmailInternal.class.getName() + '/processEmailRequests').emit();
				continue;
			}

			// Determine the actual address to pass to the Flow
			String flowToAddress = dtoRequest.toAddress;

			// If NOT using standard logging, we must pass an Email Address, not an ID.
			// The Flow Action ignores Ids if logActivity=false (the "0 recipients" error).
			if(!UTIL_Boolean.isTrue(dtoRequest.useStandardLogActivity))
			{
				flowToAddress = recipientEmailMap.get(recipientId);

				// Fallback: If we couldn't find an email (e.g. Contact has no email set), pass the original ID.
				// This allows the Flow or system to throw the natural error rather than sending null.
				flowToAddress = flowToAddress ?? dtoRequest.toAddress;
			}

			String flowErrorMessage = invokeFlow
					(
							dtoRequest,
							simulateFailedFlowExecution ? 'INVALID_FLOW_NAME' : FLOW_EMAIL_SENDER_API_NAME,
							mergedEmail,
							orgWideEmailMap,
							flowToAddress
					);

			if(String.isNotBlank(flowErrorMessage))
			{
				dtoResponse.success = false;
				dtoResponse.errors = flowErrorMessage;
			}
			else if(!UTIL_Boolean.isTrue(dtoRequest.useStandardLogActivity) && UTIL_Boolean.isTrue(dtoRequest.saveAsActivity) && String.isNotBlank(dtoRequest.whatId))
			{
				Task task = (Task)TST_Builder.of(Task.SObjectType)
						.withOptionalField(Task.Priority)
						.withOverride(Task.ActivityDate, Date.today())
						.withOverride(Task.Description, 'Email sent via Workflow Engine (' + FLOW_EMAIL_SENDER_API_NAME + ') using Template: ' + dtoRequest.templateUniqueName)
						.withOverride(Task.Status, closedTaskStatus)
						.withOverride(Task.Subject, 'Email Sent: ' + dtoRequest.templateUniqueName)
						.withOverride(Task.WhatId, simulateFailedActivityLogging ? UserInfo.getUserId() : dtoRequest.whatId)
						.withOverride(Task.WhoId, PERSON_OBJECT_NAMES.contains(recipientObjectName) ? dtoRequest.toAddress : null)
						.withoutInsertion()
						.build();

				requestIndexToFlowTask.put(requestIndex, task);
			}

			dtoResponses.add(dtoResponse);
		}

		// Activity Logging (Batch DML)
		handleActivityLogging(requestIndexToFlowTask, dtoResponses);

		return dtoResponses;
	}

	/**
	 * @description Retrieves email addresses for a set of Contact, Lead, or User IDs.
	 * This is required to support the "Standard Logging = False" flow path, which requires a raw email string.
	 *
	 * @param recipientIds Set of IDs to resolve.
	 *
	 * @return Map of RecordId to Email Address.
	 */
	private static Map<Id, String> getRecipientEmails(Set<Id> recipientIds)
	{
		Map<String, Set<Id>> objectNameToIdMap = new Map<String, Set<Id>>();

		for(Id recipientId : recipientIds)
		{
			String objectName = UTIL_SObjectDescribe.getObjectNameFromId(recipientId);

			if(PERSON_OBJECT_NAMES.contains(objectName))
			{
				Set<Id> objectIds = objectNameToIdMap.get(objectName);

				if(objectIds == null)
				{
					objectIds = new Set<Id>();
					objectNameToIdMap.put(objectName, objectIds);
				}

				objectIds.add(recipientId);
			}
		}

		Map<Id, String> recipientEmailByIdMap = new Map<Id, String>();
		final String emailField = 'Email';

		for(String objectName : objectNameToIdMap.keySet())
		{
			Set<Id> objectIds = objectNameToIdMap.get(objectName);

			for(SObject foundObject : QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectName))
					.withSystemMode()
					.fields(new List<String> {emailField})
					.condition('Id').isIn(new List<Id>(objectIds))
					.toList())
			{
				recipientEmailByIdMap.put(foundObject.Id, String.valueOf(foundObject.get(emailField)));
			}
		}

		return recipientEmailByIdMap;
	}

	/**
	 * @description Handles the bulk insertion of Task records for successful emails.
	 * Updates the corresponding `DTO_Response` if the Task insertion fails.
	 *
	 * @param requestIndexToFlowTask Map of Request Index to the Task object to insert.
	 * @param dtoResponses The list of response objects to update in case of DML errors.
	 */
	private static void handleActivityLogging(Map<Integer, Task> requestIndexToFlowTask, List<FLOW_SendEmail.DTO_Response> dtoResponses)
	{
		List<Task> tasksToInsert = requestIndexToFlowTask.values();
		if(!tasksToInsert.isEmpty())
		{
			List<Database.SaveResult> dmlResults = Database.insert(tasksToInsert, false, AccessLevel.SYSTEM_MODE);

			Integer taskIndex = 0;
			for(Integer requestIndex : requestIndexToFlowTask.keySet())
			{
				Database.SaveResult saveResult = dmlResults[taskIndex];
				taskIndex++;

				FLOW_SendEmail.DTO_Response response = dtoResponses[requestIndex];

				if(!saveResult.isSuccess())
				{
					response.success = false;
					response.errors = (response.errors != null ? response.errors + UTIL_String.LF : UTIL_String.EMPTY) +
							'Activity Logging Failed: ' +
							LOG_Engine.extractErrorMessage(saveResult.errors);

					LOG_Builder.build()
							.error('Activity insertion failed for request index ' + requestIndex + UTIL_String.COLON + response.errors)
							.at(FLOW_SendEmailInternal.class.getName() + '/handleActivityLogging')
							.emit();
				}
			}
		}
	}

	/**
	 * @description Validates the request against environment capabilities and configuration.
	 *
	 * **Robustness Note:** This method checks `UTIL_Email.getEmailDeliverabilityAccessLevel()`.
	 * If the Org has email disabled (`NO_ACCESS`), this method will fail gracefully.
	 * However, if `Test.isRunningTest()` is true, it *bypasses* the failure to allow unit tests
	 * to cover the downstream logic (Flow invocation, email construction) even in restricted Sandboxes.
	 *
	 * @param request The email request DTO.
	 * @param templateMap Map of available EmailTemplate SObjects.
	 * @param recipientId The resolved recipient ID, or null if the toAddress is an email string.
	 * @param recipientObjectName The SObject API name of the recipient ID, or null.
	 *
	 * @return Error message string if validation fails; `null` if successful.
	 */
	private static String validateRequest(FLOW_SendEmail.DTO_Request request, Map<String, SObject> templateMap, Id recipientId, String recipientObjectName)
	{
		List<String> messages = new List<String>();

		UTIL_Email.DeliverabilityAccessLevel accessLevel = UTIL_Email.getEmailDeliverabilityAccessLevel();

		if((accessLevel != UTIL_Email.DeliverabilityAccessLevel.ALL_EMAIL && !Test.isRunningTest()) || simulateRestrictedDeliverability)
		{
			messages.add('Email Deliverability is disabled or restricted (Level: ' + accessLevel.name() + '). Cannot send.');
		}

		if(!templateMap.containsKey(request.templateUniqueName))
		{
			messages.add('Email Template not found: ' + request.templateUniqueName);
		}

		if(recipientId != null && !PERSON_OBJECT_NAMES.contains(recipientObjectName))
		{
			messages.add('Invalid To Address ID (' + recipientObjectName + '). Must be a Contact, Lead, User Id or a valid Email Address.');
		}

		return UTIL_String.join(messages, UTIL_String.COMMA);
	}

	/**
	 * @description Invokes the `FLOW_SendEmail` Flow to handle the actual email delivery.
	 *
	 * @param request The email request DTO.
	 * @param flowApiName The API name of the Flow.
	 * @param mergedEmail The constructed `SingleEmailMessage` with merged content.
	 * @param orgWideEmailMap Map of valid Org Wide Email Addresses.
	 * @param targetAddress The resolved address to send to. If Standard Logging is OFF, this will be an Email Address string.
	 *
	 * @return Error message string if the Flow throws an exception; `null` if successful.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static String invokeFlow
			(
					FLOW_SendEmail.DTO_Request request,
					String flowApiName,
					Messaging.SingleEmailMessage mergedEmail,
					Map<String, SObject> orgWideEmailMap,
					String targetAddress
			)
	{
		Map<String, Object> flowVariables = new Map<String, Object>();

		flowVariables.put('varFileIds', request.fileIds ?? new List<Id>());
		flowVariables.put('varHtmlBody', mergedEmail.getHtmlBody() ?? UTIL_String.EMPTY);
		flowVariables.put('varOrgWideEmailAddress', orgWideEmailMap.containsKey(request.orgWideEmailAddress) ? request.orgWideEmailAddress : UserInfo.getUserEmail());
		flowVariables.put('varRelatedId', request.whatId);
		flowVariables.put('varSaveAsActivity', UTIL_Boolean.isTrue(request.useStandardLogActivity) ? UTIL_Boolean.isTrue(request.saveAsActivity) : false);
		flowVariables.put('varSubject', mergedEmail.getSubject());
		flowVariables.put('varTextBody', mergedEmail.getPlainTextBody() ?? UTIL_String.EMPTY);
		flowVariables.put('varToAddress', targetAddress ?? UTIL_String.EMPTY);

		try
		{
			String prefixedFlowName = UTIL_System.getManagedPackageNamespace() + UTIL_String.DOUBLE_UNDERSCORE + flowApiName;
			Flow.Interview flowInterview = UTIL_System.createInterview(prefixedFlowName, flowVariables);
			flowInterview.start();
			return null;
		}
		catch(Exception error)
		{
			LOG_Builder.build().error('Flow ' + flowApiName + ' failed: ' + error.getMessage()).at(FLOW_SendEmailInternal.class.getName() + '/invokeFlow').emit();
			return 'Flow Invocation Failed: ' + error.getMessage();
		}
	}

	/**
	 * @description Constructs the `Messaging.SingleEmailMessage` object.
	 * Renders the stored Salesforce Email Template and applies custom `[key]` replacements.
	 *
	 * @param emailRequest The email request DTO.
	 * @param templateMap Map of EmailTemplate SObjects.
	 * @param recipientId The resolved recipient ID, or null if the toAddress is an email string.
	 * @param recipientObjectName The SObject API name of the recipient ID, or null.
	 *
	 * @return A fully constructed and merged email message object.
	 */
	@SuppressWarnings('PMD.ValidateCrudFlsEmailMessageWhoIdWhatId')
	private static Messaging.SingleEmailMessage constructEmail(FLOW_SendEmail.DTO_Request emailRequest, Map<String, SObject> templateMap, Id recipientId, String recipientObjectName)
	{
		Id targetObjectId = PERSON_OBJECT_NAMES.contains(recipientObjectName) ? recipientId : null;

		targetObjectId = targetObjectId == null && PERSON_OBJECT_NAMES.contains(UTIL_SObjectDescribe.getObjectNameFromId(emailRequest.whatId)) ?
				emailRequest.whatId : targetObjectId;

		Messaging.SingleEmailMessage emailMessage = Messaging.renderStoredEmailTemplate
				(
						templateMap.get(emailRequest.templateUniqueName)?.Id,
						targetObjectId,
						emailRequest.whatId,
						Messaging.AttachmentRetrievalOption.METADATA_ONLY
				);

		// Apply Custom Merge Fields (overriding standard template rendering)
		emailMessage.setSubject(replaceMergeFields(emailMessage.getSubject(), emailRequest.mergeFields));
		emailMessage.setHtmlBody(replaceMergeFields(emailMessage.getHtmlBody(), emailRequest.mergeFields));
		emailMessage.setPlainTextBody(replaceMergeFields(emailMessage.getPlainTextBody(), emailRequest.mergeFields));

		return emailMessage;
	}

	/**
	 * @description Helper method to replace custom placeholders (format `[key]`) in email content.
	 *
	 * @param emailBody The text content to process.
	 * @param mergeFields List of name-value pairs for replacement.
	 *
	 * @return The processed string with replacements applied.
	 */
	private static String replaceMergeFields(String emailBody, List<DTO_NameValue> mergeFields)
	{
		String replacedBody = emailBody;
		if(mergeFields?.isEmpty() == false && String.isNotBlank(replacedBody))
		{
			for(DTO_NameValue mergeField : mergeFields)
			{
				replacedBody = replacedBody.replace('[' + mergeField.name + ']', mergeField.value ?? UTIL_String.EMPTY);
			}
		}
		return replacedBody;
	}
}