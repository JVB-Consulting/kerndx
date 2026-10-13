// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides an invocable entry point for sending emails via Salesforce Flow with advanced capabilities.
 * Supports:
 * - Hybrid execution (Direct Apex or delegating to a secondary Flow).
 * - Custom Merge Fields (replacing `[placeholder]` text).
 * - Conditional Activity Logging (using standard `TargetObjectId` or the Workflow Engine).
 *
 * @see FLOW_SendEmailInternal
 * @see FLOW_SendEmail_TEST
 *
 * @author Jason van Beukering
 *
 * @group Email
 *
 * @date February 2026, September 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * FLOW_SendEmail.DTO_Request request = new FLOW_SendEmail.DTO_Request();
 * request.toAddress = 'customer@example.com';
 * request.templateUniqueName = 'Customer_Welcome_Email';
 * request.orgWideEmailAddress = 'noreply@company.com';
 * request.whatId = opportunityId;
 * request.saveAsActivity = true;
 * List<FLOW_SendEmail.DTO_Response> responses = FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request> {request});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_SendEmail
{
	/**
	 * @description Invocable method to process email requests.
	 *
	 * @param dtoEmails A list of `DTO_Request` objects configured in the Flow.
	 *
	 * @return A list of `DTO_Response` objects indicating success or failure for each request.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * FLOW_SendEmail.DTO_Request emailRequest = new FLOW_SendEmail.DTO_Request();
	 * emailRequest.toAddress = 'customer@example.com';
	 * emailRequest.templateUniqueName = 'Customer_Welcome_Email';
	 * emailRequest.orgWideEmailAddress = 'noreply@company.com';
	 * emailRequest.whatId = opportunityId;
	 * emailRequest.saveAsActivity = true;
	 * List<FLOW_SendEmail.DTO_Response> responses = FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request>{emailRequest});
	 * if(responses[0].success)
	 * {
	 * 	LOG_Builder.build().info('Email sent successfully').emitAt('MyFlow.sendEmail');
	 * }
	 * ```
	 */
	@InvocableMethod
	(
			category='Email'
			label='Send Email (Flow-Delegated) and Log Activity'
			description='Sends an email using a template by delegating to an internal Flow. Optionally logs an activity, using either standard email limits or the Workflow Engine.'
	)
	global static List<DTO_Response> sendEmail(List<DTO_Request> dtoEmails)
	{
		return FLOW_SendEmailInternal.processEmailRequests(dtoEmails);
	}

	/**
	 * @description Data Transfer Object (DTO) representing the input parameters for a single email request.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The recipient. Can be a standard Email Address or the Salesforce ID of a Contact, Lead, or User.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='To Address or Target WhoId'
				description='The Id of the Contact, Lead, or User, or the recipient email address. Used to resolve "TargetObjectId".'
				required=false
		)
		global String toAddress;

		/**
		 * @description The DeveloperName of the Email Template.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Email Template Unique Name'
				description='The unique name (DeveloperName) of the email template to generate the email content.'
				required=true
		)
		global String templateUniqueName;

		/**
		 * @description The email address defined in Organization-Wide Email Addresses to be used as the sender.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Sender Org Wide Email Address'
				description='The org-wide email address to be used as the sender (From address).'
				required=true
		)
		global String orgWideEmailAddress;

		/**
		 * @description The ID of the record that the email is related to (e.g., Opportunity, Case). Used for merge fields.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Related To WhatId'
				description='The Id of a record related to the email for merge field data (WhatId).'
				required=true
		)
		global Id whatId;

		/**
		 * @description A list of ContentVersion IDs to attach to the email.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='List of File Ids for Attachments'
				description='A list of ContentVersion or Document Ids to attach as files to the email.'
				required=false
		)
		global List<Id> fileIds;

		/**
		 * @description Whether the email is logged as an activity. With custom logging (`useStandardLogActivity`
		 * false) the framework inserts a Task against `whatId`, so a null `whatId` logs nothing. With standard logging
		 * Salesforce logs the email itself for a Contact or Lead recipient, and the recipient Id reaches the flow only
		 * when this is `true`; a User recipient is refused, because Salesforce does not log an email sent to a User.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Save as Activity'
				description='Log the email as an activity. Custom logging needs a Related To Id; standard logging needs a Contact or Lead recipient.'
				defaultValue='false'
				placeholderText='false'
		)
		global Boolean saveAsActivity;

		/**
		 * @description A list of custom key-value pairs to replace placeholders in the email body (e.g., `[InvoiceNumber]`).
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Custom Merge Fields'
				description='List of name-value pairs for custom merge fields to replace in the email body. Placeholders must be in the format [mergefieldname].'
				required=false
		)
		global List<DTO_NameValue> mergeFields;

		/**
		 * @description Controls the mechanism used for Activity Logging when `saveAsActivity` is `true`; without an
		 * activity wanted it has no effect, and the email is sent to the recipient's address. Standard logging needs a
		 * Contact or Lead recipient: Salesforce does not log an email sent to a User, so that request is refused. With
		 * custom logging a User recipient's Task is related to `whatId` only, because a Task cannot name a User as its WhoId.
		 * - `true`: Uses standard `Messaging.SingleEmailMessage` activity logging (counts towards limits).
		 * - `false`: Uses a custom Task insertion approach (via Workflow Engine/Flow).
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Use Standard Activity Logging'
				description='True: Salesforce logs the email (Contact or Lead recipients only). False: the framework logs a Task itself. Applies only with Save as Activity.'
				defaultValue='false'
				placeholderText='false'
		)
		global Boolean useStandardLogActivity;
	}

	/**
	 * @description Data Transfer Object (DTO) representing the outcome of an email request.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Response
	{
		/**
		 * @description `true` if the email was successfully handed off to the delivery mechanism; `false` otherwise.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Send Successful'
				description='Indicates whether the email was successfully submitted (true) or failed validation/internal process (false).'
				required=true
		)
		global Boolean success;

		/**
		 * @description Detailed error message if `success` is `false`.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Errors'
				description='A string of errors encountered during the email send or activity logging attempt.'
				required=false
		)
		global String errors;
	}
}