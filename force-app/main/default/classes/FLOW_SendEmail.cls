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
 * @date February 2026, May 2026
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
			Category='Email'
			Label='Send Email (Flow-Delegated) and Log Activity'
			Description='Sends an email using a template by delegating to an internal Flow. Optionally logs an activity, using either standard email limits or the Workflow Engine.'
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
				Label='To Address or Target WhoId'
				Description='The Id of the Contact, Lead, or User, or the recipient email address. Used to resolve "TargetObjectId".'
				Required=false
		)
		global String toAddress;

		/**
		 * @description The DeveloperName of the Email Template.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Email Template Unique Name'
				Description='The unique name (DeveloperName) of the email template to generate the email content.'
				Required=true
		)
		global String templateUniqueName;

		/**
		 * @description The email address defined in Organization-Wide Email Addresses to be used as the sender.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Sender Org Wide Email Address'
				Description='The org-wide email address to be used as the sender (From address).'
				Required=true
		)
		global String orgWideEmailAddress;

		/**
		 * @description The ID of the record that the email is related to (e.g., Opportunity, Case). Used for merge fields.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Related To WhatId'
				Description='The Id of a record related to the email for merge field data (WhatId).'
				Required=true
		)
		global Id whatId;

		/**
		 * @description A list of ContentVersion IDs to attach to the email.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='List of File Ids for Attachments'
				Description='A list of ContentVersion or Document Ids to attach as files to the email.'
				Required=false
		)
		global List<Id> fileIds;

		/**
		 * @description Determines if a Task should be created.
		 * Note: This is ignored if `whatId` is null or if `useStandardLogActivity` is enabled (which handles logging natively).
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Save as Activity'
				Description='Indicates if an activity (Task) should be logged against the Related To Id (WhatId). Ignored if Related To Id is null.'
				DefaultValue='false'
				PlaceholderText='false'
		)
		global Boolean saveAsActivity;

		/**
		 * @description A list of custom key-value pairs to replace placeholders in the email body (e.g., `[InvoiceNumber]`).
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Custom Merge Fields'
				Description='List of name-value pairs for custom merge fields to replace in the email body. Placeholders must be in the format [mergefieldname].'
				Required=false
		)
		global List<DTO_NameValue> mergeFields;

		/**
		 * @description Controls the mechanism used for Activity Logging.
		 * - `true`: Uses standard `Messaging.SingleEmailMessage` activity logging (counts towards limits).
		 * - `false`: Uses a custom Task insertion approach (via Workflow Engine/Flow).
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Use Standard Activity Logging'
				Description='If True, standard activity logging is used. If False, custom activity logging is performed via the internal Flow.'
				DefaultValue='false'
				PlaceholderText='false'
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
				Label='Send Successful'
				Description='Indicates whether the email was successfully submitted (true) or failed validation/internal process (false).'
				Required=true
		)
		global Boolean success;

		/**
		 * @description Detailed error message if `success` is `false`.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Errors'
				Description='A string of errors encountered during the email send or activity logging attempt.'
				Required=false
		)
		global String errors;
	}
}