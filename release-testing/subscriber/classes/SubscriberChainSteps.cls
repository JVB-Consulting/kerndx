// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Chain step implementations for subscriber integration testing.
 * Exercises the UTIL_AsyncChain API from subscriber context with real DML,
 * HTTP callouts, and context manipulation.
 *
 * @see SubscriberChainSteps_TEST
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date April 2026, October 2026
 */
public with sharing class SubscriberChainSteps
{
	/**
	 * @description Context key for the created Foobar record ID.
	 */
	public static final String KEY_FOOBAR_ID = 'foobarId';
	/**
	 * @description Failure message of a step that needs the Foobar Id and finds none in the context under KEY_FOOBAR_ID.
	 */
	public static final String MISSING_FOOBAR_ID_MESSAGE = 'foobarId missing from context';
	/**
	 * @description Start of the failure message of a step whose Foobar Id names no record it can read; the Id follows.
	 */
	public static final String FOOBAR_NOT_FOUND_MESSAGE = 'Foobar not found: ';
	/**
	 * @description Failure message of VerifyContextStep when the context holds no API marker under KEY_API_RESPONSE.
	 */
	public static final String MISSING_API_MARKER_MESSAGE = 'apiResponse missing from context';
	/**
	 * @description Start of VerifyContextStep's failure message when the Foobar's name shows UpdateFoobarStep did not run;
	 * the Foobar's name follows.
	 */
	public static final String FOOBAR_NOT_UPDATED_MESSAGE = 'Foobar not updated by prior step: ';
	/**
	 * @description Context key for the marker CallApiStep writes once it has sent its call: the fixed text "invoked", not
	 * the external system's response.
	 */
	public static final String KEY_API_RESPONSE = 'apiResponse';
	/**
	 * @description Context key under which VerifyContextStep writes true once it has found the Foobar Id, the API marker
	 * and the updated Foobar.
	 */
	public static final String KEY_VERIFIED = 'verified';
	/**
	 * @description Context key for the error handler executed flag.
	 */
	public static final String KEY_ERROR_HANDLED = 'errorHandled';
	/**
	 * @description Context key for the completion handler executed flag.
	 */
	public static final String KEY_COMPLETED = 'completed';
	/**
	 * @description Prefix for per-step context keys written by WriteContextStep. Each step writes step_&lt;currentStepIndex&gt;.
	 */
	public static final String CONTEXT_KEY_PREFIX = 'step_';
	/**
	 * @description Size in characters of the random payload each WriteContextStep writes to context.
	 */
	public static final Integer WRITE_CONTEXT_PAYLOAD_SIZE = 1024;
	/**
	 * @description Context key under which CaptureIdempotencyKeyStep records the step's chain execution Id.
	 */
	public static final String KEY_IDEMPOTENCY_EXECUTION_ID = 'idempotencyExecutionId';
	/**
	 * @description Context key under which CaptureIdempotencyKeyStep records the step index as a String.
	 */
	public static final String KEY_IDEMPOTENCY_STEP_INDEX = 'idempotencyStepIndex';
	/**
	 * @description Context key under which CaptureIdempotencyKeyStep records the record Id passed to the grained overload.
	 */
	public static final String KEY_IDEMPOTENCY_RECORD_ID = 'idempotencyRecordId';
	/**
	 * @description Context key under which CaptureIdempotencyKeyStep records the bare idempotencyKey().
	 */
	public static final String KEY_IDEMPOTENCY_BASE = 'idempotencyBase';
	/**
	 * @description Context key under which CaptureIdempotencyKeyStep records idempotencyKey(recordId).
	 */
	public static final String KEY_IDEMPOTENCY_RECORD = 'idempotencyRecord';
	/**
	 * @description Context key under which CaptureIdempotencyKeyStep records idempotencyKey(grain).
	 */
	public static final String KEY_IDEMPOTENCY_GRAIN = 'idempotencyGrain';
	/**
	 * @description Fixed grain string CaptureIdempotencyKeyStep feeds to the String overload of idempotencyKey.
	 */
	public static final String IDEMPOTENCY_GRAIN = 'unit-00042';
	/**
	 * @description Name prefix of the marker records RecoveringStep keys to its chain execution.
	 */
	public static final String RECOVERY_MARKER_NAME_PREFIX = 'Subscriber Recovery Marker ';
	/**
	 * @description Failure message RecoveringStep returns on the first run that seeds its marker.
	 */
	public static final String RECOVERY_FIRST_RUN_MESSAGE = 'Deliberate first-run failure; recovery marker seeded';
	/**
	 * @description Context key under which LaunchChildChainStep records the execution id of the chain it launched.
	 */
	public static final String KEY_CHILD_EXECUTION_ID = 'childExecutionId';
	/**
	 * @description Chain name of the two-step child LaunchChildChainStep launches.
	 */
	public static final String NESTED_CHILD_CHAIN_NAME = 'SubscriberNestedChild';
	/**
	 * @description Success message RecoveringStep returns once its marker exists.
	 */
	public static final String RECOVERY_RECOVERED_MESSAGE = 'Recovery marker found; step recovered';
	/**
	 * @description Context key for a volume chain's depth below its root (the root is 0).
	 */
	public static final String KEY_VOLUME_DEPTH = 'volumeDepth';
	/**
	 * @description Context key for the depth at which a volume chain stops fanning out and runs leaf steps.
	 */
	public static final String KEY_VOLUME_TARGET_DEPTH = 'volumeTargetDepth';
	/**
	 * @description Context key for a volume chain's ordinal within its level under its root.
	 */
	public static final String KEY_VOLUME_ORDINAL = 'volumeOrdinal';
	/**
	 * @description Context key for the ordinal of the root a volume chain descends from.
	 */
	public static final String KEY_VOLUME_ROOT_ORDINAL = 'volumeRootOrdinal';
	/**
	 * @description Context key for the letters-only token of the load run a volume chain belongs to.
	 */
	public static final String KEY_VOLUME_RUN_IDENTIFIER = 'volumeRunToken';
	/**
	 * @description Context key for how a leaf chain ends: one of the OUTCOME_ values.
	 */
	public static final String KEY_VOLUME_OUTCOME = 'volumeOutcome';
	/**
	 * @description Context key for the CPU milliseconds a BusyStep spends.
	 */
	public static final String KEY_BUSY_MILLISECONDS = 'busyMilliseconds';
	/**
	 * @description A leaf that completes.
	 */
	public static final String OUTCOME_SUCCEED = 'succeed';
	/**
	 * @description A leaf that fails on its first attempt with a plain failure.
	 */
	public static final String OUTCOME_FAIL = 'fail';
	/**
	 * @description A leaf that fails permanently, so the operator retry is refused.
	 */
	public static final String OUTCOME_FAIL_PERMANENTLY = 'failPermanently';
	/**
	 * @description A leaf that fails on every attempt of a retry strategy, ending RetriesExhausted.
	 */
	public static final String OUTCOME_FAIL_AFTER_RETRIES = 'failAfterRetries';
	/**
	 * @description Chain names by depth: the root, then each level below it.
	 */
	public static final List<String> VOLUME_CHAIN_NAMES = new List<String>
	{
			'Volume_Reconciliation', 'Volume_RegionReconcile', 'Volume_LedgerReconcile', 'Volume_AccountReconcile'
	};
	/**
	 * @description Steps per volume chain, and so children per fanning chain.
	 */
	public static final Integer VOLUME_FAN_OUT = 5;
	/**
	 * @description Every this-many leaves, one fails.
	 */
	public static final Integer FAILING_LEAF_EVERY = 8;
	/**
	 * @description CPU milliseconds a BusyStep spends when the context names no budget.
	 */
	public static final Integer DEFAULT_BUSY_MILLISECONDS = 1500;
	/**
	 * @description The most CPU milliseconds a BusyStep spends, whatever the context asks.
	 */
	public static final Integer MAXIMUM_BUSY_MILLISECONDS = 5000;
	/**
	 * @description The alphabet every harness id is spelled in: hexadecimal letters only, so an id is UUID-shaped
	 * (the Log Console's search resolves it) and never forms the digit run the payment-card masking target rewrites.
	 */
	public static final String VOLUME_ID_ALPHABET = 'abcdef';
	/**
	 * @description The id kind of an action.
	 */
	public static final String KIND_ACTION = 'aaaa';
	/**
	 * @description The id kind of a run of the reconciliation action, at any depth.
	 */
	public static final String KIND_RECONCILIATION_RUN = 'bbbb';
	/**
	 * @description The id kind of a run of a small action.
	 */
	public static final String KIND_SMALL_ACTION_RUN = 'cccc';
	/**
	 * @description The id kind of a run the operator wave launches.
	 */
	public static final String KIND_WAVE_RUN = 'dddd';
	/**
	 * @description The id kind of a synthesized Stalled row.
	 */
	public static final String KIND_STALLED_ROW = 'eeee';
	/**
	 * @description Letters in a harness id's third and fourth segments.
	 */
	public static final Integer VOLUME_ID_SHORT_WIDTH = 4;
	/**
	 * @description Letters in a harness id's last segment.
	 */
	public static final Integer VOLUME_ID_LONG_WIDTH = 12;

	/**
	 * @description How a leaf with this ordinal ends: every eighth leaf fails, and the failing kinds cycle plain,
	 * permanent, after retries. The driver's shape table computes the same rule to know what to expect.
	 *
	 * @param leafOrdinal The leaf's ordinal within its level under its root.
	 *
	 * @return One of the OUTCOME_ values.
	 */
	public static String leafOutcome(Integer leafOrdinal)
	{
		if(Math.mod(leafOrdinal, FAILING_LEAF_EVERY) != 0)
		{
			return OUTCOME_SUCCEED;
		}
		Integer kind = Math.mod(leafOrdinal / FAILING_LEAF_EVERY, 3);
		if(kind == 1)
		{
			return OUTCOME_FAIL_PERMANENTLY;
		}
		return kind == 2 ? OUTCOME_FAIL_AFTER_RETRIES : OUTCOME_FAIL;
	}

	/**
	 * @description A number spelled in the id alphabet, left-padded with the alphabet's first letter to a width.
	 *
	 * @param value The number, zero or more.
	 * @param width The letters to fill.
	 *
	 * @return The letters.
	 */
	public static String volumeLetters(Integer value, Integer width)
	{
		String text = '';
		Integer remaining = value;
		do
		{
			Integer digit = Math.mod(remaining, VOLUME_ID_ALPHABET.length());
			text = VOLUME_ID_ALPHABET.substring(digit, digit + 1) + text;
			remaining = remaining / VOLUME_ID_ALPHABET.length();
		}
		while(remaining > 0);
		return text.leftPad(width, VOLUME_ID_ALPHABET.substring(0, 1));
	}

	/**
	 * @description A harness id in the framework's tracking-id shape (8-4-4-4-12): the run token, the kind, then three
	 * numbers that make it unique within its kind. Every row a load writes carries one in CorrelationId__c and its
	 * action's in RootCorrelationId__c, so a whole run is found by its token alone.
	 *
	 * @param runToken Eight letters of the id alphabet.
	 * @param kind One of the KIND_ values.
	 * @param first The first number (a root or action ordinal).
	 * @param second The second number (a depth or launch index).
	 * @param ordinal The ordinal within the first two.
	 *
	 * @return The id, 36 characters.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static String volumeRunId(String runToken, String kind, Integer first, Integer second, Integer ordinal)
	{
		return runToken + '-' + kind + '-' + volumeLetters(first, VOLUME_ID_SHORT_WIDTH) + '-' + volumeLetters(second, VOLUME_ID_SHORT_WIDTH)
				+ '-' + volumeLetters(ordinal, VOLUME_ID_LONG_WIDTH);
	}

	/**
	 * @description Creates a Foobar__c record and stores the ID in context.
	 */
	public class CreateFoobarStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Inserts a Foobar named with the current time and puts its Id in the context under KEY_FOOBAR_ID,
		 * so the later steps of the chain can find the record.
		 *
		 * @param context The chain context that receives the new record's Id.
		 *
		 * @return A success that carries the new record's Id.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			kern__Foobar__c record = new kern__Foobar__c(Name = 'Chain Test ' + Datetime.now().format());
			kern.DML_Builder.newTransaction().doInsert(record).execute();
			context.put(KEY_FOOBAR_ID, record.Id);
			return kern.UTIL_AsyncChain.succeeded('Created Foobar: ' + record.Id, record.Id);
		}
	}

	/**
	 * @description Calls the API_PostExample outbound service using UTIL_HttpClient delegation, then writes the fixed
	 * marker "invoked" under KEY_API_RESPONSE. The external system's answer is not stored.
	 */
	public class CallApiStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Sends the API_PostExample outbound call for the Foobar whose Id an earlier step put in the context,
		 * then writes a marker under KEY_API_RESPONSE so a later step can tell the call was made. The marker is the fixed
		 * text "invoked", not the external system's answer.
		 *
		 * @param context The chain context that holds the Foobar Id and receives the marker.
		 *
		 * @return A success naming the record the call was made for.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Id foobarId = (Id)context.get(KEY_FOOBAR_ID);

			kern.UTIL_HttpClient.useHandler(kern.UTIL_System.getTypeForClassName('API_PostExample'))
					.withTriggeringRecord(foobarId)
					.withParameter('foo', 'ChainTest')
					.invoke();

			context.put(KEY_API_RESPONSE, 'invoked');
			return kern.UTIL_AsyncChain.succeeded('API call invoked for: ' + foobarId);
		}
	}

	/**
	 * @description Updates the Foobar__c record created by CreateFoobarStep, reading the ID from context.
	 */
	public class UpdateFoobarStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Reads the Foobar Id from the context, loads the record and adds an "Updated" suffix to its name.
		 * VerifyContextStep looks for that suffix to prove this step ran. When the context holds no Foobar Id, or the Id
		 * names no record this user can read, the step fails with a message that says which, and changes nothing.
		 *
		 * @param context The chain context that holds the Foobar Id under KEY_FOOBAR_ID.
		 *
		 * @return A success naming the record that was updated, or a failure naming what is missing.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Id foobarId = (Id)context.get(KEY_FOOBAR_ID);
			if(foobarId == null)
			{
				return kern.UTIL_AsyncChain.failed(MISSING_FOOBAR_ID_MESSAGE);
			}

			kern__Foobar__c record = (kern__Foobar__c)kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
					.fields(new List<SObjectField> {kern__Foobar__c.Name})
					.condition(kern__Foobar__c.Id).equals(foobarId)
					.getFirst();
			if(record == null)
			{
				return kern.UTIL_AsyncChain.failed(FOOBAR_NOT_FOUND_MESSAGE + foobarId);
			}

			record.Name = record.Name + ' — Updated';
			kern.DML_Builder.newTransaction().doUpdate(record).execute();
			return kern.UTIL_AsyncChain.succeeded('Updated Foobar: ' + foobarId);
		}
	}

	/**
	 * @description Verifies that all prior context values are populated and the record exists.
	 * Reads foobarId and apiResponse from context, queries the Foobar, and writes true under KEY_VERIFIED.
	 */
	public class VerifyContextStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails unless the context holds both the Foobar Id and the API marker, the Id names a Foobar this
		 * user can read, and the Foobar's name shows that UpdateFoobarStep ran. When all of them hold, writes true under
		 * KEY_VERIFIED.
		 *
		 * @param context The chain context the earlier steps wrote to.
		 *
		 * @return A success when everything is in place; otherwise a failure that names what is missing.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Id foobarId = (Id)context.get(KEY_FOOBAR_ID);
			String apiResponse = (String)context.get(KEY_API_RESPONSE);

			if(foobarId == null)
			{
				return kern.UTIL_AsyncChain.failed(MISSING_FOOBAR_ID_MESSAGE);
			}
			if(apiResponse == null)
			{
				return kern.UTIL_AsyncChain.failed(MISSING_API_MARKER_MESSAGE);
			}

			kern__Foobar__c record = (kern__Foobar__c)kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
					.fields(new List<SObjectField> {kern__Foobar__c.Name})
					.condition(kern__Foobar__c.Id).equals(foobarId)
					.getFirst();
			if(record == null)
			{
				return kern.UTIL_AsyncChain.failed(FOOBAR_NOT_FOUND_MESSAGE + foobarId);
			}
			if(!record.Name.contains('Updated'))
			{
				return kern.UTIL_AsyncChain.failed(FOOBAR_NOT_UPDATED_MESSAGE + record.Name);
			}

			context.put(KEY_VERIFIED, true);
			return kern.UTIL_AsyncChain.succeeded('All context verified: foobar=' + foobarId + ', api=' + apiResponse);
		}
	}

	/**
	 * @description Step that always returns a failed result.
	 */
	public class FailingStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Returns a plain failure without doing any work, so a test can see what a chain does when one of
		 * its steps fails.
		 *
		 * @param context The chain context; unused.
		 *
		 * @return A failure.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.failed('Deliberate subscriber failure');
		}
	}

	/**
	 * @description Fails on its first run for a given chain execution, seeding a marker record
	 * keyed to the execution id, and succeeds on any later run that finds the marker, so an
	 * operator retry recovers the chain end-to-end from subscriber context. Declares itself
	 * idempotent: its only side effect is the marker insert, which the marker lookup guards
	 * against repeating.
	 */
	public class RecoveringStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step idempotent so the operator retry gate offers it. An override,
		 * never a constructor: the framework recreates the step by class name in each hop, and a
		 * subscriber step that declares its own constructor cannot be recreated across the package
		 * boundary.
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
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			String markerName = RECOVERY_MARKER_NAME_PREFIX + context.getChainExecutionId();
			kern__Foobar__c marker = (kern__Foobar__c)kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
					.fields(new List<SObjectField> {kern__Foobar__c.Name})
					.condition(kern__Foobar__c.Name).equals(markerName)
					.getFirst();
			if(marker == null)
			{
				kern.DML_Builder.newTransaction().doInsert(new kern__Foobar__c(Name = markerName)).execute();
				return kern.UTIL_AsyncChain.failed(RECOVERY_FIRST_RUN_MESSAGE);
			}
			return kern.UTIL_AsyncChain.succeeded(RECOVERY_RECOVERED_MESSAGE);
		}
	}

	/**
	 * @description Error handler that records execution in context.
	 */
	public class ErrorHandlerStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes true under KEY_ERROR_HANDLED, so a test can prove the chain ran its error handler.
		 *
		 * @param context The chain context that receives the flag.
		 *
		 * @return A success.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			context.put(KEY_ERROR_HANDLED, true);
			return kern.UTIL_AsyncChain.succeeded('Error handled');
		}
	}

	/**
	 * @description Completion handler that records execution in context.
	 */
	public class CompletionHandlerStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes true under KEY_COMPLETED, so a test can prove the chain ran its completion handler.
		 *
		 * @param context The chain context that receives the flag.
		 *
		 * @return A success.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			context.put(KEY_COMPLETED, true);
			return kern.UTIL_AsyncChain.succeeded('Chain completed');
		}
	}

	/**
	 * @description Launches a two-step child chain from inside its own run, or from a completion handler, and records the
	 * child's execution id in the context. Two steps, so the child's second hop proves that a chain launched inside
	 * another sets its own queueable stack depth once it is running.
	 */
	public class LaunchChildChainStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Starts a chain named NESTED_CHILD_CHAIN_NAME with two WriteContextStep steps and writes the id of
		 * that chain's execution under KEY_CHILD_EXECUTION_ID, so a test can find the child.
		 *
		 * @param context The chain context that receives the child's execution id.
		 *
		 * @return A success naming the child's execution id.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			String childExecutionId = kern.UTIL_AsyncChain.newChain(NESTED_CHILD_CHAIN_NAME)
					.then(new WriteContextStep())
					.then(new WriteContextStep())
					.execute();
			context.put(KEY_CHILD_EXECUTION_ID, childExecutionId);
			return kern.UTIL_AsyncChain.succeeded('Launched ' + childExecutionId);
		}
	}

	/**
	 * @description Step that always fails. Used with then(step, true) to test continueOnError via builder.
	 */
	public class OptionalFailingStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Returns a failure whose message says it is expected, for a step the chain is told to carry on past.
		 *
		 * @param context The chain context; unused.
		 *
		 * @return A failure.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.failed('Expected failure, continuing');
		}
	}

	/**
	 * @description Pure IF_Chain.Step implementation without extending ChainStep.
	 * Demonstrates the interface-based path for subscribers with existing class hierarchies.
	 */
	public class PureInterfaceStep implements kern.IF_Chain.Step
	{
		/**
		 * @description Marks the context and succeeds.
		 *
		 * @param context The chain context.
		 *
		 * @return A success.
		 */
		public kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			context.put('pureInterfaceExecuted', true);
			return kern.UTIL_AsyncChain.succeeded('Pure interface step');
		}
	}

	/**
	 * @description Pure IF_Chain.Step that always fails. Used with then(step, true).
	 */
	public class PureInterfaceFailingStep implements kern.IF_Chain.Step
	{
		/**
		 * @description Fails, so a step declared with continueOnError can be exercised.
		 *
		 * @param context The chain context.
		 *
		 * @return A failure.
		 */
		public kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.failed('Pure interface failure');
		}
	}

	/**
	 * @description Stress fixture for chain context serialization load tests. Writes a 1KB
	 * random alphanumeric payload to context under key step_&lt;currentStepIndex&gt; and, if a
	 * prior step has run, reads back the previous step's payload to prove the JSON
	 * round-trip across queueable boundaries. Used by section-48 to grow the context to
	 * ~50KB across 50 chained steps.
	 */
	public class WriteContextStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes a random payload of WRITE_CONTEXT_PAYLOAD_SIZE characters under this step's own key. From the
		 * second step on it also reads the payload the step before it wrote, and fails when that payload is missing or
		 * not the expected length. A pass shows the earlier payload was still in the context, at its full length, when
		 * this step ran.
		 *
		 * @param context The chain context that receives this step's payload and holds the earlier ones.
		 *
		 * @return A success stating what was written, or a failure naming the earlier key that was missing or wrong.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Integer stepIndex = context.getCurrentStepIndex();
			String payload = kern.UTIL_Random.randomAlphanumeric(WRITE_CONTEXT_PAYLOAD_SIZE);
			context.put(CONTEXT_KEY_PREFIX + stepIndex, payload);

			if(stepIndex != null && stepIndex > 0)
			{
				String priorKey = CONTEXT_KEY_PREFIX + (stepIndex - 1);
				String priorPayload = (String)context.get(priorKey);
				if(priorPayload == null)
				{
					return kern.UTIL_AsyncChain.failed('Prior payload missing at ' + priorKey);
				}
				if(priorPayload.length() != WRITE_CONTEXT_PAYLOAD_SIZE)
				{
					return kern.UTIL_AsyncChain.failed(
							'Prior payload at ' + priorKey + ' was '
							+ priorPayload.length() + ' chars (expected ' + WRITE_CONTEXT_PAYLOAD_SIZE + ')');
				}
			}

			return kern.UTIL_AsyncChain.succeeded('Wrote ' + WRITE_CONTEXT_PAYLOAD_SIZE + ' chars at step ' + stepIndex);
		}
	}

	/**
	 * @description Test-only fixture that writes an intentionally undersized payload (32 chars)
	 * to step_&lt;currentStepIndex&gt;. Used to drive the WriteContextStep size-mismatch failure path.
	 */
	public class WriteUndersizedContextStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes a 32-character payload under this step's key, shorter than WriteContextStep expects, so a
		 * WriteContextStep that runs next fails its length check.
		 *
		 * @param context The chain context that receives the short payload.
		 *
		 * @return A success.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Integer stepIndex = context.getCurrentStepIndex();
			context.put(CONTEXT_KEY_PREFIX + stepIndex, kern.UTIL_Random.randomAlphanumeric(32));
			return kern.UTIL_AsyncChain.succeeded('Wrote undersized payload at step ' + stepIndex);
		}
	}

	/**
	 * @description Test-only fixture that does NOT write to context. Used to drive the
	 * WriteContextStep missing-payload failure path.
	 */
	public class NoWriteStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Succeeds without writing to the context, so a WriteContextStep that runs next finds no payload from
		 * the step before it and fails.
		 *
		 * @param context The chain context, read only for the step index in the message.
		 *
		 * @return A success.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.succeeded('No-op step at ' + context.getCurrentStepIndex());
		}
	}

	/**
	 * @description Exercises the 1.2 per-step idempotency-key API from subscriber context.
	 * Inserts a record to obtain a real grain Id, then records the three global overloads
	 * (idempotencyKey(), idempotencyKey(Id) and idempotencyKey(String)) into context
	 * alongside the chain execution Id and step index, so the test can assert the documented
	 * key shape (executionId-stepIndex, then -grain) without depending on the absolute index.
	 */
	public class CaptureIdempotencyKeyStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Inserts a Foobar to have a real record Id, then writes to the context the chain execution id, the
		 * step index, the record Id and the three keys the context builds: the plain key, the key for the record and the
		 * key for IDEMPOTENCY_GRAIN. A test compares each key with the values it is built from.
		 *
		 * @param context The chain context that builds the keys and receives the captured values.
		 *
		 * @return A success naming the step index.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			kern__Foobar__c record = new kern__Foobar__c(Name = 'Idempotency Probe ' + Datetime.now().getTime());
			kern.DML_Builder.newTransaction().doInsert(record).execute();

			context.put(KEY_IDEMPOTENCY_EXECUTION_ID, String.valueOf(context.getChainExecutionId()));
			context.put(KEY_IDEMPOTENCY_STEP_INDEX, String.valueOf(context.getCurrentStepIndex()));
			context.put(KEY_IDEMPOTENCY_RECORD_ID, String.valueOf(record.Id));
			context.put(KEY_IDEMPOTENCY_BASE, context.idempotencyKey());
			context.put(KEY_IDEMPOTENCY_RECORD, context.idempotencyKey(record.Id));
			context.put(KEY_IDEMPOTENCY_GRAIN, context.idempotencyKey(IDEMPOTENCY_GRAIN));

			return kern.UTIL_AsyncChain.succeeded('Captured idempotency keys at step ' + context.getCurrentStepIndex());
		}
	}

	/**
	 * @description Launches the next level of the volume load from inside its own run: a child with five fanning
	 * steps while the child is above the target depth, else a leaf of two narrating steps, two busy steps and an
	 * outcome. One launch per step per transaction is the engine's rule, and one child per step is what this does.
	 */
	public class FanOutStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches one child chain, one level below this chain. The child's ordinal is this chain's ordinal
		 * times VOLUME_FAN_OUT plus this step's index, so each child of a level has its own number. A child above the
		 * target depth is given VOLUME_FAN_OUT FanOutStep steps of its own; a child at the target depth is given the leaf
		 * steps and the ending that leafOutcome picks for its ordinal. Writes one INFO log entry naming the child.
		 *
		 * @param context The chain context that holds this chain's depth and ordinal, from which the child's are worked out,
		 * and the target depth, root ordinal, run token and CPU budget, which are passed on to the child unchanged.
		 *
		 * @return A success that carries the child's execution id.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Integer depth = (Integer)context.getAs(KEY_VOLUME_DEPTH, Integer.class);
			Integer targetDepth = (Integer)context.getAs(KEY_VOLUME_TARGET_DEPTH, Integer.class);
			Integer ordinal = (Integer)context.getAs(KEY_VOLUME_ORDINAL, Integer.class);
			Integer rootOrdinal = (Integer)context.getAs(KEY_VOLUME_ROOT_ORDINAL, Integer.class);
			String runToken = (String)context.get(KEY_VOLUME_RUN_IDENTIFIER);
			Integer childDepth = depth + 1;
			Integer childOrdinal = ordinal * VOLUME_FAN_OUT + context.getCurrentStepIndex();
			String childName = VOLUME_CHAIN_NAMES[childDepth];
			kern.UTIL_AsyncChain.ChainBuilder child = kern.UTIL_AsyncChain.newChain(childName)
					.withInitialContext(KEY_VOLUME_DEPTH, childDepth)
					.withInitialContext(KEY_VOLUME_TARGET_DEPTH, targetDepth)
					.withInitialContext(KEY_VOLUME_ORDINAL, childOrdinal)
					.withInitialContext(KEY_VOLUME_ROOT_ORDINAL, context.get(KEY_VOLUME_ROOT_ORDINAL))
					.withInitialContext(KEY_VOLUME_RUN_IDENTIFIER, context.get(KEY_VOLUME_RUN_IDENTIFIER))
					.withInitialContext(KEY_BUSY_MILLISECONDS, context.get(KEY_BUSY_MILLISECONDS));
			if(childDepth < targetDepth)
			{
				for(Integer step = 0; step < VOLUME_FAN_OUT; step++)
				{
					child.then(new FanOutStep());
				}
			}
			else
			{
				String outcome = leafOutcome(childOrdinal);
				child.withInitialContext(KEY_VOLUME_OUTCOME, outcome)
						.then(new NarratingStep())
						.then(new BusyStep())
						.then(new NarratingStep())
						.then(new BusyStep());
				if(outcome == OUTCOME_FAIL_AFTER_RETRIES)
				{
					child.then(new RetryingFailureStep());
				}
				else
				{
					child.then(new OutcomeStep());
				}
			}
			String childId = child.execute(volumeRunId(runToken, KIND_RECONCILIATION_RUN, rootOrdinal, childDepth, childOrdinal));
			kern.LOG_Builder.build().info('Launched ' + childName + ' ' + childOrdinal + ' as ' + childId).emitAt('SubscriberChainSteps.FanOutStep.work');
			return kern.UTIL_AsyncChain.succeeded('Launched ' + childName + ' ' + childOrdinal, childId);
		}
	}

	/**
	 * @description Writes one INFO entry with a message an operator would expect to read, so the Log Console holds
	 * step entries under every leaf run's correlation.
	 */
	public class NarratingStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes one INFO log entry about the account batch numbered by the chain's ordinal. As the first step
		 * of a chain it says the batch was validated; as any later step it says the batch was reconciled.
		 *
		 * @param context The chain context that holds the chain's ordinal and the current step index.
		 *
		 * @return A success with the same message as the log entry.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			String batch = String.valueOf(context.get(KEY_VOLUME_ORDINAL));
			String message = context.getCurrentStepIndex() == 0
					? 'Validated account batch ' + batch + ' against the ledger'
					: 'Reconciled account batch ' + batch + ' and queued the posting';
			kern.LOG_Builder.build().info(message).emitAt('SubscriberChainSteps.NarratingStep.work');
			return kern.UTIL_AsyncChain.succeeded(message);
		}
	}

	/**
	 * @description Synthetic CPU load: spends a bounded amount of CPU so step durations are measurable, never more than
	 * the maximum. Its timings say nothing about application work and are never used as performance evidence; only
	 * the browser-side console reads are.
	 */
	public class BusyStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Generates random text in a loop until its CPU budget is spent. The budget is the value under
		 * KEY_BUSY_MILLISECONDS, or DEFAULT_BUSY_MILLISECONDS when the context has none, and never more than
		 * MAXIMUM_BUSY_MILLISECONDS.
		 *
		 * @param context The chain context that may hold the CPU budget.
		 *
		 * @return A success stating the CPU milliseconds spent and the number of rounds.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Integer requested = (Integer)context.getAs(KEY_BUSY_MILLISECONDS, Integer.class);
			Integer budget = Math.min(requested == null ? DEFAULT_BUSY_MILLISECONDS : requested, MAXIMUM_BUSY_MILLISECONDS);
			Integer startedAt = Limits.getCpuTime();
			Integer rounds = 0;
			while(Limits.getCpuTime() - startedAt < budget)
			{
				kern.UTIL_Random.randomAlphanumeric(64);
				rounds++;
			}
			return kern.UTIL_AsyncChain.succeeded('Worked ' + (Limits.getCpuTime() - startedAt) + ' ms over ' + rounds + ' rounds');
		}
	}

	/**
	 * @description Ends a leaf the way its context says: completes, fails plainly, or fails permanently.
	 */
	public class OutcomeStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Reads the ending from KEY_VOLUME_OUTCOME: OUTCOME_FAIL_PERMANENTLY gives a permanent failure,
		 * OUTCOME_FAIL a plain failure, and any other value a success. Each message names the account batch by the
		 * chain's ordinal.
		 *
		 * @param context The chain context that holds the ending and the chain's ordinal.
		 *
		 * @return The success or failure the context asked for.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			String outcome = (String)context.get(KEY_VOLUME_OUTCOME);
			String batch = String.valueOf(context.get(KEY_VOLUME_ORDINAL));
			if(outcome == OUTCOME_FAIL_PERMANENTLY)
			{
				return kern.UTIL_AsyncChain.failedPermanently('Account batch ' + batch + ' is locked by a closed period; posting refused');
			}
			if(outcome == OUTCOME_FAIL)
			{
				return kern.UTIL_AsyncChain.failed('Account batch ' + batch + ' did not balance; posting held');
			}
			return kern.UTIL_AsyncChain.succeeded('Posted account batch ' + batch);
		}
	}

	/**
	 * @description Fails on every attempt under the framework's linear retry strategy, so the run ends
	 * RetriesExhausted with the attempts in its step log.
	 */
	public class RetryingFailureStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Gives the step the linear retry strategy with its standard settings, so a failure of this step is
		 * tried again instead of ending the chain at once.
		 *
		 * @return The linear retry strategy.
		 */
		public override kern.UTIL_Retry.Strategy createRetryStrategy()
		{
			return kern.UTIL_Retry.linear();
		}

		/**
		 * @description Fails every time. The message carries the attempt number, so each attempt can be told apart in
		 * the step log.
		 *
		 * @param context The chain context, read for the attempt number.
		 *
		 * @return A failure.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.failed('The posting service answered 503 on attempt ' + context.getAttempt());
		}
	}

	/**
	 * @description Spends the transaction's single enqueue on a job of its own, so the engine's next-hop enqueue has
	 * nothing left. Exists for the volume probe, which measures what the platform does then.
	 */
	public class EnqueueSpendingStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Enqueues a SingleEnqueueJob directly, which uses up the one job this transaction may enqueue, then
		 * succeeds.
		 *
		 * @param context The chain context; unused.
		 *
		 * @return A success naming the job that was enqueued.
		 */
		@SuppressWarnings('PMD.KernNoRawEnqueueJob')
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Id jobId = System.enqueueJob(new SingleEnqueueJob());
			return kern.UTIL_AsyncChain.succeeded('Spent the enqueue on ' + jobId);
		}
	}

	/**
	 * @description The job EnqueueSpendingStep enqueues; it records that it ran and nothing else.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	public class SingleEnqueueJob implements Queueable
	{
		/**
		 * @description Writes one INFO entry saying the spent enqueue ran.
		 *
		 * @param context The job's context.
		 */
		public void execute(QueueableContext context)
		{
			kern.LOG_Builder.build().info('The spent enqueue ran').emitAt('SubscriberChainSteps.SingleEnqueueJob.execute');
		}
	}
}
