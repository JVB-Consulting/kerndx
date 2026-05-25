// SPDX-License-Identifier: BUSL-1.1
global inherited sharing class SCHED_SubscriberJob implements kern.IF_Schedulable
{
	public static Boolean executed = false;
	public static String resolvedObjectName;
	public static Integer resolvedBatchSize;
	public static Boolean resolvedDryRun;

	private kern.DTO_NameValues parameterValues;

	public List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>
		{
				kern.DTO_ScheduledParameterDefinition.of('objectName').required()
						.withDescription('API name of the SObject to process'),
				kern.DTO_ScheduledParameterDefinition.of('batchSize').asNumeric()
						.withDefault('2000')
						.withDescription('Number of records per batch'),
				kern.DTO_ScheduledParameterDefinition.of('dryRun').asBoolean()
						.withDefault('false')
						.withDescription('Run without committing changes')
		};
	}

	public void setParameterValues(kern.DTO_NameValues parameterValues)
	{
		this.parameterValues = parameterValues;
	}

	public void execute(SchedulableContext context)
	{
		executed = true;
		if(parameterValues != null)
		{
			resolvedObjectName = parameterValues.get('objectName');
			String batchSizeStr = parameterValues.get('batchSize');
			resolvedBatchSize = String.isNotBlank(batchSizeStr) ? Integer.valueOf(batchSizeStr) : null;
			String dryRunStr = parameterValues.get('dryRun');
			resolvedDryRun = String.isNotBlank(dryRunStr) ? Boolean.valueOf(dryRunStr) : false;
		}
	}
}
