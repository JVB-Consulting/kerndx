// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ScheduledJob__c SObject. Provides default field configuration
 * and query methods for scheduled job records.
 *
 * @see SEL_Base
 * @see SEL_ScheduledJob_TEST
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_ScheduledJob extends SEL_Base
{
	/**
	 * @description Constructs a ScheduledJob selector.
	 */
	public SEL_ScheduledJob()
	{
		super(ScheduledJob__c.SObjectType);
	}

	/**
	 * @description Returns the core fields for ScheduledJob__c queries.
	 *
	 * @return List of ScheduledJob__c SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				ScheduledJob__c.Parameters__c,
				ScheduledJob__c.ClassName__c,
				ScheduledJob__c.CronExpression__c,
				ScheduledJob__c.Description__c,
				ScheduledJob__c.IsActive__c,
				ScheduledJob__c.Name,
				ScheduledJob__c.ScheduledJobId__c,
				ScheduledJob__c.SchedulerName__c,
				ScheduledJob__c.Timezone__c
		};
	}

	/**
	 * @description Framework-owned sObject selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on framework-owned scheduling records (the framework owns their lifecycle), so
	 * USER_MODE reads would return empty and schedulers would fail to resolve their jobs.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds active scheduled jobs for a given Apex class name.
	 *
	 * @param className The fully qualified Apex class name
	 *
	 * @return List of active ScheduledJob__c records for the class
	 */
	public List<ScheduledJob__c> findActiveByClassName(String className)
	{
		return query
				.condition(ScheduledJob__c.IsActive__c).equals(true)
				.condition(ScheduledJob__c.ClassName__c).equals(className)
				.toList();
	}
}