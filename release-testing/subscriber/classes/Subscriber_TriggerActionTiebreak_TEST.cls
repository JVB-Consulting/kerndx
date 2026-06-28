// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber proof for the 1.2 deterministic trigger-action tiebreak. When two
 * trigger actions share an Order__c value, the framework sequences them by Order__c first and
 * then by CMDT DeveloperName ascending, so the order is stable on every run and in every org.
 *
 * Two Before Insert actions on Account share Order__c = 250:
 *   - DeveloperName Account_Tiebreak_A -> class TRG_TiebreakZ -> records 'A'
 *   - DeveloperName Account_Tiebreak_B -> class TRG_TiebreakA -> records 'B'
 *
 * Both the backing Apex class names (TRG_TiebreakZ for the A action, TRG_TiebreakA for the B
 * action) and the CMDT MasterLabels ("...Z..." for A, "...A..." for B) are deliberately
 * reverse-sorted relative to the DeveloperNames, so asserting the sequence ['A','B'] pins the
 * tiebreak key to the CMDT DeveloperName specifically — class-name or label ordering would both
 * yield ['B','A']. The actions stay inert for the rest of the suite via the
 * SubscriberTiebreakRecorder.recording gate.
 *
 * @see SubscriberTiebreakRecorder
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class Subscriber_TriggerActionTiebreak_TEST
{
	/**
	 * @description Verifies two actions sharing Order__c run in CMDT DeveloperName order.
	 */
	@IsTest
	private static void shouldBreakOrderTieByDeveloperNameAscending()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
		SubscriberTiebreakRecorder.recording = true;
		SubscriberTiebreakRecorder.order.clear();

		Test.startTest();
		insert new Account(Name = 'Tiebreak Probe');
		Test.stopTest();

		Assert.areEqual(2, SubscriberTiebreakRecorder.order.size(),
				'Both tied Before Insert actions should have run; got: ' + SubscriberTiebreakRecorder.order);
		Assert.areEqual('A', SubscriberTiebreakRecorder.order[0],
				'The action whose DeveloperName sorts first (Account_Tiebreak_A) should run first');
		Assert.areEqual('B', SubscriberTiebreakRecorder.order[1],
				'The action whose DeveloperName sorts second (Account_Tiebreak_B) should run second');
	}
}
