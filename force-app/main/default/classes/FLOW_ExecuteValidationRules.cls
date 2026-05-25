// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Flow invocable action to execute validation rules against records.
 * Use this in Record-Triggered Flows or Screen Flows to validate records before DML
 * and display user-friendly error messages.
 *
 * **Usage in Screen Flow (Pre-DML Validation):**
 * 1. User fills in fields on a screen
 * 2. Before "Create Records" element, add "Action" element
 * 3. Call this invocable with the record(s) to validate
 * 4. Check HasErrors output - if true, display errors and loop back to edit screen
 * 5. If false, proceed to Create Records
 *
 * @see UTIL_ValidationRule
 * @see FLOW_BypassValidation
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Flow Configuration:
 * Action: Execute Validation Rules
 * Input:
 *   - Records: {!$Record} or collection
 *   - TriggerContext: BEFORE_INSERT
 *   - OldRecords: (leave empty for insert; use {!$Record__Prior} for update)
 * Output:
 *   - HasErrors: Boolean - check in Decision element
 *   - HasWarnings: Boolean - check for non-blocking warnings
 *   - Errors: List<DTO_FlowValidationError> - display in lwcValidationErrors component
 *   - Warnings: List<DTO_FlowValidationError> - display shadow mode or warning-severity results
 *   - ErrorMessage: String - concatenated message for simple display
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_ExecuteValidationRules
{
	/**
	 * @description Executes validation rules against the provided records.
	 *
	 * @param requests List of validation requests (typically just one from Flow)
	 *
	 * @return List of validation responses with errors and warnings
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Programmatic usage example
	 * FLOW_ExecuteValidationRules.DTO_Request request = new FLOW_ExecuteValidationRules.DTO_Request();
	 * request.records = new List<SObject>{account};
	 * request.triggerContext = 'BEFORE_INSERT';
	 * List<FLOW_ExecuteValidationRules.DTO_Response> responses =
	 *     FLOW_ExecuteValidationRules.execute(new List<FLOW_ExecuteValidationRules.DTO_Request>{request});
	 * if(responses[0].hasErrors)
	 * {
	 *     // Handle validation errors
	 * }
	 * ```
	 */
	@InvocableMethod
	(
			Category='Validation'
			Label='Execute Validation Rules'
			Description='Validates records against formula-driven validation rules. Returns errors/warnings without blocking save.'
	)
	global static List<DTO_Response> execute(List<DTO_Request> requests)
	{
		List<DTO_Response> responses = new List<DTO_Response>();

		for(DTO_Request request : requests)
		{
			responses.add(processRequest(request));
		}

		return responses;
	}

	/**
	 * @description Processes a single validation request.
	 *
	 * @param request The validation request
	 *
	 * @return The validation response
	 */
	private static DTO_Response processRequest(DTO_Request request)
	{
		DTO_Response response = new DTO_Response();
		response.errors = new List<DTO_FlowValidationError>();
		response.warnings = new List<DTO_FlowValidationError>();

		if(request.records == null || request.records.isEmpty())
		{
			response.hasErrors = false;
			response.hasWarnings = false;
			response.errorMessage = '';
			return response;
		}

		// Determine trigger operation from context string
		TriggerOperation operation = resolveTriggerOperation(request.triggerContext);

		// Execute validation
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						request.records,
						request.oldRecords,
						operation
				);

		// Process results into Flow-friendly format
		List<String> errorMessages = new List<String>();
		Boolean hasBlockingErrors = false;
		Boolean hasWarnings = false;

		for(UTIL_ValidationRule.ValidationResult result : results)
		{
			for(UTIL_ValidationRule.ValidationError error : result.errors)
			{
				DTO_FlowValidationError flowError = new DTO_FlowValidationError();
				flowError.ruleName = error.ruleName;
				flowError.message = error.message;
				flowError.fieldName = error.fieldName;
				flowError.severity = error.severity;
				flowError.recordIndex = error.recordIndex;
				flowError.isShadowMode = error.shadowMode;

				if(error.severity == UTIL_ValidationRule.SEVERITY_ERROR && !error.shadowMode)
				{
					response.errors.add(flowError);
					errorMessages.add(error.message);
					hasBlockingErrors = true;
				}
				else if(error.severity == UTIL_ValidationRule.SEVERITY_WARNING || error.shadowMode)
				{
					response.warnings.add(flowError);
					hasWarnings = true;
				}
			}
		}

		response.hasErrors = hasBlockingErrors;
		response.hasWarnings = hasWarnings;
		response.errorMessage = String.join(errorMessages, '\n');

		return response;
	}

	/**
	 * @description Resolves a trigger context string to a TriggerOperation enum.
	 *
	 * @param contextString The context string matching TriggerOperation enum values:
	 * BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE, AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, or AFTER_UNDELETE
	 *
	 * @return The TriggerOperation enum value, defaults to BEFORE_INSERT if blank
	 *
	 * @throws System.NoSuchElementException if the context string does not match a valid TriggerOperation value
	 */
	private static TriggerOperation resolveTriggerOperation(String contextString)
	{
		if(String.isBlank(contextString))
		{
			return TriggerOperation.BEFORE_INSERT;
		}

		return TriggerOperation.valueOf(contextString.trim().toUpperCase());
	}

	/**
	 * @description Request DTO for the Execute Validation Rules invocable action.
	 * Contains the records to validate and the trigger context for rule evaluation.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The new/current records to validate. For insert operations, these are the records
		 * being created. For update operations, these are the records with their new field values.
		 * For delete operations, these are the records being deleted. This field is required.
		 *
		 * @since 1.0
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				Label='Records'
				Description='The new/current records to validate. For insert: the records being created. For update: the records with new values. For delete: the records being deleted.'
				Required=true
		)
		global List<SObject> records;

		/**
		 * @description The previous record values before the change. Required for BEFORE_UPDATE and
		 * AFTER_UPDATE operations to enable change detection in validation formulas (e.g., ISCHANGED,
		 * PRIORVALUE functions). Leave empty for insert, delete, and undelete operations.
		 * In Record-Triggered Flows, use {!$Record__Prior} to populate this field.
		 *
		 * @since 1.0
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				Label='Old Records'
				Description='The previous record values before the change. Required for BEFORE_UPDATE and AFTER_UPDATE to enable change detection in validation formulas. Leave empty for insert, delete, and undelete operations.'
		)
		global List<SObject> oldRecords;

		/**
		 * @description The trigger operation context that determines which validation rules to execute.
		 * Must match a TriggerOperation enum value: BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
		 * AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, or AFTER_UNDELETE. Defaults to BEFORE_INSERT
		 * if not specified.
		 *
		 * @since 1.0
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				Label='Trigger Context'
				Description='The trigger operation context matching TriggerOperation enum: BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE, AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, or AFTER_UNDELETE.'
				DefaultValue='BEFORE_INSERT'
				PlaceholderText='BEFORE_INSERT'
		)
		global String triggerContext;
	}

	/**
	 * @description Response DTO for the Execute Validation Rules invocable action.
	 * Contains the validation results including errors, warnings, and summary flags.
	 * Use hasErrors in a Decision element to determine whether to proceed with DML or display errors.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Response
	{
		/**
		 * @description True if any blocking validation errors occurred. Use this in a Flow Decision
		 * element to determine whether to proceed with record save or redirect back to edit screen.
		 * Only errors with severity 'Error' that are not in shadow mode are considered blocking.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.hasErrors;
		 * ```
		 */
		@InvocableVariable(Label='Has Errors' Description='True if validation failed with blocking errors')
		global Boolean hasErrors;

		/**
		 * @description True if any warnings occurred. Warnings include validation rules with severity
		 * 'Warning' and rules running in shadow mode. These do not block the save operation but may
		 * be displayed to users for informational purposes.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.hasWarnings;
		 * ```
		 */
		@InvocableVariable(Label='Has Warnings' Description='True if validation produced warnings')
		global Boolean hasWarnings;

		/**
		 * @description Combined error message string containing all blocking error messages joined
		 * by newlines. Useful for simple text display in a Flow screen when you don't need to show
		 * individual field-level errors. Empty string if no errors occurred.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.errorMessage;
		 * ```
		 */
		@InvocableVariable(Label='Error Message' Description='Combined error message for simple display')
		global String errorMessage;

		/**
		 * @description List of blocking validation errors. Each error contains the rule name, message,
		 * field name, severity, and record index. Display these in a custom LWC component like
		 * lwcValidationErrors for detailed field-level error presentation.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<DTO_FlowValidationError> value = instance.errors;
		 * ```
		 */
		@InvocableVariable(Label='Errors' Description='List of blocking validation errors')
		global List<DTO_FlowValidationError> errors;

		/**
		 * @description List of validation warnings. Includes both warning-severity rules and errors
		 * from rules running in shadow mode. Shadow mode errors are captured here for monitoring
		 * purposes without blocking the save operation.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<DTO_FlowValidationError> value = instance.warnings;
		 * ```
		 */
		@InvocableVariable(Label='Warnings' Description='List of validation warnings')
		global List<DTO_FlowValidationError> warnings;
	}
}