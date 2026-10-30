// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests the behavior of the [SEL_AsynchronousJobSetting] class.
 *
 * @see SEL_AsynchronousJobSetting
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SEL_AsynchronousJobSetting_TEST
{
	/**
	 * @description Expected default batch size when no custom metadata record exists.
	 */
	private static final Integer EXPECTED_DEFAULT = UTIL_SObjectDescribe.DEFAULT_BATCH_SIZE;

	/**
	 * @description Batch size carried by the metadata records staged in the record-name tests, chosen to differ
	 * from both the default and the maximum so a matched record is unmistakable.
	 */
	private static final Integer CONFIGURED_BATCH_SIZE = 7;

	/**
	 * @description Class name a staged metadata record is named for in the record-name tests.
	 */
	private static final String SETTING_CLASS_NAME = 'MockAsynchronousJobClass';

	/**
	 * @description The staged record's class name spelled with different capitalisation, which differs from the
	 * staged DeveloperName only by case and so must not match it, because a metadata DeveloperName lookup is
	 * case-sensitive.
	 */
	private static final String SETTING_CLASS_NAME_IN_OTHER_CASE = 'mockASYNCHRONOUSjobCLASS';

	/**
	 * @description Class name no staged metadata record is named for, used to prove a mismatch falls back to the default.
	 */
	private static final String OTHER_CLASS_NAME = 'OtherMockAsynchronousJobClass';

	/**
	 * @description Inner-class name as Apex reports it, with the dot separating the outer and inner class.
	 */
	private static final String NESTED_CLASS_NAME = 'MockAsynchronousJobOuter.MockAsynchronousJobInner';

	/**
	 * @description The same inner class as a metadata DeveloperName, which cannot contain a dot.
	 */
	private static final String NESTED_SETTING_NAME = 'MockAsynchronousJobOuter_MockAsynchronousJobInner';

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
	 * The record carries no DeveloperName, which is the form that stands in for whatever class name is requested.
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

	/**
	 * @description Proves the batch size is read from the record named for the class that was asked about: a record
	 * whose DeveloperName is that class name is applied. Without this, a per-class record could never be observed.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldReturnConfiguredBatchSizeWhenRecordIsNamedForRequestedClass()
	{
		SEL_AsynchronousJobSetting.mockedSetting = buildSetting(SETTING_CLASS_NAME, CONFIGURED_BATCH_SIZE);

		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(SETTING_CLASS_NAME);

		Test.stopTest();

		Assert.areEqual(CONFIGURED_BATCH_SIZE, batchSize, 'Should return the size from the record named for the requested class');
	}

	/**
	 * @description Proves an inner-class name is normalised before the record is located: the dotted name Apex reports
	 * finds the record whose DeveloperName has an underscore in the dot's place, the only form metadata names allow.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldReturnConfiguredBatchSizeWhenRequestedClassNameContainsDots()
	{
		SEL_AsynchronousJobSetting.mockedSetting = buildSetting(NESTED_SETTING_NAME, CONFIGURED_BATCH_SIZE);

		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(NESTED_CLASS_NAME);

		Test.stopTest();

		Assert.areEqual(CONFIGURED_BATCH_SIZE, batchSize, 'Should replace dots with underscores before locating the record');
	}

	/**
	 * @description Proves the record name is matched exactly, the way the platform's own metadata lookup treats a
	 * DeveloperName, so a class name spelled in another case does not find the record and the caller gets the default.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldReturnDefaultBatchSizeWhenRequestedClassNameDiffersOnlyByCase()
	{
		SEL_AsynchronousJobSetting.mockedSetting = buildSetting(SETTING_CLASS_NAME, CONFIGURED_BATCH_SIZE);

		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(SETTING_CLASS_NAME_IN_OTHER_CASE);

		Test.stopTest();

		Assert.areEqual(EXPECTED_DEFAULT, batchSize, 'Should not match a record name that differs only by capitalisation');
	}

	/**
	 * @description Proves a record named for one class does not answer a request about another class: the caller gets
	 * the default instead, and the org's own metadata is never consulted while a record is staged, so the result is
	 * the same in any org. This is what makes the lookup key observable rather than assumed.
	 *
	 * @see SEL_AsynchronousJobSetting.getBatchSize
	 */
	@IsTest
	private static void shouldReturnDefaultBatchSizeWhenRecordIsNamedForAnotherClass()
	{
		SEL_AsynchronousJobSetting.mockedSetting = buildSetting(SETTING_CLASS_NAME, CONFIGURED_BATCH_SIZE);

		Test.startTest();

		Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize(OTHER_CLASS_NAME);

		Test.stopTest();

		Assert.areEqual(EXPECTED_DEFAULT, batchSize, 'Should ignore a record named for a different class');
	}

	/**
	 * @description Builds an in-memory metadata record for the tests that stage a named setting.
	 *
	 * @param developerName The DeveloperName the record carries.
	 * @param batchSize The batch size the record configures.
	 *
	 * @return The in-memory `AsynchronousJobSetting__mdt` record.
	 */
	private static AsynchronousJobSetting__mdt buildSetting(String developerName, Integer batchSize)
	{
		return (AsynchronousJobSetting__mdt)TST_Builder.of(AsynchronousJobSetting__mdt.SObjectType)
				.withOverride(AsynchronousJobSetting__mdt.DeveloperName, developerName)
				.withOverride(AsynchronousJobSetting__mdt.BatchSize__c, batchSize)
				.withoutInsertion()
				.build();
	}
}