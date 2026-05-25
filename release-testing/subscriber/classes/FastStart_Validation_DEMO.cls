// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Demonstrates KernDX custom validation rules in the subscriber namespace.
 *              Wraps a DML_Builder insert so that deployed ValidationRule__mdt records
 *              (group FastStart_AccountRules) fire automatically when the trigger framework
 *              is active.
 *
 * @see FastStart_Validation_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_Validation_DEMO
{
	/**
	 * @description Inserts the supplied Account using DML_Builder and returns the
	 *              transaction result. Validation rules fire at the trigger layer if a
	 *              TriggerAction__mdt record wires TRG_ExecuteValidationRules to the object.
	 *
	 * @param account The Account record to insert.
	 *
	 * @return The DML_Builder.TransactionResult from the insert operation.
	 */
	public kern.DML_Builder.TransactionResult validateAndSave(Account account)
	{
		return kern.DML_Builder.newTransaction().doInsert(account).allowPartial().execute();
	}
}
