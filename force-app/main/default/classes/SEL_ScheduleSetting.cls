// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The SEL_ScheduleSetting class provides methods for retrieving ScheduleSetting__c
 * records based on specified criteria. It enables streamlined access to scheduling configurations
 * stored within custom objects, facilitating easier scheduling management across the system.
 *
 * @see ScheduleSetting__c
 * @see SEL_ScheduleSetting_TEST
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_ScheduleSetting
{
	/**
	 * @description Retrieves a ScheduleSetting__c record based on the provided schedule name. This method
	 * is useful for accessing specific scheduling configurations, which may include parameters or
	 * settings that define scheduling operations within the system.
	 *
	 * @param scheduleName The unique name of the Schedule Setting to retrieve.
	 *
	 * @return ScheduleSetting__c The ScheduleSetting__c record that matches the specified schedule name,
	 * or null if no matching record is found.
	 *
	 * @example
	 * ```apex
	 * // Retrieve a schedule setting by name
	 * ScheduleSetting__c scheduleSetting = SEL_ScheduleSetting.getScheduleSetting('DailySchedule');
	 * if(scheduleSetting != null)
	 * {
	 *     System.debug('Found Schedule Setting: ' + scheduleSetting.Name);
	 * }
	 * else
	 * {
	 *     System.debug('Schedule Setting not found');
	 * }
	 * ```
	 */
	public static ScheduleSetting__c getScheduleSetting(String scheduleName)
	{
		return ScheduleSetting__c.getValues(scheduleName);
	}
}