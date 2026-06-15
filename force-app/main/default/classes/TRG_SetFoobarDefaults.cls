// SPDX-License-Identifier: BUSL-1.1
/**
 * @description An example Trigger Action class that acts on the "Foobar" Object and used to test the trigger action framework
 *
 * @see TRG_SetFoobarDefaults_TEST
 * @see TRG_Base
 * @see IF_Trigger
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, June 2026
 */
public inherited sharing class TRG_SetFoobarDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
{
	@TestVisible
	private static Boolean insertNewFoo = false;
	@TestVisible
	private static final String DUMMY_TEXT_VALUE = '827432bc-9ccf-4ff3-af35-14a968ac0450';

	/**
	 * @description Action to be performed before the provided objects are inserted
	 *
	 * @param newFoobars Items being inserted
	 */
	public void beforeInsert(List<Foobar__c> newFoobars)
	{
		for(Foobar__c newFoobar : newFoobars)
		{
			//Don't do this behaviour unless we're running a test
			if(Test.isRunningTest())
			{
				newFoobar.Text__c = DUMMY_TEXT_VALUE;
			}

			//Insert item, this should not result in a second call to trigger action; used to test recursion
			if(insertNewFoo)
			{
				DML_Builder.newTransaction().systemModeInternal().doInsert(TST_Factory.newFoobar()).execute();
			}
		}
	}
}