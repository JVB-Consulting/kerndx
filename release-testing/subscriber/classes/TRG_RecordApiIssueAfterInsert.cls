// SPDX-License-Identifier: Apache-2.0
/**
 * @description Release-test trigger action on the framework's API Issue object. It runs after insert and writes down
 * each call in static counters: how many times it was called, how many records it received in all, and the service
 * name of each record. The release-test section reads these counters straight after its insert, in the same
 * transaction, to prove that a subscriber's after-insert row on a framework object runs, once per group of up to 200
 * records, and only for the records its entry formula lets through.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date November 2026
 */
public inherited sharing class TRG_RecordApiIssueAfterInsert extends kern.TRG_Base implements kern.IF_Trigger.AfterInsert
{
	/**
	 * @description How many times the framework called this action in this transaction.
	 */
	public static Integer callCount = 0;

	/**
	 * @description How many records this action received in all, over every call in this transaction.
	 */
	public static Integer recordCount = 0;

	/**
	 * @description The service name of every record this action received in this transaction.
	 */
	public static Set<String> receivedServiceNames = new Set<String>();

	/**
	 * @description Sets the counters back to zero. The section calls this before each insert, so each check reads only
	 * the calls that insert caused.
	 */
	public static void reset()
	{
		callCount = 0;
		recordCount = 0;
		receivedServiceNames = new Set<String>();
	}

	/**
	 * @description Writes down one call and the records it received.
	 *
	 * @param newRecords The API issues that were inserted and that the entry formula let through.
	 */
	public void afterInsert(List<SObject> newRecords)
	{
		callCount++;
		recordCount += newRecords.size();
		for(SObject record : newRecords)
		{
			receivedServiceNames.add(((kern__ApiIssue__c)record).kern__ServiceName__c);
		}
	}
}
