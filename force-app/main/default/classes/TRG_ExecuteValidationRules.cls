// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Pre-built trigger action that executes formula-driven validation rules.
 * This class implements all trigger interfaces and automatically executes validation rules
 * configured via ValidationRuleGroup__mdt and ValidationRule__mdt for the current trigger context.
 *
 * **Subscriber Org Setup:**
 * 1. Create TriggerSetting__mdt for your object (if not already exists)
 * 2. Create TriggerAction__mdt pointing to `kern.TRG_ExecuteValidationRules`
 * 3. Configure ValidationRuleGroup__mdt linked to your TriggerSetting
 * 4. Create ValidationRule__mdt records with formulas and error messages
 *
 * @see UTIL_ValidationRule
 * @see ValidationRuleGroup__mdt
 * @see ValidationRule__mdt
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
 * // TriggerAction__mdt configuration (no code required)
 * DeveloperName: Execute_Account_Validation_Rules
 * MasterLabel: Execute Account Validation Rules
 * ApexClassName__c: kern.TRG_ExecuteValidationRules
 * TriggerSetting__c: Account_Trigger_Setting
 * Event__c: Before Insert
 * Order__c: 10
 * Description__c: Executes formula-driven validation rules for Account records
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class TRG_ExecuteValidationRules extends TRG_Base implements
				IF_Trigger.BeforeInsert,
				IF_Trigger.AfterInsert,
				IF_Trigger.BeforeUpdate,
				IF_Trigger.AfterUpdate,
				IF_Trigger.BeforeDelete,
				IF_Trigger.AfterDelete,
				IF_Trigger.AfterUndelete
{
	/**
	 * @description Executes validation rules before new records are inserted.
	 *
	 * @param newRecords The list of new records to validate
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.beforeInsert(records);
	 * ```
	 */
	global void beforeInsert(List<SObject> newRecords)
	{
		UTIL_ValidationRule.executeForTrigger(newRecords, null, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Executes validation rules after new records are inserted.
	 * Typically used for warning-only validations that log but don't block.
	 *
	 * @param newRecords The list of newly inserted records
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.afterInsert(records);
	 * ```
	 */
	global void afterInsert(List<SObject> newRecords)
	{
		UTIL_ValidationRule.executeForTrigger(newRecords, null, TriggerOperation.AFTER_INSERT);
	}

	/**
	 * @description Executes validation rules before records are updated.
	 *
	 * @param newRecords The list of records with new values
	 * @param oldRecords The list of records with old values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.beforeUpdate(records, records);
	 * ```
	 */
	global void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		UTIL_ValidationRule.executeForTrigger(newRecords, oldRecords, TriggerOperation.BEFORE_UPDATE);
	}

	/**
	 * @description Executes validation rules after records are updated.
	 * Typically used for warning-only validations that log but don't block.
	 *
	 * @param newRecords The list of records with new values
	 * @param oldRecords The list of records with old values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.afterUpdate(records, records);
	 * ```
	 */
	global void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		UTIL_ValidationRule.executeForTrigger(newRecords, oldRecords, TriggerOperation.AFTER_UPDATE);
	}

	/**
	 * @description Executes validation rules before records are deleted.
	 *
	 * @param oldRecords The list of records to be deleted
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.beforeDelete(records);
	 * ```
	 */
	global void beforeDelete(List<SObject> oldRecords)
	{
		UTIL_ValidationRule.executeForTrigger(oldRecords, null, TriggerOperation.BEFORE_DELETE);
	}

	/**
	 * @description Executes validation rules after records are deleted.
	 * Typically used for warning-only validations that log but don't block.
	 *
	 * @param oldRecords The list of deleted records
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.afterDelete(records);
	 * ```
	 */
	global void afterDelete(List<SObject> oldRecords)
	{
		UTIL_ValidationRule.executeForTrigger(oldRecords, null, TriggerOperation.AFTER_DELETE);
	}

	/**
	 * @description Executes validation rules after records are undeleted.
	 * Typically used for warning-only validations that log but don't block.
	 *
	 * @param newRecords The list of undeleted records
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.afterUndelete(records);
	 * ```
	 */
	global void afterUndelete(List<SObject> newRecords)
	{
		UTIL_ValidationRule.executeForTrigger(newRecords, null, TriggerOperation.AFTER_UNDELETE);
	}
}