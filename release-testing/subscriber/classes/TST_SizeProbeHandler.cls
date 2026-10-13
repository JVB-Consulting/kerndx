// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test processing logic for a batch the framework launches, to prove the batch size comes from the
 * `kern__AsynchronousJobSetting__mdt` record named after this class. That record sets 75, a size that does not divide
 * the chunk of 100 rows the platform reads, so the launch also writes the framework's batch-size WARN. Each call ticks
 * the Checkbox field on the Foobar rows it receives, so section 75d can tell every row was processed.
 *
 * @author Jason van Beukering
 *
 * @group Release Testing
 *
 * @date October 2026
 */
public with sharing class TST_SizeProbeHandler implements kern.IF_Async.Processable
{
	/**
	 * @description Ticks the Checkbox field on each Foobar row of this call.
	 *
	 * @param items The Foobar rows of this call.
	 */
	public void execute(List<Object> items)
	{
		List<kern__Foobar__c> records = new List<kern__Foobar__c>();
		for(Object item : items)
		{
			records.add(new kern__Foobar__c(Id = ((kern__Foobar__c)item).Id, kern__Checkbox__c = true));
		}

		kern.DML_Builder.newTransaction()
				.doUpdate(records)
				.execute();
	}
}
