// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger action that sets a default Description on new Account records.
 *
 * Extend kern.TRG_Base and implement kern.IF_Trigger.BeforeInsert. In before-insert
 * context, modify SObject fields directly — no DML required.
 *
 * @see FastStart_TriggerAction_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public inherited sharing class FastStart_TriggerAction_DEMO extends kern.TRG_Base
		implements kern.IF_Trigger.BeforeInsert
{
	/**
	 * @description Default description stamped on new Account records.
	 */
	@TestVisible
	private static final String DEFAULT_DESCRIPTION = 'Created via Fast Start';

	/**
	 * @description Stamps a default Description on each Account that has a blank Description.
	 *
	 * @param newRecords The list of Account records being inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account account = (Account)record;

			if(String.isBlank(Account.Description))
			{
				Account.Description = DEFAULT_DESCRIPTION;
			}
		}
	}
}
