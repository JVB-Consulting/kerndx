// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_Limits.
 *
 * @see UTIL_Limits
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date April 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_Limits_TEST
{
	/**
	 * @description Verifies that remaining() returns a non-negative value for all factory methods.
	 */
	@IsTest
	private static void shouldReturnRemainingForAllLimitTypes()
	{
		Assert.isTrue(UTIL_Limits.aggregateQueries().remaining() >= 0, 'Aggregate Queries remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.callouts().remaining() >= 0, 'Callouts remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.cpuTime().remaining() >= 0, 'CPU Time remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.dmlRows().remaining() >= 0, 'DML Rows remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.dmlStatements().remaining() >= 0, 'DML Statements remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.emailInvocations().remaining() >= 0, 'Email Invocations remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.futureCalls().remaining() >= 0, 'Future Calls remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.heapSize().remaining() >= 0, 'Heap Size remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.mobilePushApexCalls().remaining() >= 0, 'Mobile Push remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.publishImmediateDml().remaining() >= 0, 'Publish Immediate DML remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.soqlQueries().remaining() >= 0, 'SOQL Queries remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.soqlQueryRows().remaining() >= 0, 'SOQL Query Rows remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.soqlQueryLocatorRows().remaining() >= 0, 'QueryLocator Rows remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.queueableJobs().remaining() >= 0, 'Queueable Jobs remaining should be non-negative');
		Assert.isTrue(UTIL_Limits.soslQueries().remaining() >= 0, 'SOSL Queries remaining should be non-negative');
	}

	/**
	 * @description Verifies that used() reflects actual consumption after a SOQL query.
	 */
	@IsTest
	private static void shouldReflectUsedAfterConsumption()
	{
		Integer beforeQueries = UTIL_Limits.soqlQueries().used();

		QRY_Builder.selectFrom(Foobar__c.SObjectType).count();

		Assert.isTrue(UTIL_Limits.soqlQueries().used() > beforeQueries, 'SOQL query count should increase after a query');
	}

	/**
	 * @description Verifies that maximum() returns the platform governor limit for SOQL queries.
	 */
	@IsTest
	private static void shouldReturnMaximumLimits()
	{
		Assert.areEqual(Limits.getLimitQueries(), UTIL_Limits.soqlQueries().maximum(), 'SOQL maximum should match Limits.getLimitQueries()');
		Assert.areEqual(Limits.getLimitCallouts(), UTIL_Limits.callouts().maximum(), 'Callouts maximum should match Limits.getLimitCallouts()');
		Assert.areEqual(Limits.getLimitDmlStatements(), UTIL_Limits.dmlStatements().maximum(), 'DML Statements maximum should match Limits.getLimitDmlStatements()');
	}

	/**
	 * @description Verifies that percentUsed() returns a value between 0.0 and 1.0.
	 */
	@IsTest
	private static void shouldCalculatePercentUsed()
	{
		Decimal percent = UTIL_Limits.soqlQueries().percentUsed();

		Assert.isTrue(percent >= 0, 'Percent used should be non-negative');
		Assert.isTrue(percent <= 1.0, 'Percent used should not exceed 1.0');
	}

	/**
	 * @description Verifies that isExhausted() returns false in a fresh transaction.
	 */
	@IsTest
	private static void shouldNotBeExhaustedInFreshTransaction()
	{
		Assert.isFalse(UTIL_Limits.soqlQueries().isExhausted(), 'SOQL queries should not be exhausted in a fresh transaction');
		Assert.isFalse(UTIL_Limits.callouts().isExhausted(), 'Callouts should not be exhausted in a fresh transaction');
		Assert.isFalse(UTIL_Limits.dmlStatements().isExhausted(), 'DML statements should not be exhausted in a fresh transaction');
	}

	/**
	 * @description Verifies that isNearLimit() with a zero threshold always returns true.
	 */
	@IsTest
	private static void shouldDetectNearLimitWithZeroThreshold()
	{
		Assert.isTrue(UTIL_Limits.heapSize().isNearLimit(0.0), 'Any usage should be at or above a 0.0 threshold');
	}

	/**
	 * @description Verifies that isNearLimit() auto-normalises values greater than 1.0.
	 */
	@IsTest
	private static void shouldNormaliseThresholdAboveOne()
	{
		Boolean resultDecimal = UTIL_Limits.soqlQueries().isNearLimit(0.99);
		Boolean resultWhole = UTIL_Limits.soqlQueries().isNearLimit(99);

		Assert.areEqual(resultDecimal, resultWhole, 'isNearLimit(99) should behave the same as isNearLimit(0.99)');
	}

	/**
	 * @description Verifies that snapshot() returns a LimitCheck for every limit type.
	 */
	@IsTest
	private static void shouldBuildSnapshotForAllLimitTypes()
	{
		List<UTIL_Limits.LimitCheck> checks = UTIL_Limits.snapshot();

		Assert.areEqual(15, checks.size(), 'Snapshot should contain 15 limit types');

		for(UTIL_Limits.LimitCheck check : checks)
		{
			Assert.isNotNull(check.label, 'Each LimitCheck should have a label');
			Assert.isTrue(check.maximum() >= 0, 'Maximum should be non-negative for ' + check.label);
		}
	}

	/**
	 * @description Verifies that toDebugString() produces a formatted multi-line output with all limit types.
	 */
	@IsTest
	private static void shouldBuildDebugString()
	{
		String debugString = UTIL_Limits.toDebugString();

		Assert.isTrue(debugString.contains('Queries:'), 'Debug string should contain Queries');
		Assert.isTrue(debugString.contains('Callouts:'), 'Debug string should contain Callouts');
		Assert.isTrue(debugString.contains('Heap Size:'), 'Debug string should contain Heap Size');
		Assert.isTrue(debugString.contains('DML Rows:'), 'Debug string should contain DML Rows');
		Assert.isTrue(debugString.contains(' of '), 'Debug string should contain " of " separator');
	}

	/**
	 * @description Verifies that the LimitCheck label is accessible.
	 */
	@IsTest
	private static void shouldExposeLabel()
	{
		Assert.areEqual('Callouts', UTIL_Limits.callouts().label, 'Callouts label should be "Callouts"');
		Assert.areEqual('Queries', UTIL_Limits.soqlQueries().label, 'SOQL Queries label should be "Queries"');
		Assert.areEqual('Heap Size', UTIL_Limits.heapSize().label, 'Heap Size label should be "Heap Size"');
	}

}