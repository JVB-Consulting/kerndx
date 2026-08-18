// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Chain step fixtures for the Chain Monitor operator-action e2e specs on the
 * no-namespace development org. The subscriber release-testing leg uses SubscriberChainSteps
 * instead; this class exists because that fixture compiles against the managed kern types and
 * cannot deploy to an unmanaged org. Deployed on demand by the part8 spec, never packaged.
 *
 * @see SubscriberChainSteps
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date August 2026
 */
public with sharing class EndToEndChainSteps
{
	/**
	 * @description Name prefix of the marker records RecoveringStep keys to its chain execution.
	 */
	public static final String MARKER_NAME_PREFIX = 'E2E Recovery Marker ';

	/**
	 * @description Fails on its first run for a given chain execution — seeding a marker record
	 * keyed to the execution id — and succeeds on any later run that finds the marker, so an
	 * operator retry recovers the chain end-to-end. Declares itself idempotent: its only side
	 * effect is the marker insert, which the marker lookup guards against repeating.
	 */
	public class RecoveringStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step idempotent so the operator retry gate offers it.
		 *
		 * @return True.
		 */
		public override Boolean isIdempotent()
		{
			return true;
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String markerName = MARKER_NAME_PREFIX + context.getChainExecutionId();
			Foobar__c marker = (Foobar__c)QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.Name})
					.condition(Foobar__c.Name).equals(markerName)
					.getFirst();
			if(marker == null)
			{
				DML_Builder.newTransaction().doInsert(new Foobar__c(Name = markerName)).execute();
				return UTIL_AsyncChain.failed('Deliberate first-run failure; recovery marker seeded');
			}
			return UTIL_AsyncChain.succeeded('Recovery marker found; step recovered');
		}
	}

	/**
	 * @description Always fails without declaring idempotency, so the failed chain shows the
	 * retry action disabled with the step-not-idempotent refusal tooltip.
	 */
	public class FailingStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Deliberate e2e failure');
		}
	}
}
