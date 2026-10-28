// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawSchedule_Negative
{
	public static void scheduleThroughFramework()
	{
		ScheduledJob__c job = new ScheduledJob__c(Name = 'Nightly');
		System.scheduleBatch(null, 'Nightly', 10);
	}
}
