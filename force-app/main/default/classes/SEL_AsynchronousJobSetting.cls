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
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_AsynchronousJobSetting
{
	/**
	 * @description Test-only override for the metadata record returned by getBatchSize.
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
		AsynchronousJobSetting__mdt asynchronousJobSetting = mockedSetting != null
				? mockedSetting
				: AsynchronousJobSetting__mdt.getInstance(UTIL_String.replace(batchApexClassName, UTIL_String.DOT, UTIL_String.UNDERSCORE));

		Integer configuredBatchSize = defaultSize;

		if(asynchronousJobSetting != null && asynchronousJobSetting.BatchSize__c >= 1)
		{
			configuredBatchSize = Math.min(Integer.valueOf(asynchronousJobSetting.BatchSize__c), UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE);
		}

		return configuredBatchSize;
	}
}