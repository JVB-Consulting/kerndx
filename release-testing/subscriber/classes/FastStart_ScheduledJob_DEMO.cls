// SPDX-License-Identifier: Apache-2.0
/**
 * @description A scheduled job for the Fast Start - Scheduled Jobs guide. A ScheduledJob__c record runs it on a
 * schedule, on a scheduled job of its own or on the job runner. Its one parameter, Fail on purpose, makes a run throw,
 * so you can see a failed run and the log entry it leaves.
 *
 * The class is global so the managed package can create it from its name, and it declares no constructor: the
 * framework can only use the constructor Apex provides when none is declared.
 *
 * @see FastStart_ScheduledJob_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date October 2026
 */
global inherited sharing class FastStart_ScheduledJob_DEMO extends kern.SCHED_Base
{
	/**
	 * @description Name of the switch that makes a run fail on purpose.
	 */
	public static final String PARAMETER_FAIL_ON_PURPOSE = 'failOnPurpose';

	/**
	 * @description Label the Scheduled Jobs editor shows beside the switch.
	 */
	private static final String LABEL_FAIL_ON_PURPOSE = 'Fail on purpose';

	/**
	 * @description What a run that fails on purpose throws, and what its log entry says.
	 */
	public static final String FAILED_ON_PURPOSE_MESSAGE = 'FastStart_ScheduledJob_DEMO failed on purpose, because Fail on purpose is switched on.';

	/**
	 * @description Declares the one parameter, which the editor shows as a switch, off unless you switch it on.
	 *
	 * @return The parameter definitions.
	 */
	public override List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>
		{
				kern.DTO_ScheduledParameterDefinition.of(PARAMETER_FAIL_ON_PURPOSE, LABEL_FAIL_ON_PURPOSE).asBoolean().withDefault(String.valueOf(false))
		};
	}

	/**
	 * @description Runs the job. It does nothing unless Fail on purpose is on; then it throws, so the run is recorded
	 * as Failed.
	 *
	 * @param context The scheduling context the platform or the job runner passes in.
	 */
	public void execute(SchedulableContext context)
	{
		if(getBooleanParameter(PARAMETER_FAIL_ON_PURPOSE))
		{
			throw new FailedOnPurposeException(FAILED_ON_PURPOSE_MESSAGE);
		}
	}

	/**
	 * @description Thrown by a run that fails on purpose.
	 */
	public class FailedOnPurposeException extends Exception
	{
	}
}
