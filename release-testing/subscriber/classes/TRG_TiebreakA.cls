// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tied Before Insert trigger action for the 1.2 deterministic-ordering proof.
 * Wired to the CMDT TriggerAction whose DeveloperName is Account_Tiebreak_B; records marker
 * 'B' when SubscriberTiebreakRecorder.recording is set. The class name (TRG_TiebreakA) is
 * deliberately reverse-sorted relative to its DeveloperName so the test can prove the tiebreak
 * key is the CMDT DeveloperName, not the Apex class name.
 *
 * @see Subscriber_TriggerActionTiebreak_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date June 2026, October 2026
 */
public inherited sharing class TRG_TiebreakA extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
{
	/**
	 * @description Adds the marker "B" to SubscriberTiebreakRecorder.order when recording is on, so the test can read the
	 * order in which the tied actions ran. Does nothing otherwise, so other Account inserts are not affected.
	 *
	 * @param newRecords The Accounts being inserted; unused.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		if(SubscriberTiebreakRecorder.recording)
		{
			SubscriberTiebreakRecorder.order.add('B');
		}
	}
}
