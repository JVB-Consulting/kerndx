// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behavior of the [SEL_AsynchronousJobSetting] class.
 *
 * @see SEL_AsynchronousJobSetting
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SEL_AsynchronousJobSetting_TEST
{
	/**
	 * @description Expected default batch size when no custom metadata record exists.
	 */
	private static final Integer EXPECTED_DEFAULT = UTIL_SObjectDescribe.DEFAULT_BATCH_SIZE;

	/**
	 * @description Tests that getBatchSize returns the default batch size when no custom metadata record exists.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldReturnDefaultBatchSizeWhenNoMetadataExists()
	{
		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(UTIL_Random.randomName());

		Test.stopTest();

		Assert.areEqual(EXPECTED_DEFAULT, batchSize, 'Should return default batch size when no metadata record exists');
	}

	/**
	 * @description Tests that getBatchSize returns the configured batch size from a mocked metadata record.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldReturnConfiguredBatchSizeWhenMetadataExists()
	{
		AsynchronousJobSetting__mdt setting = new AsynchronousJobSetting__mdt(BatchSize__c = 50);
		SEL_AsynchronousJobSetting.mockedSetting = setting;

		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(UTIL_Random.randomName());

		Test.stopTest();

		Assert.areEqual(50, batchSize, 'Should return configured batch size from metadata');
	}

	/**
	 * @description Tests that getBatchSize caps result at the maximum batch size.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldCapBatchSizeAtMaximum()
	{
		AsynchronousJobSetting__mdt setting = new AsynchronousJobSetting__mdt(BatchSize__c = 99999);
		SEL_AsynchronousJobSetting.mockedSetting = setting;

		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(UTIL_Random.randomName());

		Test.stopTest();

		Assert.areEqual(UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE, batchSize, 'Should cap at maximum batch size');
	}

	/**
	 * @description Tests that the custom default overload returns the provided default when no metadata exists.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldReturnCustomDefaultWhenNoMetadataExists()
	{
		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(UTIL_Random.randomName(), 20);

		Test.stopTest();

		Assert.areEqual(20, batchSize, 'Should return custom default when no metadata record exists');
	}

	/**
	 * @description Tests that the custom default overload still reads the metadata value when configured.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldPreferMetadataOverCustomDefault()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 35);

		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(UTIL_Random.randomName(), 20);

		Test.stopTest();

		Assert.areEqual(35, batchSize, 'Should prefer metadata value over custom default');
	}
}