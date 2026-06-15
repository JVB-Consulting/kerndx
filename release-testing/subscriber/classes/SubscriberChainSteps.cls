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
 * @date April 2026, May 2026
 */
public with sharing class SubscriberChainSteps
{
	/**
	 * @description Context key for the created Foobar record ID.
	 */
	public static final String KEY_FOOBAR_ID = 'foobarId';
	/**
	 * @description Context key for the API response body.
	 */
	public static final String KEY_API_RESPONSE = 'apiResponse';
	/**
	 * @description Context key for the verification summary written by VerifyContextStep.
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
	 * @description Creates a Foobar__c record and stores the ID in context.
	 */
	public class CreateFoobarStep extends kern.UTIL_AsyncChain.ChainStep
	{
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			kern__Foobar__c record = new kern__Foobar__c(Name = 'Chain Test ' + Datetime.now().format());
			kern.DML_Builder.newTransaction().doInsert(record).execute();
			context.put(KEY_FOOBAR_ID, record.Id);
			return kern.UTIL_AsyncChain.succeeded('Created Foobar: ' + record.Id, record.Id);
		}
	}

	/**
	 * @description Calls the API_PostExample outbound service using UTIL_HttpClient delegation.
	 * Stores the API response status in context.
	 */
	public class CallApiStep extends kern.UTIL_AsyncChain.ChainStep
	{
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
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Id foobarId = (Id)context.get(KEY_FOOBAR_ID);
			kern__Foobar__c record = (kern__Foobar__c)kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
					.fields(new List<SObjectField> {kern__Foobar__c.Name})
					.condition(kern__Foobar__c.Id).equals(foobarId)
					.getFirst();
			record.Name = record.Name + ' — Updated';
			kern.DML_Builder.newTransaction().doUpdate(record).execute();
			return kern.UTIL_AsyncChain.succeeded('Updated Foobar: ' + foobarId);
		}
	}

	/**
	 * @description Verifies that all prior context values are populated and the record exists.
	 * Reads foobarId and apiResponse from context, queries the Foobar, and writes a verification summary.
	 */
	public class VerifyContextStep extends kern.UTIL_AsyncChain.ChainStep
	{
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			Id foobarId = (Id)context.get(KEY_FOOBAR_ID);
			String apiResponse = (String)context.get(KEY_API_RESPONSE);

			if(foobarId == null)
			{
				return kern.UTIL_AsyncChain.failed('foobarId missing from context');
			}
			if(apiResponse == null)
			{
				return kern.UTIL_AsyncChain.failed('apiResponse missing from context');
			}

			kern__Foobar__c record =
			[
					SELECT Name
					FROM kern__Foobar__c
					WHERE Id = :foobarId
			];
			if(!record.Name.contains('Updated'))
			{
				return kern.UTIL_AsyncChain.failed('Foobar not updated by prior step: ' + record.Name);
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
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.failed('Deliberate subscriber failure');
		}
	}

	/**
	 * @description Error handler that records execution in context.
	 */
	public class ErrorHandlerStep extends kern.UTIL_AsyncChain.ChainStep
	{
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
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			context.put(KEY_COMPLETED, true);
			return kern.UTIL_AsyncChain.succeeded('Chain completed');
		}
	}

	/**
	 * @description Step that always fails. Used with then(step, true) to test continueOnError via builder.
	 */
	public class OptionalFailingStep extends kern.UTIL_AsyncChain.ChainStep
	{
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
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.succeeded('No-op step at ' + context.getCurrentStepIndex());
		}
	}
}
