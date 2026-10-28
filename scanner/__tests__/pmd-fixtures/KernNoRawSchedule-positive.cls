// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawSchedule_Positive
{
	public static void scheduleRaw(Schedulable job)
	{
		System.schedule('Nightly', '0 0 2 * * ?', job);
		system.SCHEDULE('Hourly', '0 0 * * * ?', job);
	}
}
