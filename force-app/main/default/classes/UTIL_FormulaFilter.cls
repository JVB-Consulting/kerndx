// SPDX-License-Identifier: Apache-2.0
/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Modifications copyright (c) 2026 JVB Consulting.
 */

/**
 * @description Class that can filter list of SObject based on Formula Information provided
 * adapted from:[apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions)
 *
 * @see UTIL_FormulaFilter_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date April 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_FormulaFilter filter = new UTIL_FormulaFilter(
 *     'MyProcess', 'UTIL_FormulaContext.AccountContext', 'newRecord.Industry == "Technology"'
 * );
 * UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(oldRecords, newRecords);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_FormulaFilter
{
	private final String contextClassName;
	private final String formula;
	private final String processName;
	private static final String ERROR_ENTRY_CRITERIA_CONFIGURATION = 'Building a Formula Instance for process "{0}", Context Class "{1}" and Formula "{2}" ' +
			'failed with the following error\n\n{3}';

	/**
	 * @description Mapping of standard object SObjectTypes to pre-built context class Types.
	 * Uses inner classes within UTIL_FormulaContext for centralized management.
	 * Only includes objects available in ALL Salesforce editions (including Essentials/Starter).
	 *
	 * Using SObjectType and Type ensures proper namespace resolution in managed packages.
	 * Type.getName() automatically includes the namespace prefix when running in a subscriber org.
	 *
	 * All inner classes use the 'Context' suffix for consistency (e.g., AccountContext, ContactContext).
	 * This naming pattern also naturally avoids Apex reserved word conflicts with `Case` and `User`.
	 */
	@TestVisible
	private static final Map<SObjectType, Type> STANDARD_OBJECT_CONTEXT_TYPES = new Map<SObjectType, Type>
	{
			// Tier 1: Universal Objects (ALL Editions)
			Account.SObjectType => UTIL_FormulaContext.AccountContext.class,
			Contact.SObjectType => UTIL_FormulaContext.ContactContext.class,
			Lead.SObjectType => UTIL_FormulaContext.LeadContext.class,
			Opportunity.SObjectType => UTIL_FormulaContext.OpportunityContext.class,
			Case.SObjectType => UTIL_FormulaContext.CaseContext.class,
			Campaign.SObjectType => UTIL_FormulaContext.CampaignContext.class,
			Task.SObjectType => UTIL_FormulaContext.TaskContext.class,
			Event.SObjectType => UTIL_FormulaContext.EventContext.class,
			User.SObjectType => UTIL_FormulaContext.UserContext.class,
			// Note: Quote, Order, Contract, Product2 require Professional+ edition

			// Package Test Object - enables comprehensive formula evaluation testing
			Foobar__c.SObjectType => UTIL_FormulaContext.FoobarContext.class
	};

	/**
	 * @description Constructs a new instance with the formula details
	 *
	 * @param processName The name of the process calling the filter, will be used if an error is generated during process so logging will be specific
	 * @param contextClassName The class that will provide the relevant variables, context to the formula.
	 * @param formula The boolean formula to execute
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_FormulaFilter instance = new UTIL_FormulaFilter('value', 'value', 'RecordType.Name = \'Default\'');
	 * ```
	 */
	global UTIL_FormulaFilter(String processName, String contextClassName, String formula)
	{
		this.contextClassName = contextClassName;
		this.formula = formula;
		this.processName = processName;
	}

	/**
	 * @description Filters the given lists of new and old SObjects based on the entry criteria formula.
	 * 
	 * This method evaluates the entry criteria formula for each record in the `triggerNew` and `triggerOld`.
	 * If the formula evaluates to true for a record, it is included in the filtered lists.
	 *
	 * _NOTE: Make sure that if both the old and new records lists are not null they are the same size_
	 *
	 * @param oldRecords The list of old SObjects to filter.
	 * @param newRecords The list of new SObjects to filter.
	 *
	 * @return An object containing the filtered lists of new and old SObjects.
	 *
	 * @throws Exception Exception could be thrown if the any of the formula build method's fail
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_FilterResults result = instance.filter(records, records);
	 * ```
	 */
	global DTO_FilterResults filter(List<SObject> oldRecords, List<SObject> newRecords)
	{
		DTO_FilterResults dtoFilterResults = new DTO_FilterResults();

		if(String.isBlank(contextClassName) || String.isBlank(formula))
		{
			dtoFilterResults.oldRecords = oldRecords;
			dtoFilterResults.newRecords = newRecords;

			return dtoFilterResults;
		}

		Type evaluationContextClass = UTIL_System.getTypeForClassName(contextClassName, INT_SObjectFormulaEvaluationContext.class);

		FormulaEval.FormulaInstance formulaInstance = getFormulaInstance(evaluationContextClass);
		INT_SObjectFormulaEvaluationContext evaluationContext = (INT_SObjectFormulaEvaluationContext)evaluationContextClass.newInstance();

		Integer numberOfRecords = (newRecords?.size() ?? oldRecords?.size()) ?? 0;

		for(Integer i = 0; i < numberOfRecords; i++)
		{
			SObject newRecord = newRecords?.get(i);
			SObject oldRecord = oldRecords?.get(i);

			evaluationContext.setContext(oldRecord, newRecord);

			if((Boolean)formulaInstance.evaluate(evaluationContext))
			{
				if(oldRecord != null)
				{
					dtoFilterResults.oldRecords.add(oldRecord);
				}

				if(newRecord != null)
				{
					dtoFilterResults.newRecords.add(newRecord);
				}
			}
		}

		return dtoFilterResults;
	}

	/**
	 * @description Will initialise a formula instance to be re-used for evaluating a formula across multiple SObjects.
	 * Delegates to the shared buildBooleanFormula() method for consistent formula building.
	 *
	 * @param formulaContextType The Type of the context class
	 *
	 * @return An initialised Instance
	 *
	 * @throws Exception Exception could be thrown if the any of the formula build method's fail
	 */
	private FormulaEval.FormulaInstance getFormulaInstance(Type formulaContextType)
	{
		return buildBooleanFormula(formula, formulaContextType, processName);
	}

	/**
	 * @description Inner class representing the result of the `filter` method.
	 *
	 * @see UTIL_FormulaFilter.filter
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_FilterResults
	{
		/**
		 * @description The filtered list of new SObjects.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> value = instance.oldRecords;
		 * ```
		 */
		global List<SObject> oldRecords
		{
			get
			{
				if(oldRecords == null)
				{
					oldRecords = new List<SObject>();
				}

				return oldRecords;
			}
			set;
		}

		/**
		 * @description The filtered list of old SObjects.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<SObject> value = instance.newRecords;
		 * ```
		 */
		global List<SObject> newRecords
		{
			get
			{
				if(newRecords == null)
				{
					newRecords = new List<SObject>();
				}

				return newRecords;
			}
			set;
		}
	}

	/**
	 * @description Builds a reusable FormulaInstance for boolean formula evaluation.
	 * Centralizes formula building logic used by both UTIL_FormulaFilter and UTIL_ValidationRule.
	 *
	 * @param formulaExpression The boolean formula string to evaluate
	 * @param contextType The Type of the formula context class
	 * @param processName Name of the calling process for error reporting
	 *
	 * @return Initialized FormulaInstance ready for evaluation
	 *
	 * @throws Exception If formula building fails
	 *
	 * @example
	 * ```apex
	 * Type contextType = UTIL_System.getTypeForClassName('UTIL_FormulaContext.AccountContext');
	 * FormulaEval.FormulaInstance formula = UTIL_FormulaFilter.buildBooleanFormula(
	 *     'newRecord.Industry == "Technology"',
	 *     contextType,
	 *     'MyValidation'
	 * );
	 * Boolean result = (Boolean)formula.evaluate(context);
	 * ```
	 */
	public static FormulaEval.FormulaInstance buildBooleanFormula(String formulaExpression, Type contextType, String processName)
	{
		try
		{
			return Formula.builder()
					.treatNumericNullAsZero(true)
					.withFormula(formulaExpression)
					.withGlobalVariables(FormulaEval.FormulaGlobal.values())
					.withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
					.withType(contextType)
					.build();
		}
		catch(Exception error)
		{
			error.setMessage
					(
							String.format
									(
											ERROR_ENTRY_CRITERIA_CONFIGURATION,
											new List<String> {processName ?? 'not defined', contextType?.getName() ?? 'null', formulaExpression, error.getMessage()}
									)
					);
			LOG_Builder.build().error(error).at(UTIL_FormulaFilter.class.getName() + '/buildBooleanFormula').emit();

			throw error;
		}
	}

	/**
	 * @description Creates a new instance of a formula evaluation context.
	 *
	 * @param contextClassName The fully qualified class name of the context
	 *
	 * @return New instance of the context class
	 *
	 * @throws TypeException If the class cannot be found or instantiated
	 *
	 * @example
	 * ```apex
	 * INT_SObjectFormulaEvaluationContext context =
	 *     UTIL_FormulaFilter.newContextInstance('UTIL_FormulaContext.AccountContext');
	 * context.setContext(oldAccount, newAccount);
	 * ```
	 */
	public static INT_SObjectFormulaEvaluationContext newContextInstance(String contextClassName)
	{
		Type contextType = UTIL_System.getTypeForClassName(contextClassName, INT_SObjectFormulaEvaluationContext.class);
		return (INT_SObjectFormulaEvaluationContext)contextType.newInstance();
	}

	/**
	 * @description Resolves context class name for formula evaluation.
	 * If contextClass is specified, uses it. Otherwise, auto-detects for standard objects.
	 *
	 * **Namespace Handling:** Uses Type.getName() which automatically includes the namespace
	 * prefix when running in a managed package context. This ensures proper resolution in subscriber orgs.
	 *
	 * @param objectType The SObjectType to resolve context for (e.g., Account.SObjectType)
	 * @param specifiedContextClass The explicitly configured context class (may be blank)
	 *
	 * @return The context class name to use, or null if no context class is available
	 *
	 * @example
	 * ```apex
	 * // Standard object - auto-detects
	 * String contextClass = UTIL_FormulaFilter.resolveContextClass(Account.SObjectType, null);
	 * // Returns: 'kern.UTIL_FormulaContext.AccountContext' (in managed package)
	 * // Custom object - requires explicit class
	 * String contextClass = UTIL_FormulaFilter.resolveContextClass(MyObject__c.SObjectType, 'CTX_MyObject');
	 * // Returns: 'CTX_MyObject'
	 * // Custom object without explicit class - returns null
	 * String contextClass = UTIL_FormulaFilter.resolveContextClass(MyObject__c.SObjectType, null);
	 * // Returns: null
	 * ```
	 */
	public static String resolveContextClass(SObjectType objectType, String specifiedContextClass)
	{
		// Explicit override takes precedence
		if(String.isNotBlank(specifiedContextClass))
		{
			return specifiedContextClass;
		}

		// Auto-detect for standard objects using Type.getName() for proper namespace resolution
		Type contextType = STANDARD_OBJECT_CONTEXT_TYPES.get(objectType);
		return contextType?.getName();
	}

	/**
	 * @description Resolves context class name for formula evaluation using object API name.
	 * If contextClass is specified, uses it. Otherwise, auto-detects for standard objects.
	 *
	 * This overload accepts a String object API name and resolves it to SObjectType internally.
	 * Use the SObjectType overload when possible for better type safety.
	 *
	 * @param objectApiName The SObject API name (e.g., 'Account', 'Contact', 'MyObject__c')
	 * @param specifiedContextClass The explicitly configured context class (may be blank)
	 *
	 * @return The context class name to use, or null if no context class is available
	 *
	 * @example
	 * ```apex
	 * // Standard object - auto-detects
	 * String contextClass = UTIL_FormulaFilter.resolveContextClass('Account', null);
	 * // Returns: 'kern.UTIL_FormulaContext.AccountContext' (in managed package)
	 * ```
	 */
	public static String resolveContextClass(String objectApiName, String specifiedContextClass)
	{
		// Explicit override takes precedence
		if(String.isNotBlank(specifiedContextClass))
		{
			return specifiedContextClass;
		}

		// Resolve object API name to SObjectType and delegate to main method
		SObjectType objectType = UTIL_SObjectDescribe.getGlobalDescribe().get(objectApiName);
		return resolveContextClass(objectType, null);
	}

	/**
	 * @description Interface for providing context data to dynamic formula evaluations using Salesforce's FormulaEval namespace.
	 * Implementing classes supply the necessary context for evaluating formulas using SObjects.
	 *
	 * @see FormulaEval.FormulaInstance.evaluate
	 *
	 * @since 1.0
	 */
	global interface INT_SObjectFormulaEvaluationContext
	{

		/**
		 * @description Sets the context for formula evaluation by providing the current and previous states of the SObject record being processed.
		 * This method is invoked during trigger execution to supply the formula with relevant data for evaluation.
		 *
		 * @param oldRecord The state of the record before the DML operation.
		 * @param newRecord The state of the record after the DML operation.
		 *
		 * @since 1.0
		 */
		void setContext(SObject oldRecord, SObject newRecord);
	}
}