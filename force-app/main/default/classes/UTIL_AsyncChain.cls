// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Lightweight async chain runner for sequencing jobs with shared state, error handling,
 * and progress tracking. Delegates to existing async and logging infrastructure.
 *
 * @see UTIL_AsyncChain_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_AsyncChain.newChain('DataMigration')
 *     .then(new LoadDataStep())
 *     .then(new TransformDataStep())
 *     .onError(new NotifyAdminStep())
 *     .execute();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.ExcessiveParameterList,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters')
global inherited sharing class UTIL_AsyncChain
{
	/**
	 * @description Default maximum number of steps permitted in a single chain.
	 */
	private static final Integer DEFAULT_MAX_STEPS = 50;

	/**
	 * @description Default maximum serialized context size in characters.
	 */
	private static final Integer DEFAULT_MAX_CONTEXT_SIZE = 32768;

	/**
	 * @description Reserved context key for persisting the previous step result across async transactions.
	 */
	private static final String PREVIOUS_RESULT_KEY = '__previousStepResult';

	/**
	 * @description Reserved context key for persisting the LOG_Builder context (correlation, parent transaction, context data).
	 */
	private static final String LOG_CONTEXT_KEY = '__logContext';

	/**
	 * @description Feature flag name used for the global async chain kill switch.
	 */
	@TestVisible
	private static final String FEATURE_FLAG_NAME = 'AsyncChain';

	/**
	 * @description Flag to simulate an unhandled Queueable crash for testing the Finalizer recovery path.
	 */
	@TestVisible
	private static Boolean simulateCrash = false;

	/**
	 * @description Flag to simulate a Finalizer enqueue failure for testing the graceful degradation path.
	 */
	@TestVisible
	private static Boolean simulateEnqueueFailure = false;

	/**
	 * @description Flag to simulate a HandlerExecutor crash for testing the handler Finalizer recovery path.
	 */
	@TestVisible
	private static Boolean simulateHandlerCrash = false;

	/**
	 * @description Context key prefix for persisting ApiStep configuration across async transactions.
	 */
	@TestVisible
	private static final String API_STEP_CONFIG_KEY_PREFIX = '__apiStep_';

	/**
	 * @description Context key prefix for storing ApiStep results for downstream steps.
	 */
	@TestVisible
	private static final String API_STEP_RESULT_KEY_PREFIX = '__apiResult_';

	/**
	 * @description Creates a new chain builder for composing a sequence of async steps.
	 *
	 * @param chainName A descriptive name for the chain, used in logs and status tracking.
	 *
	 * @return A new ChainBuilder instance for fluent configuration.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain('DataMigration');
	 * ```
	 */
	global static ChainBuilder newChain(String chainName)
	{
		return new ChainBuilder(chainName);
	}

	/**
	 * @description Retrieves the current status of a chain execution as a map of key-value pairs.
	 *
	 * @param chainExecutionId The ID of the AsyncChainExecution__c record to query.
	 *
	 * @return A map containing executionId, chainName, status, totalSteps, completedSteps, and errorMessage. Returns null if the record is not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, Object> status = UTIL_AsyncChain.getStatus(executionId);
	 * String currentStatus = (String)status.get('status');
	 * ```
	 */
	global static Map<String, Object> getStatus(Id chainExecutionId)
	{
		AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(chainExecutionId);

		if(execution == null)
		{
			return null;
		}

		return new Map<String, Object>
		{
				'executionId' => execution.Id,
				'chainName' => execution.ChainName__c,
				'status' => execution.Status__c,
				'totalSteps' => execution.TotalSteps__c,
				'completedSteps' => execution.CompletedSteps__c,
				'errorMessage' => execution.ErrorMessage__c
		};
	}

	/**
	 * @description Builds a DTO_StepDefinition from an IF_Chain.Step instance.
	 * Extracts stepName and continueOnError from ChainStep if applicable, otherwise uses defaults.
	 *
	 * @param step The step to build the definition from.
	 *
	 * @return A populated DTO_StepDefinition.
	 */
	private static DTO_StepDefinition buildDefinition(IF_Chain.Step step)
	{
		String className = UTIL_System.getRuntimeTypeName(step);
		DTO_StepDefinition definition = new DTO_StepDefinition();
		definition.className = className;

		if(step instanceof ChainStep)
		{
			ChainStep chainStep = (ChainStep)step;
			if(String.isNotBlank(chainStep.stepName) && chainStep.stepName != className)
			{
				definition.stepName = chainStep.stepName;
			}
			if(chainStep.continueOnError)
			{
				definition.continueOnError = true;
			}
		}

		return definition;
	}

	/**
	 * @description Instantiates a ChainStep from its class name using the framework type resolver.
	 *
	 * @param stepDefinition The step definition containing the class name to instantiate.
	 *
	 * @return A new ChainStep instance.
	 *
	 * @throws UTIL_Exceptions.ConfigurationException If the class cannot be found or instantiated.
	 */
	private static IF_Chain.Step instantiateStep(DTO_StepDefinition stepDefinition)
	{
		try
		{
			Type stepType = UTIL_System.getTypeForClassName(stepDefinition.className, IF_Chain.Step.class);
			return (IF_Chain.Step)stepType.newInstance();
		}
		catch(Exception error)
		{
			throw new UTIL_Exceptions.ConfigurationException
					(
							'Failed (Class Not Found: ' + stepDefinition.className + ') — ensure the class exists and has a public no-arg constructor.'
					);
		}
	}

	/**
	 * @description Abstract base class for individual steps in an async chain.
	 * Each step runs in its own Queueable transaction, providing governor limit isolation.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public class LoadDataStep extends UTIL_AsyncChain.ChainStep
	 * {
	 *     public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
	 *     {
	 *         List<Account> accounts = new SEL_Account().toList();
	 *         context.put('accountCount', accounts.size());
	 *         return UTIL_AsyncChain.succeeded('Loaded ' + accounts.size() + ' accounts');
	 *     }
	 * }
	 * ```
	 */
	global inherited sharing abstract class ChainStep implements IF_Chain.Step
	{
		/**
		 * @description Whether to continue the chain if this step fails. Default: false.
		 * Subscribers should use the builder overload then(step, true) instead.
		 */
		@TestVisible
		private Boolean continueOnError = false;

		/**
		 * @description Optional step name for identification in logs and status.
		 *
		 * @since 1.0
		 */
		global String stepName;

		/**
		 * @description Execute the step's business logic.
		 * Each step runs in its own Queueable transaction, so callouts and DML are both permitted.
		 * However, standard Apex ordering rules still apply WITHIN a step: perform all callouts
		 * before any DML. A step that does DML then a callout will throw CalloutException.
		 *
		 * **Do not call `UTIL_AsyncChain.newChain(...).execute()` from inside this method.** Async
		 * chains do not support nested execution. The inner chain consumes Queueable stack-depth
		 * budget against the outer chain (capped by `AsyncOptions.maximumQueueableStackDepth`,
		 * default 50), and ChainContext writes happen on the OUTER chain's `AsyncChainExecution__c`
		 * row only — the inner chain has its own row, totally disconnected. Either add the inner
		 * steps to the parent chain via `.then(...)` or enqueue a separate Queueable from outside
		 * the chain (e.g. from `onComplete`'s handler step) that targets a fresh chain.
		 *
		 * @param context Shared chain context for reading/writing state between steps.
		 *
		 * @return StepResult indicating success or failure.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		 * {
		 *     String previousValue = (String)context.get('inputKey');
		 *     context.put('outputKey', 'processed');
		 *     return UTIL_AsyncChain.succeeded('Done');
		 * }
		 * ```
		 */
		global abstract StepResult work(ChainContext context);
	}

	/**
	 * @description Immutable result object returned by each ChainStep to indicate success or failure.
	 * Use the static factory methods to create instances.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.succeeded('All records processed');
	 * UTIL_AsyncChain.StepResult failure = UTIL_AsyncChain.failed('Missing required field');
	 * ```
	 */
	global inherited sharing class StepResult
	{
		/**
		 * @description Whether the step completed successfully.
		 *
		 * @since 1.0
		 */
		global Boolean success {get; private set;}

		/**
		 * @description Optional human-readable message describing the outcome.
		 *
		 * @since 1.0
		 */
		global String message {get; private set;}

		/**
		 * @description Optional payload data returned by the step.
		 *
		 * @since 1.0
		 */
		global Object data {get; private set;}

		/**
		 * @description The exception that caused the step to fail, if applicable.
		 *
		 * @since 1.0
		 */
		global Exception error {get; private set;}

		/**
		 * @description Package-private constructor. Use outer class factory methods: succeeded() / failed().
		 */
		@TestVisible
		private StepResult()
		{
		}
	}

	/**
	 * @description Creates a successful step result with no message.
	 *
	 * @return A StepResult with success set to true.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * return UTIL_AsyncChain.succeeded();
	 * ```
	 */
	global static StepResult succeeded()
	{
		StepResult result = new StepResult();
		result.success = true;
		return result;
	}

	/**
	 * @description Creates a successful step result with a descriptive message.
	 *
	 * @param message A human-readable description of the successful outcome.
	 *
	 * @return A StepResult with success set to true and the provided message.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * return UTIL_AsyncChain.succeeded('Processed 42 records');
	 * ```
	 */
	global static StepResult succeeded(String message)
	{
		StepResult result = succeeded();
		result.message = message;
		return result;
	}

	/**
	 * @description Creates a successful step result with a message and data payload.
	 * The data is serialized into the chain context between transactions, so keep it small —
	 * use record IDs or primitive values, not full SObject graphs or large collections.
	 *
	 * @param message A human-readable description of the successful outcome.
	 * @param data Arbitrary data to pass to subsequent steps via the context. Prefer IDs and primitives.
	 *
	 * @return A StepResult with success set to true, the provided message, and data.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Id> processedIds = new List<Id>{ record.Id };
	 * return UTIL_AsyncChain.succeeded('Processed records', processedIds);
	 * ```
	 */
	global static StepResult succeeded(String message, Object data)
	{
		StepResult result = succeeded(message);
		result.data = data;
		return result;
	}

	/**
	 * @description Creates a failed step result with a descriptive message.
	 *
	 * @param message A human-readable description of the failure.
	 *
	 * @return A StepResult with success set to false and the provided message.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * return UTIL_AsyncChain.failed('Required field is blank');
	 * ```
	 */
	global static StepResult failed(String message)
	{
		StepResult result = new StepResult();
		result.success = false;
		result.message = message;
		return result;
	}

	/**
	 * @description Creates a failed step result from an exception, using the exception message.
	 *
	 * @param error The exception that caused the failure.
	 *
	 * @return A StepResult with success set to false, the exception message, and the exception reference.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * try { riskyOperation(); }
	 * catch(Exception error) { return UTIL_AsyncChain.failed(error); }
	 * ```
	 */
	global static StepResult failed(Exception error)
	{
		StepResult result = failed(error.getMessage());
		result.error = error;
		return result;
	}

	/**
	 * @description Shared state container passed between chain steps. Provides key-value storage
	 * for inter-step communication and access to chain metadata such as execution ID and correlation ID.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * context.put('accountId', account.Id);
	 * Id accountId = (Id)context.get('accountId');
	 * Boolean hasKey = context.has('accountId');
	 * ```
	 */
	global inherited sharing class ChainContext
	{
		/**
		 * @description Internal key-value data store for inter-step communication.
		 */
		private Map<String, Object> data;

		/**
		 * @description The ID of the AsyncChainExecution__c record tracking this chain.
		 */
		private final String chainExecutionId;

		/**
		 * @description The correlation ID for log correlation across transactions.
		 */
		private final String correlationId;

		/**
		 * @description The zero-based index of the currently executing step.
		 */
		@TestVisible
		private Integer currentStepIndex;

		/**
		 * @description The result of the most recently completed step.
		 */
		private StepResult previousStepResult;

		/**
		 * @description Constructor for framework use only. Creates a new context with the given execution and correlation IDs.
		 *
		 * @param chainExecutionId The ID of the AsyncChainExecution__c record.
		 * @param correlationId The correlation ID for log correlation.
		 */
		@TestVisible
		private ChainContext(String chainExecutionId, String correlationId)
		{
			this.data = new Map<String, Object>();
			this.chainExecutionId = chainExecutionId;
			this.correlationId = correlationId;
		}

		/**
		 * @description Retrieves a value from the context by key.
		 *
		 * @param key The key to look up.
		 *
		 * @return The stored value, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Object value = context.get('recordCount');
		 * ```
		 */
		global Object get(String key)
		{
			return data.get(key);
		}

		/**
		 * @description Retrieves a value from the context and deserializes it to the specified type.
		 * Useful for retrieving complex objects that were stored via put() and serialized between transactions.
		 *
		 * @param key The key to look up.
		 * @param targetType The Apex Type to deserialize the value into.
		 *
		 * @return The deserialized value, or null if the key is not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<String> names = (List<String>)context.getAs('nameList', List<String>.class);
		 * ```
		 */
		global Object getAs(String key, Type targetType)
		{
			Object value = data.get(key);

			if(value == null)
			{
				return null;
			}

			if(targetType != null && Type.forName(UTIL_System.getRuntimeTypeName(value)) == targetType)
			{
				return value;
			}

			return JSON.deserialize(JSON.serialize(value), targetType);
		}

		/**
		 * @description Stores a value in the context under the given key.
		 *
		 * @param key The key to store the value under.
		 * @param value The value to store.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * context.put('batchSize', 200);
		 * ```
		 */
		global void put(String key, Object value)
		{
			data.put(key, value);
		}

		/**
		 * @description Checks whether the context contains a value for the given key.
		 *
		 * @param key The key to check.
		 *
		 * @return True if the key exists in the context, false otherwise.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * if(context.has('accountId'))
		 * {
		 *     Id accountId = (Id)context.get('accountId');
		 * }
		 * ```
		 */
		global Boolean has(String key)
		{
			return data.containsKey(key);
		}

		/**
		 * @description Returns the ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @return The chain execution record ID.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String executionId = context.getChainExecutionId();
		 * ```
		 */
		global String getChainExecutionId()
		{
			return chainExecutionId;
		}

		/**
		 * @description Returns the correlation ID for this chain, used for log correlation across transactions.
		 *
		 * @return The correlation ID string.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String correlationId = context.getCorrelationId();
		 * ```
		 */
		global String getCorrelationId()
		{
			return correlationId;
		}

		/**
		 * @description Returns the result of the most recently completed step. Returns null for the first step.
		 *
		 * @return The previous step's StepResult, or null if this is the first step.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.StepResult previous = context.getPreviousStepResult();
		 * if(previous != null && previous.success)
		 * {
		 *     String message = previous.message;
		 * }
		 * ```
		 */
		global StepResult getPreviousStepResult()
		{
			return previousStepResult;
		}

		/**
		 * @description Returns the zero-based index of the currently executing step.
		 * Useful for building idempotency keys (e.g., executionId + stepIndex).
		 *
		 * @return The current step index, or null for contexts not yet assigned to a step.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String idempotencyKey = context.getChainExecutionId() + '-' + context.getCurrentStepIndex();
		 * ```
		 */
		global Integer getCurrentStepIndex()
		{
			return currentStepIndex;
		}

		/**
		 * @description Sets the previous step result. Framework use only.
		 *
		 * @param result The StepResult to set as the previous step result.
		 */
		@TestVisible
		private void setPreviousStepResult(StepResult result)
		{
			this.previousStepResult = result;
		}

		/**
		 * @description Serializes the context data map to a JSON string for persistence.
		 *
		 * @return A JSON string representation of the context data.
		 */
		@TestVisible
		private String serialize()
		{
			return JSON.serialize(data);
		}

	}

	/**
	 * @description Deserializes a JSON string back into a ChainContext with the given metadata.
	 *
	 * @param serializedData The JSON string to deserialize.
	 * @param chainExecutionId The chain execution record ID.
	 * @param correlationId The correlation ID for log correlation.
	 *
	 * @return A new ChainContext populated with the deserialized data.
	 */
	@TestVisible
	private static ChainContext deserializeContext(String serializedData, String chainExecutionId, String correlationId)
	{
		ChainContext context = new ChainContext(chainExecutionId, correlationId);

		if(String.isNotBlank(serializedData))
		{
			context.data = (Map<String, Object>)JSON.deserializeUntyped(serializedData);
		}

		return context;
	}

	/**
	 * @description Fluent builder for configuring and executing an async chain.
	 * Provides methods for adding steps, setting context, configuring error/completion handlers, and executing the chain.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String executionId = UTIL_AsyncChain.newChain('OrderProcessing')
	 *     .then(new ValidateOrderStep())
	 *     .then(new ProcessPaymentStep())
	 *     .withInitialContext('orderId', order.Id)
	 *     .onError(new NotifyAdminStep())
	 *     .onComplete(new SendConfirmationStep())
	 *     .execute();
	 * ```
	 */
	global inherited sharing class ChainBuilder
	{
		/**
		 * @description The descriptive name for this chain.
		 */
		private final String chainName;

		/**
		 * @description The ordered list of step definitions to execute.
		 */
		private final List<DTO_StepDefinition> steps;

		/**
		 * @description Initial context data to seed the chain with.
		 */
		private final Map<String, Object> initialContext;

		/**
		 * @description The error handler step definition, invoked when a step fails.
		 */
		private DTO_StepDefinition errorHandler;

		/**
		 * @description The completion handler step definition, invoked when all steps succeed.
		 */
		private DTO_StepDefinition completionHandler;

		/**
		 * @description Maximum number of steps allowed in this chain.
		 */
		private Integer maxSteps;

		/**
		 * @description Maximum serialized context size in characters.
		 */
		private Integer maxContextSize;

		/**
		 * @description AsyncOptions controlling queueable stack depth. When null, the framework
		 * creates a default with maximumQueueableStackDepth = steps.size() + 1.
		 */
		private AsyncOptions asyncOptions;

		/**
		 * @description Guards against accidental double-execution of the same builder.
		 */
		private Boolean executed = false;

		/**
		 * @description Private constructor to enforce creation via the newChain() factory method.
		 *
		 * @param chainName The descriptive name for this chain.
		 */
		private ChainBuilder(String chainName)
		{
			this.chainName = chainName;
			this.steps = new List<DTO_StepDefinition>();
			this.initialContext = new Map<String, Object>();
			this.maxSteps = DEFAULT_MAX_STEPS;
			this.maxContextSize = DEFAULT_MAX_CONTEXT_SIZE;
		}

		/**
		 * @description Appends a step to the end of the chain.
		 *
		 * @param step The IF_Chain.Step implementation to add.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new FirstStep())
		 *     .then(new SecondStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder then(IF_Chain.Step step)
		{
			validateStepCapacity();
			if(step instanceof ApiStep)
			{
				((ApiStep)step).writeConfig(initialContext, steps.size());
			}
			steps.add(buildDefinition(step));
			return this;
		}

		/**
		 * @description Appends a step to the chain with explicit control over error continuation.
		 * Use this overload for IF_Chain.Step implementations that cannot extend ChainStep.
		 *
		 * @param step The IF_Chain.Step implementation to add.
		 * @param continueOnError When true, the chain continues past this step's failure.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new CriticalStep())
		 *     .then(new OptionalStep(), true)
		 *     .then(new FinalStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder then(IF_Chain.Step step, Boolean continueOnError)
		{
			validateStepCapacity();
			if(step instanceof ApiStep)
			{
				((ApiStep)step).writeConfig(initialContext, steps.size());
			}
			DTO_StepDefinition definition = buildDefinition(step);
			if(continueOnError == true)
			{
				definition.continueOnError = true;
			}
			steps.add(definition);
			return this;
		}

		/**
		 * @description Build-time guard that mirrors the runtime cap enforced by ChainExecutor.
		 * Throws when the next `.then(step)` call would push the chain past `maxSteps`, so
		 * subscribers discover the cap when defining the chain rather than mid-execution
		 * (when partial work has already been committed and rollback is impossible across
		 * Queueable transaction boundaries).
		 */
		private void validateStepCapacity()
		{
			if(steps.size() >= maxSteps)
			{
				throw new UTIL_Exceptions.IllegalStateException(
						'Chain step capacity exceeded: maxSteps=' + maxSteps
						+ ' but step #' + (steps.size() + 1) + ' attempted to be added. '
						+ 'Increase via .withMaxSteps(...) before adding more steps, '
						+ 'or split the work into multiple chains.');
			}
		}

		/**
		 * @description Seeds the chain context with an initial key-value pair before execution begins.
		 * This is additive — each call adds one key-value pair to the initial context map.
		 *
		 * @param key The context key.
		 * @param value The context value.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .withInitialContext('recordId', record.Id)
		 *     .withInitialContext('batchSize', 200)
		 *     .then(new ProcessStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withInitialContext(String key, Object value)
		{
			initialContext.put(key, value);
			return this;
		}

		/**
		 * @description Sets the maximum number of steps the chain is allowed to execute.
		 * Prevents runaway chains from consuming unlimited resources. Default: 50.
		 *
		 * @param maximumSteps The maximum number of steps permitted.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('ShortChain')
		 *     .withMaxSteps(10)
		 *     .then(new MyStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withMaxSteps(Integer maximumSteps)
		{
			this.maxSteps = maximumSteps;
			return this;
		}

		/**
		 * @description Sets the maximum serialized context size in characters.
		 * Prevents context overflow from storing large object graphs. Default: 32768.
		 *
		 * @param maximumSize The maximum context size in characters.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('LargeContextChain')
		 *     .withMaxContextSize(65536)
		 *     .then(new DataHeavyStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withMaxContextSize(Integer maximumSize)
		{
			this.maxContextSize = maximumSize;
			return this;
		}

		/**
		 * @description Sets the AsyncOptions controlling queueable stack depth. When provided,
		 * these options override the framework default (maximumQueueableStackDepth = steps.size() + 1).
		 * In tests, pass options with an explicit maximumQueueableStackDepth matching the expected
		 * chain depth to enable chained Queueable execution within Test.startTest/stopTest.
		 *
		 * @param options The AsyncOptions to use for queueable enqueuing.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * AsyncOptions options = new AsyncOptions();
		 * options.maximumQueueableStackDepth = 4;
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new Step1()).then(new Step2()).then(new Step3())
		 *     .withAsyncOptions(options)
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withAsyncOptions(AsyncOptions options)
		{
			this.asyncOptions = options;
			return this;
		}

		/**
		 * @description Registers an error handler step that executes when any step fails
		 * (unless the failing step has continueOnError set to true).
		 *
		 * @param errorHandlerStep The IF_Chain.Step to execute on failure. Receives the chain context with the failure details.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new RiskyStep())
		 *     .onError(new NotifyAdminStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder onError(IF_Chain.Step errorHandlerStep)
		{
			DTO_StepDefinition definition = buildDefinition(errorHandlerStep);
			definition.isErrorHandler = true;
			this.errorHandler = definition;
			return this;
		}

		/**
		 * @description Registers a completion handler step that executes ONLY when every step in
		 * the chain completes successfully. The completion handler does NOT run when the chain
		 * terminates in failure (i.e. when a step returns a failed StepResult OR throws and the
		 * step is not marked `continueOnError`).
		 *
		 * **Failure-path handler is a separate registration.** To run a step on failure, register
		 * an error handler via `.onError(...)`. The two handlers are mutually exclusive at runtime:
		 * exactly one of them fires per chain (success → onComplete, failure → onError), and
		 * neither fires if the chain is aborted by the framework kill switch. Subscribers needing
		 * "always-runs" cleanup (e.g. release a row lock, close a session) should put the cleanup
		 * inside the final step's `work()` body and use `continueOnError = true` on the step
		 * before it, so the final step runs regardless of upstream failures.
		 *
		 * @param completionHandlerStep The IF_Chain.Step to execute on successful completion.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new ProcessStep())
		 *     .onComplete(new SendConfirmationStep())   // success-only
		 *     .onError(new NotifyAdminStep())           // failure-only
		 *     .execute();
		 * ```
		 */
		global ChainBuilder onComplete(IF_Chain.Step completionHandlerStep)
		{
			DTO_StepDefinition definition = buildDefinition(completionHandlerStep);
			definition.isCompletionHandler = true;
			this.completionHandler = definition;
			return this;
		}

		/**
		 * @description Executes the chain with an auto-generated correlation ID.
		 * Persists the chain configuration and enqueues the first step.
		 *
		 * @return The ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String executionId = UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new MyStep())
		 *     .execute();
		 * ```
		 */
		global String execute()
		{
			String existingCorrelationId = LOG_Builder.correlationId;
			return execute(String.isNotBlank(existingCorrelationId) ? existingCorrelationId : UTIL_Random.randomUUID());
		}

		/**
		 * @description Executes the chain with a caller-supplied correlation ID for log tracing.
		 * Persists the chain configuration and enqueues the first step.
		 *
		 * @param correlationId The correlation ID to attach to all log entries for this chain.
		 *
		 * @return The ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String executionId = UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new MyStep())
		 *     .execute('my-correlation-id');
		 * ```
		 */
		global String execute(String correlationId)
		{
			if(executed)
			{
				throw new UTIL_Exceptions.IllegalStateException('Chain has already been executed. Create a new ChainBuilder via newChain().');
			}
			executed = true;

			initialContext.put(LOG_CONTEXT_KEY, LOG_Builder.serializeContext());

			AsyncChainExecution__c execution = new AsyncChainExecution__c
					(
							ChainName__c = chainName,
							Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
							TotalSteps__c = steps.size(),
							CompletedSteps__c = 0,
							StartedAt__c = Datetime.now(),
							CorrelationId__c = correlationId,
							ContextData__c = JSON.serialize(initialContext),
							StepLog__c = UTIL_String.abbreviate(JSON.serialize(steps, true), AsyncChainExecution__c.StepLog__c)
					);
			if(steps.isEmpty())
			{
				execution.Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED;
				execution.CompletedAt__c = Datetime.now();
				DML_Builder.newTransaction().withSystemMode().doInsert(execution).execute();
				return execution.Id;
			}

			DML_Builder.newTransaction().withSystemMode().doInsert(execution).execute();

			AsyncOptions options = asyncOptions != null ? asyncOptions : new AsyncOptions();

			if(asyncOptions == null)
			{
				options.maximumQueueableStackDepth = steps.size() + 1;
			}

			ChainExecutor executor = new ChainExecutor(execution.Id, 0, maxSteps, maxContextSize, errorHandler, completionHandler, options);

			if(asyncOptions != null)
			{
				System.enqueueJob(executor, options);
			}
			else
			{
				System.enqueueJob(executor);
			}

			return execution.Id;
		}

	}

	/**
	 * @description Chain step adapter that executes any API_Outbound handler as part of an async chain.
	 * Wraps the full web service lifecycle (validation, callout, response parsing, DML, ApiCall__c persistence)
	 * via UTIL_HttpClient delegation mode, allowing existing outbound services to run inside chains with
	 * zero changes to the service class.
	 *
	 * Configuration is stored in the ChainContext (not on the step instance) because steps are serialized
	 * as class names and instantiated via reflection. At build-time, the ChainBuilder calls writeConfig()
	 * to persist the step's configuration into the initial context. At execution-time, work() reads the
	 * configuration back from the context using the current step index.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.newChain('OrderProcessing')
	 *     .withInitialContext('orderId', order.Id)
	 *     .then(new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
	 *         .triggeringRecordFrom('orderId')
	 *         .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99'))
	 *     .then(new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
	 *         .triggeringRecordFrom('orderId')
	 *         .withParameterFrom('recipient', 'customerEmail'))
	 *     .onError(new NotifyAdminStep())
	 *     .execute();
	 * ```
	 */
	global inherited sharing class ApiStep extends ChainStep
	{
		/**
		 * @description The API_Outbound subclass to execute. Build-time only — not serialized.
		 */
		private final Type handlerType;

		/**
		 * @description Named Credential override for this handler instance. Build-time only.
		 */
		private String credentialOverride;

		/**
		 * @description Static parameters passed directly to the handler. Build-time only.
		 */
		private final Map<String, String> staticParameters
		{
			get
			{
				if(staticParameters == null)
				{
					staticParameters = new Map<String, String>();
				}
				return staticParameters;
			}
			set;
		}

		/**
		 * @description Mappings from handler parameter names to ChainContext keys. Build-time only.
		 */
		private final Map<String, String> contextMappings
		{
			get
			{
				if(contextMappings == null)
				{
					contextMappings = new Map<String, String>();
				}
				return contextMappings;
			}
			set;
		}

		/**
		 * @description Static triggering record ID. Build-time only.
		 */
		private String triggeringRecordIdValue;

		/**
		 * @description ChainContext key containing the triggering record ID. Build-time only.
		 */
		private String triggeringRecordContextKey;

		/**
		 * @description No-argument constructor for reflection-based instantiation by the chain executor.
		 * Do not use directly — use the Type constructor instead.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public ApiStep()
		{
			// Required by Type.newInstance() — chain executor rehydrates via the Type constructor.
		}

		/**
		 * @description Creates an ApiStep that wraps the specified API_Outbound handler.
		 *
		 * @param handlerType The API_Outbound subclass to execute (e.g., API_SendEmail.class).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
		 *     .withParameter(API_SendEmail.PARAM_RECIPIENT, 'test@example.com')
		 *     .triggeringRecordFrom('recordId')
		 * ```
		 */
		global ApiStep(Type handlerType)
		{
			UTIL_System.assertTypeAssignable(API_Outbound.class, handlerType);
			this.handlerType = handlerType;
			this.stepName = handlerType.getName();
		}

		/**
		 * @description Overrides the Named Credential used for this API call.
		 *
		 * @param namedCredential The Named Credential developer name.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
		 *     .credential('AlternateGateway')
		 * ```
		 */
		global ApiStep credential(String namedCredential)
		{
			this.credentialOverride = namedCredential;
			return this;
		}

		/**
		 * @description Adds a static parameter value to pass to the handler.
		 *
		 * @param name The parameter name (use the handler's PARAM_* constants).
		 * @param value The parameter value.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		 *     .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99')
		 *     .withParameter(API_ChargePayment.PARAM_CURRENCY, 'USD')
		 * ```
		 */
		global ApiStep withParameter(String name, String value)
		{
			this.staticParameters.put(name, value);
			return this;
		}

		/**
		 * @description Maps a handler parameter to a ChainContext key, resolved at execution-time.
		 * Use this when the parameter value is produced by a prior step in the chain.
		 *
		 * @param parameterName The handler parameter name.
		 * @param contextKey The ChainContext key to read the value from.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
		 *     .withParameterFrom('recipient', 'customerEmail')
		 * ```
		 */
		global ApiStep withParameterFrom(String parameterName, String contextKey)
		{
			this.contextMappings.put(parameterName, contextKey);
			return this;
		}

		/**
		 * @description Sets a static triggering record ID for this API call.
		 *
		 * @param recordId The Salesforce record ID.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
		 *     .triggeringRecord(account.Id)
		 * ```
		 */
		global ApiStep triggeringRecord(Id recordId)
		{
			this.triggeringRecordIdValue = String.valueOf(recordId);
			return this;
		}

		/**
		 * @description Sets the triggering record ID from a ChainContext key, resolved at execution-time.
		 *
		 * @param contextKey The ChainContext key containing the record ID.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		 *     .triggeringRecordFrom('orderId')
		 * ```
		 */
		global ApiStep triggeringRecordFrom(String contextKey)
		{
			this.triggeringRecordContextKey = contextKey;
			return this;
		}

		/**
		 * @description Persists this step's configuration into the chain's initial context map.
		 * Called by ChainBuilder.then() at build-time so the configuration survives reflection instantiation.
		 *
		 * @param initialContext The chain's initial context map to write configuration into.
		 * @param stepIndex The zero-based index of this step in the chain.
		 */
		@TestVisible
		private void writeConfig(Map<String, Object> initialContext, Integer stepIndex)
		{
			Map<String, Object> config = new Map<String, Object>();
			config.put('handlerClassName', handlerType.getName());

			if(String.isNotBlank(credentialOverride))
			{
				config.put('credential', credentialOverride);
			}
			if(!staticParameters.isEmpty())
			{
				config.put('staticParams', staticParameters);
			}
			if(!contextMappings.isEmpty())
			{
				config.put('contextMappings', contextMappings);
			}
			if(String.isNotBlank(triggeringRecordIdValue))
			{
				config.put('triggeringRecordId', triggeringRecordIdValue);
			}
			if(String.isNotBlank(triggeringRecordContextKey))
			{
				config.put('triggeringRecordContextKey', triggeringRecordContextKey);
			}

			initialContext.put(API_STEP_CONFIG_KEY_PREFIX + stepIndex, config);
		}

		/**
		 * @description Executes the API_Outbound handler via UTIL_HttpClient delegation mode.
		 * Reads configuration from the ChainContext, builds the request, invokes the handler,
		 * and writes results back to the context for downstream steps.
		 *
		 * @param context Shared chain context for reading configuration and writing results.
		 *
		 * @return StepResult indicating success or failure of the API call.
		 *
		 * @since 1.0
		 */
		global override StepResult work(ChainContext context)
		{
			Integer stepIndex = context.getCurrentStepIndex();
			Map<String, Object> config = (Map<String, Object>)context.get(API_STEP_CONFIG_KEY_PREFIX + stepIndex);

			if(config == null)
			{
				return UTIL_AsyncChain.failed('ApiStep configuration not found for step index ' + stepIndex);
			}

			String handlerClassName = (String)config.get('handlerClassName');
			Type resolvedHandlerType = Type.forName(handlerClassName);

			if(resolvedHandlerType == null)
			{
				return UTIL_AsyncChain.failed('Handler class not found: ' + handlerClassName);
			}

			UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.useHandler(resolvedHandlerType);

			String credential = (String)config.get('credential');
			if(String.isNotBlank(credential))
			{
				builder.credential(credential);
			}

			Map<String, Object> staticParams = (Map<String, Object>)config.get('staticParams');
			if(staticParams != null)
			{
				for(String parameterName : staticParams.keySet())
				{
					builder.withParameter(parameterName, String.valueOf(staticParams.get(parameterName)));
				}
			}

			Map<String, Object> mappings = (Map<String, Object>)config.get('contextMappings');
			if(mappings != null)
			{
				for(String parameterName : mappings.keySet())
				{
					String contextKey = (String)mappings.get(parameterName);
					Object contextValue = context.get(contextKey);
					if(contextValue != null)
					{
						builder.withParameter(parameterName, String.valueOf(contextValue));
					}
				}
			}

			String staticRecordId = (String)config.get('triggeringRecordId');
			String recordContextKey = (String)config.get('triggeringRecordContextKey');
			if(String.isNotBlank(staticRecordId))
			{
				builder.withTriggeringRecord(Id.valueOf(staticRecordId));
			}
			else if(String.isNotBlank(recordContextKey))
			{
				Object recordIdValue = context.get(recordContextKey);
				if(recordIdValue != null)
				{
					builder.withTriggeringRecord(Id.valueOf(String.valueOf(recordIdValue)));
				}
			}

			builder.withCorrelationId(context.getCorrelationId());

			API_Outbound handler = builder.invoke();

			Map<String, Object> apiResult = new Map<String, Object>
			{
					'success' => handler.result.isSuccess,
					'statusCode' => handler.result.statusCode,
					'apiCallId' => handler.apiCall?.Id
			};

			String errors = handler.errorText;
			if(String.isNotBlank(errors))
			{
				apiResult.put('errors', errors);
			}

			context.put(API_STEP_RESULT_KEY_PREFIX + stepIndex, apiResult);

			if(handler.result.isSuccess)
			{
				return UTIL_AsyncChain.succeeded(handlerClassName + ' completed (HTTP ' + handler.result.statusCode + ')');
			}

			String errorMessage = handlerClassName + ' failed';
			if(String.isNotBlank(errors))
			{
				errorMessage += ': ' + errors;
			}
			return UTIL_AsyncChain.failed(errorMessage);
		}
	}

	/**
	 * @description Step definition DTO representing a single step's configuration and runtime state.
	 * Serialized to the StepLog__c field as a JSON array. Public for internal framework access
	 * (e.g., CTRL_ChainMonitor) but not global — subscribers interact via ChainStep and StepResult.
	 */
	public inherited sharing class DTO_StepDefinition
	{
		/**
		 * @description Fully-qualified or short class name.
		 */
		public String className;

		/**
		 * @description Display name for logs and status.
		 */
		public String stepName;

		/**
		 * @description Whether to continue the chain if this step fails. Null = false (suppressed from JSON).
		 */
		public Boolean continueOnError;

		/**
		 * @description Whether this step succeeded. Set at runtime after step execution.
		 */
		public Boolean success;

		/**
		 * @description Step execution duration in milliseconds. Set at runtime.
		 */
		public Long durationMs;

		/**
		 * @description Failure message. Set at runtime only when the step fails.
		 */
		public String message;

		/**
		 * @description True for onError() handler.
		 */
		public Boolean isErrorHandler;

		/**
		 * @description True for onComplete() handler. Null = false (suppressed from JSON).
		 */
		public Boolean isCompletionHandler;
	}

	/**
	 * @description Queueable executor that runs a single chain step per transaction and enqueues
	 * the next step upon completion. Also implements Finalizer for unhandled exception recovery.
	 */
	@TestVisible
	@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
	private inherited sharing class ChainExecutor implements Queueable, Database.AllowsCallouts, Finalizer
	{
		/**
		 * @description The ID of the AsyncChainExecution__c record being executed.
		 */
		private final Id chainExecutionId;

		/**
		 * @description The zero-based index of the current step to execute.
		 */
		private final Integer currentStepIndex;

		/**
		 * @description Maximum number of steps allowed in this chain.
		 */
		private final Integer maxSteps;

		/**
		 * @description Maximum serialized context size in characters.
		 */
		private final Integer maxContextSize;

		/**
		 * @description The error handler step definition, if configured.
		 */
		private final DTO_StepDefinition errorHandler;

		/**
		 * @description The completion handler step definition, if configured.
		 */
		private final DTO_StepDefinition completionHandler;

		/**
		 * @description AsyncOptions controlling queueable stack depth for chained execution.
		 */
		private final AsyncOptions asyncOptions;

		/**
		 * @description Flag set during execute() to signal that the Finalizer should chain to the next step.
		 */
		private Boolean shouldChainNext = false;

		/**
		 * @description Pending handler to enqueue from the Finalizer for transaction isolation.
		 * Set by handleChainCompletion or handleStepFailure when a handler is configured.
		 */
		private HandlerExecutor pendingHandler;

		/**
		 * @description Constructs a new ChainExecutor for the given chain execution.
		 *
		 * @param chainExecutionId The ID of the AsyncChainExecution__c record.
		 * @param currentStepIndex The zero-based index of the step to execute.
		 * @param maxSteps Maximum number of steps allowed.
		 * @param maxContextSize Maximum serialized context size in characters.
		 * @param errorHandler The error handler step definition, or null.
		 * @param completionHandler The completion handler step definition, or null.
		 * @param asyncOptions AsyncOptions for controlling queueable chaining depth.
		 */
		@TestVisible
		private ChainExecutor
				(
						Id chainExecutionId,
						Integer currentStepIndex,
						Integer maxSteps,
						Integer maxContextSize,
						DTO_StepDefinition errorHandler,
						DTO_StepDefinition completionHandler,
						AsyncOptions asyncOptions
				)
		{
			this.chainExecutionId = chainExecutionId;
			this.currentStepIndex = currentStepIndex;
			this.maxSteps = maxSteps;
			this.maxContextSize = maxContextSize;
			this.errorHandler = errorHandler;
			this.completionHandler = completionHandler;
			this.asyncOptions = asyncOptions;
		}

		/**
		 * @description Executes the current step and enqueues the next step if the chain should continue.
		 *
		 * @param queueableContext The Queueable context provided by the platform.
		 */
		public void execute(QueueableContext queueableContext)
		{
			System.attachFinalizer(this);

			AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(chainExecutionId);

			if(execution == null)
			{
				LOG_Builder.build().warn('Chain execution record deleted externally')
						.at(UTIL_AsyncChain.class.getName() + '.ChainExecutor.execute')
						.forRecord(chainExecutionId)
						.emit();
				return;
			}

			if(execution.Status__c == SEL_AsyncChainExecution.STATUS_ABORTED)
			{
				return;
			}

			List<DTO_StepDefinition> steps = (List<DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<DTO_StepDefinition>.class);
			ChainContext context = deserializeContext(execution.ContextData__c, execution.Id, execution.CorrelationId__c);

			String serializedLogContext = (String)context.get(LOG_CONTEXT_KEY);
			if(String.isNotBlank(serializedLogContext))
			{
				LOG_Builder.hydrateContext(serializedLogContext);
			}
			else
			{
				LOG_Builder.setCorrelationId(execution.CorrelationId__c);
			}

			if(!UTIL_FeatureFlag.isEnabled(FEATURE_FLAG_NAME))
			{
				markAborted(execution, 'Kill switch active');
				return;
			}

			if(simulateCrash)
			{
				simulateCrash = false;
				throw new UTIL_Exceptions.IllegalStateException('Simulated Queueable crash');
			}
			context.currentStepIndex = currentStepIndex;
			restorePreviousStepResult(context);

			DTO_StepDefinition stepDefinition = steps[currentStepIndex];
			String displayName = String.isNotBlank(stepDefinition.stepName) ? stepDefinition.stepName : stepDefinition.className;
			StepResult result;
			String executorClass = UTIL_AsyncChain.class.getName() + '.ChainExecutor.execute';

			UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(
					'Chain step: ' + displayName, executorClass
			);
			timer.start();

			try
			{
				IF_Chain.Step step = instantiateStep(stepDefinition);
				result = step.work(context);
			}
			catch(Exception error)
			{
				result = failed(error);
				LOG_Builder.build().error(error)
						.at(executorClass)
						.forRecord(execution.Id)
						.emit();
			}

			timer.stop();
			Long stepDurationMs = timer.getTime();

			stepDefinition.success = result.success;
			stepDefinition.durationMs = stepDurationMs;
			if(!result.success)
			{
				stepDefinition.message = result.message;
			}

			context.setPreviousStepResult(result);
			persistPreviousStepResult(context, result);

			if(!result.success && stepDefinition.continueOnError != true)
			{
				execution.StepLog__c = UTIL_String.abbreviate(JSON.serialize(steps, true), AsyncChainExecution__c.StepLog__c);
				handleStepFailure(execution, context, stepDefinition, result);
				return;
			}

			if(!result.success && stepDefinition.continueOnError == true)
			{
				LOG_Builder.build().warn('Step failed but continuing: ' + displayName + ' (' + stepDurationMs + 'ms)')
						.at(executorClass)
						.forRecord(execution.Id)
						.withContext('message', result.message)
						.withContext('durationMs', stepDurationMs)
						.emit();
				appendContinuedFailure(execution, displayName, result.message);
			}

			if(result.success)
			{
				execution.CompletedSteps__c = (execution.CompletedSteps__c == null ? 0 : execution.CompletedSteps__c) + 1;
			}
			execution.CurrentStepName__c = UTIL_String.abbreviate(displayName, AsyncChainExecution__c.CurrentStepName__c);

			String serializedContext = context.serialize();
			Integer contextSize = serializedContext.length();
			Integer warningThreshold = (Integer)(maxContextSize * 0.8);

			if(contextSize > maxContextSize)
			{
				markFailed(execution, 'Chain context overflow: ' + contextSize + ' / ' + maxContextSize
						+ ' characters. Store record IDs in context, not full SObject graphs.');
				return;
			}

			if(contextSize > warningThreshold)
			{
				LOG_Builder.build().warn('Chain context approaching limit: ' + contextSize + ' / ' + maxContextSize + ' characters')
						.at(UTIL_AsyncChain.class.getName() + '.ChainExecutor.execute')
						.forRecord(execution.Id)
						.emit();
			}

			execution.ContextData__c = serializedContext;
			execution.StepLog__c = UTIL_String.abbreviate(JSON.serialize(steps, true), AsyncChainExecution__c.StepLog__c);

			if(currentStepIndex + 1 >= steps.size())
			{
				handleChainCompletion(execution, context);
				return;
			}

			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
			shouldChainNext = true;
		}

		/**
		 * @description Finalizer callback that chains to the next step on success, or marks the chain
		 * as Failed on unhandled exception (governor limits, platform errors). Prevents zombie chains
		 * stuck in Running status. Finalizers receive fresh governor limits from the platform.
		 *
		 * @param finalizerContext The Finalizer context provided by the platform.
		 */
		@SuppressWarnings('PMD.EmptyCatchBlock')
		public void execute(FinalizerContext finalizerContext)
		{
			if(finalizerContext.getResult() == ParentJobResult.SUCCESS && shouldChainNext)
			{
				try
				{
					if(simulateEnqueueFailure)
					{
						simulateEnqueueFailure = false;
						throw new UTIL_Exceptions.IllegalStateException('Simulated enqueue failure');
					}
					ChainExecutor nextExecutor = new ChainExecutor(chainExecutionId, currentStepIndex + 1, maxSteps, maxContextSize, errorHandler, completionHandler, asyncOptions);
					System.enqueueJob(nextExecutor, asyncOptions);
				}
				catch(Exception enqueueError)
				{
					markChainFailedFromFinalizer(chainExecutionId, 'Finalizer failed to enqueue next step: ' + enqueueError.getMessage());
				}
			}
			else if(finalizerContext.getResult() == ParentJobResult.SUCCESS && pendingHandler != null)
			{
				try
				{
					if(simulateEnqueueFailure)
					{
						simulateEnqueueFailure = false;
						throw new UTIL_Exceptions.IllegalStateException('Simulated handler enqueue failure');
					}
					System.enqueueJob(pendingHandler);
				}
				catch(Exception enqueueError)
				{
					markChainFailedFromFinalizer(chainExecutionId, 'Finalizer failed to enqueue handler: ' + enqueueError.getMessage());
				}
			}
			else if(finalizerContext.getResult() == ParentJobResult.UNHANDLED_EXCEPTION)
			{
				Exception unhandledError = finalizerContext.getException();
				String errorMessage = unhandledError != null ? unhandledError.getMessage() : 'Unknown unhandled exception';
				markChainFailedFromFinalizer(chainExecutionId, 'Queueable crashed (unhandled exception): ' + errorMessage);
			}
		}

		/**
		 * @description Marks a chain as Failed from the Finalizer context. Wraps DML in try/catch
		 * because the Finalizer is the last recovery point — if DML fails (e.g., row lock), the
		 * error is logged but the Finalizer must not throw.
		 *
		 * @param executionId The chain execution record ID.
		 * @param errorMessage The failure message.
		 */
		@TestVisible
		@SuppressWarnings('PMD.EmptyCatchBlock')
		private void markChainFailedFromFinalizer(Id executionId, String errorMessage)
		{
			try
			{
				AsyncChainExecution__c execution = new AsyncChainExecution__c
						(
								Id = executionId,
								Status__c = SEL_AsyncChainExecution.STATUS_FAILED,
								ErrorMessage__c = UTIL_String.abbreviate(errorMessage, AsyncChainExecution__c.ErrorMessage__c),
								CompletedAt__c = Datetime.now()
						);
				DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
			}
			catch(Exception dmlError)
			{
				LOG_Builder.build().error('Finalizer DML failed: ' + dmlError.getMessage() + ' | Original: ' + errorMessage)
						.at(UTIL_AsyncChain.class.getName() + '.ChainExecutor.Finalizer')
						.forRecord(executionId)
						.emit();
				return;
			}

			LOG_Builder.build().error(errorMessage)
					.at(UTIL_AsyncChain.class.getName() + '.ChainExecutor.Finalizer')
					.forRecord(executionId)
					.emit();
		}

		/**
		 * @description Handles a step failure by updating the execution record and optionally running the error handler.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param context The current chain context.
		 * @param stepDefinition The definition of the step that failed.
		 * @param result The failed StepResult.
		 */
		private void handleStepFailure(AsyncChainExecution__c execution, ChainContext context, DTO_StepDefinition stepDefinition, StepResult result)
		{
			String failedStepName = String.isNotBlank(stepDefinition.stepName) ? stepDefinition.stepName : stepDefinition.className;
			execution.CurrentStepName__c = UTIL_String.abbreviate(failedStepName, AsyncChainExecution__c.CurrentStepName__c);
			execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
			execution.ErrorMessage__c = UTIL_String.abbreviate(result.message, AsyncChainExecution__c.ErrorMessage__c);
			execution.CompletedAt__c = Datetime.now();
			setDuration(execution);
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			if(errorHandler != null)
			{
				pendingHandler = new HandlerExecutor(execution.Id, context, errorHandler, SEL_AsyncChainExecution.STATUS_FAILED, result.message);
			}
		}

		/**
		 * @description Handles successful chain completion by updating the execution record
		 * and optionally running the completion handler.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param context The current chain context.
		 */
		private void handleChainCompletion(AsyncChainExecution__c execution, ChainContext context)
		{
			execution.Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED;
			execution.CompletedAt__c = Datetime.now();
			setDuration(execution);
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
			logChainPerformance(execution);

			if(completionHandler != null)
			{
				pendingHandler = new HandlerExecutor(execution.Id, context, completionHandler, SEL_AsyncChainExecution.STATUS_COMPLETED, null);
			}
		}

		/**
		 * @description Marks the execution as failed with the given message.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param message The failure message to record.
		 */
		private void markFailed(AsyncChainExecution__c execution, String message)
		{
			execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
			execution.ErrorMessage__c = UTIL_String.abbreviate(message, AsyncChainExecution__c.ErrorMessage__c);
			execution.CompletedAt__c = Datetime.now();
			setDuration(execution);
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
			logChainPerformance(execution);
		}

		/**
		 * @description Marks the execution as aborted with the given message and logs a warning.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param message The abort reason to record.
		 */
		private void markAborted(AsyncChainExecution__c execution, String message)
		{
			execution.Status__c = SEL_AsyncChainExecution.STATUS_ABORTED;
			execution.ErrorMessage__c = UTIL_String.abbreviate(message, AsyncChainExecution__c.ErrorMessage__c);
			execution.CompletedAt__c = Datetime.now();
			setDuration(execution);
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			LOG_Builder.build().warn('Chain aborted: ' + message)
					.at(UTIL_AsyncChain.class.getName() + '.ChainExecutor.markAborted')
					.forRecord(execution.Id)
					.emit();
			logChainPerformance(execution);
		}

		/**
		 * @description Computes and sets the total chain duration from StartedAt to now.
		 *
		 * @param execution The execution record to update.
		 */
		private void setDuration(AsyncChainExecution__c execution)
		{
			if(execution.StartedAt__c != null)
			{
				execution.DurationMs__c = Datetime.now().getTime() - execution.StartedAt__c.getTime();
			}
		}

		/**
		 * @description Emits a chain-level performance log if performance logging is enabled and the
		 * total chain duration exceeds the configured threshold. Uses LOG_Engine.logPerformance()
		 * which respects LogSetting__c.EnablePerformanceLogging__c and PerformanceThresholdMs__c.
		 *
		 * @param execution The execution record with DurationMs__c set.
		 */
		private void logChainPerformance(AsyncChainExecution__c execution)
		{
			Long duration = execution.DurationMs__c != null ? execution.DurationMs__c.longValue() : 0;

			String summary = 'Chain ' + execution.ChainName__c + ' ' + execution.Status__c
					+ ': ' + (Integer)execution.CompletedSteps__c + '/' + (Integer)execution.TotalSteps__c
					+ ' steps in ' + duration + 'ms (wall-clock)';

			LOG_Engine.logPerformance(
					summary,
					null,
					UTIL_AsyncChain.class.getName() + '.ChainExecutor',
					duration
			);
		}

		/**
		 * @description Appends a non-fatal step failure summary to ErrorMessage for admin visibility.
		 * Called when a step with continueOnError fails but the chain continues.
		 *
		 * @param execution The execution record to update.
		 * @param stepName The name of the step that failed.
		 * @param failureMessage The failure reason.
		 */
		private void appendContinuedFailure(AsyncChainExecution__c execution, String stepName, String failureMessage)
		{
			String entry = stepName + ': ' + failureMessage;
			String combined = String.isBlank(execution.ErrorMessage__c)
					? 'Non-fatal step failures: ' + entry
					: execution.ErrorMessage__c + '; ' + entry;
			execution.ErrorMessage__c = UTIL_String.abbreviate(combined, AsyncChainExecution__c.ErrorMessage__c);
		}

	}

	/**
	 * @description Lightweight Queueable that executes a completion or error handler in its own
	 * transaction, guaranteeing governor limit isolation from the step that triggered it.
	 * Prevents CalloutException when a handler needs to make HTTP callouts after a step did DML.
	 */
	@TestVisible
	private inherited sharing class HandlerExecutor implements Queueable, Database.AllowsCallouts, Finalizer
	{
		private final Id executionId;
		private final ChainContext context;
		private final DTO_StepDefinition handlerDefinition;
		private final String expectedStatus;
		private final String originalErrorMessage;

		/**
		 * @description Constructs a HandlerExecutor.
		 *
		 * @param executionId The chain execution record ID.
		 * @param context The chain context to pass to the handler.
		 * @param handlerDefinition The handler step definition.
		 * @param expectedStatus The status to set if the handler succeeds.
		 * @param originalErrorMessage The original error message (for error handlers), null for completion handlers.
		 */
		@TestVisible
		private HandlerExecutor(Id executionId, ChainContext context, DTO_StepDefinition handlerDefinition, String expectedStatus, String originalErrorMessage)
		{
			this.executionId = executionId;
			this.context = context;
			this.handlerDefinition = handlerDefinition;
			this.expectedStatus = expectedStatus;
			this.originalErrorMessage = originalErrorMessage;
		}

		public void execute(QueueableContext queueableContext)
		{
			System.attachFinalizer(this);

			if(simulateHandlerCrash)
			{
				simulateHandlerCrash = false;
				throw new UTIL_Exceptions.IllegalStateException('Simulated handler crash');
			}

			StepResult result;

			try
			{
				IF_Chain.Step handler = instantiateStep(handlerDefinition);
				result = handler.work(context);
			}
			catch(Exception handlerError)
			{
				result = failed(handlerError);
			}

			AsyncChainExecution__c execution = new AsyncChainExecution__c(Id = executionId);
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);

			if(result.success)
			{
				execution.Status__c = expectedStatus;
				execution.ErrorMessage__c = UTIL_String.abbreviate(originalErrorMessage, AsyncChainExecution__c.ErrorMessage__c);
			}
			else
			{
				String errorMessage = String.isNotBlank(originalErrorMessage) ? originalErrorMessage + '; Handler failed: ' + result.message : 'Handler failed: ' + result.message;
				execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
				execution.ErrorMessage__c = UTIL_String.abbreviate(errorMessage, AsyncChainExecution__c.ErrorMessage__c);
			}

			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		}

		public void execute(FinalizerContext finalizerContext)
		{
			if(finalizerContext.getResult() == ParentJobResult.UNHANDLED_EXCEPTION)
			{
				Exception unhandledError = finalizerContext.getException();
				String errorMessage = 'Handler crashed: ' + (unhandledError != null ? unhandledError.getMessage() : 'Unknown');
				markHandlerFailed(executionId, errorMessage);
			}
		}

		/**
		 * @description Marks a chain as Failed from the HandlerExecutor Finalizer. Wraps DML in try/catch.
		 *
		 * @param handlerExecutionId The chain execution record ID.
		 * @param errorMessage The failure message.
		 */
		@TestVisible
		@SuppressWarnings('PMD.EmptyCatchBlock')
		private void markHandlerFailed(Id handlerExecutionId, String errorMessage)
		{
			try
			{
				AsyncChainExecution__c execution = new AsyncChainExecution__c
						(
								Id = handlerExecutionId,
								Status__c = SEL_AsyncChainExecution.STATUS_FAILED,
								ErrorMessage__c = UTIL_String.abbreviate(errorMessage, AsyncChainExecution__c.ErrorMessage__c),
								CompletedAt__c = Datetime.now()
						);
				DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
			}
			catch(Exception dmlError)
			{
				LOG_Builder.build().error('Handler Finalizer DML failed: ' + dmlError.getMessage())
						.at(UTIL_AsyncChain.class.getName() + '.HandlerExecutor.Finalizer')
						.forRecord(handlerExecutionId)
						.emit();
			}
		}
	}

	/**
	 * @description Persists the previous step result into the context data map for cross-transaction access.
	 *
	 * @param context The chain context to update.
	 * @param result The step result to persist.
	 */
	private static void persistPreviousStepResult(ChainContext context, StepResult result)
	{
		Map<String, Object> resultMap = new Map<String, Object>
		{
				'success' => result.success,
				'message' => result.message,
				'data' => result.data
		};
		context.put(PREVIOUS_RESULT_KEY, resultMap);
	}

	/**
	 * @description Restores the previous step result from the persisted context data map.
	 *
	 * @param context The chain context to read from and update.
	 */
	private static void restorePreviousStepResult(ChainContext context)
	{
		if(context.has(PREVIOUS_RESULT_KEY))
		{
			Map<String, Object> resultMap = (Map<String, Object>)context.get(PREVIOUS_RESULT_KEY);
			StepResult previous = new StepResult();
			previous.success = (Boolean)resultMap.get('success');
			previous.message = (String)resultMap.get('message');
			previous.data = resultMap.get('data');
			context.setPreviousStepResult(previous);
			context.data.remove(PREVIOUS_RESULT_KEY);
		}
	}
}