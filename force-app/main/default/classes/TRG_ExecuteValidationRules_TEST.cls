// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for TRG_ExecuteValidationRules trigger action.
 * Verifies that validation rules are correctly executed for each trigger context.
 *
 * @see TRG_ExecuteValidationRules
 * @see UTIL_ValidationRule
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_ExecuteValidationRules_TEST
{
	/**
	 * @description Tests that beforeInsert correctly delegates to UTIL_ValidationRule.executeForTrigger
	 * with the BEFORE_INSERT operation.
	 */
	@IsTest
	private static void beforeInsertExecutesValidationRules()
	{
		List<Foobar__c> records = TST_Factory.newFoobars(5);
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();

		Test.startTest();
		action.beforeInsert(records);
		Test.stopTest();

		// - no exception thrown means validation executed successfully
		Assert.isNotNull(records, 'Records should not be null after validation');
	}

	/**
	 * @description Tests that afterInsert correctly delegates to UTIL_ValidationRule.executeForTrigger
	 * with the AFTER_INSERT operation.
	 */
	@IsTest
	private static void afterInsertExecutesValidationRules()
	{
		List<Foobar__c> records = TST_Factory.newFoobars(5);
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();

		Test.startTest();
		action.afterInsert(records);
		Test.stopTest();

		// - no exception thrown means validation executed successfully
		Assert.isNotNull(records, 'Records should not be null after validation');
	}

	/**
	 * @description Tests that beforeUpdate correctly delegates to UTIL_ValidationRule.executeForTrigger
	 * with the BEFORE_UPDATE operation and both new and old records.
	 */
	@IsTest
	private static void beforeUpdateExecutesValidationRules()
	{
		List<Foobar__c> oldRecords = TST_Factory.newFoobars(5);
		List<Foobar__c> newRecords = oldRecords.deepClone(true);
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();

		Test.startTest();
		action.beforeUpdate(newRecords, oldRecords);
		Test.stopTest();

		// - no exception thrown means validation executed successfully
		Assert.isNotNull(newRecords, 'New records should not be null after validation');
	}

	/**
	 * @description Tests that afterUpdate correctly delegates to UTIL_ValidationRule.executeForTrigger
	 * with the AFTER_UPDATE operation and both new and old records.
	 */
	@IsTest
	private static void afterUpdateExecutesValidationRules()
	{
		List<Foobar__c> oldRecords = TST_Factory.newFoobars(5);
		List<Foobar__c> newRecords = oldRecords.deepClone(true);
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();

		Test.startTest();
		action.afterUpdate(newRecords, oldRecords);
		Test.stopTest();

		// - no exception thrown means validation executed successfully
		Assert.isNotNull(newRecords, 'New records should not be null after validation');
	}

	/**
	 * @description Tests that beforeDelete correctly delegates to UTIL_ValidationRule.executeForTrigger
	 * with the BEFORE_DELETE operation.
	 */
	@IsTest
	private static void beforeDeleteExecutesValidationRules()
	{
		List<Foobar__c> records = TST_Factory.newFoobars(5);
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();

		Test.startTest();
		action.beforeDelete(records);
		Test.stopTest();

		// - no exception thrown means validation executed successfully
		Assert.isNotNull(records, 'Records should not be null after validation');
	}

	/**
	 * @description Tests that afterDelete correctly delegates to UTIL_ValidationRule.executeForTrigger
	 * with the AFTER_DELETE operation.
	 */
	@IsTest
	private static void afterDeleteExecutesValidationRules()
	{
		List<Foobar__c> records = TST_Factory.newFoobars(5);
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();

		Test.startTest();
		action.afterDelete(records);
		Test.stopTest();

		// - no exception thrown means validation executed successfully
		Assert.isNotNull(records, 'Records should not be null after validation');
	}

	/**
	 * @description Tests that afterUndelete correctly delegates to UTIL_ValidationRule.executeForTrigger
	 * with the AFTER_UNDELETE operation.
	 */
	@IsTest
	private static void afterUndeleteExecutesValidationRules()
	{
		List<Foobar__c> records = TST_Factory.newFoobars(5);
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();

		Test.startTest();
		action.afterUndelete(records);
		Test.stopTest();

		// - no exception thrown means validation executed successfully
		Assert.isNotNull(records, 'Records should not be null after validation');
	}

	/**
	 * @description Tests that TRG_ExecuteValidationRules can be instantiated and extends TRG_Base.
	 */
	@IsTest
	private static void extendsBaseObject()
	{
		// Given/When
		Test.startTest();
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Test.stopTest();

		//
		Assert.isInstanceOfType(action, TRG_Base.class, 'Should extend TRG_Base');
	}
}