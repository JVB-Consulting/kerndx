// SPDX-License-Identifier: Apache-2.0
/**
 * @description Archives old cases each time it runs. It is the scheduled job sample of the Why KernDX page, word for
 * word. An admin chooses how many days of cases to keep on its Scheduled Job record.
 *
 * @see DocumentationSamplesFrontPage_TEST
 * @see CaseArchiveService
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
// global: KernDX creates this class by name, from its Scheduled Job record
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class CaseArchiveJob extends kern.SCHED_Base
{
	/**
	 * @description Declares the one setting an admin can change: how many days of cases to keep.
	 *
	 * @return The setting, a number that is 90 unless the admin changes it.
	 */
	public override List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>
		{
				kern.DTO_ScheduledParameterDefinition.of('daysToKeep', 'Days to keep').asNumeric().withDefault('90')
		};
	}

	/**
	 * @description Archives the cases older than the number of days to keep.
	 *
	 * @param context The context the platform passes to a scheduled job.
	 */
	public void execute(SchedulableContext context)
	{
		CaseArchiveService.archiveOlderThan(getNumericParameter('daysToKeep'));
	}
}
