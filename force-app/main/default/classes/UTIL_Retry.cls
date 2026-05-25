// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Factory for retry strategies with nested interface definitions.
 * Provides a clean API for creating and configuring retry strategies with exponential or linear backoff.
 * This factory pattern reduces namespace pollution by nesting the interface inside the factory class.
 *
 * Features:
 * - Nested interfaces for clean type organization
 * - Fluent configuration API
 * - Standard implementations (exponential, linear)
 * - Custom strategy support via interface
 * - Jitter support to prevent thundering herd
 *
 * @see UTIL_Retry_TEST
 *
 * @author Jason van Beukering
 *
 * @group Resilience
 *
 * @date December 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * Example 1: Simple exponential backoff
 * ```apex
 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
 * UTIL_Retry.Context context = UTIL_Retry.newContext(1);
 * if(strategy.shouldRetry(context))
 * {
 *     Integer backoffSeconds = strategy.calculateBackoff(context);
 *     Datetime nextRetry = Datetime.now().addSeconds(backoffSeconds);
 * }
 * ```
 * Example 2: Custom configuration
 * ```apex
 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
 *     .withMaxRetries(5)
 *     .withBaseBackoff(10)
 *     .withJitter(true);
 * ```
 * Example 3: Custom strategy implementation
 * ```apex
 * public class RateLimitStrategy implements UTIL_Retry.Strategy
 * {
 *     public Boolean shouldRetry(UTIL_Retry.Context ctx)
 *     {
 *         return context.getRetryCount() < 3;
 *     }
 *     public Integer calculateBackoff(UTIL_Retry.Context ctx)
 *     {
 *         // Custom logic based on rate limit headers
 *         return 60; // Wait 1 minute for rate limit
 *     }
 *     // Implement fluent setters...
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidBooleanMethodParameters,PMD.CognitiveComplexity')
global inherited sharing class UTIL_Retry
{

	/**
	 * @description Default base backoff period in seconds
	 */
	private static final Integer DEFAULT_BASE_BACKOFF_SECONDS = 10;

	/**
	 * @description Default maximum backoff period in seconds (5 minutes)
	 */
	private static final Integer DEFAULT_MAX_BACKOFF_SECONDS = 300;

	/**
	 * @description Default maximum number of retry attempts
	 */
	private static final Integer DEFAULT_MAX_RETRIES = 3;

	/**
	 * @description Default exponential multiplier
	 */
	private static final Decimal DEFAULT_EXPONENTIAL_MULTIPLIER = 2.0;

	/**
	 * @description Interface defining the retry context.
	 * Contains information about the current retry attempt including count, timing, and custom data.
	 *
	 * @since 1.0
	 */
	global interface Context
	{
		/**
		 * @description Gets the current retry attempt number (0 = first attempt, 1 = first retry, etc.)
		 *
		 * @return The retry count
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(2);
		 * Integer count = context.getRetryCount(); // Returns 2
		 * ```
		 */
		Integer getRetryCount();

		/**
		 * @description Gets the datetime of the last retry attempt
		 *
		 * @return The last attempt time, or null if not set
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
		 *     .withLastAttemptTime(Datetime.now());
		 * Datetime lastAttempt = ctx.getLastAttemptTime();
		 * ```
		 */
		Datetime getLastAttemptTime();

		/**
		 * @description Gets custom data for use with custom retry strategies
		 *
		 * @return The custom data object, or null if not set
		 *
		 * @example
		 * ```apex
		 * Map<String, Object> data = new Map<String, Object>{'error' => '429'};
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
		 *     .withCustomData(data);
		 * Object customData = ctx.getCustomData();
		 * ```
		 */
		Object getCustomData();

		/**
		 * @description Sets the last attempt time (fluent API)
		 *
		 * @param dt The datetime of the last attempt
		 *
		 * @return This context for method chaining
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
		 *     .withLastAttemptTime(Datetime.now());
		 * ```
		 */
		Context withLastAttemptTime(Datetime dt);

		/**
		 * @description Sets custom data for use with custom retry strategies (fluent API)
		 *
		 * @param data The custom data (SObject, Map, List, custom class, etc.)
		 *
		 * @return This context for method chaining
		 *
		 * @example
		 * ```apex
		 * ApiCall__c apiCall = [SELECT Id, StatusCode__c FROM ApiCall__c LIMIT 1];
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
		 *     .withCustomData(apiCall);
		 * ```
		 */
		Context withCustomData(Object data);

		/**
		 * @description Gets the configured base backoff in seconds
		 *
		 * @return The base backoff period
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(1);
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.linear();
		 * strategy.calculateBackoff(ctx);
		 * Integer baseBackoff = ctx.getBaseBackoff(); // Returns 10 (default)
		 * ```
		 */
		Integer getBaseBackoff();

		/**
		 * @description Gets the configured maximum backoff in seconds
		 *
		 * @return The maximum backoff period
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(1);
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
		 * strategy.calculateBackoff(ctx);
		 * Integer maxBackoff = ctx.getMaxBackoff(); // Returns 300 (default)
		 * ```
		 */
		Integer getMaxBackoff();
	}

	/**
	 * @description Interface defining the retry strategy logic.
	 * Implement this interface to create custom retry strategies.
	 *
	 * @since 1.0
	 */
	global interface Strategy
	{
		/**
		 * @description Determines if a retry should be attempted
		 *
		 * @param context The retry context containing retry count and configuration
		 *
		 * @return True if a retry should be attempted, false otherwise
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(2);
		 * if(strategy.shouldRetry(ctx))
		 * {
		 *     // Perform retry logic
		 * }
		 * ```
		 */
		Boolean shouldRetry(Context context);

		/**
		 * @description Calculates the backoff period in seconds for the next retry
		 *
		 * @param context The retry context containing retry count and configuration
		 *
		 * @return The backoff period in seconds
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
		 * UTIL_Retry.Context ctx = UTIL_Retry.newContext(1);
		 * Integer backoffSeconds = strategy.calculateBackoff(ctx);
		 * Datetime nextRetry = Datetime.now().addSeconds(backoffSeconds);
		 * ```
		 */
		Integer calculateBackoff(Context context);

		/**
		 * @description Sets the maximum retry attempts (fluent API)
		 *
		 * @param max The maximum retry attempts
		 *
		 * @return This strategy for method chaining
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
		 *     .withMaxRetries(5);
		 * ```
		 */
		Strategy withMaxRetries(Integer max);

		/**
		 * @description Sets the base backoff period in seconds (fluent API)
		 *
		 * @param seconds The base backoff period
		 *
		 * @return This strategy for method chaining
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.linear()
		 *     .withBaseBackoff(15);
		 * ```
		 */
		Strategy withBaseBackoff(Integer seconds);

		/**
		 * @description Enables or disables random jitter (fluent API)
		 *
		 * @param enabled Whether to enable jitter (adds up to 25% randomness)
		 *
		 * @return This strategy for method chaining
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
		 *     .withJitter(true);
		 * ```
		 */
		Strategy withJitter(Boolean enabled);

		/**
		 * @description Sets the maximum backoff cap in seconds (fluent API)
		 *
		 * @param seconds Maximum backoff cap in seconds
		 *
		 * @return This strategy for method chaining
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
		 *     .withMaximumBackoff(600); // Cap at 10 minutes
		 * ```
		 */
		Strategy withMaximumBackoff(Integer seconds);

		/**
		 * @description Sets the exponential multiplier for exponential backoff (fluent API)
		 *
		 * @param multiplier The exponential multiplier (must be >= 1.0, default: 2.0)
		 *
		 * @return This strategy for method chaining
		 *
		 * @example
		 * ```apex
		 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
		 *     .withExponentialMultiplier(3.0); // Faster backoff growth
		 * ```
		 */
		Strategy withExponentialMultiplier(Decimal multiplier);
	}

	/**
	 * @description Returns a standard exponential backoff strategy.
	 * Defaults: max retries = 3, base backoff = 10s, jitter = false
	 *
	 * @return Configured exponential backoff strategy
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
	 *     .withMaxRetries(5)
	 *     .withJitter(true);
	 * ```
	 */
	global static Strategy exponential()
	{
		DefaultStrategy strategy = new DefaultStrategy();
		strategy.withMaxRetries(DEFAULT_MAX_RETRIES);
		strategy.withBaseBackoff(DEFAULT_BASE_BACKOFF_SECONDS);
		strategy.setExponentialMode(true);
		return strategy;
	}

	/**
	 * @description Returns a standard linear backoff strategy.
	 * Defaults: max retries = 3, base backoff = 10s
	 *
	 * @return Configured linear backoff strategy
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Retry.Strategy strategy = UTIL_Retry.linear()
	 *     .withMaxRetries(5)
	 *     .withBaseBackoff(15);
	 * ```
	 */
	global static Strategy linear()
	{
		DefaultStrategy strategy = new DefaultStrategy();
		strategy.withMaxRetries(DEFAULT_MAX_RETRIES);
		strategy.withBaseBackoff(DEFAULT_BASE_BACKOFF_SECONDS);
		strategy.setExponentialMode(false);
		return strategy;
	}

	/**
	 * @description Creates a new retry context with the specified retry count.
	 *
	 * @param retryCount The current retry attempt number (0 = first attempt, 1 = first retry, etc.)
	 *
	 * @return New context instance
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Retry.Context context = UTIL_Retry.newContext(1)
	 *     .withLastAttemptTime(Datetime.now())
	 *     .withCustomData(apiCall);
	 * ```
	 */
	global static Context newContext(Integer retryCount)
	{
		return new DefaultContext(retryCount);
	}

	/**
	 * @description Wraps an existing strategy with an exception-type denylist. The wrapped
	 * strategy delegates `calculateBackoff` and the fluent setters (`withMaxRetries`, etc.)
	 * to the base strategy, but `shouldRetry` returns `false` whenever the caught exception
	 * (passed via `Context.withCustomData(Exception)`) matches any type in the denylist by
	 * **exact type name** (e.g. `System.IllegalArgumentException`). Subclass relationships
	 * are NOT considered — denylisting `Exception.class` does not catch concrete subclasses;
	 * list each concrete type explicitly. Use for "never retry on these errors" cases — e.g.
	 * authentication failures that won't recover via retry.
	 *
	 * Wrapping (rather than adding setters to the `Strategy` interface) keeps the contract
	 * for subscriber Strategy implementations unchanged.
	 *
	 * @param base The base retry strategy to wrap.
	 * @param exceptionTypes Set of exception types that should NEVER be retried.
	 *
	 * @return A wrapped Strategy that suppresses retries when the caught exception matches
	 *         any type in the denylist.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Retry.Strategy strategy = UTIL_Retry.dontRetryOnException(
	 *         UTIL_Retry.exponential().withMaxRetries(5),
	 *         new Set<Type>{System.IllegalArgumentException.class}
	 * );
	 * UTIL_Retry.Context context = UTIL_Retry.newContext(0).withCustomData(caughtException);
	 * Boolean shouldRetry = strategy.shouldRetry(context);
	 * ```
	 */
	global static Strategy dontRetryOnException(Strategy base, Set<Type> exceptionTypes)
	{
		return new FilteredStrategy(base, exceptionTypes, null);
	}

	/**
	 * @description Wraps an existing strategy with an exception-type allowlist. The wrapped
	 * strategy delegates everything to the base, but `shouldRetry` returns `false` UNLESS
	 * the caught exception (passed via `Context.withCustomData(Exception)`) matches one of
	 * the allowed types by **exact type name**. Subclass relationships are NOT considered.
	 * Use for "only retry on these errors" cases — e.g. a narrow set of transient errors a
	 * remote service might throw.
	 *
	 * Calls without a caught Exception in `Context.getCustomData()` always retry per the
	 * base strategy (the allowlist only applies when an exception is present).
	 *
	 * @param base The base retry strategy to wrap.
	 * @param exceptionTypes Set of exception types that ARE allowed to be retried. Empty or
	 *                       null disables the filter (delegates fully to base).
	 *
	 * @return A wrapped Strategy that only retries when the caught exception matches an
	 *         allowed type.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Retry.Strategy strategy = UTIL_Retry.retryOnlyOnException(
	 *         UTIL_Retry.exponential().withMaxRetries(5),
	 *         new Set<Type>{System.CalloutException.class}
	 * );
	 * ```
	 */
	global static Strategy retryOnlyOnException(Strategy base, Set<Type> exceptionTypes)
	{
		return new FilteredStrategy(base, null, exceptionTypes);
	}

	/**
	 * @description Internal Strategy decorator that applies an exception-type allowlist or
	 * denylist on top of a base strategy. Constructed via `dontRetryOnException` or
	 * `retryOnlyOnException`; not directly instantiable by subscribers (private). Delegates
	 * every Strategy method to the wrapped base except `shouldRetry`, which inspects the
	 * caught exception (read from `Context.getCustomData()`) before consulting the base.
	 */
	@SuppressWarnings('PMD.CognitiveComplexity')
	private inherited sharing class FilteredStrategy implements Strategy
	{
		/**
		 * @description The wrapped base strategy.
		 */
		private final Strategy delegate;

		/**
		 * @description Exception types that suppress retry when present.
		 */
		private final Set<Type> denyList;

		/**
		 * @description Exception types that are exclusively allowed to retry.
		 */
		private final Set<Type> allowList;

		/**
		 * @description Builds a filtered strategy.
		 *
		 * @param delegate The base Strategy to delegate to.
		 * @param denyList Exception types that suppress retry, or null for no denylist.
		 * @param allowList Exception types exclusively allowed to retry, or null for no allowlist.
		 */
		private FilteredStrategy(Strategy delegate, Set<Type> denyList, Set<Type> allowList)
		{
			this.delegate = delegate;
			this.denyList = denyList;
			this.allowList = allowList;
		}

		public Boolean shouldRetry(Context context)
		{
			Object customData = context?.getCustomData();
			if(customData instanceof Exception)
			{
				Exception caught = (Exception)customData;
				if(denyList != null && exceptionMatchesType(caught, denyList))
				{
					return false;
				}
				if(allowList != null && !allowList.isEmpty() && !exceptionMatchesType(caught, allowList))
				{
					return false;
				}
			}
			return delegate.shouldRetry(context);
		}

		public Integer calculateBackoff(Context context)
		{
			return delegate.calculateBackoff(context);
		}

		public Strategy withMaxRetries(Integer max)
		{
			delegate.withMaxRetries(max);
			return this;
		}

		public Strategy withBaseBackoff(Integer seconds)
		{
			delegate.withBaseBackoff(seconds);
			return this;
		}

		public Strategy withJitter(Boolean enabled)
		{
			delegate.withJitter(enabled);
			return this;
		}

		public Strategy withMaximumBackoff(Integer seconds)
		{
			delegate.withMaximumBackoff(seconds);
			return this;
		}

		public Strategy withExponentialMultiplier(Decimal multiplier)
		{
			delegate.withExponentialMultiplier(multiplier);
			return this;
		}

		/**
		 * @description Returns true when the caught exception is an instance of any type in
		 * the supplied set. Compares by canonical type name (Apex doesn't expose `instanceof`
		 * via runtime `Type` tokens, so name-based matching is the supported pattern).
		 *
		 * @param caught The exception to classify.
		 * @param types The set of types to test against.
		 *
		 * @return True when the exception's type name matches any entry in the set.
		 */
		private Boolean exceptionMatchesType(Exception caught, Set<Type> types)
		{
			String caughtName = caught.getTypeName();
			for(Type candidate : types)
			{
				if(candidate?.getName() == caughtName)
				{
					return true;
				}
			}
			return false;
		}
	}

	/**
	 * @description Internal implementation of the Context interface.
	 * Tracks retry count, timing, and custom data for retry decisions.
	 */
	private class DefaultContext implements Context
	{
		/**
		 * @description Datetime of the last retry attempt
		 */
		private Datetime lastAttempt;

		/**
		 * @description Base backoff period in seconds configured in the strategy
		 */
		private Integer baseBackoff;

		/**
		 * @description Maximum backoff period in seconds configured in the strategy
		 */
		private Integer maxBackoff;

		/**
		 * @description Current retry attempt number (0 = first attempt, 1 = first retry, etc.)
		 */
		private final Integer retryCount;

		/**
		 * @description Custom data for use with custom retry strategies
		 */
		private Object data;

		/**
		 * @description Constructor that initializes retry count
		 *
		 * @param count The current retry count
		 */
		private DefaultContext(Integer count)
		{
			this.retryCount = (count == null || count < 0) ? 0 : count;
		}

		/**
		 * @description Gets the current retry attempt number
		 *
		 * @return The retry count
		 */
		public Integer getRetryCount()
		{
			return retryCount;
		}

		/**
		 * @description Gets the datetime of the last retry attempt
		 *
		 * @return The last attempt time, or null if not set
		 */
		public Datetime getLastAttemptTime()
		{
			return lastAttempt;
		}

		/**
		 * @description Gets custom data for use with custom retry strategies
		 *
		 * @return The custom data object, or null if not set
		 */
		public Object getCustomData()
		{
			return data;
		}

		/**
		 * @description Sets the last attempt time (fluent API)
		 *
		 * @param attemptTime The datetime of the last attempt
		 *
		 * @return This context for method chaining
		 */
		public Context withLastAttemptTime(Datetime attemptTime)
		{
			this.lastAttempt = attemptTime;
			return this;
		}

		/**
		 * @description Sets custom data for use with custom retry strategies (fluent API)
		 *
		 * @param customData The custom data (SObject, Map, List, custom class, etc.)
		 *
		 * @return This context for method chaining
		 */
		public Context withCustomData(Object customData)
		{
			this.data = customData;
			return this;
		}

		/**
		 * @description Gets the configured base backoff in seconds
		 *
		 * @return The base backoff period
		 */
		public Integer getBaseBackoff()
		{
			return baseBackoff;
		}

		/**
		 * @description Gets the configured maximum backoff in seconds
		 *
		 * @return The maximum backoff period
		 */
		public Integer getMaxBackoff()
		{
			return maxBackoff;
		}

		/**
		 * @description Internal method to set base backoff from strategy
		 *
		 * @param seconds The base backoff period
		 */
		private void setBaseBackoff(Integer seconds)
		{
			this.baseBackoff = seconds;
		}

		/**
		 * @description Internal method to set max backoff from strategy
		 *
		 * @param seconds The maximum backoff period
		 */
		private void setMaxBackoff(Integer seconds)
		{
			this.maxBackoff = seconds;
		}
	}

	/**
	 * @description Internal implementation of the Strategy interface.
	 * Supports both exponential and linear backoff with optional jitter.
	 */
	private class DefaultStrategy implements Strategy
	{
		/**
		 * @description Whether to use exponential backoff (true) or linear (false)
		 */
		private Boolean isExponential = false;

		/**
		 * @description Whether to add random jitter to backoff calculations
		 */
		private Boolean useJitter = false;

		/**
		 * @description Multiplier for exponential backoff calculations (default 2.0)
		 */
		private Decimal exponentialMultiplier = DEFAULT_EXPONENTIAL_MULTIPLIER;

		/**
		 * @description Base backoff period in seconds
		 */
		private Integer baseBackoff = DEFAULT_BASE_BACKOFF_SECONDS;

		/**
		 * @description Maximum backoff period in seconds (cap)
		 */
		private Integer maxBackoff = DEFAULT_MAX_BACKOFF_SECONDS;

		/**
		 * @description Maximum number of retry attempts allowed
		 */
		private Integer maxRetries = DEFAULT_MAX_RETRIES;

		/**
		 * @description Determines if a retry should be attempted
		 *
		 * @param context The retry context containing retry count and configuration
		 *
		 * @return True if a retry should be attempted, false otherwise
		 */
		public Boolean shouldRetry(Context context)
		{
			return context != null && context.getRetryCount() < this.maxRetries;
		}

		/**
		 * @description Calculates the backoff period in seconds for the next retry
		 *
		 * @param context The retry context containing retry count and configuration
		 *
		 * @return The backoff period in seconds
		 */
		public Integer calculateBackoff(Context context)
		{
			if(context == null)
			{
				return 0;
			}

			// Populate context with configuration
			if(context instanceof DefaultContext)
			{
				DefaultContext contextImplementation = (DefaultContext)context;
				contextImplementation.setBaseBackoff(this.baseBackoff);
				contextImplementation.setMaxBackoff(this.maxBackoff);
			}

			Integer count = context.getRetryCount();
			Decimal result;

			if(isExponential)
			{
				// Exponential: baseBackoff * (multiplier ^ retryCount)
				// Safety check to prevent overflow
				if(count >= 31)
				{
					result = maxBackoff;
				}
				else
				{
					Double exponentialValue = Math.pow(exponentialMultiplier.doubleValue(), count);
					result = baseBackoff * exponentialValue;
					result = Math.min(result, maxBackoff);
				}
			}
			else
			{
				// Linear: baseBackoff * retryCount
				result = count <= 0 ? baseBackoff : baseBackoff * count;
				result = Math.min(result, maxBackoff);
			}

			// Add proportional jitter if enabled
			if(useJitter && result > 0)
			{
				Integer currentBackoffInt = result.intValue();
				Integer maxJitter = (Integer)(currentBackoffInt * 0.25);
				Integer jitter = UTIL_Random.nextInteger(0, maxJitter);
				result = result + jitter;
			}

			// Ensure we don't exceed maximum backoff after jitter
			result = Math.min(result, maxBackoff);

			return result.intValue();
		}

		/**
		 * @description Sets the maximum retry attempts (fluent API)
		 *
		 * @param maximumRetries The maximum retry attempts
		 *
		 * @return This strategy for method chaining
		 */
		public Strategy withMaxRetries(Integer maximumRetries)
		{
			this.maxRetries = (maximumRetries == null || maximumRetries < 0) ? 0 : maximumRetries;
			return this;
		}

		/**
		 * @description Sets the base backoff period in seconds (fluent API)
		 *
		 * @param seconds The base backoff period
		 *
		 * @return This strategy for method chaining
		 */
		public Strategy withBaseBackoff(Integer seconds)
		{
			this.baseBackoff = (seconds == null || seconds < 0) ? 0 : seconds;
			return this;
		}

		/**
		 * @description Enables or disables random jitter (fluent API)
		 *
		 * @param enabled Whether to enable jitter (adds up to 25% randomness)
		 *
		 * @return This strategy for method chaining
		 */
		public Strategy withJitter(Boolean enabled)
		{
			this.useJitter = enabled;
			return this;
		}

		/**
		 * @description Sets the maximum backoff cap in seconds (fluent API)
		 *
		 * @param seconds Maximum backoff cap in seconds
		 *
		 * @return This strategy for method chaining
		 */
		public Strategy withMaximumBackoff(Integer seconds)
		{
			this.maxBackoff = (seconds == null || seconds < 0) ? 0 : seconds;
			return this;
		}

		/**
		 * @description Sets the exponential multiplier for exponential backoff (fluent API)
		 *
		 * @param multiplier The exponential multiplier (must be >= 1.0, default: 2.0)
		 *
		 * @return This strategy for method chaining
		 */
		public Strategy withExponentialMultiplier(Decimal multiplier)
		{
			this.exponentialMultiplier = (multiplier == null || multiplier < 1.0) ? 1.0 : multiplier;
			return this;
		}

		/**
		 * @description Internal method to set exponential mode
		 *
		 * @param isExponentialBackoff Whether to use exponential backoff
		 *
		 * @return This strategy for method chaining
		 */
		private DefaultStrategy setExponentialMode(Boolean isExponentialBackoff)
		{
			this.isExponential = isExponentialBackoff;
			return this;
		}

	}
}