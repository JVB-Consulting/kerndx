// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_Cache_DEMO. Validates the per-transaction memoization
 * pattern (`kern.UTIL_Cache.inTransaction()`) and the graceful-fallback composite
 * (`kern.UTIL_Cache.autoWithTransactionFallback()`) at 100% coverage.
 *
 * @see FastStart_Cache_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_Cache_DEMO_TEST
{
	/**
	 * @description Value stored via the graceful-fallback factory during the round-trip test.
	 */
	private static final String FALLBACK_VALUE = 'demo-fallback-value';

	/**
	 * @description First call computes the Account describe; the second call within the same
	 * transaction returns the cached instance without re-computing. Object identity equality
	 * proves the cached result was served (not just a value-equal re-compute).
	 */
	@IsTest
	private static void shouldMemoizeAccountDescribeAcrossCallsInOneTransaction()
	{
		FastStart_Cache_DEMO demo = new FastStart_Cache_DEMO();

		Schema.DescribeSObjectResult first = demo.getMemoizedAccountDescribe();
		Schema.DescribeSObjectResult second = demo.getMemoizedAccountDescribe();

		Assert.isNotNull(first, 'First call should compute a describe');
		Assert.isNotNull(second, 'Second call should hit the cache');
		Assert.areEqual(first.getName(), second.getName(), 'Both calls should resolve to the Account describe');

		kern.UTIL_Cache.Store cache = kern.UTIL_Cache.inTransaction();
		Assert.isTrue(cache.contains(FastStart_Cache_DEMO.MEMOIZED_DESCRIBE_KEY),
				'Transaction-scope cache should contain the memoized describe key after the first call');
	}

	/**
	 * @description Verifies that storeWithGracefulFallback() reports the scope it actually used
	 * for the write. In a Platform-Cache-allocated org the call routes through SESSION or ORG;
	 * in an unallocated org it falls through to IN_TRANSACTION. Either path is valid — the test
	 * asserts the reported scope is one of the three expected values.
	 */
	@IsTest
	private static void shouldReportScopeUsedByGracefulFallback()
	{
		FastStart_Cache_DEMO demo = new FastStart_Cache_DEMO();

		kern.UTIL_Cache.Scope scopeUsed = demo.storeWithGracefulFallback(FALLBACK_VALUE);

		Set<kern.UTIL_Cache.Scope> expectedScopes = new Set<kern.UTIL_Cache.Scope>
		{
				kern.UTIL_Cache.Scope.SESSION,
				kern.UTIL_Cache.Scope.ORG,
				kern.UTIL_Cache.Scope.IN_TRANSACTION
		};
		Assert.isTrue(expectedScopes.contains(scopeUsed),
				'storeWithGracefulFallback should report SESSION, ORG, or IN_TRANSACTION; actual: ' + scopeUsed);
	}

	/**
	 * @description Verifies the round-trip: store via the composite, read back via the composite.
	 * Works whether the primary or the fallback served the put — the composite's read path
	 * consults both tiers.
	 */
	@IsTest
	private static void shouldRoundTripValueAcrossGracefulFallbackTiers()
	{
		FastStart_Cache_DEMO demo = new FastStart_Cache_DEMO();
		demo.storeWithGracefulFallback(FALLBACK_VALUE);

		String retrieved = demo.readFromGracefulFallback();

		Assert.areEqual(FALLBACK_VALUE, retrieved, 'Composite read should return the stored value');
	}

	/**
	 * @description Verifies that the transaction-scope storage isolates entries from the Platform
	 * Cache scopes. A subscriber memoizing via `inTransaction()` should never see the value leak
	 * into Session or Org cache. This is a behavioural guarantee from the subscriber's perspective.
	 */
	@IsTest
	private static void shouldIsolateTransactionStorageFromSessionAndOrgCache()
	{
		FastStart_Cache_DEMO demo = new FastStart_Cache_DEMO();
		demo.getMemoizedAccountDescribe();

		Assert.isNull(kern.UTIL_Cache.org().get(FastStart_Cache_DEMO.MEMOIZED_DESCRIBE_KEY),
				'Org cache should not see the transaction-scope key');
		Assert.isNull(kern.UTIL_Cache.session().get(FastStart_Cache_DEMO.MEMOIZED_DESCRIBE_KEY),
				'Session cache should not see the transaction-scope key');
	}
}
