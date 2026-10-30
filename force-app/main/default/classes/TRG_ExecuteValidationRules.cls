// SPDX-License-Identifier: Apache-2.0
/**
 * @description Pre-built trigger action that executes formula-driven validation rules.
 * This class implements all trigger interfaces and automatically executes validation rules
 * configured via ValidationRuleGroup__mdt and ValidationRule__mdt for the current trigger context.
 *
 * **Setup in your org:**
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
 * @date January 2026, October 2026
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
	 * @description Checks the new records against the Before Insert validation rules set up for their
	 * object. A failed rule of Error severity stops the save and shows its message on the record. A failed Warning
	 * rule, or a rule with Shadow Mode turned on, is only logged.
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
	 * @description Checks the saved records against the After Insert validation rules set up for their object.
	 * A failed rule of Error severity rolls the save back and shows its message on the record. A failed Warning
	 * rule, or a rule with Shadow Mode turned on, is only logged.
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
	 * @description Checks the changed records against the Before Update validation rules set up for their
	 * object. A failed rule of Error severity stops the save and shows its message on the record. A failed Warning
	 * rule, or a rule with Shadow Mode turned on, is only logged.
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
	 * @description Checks the saved records against the After Update validation rules set up for their object.
	 * A failed rule of Error severity rolls the save back and shows its message on the record. A failed Warning
	 * rule, or a rule with Shadow Mode turned on, is only logged.
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
	 * @description Checks the records about to be deleted against the Before Delete validation rules set up for their
	 * object. A failed rule of Error severity stops the delete and shows its message on the record. A failed Warning
	 * rule, or a rule with Shadow Mode turned on, is only logged.
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
	 * @description Checks the deleted records against the After Delete validation rules set up for their object.
	 * A failed rule of Error severity rolls the delete back and shows its message on the record. A failed Warning
	 * rule, or a rule with Shadow Mode turned on, is only logged.
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
	 * @description Checks the restored records against the After Undelete validation rules set up for their object.
	 * A failed rule of Error severity rolls the restore back and shows its message on the record. A failed Warning
	 * rule, or a rule with Shadow Mode turned on, is only logged.
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