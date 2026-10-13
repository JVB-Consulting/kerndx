// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides methods to retrieve asynchronous job configuration settings from the `AsynchronousJobSetting__mdt` custom metadata type.
 * The class supports configurable batch sizes for different async classes, enabling dynamic processing based on
 * metadata configuration.
 *
 * @see AsynchronousJobSetting__mdt
 * @see SEL_AsynchronousJobSetting_TEST
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, August 2026
 */
public inherited sharing class SEL_AsynchronousJobSetting
{
	/**
	 * @description Test-only override for the metadata record returned by getBatchSize, set only by `_TEST` classes.
	 * The override stands in for the metadata record when its `DeveloperName` is blank, or when that `DeveloperName`
	 * matches the requested class name exactly, as the metadata lookup does, once dots have been replaced with
	 * underscores. While it is set the org's own metadata is never read, so a request for any other class name
	 * returns the default rather than whatever a subscriber happens to have configured, which lets a test prove the
	 * key a caller looked the setting up under without depending on the org it runs in.
	 */
	@TestVisible
	private static AsynchronousJobSetting__mdt mockedSetting;

	/**
	 * @description Retrieves the configured batch size for the specified asynchronous job class.
	 * If no metadata record is found for the given class or if the configured size is invalid, it defaults to the standard batch size.
	 * This method ensures batch sizes are capped at the defined maximum to prevent exceeding Salesforce limits.
	 *
	 * @param batchApexClassName The name of the asynchronous job class for which the batch size is required.
	 * This parameter is used to locate the corresponding metadata record in `AsynchronousJobSetting__mdt`.
	 *
	 * @return Integer The configured batch size for the specified class, defaulting to `UTIL_SObjectDescribe.DEFAULT_BATCH_SIZE`
	 * if no valid setting exists. The size is capped at `UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE`.
	 *
	 * @see AsynchronousJobSetting__mdt
	 * @see UTIL_SObjectDescribe.DEFAULT_BATCH_SIZE
	 * @see UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE
	 *
	 * @example
	 * ```apex
	 * Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize('MyBatchClass');
	 * ```
	 */
	public static Integer getBatchSize(String batchApexClassName)
	{
		return getBatchSize(batchApexClassName, UTIL_SObjectDescribe.DEFAULT_BATCH_SIZE);
	}

	/**
	 * @description Retrieves the configured batch size for the specified asynchronous job class, using the provided
	 * default when no metadata record is found. This overload is useful for callout-heavy jobs that need a lower
	 * default than the standard 200.
	 *
	 * @param batchApexClassName The name of the asynchronous job class for which the batch size is required.
	 * This parameter is used to locate the corresponding metadata record in `AsynchronousJobSetting__mdt`.
	 * @param defaultSize The fallback batch size when no metadata record is configured.
	 *
	 * @return Integer The configured batch size for the specified class, defaulting to `defaultSize`
	 * if no valid setting exists. The size is capped at `UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE`.
	 *
	 * @see AsynchronousJobSetting__mdt
	 *
	 * @example
	 * ```apex
	 * Integer batchSize = SEL_AsynchronousJobSetting.getBatchSize('FLOW_CallApiAsync', 20);
	 * ```
	 */
	public static Integer getBatchSize(String batchApexClassName, Integer defaultSize)
	{
		String settingDeveloperName = UTIL_String.replace(batchApexClassName, UTIL_String.DOT, UTIL_String.UNDERSCORE);

		AsynchronousJobSetting__mdt asynchronousJobSetting = mockedSetting != null
				? resolveMockedSetting(settingDeveloperName)
				: AsynchronousJobSetting__mdt.getInstance(settingDeveloperName);

		Integer configuredBatchSize = defaultSize;

		if(asynchronousJobSetting != null && asynchronousJobSetting.BatchSize__c >= 1)
		{
			configuredBatchSize = Math.min(Integer.valueOf(asynchronousJobSetting.BatchSize__c), UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE);
		}

		return configuredBatchSize;
	}

	/**
	 * @description Resolves the test-only mocked setting for the metadata record name a caller asked for. Called
	 * only when `mockedSetting` has been staged. The mock stands in when no `DeveloperName` was staged on it, or
	 * when the staged `DeveloperName` matches the requested name exactly, as the metadata lookup does, so a test
	 * that stages one class name proves callers ask for that name and no other.
	 *
	 * @param settingDeveloperName The `AsynchronousJobSetting__mdt` DeveloperName being requested, already normalised.
	 *
	 * @return The mocked setting when it stands in for the requested name, otherwise null.
	 */
	private static AsynchronousJobSetting__mdt resolveMockedSetting(String settingDeveloperName)
	{
		Boolean standsInForAnyName = String.isBlank(mockedSetting.DeveloperName);

		return standsInForAnyName || mockedSetting.DeveloperName.equals(settingDeveloperName) ? mockedSetting : null;
	}
}