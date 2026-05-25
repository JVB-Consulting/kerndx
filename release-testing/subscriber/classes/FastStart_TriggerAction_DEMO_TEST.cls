// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for FastStart_TriggerAction_DEMO trigger action.
 *
 * Tests invoke the handler directly (unit-style) rather than through the
 * TRG_Dispatcher metadata pipeline. Direct invocation avoids the subscriber-
 * namespace visibility limit on @TestVisible private TST_Factory.newTriggerSetting,
 * and keeps the test focused on the handler's logic.
 *
 * @see FastStart_TriggerAction_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_TriggerAction_DEMO_TEST
{
	/**
	 * @description Tests that Description is stamped when blank on insert.
	 */
	@IsTest
	private static void shouldStampDefaultDescriptionWhenBlank()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, null)
			.withoutInsertion()
			.build();

		new FastStart_TriggerAction_DEMO().beforeInsert(new List<SObject>{ record });

		Assert.areEqual
		(
			FastStart_TriggerAction_DEMO.DEFAULT_DESCRIPTION,
			record.Description,
			'Description should be stamped when blank'
		);
	}

	/**
	 * @description Tests that a pre-populated Description is not overwritten on insert.
	 */
	@IsTest
	private static void shouldPreserveDescriptionWhenAlreadySet()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, 'Custom description')
			.withoutInsertion()
			.build();

		new FastStart_TriggerAction_DEMO().beforeInsert(new List<SObject>{ record });

		Assert.areEqual
		(
			'Custom description',
			record.Description,
			'Pre-populated Description should not be overwritten'
		);
	}
}
