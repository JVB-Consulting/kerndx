// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Drift-guard demo class for UTIL_Cache transaction-scope additions.
 * Demonstrates the two subscriber-facing factories:
 *
 *   - `kern.UTIL_Cache.inTransaction()` — per-request in-memory memoization. Lifetime is the
 *     current Apex transaction. Use for expensive describes, lazy singletons, or per-request
 *     deduplication.
 *   - `kern.UTIL_Cache.autoWithTransactionFallback()` — Session → Org → IN_TRANSACTION graceful
 *     degradation. Reports `cacheTypeUsed = Scope.IN_TRANSACTION` on the fallback path so callers
 *     can detect a degraded scope. Use when Platform Cache may not be allocated and durability
 *     is not strictly required.
 *
 * For durability-required workloads (security keys, distributed counters) subscribers stay on
 * `kern.UTIL_Cache.auto()` so the loud `CACHE_UNAVAILABLE` failure signal stays loud.
 *
 * @see FastStart_Cache_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_Cache_DEMO
{
	/** @description Stable cache key for the per-transaction describe memoization demo. */
	@TestVisible
	private static final String MEMOIZED_DESCRIBE_KEY = 'fastStartCacheDemoAccountDescribe';

	/** @description Stable cache key for the graceful-fallback demo. */
	@TestVisible
	private static final String FALLBACK_KEY = 'fastStartCacheDemoFallback';

	/**
	 * @description Memoizes the Account SObjectType describe result for the current request.
	 * The first call computes the describe and stores it in transaction-scope cache; subsequent
	 * calls within the same Apex transaction return the cached describe without a re-compute.
	 *
	 * @return The Account DescribeSObjectResult, served from cache on second-and-later calls.
	 */
	public Schema.DescribeSObjectResult getMemoizedAccountDescribe()
	{
		kern.UTIL_Cache.Store cache = kern.UTIL_Cache.inTransaction();
		Schema.DescribeSObjectResult cached = (Schema.DescribeSObjectResult)cache.get(MEMOIZED_DESCRIBE_KEY);

		if(cached != null)
		{
			return cached;
		}

		Schema.DescribeSObjectResult computed = Account.SObjectType.getDescribe();
		cache.put(MEMOIZED_DESCRIBE_KEY, computed);
		return computed;
	}

	/**
	 * @description Stores a value via the autoWithTransactionFallback() composite store and
	 * reports back which scope serviced the put. Subscribers monitoring degraded paths read
	 * `OperationResult.cacheTypeUsed` after each call.
	 *
	 * @param value The value to cache.
	 *
	 * @return The Scope that serviced the put (SESSION / ORG / IN_TRANSACTION).
	 */
	public kern.UTIL_Cache.Scope storeWithGracefulFallback(String value)
	{
		kern.UTIL_Cache.Store composite = kern.UTIL_Cache.autoWithTransactionFallback();
		composite.put(FALLBACK_KEY, value);
		return composite.getLastOperationResult().cacheTypeUsed;
	}

	/**
	 * @description Reads the value previously stored via {@link #storeWithGracefulFallback}.
	 *
	 * @return The stored value, or null if never stored.
	 */
	public String readFromGracefulFallback()
	{
		return (String)kern.UTIL_Cache.autoWithTransactionFallback().get(FALLBACK_KEY);
	}
}
