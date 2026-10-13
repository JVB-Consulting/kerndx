// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A scheduled job that takes parameters, used to prove the framework's scheduler from code outside the
 * package. It declares three parameters, is handed their values before it runs, and records what it was handed in static
 * fields so a test can read them. A parameter left blank takes the default the job declares for it. It does no other work.
 */
global inherited sharing class SCHED_SubscriberJob implements kern.IF_Schedulable
{
	/**
	 * @description Name of the required parameter that holds the API name of the object to process.
	 */
	public static final String PARAMETER_OBJECT_NAME = 'objectName';
	/**
	 * @description Name of the numeric parameter that holds how many records go in each batch.
	 */
	public static final String PARAMETER_BATCH_SIZE = 'batchSize';
	/**
	 * @description Name of the true-or-false parameter that says whether to run without committing changes.
	 */
	public static final String PARAMETER_DRY_RUN = 'dryRun';
	/**
	 * @description The batch size the job declares as its default and uses when batchSize is left blank.
	 */
	public static final Integer DEFAULT_BATCH_SIZE = 2000;
	/**
	 * @description The dry-run setting the job declares as its default and uses when dryRun is left blank.
	 */
	public static final Boolean DEFAULT_DRY_RUN = false;

	/**
	 * @description True once execute has run in this transaction. Tests read it to prove the job was run.
	 */
	public static Boolean executed = false;
	/**
	 * @description The objectName parameter as execute received it. Null when it was not given; it has no default.
	 */
	public static String resolvedObjectName;
	/**
	 * @description The batchSize parameter as a number: DEFAULT_BATCH_SIZE when the value was blank or not given. Null
	 * until execute has run.
	 */
	public static Integer resolvedBatchSize;
	/**
	 * @description The dryRun parameter as true or false: DEFAULT_DRY_RUN when the value was blank or not given. Null
	 * until execute has run.
	 */
	public static Boolean resolvedDryRun;

	/**
	 * @description The parameter values handed over through setParameterValues before the run. Null when none were
	 * handed over.
	 */
	private kern.DTO_NameValues parameterValues;

	/**
	 * @description Declares the parameters this job accepts: objectName (required), batchSize (a number, with
	 * DEFAULT_BATCH_SIZE as its default) and dryRun (true or false, with DEFAULT_DRY_RUN as its default).
	 *
	 * @return The three parameter definitions.
	 */
	public List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>
		{
				kern.DTO_ScheduledParameterDefinition.of(PARAMETER_OBJECT_NAME).required()
						.withDescription('API name of the SObject to process'),
				kern.DTO_ScheduledParameterDefinition.of(PARAMETER_BATCH_SIZE).asNumeric()
						.withDefault(String.valueOf(DEFAULT_BATCH_SIZE))
						.withDescription('Number of records per batch'),
				kern.DTO_ScheduledParameterDefinition.of(PARAMETER_DRY_RUN).asBoolean()
						.withDefault(String.valueOf(DEFAULT_DRY_RUN))
						.withDescription('Run without committing changes')
		};
	}

	/**
	 * @description Receives the parameter values for a run and keeps them for execute.
	 *
	 * @param parameterValues The values, by parameter name.
	 */
	public void setParameterValues(kern.DTO_NameValues parameterValues)
	{
		this.parameterValues = parameterValues;
	}

	/**
	 * @description Marks the job as run and copies the parameter values into the static fields, turning batchSize into a
	 * number and dryRun into true or false. A batchSize or dryRun that is blank, or was not handed over at all, takes the
	 * default getParameterDefinitions declares for it; objectName has no default and stays null when it was not given.
	 *
	 * @param context The scheduler's context; unused.
	 */
	public void execute(SchedulableContext context)
	{
		executed = true;
		resolvedObjectName = parameterValues?.get(PARAMETER_OBJECT_NAME);
		String batchSizeText = parameterValues?.get(PARAMETER_BATCH_SIZE);
		resolvedBatchSize = String.isBlank(batchSizeText) ? DEFAULT_BATCH_SIZE : Integer.valueOf(batchSizeText);
		String dryRunText = parameterValues?.get(PARAMETER_DRY_RUN);
		resolvedDryRun = String.isBlank(dryRunText) ? DEFAULT_DRY_RUN : Boolean.valueOf(dryRunText);
	}
}
