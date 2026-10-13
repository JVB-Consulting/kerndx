// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Factory for creating circuit breaker instances to prevent cascading failures
 * and provide fast failure when external services are unavailable.
 *
 * The circuit breaker has three states: CLOSED (normal operation), OPEN (failing fast),
 * and HALF_OPEN (testing recovery).
 *
 * Features:
 * - Three-state circuit breaker pattern (CLOSED, OPEN, HALF_OPEN)
 * - Configurable failure threshold and timeout periods
 * - Automatic state transitions based on success/failure rates
 * - Integration with Platform Cache for distributed state management
 * - Per-service circuit breaker instances with shared state across transactions
 * - Detailed state tracking and metrics
 * - Convenient execute() helpers for protected actions
 *
 * Circuit States:
 * - CLOSED: Normal operation, requests pass through
 * - OPEN: Circuit is open, requests fail immediately without attempting the call
 * - HALF_OPEN: Testing if service has recovered, limited requests allowed through
 *
 * State Transitions:
 * - CLOSED → OPEN: When failure count exceeds threshold
 * - OPEN → HALF_OPEN: After timeout period expires
 * - HALF_OPEN → CLOSED: When success count indicates recovery
 * - HALF_OPEN → OPEN: When failures continue
 * - HALF_OPEN stays HALF_OPEN with a new round of trial requests: when every trial request of the round was used,
 *   none of them closed or reopened the circuit, and the timeout period has passed since the round began
 *
 * @see API_Outbound
 * @see UTIL_CircuitBreaker_TEST
 * @see UTIL_Cache
 * @see UTIL_Retry
 *
 * @author Jason van Beukering
 *
 * @group Resilience
 *
 * @date December 2025, October 2026
 *
 * @since 1.0
 *
 * @example
 * Example 1: Simple usage with execute() helper (RECOMMENDED)
 * ```apex
 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail');
 * try
 * {
 *     breaker.execute(new SendEmailAction(emailData));
 * }
 * catch(UTIL_CircuitBreaker.OpenException e)
 * {
 *     // Circuit is open - handle gracefully
 * }
 * ```
 * Example 2: Manual control with allowRequest()
 * ```apex
 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail')
 *     .withFailureThreshold(5)
 *     .withTimeout(60);
 * if(breaker.allowRequest())
 * {
 *     try
 *     {
 *         // Make webservice call
 *         breaker.recordSuccess();
 *     }
 *     catch(Exception e)
 *     {
 *         breaker.recordFailure();
 *     }
 * }
 * ```
 * Example 3: An API_Outbound handler needs no breaker code. Check Circuit Breaker Enabled on the service's API setting
 * (it is off by default) and the framework checks a breaker named after the service before each send. While that breaker
 * is open, the call is not sent, and its errors hold the line "The circuit breaker for (the service name) is open after
 * repeated failures, so the request was not sent." A call whose setting allows retries is tried again after the cool-off
 * while retries remain; a call whose setting allows no retries ends Aborted. To spot that outcome in your own code:
 * ```apex
 * API_Outbound handler = UTIL_HttpClient.useHandler(API_SendGridEmail.class).invoke();
 * Boolean isCircuitOpen = handler != null && String.join(handler.result.errors, '\n').contains('is open after repeated failures');
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.ExcessiveClassLength')
global inherited sharing class UTIL_CircuitBreaker
{
	/**
	 * @description Class name for log source attribution on the state-transition entries.
	 */
	private static final String CLASS_NAME = UTIL_CircuitBreaker.class.getName();

	/**
	 * @description Default failure threshold before opening the circuit
	 */
	private static final Integer DEFAULT_FAILURE_THRESHOLD = 5;

	/**
	 * @description Default timeout in seconds before attempting recovery
	 */
	private static final Integer DEFAULT_TIMEOUT_SECONDS = 60;

	/**
	 * @description Default number of successful attempts needed in HALF_OPEN state to close circuit
	 */
	private static final Integer DEFAULT_SUCCESS_THRESHOLD = 2;

	/**
	 * @description Default number of requests allowed in HALF_OPEN state
	 */
	private static final Integer DEFAULT_HALF_OPEN_MAX_ATTEMPTS = 3;

	/**
	 * @description Buffer time (in seconds) to keep cache entry alive after timeout expires.
	 * This ensures the state still exists when the timeout completes, allowing the logic to transition to HALF_OPEN.
	 */
	private static final Integer TTL_BUFFER_SECONDS = 300;

	/**
	 * @description The log line written when a HALF_OPEN circuit starts a new round of trial requests; {0} is the
	 * circuit's id. It says why: every trial request of the round before was used, and none closed or reopened the
	 * circuit.
	 */
	private static final String MESSAGE_NEW_ROUND_OF_TRIALS =
			'Circuit breaker {0} started a new round of trial requests: every trial request of the round before was used and none closed or reopened the circuit';

	/**
	 * @description Cache partition name for circuit breaker state
	 *
	 * Uses the framework's standard Library partition for consistency with other framework components.
	 * This automatically resolves to 'local.Library' (unmanaged) or 'PackageNamespace.Library' (managed package).
	 *
	 * If the partition doesn't exist, the circuit breaker gracefully degrades to in-memory
	 * state (resets per transaction), which is suitable for testing but not production.
	 */
	private static final String cachePartition
	{
		get
		{
			if(cachePartition == null)
			{
				cachePartition = UTIL_Cache.getPlatformCacheName();
			}
			return cachePartition;
		}
		set;
	}

	/**
	 * @description Enum representing the circuit breaker state
	 *
	 * @since 1.0
	 */
	global enum State
	{
		/**
		 * @description Normal operation - requests pass through
		 */
		CLOSED,

		/**
		 * @description Circuit is open - requests fail fast without attempting call
		 */
		OPEN,

		/**
		 * @description Testing recovery - limited requests allowed to test if service recovered
		 */
		HALF_OPEN
	}

	/**
	 * @description Public class containing circuit breaker metrics
	 *
	 * @since 1.0
	 */
	global inherited sharing class Metrics
	{
		/**
		 * @description The circuit identifier
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.circuitId;
		 * ```
		 */
		global String circuitId;

		/**
		 * @description Current state of the circuit
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * State value = instance.state;
		 * ```
		 */
		global State state;

		/**
		 * @description Current failure count
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.failureCount;
		 * ```
		 */
		global Integer failureCount;

		/**
		 * @description Current consecutive success count
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.consecutiveSuccesses;
		 * ```
		 */
		global Integer consecutiveSuccesses;

		/**
		 * @description Time of last failure
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Datetime value = instance.lastFailureTime;
		 * ```
		 */
		global Datetime lastFailureTime;

		/**
		 * @description Time when the state last changed. While the circuit is HALF_OPEN it is the time the current round of
		 * trial requests began.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Datetime value = instance.stateChangedTime;
		 * ```
		 */
		global Datetime stateChangedTime;
	}

	/**
	 * @description Exception thrown when circuit breaker is OPEN and blocks a request
	 *
	 * @since 1.0
	 */
	global inherited sharing class OpenException extends Exception
	{
	}

	/**
	 * @description Interface for circuit breaker operations.
	 *
	 * This interface defines the contract for circuit breaker behavior, including:
	 * - Request gating (allowRequest)
	 * - Success/failure recording
	 * - State inspection and metrics
	 * - Configuration via fluent API
	 * - Convenient execute() helpers for protected actions
	 *
	 * @since 1.0
	 */
	global interface Breaker
	{
		/**
		 * @description Determines if a request is allowed through the circuit breaker
		 *
		 * @return True if the request should proceed, false if it should fail fast
		 *
		 * @since 1.0
		 */
		Boolean allowRequest();

		/**
		 * @description Records a successful request
		 *
		 * @since 1.0
		 */
		void recordSuccess();

		/**
		 * @description Records a failed request
		 *
		 * @since 1.0
		 */
		void recordFailure();

		/**
		 * @description Gets the current state of the circuit breaker
		 *
		 * @return The current circuit state
		 *
		 * @since 1.0
		 */
		State getState();

		/**
		 * @description Gets detailed metrics about the circuit breaker
		 *
		 * @return Circuit metrics including failure count, state, etc.
		 *
		 * @since 1.0
		 */
		Metrics getMetrics();

		/**
		 * @description Manually resets the circuit breaker to CLOSED state (use with caution)
		 *
		 * @since 1.0
		 */
		void reset();

		/**
		 * @description Manually forces the circuit breaker to OPEN state (use with caution)
		 *
		 * @since 1.0
		 */
		void forceOpen();

		/**
		 * @description Sets the failure threshold (fluent API)
		 *
		 * @param threshold Number of failures before opening the circuit
		 *
		 * @return This instance for method chaining
		 *
		 * @since 1.0
		 */
		Breaker withFailureThreshold(Integer threshold);

		/**
		 * @description Sets the timeout period in seconds (fluent API)
		 *
		 * @param seconds Timeout in seconds before transitioning from OPEN to HALF_OPEN
		 *
		 * @return This instance for method chaining
		 *
		 * @since 1.0
		 */
		Breaker withTimeout(Integer seconds);

		/**
		 * @description Sets the success threshold for HALF_OPEN state (fluent API)
		 *
		 * @param threshold Number of consecutive successes needed to close circuit
		 *
		 * @return This instance for method chaining
		 *
		 * @since 1.0
		 */
		Breaker withSuccessThreshold(Integer threshold);

		/**
		 * @description Sets the maximum attempts allowed in HALF_OPEN state (fluent API)
		 *
		 * @param maxAttempts Maximum number of requests allowed in HALF_OPEN state
		 *
		 * @return This instance for method chaining
		 *
		 * @since 1.0
		 */
		Breaker withHalfOpenMaxAttempts(Integer maxAttempts);

		/**
		 * @description Executes an action within the circuit breaker context
		 *
		 * This is a convenience method that abstracts the boilerplate pattern:
		 * - Checks if request is allowed (throws exception if circuit is OPEN)
		 * - Executes the action
		 * - Records success/failure automatically
		 *
		 * @param action The action to execute with circuit breaker protection
		 *
		 * @throws OpenException if the circuit is OPEN and request is blocked
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail');
		 * try
		 * {
		 *     breaker.execute(new SendEmailAction('user@example.com'));
		 * }
		 * catch(UTIL_CircuitBreaker.OpenException e)
		 * {
		 *     LOG_Builder.build().error(e).at('MyClass.sendEmail').emit();
		 *     // Handle circuit open scenario
		 * }
		 * ```
		 */
		void execute(ProtectedAction action);

		/**
		 * @description Executes an action within the circuit breaker context (with return value)
		 *
		 * This overload allows actions to return data, eliminating the need for member variables
		 * to capture API responses.
		 *
		 * @param action The action to execute with circuit breaker protection
		 *
		 * @return The result from action.execute() (caller must cast to appropriate type)
		 *
		 * @throws OpenException if the circuit is OPEN and request is blocked
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_GetCustomerData');
		 * try
		 * {
		 *     DTO_CustomerResponse response = (DTO_CustomerResponse)breaker.execute(
		 *         new GetCustomerDataProvider(customerId)
		 *     );
		 *     System.debug('Customer Name: ' + response.name);
		 * }
		 * catch(UTIL_CircuitBreaker.OpenException e)
		 * {
		 *     LOG_Builder.build().error(e).at('MyClass.getCustomerData').emit();
		 *     // Handle circuit open scenario
		 * }
		 * ```
		 */
		Object execute(Provider action);
	}

	/**
	 * @description Interface for code that needs circuit breaker protection (no return value)
	 *
	 * Implement this interface to use the simplified execute() method
	 * which handles allowRequest(), recordSuccess(), and recordFailure() automatically.
	 *
	 * Use Provider if your action needs to return a value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public class SendEmailAction implements UTIL_CircuitBreaker.ProtectedAction
	 * {
	 *     private String emailAddress;
	 *     public SendEmailAction(String emailAddress)
	 *     {
	 *         emailAddress = emailAddress;
	 *     }
	 *     public void execute()
	 *     {
	 *         // Protected code that may fail
	 *         Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ buildEmail() });
	 *     }
	 * }
	 * // Usage
	 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('EmailService');
	 * breaker.execute(new SendEmailAction('user@example.com'));
	 * ```
	 */
	global interface ProtectedAction
	{
		/**
		 * @description The code to execute with circuit breaker protection
		 *
		 * @since 1.0
		 */
		void execute();
	}

	/**
	 * @description Interface for code that needs circuit breaker protection (with return value)
	 *
	 * Implement this interface when your action needs to return data.
	 * Use ProtectedAction if no return value is needed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public class GetCustomerDataProvider implements UTIL_CircuitBreaker.Provider
	 * {
	 *     private Id customerId;
	 *     public GetCustomerDataProvider(Id customerId)
	 *     {
	 *         customerId = customerId;
	 *     }
	 *     public Object execute()
	 *     {
	 *         // Make API call and return response
	 *         HttpResponse response = makeApiCall();
	 *         return JSON.deserialize(response.getBody(), DTO_CustomerResponse.class);
	 *     }
	 * }
	 * // Usage
	 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_GetCustomerData');
	 * DTO_CustomerResponse customer = (DTO_CustomerResponse)breaker.execute(new GetCustomerDataProvider(customerId));
	 * ```
	 */
	global interface Provider
	{
		/**
		 * @description The code to execute with circuit breaker protection
		 *
		 * @return The result of the operation (caller must cast to appropriate type)
		 *
		 * @since 1.0
		 */
		Object execute();
	}

	/**
	 * @description Creates a new circuit breaker instance with default configuration
	 *
	 * Default configuration:
	 * - Failure threshold: 5 failures
	 * - Timeout: 60 seconds
	 * - Success threshold: 2 successes
	 * - Half-open max attempts: 3
	 *
	 * @param circuitId Unique identifier for this circuit (typically service class name)
	 *
	 * @return A new circuit breaker instance with defaults
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Use defaults
	 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail');
	 * // Customize with fluent API
	 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail')
	 *     .withFailureThreshold(10)
	 *     .withTimeout(120);
	 * ```
	 */
	global static Breaker monitor(String circuitId)
	{
		return new DefaultCircuitBreaker(circuitId, new CircuitConfiguration());
	}

	/**
	 * @description Creates a circuit breaker from ApiSetting metadata configuration.
	 * This is an internal framework method used by API_Outbound.
	 *
	 * Maps ApiSetting circuit breaker fields to configuration:
	 * - CircuitBreakerFailureThreshold__c → failure threshold
	 * - CircuitBreakerTimeout__c → timeout in seconds
	 * - CircuitBreakerSuccessThreshold__c → success threshold for half-open state
	 *
	 * The state is loaded from Platform Cache, which is shared across all transactions
	 * and user sessions.
	 *
	 * @param serviceName The service name (typically API class name)
	 * @param setting The API setting metadata record containing circuit breaker configuration
	 *
	 * @return A configured circuit breaker instance
	 */
	public static Breaker fromSetting(String serviceName, ApiSetting__mdt setting)
	{
		CircuitConfiguration configuration = new CircuitConfiguration();

		if(setting != null)
		{
			configuration.failureThreshold = setting.CircuitBreakerFailureThreshold__c != null ? setting.CircuitBreakerFailureThreshold__c.intValue() : DEFAULT_FAILURE_THRESHOLD;
			configuration.timeoutSeconds = setting.CircuitBreakerTimeout__c != null ? setting.CircuitBreakerTimeout__c.intValue() : DEFAULT_TIMEOUT_SECONDS;
			configuration.successThreshold = setting.CircuitBreakerSuccessThreshold__c != null ? setting.CircuitBreakerSuccessThreshold__c.intValue() : DEFAULT_SUCCESS_THRESHOLD;
		}

		return new DefaultCircuitBreaker(serviceName, configuration);
	}

	/**
	 * @description Configuration class for circuit breaker settings
	 * PRIVATE: Implementation detail not exposed to API consumers.
	 * Subscribers interact via fluent 'withX()' methods only.
	 */
	private class CircuitConfiguration
	{
		/**
		 * @description Number of consecutive failures before opening the circuit
		 */
		public Integer failureThreshold;

		/**
		 * @description Timeout in seconds before transitioning from OPEN to HALF_OPEN
		 */
		public Integer timeoutSeconds;

		/**
		 * @description Number of consecutive successes in HALF_OPEN state needed to close circuit
		 */
		public Integer successThreshold;

		/**
		 * @description Maximum number of requests allowed in HALF_OPEN state
		 */
		public Integer halfOpenMaxAttempts;

		/**
		 * @description Default constructor with standard values
		 */
		public CircuitConfiguration()
		{
			failureThreshold = DEFAULT_FAILURE_THRESHOLD;
			timeoutSeconds = DEFAULT_TIMEOUT_SECONDS;
			successThreshold = DEFAULT_SUCCESS_THRESHOLD;
			halfOpenMaxAttempts = DEFAULT_HALF_OPEN_MAX_ATTEMPTS;
		}
	}

	/**
	 * @description Internal class to track circuit state, needs to be public for type resolution
	 */
	public class CircuitState
	{
		/**
		 * @description Current state of the circuit breaker
		 */
		private State state;

		/**
		 * @description Time of last failure
		 */
		private Datetime lastFailureTime;

		/**
		 * @description Time when the state last changed. While the circuit is HALF_OPEN it is the time the current round of
		 * trial requests began, which is later than the change to HALF_OPEN once a new round has started.
		 */
		private Datetime stateChangedTime;

		/**
		 * @description Current consecutive success count
		 */
		private Integer consecutiveSuccesses;

		/**
		 * @description Current failure count
		 */
		private Integer failureCount;

		/**
		 * @description Number of trial requests let through in the current round while the circuit is HALF_OPEN
		 */
		private Integer halfOpenAttempts;
	}

	/**
	 * @description Default implementation of Breaker interface
	 * PRIVATE: Implementation detail not exposed to API consumers.
	 * Subscribers only interact via the Breaker interface.
	 */
	@SuppressWarnings('PMD.CyclomaticComplexity')
	@TestVisible
	private class DefaultCircuitBreaker implements Breaker
	{
		/**
		 * @description The unique identifier for this circuit breaker instance (typically service name)
		 */
		private final String circuitId;

		/**
		 * @description Configuration for this circuit breaker
		 */
		private final CircuitConfiguration configuration;

		/**
		 * @description Current state of the circuit breaker
		 */
		private final CircuitState currentState;

		/**
		 * @description Flag to skip the next updateStateIfNeeded() check after a transition
		 */
		private transient Boolean skipNextUpdate = false;

		/**
		 * @description Private constructor - use factory methods instead
		 *
		 * @param circuitId Unique identifier for this circuit (typically service class name)
		 * @param configuration Configuration for the circuit breaker
		 */
		private DefaultCircuitBreaker(String circuitId, CircuitConfiguration configuration)
		{
			this.circuitId = circuitId;
			this.configuration = configuration ?? new CircuitConfiguration();
			currentState = loadState();
		}

		/**
		 * @description Determines if a request is allowed through the circuit breaker
		 *
		 * @return True if the request should proceed, false if it should fail fast
		 */
		public Boolean allowRequest()
		{
			updateStateIfNeeded();

			switch on currentState.state
			{
				when OPEN
				{
					return false;
				}
				when HALF_OPEN
				{
					// Allow limited requests in half-open state
					Boolean allowed = !hasUsedEveryTrialRequest();
					if(allowed)
					{
						currentState.halfOpenAttempts++;
						saveState();
					}
					return allowed;
				}
				//This is "CLOSED" state
				when else
				{
					return true;
				}
			}
		}

		/**
		 * @description Records a successful request
		 */
		public void recordSuccess()
		{
			updateStateIfNeeded();

			switch on currentState.state
			{
				when CLOSED
				{
					// Reset failure count on success in CLOSED state
					currentState.failureCount = 0;
					currentState.consecutiveSuccesses = 0;
				}
				when HALF_OPEN
				{
					currentState.consecutiveSuccesses++;

					// Transition to CLOSED if we have enough successes
					if(currentState.consecutiveSuccesses >= configuration.successThreshold)
					{
						transitionToClosed();
					}
				}
			}

			saveState();
		}

		/**
		 * @description Records a failed request
		 */
		public void recordFailure()
		{
			updateStateIfNeeded();

			switch on currentState.state
			{
				when CLOSED
				{
					currentState.failureCount++;
					currentState.consecutiveSuccesses = 0;

					// Transition to OPEN if failure threshold exceeded
					if(currentState.failureCount >= configuration.failureThreshold)
					{
						transitionToOpen();
					}
				}
				when HALF_OPEN
				{
					// Any failure in HALF_OPEN transitions back to OPEN
					transitionToOpen();
				}
			}

			saveState();
		}

		/**
		 * @description Gets the current state of the circuit breaker
		 *
		 * @return The current circuit state
		 */
		public State getState()
		{
			updateStateIfNeeded();
			return currentState.state;
		}

		/**
		 * @description Gets detailed metrics about the circuit breaker
		 *
		 * @return Circuit metrics including failure count, state, etc.
		 */
		public Metrics getMetrics()
		{
			updateStateIfNeeded();

			Metrics metrics = new Metrics();
			metrics.circuitId = circuitId;
			metrics.state = currentState.state;
			metrics.failureCount = currentState.failureCount;
			metrics.consecutiveSuccesses = currentState.consecutiveSuccesses;
			metrics.lastFailureTime = currentState.lastFailureTime;
			metrics.stateChangedTime = currentState.stateChangedTime;

			return metrics;
		}

		/**
		 * @description Manually resets the circuit breaker to CLOSED state (use with caution)
		 */
		public void reset()
		{
			transitionToClosed();
			saveState();
		}

		/**
		 * @description Manually forces the circuit breaker to OPEN state (use with caution)
		 */
		public void forceOpen()
		{
			transitionToOpen();
			saveState();
		}

		/**
		 * @description Sets the failure threshold (fluent API)
		 *
		 * @param threshold Number of failures before opening the circuit
		 *
		 * @return This instance for method chaining
		 */
		public Breaker withFailureThreshold(Integer threshold)
		{
			configuration.failureThreshold = threshold;
			return this;
		}

		/**
		 * @description Sets the timeout period in seconds (fluent API)
		 *
		 * @param seconds Timeout in seconds before transitioning from OPEN to HALF_OPEN
		 *
		 * @return This instance for method chaining
		 */
		public Breaker withTimeout(Integer seconds)
		{
			configuration.timeoutSeconds = seconds;
			return this;
		}

		/**
		 * @description Sets the success threshold for HALF_OPEN state (fluent API)
		 *
		 * @param threshold Number of consecutive successes needed to close circuit
		 *
		 * @return This instance for method chaining
		 */
		public Breaker withSuccessThreshold(Integer threshold)
		{
			configuration.successThreshold = threshold;
			return this;
		}

		/**
		 * @description Sets the maximum attempts allowed in HALF_OPEN state (fluent API)
		 *
		 * @param maxAttempts Maximum number of requests allowed in HALF_OPEN state
		 *
		 * @return This instance for method chaining
		 */
		public Breaker withHalfOpenMaxAttempts(Integer maxAttempts)
		{
			configuration.halfOpenMaxAttempts = maxAttempts;
			return this;
		}

		/**
		 * @description Executes an action within the circuit breaker context
		 *
		 * This is a convenience method that abstracts the boilerplate pattern:
		 * - Checks if request is allowed (throws exception if circuit is OPEN)
		 * - Executes the action
		 * - Records success/failure automatically
		 *
		 * @param action The action to execute with circuit breaker protection
		 *
		 * @throws OpenException if the circuit is OPEN and request is blocked
		 *
		 * @example
		 * ```apex
		 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail');
		 * try
		 * {
		 *     breaker.execute(new SendEmailAction('user@example.com'));
		 * }
		 * catch(UTIL_CircuitBreaker.OpenException e)
		 * {
		 *     LOG_Builder.build().error(e).at('MyClass.sendEmail').emit();
		 *     // Handle circuit open scenario
		 * }
		 * ```
		 */
		public void execute(ProtectedAction action)
		{
			if(!allowRequest())
			{
				throw new OpenException('Circuit breaker ' + circuitId + ' is OPEN - service temporarily unavailable');
			}

			try
			{
				action.execute();
				recordSuccess();
			}
			catch(Exception error)
			{
				recordFailure();
				throw error; // Re-throw so the caller knows it failed
			}
		}

		/**
		 * @description Executes an action within the circuit breaker context (with return value)
		 *
		 * This overload allows actions to return data, eliminating the need for member variables
		 * to capture API responses.
		 *
		 * @param action The action to execute with circuit breaker protection
		 *
		 * @return The result from action.execute() (caller must cast to appropriate type)
		 *
		 * @throws OpenException if the circuit is OPEN and request is blocked
		 *
		 * @example
		 * ```apex
		 * UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_GetCustomerData');
		 * try
		 * {
		 *     DTO_CustomerResponse response = (DTO_CustomerResponse)breaker.execute(
		 *         new GetCustomerDataProvider(customerId)
		 *     );
		 *     System.debug('Customer Name: ' + response.name);
		 * }
		 * catch(UTIL_CircuitBreaker.OpenException e)
		 * {
		 *     LOG_Builder.build().error(e).at('MyClass.getCustomerData').emit();
		 *     // Handle circuit open scenario
		 * }
		 * ```
		 */
		public Object execute(Provider action)
		{
			if(!allowRequest())
			{
				throw new OpenException('Circuit breaker ' + circuitId + ' is OPEN - service temporarily unavailable');
			}

			try
			{
				Object result = action.execute();
				recordSuccess();
				return result;
			}
			catch(Exception error)
			{
				recordFailure();
				throw error; // Re-throw so the caller knows it failed
			}
		}

		/**
		 * @description Moves the circuit on when its timeout has passed, and saves the state when it does. An OPEN circuit
		 * becomes HALF_OPEN once the timeout has passed since the last failure. A HALF_OPEN circuit that has used every
		 * trial request of its round, none of which closed or reopened the circuit, starts a new round of trial requests
		 * once the timeout has passed since the current round began, so a round that settled nothing never leaves the
		 * circuit refusing every request. Nothing changes while the circuit is CLOSED or while a HALF_OPEN circuit still
		 * has trial requests left. The first call after the circuit opens checks nothing, so a circuit with a zero timeout
		 * stays OPEN for that call.
		 */
		private void updateStateIfNeeded()
		{
			// Skip the next update check if flag is set (set after transition to prevent immediate re-transition)
			if(skipNextUpdate)
			{
				skipNextUpdate = false;
				return;
			}

			if(currentState.state == State.OPEN && currentState.lastFailureTime != null && hasTimeoutPassedSince(currentState.lastFailureTime))
			{
				transitionToHalfOpen();
				saveState();
			}
			else if(currentState.state == State.HALF_OPEN && hasUsedEveryTrialRequest() && hasTimeoutPassedSince(currentState.stateChangedTime))
			{
				startNewRoundOfTrials();
				saveState();
			}
		}

		/**
		 * @description Whether a HALF_OPEN circuit has let through every trial request its current round allows.
		 *
		 * @return True when no trial request is left in the current round.
		 */
		private Boolean hasUsedEveryTrialRequest()
		{
			return currentState.halfOpenAttempts >= configuration.halfOpenMaxAttempts;
		}

		/**
		 * @description Whether the configured timeout has passed since a moment. More whole seconds than the timeout must
		 * have gone by. Inside a test a timeout of zero is read in milliseconds, so a test can let the timeout pass by
		 * letting the clock move on. A missing start time reads as a timeout that has passed, so a state saved without one
		 * never blocks the circuit.
		 *
		 * @param startTime The moment the timeout is counted from, or null when the state holds none.
		 *
		 * @return True when the timeout has passed since the start time, or when there is no start time.
		 */
		private Boolean hasTimeoutPassedSince(Datetime startTime)
		{
			if(startTime == null)
			{
				return true;
			}

			Long millisecondsSinceStart = Datetime.now().getTime() - startTime.getTime();
			if(Test.isRunningTest() && configuration.timeoutSeconds == 0)
			{
				return millisecondsSinceStart > 0;
			}
			return millisecondsSinceStart / 1000 > configuration.timeoutSeconds;
		}

		/**
		 * @description Transitions circuit breaker to CLOSED state
		 */
		private void transitionToClosed()
		{
			currentState.state = State.CLOSED;
			currentState.failureCount = 0;
			currentState.consecutiveSuccesses = 0;
			currentState.halfOpenAttempts = 0;
			currentState.stateChangedTime = Datetime.now();

			LOG_Builder.build()
					.info(String.format('Circuit breaker {0} transitioned to CLOSED', new List<String> {circuitId}))
					.at(CLASS_NAME + '.transitionToClosed')
					.emit();
		}

		/**
		 * @description Transitions circuit breaker to OPEN state
		 */
		private void transitionToOpen()
		{
			currentState.state = State.OPEN;
			currentState.lastFailureTime = Datetime.now();
			currentState.consecutiveSuccesses = 0;
			currentState.halfOpenAttempts = 0;
			currentState.stateChangedTime = Datetime.now();

			// Set flag to skip next update check to prevent immediate re-transition
			skipNextUpdate = true;

			LOG_Builder.build()
					.warn(String.format('Circuit breaker {0} transitioned to OPEN after {1} failures', new List<String> {circuitId, String.valueOf(currentState.failureCount)}))
					.at(CLASS_NAME + '.transitionToOpen')
					.emit();
		}

		/**
		 * @description Transitions circuit breaker to HALF_OPEN state
		 */
		private void transitionToHalfOpen()
		{
			currentState.state = State.HALF_OPEN;
			currentState.halfOpenAttempts = 0;
			currentState.consecutiveSuccesses = 0;
			currentState.stateChangedTime = Datetime.now();

			LOG_Builder.build()
					.info(String.format('Circuit breaker {0} transitioned to HALF_OPEN for recovery testing', new List<String> {circuitId}))
					.at(CLASS_NAME + '.transitionToHalfOpen')
					.emit();
		}

		/**
		 * @description Starts a new round of trial requests while the circuit stays HALF_OPEN: the count of trial requests
		 * used goes back to zero and the round's start time becomes now. Successes already recorded still count towards
		 * closing the circuit, and the failure count and the time of the last failure are left as they are.
		 */
		private void startNewRoundOfTrials()
		{
			currentState.halfOpenAttempts = 0;
			currentState.stateChangedTime = Datetime.now();

			LOG_Builder.build()
					.info(String.format(MESSAGE_NEW_ROUND_OF_TRIALS, new List<String> {circuitId}))
					.at(CLASS_NAME + '.startNewRoundOfTrials')
					.emit();
		}

		/**
		 * @description Loads circuit state from Platform Cache or creates new state
		 *
		 * @return The loaded or new circuit state
		 */
		private CircuitState loadState()
		{
			CircuitState state;

			// Try to load from platform cache
			// Note: UTIL_Cache.simulateNullPartition flag can be set in tests
			// to simulate cache failures and achieve 100% test coverage
			UTIL_Cache.Store cache = UTIL_Cache.org()
					.withPartition(cachePartition);

			state = (CircuitState)cache?.get(circuitId);

			// Create new state if not found in cache
			if(state == null)
			{
				state = new CircuitState();

				state.consecutiveSuccesses = 0;
				state.failureCount = 0;
				state.halfOpenAttempts = 0;
				state.state = UTIL_CircuitBreaker.State.CLOSED;
				state.stateChangedTime = Datetime.now();
			}

			return state;
		}

		/**
		 * @description Saves current circuit state to Platform Cache
		 */
		private void saveState()
		{
			// Save to platform cache with TTL
			// Note: UTIL_Cache.simulateNullPartition flag can be set in tests
			// to simulate cache failures and achieve 100% test coverage
			UTIL_Cache.Store cache = UTIL_Cache.org()
					.withPartition(cachePartition);

			// We add a buffer to the TTL to ensure the state object survives slightly longer
			// than the circuit timeout. This ensures that when the timeout expires, the
			// circuit state is still present in cache so we can transition to HALF_OPEN.
			// Without this buffer, the cache entry would expire at the exact same moment
			// the circuit should recover, resulting in a "cache miss" and a hard reset
			// to CLOSED (skipping the HALF_OPEN verification step).
			Integer ttlWithBuffer = configuration.timeoutSeconds + TTL_BUFFER_SECONDS;

			cache?.put(circuitId, currentState, ttlWithBuffer);
		}
	}
}