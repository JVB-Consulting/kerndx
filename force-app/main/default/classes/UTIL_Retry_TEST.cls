// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_Retry
 *
 * @see UTIL_Retry
 *
 * @author Jason van Beukering
 *
 * @group Resilience
 *
 * @date December 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_Retry_TEST
{
	/**
	 * @description Tests exponential backoff strategy with default configuration
	 */
	@IsTest
	private static void shouldCreateExponentialStrategy()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();

		Test.stopTest();

		Assert.isNotNull(strategy, 'Strategy should not be null');

		// Test retry count progression
		UTIL_Retry.Context ctx0 = UTIL_Retry.newContext(0);
		Assert.isTrue(strategy.shouldRetry(ctx0), 'Should retry at count 0');

		UTIL_Retry.Context ctx1 = UTIL_Retry.newContext(1);
		Assert.isTrue(strategy.shouldRetry(ctx1), 'Should retry at count 1');

		UTIL_Retry.Context ctx2 = UTIL_Retry.newContext(2);
		Assert.isTrue(strategy.shouldRetry(ctx2), 'Should retry at count 2');

		UTIL_Retry.Context ctx3 = UTIL_Retry.newContext(3);
		Assert.isFalse(strategy.shouldRetry(ctx3), 'Should not retry at count 3 (max is 3)');
	}

	/**
	 * @description Tests linear backoff strategy with default configuration
	 */
	@IsTest
	private static void shouldCreateLinearStrategy()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.linear();

		Test.stopTest();

		Assert.isNotNull(strategy, 'Strategy should not be null');

		// Test linear backoff calculation
		UTIL_Retry.Context ctx0 = UTIL_Retry.newContext(0);
		Integer backoff0 = strategy.calculateBackoff(ctx0);
		Assert.areEqual(10, backoff0, 'First retry should use base backoff (10)');

		UTIL_Retry.Context ctx1 = UTIL_Retry.newContext(1);
		Integer backoff1 = strategy.calculateBackoff(ctx1);
		Assert.areEqual(10, backoff1, 'Second retry should be 10 * 1 = 10');

		UTIL_Retry.Context ctx2 = UTIL_Retry.newContext(2);
		Integer backoff2 = strategy.calculateBackoff(ctx2);
		Assert.areEqual(20, backoff2, 'Third retry should be 10 * 2 = 20');
	}

	/**
	 * @description Tests exponential backoff calculation
	 */
	@IsTest
	private static void shouldCalculateExponentialBackoff()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withMaxRetries(5)
				.withBaseBackoff(10);

		Test.stopTest();

		// Exponential: base * (2 ^ retryCount)
		UTIL_Retry.Context ctx0 = UTIL_Retry.newContext(0);
		Integer backoff0 = strategy.calculateBackoff(ctx0);
		Assert.areEqual(10, backoff0, 'Retry 0: 10 * (2^0) = 10');

		UTIL_Retry.Context ctx1 = UTIL_Retry.newContext(1);
		Integer backoff1 = strategy.calculateBackoff(ctx1);
		Assert.areEqual(20, backoff1, 'Retry 1: 10 * (2^1) = 20');

		UTIL_Retry.Context ctx2 = UTIL_Retry.newContext(2);
		Integer backoff2 = strategy.calculateBackoff(ctx2);
		Assert.areEqual(40, backoff2, 'Retry 2: 10 * (2^2) = 40');

		UTIL_Retry.Context ctx3 = UTIL_Retry.newContext(3);
		Integer backoff3 = strategy.calculateBackoff(ctx3);
		Assert.areEqual(80, backoff3, 'Retry 3: 10 * (2^3) = 80');
	}

	/**
	 * @description Tests custom retry configuration
	 */
	@IsTest
	private static void shouldSupportCustomConfiguration()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withMaxRetries(10)
				.withBaseBackoff(5);

		Test.stopTest();

		UTIL_Retry.Context ctx5 = UTIL_Retry.newContext(5);
		Assert.isTrue(strategy.shouldRetry(ctx5), 'Should retry at count 5 (max is 10)');

		UTIL_Retry.Context ctx10 = UTIL_Retry.newContext(10);
		Assert.isFalse(strategy.shouldRetry(ctx10), 'Should not retry at count 10 (max is 10)');

		Integer backoff = strategy.calculateBackoff(ctx5);
		Assert.areEqual(160, backoff, 'Retry 5: 5 * (2^5) = 160');
	}

	/**
	 * @description Tests jitter functionality
	 */
	@IsTest
	private static void shouldApplyJitterWhenEnabled()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withMaxRetries(5)
				.withBaseBackoff(100)
				.withJitter(true);

		Test.stopTest();

		UTIL_Retry.Context ctx1 = UTIL_Retry.newContext(1);

		// With jitter, backoff should be between base and base + 25%
		// Base for retry 1: 100 * (2^1) = 200
		// Jitter adds up to 25% = 50
		// So range is 200-250
		Integer backoff1 = strategy.calculateBackoff(ctx1);
		Assert.isTrue(backoff1 >= 200, 'Backoff with jitter should be at least base (200)');
		Assert.isTrue(backoff1 <= 250, 'Backoff with jitter should be at most base + 25% (250)');

		// Run multiple times to verify randomness
		Set<Integer> results = new Set<Integer>();
		for(Integer i = 0; i < 10; i++)
		{
			Integer backoff = strategy.calculateBackoff(ctx1);
			results.add(backoff);
		}

		// With jitter enabled, we should get some variation (not all the same)
		// Note: This could theoretically fail if random generates the same value 10 times,
		// but that's extremely unlikely
		Assert.isTrue(results.size() > 1, 'Jitter should produce varied backoff values');
	}

	/**
	 * @description Tests context with custom data
	 */
	@IsTest
	private static void shouldSupportContextWithCustomData()
	{
		Test.startTest();

		Map<String, Object> customData = new Map<String, Object>
		{
				'statusCode' => '429',
				'retryAfter' => 60
		};

		UTIL_Retry.Context context = UTIL_Retry.newContext(1)
				.withLastAttemptTime(Datetime.now())
				.withCustomData(customData);

		Test.stopTest();

		Assert.areEqual(1, context.getRetryCount(), 'Retry count should be 1');
		Assert.isNotNull(context.getLastAttemptTime(), 'Last attempt time should be set');
		Assert.isNotNull(context.getCustomData(), 'Custom data should be set');

		Map<String, Object> retrievedData = (Map<String, Object>)context.getCustomData();
		Assert.areEqual('429', retrievedData.get('statusCode'), 'Custom data should be retrievable');
	}

	/**
	 * @description Tests null context handling
	 */
	@IsTest
	private static void shouldHandleNullContext()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();

		Boolean shouldRetry = strategy.shouldRetry(null);
		Integer backoff = strategy.calculateBackoff(null);

		Test.stopTest();

		Assert.isFalse(shouldRetry, 'Should not retry with null context');
		Assert.areEqual(0, backoff, 'Backoff should be 0 with null context');
	}

	/**
	 * @description Tests negative retry count handling
	 */
	@IsTest
	private static void shouldHandleNegativeRetryCount()
	{
		Test.startTest();

		UTIL_Retry.Context context = UTIL_Retry.newContext(-1);

		Test.stopTest();

		Assert.areEqual(0, context.getRetryCount(), 'Negative retry count should be normalized to 0');
	}

	/**
	 * @description Tests null retry count handling
	 */
	@IsTest
	private static void shouldHandleNullRetryCount()
	{
		Test.startTest();

		UTIL_Retry.Context context = UTIL_Retry.newContext(null);

		Test.stopTest();

		Assert.areEqual(0, context.getRetryCount(), 'Null retry count should be normalized to 0');
	}

	/**
	 * @description Tests negative max retries handling
	 */
	@IsTest
	private static void shouldHandleNegativeMaxRetries()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withMaxRetries(-1);

		UTIL_Retry.Context context = UTIL_Retry.newContext(0);

		Test.stopTest();

		Assert.isFalse(strategy.shouldRetry(context), 'Should not retry with negative max retries');
	}

	/**
	 * @description Tests negative base backoff handling
	 */
	@IsTest
	private static void shouldHandleNegativeBaseBackoff()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withBaseBackoff(-10);

		UTIL_Retry.Context context = UTIL_Retry.newContext(1);
		Integer backoff = strategy.calculateBackoff(context);

		Test.stopTest();

		Assert.areEqual(0, backoff, 'Negative base backoff should be normalized to 0');
	}

	/**
	 * @description Tests context base and max backoff exposure
	 */
	@IsTest
	private static void shouldExposeBackoffConfigurationInContext()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withBaseBackoff(15)
				.withMaxRetries(5);

		UTIL_Retry.Context context = UTIL_Retry.newContext(1);

		// Calculate backoff to populate context with configuration
		strategy.calculateBackoff(context);

		Test.stopTest();

		Assert.areEqual(15, context.getBaseBackoff(), 'Context should expose base backoff');
		Assert.isNotNull(context.getMaxBackoff(), 'Context should expose max backoff');
	}

	/**
	 * @description Tests overflow protection in exponential backoff
	 */
	@IsTest
	private static void shouldPreventOverflowInExponentialBackoff()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withMaxRetries(100)
				.withBaseBackoff(10);

		// Test with very high retry count that would cause overflow
		UTIL_Retry.Context ctx31 = UTIL_Retry.newContext(31);
		Integer backoff31 = strategy.calculateBackoff(ctx31);

		UTIL_Retry.Context ctx100 = UTIL_Retry.newContext(100);
		Integer backoff100 = strategy.calculateBackoff(ctx100);

		Test.stopTest();

		// Should cap at max backoff (300 default)
		Assert.areEqual(300, backoff31, 'Should cap at max backoff for high retry count');
		Assert.areEqual(300, backoff100, 'Should cap at max backoff for very high retry count');
	}

	/**
	 * @description Tests linear backoff with zero retry count
	 */
	@IsTest
	private static void shouldHandleZeroRetryCountInLinear()
	{
		Test.startTest();

		UTIL_Retry.Strategy strategy = UTIL_Retry.linear()
				.withBaseBackoff(20);

		UTIL_Retry.Context ctx0 = UTIL_Retry.newContext(0);
		Integer backoff = strategy.calculateBackoff(ctx0);

		Test.stopTest();

		Assert.areEqual(20, backoff, 'Zero retry count should return base backoff');
	}

	/**
	 * @description Tests exponential backoff with maximum backoff cap
	 */
	@IsTest
	private static void shouldRespectMaximumBackoffCap()
	{
		Test.startTest();

		// Create strategy with low max backoff to test capping
		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withMaxRetries(10)
				.withBaseBackoff(50);

		// High retry count would normally produce very large backoff
		// 50 * (2^5) = 1600, but default max is 300
		UTIL_Retry.Context ctx5 = UTIL_Retry.newContext(5);
		Integer backoff = strategy.calculateBackoff(ctx5);

		Test.stopTest();

		// Should be capped at default maximum (300)
		Assert.areEqual(300, backoff, 'Backoff should be capped at maximum (300)');
	}

	/**
	 * @description Tests exponential multiplier effect
	 */
	@IsTest
	private static void shouldApplyExponentialMultiplier()
	{
		Test.startTest();

		// Test with default multiplier (2.0)
		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withBaseBackoff(10);

		UTIL_Retry.Context ctx2 = UTIL_Retry.newContext(2);
		Integer backoff = strategy.calculateBackoff(ctx2);

		Test.stopTest();

		// 10 * (2^2) = 40
		Assert.areEqual(40, backoff, 'Default exponential multiplier should produce 10 * (2^2) = 40');
	}

	/**
	 * @description Tests custom exponential multiplier configuration
	 */
	@IsTest
	private static void shouldSupportCustomExponentialMultiplier()
	{
		Test.startTest();

		// Test with custom multiplier (3.0)
		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withBaseBackoff(10)
				.withExponentialMultiplier(3.0);

		UTIL_Retry.Context ctx2 = UTIL_Retry.newContext(2);
		Integer backoff = strategy.calculateBackoff(ctx2);

		Test.stopTest();

		// 10 * (3^2) = 90
		Assert.areEqual(90, backoff, 'Custom exponential multiplier should produce 10 * (3^2) = 90');
	}

	/**
	 * @description Tests custom maximum backoff configuration
	 */
	@IsTest
	private static void shouldSupportCustomMaximumBackoff()
	{
		Test.startTest();

		// Test with custom max backoff (100 seconds instead of 300)
		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
				.withBaseBackoff(50)
				.withMaximumBackoff(100);

		// High retry count would produce large backoff without cap
		// 50 * (2^5) = 1600, but should be capped at 100
		UTIL_Retry.Context ctx5 = UTIL_Retry.newContext(5);
		Integer backoff = strategy.calculateBackoff(ctx5);

		Test.stopTest();

		Assert.areEqual(100, backoff, 'Should respect custom maximum backoff of 100');
	}

	/**
	 * @description Tests null handling in new fluent methods
	 */
	@IsTest
	private static void shouldHandleNullInNewFluentMethods()
	{
		Test.startTest();

		// Test null exponential multiplier (should default to 1.0)
		UTIL_Retry.Strategy strategy1 = UTIL_Retry.exponential()
				.withExponentialMultiplier(null);

		UTIL_Retry.Context ctx1 = UTIL_Retry.newContext(2);
		Integer backoff1 = strategy1.calculateBackoff(ctx1);

		// Test null maximum backoff (should default to 0)
		UTIL_Retry.Strategy strategy2 = UTIL_Retry.linear()
				.withMaximumBackoff(null);

		UTIL_Retry.Context ctx2 = UTIL_Retry.newContext(1);
		Integer backoff2 = strategy2.calculateBackoff(ctx2);

		Test.stopTest();

		// With multiplier = 1.0: 10 * (1^2) = 10
		Assert.areEqual(10, backoff1, 'Null multiplier should default to 1.0');

		// With max backoff = 0, should cap at 0
		Assert.areEqual(0, backoff2, 'Null max backoff should default to 0');
	}

	/**
	 * @description Verifies `dontRetryOnException` suppresses retry when the caught exception
	 * matches a denylisted type. Subscribers wrap a base strategy with the denylist and pass
	 * the caught exception via `Context.withCustomData(...)`; the wrapped Strategy returns
	 * false for shouldRetry() in that case.
	 */
	@IsTest
	private static void shouldSuppressRetryWhenExceptionInDenyList()
	{
		UTIL_Retry.Strategy strategy = UTIL_Retry.dontRetryOnException(
				UTIL_Retry.exponential().withMaxRetries(5),
				new Set<Type> {System.IllegalArgumentException.class}
		);

		UTIL_Retry.Context contextWithBlocked = UTIL_Retry.newContext(0).withCustomData(new IllegalArgumentException('bad input'));
		Assert.isFalse(strategy.shouldRetry(contextWithBlocked),
				'Denylisted IllegalArgumentException must suppress retry');

		UTIL_Retry.Context contextWithUnrelated = UTIL_Retry.newContext(0).withCustomData(new System.QueryException('soql failure'));
		Assert.isTrue(strategy.shouldRetry(contextWithUnrelated),
				'Non-denylisted QueryException must fall through to base strategy and retry');

		UTIL_Retry.Context contextWithNoException = UTIL_Retry.newContext(0);
		Assert.isTrue(strategy.shouldRetry(contextWithNoException),
				'Context without an exception in customData must fall through to base strategy and retry');
	}

	/**
	 * @description Verifies `retryOnlyOnException` suppresses retry unless the caught exception
	 * matches an allowlisted type. Calls without a caught exception fall through to the base
	 * strategy (the allowlist only applies when an exception is present).
	 */
	@IsTest
	private static void shouldRestrictRetryWhenExceptionNotInAllowList()
	{
		UTIL_Retry.Strategy strategy = UTIL_Retry.retryOnlyOnException(
				UTIL_Retry.exponential().withMaxRetries(5),
				new Set<Type> {System.CalloutException.class}
		);

		UTIL_Retry.Context contextWithAllowed = UTIL_Retry.newContext(0).withCustomData(new System.CalloutException('endpoint down'));
		Assert.isTrue(strategy.shouldRetry(contextWithAllowed),
				'Allowlisted CalloutException must permit retry');

		UTIL_Retry.Context contextWithDisallowed = UTIL_Retry.newContext(0).withCustomData(new IllegalArgumentException('bad input'));
		Assert.isFalse(strategy.shouldRetry(contextWithDisallowed),
				'Non-allowlisted IllegalArgumentException must suppress retry');

		UTIL_Retry.Context contextWithNoException = UTIL_Retry.newContext(0);
		Assert.isTrue(strategy.shouldRetry(contextWithNoException),
				'Context without an exception in customData must fall through to base strategy');
	}

	/**
	 * @description Verifies the denylist correctly matches inner-class exception types from
	 * the kern namespace (e.g. `UTIL_Exceptions.IllegalStateException`) — this is the
	 * non-System-namespace path subscribers will most often hit when filtering against
	 * framework exceptions.
	 */
	@IsTest
	private static void shouldMatchInnerClassExceptionInDenyList()
	{
		UTIL_Retry.Strategy strategy = UTIL_Retry.dontRetryOnException(
				UTIL_Retry.exponential().withMaxRetries(5),
				new Set<Type> {UTIL_Exceptions.IllegalStateException.class}
		);

		UTIL_Retry.Context contextWithBlocked = UTIL_Retry.newContext(0)
				.withCustomData(new UTIL_Exceptions.IllegalStateException('framework state error'));

		Assert.isFalse(strategy.shouldRetry(contextWithBlocked),
				'Inner-class kern.UTIL_Exceptions.IllegalStateException must match the denylist by exact type name');
	}

	/**
	 * @description Verifies passing `null` or an empty Set as the filter delegates fully to
	 * the base strategy — the filter behaves as if it weren't there. Locks in the
	 * "empty/null filter = no-op" contract.
	 */
	@IsTest
	private static void shouldDelegateFullyWhenFilterIsNullOrEmpty()
	{
		UTIL_Retry.Strategy denyNull = UTIL_Retry.dontRetryOnException(
				UTIL_Retry.exponential().withMaxRetries(2),
				null
		);
		UTIL_Retry.Strategy allowEmpty = UTIL_Retry.retryOnlyOnException(
				UTIL_Retry.exponential().withMaxRetries(2),
				new Set<Type> {}
		);

		UTIL_Retry.Context contextWithException = UTIL_Retry.newContext(0)
				.withCustomData(new IllegalArgumentException('any exception'));

		Assert.isTrue(denyNull.shouldRetry(contextWithException),
				'null denylist must delegate fully to base (which returns true at retry count 0)');
		Assert.isTrue(allowEmpty.shouldRetry(contextWithException),
				'empty allowlist must delegate fully to base (allowlist filter is skipped when empty)');
	}

	/**
	 * @description Verifies the FilteredStrategy delegates fluent setters (withMaxRetries,
	 * withBaseBackoff, withJitter, withMaximumBackoff, withExponentialMultiplier) and
	 * calculateBackoff to the underlying base strategy, so the wrapper composes transparently
	 * in chained configuration.
	 */
	@IsTest
	private static void shouldDelegateFluentSettersAndBackoffCalculationToBase()
	{
		UTIL_Retry.Strategy filtered = UTIL_Retry.dontRetryOnException(
				UTIL_Retry.linear(),
				new Set<Type> {System.IllegalArgumentException.class}
		);

		filtered.withMaxRetries(7)
				.withBaseBackoff(20)
				.withJitter(false)
				.withMaximumBackoff(120)
				.withExponentialMultiplier(2.0);

		UTIL_Retry.Context contextAtMax = UTIL_Retry.newContext(7);
		Assert.isFalse(filtered.shouldRetry(contextAtMax),
				'After delegating withMaxRetries(7), shouldRetry must respect the cap');

		UTIL_Retry.Context contextNotAtMax = UTIL_Retry.newContext(0);
		Assert.areEqual(20, filtered.calculateBackoff(contextNotAtMax),
				'Linear backoff with delegated baseBackoff(20) at retry 0 should equal 20');
	}
}