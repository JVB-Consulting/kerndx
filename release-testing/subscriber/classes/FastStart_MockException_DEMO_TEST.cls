// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_MockException_DEMO. Exercises the catch path of
 * `safeCountAccountsByIndustry` via the three `kern.TST_Mock.throwsException` overloads and
 * confirms the happy path still works when no exception is registered.
 *
 * @see FastStart_MockException_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_MockException_DEMO_TEST
{
	/**
	 * @description Industry value used across catch-path tests; specific Industry text is irrelevant when the mock throws.
	 */
	private static final String FIXTURE_INDUSTRY = 'Biotechnology';

	/**
	 * @description Custom exception message verifying the String-overload threading.
	 */
	private static final String CUSTOM_ERROR_MESSAGE = 'Mocked query failure for negative-path demo';

	/**
	 * @description Without registering a mock exception, the query executes normally and the
	 * wrapper returns the actual count (zero in an empty scratch org with no Accounts of the
	 * fixture Industry).
	 */
	@IsTest
	private static void shouldReturnRealCountWhenNoMockRegistered()
	{
		Integer result = new FastStart_MockException_DEMO().safeCountAccountsByIndustry(FIXTURE_INDUSTRY);

		Assert.areEqual(0, result, 'Empty org with no matching Accounts should return 0, not the sentinel');
	}

	/**
	 * @description Verifies the explicit-Exception-instance overload. Registers a
	 * `QueryException` against `Account.SObjectType`; the wrapper's catch block returns -1.
	 */
	@IsTest
	private static void shouldReturnSentinelWhenExplicitExceptionRegistered()
	{
		kern.TST_Mock.throwsException(Account.SObjectType, new QueryException(CUSTOM_ERROR_MESSAGE));

		Integer result = new FastStart_MockException_DEMO().safeCountAccountsByIndustry(FIXTURE_INDUSTRY);

		Assert.areEqual(FastStart_MockException_DEMO.QUERY_FAILED_SENTINEL, result,
				'Catch path should return the sentinel when the explicit-exception mock fires');
	}

	/**
	 * @description Verifies the String-overload — `kern.TST_Mock` wraps the message in a
	 * `QueryException` automatically.
	 */
	@IsTest
	private static void shouldReturnSentinelWhenStringMessageOverloadUsed()
	{
		kern.TST_Mock.throwsException(Account.SObjectType, CUSTOM_ERROR_MESSAGE);

		Integer result = new FastStart_MockException_DEMO().safeCountAccountsByIndustry(FIXTURE_INDUSTRY);

		Assert.areEqual(FastStart_MockException_DEMO.QUERY_FAILED_SENTINEL, result,
				'Catch path should return the sentinel when the String-overload mock fires');
	}

	/**
	 * @description Verifies the no-arg-message overload — generic QueryException default message.
	 */
	@IsTest
	private static void shouldReturnSentinelWhenNoArgOverloadUsed()
	{
		kern.TST_Mock.throwsException(Account.SObjectType);

		Integer result = new FastStart_MockException_DEMO().safeCountAccountsByIndustry(FIXTURE_INDUSTRY);

		Assert.areEqual(FastStart_MockException_DEMO.QUERY_FAILED_SENTINEL, result,
				'Catch path should return the sentinel when the no-arg overload mock fires');
	}

	/**
	 * @description Verifies `kern.TST_Mock.clear(SObjectType)` wipes the registered exception so
	 * subsequent queries on the same type return real data again.
	 */
	@IsTest
	private static void shouldClearRegisteredExceptionPerSObjectType()
	{
		kern.TST_Mock.throwsException(Account.SObjectType, CUSTOM_ERROR_MESSAGE);
		kern.TST_Mock.clear(Account.SObjectType);

		Integer result = new FastStart_MockException_DEMO().safeCountAccountsByIndustry(FIXTURE_INDUSTRY);

		Assert.areEqual(0, result,
				'After clear(Account.SObjectType), the query should execute normally and return 0');
	}
}
