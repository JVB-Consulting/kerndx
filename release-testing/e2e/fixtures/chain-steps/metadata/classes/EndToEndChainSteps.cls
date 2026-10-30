// SPDX-License-Identifier: Apache-2.0
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
 * @date August 2026, October 2026
 */
public with sharing class EndToEndChainSteps
{
	/**
	 * @description Name prefix of the marker records RecoveringStep keys to its chain execution.
	 */
	public static final String MARKER_NAME_PREFIX = 'E2E Recovery Marker ';
	/**
	 * @description Context key for the created Foobar record ID.
	 */
	public static final String KEY_FOOBAR_ID = 'foobarId';
	/**
	 * @description Failure message of UpdateFoobarStep when the context holds no Foobar Id under KEY_FOOBAR_ID.
	 */
	public static final String MISSING_FOOBAR_ID_MESSAGE = 'foobarId missing from context';
	/**
	 * @description Start of the failure message of UpdateFoobarStep when its Foobar Id names no record it can read; the
	 * Id follows.
	 */
	public static final String FOOBAR_NOT_FOUND_MESSAGE = 'Foobar not found: ';

	/**
	 * @description Fails on its first run for a given chain execution, seeding a marker record
	 * keyed to the execution id, and succeeds on any later run that finds the marker, so an
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

		/**
		 * @description Looks for a Foobar marker named after this chain execution. When there is none it inserts one and
		 * fails; when there is one it succeeds. So the first run fails and a retry of the same execution succeeds.
		 *
		 * @param context The chain context, read for the chain execution id the marker is named after.
		 *
		 * @return A failure on the run that creates the marker, a success on any run that finds it.
		 */
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
	 * @description Creates a Foobar__c record and stores the ID in context.
	 */
	public class CreateFoobarStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Inserts a Foobar named with the current time and puts its Id in the context under KEY_FOOBAR_ID,
		 * so a later step can find the record.
		 *
		 * @param context The chain context that receives the new record's Id.
		 *
		 * @return A success that carries the new record's Id.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Foobar__c record = new Foobar__c(Name = 'Chain Test ' + Datetime.now().format());
			DML_Builder.newTransaction().doInsert(record).execute();
			context.put(KEY_FOOBAR_ID, record.Id);
			return UTIL_AsyncChain.succeeded('Created Foobar: ' + record.Id, record.Id);
		}
	}

	/**
	 * @description Updates the Foobar__c record created by CreateFoobarStep, reading the ID from context.
	 */
	public class UpdateFoobarStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Reads the Foobar Id an earlier step put in the context, loads the record and adds an "Updated"
		 * suffix to its name, so the change one step makes to another step's record is visible on the record. When the
		 * context holds no Foobar Id, or the Id names no record this user can read, the step fails with a message that
		 * says which, and changes nothing.
		 *
		 * @param context The chain context that holds the Foobar Id under KEY_FOOBAR_ID.
		 *
		 * @return A success naming the record that was updated, or a failure naming what is missing.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Id foobarId = (Id)context.get(KEY_FOOBAR_ID);
			if(foobarId == null)
			{
				return UTIL_AsyncChain.failed(MISSING_FOOBAR_ID_MESSAGE);
			}

			Foobar__c record = (Foobar__c)QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.Name})
					.condition(Foobar__c.Id).equals(foobarId)
					.getFirst();
			if(record == null)
			{
				return UTIL_AsyncChain.failed(FOOBAR_NOT_FOUND_MESSAGE + foobarId);
			}

			record.Name = record.Name + ' — Updated';
			DML_Builder.newTransaction().doUpdate(record).execute();
			return UTIL_AsyncChain.succeeded('Updated Foobar: ' + foobarId);
		}
	}

	/**
	 * @description Always fails without declaring idempotency, so the failed chain shows the
	 * retry action disabled with the step-not-idempotent refusal tooltip.
	 */
	public class FailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Returns a plain failure without doing any work, so the chain it belongs to always ends failed.
		 *
		 * @param context The chain context; unused.
		 *
		 * @return A failure.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Deliberate e2e failure');
		}
	}
}
