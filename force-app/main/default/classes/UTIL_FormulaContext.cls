// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Container for pre-built formula evaluation context classes for standard Salesforce objects.
 *
 * This class provides typed context implementations for Salesforce's `FormulaEval` namespace,
 * enabling dynamic formula evaluation against standard object records. These contexts can be used
 * in any scenario requiring formula evaluation, including but not limited to:
 *
 * - **Trigger Action Framework** - Entry criteria formulas on `TriggerAction__mdt`
 * - **Custom Business Rules** - Configurable filtering or validation logic
 * - **Flow Extensions** - Dynamic formula evaluation in Apex-backed Flow actions
 * - **Batch Processing** - Record filtering based on formula criteria
 *
 * **Supported Objects:** Account, Contact, Lead, Opportunity, Case, Campaign, Task, Event, User, Foobar__c (test object)
 *
 * **Formula Variable Names:**
 * - `oldRecord` - Record state BEFORE an operation (null when no prior state exists)
 * - `newRecord` - Record state AFTER an operation (null when record is being removed)
 *
 * Inner classes are GLOBAL because Salesforce `FormulaEval.FormulaInstance.evaluate()`
 * requires runtime access to context properties. The `global` visibility ensures
 * cross-namespace access when the managed package evaluates formulas in subscriber orgs.
 *
 * **Why global visibility is required:**
 * 1. Member variables must be accessible by FormulaEval at runtime
 * 2. For managed packages, `global` guarantees visibility across all scenarios
 * 3. Subscriber org context classes must also use `global` for the same reason
 *
 * @see UTIL_FormulaFilter
 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
 * @see FormulaEval.FormulaInstance
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date January 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Direct usage with Formula.builder()
 * FormulaEval.FormulaInstance formula = Formula.builder()
 *     .withFormula('newRecord.AnnualRevenue > 1000000 && newRecord.Industry = "Technology"')
 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
 *     .withType(UTIL_FormulaContext.AccountContext.class)
 *     .build();
 * UTIL_FormulaContext.AccountContext context = new UTIL_FormulaContext.AccountContext();
 * context.setContext(null, account);
 * Boolean matches = (Boolean)formula.evaluate(context);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_FormulaContext
{
	/**
	 * @description Formula evaluation context for Account object.
	 *
	 * Provides typed access to Account records in formula evaluations.
	 * The Trigger Action Framework automatically uses this context when `EntryCriteriaContextClassName__c`
	 * is blank on `TriggerAction__mdt` records for the Account object. This context can also be used
	 * directly in custom Apex code for any formula evaluation scenario.
	 *
	 * **Formula Variable Names:**
	 * - `oldRecord` - Account state before DML (null on insert)
	 * - `newRecord` - Account state after DML
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // --- Trigger Action Framework Usage ---
	 * // TriggerAction__mdt.EntryCriteriaFormula__c examples:
	 * // newRecord.Type = "Customer"
	 * // newRecord.Industry <> oldRecord.Industry
	 * // AND(newRecord.AnnualRevenue > 1000000, newRecord.Type = "Customer")
	 * // --- Direct Apex Usage (Batch, Validation, Custom Business Rules) ---
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.AnnualRevenue > 1000000 && newRecord.Industry = "Technology"')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.AccountContext.class)
	 *     .build();
	 * UTIL_FormulaContext.AccountContext context = new UTIL_FormulaContext.AccountContext();
	 * for(Account account : accounts)
	 * {
	 *     context.setContext(null, account);
	 *     if((Boolean)formula.evaluate(context))
	 *     {
	 *         // Account matches criteria
	 *     }
	 * }
	 * ```
	 */
	global inherited sharing class AccountContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description The Account record state BEFORE the DML operation.
		 * This property is null during insert operations since no prior record exists.
		 * Use `oldRecord.Id = null` in formulas to detect insert operations.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account value = instance.oldRecord;
		 * ```
		 */
		global Account oldRecord;

		/**
		 * @description The Account record state AFTER the DML operation.
		 * Contains the record with all field values as they will be saved to the database.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Account value = instance.newRecord;
		 * ```
		 */
		global Account newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Account records.
		 * Called by the framework before formula evaluation for each record.
		 *
		 * @param oldSObject The Account record before DML (null on insert)
		 * @param newSObject The Account record after DML (null on delete)
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Account)oldSObject;
			this.newRecord = (Account)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Contact object.
	 *
	 * Provides typed access to Contact records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.Email <> oldRecord.Email
	 * // ISBLANK(oldRecord.AccountId) && NOT(ISBLANK(newRecord.AccountId))
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.HasOptedOutOfEmail = false')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.ContactContext.class)
	 *     .build();
	 * UTIL_FormulaContext.ContactContext context = new UTIL_FormulaContext.ContactContext();
	 * context.setContext(null, contact); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class ContactContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Contact record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Contact value = instance.oldRecord;
		 * ```
		 */
		global Contact oldRecord;

		/**
		 * @description Contact record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Contact value = instance.newRecord;
		 * ```
		 */
		global Contact newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Contact records.
		 *
		 * @param oldSObject The Contact record before DML
		 * @param newSObject The Contact record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Contact)oldSObject;
			this.newRecord = (Contact)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Lead object.
	 *
	 * Provides typed access to Lead records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.Status = "Working"
	 * // newRecord.LeadSource <> oldRecord.LeadSource
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.IsConverted = false && newRecord.Status = "Qualified"')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.LeadContext.class)
	 *     .build();
	 * UTIL_FormulaContext.LeadContext context = new UTIL_FormulaContext.LeadContext();
	 * context.setContext(null, lead); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class LeadContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Lead record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Lead value = instance.oldRecord;
		 * ```
		 */
		global Lead oldRecord;

		/**
		 * @description Lead record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Lead value = instance.newRecord;
		 * ```
		 */
		global Lead newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Lead records.
		 *
		 * @param oldSObject The Lead record before DML
		 * @param newSObject The Lead record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Lead)oldSObject;
			this.newRecord = (Lead)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Opportunity object.
	 *
	 * Provides typed access to Opportunity records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.StageName <> oldRecord.StageName
	 * // newRecord.Amount > 100000 && newRecord.StageName = "Closed Won"
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.IsClosed && newRecord.IsWon')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.OpportunityContext.class)
	 *     .build();
	 * UTIL_FormulaContext.OpportunityContext context = new UTIL_FormulaContext.OpportunityContext();
	 * context.setContext(null, opportunity); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class OpportunityContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Opportunity record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Opportunity value = instance.oldRecord;
		 * ```
		 */
		global Opportunity oldRecord;

		/**
		 * @description Opportunity record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Opportunity value = instance.newRecord;
		 * ```
		 */
		global Opportunity newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Opportunity records.
		 *
		 * @param oldSObject The Opportunity record before DML
		 * @param newSObject The Opportunity record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Opportunity)oldSObject;
			this.newRecord = (Opportunity)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Case object.
	 *
	 * Provides typed access to Case records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * Note: Class is named `CaseContext` because `Case` is an Apex reserved keyword.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.Priority = "High"
	 * // newRecord.Status <> oldRecord.Status
	 * // newRecord.IsClosed && NOT(oldRecord.IsClosed)
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.IsEscalated && newRecord.Priority = "High"')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.CaseContext.class)
	 *     .build();
	 * UTIL_FormulaContext.CaseContext context = new UTIL_FormulaContext.CaseContext();
	 * context.setContext(null, caseRecord); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class CaseContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Case record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Case value = instance.oldRecord;
		 * ```
		 */
		global Case oldRecord;

		/**
		 * @description Case record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Case value = instance.newRecord;
		 * ```
		 */
		global Case newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Case records.
		 *
		 * @param oldSObject The Case record before DML
		 * @param newSObject The Case record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Case)oldSObject;
			this.newRecord = (Case)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Campaign object.
	 *
	 * Provides typed access to Campaign records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.IsActive = true
	 * // newRecord.Status <> oldRecord.Status
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.IsActive && newRecord.Type = "Email"')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.CampaignContext.class)
	 *     .build();
	 * UTIL_FormulaContext.CampaignContext context = new UTIL_FormulaContext.CampaignContext();
	 * context.setContext(null, campaign); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class CampaignContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Campaign record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Campaign value = instance.oldRecord;
		 * ```
		 */
		global Campaign oldRecord;

		/**
		 * @description Campaign record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Campaign value = instance.newRecord;
		 * ```
		 */
		global Campaign newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Campaign records.
		 *
		 * @param oldSObject The Campaign record before DML
		 * @param newSObject The Campaign record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Campaign)oldSObject;
			this.newRecord = (Campaign)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Task object.
	 *
	 * Provides typed access to Task records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.Status = "Completed"
	 * // newRecord.Priority = "High" && oldRecord.Status <> "Completed"
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.IsClosed && newRecord.Priority = "High"')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.TaskContext.class)
	 *     .build();
	 * UTIL_FormulaContext.TaskContext context = new UTIL_FormulaContext.TaskContext();
	 * context.setContext(null, task); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class TaskContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Task record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Task value = instance.oldRecord;
		 * ```
		 */
		global Task oldRecord;

		/**
		 * @description Task record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Task value = instance.newRecord;
		 * ```
		 */
		global Task newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Task records.
		 *
		 * @param oldSObject The Task record before DML
		 * @param newSObject The Task record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Task)oldSObject;
			this.newRecord = (Task)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Event object.
	 *
	 * Provides typed access to Event records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.IsAllDayEvent = true
	 * // newRecord.StartDateTime <> oldRecord.StartDateTime
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.IsAllDayEvent && newRecord.IsPrivate = false')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.EventContext.class)
	 *     .build();
	 * UTIL_FormulaContext.EventContext context = new UTIL_FormulaContext.EventContext();
	 * context.setContext(null, event); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class EventContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Event record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Event value = instance.oldRecord;
		 * ```
		 */
		global Event oldRecord;

		/**
		 * @description Event record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Event value = instance.newRecord;
		 * ```
		 */
		global Event newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Event records.
		 *
		 * @param oldSObject The Event record before DML
		 * @param newSObject The Event record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Event)oldSObject;
			this.newRecord = (Event)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for User object.
	 *
	 * Provides typed access to User records in formula evaluations.
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex.
	 *
	 * Note: Class is named `UserContext` because `User` is an Apex reserved keyword.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.IsActive <> oldRecord.IsActive
	 * // newRecord.ProfileId <> oldRecord.ProfileId
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.IsActive && newRecord.ReceivesAdminInfoEmails')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.UserContext.class)
	 *     .build();
	 * UTIL_FormulaContext.UserContext context = new UTIL_FormulaContext.UserContext();
	 * context.setContext(null, userRecord); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class UserContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description User record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * User value = instance.oldRecord;
		 * ```
		 */
		global User oldRecord;

		/**
		 * @description User record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * User value = instance.newRecord;
		 * ```
		 */
		global User newRecord;

		/**
		 * @description Sets the formula evaluation context with typed User records.
		 *
		 * @param oldSObject The User record before DML
		 * @param newSObject The User record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (User)oldSObject;
			this.newRecord = (User)newSObject;
		}
	}

	/**
	 * @description Formula evaluation context for Foobar__c test object.
	 *
	 * Provides typed access to Foobar__c records in formula evaluations.
	 * This context class enables comprehensive testing of formula evaluation
	 * functionality within the managed package without requiring subscriber-created classes.
	 *
	 * Auto-detected by Trigger Action Framework when `EntryCriteriaContextClassName__c` is blank.
	 * Can also be used directly in custom Apex for testing purposes.
	 *
	 * **Formula Variable Names:** `oldRecord`, `newRecord`
	 *
	 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Trigger Action Framework formulas:
	 * // newRecord.Checkbox__c = true
	 * // newRecord.NumberInteger__c > oldRecord.NumberInteger__c
	 * // newRecord.Picklist__c <> oldRecord.Picklist__c
	 * // Direct Apex usage:
	 * FormulaEval.FormulaInstance formula = Formula.builder()
	 *     .withFormula('newRecord.Checkbox__c && newRecord.NumberInteger__c > 100')
	 *     .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
	 *     .withType(UTIL_FormulaContext.FoobarContext.class)
	 *     .build();
	 * UTIL_FormulaContext.FoobarContext context = new UTIL_FormulaContext.FoobarContext();
	 * context.setContext(null, foobar); // null = no old record (insert scenario)
	 * Boolean matches = (Boolean)formula.evaluate(context);
	 * ```
	 */
	global inherited sharing class FoobarContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
	{
		/**
		 * @description Foobar__c record state BEFORE DML (null on insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Foobar__c value = instance.oldRecord;
		 * ```
		 */
		global Foobar__c oldRecord;

		/**
		 * @description Foobar__c record state AFTER DML (null on delete).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Foobar__c value = instance.newRecord;
		 * ```
		 */
		global Foobar__c newRecord;

		/**
		 * @description Sets the formula evaluation context with typed Foobar__c records.
		 *
		 * @param oldSObject The Foobar__c record before DML
		 * @param newSObject The Foobar__c record after DML
		 */
		public void setContext(SObject oldSObject, SObject newSObject)
		{
			this.oldRecord = (Foobar__c)oldSObject;
			this.newRecord = (Foobar__c)newSObject;
		}
	}
}