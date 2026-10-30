// SPDX-License-Identifier: Apache-2.0
/**
 * @description Recurring-chain composition pattern: a schedulable whose execute() starts an
 * async chain, driven declaratively by a ScheduledJob__c record, with the deduplication key
 * making overlapping runs a non-event. Global class because the framework instantiates
 * schedulables across the namespace boundary; the chain assembly lives in its own method so
 * the run identifier stays observable. Proof artifact for the Async Processing guide's
 * "Running a chain on a schedule" pattern.
 *
 * @see Recipe_ScheduledChain_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class Recipe_ScheduledChain_DEMO extends kern.SCHED_Base
{
	/**
	 * @description Deduplication key held while a run is active; a second start while the key
	 * is held returns the active run instead of doubling up.
	 */
	public static final String DEDUPLICATION_KEY = 'NightlyOrderExport';

	/**
	 * @description Declares the typed parameter the ScheduledJob__c record supplies.
	 *
	 * @return The parameter definitions.
	 */
	public override List<kern.DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<kern.DTO_ScheduledParameterDefinition>{
				kern.DTO_ScheduledParameterDefinition.of('batchLimit').asNumeric().withDefault('200')
		};
	}

	/**
	 * @description Scheduled entry point: delegates to the chain assembly.
	 *
	 * @param context The schedulable context.
	 */
	public void execute(SchedulableContext context)
	{
		startExport(getNumericParameter('batchLimit'));
	}

	/**
	 * @description Assembles and starts the export chain.
	 *
	 * @param batchLimit How many records one run may process.
	 *
	 * @return The chain run record Id (the ACTIVE run's Id when the deduplication key is held).
	 */
	public static String startExport(Integer batchLimit)
	{
		return kern.UTIL_AsyncChain.newChain('Nightly Order Export')
				.withInitialContext('batchLimit', batchLimit)
				.withDeduplicationKey(DEDUPLICATION_KEY)
				.then(new ExportStep())
				.execute();
	}

	/**
	 * @description The nightly work; stands in for your real export step.
	 */
	public with sharing class ExportStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Performs the export work.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.succeeded();
		}
	}
}
