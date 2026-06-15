// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Drift-guard demo class for `kern.TST_Mock.throwsException()`
 * subscriber-facing surface. Demonstrates a `try` / `catch` against `kern.QRY_Builder`
 * — exactly the negative-path scenario subscribers need to cover their catch blocks at
 * 100% per docs/Code Conventions - Guide.md.
 *
 * The wrapper exposes a single service method that runs a query and returns the count, or
 * returns -1 on caught `QueryException`. Subscriber tests then call
 * `kern.TST_Mock.throwsException(Account.SObjectType, ...)` to force the negative path
 * without any other mocking layer. Three `kern.TST_Mock.throwsException` overloads exist:
 *
 * - `throwsException(SObjectType, Exception)`  — explicit exception instance
 * - `throwsException(SObjectType, String)`     — wraps the message in a QueryException
 * - `throwsException(SObjectType)`             — generic QueryException with default message
 *
 * `kern.TST_Mock.clear(SObjectType)` and `kern.TST_Mock.clear()` both wipe the exception
 * registry so subscribers do not need to clear two layers manually.
 *
 * @see FastStart_MockException_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_MockException_DEMO
{
	/**
	 * @description Sentinel value returned when the wrapped query throws a QueryException.
	 */
	@TestVisible
	private static final Integer QUERY_FAILED_SENTINEL = -1;

	/**
	 * @description Counts Accounts matching the given Industry. Returns -1 when the underlying
	 * query throws a `QueryException`. Subscribers test the catch path by registering a mock
	 * exception against `Account.SObjectType` via `kern.TST_Mock.throwsException` before calling
	 * this method — no DML or query mock is required at any other layer.
	 *
	 * @param industry The Industry value to filter on.
	 *
	 * @return The matching record count, or `-1` when a QueryException was caught.
	 */
	public Integer safeCountAccountsByIndustry(String industry)
	{
		try
		{
			return kern.QRY_Builder.selectFrom(Account.SObjectType)
					.condition(Account.Industry).equals(industry)
					.count();
		}
		catch(QueryException error)
		{
			return QUERY_FAILED_SENTINEL;
		}
	}
}
